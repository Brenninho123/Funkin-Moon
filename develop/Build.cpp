#include <algorithm>
#include <array>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <regex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <io.h>
#include <windows.h>
#else
#include <sys/wait.h>
#include <unistd.h>
#endif

static const std::vector<std::string> KNOWN_TARGETS = {"windows", "linux", "macos", "android", "ios", "html5"};

struct BuildOptions
{
  bool debug = false;
  bool clean = false;
  bool failFast = false;
  int jobs = 1;
  std::string haxelibPath = "haxelib";
  std::vector<std::string> defines;
  std::filesystem::path logDir = "develop/build-logs";
};

struct TargetResult
{
  std::string target;
  bool debug = false;
  bool success = false;
  std::size_t errorBlocks = 0;
  std::size_t warningBlocks = 0;
  double durationSeconds = 0.0;
  int exitCode = -1;
  std::string logPath;
};

class LineBlockCollector
{
public:
  using Matcher = bool (*)(const std::string &);

  explicit LineBlockCollector(Matcher matcherFn, std::size_t maxLines = 12) : matcher(matcherFn), maxBlockLines(maxLines) {}

  void feed(const std::string &line)
  {
    bool isMatch = matcher(line);

    if (capturing)
    {
      if (isBlankLine(line))
      {
        closeBlock();
        return;
      }

      if (isMatch)
      {
        closeBlock();
      }
      else if (currentBlock.size() >= maxBlockLines)
      {
        closeBlock();
      }
      else
      {
        currentBlock.push_back(line);
        return;
      }
    }

    if (isMatch)
    {
      capturing = true;
      currentBlock.push_back(line);
    }
  }

  void finish()
  {
    if (capturing) closeBlock();
  }

  std::size_t count() const
  {
    return blocks.size();
  }

  const std::vector<std::vector<std::string>> &getBlocks() const
  {
    return blocks;
  }

private:
  Matcher matcher;
  std::size_t maxBlockLines;
  bool capturing = false;
  std::vector<std::string> currentBlock;
  std::vector<std::vector<std::string>> blocks;

  void closeBlock()
  {
    if (!currentBlock.empty()) blocks.push_back(currentBlock);

    currentBlock.clear();
    capturing = false;
  }

  static bool isBlankLine(const std::string &line)
  {
    for (char c : line)
    {
      if (!std::isspace(static_cast<unsigned char>(c))) return false;
    }

    return true;
  }
};

static bool matchesError(const std::string &line)
{
  static const std::vector<std::regex> patterns = {
    std::regex("\\bERROR\\b"),
    std::regex("^Error\\s*:"),
    std::regex(": error\\s*:", std::regex::icase),
    std::regex("\\berror [A-Z]+[0-9]+"),
    std::regex("Uncaught exception", std::regex::icase),
    std::regex("Build failed", std::regex::icase),
    std::regex("Fatal error", std::regex::icase)
  };

  for (const auto &pattern : patterns)
  {
    if (std::regex_search(line, pattern)) return true;
  }

  return false;
}

static bool matchesWarning(const std::string &line)
{
  static const std::vector<std::regex> patterns = {
    std::regex("\\bWARNING\\b"),
    std::regex("^Warning\\s*:"),
    std::regex(": warning\\s*:", std::regex::icase)
  };

  for (const auto &pattern : patterns)
  {
    if (std::regex_search(line, pattern)) return true;
  }

  return false;
}

#if defined(_WIN32)
static void enableWindowsAnsiSupport()
{
  HANDLE handle = GetStdHandle(STD_OUTPUT_HANDLE);
  DWORD mode = 0;

  if (handle != INVALID_HANDLE_VALUE && GetConsoleMode(handle, &mode))
  {
    SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  }
}
#endif

static bool detectColorSupport()
{
  const char *noColor = std::getenv("NO_COLOR");
  const char *forceColor = std::getenv("FORCE_COLOR");

  if (noColor != nullptr) return false;

  if (forceColor != nullptr) return std::string(forceColor) != "0";

#if defined(_WIN32)
  return _isatty(_fileno(stdout)) != 0;
#else
  return isatty(fileno(stdout)) != 0;
#endif
}

static bool colorEnabled()
{
  static const bool enabled = detectColorSupport();

  return enabled;
}

static bool needsQuoting(const std::string &part)
{
  return part.empty() || part.find_first_of(" \t\"'&|<>()^;$`*?[]{}!#~\\") != std::string::npos;
}

static std::string quoteArgument(const std::string &part)
{
  if (!needsQuoting(part)) return part;

  std::string quoted;

#if defined(_WIN32)
  quoted += '"';

  for (char c : part)
  {
    if (c == '"') quoted += '\\';

    quoted += c;
  }

  quoted += '"';
#else
  quoted += '\'';

  for (char c : part)
  {
    if (c == '\'') quoted += "'\\''";
    else quoted += c;
  }

  quoted += '\'';
#endif

  return quoted;
}

static bool isSafeName(const std::string &name)
{
  if (name.empty()) return false;

  for (char c : name)
  {
    if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_' && c != '-' && c != '=' && c != '.') return false;
  }

  return true;
}

static bool readLine(FILE *pipe, std::string &line)
{
  line.clear();

  std::array<char, 4096> buffer;

  while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr)
  {
    line += buffer.data();

    if (!line.empty() && line.back() == '\n') return true;
  }

  return !line.empty();
}

static std::string colorize(const std::string &text, const std::string &code)
{
  if (!colorEnabled()) return text;

  return "\x1b[" + code + "m" + text + "\x1b[0m";
}

static std::string red(const std::string &text)
{
  return colorize(text, "1;31");
}

static std::string green(const std::string &text)
{
  return colorize(text, "1;32");
}

static std::string yellow(const std::string &text)
{
  return colorize(text, "1;33");
}

static std::string bold(const std::string &text)
{
  return colorize(text, "1");
}

static std::string timestampForFilename()
{
  auto now = std::chrono::system_clock::now();
  std::time_t t = std::chrono::system_clock::to_time_t(now);
  std::tm tmValue{};

#if defined(_WIN32)
  localtime_s(&tmValue, &t);
#else
  localtime_r(&t, &tmValue);
#endif

  std::ostringstream out;
  out << std::put_time(&tmValue, "%Y%m%d-%H%M%S");
  return out.str();
}

static std::string timestampIso()
{
  auto now = std::chrono::system_clock::now();
  std::time_t t = std::chrono::system_clock::to_time_t(now);
  std::tm tmValue{};

#if defined(_WIN32)
  localtime_s(&tmValue, &t);
#else
  localtime_r(&t, &tmValue);
#endif

  std::ostringstream out;
  out << std::put_time(&tmValue, "%Y-%m-%dT%H:%M:%S");
  return out.str();
}

static std::string jsonEscape(const std::string &input)
{
  std::string output;
  output.reserve(input.size());

  for (char c : input)
  {
    switch (c)
    {
      case '"':
        output += "\\\"";
        break;
      case '\\':
        output += "\\\\";
        break;
      case '\n':
        output += "\\n";
        break;
      case '\r':
        output += "\\r";
        break;
      case '\t':
        output += "\\t";
        break;
      default:
        if (static_cast<unsigned char>(c) < 0x20)
        {
          char escaped[8];
          std::snprintf(escaped, sizeof(escaped), "\\u%04x", static_cast<unsigned int>(static_cast<unsigned char>(c)));
          output += escaped;
        }
        else
        {
          output += c;
        }
    }
  }

  return output;
}

static std::string buildCommand(const std::string &target, const BuildOptions &options)
{
  std::ostringstream command;

  command << quoteArgument(options.haxelibPath) << " run lime build " << target;
  command << (options.debug ? " -debug" : " -release");

  for (const auto &define : options.defines)
  {
    command << " -D" << define;
  }

  if (options.clean) command << " -clean";

  command << " 2>&1";

#if defined(_WIN32)
  return "\"" + command.str() + "\"";
#else
  return command.str();
#endif
}

static int closeProcess(FILE *pipe)
{
#if defined(_WIN32)
  return _pclose(pipe);
#else
  int status = pclose(pipe);

  if (status == -1) return -1;

  return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
#endif
}

static void writeJsonSummary(const std::filesystem::path &path, const std::vector<TargetResult> &results, double totalDuration)
{
  std::error_code dirError;
  std::filesystem::create_directories(path.parent_path(), dirError);

  std::ofstream file(path);

  if (!file.is_open()) return;

  file << "{\n";
  file << "  \"generatedAt\": \"" << jsonEscape(timestampIso()) << "\",\n";
  file << "  \"totalDurationSeconds\": " << totalDuration << ",\n";
  file << "  \"targets\": [\n";

  for (std::size_t i = 0; i < results.size(); i++)
  {
    const auto &result = results[i];

    file << "    {\n";
    file << "      \"target\": \"" << jsonEscape(result.target) << "\",\n";
    file << "      \"mode\": \"" << (result.debug ? "debug" : "release") << "\",\n";
    file << "      \"success\": " << (result.success ? "true" : "false") << ",\n";
    file << "      \"errorBlocks\": " << result.errorBlocks << ",\n";
    file << "      \"warningBlocks\": " << result.warningBlocks << ",\n";
    file << "      \"durationSeconds\": " << result.durationSeconds << ",\n";
    file << "      \"exitCode\": " << result.exitCode << ",\n";
    file << "      \"logPath\": \"" << jsonEscape(result.logPath) << "\"\n";
    file << "    }" << (i + 1 < results.size() ? "," : "") << "\n";
  }

  file << "  ]\n";
  file << "}\n";
}

static TargetResult runTarget(const std::string &target, const BuildOptions &options, bool liveConsole)
{
  std::string command = buildCommand(target, options);

  std::error_code dirError;
  std::filesystem::create_directories(options.logDir, dirError);

  std::filesystem::path logPath = options.logDir
    / (target + "-" + (options.debug ? "debug" : "release") + "-" + timestampForFilename() + ".log");

  std::ofstream logFile(logPath);

  TargetResult result;
  result.target = target;
  result.debug = options.debug;
  result.logPath = logPath.string();

  if (liveConsole)
  {
    std::cout << "\n" << std::string(70, '=') << "\n";
    std::cout << "Building target: " << bold(target) << (options.debug ? " (debug)" : " (release)") << "\n";
    std::cout << std::string(70, '=') << "\n";
    std::cout.flush();
  }

  auto start = std::chrono::steady_clock::now();

#if defined(_WIN32)
  FILE *pipe = _popen(command.c_str(), "r");
#else
  FILE *pipe = popen(command.c_str(), "r");
#endif

  if (pipe == nullptr)
  {
    if (liveConsole) std::cerr << red("Failed to start build process for target: ") << target << "\n";

    return result;
  }

  LineBlockCollector errorCollector(matchesError);
  LineBlockCollector warningCollector(matchesWarning);
  std::string line;

  while (readLine(pipe, line))
  {
    if (liveConsole) std::cout << line;

    if (logFile.is_open()) logFile << line;

    errorCollector.feed(line);
    warningCollector.feed(line);
  }

  errorCollector.finish();
  warningCollector.finish();

  if (logFile.is_open()) logFile.close();

  int exitCode = closeProcess(pipe);

  auto end = std::chrono::steady_clock::now();
  double duration = std::chrono::duration<double>(end - start).count();

  bool success = exitCode == 0;

  result.success = success;
  result.errorBlocks = errorCollector.count();
  result.warningBlocks = warningCollector.count();
  result.durationSeconds = duration;
  result.exitCode = exitCode;

  if (liveConsole)
  {
    if (errorCollector.count() > 0)
    {
      std::cout << "\n" << std::string(70, '-') << "\n";
      std::cout << red(std::to_string(errorCollector.count()) + " error block(s) detected for target " + target + ":") << "\n";
      std::cout << std::string(70, '-') << "\n";

      std::size_t index = 1;

      for (const auto &block : errorCollector.getBlocks())
      {
        std::cout << "\n[" << index << "]\n";
        index++;

        for (const auto &blockLine : block)
        {
          std::cout << blockLine;
        }
      }

      std::cout << "\n" << std::string(70, '-') << "\n";
    }

    if (warningCollector.count() > 0)
    {
      std::cout << yellow(std::to_string(warningCollector.count()) + " warning(s) detected for target " + target + ".") << "\n";
    }

    std::cout << "\nTarget " << target << ": " << (success ? green("PASSED") : red("FAILED"));
    std::cout << " (" << duration << "s, exit code " << exitCode << ", log: " << logPath.string() << ")\n";
    std::cout.flush();
  }

  return result;
}

static void printUsage()
{
  std::cout << "Usage: Build [options] [targets...]\n";
  std::cout << "Options:\n";
  std::cout << "  --debug              Build in debug mode (default: release)\n";
  std::cout << "  --release            Build in release mode\n";
  std::cout << "  --clean              Pass -clean to the build\n";
  std::cout << "  --define <name>      Add a -D<name> compiler define, repeatable\n";
  std::cout << "  --all                Build every known target in sequence\n";
  std::cout << "  --jobs <n>           Build up to n targets in parallel (default: 1)\n";
  std::cout << "  --fail-fast          Stop after the first failing target (sequential mode only)\n";
  std::cout << "  --log-dir <path>     Directory for per-target build logs (default: develop/build-logs)\n";
  std::cout << "  --haxelib <path>     Path to the haxelib executable (default: haxelib)\n";
  std::cout << "  --list               List known targets and exit\n";
  std::cout << "  --help               Show this message\n";
  std::cout << "Targets: windows, linux, macos, android, ios, html5\n";
}

int main(int argc, char **argv)
{
#if defined(_WIN32)
  enableWindowsAnsiSupport();
#endif

  BuildOptions options;
  bool buildAll = false;
  std::vector<std::string> targets;

  for (int i = 1; i < argc; i++)
  {
    std::string arg = argv[i];

    if (arg == "--help" || arg == "-h")
    {
      printUsage();
      return 0;
    }
    else if (arg == "--list")
    {
      std::cout << "Known targets:\n";

      for (const auto &knownTarget : KNOWN_TARGETS)
      {
        std::cout << "  " << knownTarget << "\n";
      }

      return 0;
    }
    else if (arg == "--debug")
    {
      options.debug = true;
    }
    else if (arg == "--release")
    {
      options.debug = false;
    }
    else if (arg == "--clean")
    {
      options.clean = true;
    }
    else if (arg == "--all")
    {
      buildAll = true;
    }
    else if (arg == "--fail-fast")
    {
      options.failFast = true;
    }
    else if (arg == "--jobs" && i + 1 < argc)
    {
      options.jobs = std::max(1, std::atoi(argv[++i]));
    }
    else if (arg == "--log-dir" && i + 1 < argc)
    {
      options.logDir = argv[++i];
    }
    else if (arg == "--haxelib" && i + 1 < argc)
    {
      options.haxelibPath = argv[++i];
    }
    else if (arg == "--define" && i + 1 < argc)
    {
      options.defines.push_back(argv[++i]);
    }
    else if (arg.rfind("--", 0) == 0)
    {
      std::cerr << "Unknown option: " << arg << "\n";
      printUsage();
      return 2;
    }
    else
    {
      targets.push_back(arg);
    }
  }

  if (buildAll)
  {
    targets = KNOWN_TARGETS;
  }
  else if (targets.empty())
  {
#if defined(_WIN32)
    targets = {"windows"};
#elif defined(__APPLE__)
    targets = {"macos"};
#else
    targets = {"linux"};
#endif
  }

  for (const auto &define : options.defines)
  {
    if (!isSafeName(define))
    {
      std::cerr << "Invalid define: " << define << "\n";
      return 2;
    }
  }

  for (const auto &target : targets)
  {
    if (!isSafeName(target))
    {
      std::cerr << "Invalid target name: " << target << "\n";
      return 2;
    }

    if (std::find(KNOWN_TARGETS.begin(), KNOWN_TARGETS.end(), target) == KNOWN_TARGETS.end())
    {
      std::cerr << yellow("Warning: \"" + target + "\" is not a recognized target name.") << "\n";
    }
  }

  auto overallStart = std::chrono::steady_clock::now();
  std::vector<TargetResult> results;
  bool anyFailed = false;

  if (options.jobs > 1 && targets.size() > 1)
  {
    results.resize(targets.size());

    std::atomic<std::size_t> nextIndex{0};
    std::mutex consoleMutex;

    auto worker = [&]()
    {
      while (true)
      {
        std::size_t index = nextIndex.fetch_add(1);

        if (index >= targets.size()) break;

        {
          std::lock_guard<std::mutex> lock(consoleMutex);
          std::cout << bold("[start] ") << targets[index] << (options.debug ? " (debug)" : " (release)") << "\n";
          std::cout.flush();
        }

        TargetResult result = runTarget(targets[index], options, false);
        results[index] = result;

        {
          std::lock_guard<std::mutex> lock(consoleMutex);
          std::cout << (result.success ? green("[pass] ") : red("[fail] ")) << targets[index] << " - " << result.errorBlocks
                     << " error(s), " << result.warningBlocks << " warning(s), " << result.durationSeconds << "s (log: " << result.logPath
                     << ")\n";
          std::cout.flush();
        }
      }
    };

    int workerCount = std::max(1, std::min(options.jobs, static_cast<int>(targets.size())));
    std::vector<std::thread> workers;

    for (int i = 0; i < workerCount; i++)
    {
      workers.emplace_back(worker);
    }

    for (auto &worker2 : workers)
    {
      worker2.join();
    }

    for (const auto &result : results)
    {
      if (!result.success) anyFailed = true;
    }
  }
  else
  {
    for (const auto &target : targets)
    {
      TargetResult result = runTarget(target, options, true);

      results.push_back(result);

      if (!result.success)
      {
        anyFailed = true;

        if (options.failFast) break;
      }
    }
  }

  double totalDuration = std::chrono::duration<double>(std::chrono::steady_clock::now() - overallStart).count();

  std::cout << "\n" << std::string(70, '=') << "\n";
  std::cout << "BUILD SUMMARY\n";
  std::cout << std::string(70, '=') << "\n";

  for (const auto &result : results)
  {
    std::cout << (result.success ? green("[PASS] ") : red("[FAIL] "));
    std::cout << result.target << (result.debug ? " (debug)" : " (release)");
    std::cout << " - " << result.errorBlocks << " error(s), " << result.warningBlocks << " warning(s), " << result.durationSeconds << "s\n";
  }

  std::cout << "Total time: " << totalDuration << "s\n";
  std::cout << std::string(70, '=') << "\n";

  writeJsonSummary(options.logDir / "summary.json", results, totalDuration);

  return anyFailed ? 1 : 0;
}

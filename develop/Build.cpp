#include <array>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <iostream>
#include <regex>
#include <sstream>
#include <string>
#include <vector>

#if !defined(_WIN32)
#include <sys/wait.h>
#endif

struct TargetResult
{
  std::string target;
  bool debug;
  bool success;
  std::size_t errorBlocks;
  double durationSeconds;
  int exitCode;
};

class ErrorCollector
{
public:
  void feed(const std::string &line)
  {
    bool isErrorLine = matchesErrorStart(line);

    if (capturing)
    {
      if (isBlankLine(line))
      {
        closeBlock();
        return;
      }

      if (isErrorLine)
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

    if (isErrorLine)
    {
      capturing = true;
      currentBlock.push_back(line);
    }
  }

  void finish()
  {
    if (capturing) closeBlock();
  }

  const std::vector<std::vector<std::string>> &getBlocks() const
  {
    return blocks;
  }

  std::size_t count() const
  {
    return blocks.size();
  }

private:
  static const std::size_t maxBlockLines = 12;
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

  static bool matchesErrorStart(const std::string &line)
  {
    static const std::vector<std::regex> patterns = {
      std::regex("\\bERROR\\b"),
      std::regex("^Error:"),
      std::regex(": error:", std::regex::icase),
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
};

static std::string buildCommand(const std::string &target, bool debug, const std::vector<std::string> &defines, bool clean)
{
  std::ostringstream command;

  command << "haxelib run lime build " << target;
  command << (debug ? " -debug" : " -release");

  for (const auto &define : defines)
  {
    command << " -D" << define;
  }

  if (clean) command << " -clean";

  command << " 2>&1";

  return command.str();
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

static TargetResult runTarget(const std::string &target, bool debug, const std::vector<std::string> &defines, bool clean)
{
  std::string command = buildCommand(target, debug, defines, clean);

  std::cout << "\n" << std::string(70, '=') << "\n";
  std::cout << "Building target: " << target << (debug ? " (debug)" : " (release)") << "\n";
  std::cout << std::string(70, '=') << "\n";
  std::cout.flush();

  auto start = std::chrono::steady_clock::now();

#if defined(_WIN32)
  FILE *pipe = _popen(command.c_str(), "r");
#else
  FILE *pipe = popen(command.c_str(), "r");
#endif

  if (pipe == nullptr)
  {
    std::cerr << "Failed to start build process for target: " << target << "\n";
    return {target, debug, false, 0, 0.0, -1};
  }

  ErrorCollector collector;
  std::array<char, 4096> buffer;

  while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr)
  {
    std::string line(buffer.data());

    std::cout << line;
    collector.feed(line);
  }

  collector.finish();

  int exitCode = closeProcess(pipe);

  auto end = std::chrono::steady_clock::now();
  double duration = std::chrono::duration<double>(end - start).count();

  bool success = (exitCode == 0) && (collector.count() == 0);

  if (collector.count() > 0)
  {
    std::cout << "\n" << std::string(70, '-') << "\n";
    std::cout << collector.count() << " error block(s) detected for target " << target << ":\n";
    std::cout << std::string(70, '-') << "\n";

    std::size_t index = 1;

    for (const auto &block : collector.getBlocks())
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

  std::cout << "\nTarget " << target << ": " << (success ? "PASSED" : "FAILED");
  std::cout << " (" << duration << "s, exit code " << exitCode << ")\n";
  std::cout.flush();

  return {target, debug, success, collector.count(), duration, exitCode};
}

static void printUsage()
{
  std::cout << "Usage: Build [options] [targets...]\n";
  std::cout << "Options:\n";
  std::cout << "  --debug            Build in debug mode (default: release)\n";
  std::cout << "  --release          Build in release mode\n";
  std::cout << "  --clean            Pass -clean to the build\n";
  std::cout << "  --define <name>    Add a -D<name> compiler define, repeatable\n";
  std::cout << "  --all              Build every known target in sequence\n";
  std::cout << "  --help             Show this message\n";
  std::cout << "Targets: windows, linux, macos, android, ios, html5\n";
}

int main(int argc, char **argv)
{
  bool debug = false;
  bool clean = false;
  bool buildAll = false;
  std::vector<std::string> defines;
  std::vector<std::string> targets;

  for (int i = 1; i < argc; i++)
  {
    std::string arg = argv[i];

    if (arg == "--help" || arg == "-h")
    {
      printUsage();
      return 0;
    }
    else if (arg == "--debug")
    {
      debug = true;
    }
    else if (arg == "--release")
    {
      debug = false;
    }
    else if (arg == "--clean")
    {
      clean = true;
    }
    else if (arg == "--all")
    {
      buildAll = true;
    }
    else if (arg == "--define" && i + 1 < argc)
    {
      defines.push_back(argv[++i]);
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
    targets = {"windows", "linux", "macos", "android", "ios", "html5"};
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

  std::vector<TargetResult> results;
  bool anyFailed = false;

  for (const auto &target : targets)
  {
    TargetResult result = runTarget(target, debug, defines, clean);

    results.push_back(result);

    if (!result.success) anyFailed = true;
  }

  std::cout << "\n" << std::string(70, '=') << "\n";
  std::cout << "BUILD SUMMARY\n";
  std::cout << std::string(70, '=') << "\n";

  for (const auto &result : results)
  {
    std::cout << (result.success ? "[PASS] " : "[FAIL] ");
    std::cout << result.target << (result.debug ? " (debug)" : " (release)");
    std::cout << " - " << result.errorBlocks << " error block(s), " << result.durationSeconds << "s\n";
  }

  std::cout << std::string(70, '=') << "\n";

  return anyFailed ? 1 : 0;
}

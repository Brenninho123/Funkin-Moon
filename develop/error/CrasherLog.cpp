#include <array>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <deque>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#if defined(_WIN32)
#else
#include <csignal>
#include <sys/wait.h>
#endif

struct RunResult
{
  bool crashed;
  bool signaled;
  int code;
  int signalNumber;
  double durationSeconds;
};

#if !defined(_WIN32)
static std::string signalName(int sig)
{
  switch (sig)
  {
    case SIGSEGV:
      return "SIGSEGV (segmentation fault)";
    case SIGABRT:
      return "SIGABRT (abort)";
    case SIGFPE:
      return "SIGFPE (floating point exception)";
    case SIGILL:
      return "SIGILL (illegal instruction)";
    case SIGBUS:
      return "SIGBUS (bus error)";
    case SIGTRAP:
      return "SIGTRAP (trace/breakpoint trap)";
    default:
      return "signal " + std::to_string(sig);
  }
}
#endif

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

static RunResult runOnce(const std::string &command, std::deque<std::string> &tail, std::size_t tailMax)
{
  auto start = std::chrono::steady_clock::now();

#if defined(_WIN32)
  FILE *pipe = _popen(command.c_str(), "r");
#else
  FILE *pipe = popen(command.c_str(), "r");
#endif

  if (pipe == nullptr)
  {
    return {true, false, -1, 0, 0.0};
  }

  std::array<char, 4096> buffer;

  while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr)
  {
    std::string line(buffer.data());

    std::cout << line;

    tail.push_back(line);

    if (tail.size() > tailMax) tail.pop_front();
  }

  auto end = std::chrono::steady_clock::now();
  double duration = std::chrono::duration<double>(end - start).count();

#if defined(_WIN32)
  int status = _pclose(pipe);

  return {status != 0, false, status, 0, duration};
#else
  int status = pclose(pipe);

  if (status == -1)
  {
    return {true, false, -1, 0, duration};
  }

  if (WIFSIGNALED(status))
  {
    return {true, true, status, WTERMSIG(status), duration};
  }

  int code = WIFEXITED(status) ? WEXITSTATUS(status) : status;

  if (code > 128 && code < 128 + NSIG)
  {
    return {true, true, code, code - 128, duration};
  }

  return {code != 0, false, code, 0, duration};
#endif
}

static std::string writeCrashLog(const std::filesystem::path &logDir, const std::string &command, const RunResult &result,
    const std::deque<std::string> &tail, int attempt, int totalAttempts)
{
  std::error_code dirError;

  std::filesystem::create_directories(logDir, dirError);

  std::filesystem::path logPath = logDir / ("crash_" + timestampForFilename() + "_run" + std::to_string(attempt) + ".log");

  std::ofstream file(logPath);

  if (!file.is_open())
  {
    std::cerr << "Failed to write crash log to " << logPath.string() << "\n";
    return "";
  }

  file << "CrasherLog crash report\n";
  file << "Generated at: " << timestampIso() << "\n";
  file << "Command: " << command << "\n";
  file << "Ran for: " << result.durationSeconds << "s\n";

#if defined(_WIN32)
  file << "Exit code: 0x" << std::hex << static_cast<unsigned int>(result.code) << std::dec << "\n";
#else
  if (result.signaled)
  {
    file << "Terminated by " << signalName(result.signalNumber) << "\n";
  }
  else
  {
    file << "Exit code: " << result.code << "\n";
  }
#endif

  file << "Attempt: " << attempt << " of " << totalAttempts << "\n";
  file << "\n--- Last " << tail.size() << " line(s) of output ---\n";

  for (const auto &line : tail)
  {
    file << line;
  }

  file << "--- End of output ---\n";

  file.close();

  return logPath.string();
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

static void printUsage()
{
  std::cout << "Usage: CrasherLog [options] -- <executable> [args...]\n";
  std::cout << "Options:\n";
  std::cout << "  --log-dir <path>       Directory to write crash logs (default: develop/error/logs)\n";
  std::cout << "  --restart-on-crash     Automatically relaunch the target after a crash\n";
  std::cout << "  --max-restarts <n>     Maximum automatic restarts (default: 5)\n";
  std::cout << "  --tail <n>             Trailing output lines kept for crash context (default: 200)\n";
  std::cout << "  --help                 Show this message\n";
}

int main(int argc, char **argv)
{
  std::string logDir = "develop/error/logs";
  bool restartOnCrash = false;
  int maxRestarts = 5;
  std::size_t tailMax = 200;
  std::vector<std::string> targetArgs;
  bool foundSeparator = false;

  int i = 1;

  for (; i < argc; i++)
  {
    std::string arg = argv[i];

    if (arg == "--")
    {
      foundSeparator = true;
      i++;
      break;
    }
    else if (arg == "--help" || arg == "-h")
    {
      printUsage();
      return 0;
    }
    else if (arg == "--log-dir" && i + 1 < argc)
    {
      logDir = argv[++i];
    }
    else if (arg == "--restart-on-crash")
    {
      restartOnCrash = true;
    }
    else if (arg == "--max-restarts" && i + 1 < argc)
    {
      maxRestarts = std::atoi(argv[++i]);
    }
    else if (arg == "--tail" && i + 1 < argc)
    {
      tailMax = static_cast<std::size_t>(std::atoi(argv[++i]));
    }
    else
    {
      std::cerr << "Unknown option: " << arg << "\n";
      printUsage();
      return 2;
    }
  }

  for (; i < argc; i++)
  {
    targetArgs.push_back(argv[i]);
  }

  if (!foundSeparator || targetArgs.empty())
  {
    std::cerr << "No target executable specified. Use: CrasherLog [options] -- <executable> [args...]\n";
    printUsage();
    return 2;
  }

  std::ostringstream commandBuilder;

  for (std::size_t argIndex = 0; argIndex < targetArgs.size(); argIndex++)
  {
    if (argIndex > 0) commandBuilder << " ";

    commandBuilder << quoteArgument(targetArgs[argIndex]);
  }

  commandBuilder << " 2>&1";

#if defined(_WIN32)
  std::string command = "\"" + commandBuilder.str() + "\"";
#else
  std::string command = commandBuilder.str();
#endif

  std::filesystem::path logPath(logDir);

  if (maxRestarts < 0) maxRestarts = 0;

  int attempt = 1;
  int runsExecuted = 0;
  int totalAttempts = restartOnCrash ? (maxRestarts + 1) : 1;
  int crashCount = 0;

  while (attempt <= totalAttempts)
  {
    runsExecuted++;

    std::cout << "\n" << std::string(70, '=') << "\n";
    std::cout << "CrasherLog run " << attempt << " of " << totalAttempts << "\n";
    std::cout << std::string(70, '=') << "\n";
    std::cout.flush();

    std::deque<std::string> tail;
    RunResult result = runOnce(command, tail, tailMax);

    if (result.crashed)
    {
      crashCount++;

      std::string writtenPath = writeCrashLog(logPath, command, result, tail, attempt, totalAttempts);

      std::cout << "\nCrash detected on run " << attempt << ".\n";

      if (!writtenPath.empty())
      {
        std::cout << "Crash log written to: " << writtenPath << "\n";
      }
    }
    else
    {
      std::cout << "\nRun " << attempt << " exited normally (code " << result.code << ", " << result.durationSeconds << "s).\n";
    }

    if (!result.crashed || !restartOnCrash) break;

    attempt++;
  }

  std::cout << "\n" << std::string(70, '=') << "\n";
  std::cout << "CrasherLog summary: " << runsExecuted << " run(s), " << crashCount << " crash(es) detected.\n";
  std::cout << std::string(70, '=') << "\n";

  return crashCount > 0 ? 1 : 0;
}

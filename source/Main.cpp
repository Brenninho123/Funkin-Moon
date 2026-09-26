#include "Main.hpp"

#include <atomic>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <psapi.h>
#if defined(_MSC_VER)
#pragma comment(lib, "psapi.lib")
#endif
#else
#include <fcntl.h>
#include <unistd.h>
#endif

#if defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#endif

namespace
{
constexpr const char *CRASH_MARKER_PATH = "native-crash.marker";
constexpr std::size_t MAX_MARKER_LENGTH = 32;

std::atomic<int> currentCrashSignal{0};
std::atomic<bool> crashHandlerInstalled{false};
std::string previousCrashSignalName;
std::string currentCrashSignalName;

const char *signalDisplayName(int sig)
{
  switch (sig)
  {
    case 0:
      return "";
    case SIGSEGV:
      return "SIGSEGV";
    case SIGABRT:
      return "SIGABRT";
    case SIGFPE:
      return "SIGFPE";
    case SIGILL:
      return "SIGILL";
#if !defined(_WIN32)
    case SIGBUS:
      return "SIGBUS";
#endif
    default:
      return "UNKNOWN";
  }
}

void writeCrashMarker(const char *name)
{
  std::size_t length = std::strlen(name);

#if defined(_WIN32)
  HANDLE file = CreateFileA(CRASH_MARKER_PATH, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);

  if (file == INVALID_HANDLE_VALUE) return;

  DWORD written = 0;
  WriteFile(file, name, static_cast<DWORD>(length), &written, nullptr);
  CloseHandle(file);
#else
  int file = open(CRASH_MARKER_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0644);

  if (file < 0) return;

  ssize_t written = write(file, name, length);
  (void) written;
  close(file);
#endif
}

void nativeSignalHandler(int sig)
{
  currentCrashSignal.store(sig);
  writeCrashMarker(signalDisplayName(sig));

  std::signal(sig, SIG_DFL);
  std::raise(sig);
}

void consumePreviousCrashMarker()
{
  previousCrashSignalName.clear();

  {
    std::ifstream file(CRASH_MARKER_PATH, std::ios::binary);

    if (!file.is_open()) return;

    std::string content;
    std::getline(file, content);

    if (content.size() > MAX_MARKER_LENGTH) content.resize(MAX_MARKER_LENGTH);

    while (!content.empty() && (content.back() == '\r' || content.back() == '\n' || content.back() == ' '))
    {
      content.pop_back();
    }

    previousCrashSignalName = content.empty() ? "UNKNOWN" : content;
  }

  std::remove(CRASH_MARKER_PATH);
}

#if !defined(_WIN32) && !defined(__APPLE__)
double readProcFieldKilobytes(const char *path, const char *key)
{
  std::ifstream stream(path);
  std::string line;
  std::size_t keyLength = std::strlen(key);

  while (std::getline(stream, line))
  {
    if (line.compare(0, keyLength, key) != 0) continue;

    std::istringstream lineStream(line.substr(keyLength));
    double kilobytes = 0.0;

    if (lineStream >> kilobytes) return kilobytes * 1024.0;

    return 0.0;
  }

  return 0.0;
}
#endif
} // namespace

extern "C" void funkin_native_installCrashHandler()
{
  if (crashHandlerInstalled.exchange(true)) return;

  consumePreviousCrashMarker();

  std::signal(SIGSEGV, nativeSignalHandler);
  std::signal(SIGABRT, nativeSignalHandler);
  std::signal(SIGFPE, nativeSignalHandler);
  std::signal(SIGILL, nativeSignalHandler);

#if !defined(_WIN32)
  std::signal(SIGBUS, nativeSignalHandler);
#endif
}

extern "C" bool funkin_native_hadNativeCrash()
{
  return currentCrashSignal.load() != 0 || !previousCrashSignalName.empty();
}

extern "C" const char *funkin_native_getLastCrashSignalName()
{
  int sig = currentCrashSignal.load();

  if (sig != 0)
  {
    currentCrashSignalName = signalDisplayName(sig);
    return currentCrashSignalName.c_str();
  }

  return previousCrashSignalName.c_str();
}

extern "C" double funkin_native_getProcessMemoryBytes()
{
#if defined(_WIN32)
  PROCESS_MEMORY_COUNTERS counters;
  std::memset(&counters, 0, sizeof(counters));
  counters.cb = sizeof(counters);

  if (GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters)))
  {
    return static_cast<double>(counters.WorkingSetSize);
  }

  return 0.0;
#elif defined(__APPLE__)
  mach_task_basic_info_data_t info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;

  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS)
  {
    return static_cast<double>(info.resident_size);
  }

  return 0.0;
#else
  return readProcFieldKilobytes("/proc/self/status", "VmRSS:");
#endif
}

extern "C" double funkin_native_getTotalSystemMemoryBytes()
{
#if defined(_WIN32)
  MEMORYSTATUSEX status;
  std::memset(&status, 0, sizeof(status));
  status.dwLength = sizeof(status);

  if (GlobalMemoryStatusEx(&status))
  {
    return static_cast<double>(status.ullTotalPhys);
  }

  return 0.0;
#elif defined(__APPLE__)
  uint64_t value = 0;
  size_t size = sizeof(value);

  if (sysctlbyname("hw.memsize", &value, &size, nullptr, 0) == 0)
  {
    return static_cast<double>(value);
  }

  return 0.0;
#else
  return readProcFieldKilobytes("/proc/meminfo", "MemTotal:");
#endif
}

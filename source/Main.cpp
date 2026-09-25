#include "Main.hpp"

#include <atomic>
#include <csignal>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <string>

#if defined(_WIN32)
#include <psapi.h>
#include <windows.h>
#else
#include <unistd.h>
#endif

#if defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#endif

static std::atomic<int> lastCrashSignal{0};
static std::atomic<bool> crashHandlerInstalled{false};

static const char *signalDisplayName(int sig)
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

static void writeNativeCrashMarker(int sig)
{
  std::ofstream file("native-crash.marker", std::ios::trunc);

  if (file.is_open())
  {
    file << signalDisplayName(sig) << "\n";
    file.close();
  }
}

static void funkinNativeSignalHandler(int sig)
{
  lastCrashSignal.store(sig);
  writeNativeCrashMarker(sig);

  std::signal(sig, SIG_DFL);
  std::raise(sig);
}

extern "C" void funkin_native_installCrashHandler()
{
  if (crashHandlerInstalled.exchange(true)) return;

  std::signal(SIGSEGV, funkinNativeSignalHandler);
  std::signal(SIGABRT, funkinNativeSignalHandler);
  std::signal(SIGFPE, funkinNativeSignalHandler);
  std::signal(SIGILL, funkinNativeSignalHandler);

#if !defined(_WIN32)
  std::signal(SIGBUS, funkinNativeSignalHandler);
#endif
}

extern "C" bool funkin_native_hadNativeCrash()
{
  return lastCrashSignal.load() != 0;
}

extern "C" const char *funkin_native_getLastCrashSignalName()
{
  return signalDisplayName(lastCrashSignal.load());
}

extern "C" double funkin_native_getProcessMemoryBytes()
{
#if defined(_WIN32)
  PROCESS_MEMORY_COUNTERS counters;

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
  std::ifstream status("/proc/self/status");
  std::string line;

  while (std::getline(status, line))
  {
    if (line.rfind("VmRSS:", 0) == 0)
    {
      std::istringstream lineStream(line.substr(6));
      double kilobytes = 0.0;

      lineStream >> kilobytes;

      return kilobytes * 1024.0;
    }
  }

  return 0.0;
#endif
}

extern "C" double funkin_native_getTotalSystemMemoryBytes()
{
#if defined(_WIN32)
  MEMORYSTATUSEX status;
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
  std::ifstream meminfo("/proc/meminfo");
  std::string line;

  while (std::getline(meminfo, line))
  {
    if (line.rfind("MemTotal:", 0) == 0)
    {
      std::istringstream lineStream(line.substr(9));
      double kilobytes = 0.0;

      lineStream >> kilobytes;

      return kilobytes * 1024.0;
    }
  }

  return 0.0;
#endif
}

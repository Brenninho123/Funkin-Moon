#include <array>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <deque>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <map>
#include <mutex>
#include <regex>
#include <sstream>
#include <stdexcept>
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
#include <windows.h>
#include <psapi.h>
#else
#include <unistd.h>
#endif

#if defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#endif

enum class DeviceMemoryClass
{
  Unknown,
  Low,
  Mid,
  High
};

struct BuildInfo
{
  bool valid = false;
  std::string commit;
  std::string branch;
  std::string buildType;
  std::string platform;
  std::string builtAt;
  std::string moonVersion;
  int buildNumber = 0;
};

template <typename... Args>
class Signal
{
public:
  using Listener = std::function<void(Args...)>;

  void add(Listener listener)
  {
    std::lock_guard<std::mutex> lock(mutex);
    listeners.push_back(std::move(listener));
  }

  void clear()
  {
    std::lock_guard<std::mutex> lock(mutex);
    listeners.clear();
  }

  void dispatch(Args... args)
  {
    std::vector<Listener> snapshot;

    {
      std::lock_guard<std::mutex> lock(mutex);
      snapshot = listeners;
    }

    for (auto &listener : snapshot) listener(args...);
  }

private:
  std::mutex mutex;
  std::vector<Listener> listeners;
};

static uint32_t crc32(const std::vector<uint8_t> &data)
{
  static const std::array<uint32_t, 256> table = []
  {
    std::array<uint32_t, 256> values{};

    for (uint32_t i = 0; i < 256; i++)
    {
      uint32_t c = i;

      for (int k = 0; k < 8; k++)
      {
        c = (c & 1u) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
      }

      values[i] = c;
    }

    return values;
  }();

  uint32_t crc = 0xFFFFFFFFu;

  for (uint8_t byte : data)
  {
    crc = table[(crc ^ byte) & 0xFFu] ^ (crc >> 8);
  }

  return crc ^ 0xFFFFFFFFu;
}

static std::string crc32Hex(const std::vector<uint8_t> &data)
{
  std::ostringstream out;
  out << std::hex << std::setw(8) << std::setfill('0') << crc32(data);
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

static std::string regexEscape(const std::string &input)
{
  static const std::string special = "\\^$.|?*+()[]{}";
  std::string output;

  for (char c : input)
  {
    if (special.find(c) != std::string::npos) output += '\\';

    output += c;
  }

  return output;
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

static bool readFileBytes(const std::filesystem::path &path, std::vector<uint8_t> &out)
{
  std::ifstream file(path, std::ios::binary);

  if (!file.is_open()) return false;

  out.assign(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());

  return true;
}

static bool readFileText(const std::filesystem::path &path, std::string &out)
{
  std::ifstream file(path, std::ios::binary);

  if (!file.is_open()) return false;

  std::ostringstream buffer;
  buffer << file.rdbuf();
  out = buffer.str();

  return true;
}

static bool extractJsonString(const std::string &json, const std::string &field, std::string &out)
{
  std::regex pattern("\"" + regexEscape(field) + "\"\\s*:\\s*\"([^\"]*)\"");
  std::smatch match;

  if (std::regex_search(json, match, pattern) && match.size() > 1)
  {
    out = match[1].str();
    return true;
  }

  return false;
}

static bool extractJsonInt(const std::string &json, const std::string &field, int &out)
{
  std::regex pattern("\"" + regexEscape(field) + "\"\\s*:\\s*(-?\\d+)");
  std::smatch match;

  if (std::regex_search(json, match, pattern) && match.size() > 1)
  {
    out = std::atoi(match[1].str().c_str());
    return true;
  }

  return false;
}

static uint64_t getProcessMemoryBytes()
{
#if defined(_WIN32)
  PROCESS_MEMORY_COUNTERS counters{};
  counters.cb = sizeof(counters);

  if (GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters)))
  {
    return static_cast<uint64_t>(counters.WorkingSetSize);
  }

  return 0;
#elif defined(__APPLE__)
  mach_task_basic_info_data_t info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;

  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS)
  {
    return static_cast<uint64_t>(info.resident_size);
  }

  return 0;
#else
  std::ifstream status("/proc/self/status");
  std::string line;

  while (std::getline(status, line))
  {
    if (line.rfind("VmRSS:", 0) == 0)
    {
      std::istringstream lineStream(line.substr(6));
      uint64_t kilobytes = 0;

      lineStream >> kilobytes;

      return kilobytes * 1024ull;
    }
  }

  return 0;
#endif
}

static uint64_t getTotalSystemMemoryBytes()
{
#if defined(_WIN32)
  MEMORYSTATUSEX status{};
  status.dwLength = sizeof(status);

  if (GlobalMemoryStatusEx(&status))
  {
    return static_cast<uint64_t>(status.ullTotalPhys);
  }

  return 0;
#elif defined(__APPLE__)
  uint64_t value = 0;
  size_t size = sizeof(value);

  if (sysctlbyname("hw.memsize", &value, &size, nullptr, 0) == 0)
  {
    return value;
  }

  return 0;
#else
  std::ifstream meminfo("/proc/meminfo");
  std::string line;

  while (std::getline(meminfo, line))
  {
    if (line.rfind("MemTotal:", 0) == 0)
    {
      std::istringstream lineStream(line.substr(9));
      uint64_t kilobytes = 0;

      lineStream >> kilobytes;

      return kilobytes * 1024ull;
    }
  }

  return 0;
#endif
}

class FunkinApp
{
public:
  static constexpr int MAX_UNCAUGHT_ERRORS_BEFORE_EXIT = 25;
  static constexpr int SAFE_MODE_ERROR_THRESHOLD = 5;
  static constexpr double SAFE_MODE_WINDOW_SECONDS = 3.0;
  static constexpr int MAX_GRAPHICS_CONTEXT_RETRIES = 3;
  static constexpr int GRAPHICS_CONTEXT_RETRY_DELAY_MS = 250;
  static constexpr double FREEZE_WATCHDOG_THRESHOLD_SECONDS = 5.0;
  static constexpr int MEMORY_POLL_INTERVAL_MS = 4000;
  static constexpr double MEMORY_PRESSURE_JUMP_MB = 96.0;
  static constexpr double EXIT_CONFIRM_WINDOW_SECONDS = 2.0;
  static constexpr int BACKGROUND_SAVE_DEBOUNCE_MS = 600;
  static constexpr uint64_t LOW_MEMORY_DEVICE_THRESHOLD_MB = 1536;
  static constexpr uint64_t MID_MEMORY_DEVICE_THRESHOLD_MB = 3072;

  static FunkinApp *instance;

  static bool safeMode;
  static DeviceMemoryClass deviceMemoryClass;
  static std::atomic<int> lowMemoryEventCount;
  static std::atomic<bool> isAppInForeground;
  static BuildInfo buildInfo;

  std::function<bool()> graphicsValidator = [] { return true; };
  std::function<void()> onCreateGame = [] {};
  std::function<void()> onLoadSave = [] {};
  std::function<void()> onFlushSave = [] {};
  std::function<void()> onStopAudio = [] {};
  std::function<void()> onPurgeCaches = [] {};
  std::function<bool()> onTick = [] { return true; };

  Signal<> onLowMemoryPressure;
  Signal<double> onFreezeDetected;
  Signal<> onEnterBackground;
  Signal<> onEnterForeground;

  std::filesystem::path buildInfoPath = "assets/preload/data/build-info.json";
  std::filesystem::path assetManifestPath = "assets/preload/data/asset-manifest.json";
  std::filesystem::path assetsRoot = "assets";
  std::filesystem::path crashDiagnosticsPath = "crash-diagnostics.json";
  std::vector<std::string> criticalIntegrityPaths = {"data/credits.json", "images/logoBumpin.png"};
  std::function<std::string(const std::vector<uint8_t> &)> checksumFunction = crc32Hex;

  FunkinApp()
  {
    instance = this;
  }

  ~FunkinApp()
  {
    if (instance == this) instance = nullptr;
  }

  int run()
  {
    installSignalHandlers();
    detectDeviceMemoryClass();

    try
    {
      initializeStages();
    }
    catch (const std::exception &e)
    {
      reportFatalStartupError(e.what());
      return 1;
    }

    touchFrameStamp();
    freezeWatchdogArmed = true;
    running = true;

    initializeMemoryPolling();
    initializeFreezeWatchdog();

    while (running.load() && !shuttingDown.load())
    {
      touchFrameStamp();

      if (interruptRequested.exchange(false)) requestExitConfirm();
      if (terminateRequested.load()) requestShutdown();

      bool keepRunning = true;

      try
      {
        keepRunning = onTick();
      }
      catch (const std::exception &e)
      {
        reportUncaughtError(e.what());
        keepRunning = uncaughtErrorCount < MAX_UNCAUGHT_ERRORS_BEFORE_EXIT;
      }
      catch (...)
      {
        reportUncaughtError("Unknown exception.");
        keepRunning = uncaughtErrorCount < MAX_UNCAUGHT_ERRORS_BEFORE_EXIT;
      }

      if (!keepRunning) requestShutdown();
    }

    shutdown();

    return 0;
  }

  void requestShutdown()
  {
    {
      std::lock_guard<std::mutex> lock(wakeMutex);
      running = false;
    }

    wakeCondition.notify_all();
  }

  void enterBackground()
  {
    isAppInForeground = false;
    onEnterBackground.dispatch();
    scheduleBackgroundSave();
  }

  void enterForeground()
  {
    isAppInForeground = true;
    touchFrameStamp();
    watchdogWarningIssued = false;
    onEnterForeground.dispatch();
  }

  void requestExitConfirm()
  {
    double now = nowSeconds();

    if ((now - lastExitRequestTime) <= EXIT_CONFIRM_WINDOW_SECONDS)
    {
      requestShutdown();
      return;
    }

    lastExitRequestTime = now;
    std::cout << "Press again within " << EXIT_CONFIRM_WINDOW_SECONDS << "s to exit." << std::endl;
  }

private:
  int uncaughtErrorCount = 0;
  std::deque<double> startupErrorTimestamps;
  std::map<std::string, double> stageTimings;
  bool assetIntegrityOk = true;
  int graphicsContextRetries = 0;
  double lastFrameStamp = 0.0;
  std::atomic<bool> freezeWatchdogArmed{false};
  std::atomic<bool> watchdogWarningIssued{false};
  double lastMemoryPollBytes = 0.0;
  double lastExitRequestTime = -1000.0;
  bool pendingBackgroundSave = false;
  bool saveWorkerActive = false;
  std::chrono::steady_clock::time_point saveDeadline;
  std::atomic<bool> shuttingDown{false};
  std::atomic<bool> running{false};
  std::mutex frameStampMutex;
  std::mutex wakeMutex;
  std::condition_variable wakeCondition;
  std::mutex saveMutex;
  std::condition_variable saveCondition;
  std::thread memoryPollThread;
  std::thread freezeWatchdogThread;
  std::thread backgroundSaveThread;

  static std::atomic<bool> interruptRequested;
  static std::atomic<bool> terminateRequested;

  static double nowSeconds()
  {
    static const auto start = std::chrono::steady_clock::now();
    return std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
  }

  void touchFrameStamp()
  {
    std::lock_guard<std::mutex> lock(frameStampMutex);
    lastFrameStamp = nowSeconds();
  }

  bool waitOrStop(int milliseconds)
  {
    std::unique_lock<std::mutex> lock(wakeMutex);

    wakeCondition.wait_for(lock, std::chrono::milliseconds(milliseconds), [this] { return !running.load() || shuttingDown.load(); });

    return running.load() && !shuttingDown.load();
  }

  void runStage(const std::string &name, const std::function<void()> &callback)
  {
    double start = nowSeconds();
    callback();
    stageTimings[name] = (nowSeconds() - start) * 1000.0;
  }

  void initializeStages()
  {
    runStage("logBuildInfo", [this] { logBuildInfo(); });
    runStage("checkAssetIntegrity", [this] { checkAssetIntegrity(); });
    runStage("attemptGraphicsValidation", [this] { attemptGraphicsValidation(); });
    runStage("loadSave", [this] { onLoadSave(); });
    runStage("createGame", [this] { onCreateGame(); });

    logStartupSummary();
  }

  void attemptGraphicsValidation()
  {
    while (!graphicsValidator())
    {
      graphicsContextRetries++;

      if (graphicsContextRetries >= MAX_GRAPHICS_CONTEXT_RETRIES)
      {
        throw std::runtime_error("Failed to initialize the rendering context after " + std::to_string(graphicsContextRetries) + " attempts.");
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(GRAPHICS_CONTEXT_RETRY_DELAY_MS));
    }
  }

  void logBuildInfo()
  {
    std::string raw;

    if (!readFileText(buildInfoPath, raw))
    {
      buildInfo = BuildInfo{};
      return;
    }

    BuildInfo info;
    info.valid = extractJsonString(raw, "commit", info.commit) || extractJsonString(raw, "branch", info.branch);

    extractJsonString(raw, "commit", info.commit);
    extractJsonString(raw, "branch", info.branch);
    extractJsonString(raw, "buildType", info.buildType);
    extractJsonString(raw, "platform", info.platform);
    extractJsonString(raw, "builtAt", info.builtAt);
    extractJsonString(raw, "moonVersion", info.moonVersion);
    extractJsonInt(raw, "buildNumber", info.buildNumber);

    buildInfo = info;

    if (buildInfo.valid)
    {
      std::cout << "Build: " << buildInfo.commit << " (" << buildInfo.branch << ") - " << buildInfo.buildType << " - built "
                << buildInfo.builtAt << std::endl;
    }
  }

  void checkAssetIntegrity()
  {
    std::string manifestJson;

    if (!readFileText(assetManifestPath, manifestJson))
    {
      assetIntegrityOk = true;
      return;
    }

    for (const auto &relativePath : criticalIntegrityPaths)
    {
      std::filesystem::path assetPath = assetsRoot / relativePath;

      std::string expectedHash;

      if (!extractJsonString(manifestJson, assetPath.generic_string(), expectedHash)) continue;

      std::vector<uint8_t> bytes;

      if (!readFileBytes(assetPath, bytes)) continue;

      std::string actualHash = checksumFunction(bytes);

      if (actualHash != expectedHash)
      {
        assetIntegrityOk = false;
        std::cerr << "Asset integrity mismatch for " << assetPath.string() << std::endl;
      }
    }

    if (!assetIntegrityOk)
    {
      std::cerr << "One or more critical assets failed integrity verification." << std::endl;
    }
  }

  void detectDeviceMemoryClass()
  {
    uint64_t totalBytes = getTotalSystemMemoryBytes();

    if (totalBytes == 0)
    {
      deviceMemoryClass = DeviceMemoryClass::Unknown;
      return;
    }

    uint64_t totalMb = totalBytes / (1024ull * 1024ull);

    if (totalMb <= LOW_MEMORY_DEVICE_THRESHOLD_MB)
    {
      deviceMemoryClass = DeviceMemoryClass::Low;
    }
    else if (totalMb <= MID_MEMORY_DEVICE_THRESHOLD_MB)
    {
      deviceMemoryClass = DeviceMemoryClass::Mid;
    }
    else
    {
      deviceMemoryClass = DeviceMemoryClass::High;
    }
  }

  void initializeMemoryPolling()
  {
    memoryPollThread = std::thread([this]
    {
      while (waitOrStop(MEMORY_POLL_INTERVAL_MS))
      {
        if (!isAppInForeground.load()) continue;

        pollMemoryUsage();
      }
    });
  }

  void pollMemoryUsage()
  {
    double currentBytes = static_cast<double>(getProcessMemoryBytes());
    double currentMb = currentBytes / (1024.0 * 1024.0);

    if (lastMemoryPollBytes > 0)
    {
      double deltaMb = currentMb - (lastMemoryPollBytes / (1024.0 * 1024.0));

      if (deltaMb >= MEMORY_PRESSURE_JUMP_MB)
      {
        onMemoryPressureDetected(currentMb, deltaMb);
      }
    }

    lastMemoryPollBytes = currentBytes;
  }

  void onMemoryPressureDetected(double currentMb, double deltaMb)
  {
    lowMemoryEventCount++;

    std::cerr << "Memory pressure detected: +" << static_cast<int>(deltaMb) << "MB in " << MEMORY_POLL_INTERVAL_MS << "ms, now ~"
              << static_cast<int>(currentMb) << "MB (#" << lowMemoryEventCount << ")." << std::endl;

    onPurgeCaches();
    onLowMemoryPressure.dispatch();
  }

  void initializeFreezeWatchdog()
  {
    freezeWatchdogThread = std::thread([this]
    {
      while (waitOrStop(500))
      {
        if (!freezeWatchdogArmed.load() || !isAppInForeground.load()) continue;

        double now = nowSeconds();
        double delta;

        {
          std::lock_guard<std::mutex> lock(frameStampMutex);
          delta = now - lastFrameStamp;
        }

        if (delta >= FREEZE_WATCHDOG_THRESHOLD_SECONDS && !watchdogWarningIssued.load())
        {
          watchdogWarningIssued = true;
          std::cerr << "Main loop appears stalled for " << delta << "s." << std::endl;
          onFreezeDetected.dispatch(delta);
        }
        else if (delta < FREEZE_WATCHDOG_THRESHOLD_SECONDS)
        {
          watchdogWarningIssued = false;
        }
      }
    });
  }

  void scheduleBackgroundSave()
  {
    std::lock_guard<std::mutex> lock(saveMutex);

    pendingBackgroundSave = true;
    saveDeadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(BACKGROUND_SAVE_DEBOUNCE_MS);

    if (saveWorkerActive)
    {
      saveCondition.notify_all();
      return;
    }

    if (backgroundSaveThread.joinable()) backgroundSaveThread.join();

    saveWorkerActive = true;

    backgroundSaveThread = std::thread([this]
    {
      std::unique_lock<std::mutex> workerLock(saveMutex);

      while (pendingBackgroundSave && !shuttingDown.load())
      {
        if (std::chrono::steady_clock::now() < saveDeadline)
        {
          saveCondition.wait_until(workerLock, saveDeadline);
          continue;
        }

        pendingBackgroundSave = false;

        workerLock.unlock();
        onFlushSave();
        workerLock.lock();
      }

      saveWorkerActive = false;
    });
  }

  void reportUncaughtError(const std::string &message)
  {
    uncaughtErrorCount++;

    double now = nowSeconds();
    startupErrorTimestamps.push_back(now);

    while (!startupErrorTimestamps.empty() && (now - startupErrorTimestamps.front()) > SAFE_MODE_WINDOW_SECONDS)
    {
      startupErrorTimestamps.pop_front();
    }

    std::cerr << "Uncaught error #" << uncaughtErrorCount << ": " << message << std::endl;

    if (!safeMode && static_cast<int>(startupErrorTimestamps.size()) >= SAFE_MODE_ERROR_THRESHOLD)
    {
      triggerSafeModeRestart(message);
      return;
    }

    if (uncaughtErrorCount >= MAX_UNCAUGHT_ERRORS_BEFORE_EXIT)
    {
      writeCrashDiagnostics(message);
    }
  }

  void triggerSafeModeRestart(const std::string &lastError)
  {
    safeMode = true;

    std::cerr << "Too many errors in a short window (" << SAFE_MODE_ERROR_THRESHOLD << " in " << SAFE_MODE_WINDOW_SECONDS
              << "s), entering safe mode." << std::endl;

    startupErrorTimestamps.clear();
  }

  void reportFatalStartupError(const std::string &message)
  {
    writeCrashDiagnostics(message);
    std::cerr << "Startup failed: " << message << std::endl;
  }

  void writeCrashDiagnostics(const std::string &lastError)
  {
    std::ostringstream json;

    json << "{\n";
    json << "  \"stageTimingsMs\": {\n";

    std::size_t index = 0;

    for (const auto &entry : stageTimings)
    {
      json << "    \"" << jsonEscape(entry.first) << "\": " << entry.second;
      index++;

      if (index < stageTimings.size()) json << ",";

      json << "\n";
    }

    json << "  },\n";
    json << "  \"uncaughtErrorCount\": " << uncaughtErrorCount << ",\n";
    json << "  \"safeModeTriggered\": " << (safeMode ? "true" : "false") << ",\n";
    json << "  \"assetIntegrityOk\": " << (assetIntegrityOk ? "true" : "false") << ",\n";
    json << "  \"deviceMemoryClass\": " << static_cast<int>(deviceMemoryClass) << ",\n";
    json << "  \"lowMemoryEventCount\": " << lowMemoryEventCount << ",\n";
    json << "  \"isAppInForeground\": " << (isAppInForeground.load() ? "true" : "false") << ",\n";
    json << "  \"lastError\": \"" << jsonEscape(lastError) << "\",\n";
    json << "  \"generatedAt\": \"" << jsonEscape(timestampIso()) << "\"\n";
    json << "}\n";

    std::ofstream file(crashDiagnosticsPath);

    if (file.is_open())
    {
      file << json.str();
      file.close();
    }
  }

  void logStartupSummary()
  {
    double totalMs = 0.0;

    for (const auto &entry : stageTimings) totalMs += entry.second;

    std::cout << "Startup complete in " << static_cast<int>(totalMs) << "ms across " << stageTimings.size() << " stage(s)." << std::endl;

    if (safeMode)
    {
      std::cerr << "Running in safe mode." << std::endl;
    }
  }

  void shutdown()
  {
    if (shuttingDown.exchange(true)) return;

    wakeCondition.notify_all();
    saveCondition.notify_all();

    if (memoryPollThread.joinable()) memoryPollThread.join();
    if (freezeWatchdogThread.joinable()) freezeWatchdogThread.join();
    if (backgroundSaveThread.joinable()) backgroundSaveThread.join();

    pendingBackgroundSave = false;
    onFlushSave();
    onStopAudio();
    onPurgeCaches();
  }

  void installSignalHandlers()
  {
    std::signal(SIGINT, &FunkinApp::staticInterruptHandler);
    std::signal(SIGTERM, &FunkinApp::staticTerminateHandler);
    std::signal(SIGSEGV, &FunkinApp::staticFatalSignalHandler);
    std::signal(SIGABRT, &FunkinApp::staticFatalSignalHandler);
    std::signal(SIGFPE, &FunkinApp::staticFatalSignalHandler);
    std::signal(SIGILL, &FunkinApp::staticFatalSignalHandler);
  }

  static void staticInterruptHandler(int sig)
  {
    interruptRequested.store(true);
    std::signal(sig, &FunkinApp::staticInterruptHandler);
  }

  static void staticTerminateHandler(int)
  {
    terminateRequested.store(true);
  }

  static void staticFatalSignalHandler(int sig)
  {
    static std::atomic<bool> handling{false};

    if (!handling.exchange(true) && instance != nullptr)
    {
      instance->writeCrashDiagnostics("Fatal signal " + std::to_string(sig));
    }

    std::signal(sig, SIG_DFL);
    std::raise(sig);
  }
};

FunkinApp *FunkinApp::instance = nullptr;
bool FunkinApp::safeMode = false;
DeviceMemoryClass FunkinApp::deviceMemoryClass = DeviceMemoryClass::Unknown;
std::atomic<int> FunkinApp::lowMemoryEventCount{0};
std::atomic<bool> FunkinApp::isAppInForeground{true};
std::atomic<bool> FunkinApp::interruptRequested{false};
std::atomic<bool> FunkinApp::terminateRequested{false};
BuildInfo FunkinApp::buildInfo{};

int main()
{
  FunkinApp app;

  int frameCount = 0;

  app.onCreateGame = []
  {
    std::cout << "Game created. Running headless tick loop." << std::endl;
  };

  app.onTick = [&frameCount]
  {
    frameCount++;
    std::this_thread::sleep_for(std::chrono::milliseconds(16));
    return frameCount < 300;
  };

  app.onFlushSave = [] { std::cout << "Flushing save data." << std::endl; };
  app.onStopAudio = [] { std::cout << "Stopping audio." << std::endl; };
  app.onPurgeCaches = [] { std::cout << "Purging caches." << std::endl; };

  return app.run();
}

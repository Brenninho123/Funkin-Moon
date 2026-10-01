#include "videoenc.hpp"

#ifdef _WIN32

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <objbase.h>
#include <propidl.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mferror.h>
#include <mfreadwrite.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <audioclientactivationparams.h>
#include <atomic>
#include <algorithm>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace
{
struct Frame
{
  std::vector<uint8_t> pixels;
  int width = 0;
  int height = 0;
  bool rgba = false;
  int64_t index = 0;
  int repeat = 1;
};

class ActivationHandler : public IActivateAudioInterfaceCompletionHandler, public IAgileObject
{
public:
  ActivationHandler()
  {
    done = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  }

  ~ActivationHandler()
  {
    if (done != nullptr) CloseHandle(done);
    if (client != nullptr) client->Release();
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **object) override
  {
    if (riid == __uuidof(IUnknown) || riid == __uuidof(IActivateAudioInterfaceCompletionHandler))
    {
      *object = static_cast<IActivateAudioInterfaceCompletionHandler *>(this);
    }
    else if (riid == __uuidof(IAgileObject))
    {
      *object = static_cast<IAgileObject *>(this);
    }
    else
    {
      *object = nullptr;
      return E_NOINTERFACE;
    }

    AddRef();
    return S_OK;
  }

  ULONG STDMETHODCALLTYPE AddRef() override
  {
    return static_cast<ULONG>(InterlockedIncrement(&references));
  }

  ULONG STDMETHODCALLTYPE Release() override
  {
    ULONG count = static_cast<ULONG>(InterlockedDecrement(&references));
    if (count == 0) delete this;
    return count;
  }

  HRESULT STDMETHODCALLTYPE ActivateCompleted(IActivateAudioInterfaceAsyncOperation *operation) override
  {
    HRESULT activateResult = E_FAIL;
    IUnknown *unknown = nullptr;

    HRESULT hr = operation->GetActivateResult(&activateResult, &unknown);

    if (SUCCEEDED(hr) && SUCCEEDED(activateResult) && unknown != nullptr)
    {
      unknown->QueryInterface(__uuidof(IAudioClient), reinterpret_cast<void **>(&client));
    }

    if (unknown != nullptr) unknown->Release();

    SetEvent(done);
    return S_OK;
  }

  HANDLE done = nullptr;
  IAudioClient *client = nullptr;

private:
  LONG references = 1;
};

struct Recorder
{
  IMFSinkWriter *writer = nullptr;
  DWORD videoStream = 0;
  DWORD audioStream = 0;
  int width = 0;
  int height = 0;
  int fps = 60;
  bool hasAudio = false;
  std::string audioKind = "none";
  std::mutex writerMutex;

  std::mutex queueMutex;
  std::condition_variable queueSignal;
  std::deque<Frame> queue;
  bool stopping = false;
  std::thread videoThread;
  std::atomic<int> videoFrames{0};
  std::atomic<bool> failed{false};

  std::thread audioThread;
  std::atomic<bool> audioStop{false};
  IAudioClient *audioClient = nullptr;
  IAudioCaptureClient *capture = nullptr;
  HANDLE audioEvent = nullptr;
  int audioRate = 48000;
  int captureChannels = 2;
  int captureBits = 16;
  bool captureFloat = false;
  bool systemLoopback = false;
  bool useEvent = false;
  LARGE_INTEGER qpcStart{};
  LARGE_INTEGER qpcFrequency{};
  int64_t audioSamples = 0;

  std::wstring path;
  bool comStarted = false;
  bool mediaStarted = false;
};

Recorder *gRecorder = nullptr;
std::mutex gMutex;
std::string gError;
std::string gResult;

void setError(const std::string &message, HRESULT hr = S_OK)
{
  char code[32] = {0};

  if (FAILED(hr)) snprintf(code, sizeof(code), " (0x%08lX)", static_cast<unsigned long>(hr));

  gError = message + code;
}

std::wstring widen(const char *text)
{
  int length = MultiByteToWideChar(CP_UTF8, 0, text, -1, nullptr, 0);

  if (length <= 0) return std::wstring();

  std::wstring result(static_cast<size_t>(length), L'\0');

  MultiByteToWideChar(CP_UTF8, 0, text, -1, &result[0], length);

  if (!result.empty() && result.back() == L'\0') result.pop_back();

  return result;
}

template <typename T> void release(T *&pointer)
{
  if (pointer != nullptr)
  {
    pointer->Release();
    pointer = nullptr;
  }
}

double elapsedSeconds(const Recorder &recorder)
{
  LARGE_INTEGER now;

  QueryPerformanceCounter(&now);

  return static_cast<double>(now.QuadPart - recorder.qpcStart.QuadPart) / static_cast<double>(recorder.qpcFrequency.QuadPart);
}

bool writeAudio(Recorder &recorder, const BYTE *data, int sampleCount)
{
  if (sampleCount <= 0) return true;

  DWORD bytes = static_cast<DWORD>(sampleCount) * 4;
  IMFMediaBuffer *buffer = nullptr;
  IMFSample *sample = nullptr;

  if (FAILED(MFCreateMemoryBuffer(bytes, &buffer))) return false;

  BYTE *target = nullptr;

  if (FAILED(buffer->Lock(&target, nullptr, nullptr)))
  {
    buffer->Release();
    return false;
  }

  if (data != nullptr) memcpy(target, data, bytes);
  else memset(target, 0, bytes);

  buffer->Unlock();
  buffer->SetCurrentLength(bytes);

  if (FAILED(MFCreateSample(&sample)))
  {
    buffer->Release();
    return false;
  }

  sample->AddBuffer(buffer);
  sample->SetSampleTime(recorder.audioSamples * 10000000LL / recorder.audioRate);
  sample->SetSampleDuration(static_cast<LONGLONG>(sampleCount) * 10000000LL / recorder.audioRate);

  HRESULT hr;

  {
    std::lock_guard<std::mutex> lock(recorder.writerMutex);
    hr = recorder.writer->WriteSample(recorder.audioStream, sample);
  }

  sample->Release();
  buffer->Release();

  recorder.audioSamples += sampleCount;

  return SUCCEEDED(hr);
}

void convertToStereo16(const Recorder &recorder, const BYTE *data, UINT32 frames, std::vector<int16_t> &output)
{
  output.resize(static_cast<size_t>(frames) * 2);

  int channels = std::max(1, recorder.captureChannels);

  for (UINT32 i = 0; i < frames; i++)
  {
    float left = 0.0f;
    float right = 0.0f;

    for (int c = 0; c < channels; c++)
    {
      float value;

      if (recorder.captureFloat)
      {
        value = reinterpret_cast<const float *>(data)[i * channels + c];
      }
      else
      {
        value = reinterpret_cast<const int16_t *>(data)[i * channels + c] / 32768.0f;
      }

      if (c == 0 || c % 2 == 0) left += value;
      if (c == 1 || c % 2 == 1) right += value;
    }

    if (channels == 1) right = left;

    int perSide = std::max(1, (channels + 1) / 2);

    left = std::max(-1.0f, std::min(1.0f, left / static_cast<float>(perSide)));
    right = std::max(-1.0f, std::min(1.0f, right / static_cast<float>(perSide)));

    output[i * 2] = static_cast<int16_t>(left * 32767.0f);
    output[i * 2 + 1] = static_cast<int16_t>(right * 32767.0f);
  }
}

void audioLoop(Recorder *recorder)
{
  HRESULT comResult = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  std::vector<int16_t> converted;

  while (!recorder->audioStop.load())
  {
    WaitForSingleObject(recorder->audioEvent, 10);

    UINT32 packet = 0;

    while (SUCCEEDED(recorder->capture->GetNextPacketSize(&packet)) && packet > 0)
    {
      BYTE *data = nullptr;
      UINT32 frames = 0;
      DWORD flags = 0;

      if (FAILED(recorder->capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr))) break;

      if (frames > 0)
      {
        if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0 || data == nullptr)
        {
          writeAudio(*recorder, nullptr, static_cast<int>(frames));
        }
        else if (!recorder->systemLoopback)
        {
          writeAudio(*recorder, data, static_cast<int>(frames));
        }
        else
        {
          convertToStereo16(*recorder, data, frames, converted);
          writeAudio(*recorder, reinterpret_cast<const BYTE *>(converted.data()), static_cast<int>(frames));
        }
      }

      recorder->capture->ReleaseBuffer(frames);
    }

    int64_t wanted = static_cast<int64_t>(elapsedSeconds(*recorder) * recorder->audioRate);
    int64_t missing = wanted - recorder->audioSamples;

    while (missing > recorder->audioRate / 50)
    {
      int chunk = static_cast<int>(std::min<int64_t>(missing, recorder->audioRate));

      if (!writeAudio(*recorder, nullptr, chunk)) break;

      missing -= chunk;
    }
  }

  if (SUCCEEDED(comResult)) CoUninitialize();
}

std::string gAudioNote;

IAudioClient *activateProcessClient(std::string &note)
{
  AUDIOCLIENT_ACTIVATION_PARAMS params = {};

  params.ActivationType = AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  params.ProcessLoopbackParams.TargetProcessId = GetCurrentProcessId();
  params.ProcessLoopbackParams.ProcessLoopbackMode = PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE;

  PROPVARIANT activation = {};

  activation.vt = VT_BLOB;
  activation.blob.cbSize = sizeof(params);
  activation.blob.pBlobData = reinterpret_cast<BYTE *>(&params);

  ActivationHandler *handler = new ActivationHandler();
  IActivateAudioInterfaceAsyncOperation *operation = nullptr;

  HRESULT hr = ActivateAudioInterfaceAsync(VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK, __uuidof(IAudioClient), &activation, handler, &operation);

  if (FAILED(hr))
  {
    char code[64];

    snprintf(code, sizeof(code), "activation 0x%08lX", static_cast<unsigned long>(hr));
    note = code;
    handler->Release();
    return nullptr;
  }

  WaitForSingleObject(handler->done, 5000);

  IAudioClient *client = handler->client;

  if (client != nullptr) client->AddRef();

  release(operation);
  handler->Release();

  if (client == nullptr) note = "activation returned no client";

  return client;
}

bool startProcessLoopback(Recorder &recorder)
{
  WAVEFORMATEX format = {};

  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = 2;
  format.nSamplesPerSec = 48000;
  format.wBitsPerSample = 16;
  format.nBlockAlign = 4;
  format.nAvgBytesPerSec = 48000 * 4;

  struct Attempt
  {
    DWORD flags;
    REFERENCE_TIME duration;
    REFERENCE_TIME period;
    bool event;
  };

  const Attempt attempts[] = {
    {AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK | AUDCLNT_STREAMFLAGS_NOPERSIST, 200000, AUDCLNT_STREAMFLAGS_LOOPBACK, true},
    {AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 0, 0, true},
    {AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 200000, 0, true},
    {AUDCLNT_STREAMFLAGS_LOOPBACK, 200000, 0, false},
    {AUDCLNT_STREAMFLAGS_LOOPBACK, 0, 0, false},
    {AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY, 200000, 0, false},
  };

  std::string note;

  for (const Attempt &attempt : attempts)
  {
    IAudioClient *client = activateProcessClient(note);

    if (client == nullptr) return false;

    HRESULT hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED, attempt.flags, attempt.duration, attempt.period, &format, nullptr);

    if (FAILED(hr))
    {
      char code[64];

      snprintf(code, sizeof(code), "initialize 0x%08lX", static_cast<unsigned long>(hr));
      note = code;
      client->Release();

      continue;
    }

    recorder.audioClient = client;
    recorder.audioRate = 48000;
    recorder.captureChannels = 2;
    recorder.captureBits = 16;
    recorder.captureFloat = false;
    recorder.systemLoopback = false;
    recorder.useEvent = attempt.event;
    recorder.audioKind = "game";

    return true;
  }

  gAudioNote = note;

  return false;
}

bool startSystemLoopback(Recorder &recorder)
{
  IMMDeviceEnumerator *enumerator = nullptr;
  IMMDevice *device = nullptr;
  IAudioClient *client = nullptr;
  WAVEFORMATEX *mix = nullptr;

  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, __uuidof(IMMDeviceEnumerator), reinterpret_cast<void **>(&enumerator));

  if (FAILED(hr)) return false;

  hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  release(enumerator);

  if (FAILED(hr)) return false;

  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, reinterpret_cast<void **>(&client));
  release(device);

  if (FAILED(hr)) return false;

  hr = client->GetMixFormat(&mix);

  if (FAILED(hr) || mix == nullptr)
  {
    client->Release();
    return false;
  }

  bool isFloat = mix->wFormatTag == WAVE_FORMAT_IEEE_FLOAT;

  if (mix->wFormatTag == WAVE_FORMAT_EXTENSIBLE && mix->cbSize >= 22)
  {
    const WAVEFORMATEXTENSIBLE *extensible = reinterpret_cast<const WAVEFORMATEXTENSIBLE *>(mix);

    isFloat = extensible->SubFormat.Data1 == WAVE_FORMAT_IEEE_FLOAT;
  }

  if ((isFloat && mix->wBitsPerSample != 32) || (!isFloat && mix->wBitsPerSample != 16))
  {
    CoTaskMemFree(mix);
    client->Release();
    return false;
  }

  hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK, 200000, 0, mix, nullptr);

  if (FAILED(hr))
  {
    CoTaskMemFree(mix);
    client->Release();
    return false;
  }

  recorder.audioClient = client;
  recorder.audioRate = static_cast<int>(mix->nSamplesPerSec);
  recorder.captureChannels = mix->nChannels;
  recorder.captureBits = mix->wBitsPerSample;
  recorder.captureFloat = isFloat;
  recorder.systemLoopback = true;
  recorder.audioKind = "system";

  CoTaskMemFree(mix);

  return true;
}

bool startAudioCapture(Recorder &recorder)
{
  if (!startProcessLoopback(recorder) && !startSystemLoopback(recorder)) return false;

  recorder.audioEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);

  bool eventFailed = recorder.useEvent && recorder.audioEvent != nullptr && FAILED(recorder.audioClient->SetEventHandle(recorder.audioEvent));

  if (recorder.audioEvent == nullptr || eventFailed ||
      FAILED(recorder.audioClient->GetService(__uuidof(IAudioCaptureClient), reinterpret_cast<void **>(&recorder.capture))))
  {
    release(recorder.capture);
    release(recorder.audioClient);

    if (recorder.audioEvent != nullptr)
    {
      CloseHandle(recorder.audioEvent);
      recorder.audioEvent = nullptr;
    }

    return false;
  }

  return true;
}

bool configureWriter(Recorder &recorder, bool hardware, int bitrateKbps)
{
  IMFAttributes *attributes = nullptr;

  if (FAILED(MFCreateAttributes(&attributes, 4))) return false;

  attributes->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, hardware ? TRUE : FALSE);
  attributes->SetUINT32(MF_SINK_WRITER_DISABLE_THROTTLING, TRUE);
  attributes->SetGUID(MF_TRANSCODE_CONTAINERTYPE, MFTranscodeContainerType_MPEG4);

  HRESULT hr = MFCreateSinkWriterFromURL(recorder.path.c_str(), nullptr, attributes, &recorder.writer);

  release(attributes);

  if (FAILED(hr))
  {
    setError("Could not create the video file", hr);
    return false;
  }

  IMFMediaType *videoOut = nullptr;

  MFCreateMediaType(&videoOut);
  videoOut->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  videoOut->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
  videoOut->SetUINT32(MF_MT_AVG_BITRATE, static_cast<UINT32>(bitrateKbps) * 1000);
  videoOut->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
  videoOut->SetUINT32(MF_MT_MPEG2_PROFILE, 100);
  MFSetAttributeSize(videoOut, MF_MT_FRAME_SIZE, static_cast<UINT32>(recorder.width), static_cast<UINT32>(recorder.height));
  MFSetAttributeRatio(videoOut, MF_MT_FRAME_RATE, static_cast<UINT32>(recorder.fps), 1);
  MFSetAttributeRatio(videoOut, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);

  hr = recorder.writer->AddStream(videoOut, &recorder.videoStream);
  release(videoOut);

  if (FAILED(hr))
  {
    setError("The H.264 encoder is not available", hr);
    release(recorder.writer);
    return false;
  }

  IMFMediaType *videoIn = nullptr;

  MFCreateMediaType(&videoIn);
  videoIn->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  videoIn->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
  videoIn->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
  videoIn->SetUINT32(MF_MT_DEFAULT_STRIDE, static_cast<UINT32>(recorder.width * 4));
  MFSetAttributeSize(videoIn, MF_MT_FRAME_SIZE, static_cast<UINT32>(recorder.width), static_cast<UINT32>(recorder.height));
  MFSetAttributeRatio(videoIn, MF_MT_FRAME_RATE, static_cast<UINT32>(recorder.fps), 1);
  MFSetAttributeRatio(videoIn, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);

  hr = recorder.writer->SetInputMediaType(recorder.videoStream, videoIn, nullptr);
  release(videoIn);

  if (FAILED(hr))
  {
    setError("The video format is not accepted by the encoder", hr);
    release(recorder.writer);
    return false;
  }

  if (recorder.hasAudio)
  {
    IMFMediaType *audioOut = nullptr;

    MFCreateMediaType(&audioOut);
    audioOut->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    audioOut->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
    audioOut->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    audioOut->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, static_cast<UINT32>(recorder.audioRate));
    audioOut->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 2);
    audioOut->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, 24000);
    audioOut->SetUINT32(MF_MT_AAC_PAYLOAD_TYPE, 0);
    audioOut->SetUINT32(MF_MT_AAC_AUDIO_PROFILE_LEVEL_INDICATION, 0x29);

    hr = recorder.writer->AddStream(audioOut, &recorder.audioStream);
    release(audioOut);

    if (SUCCEEDED(hr))
    {
      IMFMediaType *audioIn = nullptr;

      MFCreateMediaType(&audioIn);
      audioIn->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
      audioIn->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
      audioIn->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
      audioIn->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, static_cast<UINT32>(recorder.audioRate));
      audioIn->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 2);
      audioIn->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, 4);
      audioIn->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, static_cast<UINT32>(recorder.audioRate) * 4);

      hr = recorder.writer->SetInputMediaType(recorder.audioStream, audioIn, nullptr);
      release(audioIn);
    }

    if (FAILED(hr))
    {
      recorder.hasAudio = false;
      recorder.audioKind = "none";
      release(recorder.writer);

      return false;
    }
  }

  hr = recorder.writer->BeginWriting();

  if (FAILED(hr))
  {
    setError("The encoder could not start", hr);
    release(recorder.writer);
    return false;
  }

  return true;
}

void copyFrame(const Recorder &recorder, const Frame &frame, BYTE *target)
{
  int width = recorder.width;
  int height = recorder.height;

  if (frame.width != width || frame.height != height) memset(target, 0, static_cast<size_t>(width) * height * 4);

  int copyWidth = std::min(width, frame.width);
  int copyHeight = std::min(height, frame.height);

  for (int y = 0; y < copyHeight; y++)
  {
    const uint8_t *source = frame.pixels.data() + static_cast<size_t>(y) * frame.width * 4;
    BYTE *destination = target + static_cast<size_t>(y) * width * 4;

    if (frame.rgba)
    {
      for (int x = 0; x < copyWidth; x++)
      {
        destination[x * 4] = source[x * 4 + 2];
        destination[x * 4 + 1] = source[x * 4 + 1];
        destination[x * 4 + 2] = source[x * 4];
        destination[x * 4 + 3] = 0xFF;
      }
    }
    else
    {
      memcpy(destination, source, static_cast<size_t>(copyWidth) * 4);
    }
  }
}

void videoLoop(Recorder *recorder)
{
  HRESULT comResult = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  for (;;)
  {
    Frame frame;

    {
      std::unique_lock<std::mutex> lock(recorder->queueMutex);

      recorder->queueSignal.wait(lock, [recorder] { return !recorder->queue.empty() || recorder->stopping; });

      if (recorder->queue.empty()) break;

      frame = std::move(recorder->queue.front());
      recorder->queue.pop_front();
    }

    DWORD bytes = static_cast<DWORD>(recorder->width) * static_cast<DWORD>(recorder->height) * 4;
    IMFMediaBuffer *buffer = nullptr;
    IMFSample *sample = nullptr;

    if (FAILED(MFCreateMemoryBuffer(bytes, &buffer)))
    {
      recorder->failed = true;
      continue;
    }

    BYTE *target = nullptr;

    if (FAILED(buffer->Lock(&target, nullptr, nullptr)))
    {
      buffer->Release();
      recorder->failed = true;
      continue;
    }

    copyFrame(*recorder, frame, target);

    buffer->Unlock();
    buffer->SetCurrentLength(bytes);

    if (FAILED(MFCreateSample(&sample)))
    {
      buffer->Release();
      recorder->failed = true;
      continue;
    }

    sample->AddBuffer(buffer);
    sample->SetSampleTime(frame.index * 10000000LL / recorder->fps);
    sample->SetSampleDuration(static_cast<LONGLONG>(frame.repeat) * 10000000LL / recorder->fps);

    HRESULT hr;

    {
      std::lock_guard<std::mutex> lock(recorder->writerMutex);
      hr = recorder->writer->WriteSample(recorder->videoStream, sample);
    }

    if (FAILED(hr)) recorder->failed = true;
    else recorder->videoFrames += frame.repeat;

    sample->Release();
    buffer->Release();
  }

  if (SUCCEEDED(comResult)) CoUninitialize();
}

void cleanup(Recorder *recorder)
{
  release(recorder->capture);
  release(recorder->audioClient);

  if (recorder->audioEvent != nullptr) CloseHandle(recorder->audioEvent);

  release(recorder->writer);

  if (recorder->mediaStarted) MFShutdown();
  if (recorder->comStarted) CoUninitialize();

  delete recorder;
}
} // namespace

bool VIDEOENC_Start(const char *path, int width, int height, int fps, int bitrateKbps, bool wantAudio)
{
  std::lock_guard<std::mutex> lock(gMutex);

  gError.clear();
  gAudioNote.clear();

  if (gRecorder != nullptr)
  {
    setError("A recording is already running");
    return false;
  }

  Recorder *recorder = new Recorder();

  recorder->width = width & ~1;
  recorder->height = height & ~1;
  recorder->fps = std::max(1, fps);
  recorder->path = widen(path);

  if (recorder->width < 16 || recorder->height < 16)
  {
    setError("The window is too small to record");
    delete recorder;
    return false;
  }

  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  recorder->comStarted = SUCCEEDED(hr);

  hr = MFStartup(MF_VERSION, MFSTARTUP_FULL);

  if (FAILED(hr))
  {
    setError("Media Foundation is not available", hr);
    cleanup(recorder);
    return false;
  }

  recorder->mediaStarted = true;

  QueryPerformanceFrequency(&recorder->qpcFrequency);

  recorder->hasAudio = wantAudio && startAudioCapture(*recorder);

  const char *forceSoftware = getenv("MOON_VIDEO_SOFTWARE");
  bool ready = configureWriter(*recorder, forceSoftware == nullptr || forceSoftware[0] == '0', bitrateKbps);

  if (!ready)
  {
    bool audioWasOn = recorder->hasAudio;

    ready = configureWriter(*recorder, false, bitrateKbps);

    if (!ready && audioWasOn && !recorder->hasAudio)
    {
      ready = configureWriter(*recorder, false, bitrateKbps);
    }
  }

  if (!ready)
  {
    if (gError.empty()) setError("The video file could not be prepared");

    cleanup(recorder);

    return false;
  }

  QueryPerformanceCounter(&recorder->qpcStart);

  recorder->videoThread = std::thread(videoLoop, recorder);

  if (recorder->hasAudio)
  {
    if (FAILED(recorder->audioClient->Start()))
    {
      recorder->hasAudio = false;
      recorder->audioKind = "none";
    }
    else
    {
      recorder->audioThread = std::thread(audioLoop, recorder);
    }
  }

  gRecorder = recorder;

  return true;
}

bool VIDEOENC_WriteFrame(const unsigned char *pixels, int width, int height, bool rgba, int startIndex, int repeat)
{
  Recorder *recorder = gRecorder;

  if (recorder == nullptr || pixels == nullptr || width <= 0 || height <= 0 || recorder->failed.load()) return false;

  Frame frame;

  frame.pixels.assign(pixels, pixels + static_cast<size_t>(width) * height * 4);
  frame.width = width;
  frame.height = height;
  frame.rgba = rgba;
  frame.index = startIndex;
  frame.repeat = std::max(1, repeat);

  {
    std::lock_guard<std::mutex> lock(recorder->queueMutex);

    if (recorder->stopping) return false;

    recorder->queue.push_back(std::move(frame));
  }

  recorder->queueSignal.notify_one();

  return true;
}

int VIDEOENC_QueuedFrames()
{
  Recorder *recorder = gRecorder;

  if (recorder == nullptr) return 0;

  std::lock_guard<std::mutex> lock(recorder->queueMutex);

  return static_cast<int>(recorder->queue.size());
}

bool VIDEOENC_HasAudio()
{
  Recorder *recorder = gRecorder;

  return recorder != nullptr && recorder->hasAudio;
}

const char *VIDEOENC_AudioKind()
{
  Recorder *recorder = gRecorder;

  gResult = recorder != nullptr ? recorder->audioKind : "none";

  if (!gAudioNote.empty()) gResult += " (game audio: " + gAudioNote + ")";

  return gResult.c_str();
}

const char *VIDEOENC_Stop()
{
  std::lock_guard<std::mutex> lock(gMutex);

  Recorder *recorder = gRecorder;

  if (recorder == nullptr)
  {
    gResult = "error:nothing is being recorded";
    return gResult.c_str();
  }

  gRecorder = nullptr;

  {
    std::lock_guard<std::mutex> queueLock(recorder->queueMutex);
    recorder->stopping = true;
  }

  recorder->queueSignal.notify_all();

  if (recorder->videoThread.joinable()) recorder->videoThread.join();

  recorder->audioStop = true;

  if (recorder->audioThread.joinable()) recorder->audioThread.join();

  if (recorder->audioClient != nullptr) recorder->audioClient->Stop();

  if (recorder->hasAudio)
  {
    int64_t wanted = static_cast<int64_t>(elapsedSeconds(*recorder) * recorder->audioRate);
    int64_t missing = wanted - recorder->audioSamples;

    while (missing > 0)
    {
      int chunk = static_cast<int>(std::min<int64_t>(missing, recorder->audioRate));

      if (!writeAudio(*recorder, nullptr, chunk)) break;

      missing -= chunk;
    }
  }

  HRESULT hr;

  {
    std::lock_guard<std::mutex> writerLock(recorder->writerMutex);
    hr = recorder->writer->Finalize();
  }

  int frames = recorder->videoFrames.load();
  bool failed = recorder->failed.load();
  bool audio = recorder->hasAudio;

  WIN32_FILE_ATTRIBUTE_DATA info = {};
  long long bytes = 0;

  if (GetFileAttributesExW(recorder->path.c_str(), GetFileExInfoStandard, &info))
  {
    bytes = (static_cast<long long>(info.nFileSizeHigh) << 32) | info.nFileSizeLow;
  }

  cleanup(recorder);

  if (FAILED(hr))
  {
    setError("The video file could not be finished", hr);
    gResult = "error:" + gError;
    return gResult.c_str();
  }

  char text[128];

  snprintf(text, sizeof(text), "%d|%lld|1|%d|%d", frames, bytes, audio ? 1 : 0, failed ? 1 : 0);

  gResult = text;

  return gResult.c_str();
}

const char *VIDEOENC_LastError()
{
  return gError.c_str();
}

#else

bool VIDEOENC_Start(const char *, int, int, int, int, bool)
{
  return false;
}

bool VIDEOENC_WriteFrame(const unsigned char *, int, int, bool, int, int)
{
  return false;
}

int VIDEOENC_QueuedFrames()
{
  return 0;
}

bool VIDEOENC_HasAudio()
{
  return false;
}

const char *VIDEOENC_AudioKind()
{
  return "none";
}

const char *VIDEOENC_Stop()
{
  return "error:not supported";
}

const char *VIDEOENC_LastError()
{
  return "not supported";
}

#endif

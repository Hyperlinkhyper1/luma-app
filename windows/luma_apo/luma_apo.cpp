// luma's system-wide microphone EQ: an Audio Processing Object that the
// Windows audio engine (audiodg) loads onto a capture endpoint, so every app
// recording from that mic, Discord included, hears the luma curve.
// No virtual cable and no kernel driver needed.
//
// luma_apo_setup.exe registers it (see setup.cpp). The curve comes from
// eq.bin under %ProgramData%\luma\apo, written by the unelevated app and
// hot-reloaded here by a watcher thread; the real-time thread only ever
// picks up a finished snapshot through a sequence lock.
//
// The same watcher also writes alive.bin next to eq.bin: a count of frames
// processed, which is how the installer proves Windows really runs the EQ
// on the mic before it leaves it attached.

#include <windows.h>

#include <audioenginebaseapo.h>
#include <shlobj.h>

#include <atomic>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <new>

#include "apo_ids.h"
#include "eq_config.h"
#include "eq_dsp.h"

namespace luma_apo {

#ifdef LUMA_APO_TESTING
// Lets apo_test point the watcher at a scratch file.
wchar_t g_config_path_override[MAX_PATH] = {};
#endif

namespace {

std::atomic<long> g_objects{0};
std::atomic<long> g_locks{0};

// Frames every instance in this audiodg has processed; only ever bumped on
// the real-time thread and read by the watcher.
std::atomic<uint64_t> g_frames{0};

// {00000003-0000-0010-8000-00aa00389b71}
constexpr GUID kSubtypeIeeeFloat = {
    0x00000003, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}};

// ---------------------------------------------------------------------------
// The curve file, shared by every APO instance in the process.

bool ConfigPath(wchar_t* out, size_t capacity) {
#ifdef LUMA_APO_TESTING
  if (g_config_path_override[0] != 0) {
    return wcscpy_s(out, capacity, g_config_path_override) == 0;
  }
#endif
  PWSTR program_data = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_ProgramData, 0, nullptr,
                                  &program_data))) {
    return false;
  }
  const bool ok =
      wcscpy_s(out, capacity, program_data) == 0 &&
      wcscat_s(out, capacity, L"\\luma\\apo\\eq.bin") == 0;
  CoTaskMemFree(program_data);
  return ok;
}

class SharedConfig {
 public:
  static SharedConfig& Instance() {
    static SharedConfig instance;
    return instance;
  }

  void Acquire() {
    AcquireSRWLockExclusive(&lock_);
    if (users_++ == 0) {
      if (!ConfigPath(path_, MAX_PATH)) path_[0] = 0;
      HeartbeatPath(path_, alive_path_, MAX_PATH);
      written_frames_ = ~0ull;
      has_stamp_ = false;
      Poll();
      stop_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
      thread_ = stop_ ? CreateThread(nullptr, 0, &Watch, this, 0, nullptr)
                      : nullptr;
    }
    ReleaseSRWLockExclusive(&lock_);
  }

  void Release() {
    AcquireSRWLockExclusive(&lock_);
    if (users_ > 0 && --users_ == 0) {
      if (thread_) {
        SetEvent(stop_);
        WaitForSingleObject(thread_, 2000);
        CloseHandle(thread_);
        thread_ = nullptr;
      }
      if (stop_) {
        CloseHandle(stop_);
        stop_ = nullptr;
      }
    }
    ReleaseSRWLockExclusive(&lock_);
  }

  uint32_t sequence() const { return seq_.load(std::memory_order_acquire); }

  // Real-time safe: copies the snapshot published under [expected], or
  // returns false if a write is in progress or has since replaced it.
  bool Read(uint32_t expected, Config* out) const {
    if (expected & 1) return false;
    std::memcpy(out, &config_, sizeof(Config));
    std::atomic_thread_fence(std::memory_order_acquire);
    return seq_.load(std::memory_order_relaxed) == expected;
  }

 private:
  static DWORD WINAPI Watch(LPVOID param) {
    auto* self = static_cast<SharedConfig*>(param);
    for (unsigned tick = 0;
         WaitForSingleObject(self->stop_, 100) == WAIT_TIMEOUT; tick++) {
      self->Poll();
      if (tick % 3 == 0) self->Beat();
    }
    self->Beat();
    return 0;
  }

  static void HeartbeatPath(const wchar_t* config, wchar_t* out,
                            size_t capacity) {
    out[0] = 0;
    const wchar_t* slash = wcsrchr(config, L'\\');
    if (slash == nullptr) return;
    const size_t dir = size_t(slash - config) + 1;
    if (dir + 10 > capacity) return;
    wcsncpy_s(out, capacity, config, dir);
    wcscat_s(out, capacity, L"alive.bin");
  }

  // Off the real-time thread, and only when the count moved, so an idle mic
  // costs no disk writes.
  void Beat() {
    if (alive_path_[0] == 0) return;
    const uint64_t frames = g_frames.load(std::memory_order_relaxed);
    if (frames == written_frames_) return;
    HANDLE file = CreateFileW(alive_path_, GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_DELETE, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    DWORD written = 0;
    if (WriteFile(file, &frames, sizeof frames, &written, nullptr) &&
        written == sizeof frames) {
      written_frames_ = frames;
    }
    CloseHandle(file);
  }

  void Poll() {
    WIN32_FILE_ATTRIBUTE_DATA info;
    if (path_[0] == 0 ||
        !GetFileAttributesExW(path_, GetFileExInfoStandard, &info)) {
      if (has_stamp_ || seq_.load(std::memory_order_relaxed) == 0) {
        has_stamp_ = false;
        Publish(Config{});
      }
      return;
    }
    if (has_stamp_ &&
        CompareFileTime(&info.ftLastWriteTime, &stamp_) == 0 &&
        info.nFileSizeLow == stamp_size_) {
      return;
    }
    uint8_t buffer[kConfigBytes + 1];
    DWORD read = 0;
    HANDLE file = CreateFileW(
        path_, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    const BOOL ok = ReadFile(file, buffer, sizeof buffer, &read, nullptr);
    CloseHandle(file);
    if (!ok) return;

    has_stamp_ = true;
    stamp_ = info.ftLastWriteTime;
    stamp_size_ = info.nFileSizeLow;
    Config parsed;
    if (ParseConfig(buffer, read, &parsed)) Publish(parsed);
  }

  void Publish(const Config& config) {
    const uint32_t s = seq_.load(std::memory_order_relaxed);
    seq_.store(s + 1, std::memory_order_relaxed);
    std::atomic_thread_fence(std::memory_order_release);
    std::memcpy(&config_, &config, sizeof(Config));
    seq_.store(s + 2, std::memory_order_release);
  }

  SRWLOCK lock_ = SRWLOCK_INIT;
  long users_ = 0;
  HANDLE thread_ = nullptr;
  HANDLE stop_ = nullptr;
  wchar_t path_[MAX_PATH] = {};
  wchar_t alive_path_[MAX_PATH] = {};
  uint64_t written_frames_ = ~0ull;
  bool has_stamp_ = false;
  FILETIME stamp_ = {};
  DWORD stamp_size_ = 0;

  std::atomic<uint32_t> seq_{0};
  Config config_;
};

// ---------------------------------------------------------------------------

bool IsFloat32(IAudioMediaType* type, UNCOMPRESSEDAUDIOFORMAT* format) {
  if (type == nullptr) return false;
  UNCOMPRESSEDAUDIOFORMAT f;
  if (FAILED(type->GetUncompressedAudioFormat(&f))) return false;
  if (!IsEqualGUID(f.guidFormatType, kSubtypeIeeeFloat)) return false;
  if (f.dwBytesPerSampleContainer != 4 || f.dwValidBitsPerSample != 32) {
    return false;
  }
  if (f.dwSamplesPerFrame == 0 || f.fFramesPerSecond <= 0) return false;
  if (format) *format = f;
  return true;
}

// Float32 is all the filters take. Anything else is answered with the
// float version of the same layout (S_FALSE) rather than a refusal, since a
// refused format can leave the mic with no working graph at all.
HRESULT FormatSupported(IAudioMediaType* opposite, IAudioMediaType* requested,
                        IAudioMediaType** supported) {
  if (requested == nullptr || supported == nullptr) return E_POINTER;
  *supported = nullptr;
  if (IsFloat32(requested, nullptr)) {
    requested->AddRef();
    *supported = requested;
    return S_OK;
  }
  if (IsFloat32(opposite, nullptr)) {
    opposite->AddRef();
    *supported = opposite;
    return S_FALSE;
  }
  UNCOMPRESSEDAUDIOFORMAT f;
  if (FAILED(requested->GetUncompressedAudioFormat(&f)) ||
      f.dwSamplesPerFrame == 0 || f.fFramesPerSecond <= 0) {
    return APOERR_FORMAT_NOT_SUPPORTED;
  }
  f.guidFormatType = kSubtypeIeeeFloat;
  f.dwBytesPerSampleContainer = 4;
  f.dwValidBitsPerSample = 32;
  IAudioMediaType* proposed = nullptr;
  if (FAILED(CreateAudioMediaTypeFromUncompressedAudioFormat(&f, &proposed)) ||
      proposed == nullptr) {
    return APOERR_FORMAT_NOT_SUPPORTED;
  }
  *supported = proposed;
  return S_FALSE;
}

}  // namespace

// ---------------------------------------------------------------------------

class VoiceEq final : public IAudioProcessingObject,
                      public IAudioProcessingObjectRT,
                      public IAudioProcessingObjectConfiguration,
                      public IAudioSystemEffects2 {
 public:
  VoiceEq() { g_objects.fetch_add(1); }

  ~VoiceEq() {
    if (locked_) SharedConfig::Instance().Release();
    g_objects.fetch_sub(1);
  }

  // IUnknown
  STDMETHODIMP QueryInterface(REFIID riid, void** out) override {
    if (out == nullptr) return E_POINTER;
    if (riid == __uuidof(IUnknown) || riid == __uuidof(IAudioProcessingObject)) {
      *out = static_cast<IAudioProcessingObject*>(this);
    } else if (riid == __uuidof(IAudioProcessingObjectRT)) {
      *out = static_cast<IAudioProcessingObjectRT*>(this);
    } else if (riid == __uuidof(IAudioProcessingObjectConfiguration)) {
      *out = static_cast<IAudioProcessingObjectConfiguration*>(this);
    } else if (riid == __uuidof(IAudioSystemEffects) ||
               riid == __uuidof(IAudioSystemEffects2)) {
      *out = static_cast<IAudioSystemEffects2*>(this);
    } else {
      *out = nullptr;
      return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
  }

  STDMETHODIMP_(ULONG) AddRef() override { return ULONG(refs_.fetch_add(1) + 1); }

  STDMETHODIMP_(ULONG) Release() override {
    const long left = refs_.fetch_sub(1) - 1;
    if (left == 0) delete this;
    return ULONG(left);
  }

  // IAudioProcessingObject
  STDMETHODIMP Reset() override {
    processor_.Reset();
    return S_OK;
  }

  STDMETHODIMP GetLatency(HNSTIME* time) override {
    if (time == nullptr) return E_POINTER;
    *time = 0;
    return S_OK;
  }

  STDMETHODIMP GetRegistrationProperties(APO_REG_PROPERTIES** props) override {
    if (props == nullptr) return E_POINTER;
    auto* p = static_cast<APO_REG_PROPERTIES*>(
        CoTaskMemAlloc(sizeof(APO_REG_PROPERTIES)));
    if (p == nullptr) return E_OUTOFMEMORY;
    FillRegistrationProperties(p);
    *props = p;
    return S_OK;
  }

  STDMETHODIMP Initialize(UINT32 size, BYTE* data) override {
    if (initialized_) return APOERR_ALREADY_INITIALIZED;
    if (size != 0 && data == nullptr) return E_POINTER;
    initialized_ = true;
    return S_OK;
  }

  STDMETHODIMP IsInputFormatSupported(IAudioMediaType* opposite,
                                      IAudioMediaType* requested,
                                      IAudioMediaType** supported) override {
    return FormatSupported(opposite, requested, supported);
  }

  STDMETHODIMP IsOutputFormatSupported(IAudioMediaType* opposite,
                                       IAudioMediaType* requested,
                                       IAudioMediaType** supported) override {
    return FormatSupported(opposite, requested, supported);
  }

  STDMETHODIMP GetInputChannelCount(UINT32* count) override {
    if (count == nullptr) return E_POINTER;
    *count = channels_;
    return S_OK;
  }

  // IAudioProcessingObjectConfiguration
  STDMETHODIMP LockForProcess(UINT32 num_in, APO_CONNECTION_DESCRIPTOR** in,
                              UINT32 num_out,
                              APO_CONNECTION_DESCRIPTOR** out) override {
    if (!initialized_) return APOERR_NOT_INITIALIZED;
    if (locked_) return APOERR_APO_LOCKED;
    if (num_in != 1 || num_out != 1 || in == nullptr || out == nullptr ||
        in[0] == nullptr || out[0] == nullptr) {
      return APOERR_NUM_CONNECTIONS_INVALID;
    }
    UNCOMPRESSEDAUDIOFORMAT fin, fout;
    if (!IsFloat32(in[0]->pFormat, &fin) || !IsFloat32(out[0]->pFormat, &fout) ||
        fin.dwSamplesPerFrame != fout.dwSamplesPerFrame ||
        fin.fFramesPerSecond != fout.fFramesPerSecond) {
      return APOERR_INVALID_CONNECTION_FORMAT;
    }
    channels_ = fin.dwSamplesPerFrame;
    processor_.Configure(fin.fFramesPerSecond, channels_);

    SharedConfig& shared = SharedConfig::Instance();
    shared.Acquire();
    seen_seq_ = ~0u;
    PickUpConfig();
    locked_ = true;
    return S_OK;
  }

  STDMETHODIMP UnlockForProcess() override {
    if (!locked_) return APOERR_ALREADY_UNLOCKED;
    locked_ = false;
    SharedConfig::Instance().Release();
    return S_OK;
  }

  // IAudioProcessingObjectRT
  STDMETHODIMP_(void) APOProcess(UINT32 num_in, APO_CONNECTION_PROPERTY** in,
                                 UINT32 num_out,
                                 APO_CONNECTION_PROPERTY** out) override {
    if (num_in < 1 || num_out < 1 || in == nullptr || out == nullptr) return;
    APO_CONNECTION_PROPERTY* src = in[0];
    APO_CONNECTION_PROPERTY* dst = out[0];
    if (src == nullptr || dst == nullptr) return;

    const UINT32 frames = src->u32ValidFrameCount;
    g_frames.fetch_add(frames, std::memory_order_relaxed);
    auto* input = reinterpret_cast<float*>(src->pBuffer);
    auto* output = reinterpret_cast<float*>(dst->pBuffer);
    const size_t bytes = size_t(frames) * channels_ * sizeof(float);

    if (src->u32BufferFlags == BUFFER_SILENT) {
      if (output != input && output != nullptr) std::memset(output, 0, bytes);
      dst->u32ValidFrameCount = frames;
      dst->u32BufferFlags = BUFFER_SILENT;
      return;
    }
    if (output != input && output != nullptr && input != nullptr) {
      std::memcpy(output, input, bytes);
    }
    if (output != nullptr) {
      PickUpConfig();
      processor_.Process(output, frames, channels_);
    }
    dst->u32ValidFrameCount = frames;
    dst->u32BufferFlags = src->u32BufferFlags;
  }

  STDMETHODIMP_(UINT32) CalcInputFrames(UINT32 frames) override { return frames; }

  STDMETHODIMP_(UINT32) CalcOutputFrames(UINT32 frames) override { return frames; }

  // IAudioSystemEffects2
  STDMETHODIMP GetEffectsList(LPGUID* ids, UINT* count, HANDLE) override {
    if (ids == nullptr || count == nullptr) return E_POINTER;
    *ids = nullptr;
    *count = 0;
    return S_OK;
  }

  static void FillRegistrationProperties(APO_REG_PROPERTIES* p) {
    std::memset(p, 0, sizeof *p);
    p->clsid = kVoiceEqClsid;
    p->Flags = APO_FLAG(APO_FLAG_INPLACE | APO_FLAG_DEFAULT);
    wcscpy_s(p->szFriendlyName, kVoiceEqFriendlyName);
    wcscpy_s(p->szCopyrightInfo, L"luma");
    p->u32MajorVersion = 1;
    p->u32MinorVersion = 0;
    p->u32MinInputConnections = 1;
    p->u32MaxInputConnections = 1;
    p->u32MinOutputConnections = 1;
    p->u32MaxOutputConnections = 1;
    p->u32MaxInstances = 0xFFFFFFFF;
    p->u32NumAPOInterfaces = 1;
    p->iidAPOInterfaceList[0] = __uuidof(IAudioProcessingObject);
  }

 private:
  void PickUpConfig() {
    const SharedConfig& shared = SharedConfig::Instance();
    const uint32_t seq = shared.sequence();
    if (seq == seen_seq_) return;
    Config config;
    if (!shared.Read(seq, &config)) return;
    processor_.Apply(config);
    seen_seq_ = seq;
  }

  std::atomic<long> refs_{1};
  bool initialized_ = false;
  bool locked_ = false;
  UINT32 channels_ = 0;
  uint32_t seen_seq_ = ~0u;
  Processor processor_;
};

// ---------------------------------------------------------------------------

class Factory final : public IClassFactory {
 public:
  STDMETHODIMP QueryInterface(REFIID riid, void** out) override {
    if (out == nullptr) return E_POINTER;
    if (riid == __uuidof(IUnknown) || riid == __uuidof(IClassFactory)) {
      *out = static_cast<IClassFactory*>(this);
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override { return 2; }
  STDMETHODIMP_(ULONG) Release() override { return 1; }

  STDMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** out) override {
    if (out == nullptr) return E_POINTER;
    *out = nullptr;
    if (outer != nullptr) return CLASS_E_NOAGGREGATION;
    auto* apo = new (std::nothrow) VoiceEq();
    if (apo == nullptr) return E_OUTOFMEMORY;
    const HRESULT hr = apo->QueryInterface(riid, out);
    apo->Release();
    return hr;
  }

  STDMETHODIMP LockServer(BOOL lock) override {
    if (lock) {
      g_locks.fetch_add(1);
    } else {
      g_locks.fetch_sub(1);
    }
    return S_OK;
  }
};

Factory g_factory;

}  // namespace luma_apo

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** out) {
  if (out == nullptr) return E_POINTER;
  *out = nullptr;
  if (!IsEqualCLSID(clsid, luma_apo::kVoiceEqClsid)) {
    return CLASS_E_CLASSNOTAVAILABLE;
  }
  return luma_apo::g_factory.QueryInterface(riid, out);
}

STDAPI DllCanUnloadNow() {
  return luma_apo::g_objects.load() == 0 && luma_apo::g_locks.load() == 0
             ? S_OK
             : S_FALSE;
}

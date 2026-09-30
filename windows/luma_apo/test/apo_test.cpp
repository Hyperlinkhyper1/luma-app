// Drives the APO the way audiodg does (class factory, Initialize, format
// negotiation, LockForProcess, APOProcess) plus the config parser and the
// DSP, without registering anything or touching a real audio device.
//
// Build: cmake --build <dir> --target luma_apo_test, then run the exe;
// exit code 0 means every check passed.

#include <windows.h>

#include <audioenginebaseapo.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "../apo_ids.h"
#include "../eq_config.h"
#include "../eq_dsp.h"

namespace luma_apo {
extern wchar_t g_config_path_override[MAX_PATH];
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** out);
STDAPI DllCanUnloadNow();

namespace {

int g_failures = 0;

void Check(bool ok, const char* what) {
  std::printf("%s  %s\n", ok ? "ok  " : "FAIL", what);
  if (!ok) g_failures++;
}

constexpr GUID kFloat = {
    0x00000003, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}};
constexpr GUID kPcm = {
    0x00000001, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}};

class FakeMediaType final : public IAudioMediaType {
 public:
  FakeMediaType(const GUID& subtype, DWORD bytes, DWORD channels, float rate) {
    f_.guidFormatType = subtype;
    f_.dwSamplesPerFrame = channels;
    f_.dwBytesPerSampleContainer = bytes;
    f_.dwValidBitsPerSample = bytes * 8;
    f_.fFramesPerSecond = rate;
    f_.dwChannelMask = 0;
  }
  STDMETHODIMP QueryInterface(REFIID riid, void** out) override {
    if (riid == __uuidof(IUnknown) || riid == __uuidof(IAudioMediaType)) {
      *out = this;
      AddRef();
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }
  STDMETHODIMP_(ULONG) AddRef() override { return ULONG(++refs); }
  STDMETHODIMP_(ULONG) Release() override { return ULONG(--refs); }
  STDMETHODIMP IsCompressedFormat(BOOL* c) override {
    *c = FALSE;
    return S_OK;
  }
  STDMETHODIMP IsEqual(IAudioMediaType*, DWORD*) override { return E_NOTIMPL; }
  const WAVEFORMATEX* STDMETHODCALLTYPE GetAudioFormat() override { return nullptr; }
  STDMETHODIMP GetUncompressedAudioFormat(UNCOMPRESSEDAUDIOFORMAT* f) override {
    *f = f_;
    return S_OK;
  }
  long refs = 1;

 private:
  UNCOMPRESSEDAUDIOFORMAT f_{};
};

void PutU32(std::vector<uint8_t>& b, size_t at, uint32_t v) {
  b[at] = uint8_t(v);
  b[at + 1] = uint8_t(v >> 8);
  b[at + 2] = uint8_t(v >> 16);
  b[at + 3] = uint8_t(v >> 24);
}

void PutF32(std::vector<uint8_t>& b, size_t at, float v) {
  uint32_t bits;
  std::memcpy(&bits, &v, 4);
  PutU32(b, at, bits);
}

struct TestBand {
  uint32_t type;
  bool enabled;
  float frequency, gain, q;
};

std::vector<uint8_t> Encode(bool enabled, float preamp,
                            const std::vector<TestBand>& bands) {
  std::vector<uint8_t> b(luma_apo::kConfigBytes, 0);
  PutU32(b, 0, luma_apo::kConfigMagic);
  PutU32(b, 4, luma_apo::kConfigVersion);
  PutU32(b, 8, enabled ? 1 : 0);
  PutF32(b, 12, preamp);
  PutU32(b, 16, uint32_t(bands.size()));
  for (size_t i = 0; i < bands.size(); i++) {
    const size_t o = luma_apo::kHeaderBytes + i * luma_apo::kBandBytes;
    PutU32(b, o, bands[i].type);
    PutU32(b, o + 4, bands[i].enabled ? 1 : 0);
    PutF32(b, o + 8, bands[i].frequency);
    PutF32(b, o + 12, bands[i].gain);
    PutF32(b, o + 16, bands[i].q);
  }
  return b;
}

// Written the way luma does it: a temp file renamed over the real one.
void WriteConfig(const wchar_t* path, const std::vector<uint8_t>& bytes) {
  std::wstring tmp = std::wstring(path) + L".tmp";
  HANDLE f = CreateFileW(tmp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                         FILE_ATTRIBUTE_NORMAL, nullptr);
  DWORD written;
  WriteFile(f, bytes.data(), DWORD(bytes.size()), &written, nullptr);
  CloseHandle(f);
  MoveFileExW(tmp.c_str(), path, MOVEFILE_REPLACE_EXISTING);
}

double Rms(const float* s, size_t frames, size_t stride, size_t ch, size_t skip) {
  double sum = 0;
  for (size_t i = skip; i < frames; i++) sum += double(s[i * stride + ch]) * s[i * stride + ch];
  return std::sqrt(sum / double(frames - skip));
}

std::vector<float> Sine(size_t frames, size_t channels, double hz, double amp) {
  std::vector<float> v(frames * channels);
  for (size_t i = 0; i < frames; i++) {
    const float s = float(amp * std::sin(2 * 3.14159265358979 * hz * double(i) / 48000));
    for (size_t c = 0; c < channels; c++) v[i * channels + c] = s;
  }
  return v;
}

double Db(double ratio) { return 20 * std::log10(ratio); }

// ---------------------------------------------------------------------------

void TestParser() {
  using namespace luma_apo;
  auto good = Encode(true, -3, {{2, true, 1000, 6, 1}, {0, false, 80, 0, 0.707f}});
  Config c;
  Check(ParseConfig(good.data(), good.size(), &c), "parser accepts a valid file");
  Check(c.enabled && c.band_count == 2 && c.bands[0].type == BandType::kPeak &&
            std::fabs(c.bands[0].gain_db - 6) < 1e-6 && !c.bands[1].enabled &&
            std::fabs(c.preamp_db + 3) < 1e-6,
        "parser reads every field");

  Check(!ParseConfig(good.data(), good.size() - 1, &c), "rejects a short file");
  auto bad = good;
  bad[0] ^= 1;
  Check(!ParseConfig(bad.data(), bad.size(), &c), "rejects a bad magic");
  bad = good;
  PutU32(bad, 4, 2);
  Check(!ParseConfig(bad.data(), bad.size(), &c), "rejects a future version");
  bad = good;
  PutU32(bad, 16, 17);
  Check(!ParseConfig(bad.data(), bad.size(), &c), "rejects too many bands");
  bad = good;
  PutU32(bad, kHeaderBytes, 9);
  Check(!ParseConfig(bad.data(), bad.size(), &c), "rejects an unknown band type");

  auto wild = Encode(true, 1e9f, {{2, true, NAN, 1e9f, 0}});
  Check(ParseConfig(wild.data(), wild.size(), &c) && c.preamp_db == 12 &&
            c.bands[0].frequency == 20 && c.bands[0].gain_db == 24 &&
            std::fabs(c.bands[0].q - 0.3) < 1e-6,
        "clamps out-of-range and NaN numbers");
}

void TestDsp() {
  using namespace luma_apo;
  const size_t frames = 48000;
  Config c;
  c.enabled = true;
  c.band_count = 1;
  c.bands[0] = {BandType::kPeak, true, 1000, 6, 1};

  Processor p;
  p.Configure(48000, 2);
  p.Apply(c);
  auto s = Sine(frames, 2, 1000, 0.1);
  p.Process(s.data(), uint32_t(frames), 2);
  const double gain = Db(Rms(s.data(), frames, 2, 0, 4800) / (0.1 / std::sqrt(2.0)));
  std::printf("      peak +6 dB @1k measured %.3f dB\n", gain);
  Check(std::fabs(gain - 6) < 0.05, "peak band boosts its centre by its gain");
  Check(std::fabs(Rms(s.data(), frames, 2, 1, 4800) - Rms(s.data(), frames, 2, 0, 4800)) < 1e-9,
        "every channel gets the same filter");

  c.bands[0] = {BandType::kLowPass, true, 1000, 0, 0.707};
  p.Configure(48000, 1);
  p.Apply(c);
  auto hi = Sine(frames, 1, 8000, 0.1);
  p.Process(hi.data(), uint32_t(frames), 1);
  const double cut = Db(Rms(hi.data(), frames, 1, 0, 4800) / (0.1 / std::sqrt(2.0)));
  std::printf("      low-pass 1k at 8k measured %.1f dB\n", cut);
  Check(cut < -30, "low-pass removes the highs");

  c.enabled = false;
  p.Apply(c);
  auto raw = Sine(4800, 1, 440, 0.9);
  auto copy = raw;
  p.Process(copy.data(), 4800, 1);
  Check(copy == raw, "disabled config is a bit-exact passthrough");

  Check(SoftClip(0.5) == 0.5 && SoftClip(0.9) < 0.9 && SoftClip(10) <= 1 &&
            SoftClip(-10) >= -1,
        "soft clip stays linear below 0.8 and never passes 1");
}

void TestComObject(const wchar_t* config_path) {
  using namespace luma_apo;
  DeleteFileW(config_path);
  wcscpy_s(g_config_path_override, config_path);

  IClassFactory* factory = nullptr;
  Check(SUCCEEDED(DllGetClassObject(kVoiceEqClsid, __uuidof(IClassFactory),
                                    reinterpret_cast<void**>(&factory))),
        "class factory for the luma CLSID");
  GUID other = kVoiceEqClsid;
  other.Data1 ^= 1;
  void* nothing = nullptr;
  Check(DllGetClassObject(other, __uuidof(IClassFactory), &nothing) ==
            CLASS_E_CLASSNOTAVAILABLE,
        "refuses other CLSIDs");

  IAudioProcessingObject* apo = nullptr;
  factory->CreateInstance(nullptr, __uuidof(IAudioProcessingObject),
                          reinterpret_cast<void**>(&apo));
  Check(apo != nullptr, "creates an instance");
  if (!apo) return;

  IAudioProcessingObjectRT* rt = nullptr;
  IAudioProcessingObjectConfiguration* cfg = nullptr;
  IAudioSystemEffects2* sfx = nullptr;
  apo->QueryInterface(__uuidof(IAudioProcessingObjectRT), reinterpret_cast<void**>(&rt));
  apo->QueryInterface(__uuidof(IAudioProcessingObjectConfiguration),
                      reinterpret_cast<void**>(&cfg));
  apo->QueryInterface(__uuidof(IAudioSystemEffects2), reinterpret_cast<void**>(&sfx));
  Check(rt && cfg && sfx, "exposes RT, configuration and system-effects interfaces");

  APO_REG_PROPERTIES* props = nullptr;
  Check(SUCCEEDED(apo->GetRegistrationProperties(&props)) && props &&
            IsEqualCLSID(props->clsid, kVoiceEqClsid) &&
            props->u32NumAPOInterfaces == 1 &&
            props->iidAPOInterfaceList[0] == __uuidof(IAudioProcessingObject),
        "registration properties");
  CoTaskMemFree(props);

  APOInitSystemEffects2 init{};
  init.APOInit.cbSize = sizeof init;
  init.APOInit.clsid = kVoiceEqClsid;
  Check(SUCCEEDED(apo->Initialize(sizeof init, reinterpret_cast<BYTE*>(&init))),
        "Initialize with APOInitSystemEffects2");
  Check(apo->Initialize(sizeof init, reinterpret_cast<BYTE*>(&init)) ==
            APOERR_ALREADY_INITIALIZED,
        "second Initialize is refused");

  FakeMediaType fmt(kFloat, 4, 2, 48000);
  FakeMediaType pcm(kPcm, 2, 2, 48000);
  IAudioMediaType* supported = nullptr;
  Check(apo->IsInputFormatSupported(nullptr, &fmt, &supported) == S_OK &&
            supported == &fmt,
        "accepts float32 input");
  if (supported) supported->Release();
  supported = nullptr;
  {
    const HRESULT hr = apo->IsOutputFormatSupported(nullptr, &pcm, &supported);
    UNCOMPRESSEDAUDIOFORMAT proposed{};
    const bool got = supported != nullptr &&
                     SUCCEEDED(supported->GetUncompressedAudioFormat(&proposed));
    Check(hr == S_FALSE && got && IsEqualGUID(proposed.guidFormatType, kFloat) &&
              proposed.dwBytesPerSampleContainer == 4 &&
              proposed.dwSamplesPerFrame == 2 && proposed.fFramesPerSecond == 48000,
          "answers 16-bit PCM with the float version of the same layout");
    if (supported) supported->Release();
    supported = nullptr;
  }
  Check(apo->IsOutputFormatSupported(&fmt, &pcm, &supported) == S_FALSE &&
            supported == &fmt,
        "offers the float opposite format instead");
  if (supported) supported->Release();

  const size_t frames = 480;
  std::vector<float> buffer(frames * 2);
  APO_CONNECTION_DESCRIPTOR din{APO_CONNECTION_BUFFER_TYPE_EXTERNAL,
                                reinterpret_cast<UINT_PTR>(buffer.data()),
                                UINT32(frames), &fmt, 0};
  APO_CONNECTION_DESCRIPTOR dout = din;
  APO_CONNECTION_DESCRIPTOR* pin = &din;
  APO_CONNECTION_DESCRIPTOR* pout = &dout;

  WriteConfig(config_path, Encode(true, 0, {{2, true, 1000, 12, 1}}));
  Check(SUCCEEDED(cfg->LockForProcess(1, &pin, 1, &pout)), "LockForProcess");
  UINT32 channels = 0;
  apo->GetInputChannelCount(&channels);
  Check(channels == 2, "reports the locked channel count");

  APO_CONNECTION_PROPERTY cin{reinterpret_cast<UINT_PTR>(buffer.data()),
                              UINT32(frames), BUFFER_VALID, 0};
  APO_CONNECTION_PROPERTY cout = cin;
  APO_CONNECTION_PROPERTY* ppin = &cin;
  APO_CONNECTION_PROPERTY* ppout = &cout;

  // One second of 1 kHz in 10 ms blocks, in place, like the engine does.
  auto run = [&]() {
    const auto tone = Sine(48000, 2, 1000, 0.05);
    double sum = 0;
    size_t n = 0;
    for (size_t block = 0; block < 100; block++) {
      std::memcpy(buffer.data(), tone.data() + block * frames * 2,
                  frames * 2 * sizeof(float));
      cin.u32BufferFlags = BUFFER_VALID;
      rt->APOProcess(1, &ppin, 1, &ppout);
      if (block >= 10) {
        for (size_t i = 0; i < frames; i++) {
          sum += double(buffer[i * 2]) * buffer[i * 2];
          n++;
        }
      }
    }
    return Db(std::sqrt(sum / double(n)) / (0.05 / std::sqrt(2.0)));
  };

  const double boosted = run();
  std::printf("      through the APO: %.2f dB\n", boosted);
  Check(std::fabs(boosted - 12) < 0.1, "applies the curve from eq.bin");
  Check(cout.u32ValidFrameCount == frames && cout.u32BufferFlags == BUFFER_VALID,
        "reports the frames it produced");

  WriteConfig(config_path, Encode(false, 0, {{2, true, 1000, 12, 1}}));
  Sleep(400);
  const double off = run();
  std::printf("      after switching off: %.2f dB\n", off);
  Check(std::fabs(off) < 0.01, "hot-reloads a switched-off curve without a relock");

  WriteConfig(config_path, Encode(true, -6, {}));
  Sleep(400);
  const double quieter = run();
  Check(std::fabs(quieter + 6) < 0.05, "hot-reloads a new curve");

  DeleteFileW(config_path);
  Sleep(400);
  Check(std::fabs(run()) < 0.01, "a deleted eq.bin means passthrough");

  std::fill(buffer.begin(), buffer.end(), 0.5f);
  cin.u32BufferFlags = BUFFER_SILENT;
  rt->APOProcess(1, &ppin, 1, &ppout);
  Check(cout.u32BufferFlags == BUFFER_SILENT, "passes silence through as silence");

  std::wstring alive(config_path);
  alive = alive.substr(0, alive.find_last_of(L'\\') + 1) + L"alive.bin";
  Sleep(400);
  {
    uint64_t counted = 0;
    HANDLE f = CreateFileW(alive.c_str(), GENERIC_READ,
                           FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           nullptr, OPEN_EXISTING, 0, nullptr);
    DWORD read = 0;
    const bool ok = f != INVALID_HANDLE_VALUE &&
                    ReadFile(f, &counted, sizeof counted, &read, nullptr) &&
                    read == sizeof counted;
    if (f != INVALID_HANDLE_VALUE) CloseHandle(f);
    std::printf("      heartbeat: %llu frames\n", counted);
    Check(ok && counted >= 4 * 100 * frames,
          "writes alive.bin with the frames it processed");
  }

  Check(SUCCEEDED(cfg->UnlockForProcess()), "UnlockForProcess");
  Check(cfg->UnlockForProcess() == APOERR_ALREADY_UNLOCKED, "second unlock is refused");
  DeleteFileW(alive.c_str());

  sfx->Release();
  cfg->Release();
  rt->Release();
  Check(DllCanUnloadNow() == S_FALSE, "stays loaded while an instance lives");
  apo->Release();
  Check(DllCanUnloadNow() == S_OK, "can unload once every instance is gone");
}

}  // namespace

int wmain() {
  CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  wchar_t dir[MAX_PATH];
  GetTempPathW(MAX_PATH, dir);
  std::wstring path = std::wstring(dir) + L"luma_apo_test_eq.bin";

  TestParser();
  TestDsp();
  TestComObject(path.c_str());

  std::printf(g_failures == 0 ? "\nall passed\n" : "\n%d FAILED\n", g_failures);
  CoUninitialize();
  return g_failures == 0 ? 0 : 1;
}

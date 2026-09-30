// luma_apo_setup.exe: installs and removes the luma voice EQ APO on a
// microphone. The only luma code that runs elevated.
//
//   luma_apo_setup.exe status               JSON on stdout, never elevates
//   luma_apo_setup.exe check <deviceId>     record 1.5 s, JSON on stdout
//   luma_apo_setup.exe install <deviceId>   UAC prompt, then attach to that mic
//   luma_apo_setup.exe uninstall <deviceId> UAC prompt, then restore that mic
//   luma_apo_setup.exe uninstall-all        restore every mic, remove the APO
//
// <deviceId> is the IMMDevice id luma already has, e.g.
// "{0.0.1.00000000}.{78047f01-3c0e-4893-b7e8-150482cd3d14}".
//
// Install copies the DLL out of the per-user app folder into Program Files,
// because audiodg must never load code an unelevated user can overwrite.
// Every endpoint value it changes is backed up first under HKLM\SOFTWARE\
// luma\AudioApo and put back exactly on uninstall.
//
// Windows gives no error when a mic refuses a third-party effect: the mic
// just goes silent, or the effect is quietly skipped. So install never
// trusts the registry write. It records from the mic before touching
// anything, then after each attempt checks the mic still delivers sound and
// that the APO's alive.bin counter moved. A slot that fails is restored on
// the spot and the next is tried; if none works the mic is left exactly as
// it was and the exit code says so. The endpoint keys belong
// to the audio services and only grant Administrators SetValue, so writes
// there go through SeRestorePrivilege (REG_OPTION_BACKUP_RESTORE).

#include <windows.h>

#include <aclapi.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <sddl.h>
#include <shellapi.h>
#include <shlobj.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "apo_ids.h"

namespace {

enum ExitCode : int {
  kOk = 0,
  kUsage = 1,
  kFailed = 2,
  kCancelled = 3,
  kFilesMissing = 4,
  kRestartNeeded = 5,
  kNoSuchDevice = 6,
  kIncompatible = 7,
  kMicNotRecording = 8,
};

constexpr wchar_t kCaptureRoot[] =
    L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Capture\\";
constexpr wchar_t kLumaRoot[] = L"SOFTWARE\\luma\\AudioApo";
constexpr wchar_t kEndpointsRoot[] = L"SOFTWARE\\luma\\AudioApo\\Endpoints";
constexpr wchar_t kApoRoot[] =
    L"SOFTWARE\\Classes\\AudioEngine\\AudioProcessingObjects";
constexpr wchar_t kClsidRoot[] = L"SOFTWARE\\Classes\\CLSID";

// PKEY_FX_Association, the CompositeFX and legacy stream/mode/endpoint
// effect CLSIDs, the matching *_ProcessingModes_Supported_For_Streaming and
// PKEY_AudioEndpoint_Disable_SysFx, as FxProperties value names.
constexpr wchar_t kAssociation[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},0";
constexpr wchar_t kLegacySfx[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},5";
constexpr wchar_t kLegacyMfx[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},6";
constexpr wchar_t kLegacyEfx[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},7";
constexpr wchar_t kCompositeSfx[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},13";
constexpr wchar_t kCompositeMfx[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},14";
constexpr wchar_t kCompositeEfx[] = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},15";
constexpr wchar_t kSfxModes[] = L"{d3993a3f-99c2-4402-b5ec-a92a0367664b},5";
constexpr wchar_t kMfxModes[] = L"{d3993a3f-99c2-4402-b5ec-a92a0367664b},6";
constexpr wchar_t kEfxModes[] = L"{d3993a3f-99c2-4402-b5ec-a92a0367664b},7";
constexpr wchar_t kDisableSysFx[] = L"{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5";
constexpr const wchar_t* kTouched[] = {
    kAssociation, kCompositeSfx, kCompositeMfx, kCompositeEfx,
    kSfxModes,    kMfxModes,     kEfxModes,     kDisableSysFx};

// Where in the mic's effect chain luma can sit, in the order tried. The
// endpoint slot runs once for every app; the stream and mode slots are the
// fallbacks for mics whose endpoint slot Windows won't combine with luma.
struct Slot {
  const wchar_t* name;
  const wchar_t* composite;
  const wchar_t* legacy;
  const wchar_t* modes;
};
constexpr Slot kSlots[] = {
    {L"endpoint", kCompositeEfx, kLegacyEfx, kEfxModes},
    {L"stream", kCompositeSfx, kLegacySfx, kSfxModes},
    {L"mode", kCompositeMfx, kLegacyMfx, kMfxModes},
};

constexpr wchar_t kAnyNodeType[] = L"{00000000-0000-0000-0000-000000000000}";
constexpr wchar_t kDefaultMode[] = L"{C18E2F7E-933D-4965-B7D1-1EEF228D2AF3}";
constexpr wchar_t kCommunicationsMode[] =
    L"{98951333-B9CD-48B1-A0A3-FF40682D73F7}";

constexpr wchar_t kAbsentValue[] = L"__absent";
constexpr wchar_t kDeviceIdValue[] = L"__deviceId";

// ---------------------------------------------------------------------------

std::wstring Lower(std::wstring s) {
  for (auto& c : s) c = wchar_t(towlower(c));
  return s;
}

bool IsGuid(const std::wstring& s) {
  if (s.size() != 38 || s[0] != L'{' || s[37] != L'}') return false;
  for (size_t i = 1; i < 37; i++) {
    const bool dash = i == 9 || i == 14 || i == 19 || i == 24;
    if (dash ? s[i] != L'-' : !iswxdigit(s[i])) return false;
  }
  return true;
}

// Only capture endpoints: "{0.0.1.00000000}.{guid}".
bool EndpointGuid(const std::wstring& device_id, std::wstring* guid) {
  const std::wstring prefix = L"{0.0.1.00000000}.";
  if (device_id.size() != prefix.size() + 38 ||
      device_id.compare(0, prefix.size(), prefix) != 0) {
    return false;
  }
  *guid = Lower(device_id.substr(prefix.size()));
  return IsGuid(*guid);
}

std::wstring KnownFolder(REFKNOWNFOLDERID id) {
  PWSTR path = nullptr;
  std::wstring result;
  if (SUCCEEDED(SHGetKnownFolderPath(id, 0, nullptr, &path))) result = path;
  CoTaskMemFree(path);
  return result;
}

std::wstring SelfDirectory() {
  wchar_t path[MAX_PATH];
  const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (n == 0 || n == MAX_PATH) return L"";
  std::wstring s(path, n);
  return s.substr(0, s.find_last_of(L'\\'));
}

std::wstring InstallDirectory() {
  return KnownFolder(FOLDERID_ProgramFiles) + L"\\luma\\apo";
}

std::wstring ConfigDirectory() {
  return KnownFolder(FOLDERID_ProgramData) + L"\\luma\\apo";
}

void Log(const std::wstring& line) {
  const std::wstring dir = ConfigDirectory();
  if (dir.size() <= 10) return;
  HANDLE f = CreateFileW((dir + L"\\setup.log").c_str(), FILE_APPEND_DATA,
                         FILE_SHARE_READ, nullptr, OPEN_ALWAYS,
                         FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE) return;
  SYSTEMTIME t;
  GetLocalTime(&t);
  wchar_t stamp[32];
  swprintf_s(stamp, L"%04u-%02u-%02u %02u:%02u:%02u ", t.wYear, t.wMonth,
             t.wDay, t.wHour, t.wMinute, t.wSecond);
  const std::wstring text = stamp + line + L"\r\n";
  const int bytes = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), int(text.size()),
                                        nullptr, 0, nullptr, nullptr);
  std::string utf8(size_t(bytes), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.c_str(), int(text.size()), utf8.data(),
                      bytes, nullptr, nullptr);
  DWORD written;
  WriteFile(f, utf8.data(), DWORD(utf8.size()), &written, nullptr);
  CloseHandle(f);
}

void Print(const std::wstring& text) {
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  if (out == nullptr || out == INVALID_HANDLE_VALUE) return;
  const int bytes = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), int(text.size()),
                                        nullptr, 0, nullptr, nullptr);
  std::string utf8(size_t(bytes), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.c_str(), int(text.size()), utf8.data(),
                      bytes, nullptr, nullptr);
  DWORD written;
  WriteFile(out, utf8.data(), DWORD(utf8.size()), &written, nullptr);
}

// ---------------------------------------------------------------------------
// Registry helpers.

class Key {
 public:
  Key() = default;
  explicit Key(HKEY h) : h_(h) {}
  Key(const Key&) = delete;
  Key& operator=(const Key&) = delete;
  Key(Key&& o) noexcept : h_(o.h_) { o.h_ = nullptr; }
  Key& operator=(Key&& o) noexcept {
    if (this != &o) {
      if (h_) RegCloseKey(h_);
      h_ = o.h_;
      o.h_ = nullptr;
    }
    return *this;
  }
  ~Key() {
    if (h_) RegCloseKey(h_);
  }
  HKEY get() const { return h_; }
  explicit operator bool() const { return h_ != nullptr; }

 private:
  HKEY h_ = nullptr;
};

Key OpenRead(const std::wstring& path) {
  HKEY h = nullptr;
  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, path.c_str(), 0,
                    KEY_READ | KEY_WOW64_64KEY, &h) != ERROR_SUCCESS) {
    return Key();
  }
  return Key(h);
}

bool KeyExists(const std::wstring& path) { return bool(OpenRead(path)); }

// Opens through backup/restore semantics, which bypass the key's ACL. With
// [create] false, a missing key stays missing.
Key OpenPrivileged(const std::wstring& path, bool create) {
  if (!create && !KeyExists(path)) return Key();
  HKEY h = nullptr;
  DWORD disposition = 0;
  if (RegCreateKeyExW(HKEY_LOCAL_MACHINE, path.c_str(), 0, nullptr,
                      REG_OPTION_BACKUP_RESTORE, KEY_ALL_ACCESS, nullptr, &h,
                      &disposition) != ERROR_SUCCESS) {
    return Key();
  }
  return Key(h);
}

struct RawValue {
  DWORD type = REG_NONE;
  std::vector<BYTE> data;
};

bool ReadRaw(HKEY key, const wchar_t* name, RawValue* out) {
  DWORD type = 0, size = 0;
  if (RegQueryValueExW(key, name, nullptr, &type, nullptr, &size) != ERROR_SUCCESS) {
    return false;
  }
  out->type = type;
  out->data.resize(size);
  if (size == 0) return true;
  if (RegQueryValueExW(key, name, nullptr, &type, out->data.data(), &size) !=
      ERROR_SUCCESS) {
    return false;
  }
  out->data.resize(size);
  return true;
}

bool WriteRaw(HKEY key, const wchar_t* name, const RawValue& v) {
  return RegSetValueExW(key, name, 0, v.type, v.data.empty() ? nullptr : v.data.data(),
                        DWORD(v.data.size())) == ERROR_SUCCESS;
}

bool WriteString(HKEY key, const wchar_t* name, const std::wstring& value) {
  return RegSetValueExW(key, name, 0, REG_SZ,
                        reinterpret_cast<const BYTE*>(value.c_str()),
                        DWORD((value.size() + 1) * sizeof(wchar_t))) == ERROR_SUCCESS;
}

bool WriteDword(HKEY key, const wchar_t* name, DWORD value) {
  return RegSetValueExW(key, name, 0, REG_DWORD,
                        reinterpret_cast<const BYTE*>(&value),
                        sizeof value) == ERROR_SUCCESS;
}

std::vector<std::wstring> ParseMultiString(const RawValue& v) {
  std::vector<std::wstring> items;
  if (v.type == REG_SZ || v.type == REG_EXPAND_SZ) {
    std::wstring s(reinterpret_cast<const wchar_t*>(v.data.data()),
                   v.data.size() / sizeof(wchar_t));
    s = s.substr(0, s.find(L'\0'));
    if (!s.empty()) items.push_back(s);
    return items;
  }
  if (v.type != REG_MULTI_SZ) return items;
  const auto* p = reinterpret_cast<const wchar_t*>(v.data.data());
  const size_t n = v.data.size() / sizeof(wchar_t);
  size_t start = 0;
  for (size_t i = 0; i < n; i++) {
    if (p[i] != L'\0') continue;
    if (i > start) items.emplace_back(p + start, i - start);
    start = i + 1;
  }
  if (start < n) items.emplace_back(p + start, n - start);
  return items;
}

bool WriteMultiString(HKEY key, const wchar_t* name,
                      const std::vector<std::wstring>& items) {
  std::wstring block;
  for (const auto& item : items) {
    block += item;
    block += L'\0';
  }
  block += L'\0';
  return RegSetValueExW(key, name, 0, REG_MULTI_SZ,
                        reinterpret_cast<const BYTE*>(block.data()),
                        DWORD(block.size() * sizeof(wchar_t))) == ERROR_SUCCESS;
}

bool SameGuid(const std::wstring& a, const std::wstring& b) {
  return Lower(a) == Lower(b);
}

std::vector<std::wstring> SubkeyNames(HKEY key) {
  std::vector<std::wstring> names;
  wchar_t name[256];
  for (DWORD i = 0;; i++) {
    DWORD len = 256;
    if (RegEnumKeyExW(key, i, name, &len, nullptr, nullptr, nullptr, nullptr) !=
        ERROR_SUCCESS) {
      break;
    }
    names.emplace_back(name, len);
  }
  return names;
}

// ---------------------------------------------------------------------------
// Process and service helpers.

bool IsElevated() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
  TOKEN_ELEVATION elevation{};
  DWORD size = 0;
  const BOOL ok = GetTokenInformation(token, TokenElevation, &elevation,
                                      sizeof elevation, &size);
  CloseHandle(token);
  return ok && elevation.TokenIsElevated;
}

bool EnablePrivilege(const wchar_t* name) {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                        &token)) {
    return false;
  }
  TOKEN_PRIVILEGES tp{};
  tp.PrivilegeCount = 1;
  tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
  bool ok = LookupPrivilegeValueW(nullptr, name, &tp.Privileges[0].Luid) &&
            AdjustTokenPrivileges(token, FALSE, &tp, 0, nullptr, nullptr) &&
            GetLastError() == ERROR_SUCCESS;
  CloseHandle(token);
  return ok;
}

// Re-runs this exe elevated with the same arguments and returns its code.
int RelaunchElevated(const std::vector<std::wstring>& args) {
  wchar_t self[MAX_PATH];
  if (GetModuleFileNameW(nullptr, self, MAX_PATH) == 0) return kFailed;
  std::wstring params;
  for (size_t i = 1; i < args.size(); i++) {
    if (i > 1) params += L' ';
    params += L'"' + args[i] + L'"';
  }
  SHELLEXECUTEINFOW info{};
  info.cbSize = sizeof info;
  info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC;
  info.lpVerb = L"runas";
  info.lpFile = self;
  info.lpParameters = params.c_str();
  info.nShow = SW_HIDE;
  if (!ShellExecuteExW(&info)) {
    return GetLastError() == ERROR_CANCELLED ? kCancelled : kFailed;
  }
  if (info.hProcess == nullptr) return kFailed;
  WaitForSingleObject(info.hProcess, INFINITE);
  DWORD code = kFailed;
  GetExitCodeProcess(info.hProcess, &code);
  CloseHandle(info.hProcess);
  return int(code);
}

bool WaitForServiceState(SC_HANDLE service, DWORD state) {
  for (int i = 0; i < 100; i++) {
    SERVICE_STATUS status{};
    if (!QueryServiceStatus(service, &status)) return false;
    if (status.dwCurrentState == state) return true;
    Sleep(100);
  }
  return false;
}

// Audiosrv only reads endpoint effects when it builds a graph, and audiodg
// keeps the DLL mapped, so both the copy and the registry change need it
// down for a moment.
class AudioService {
 public:
  AudioService() {
    manager_ = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (manager_) {
      service_ = OpenServiceW(manager_, L"Audiosrv",
                              SERVICE_STOP | SERVICE_START | SERVICE_QUERY_STATUS);
    }
  }
  ~AudioService() {
    if (service_) CloseServiceHandle(service_);
    if (manager_) CloseServiceHandle(manager_);
  }

  bool Stop() {
    if (!service_) return false;
    SERVICE_STATUS status{};
    if (!ControlService(service_, SERVICE_CONTROL_STOP, &status) &&
        GetLastError() != ERROR_SERVICE_NOT_ACTIVE) {
      return false;
    }
    stopped_ = WaitForServiceState(service_, SERVICE_STOPPED);
    return stopped_;
  }

  bool Start() {
    if (!service_) return false;
    if (!StartServiceW(service_, 0, nullptr) &&
        GetLastError() != ERROR_SERVICE_ALREADY_RUNNING) {
      return false;
    }
    return WaitForServiceState(service_, SERVICE_RUNNING);
  }

  bool stopped() const { return stopped_; }

 private:
  SC_HANDLE manager_ = nullptr;
  SC_HANDLE service_ = nullptr;
  bool stopped_ = false;
};

bool ReadFileBytes(const std::wstring& path, std::vector<BYTE>* out) {
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE) return false;
  LARGE_INTEGER size;
  bool ok = GetFileSizeEx(f, &size) && size.QuadPart < (64ll << 20);
  if (ok) {
    out->resize(size_t(size.QuadPart));
    DWORD read = 0;
    ok = out->empty() ||
         (ReadFile(f, out->data(), DWORD(out->size()), &read, nullptr) &&
          read == out->size());
  }
  CloseHandle(f);
  return ok;
}

bool SameFileContents(const std::wstring& a, const std::wstring& b) {
  std::vector<BYTE> x, y;
  return ReadFileBytes(a, &x) && ReadFileBytes(b, &y) && x == y;
}

std::wstring InstalledDllPath() {
  Key root = OpenRead(kLumaRoot);
  if (!root) return L"";
  RawValue v;
  if (!ReadRaw(root.get(), L"DllPath", &v)) return L"";
  const auto items = ParseMultiString(v);
  return items.empty() ? L"" : items[0];
}

// ---------------------------------------------------------------------------
// Checking the mic still works.

std::wstring HeartbeatPath() { return ConfigDirectory() + L"\\alive.bin"; }

uint64_t HeartbeatFrames() {
  std::vector<BYTE> data;
  uint64_t frames = 0;
  if (ReadFileBytes(HeartbeatPath(), &data) && data.size() == sizeof frames) {
    std::memcpy(&frames, data.data(), sizeof frames);
  }
  return frames;
}

struct Recording {
  bool opened = false;
  uint64_t frames = 0;
  uint32_t rate = 0;
  // Any sample that wasn't exactly zero. A real mic always has some noise
  // floor, so a stream of pure digital silence means the path is broken.
  bool sound = false;

  // At least a quarter of the time's worth of frames: a stalled graph
  // delivers nothing, a live one delivers all of it.
  bool flowing() const {
    return rate != 0 && frames >= uint64_t(rate) * kRecordMs / 1000 / 4;
  }

  static constexpr DWORD kRecordMs = 1500;
};

template <typename T>
void SafeRelease(T*& p) {
  if (p) p->Release();
  p = nullptr;
}

// Records from the mic the way any app would, in shared mode at its own mix
// format.
Recording Record(const std::wstring& device_id) {
  Recording r;
  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  IAudioClient* client = nullptr;
  IAudioCaptureClient* capture = nullptr;
  WAVEFORMATEX* format = nullptr;
  r.opened =
      SUCCEEDED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                 CLSCTX_ALL, IID_PPV_ARGS(&enumerator))) &&
      SUCCEEDED(enumerator->GetDevice(device_id.c_str(), &device)) &&
      SUCCEEDED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                 reinterpret_cast<void**>(&client))) &&
      SUCCEEDED(client->GetMixFormat(&format)) &&
      SUCCEEDED(client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 2000000, 0,
                                   format, nullptr)) &&
      SUCCEEDED(client->GetService(IID_PPV_ARGS(&capture))) &&
      SUCCEEDED(client->Start());
  if (r.opened) {
    r.rate = format->nSamplesPerSec;
    const size_t frame_bytes = format->nBlockAlign;
    const ULONGLONG end = GetTickCount64() + Recording::kRecordMs;
    bool failed = false;
    while (!failed && GetTickCount64() < end) {
      Sleep(10);
      for (;;) {
        UINT32 packet = 0;
        if (FAILED(capture->GetNextPacketSize(&packet))) {
          failed = true;
          break;
        }
        if (packet == 0) break;
        BYTE* data = nullptr;
        UINT32 frames = 0;
        DWORD flags = 0;
        if (FAILED(capture->GetBuffer(&data, &frames, &flags, nullptr,
                                      nullptr))) {
          failed = true;
          break;
        }
        r.frames += frames;
        if (!r.sound && !(flags & AUDCLNT_BUFFERFLAGS_SILENT) && data) {
          const size_t bytes = size_t(frames) * frame_bytes;
          for (size_t i = 0; i < bytes && !r.sound; i++) r.sound = data[i] != 0;
        }
        capture->ReleaseBuffer(frames);
      }
    }
    client->Stop();
  }
  SafeRelease(capture);
  SafeRelease(client);
  SafeRelease(device);
  SafeRelease(enumerator);
  CoTaskMemFree(format);
  return r;
}

// Right after the audio service starts, the endpoint can take a few seconds
// to come back; keep trying until it opens.
Recording RecordWhenReady(const std::wstring& device_id) {
  Recording r;
  for (int attempt = 0; attempt < 12; attempt++) {
    r = Record(device_id);
    if (r.opened && r.flowing()) return r;
    Sleep(500);
  }
  return r;
}

// The mic records like it did before, and it did so through luma's APO.
bool StillWorks(const std::wstring& device_id, const Recording& before) {
  const Recording after = RecordWhenReady(device_id);
  if (!after.opened || !after.flowing()) return false;
  if (before.sound && !after.sound) return false;
  // The APO writes its counter every ~300 ms; give it a moment to land.
  for (int i = 0; i < 10; i++) {
    if (HeartbeatFrames() > 0) return true;
    Sleep(100);
  }
  return false;
}

// ---------------------------------------------------------------------------
// Install.

// Protected DACL: SYSTEM and Administrators full, Users modify (luma writes
// the curve unelevated), LOCAL SERVICE modify (audiodg runs as it and
// writes alive.bin).
bool PrepareConfigDirectory() {
  const std::wstring luma = KnownFolder(FOLDERID_ProgramData) + L"\\luma";
  const std::wstring dir = ConfigDirectory();
  CreateDirectoryW(luma.c_str(), nullptr);
  CreateDirectoryW(dir.c_str(), nullptr);
  PSECURITY_DESCRIPTOR sd = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
          L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1301bf;;;BU)"
          L"(A;OICI;0x1301bf;;;LS)",
          SDDL_REVISION_1, &sd, nullptr)) {
    return false;
  }
  BOOL present = FALSE, defaulted = FALSE;
  PACL dacl = nullptr;
  bool ok = GetSecurityDescriptorDacl(sd, &present, &dacl, &defaulted) &&
            SetNamedSecurityInfoW(const_cast<LPWSTR>(dir.c_str()), SE_FILE_OBJECT,
                                  DACL_SECURITY_INFORMATION |
                                      PROTECTED_DACL_SECURITY_INFORMATION,
                                  nullptr, nullptr, dacl, nullptr) == ERROR_SUCCESS;
  LocalFree(sd);
  return ok;
}

bool CopyDll(std::wstring* installed_path) {
  const std::wstring source = SelfDirectory() + L"\\luma_apo.dll";
  const std::wstring dir = InstallDirectory();
  CreateDirectoryW((KnownFolder(FOLDERID_ProgramFiles) + L"\\luma").c_str(), nullptr);
  CreateDirectoryW(dir.c_str(), nullptr);

  const std::wstring previous = InstalledDllPath();
  std::wstring target = dir + L"\\luma_apo.dll";
  if (!CopyFileW(source.c_str(), target.c_str(), FALSE)) {
    // Still mapped by an audiodg that would not stop: install beside it
    // and let the old copy go at the next reboot.
    wchar_t name[64];
    swprintf_s(name, L"\\luma_apo-%llu.dll", GetTickCount64());
    target = dir + name;
    if (!CopyFileW(source.c_str(), target.c_str(), FALSE)) return false;
  }
  if (!previous.empty() && Lower(previous) != Lower(target) &&
      !DeleteFileW(previous.c_str())) {
    MoveFileExW(previous.c_str(), nullptr, MOVEFILE_DELAY_UNTIL_REBOOT);
  }
  *installed_path = target;
  return true;
}

bool RegisterApo(const std::wstring& dll_path) {
  const std::wstring clsid = luma_apo::kVoiceEqClsidString;
  Key com = OpenPrivileged(std::wstring(kClsidRoot) + L"\\" + clsid, true);
  Key server = OpenPrivileged(
      std::wstring(kClsidRoot) + L"\\" + clsid + L"\\InprocServer32", true);
  if (!com || !server) return false;
  if (!WriteString(com.get(), nullptr, luma_apo::kVoiceEqFriendlyName) ||
      !WriteString(server.get(), nullptr, dll_path) ||
      !WriteString(server.get(), L"ThreadingModel", L"Both")) {
    return false;
  }

  Key apo = OpenPrivileged(std::wstring(kApoRoot) + L"\\" + clsid, true);
  if (!apo) return false;
  const HKEY k = apo.get();
  return WriteString(k, L"FriendlyName", luma_apo::kVoiceEqFriendlyName) &&
         WriteString(k, L"Copyright", L"luma") &&
         WriteDword(k, L"MajorVersion", 1) && WriteDword(k, L"MinorVersion", 0) &&
         WriteDword(k, L"Flags", 0x1 | 0x2 | 0x4 | 0x8) &&
         WriteDword(k, L"MinInputConnections", 1) &&
         WriteDword(k, L"MaxInputConnections", 1) &&
         WriteDword(k, L"MinOutputConnections", 1) &&
         WriteDword(k, L"MaxOutputConnections", 1) &&
         WriteDword(k, L"MaxInstances", 0xFFFFFFFF) &&
         WriteDword(k, L"NumAPOInterfaces", 1) &&
         WriteString(k, L"APOInterface0",
                     L"{FD7F2B29-24D0-4B5C-B177-592C39F9CA10}");
}

// Records what the endpoint looked like before luma touched it, once: a
// reinstall must not overwrite the original with luma's own values.
bool BackUpEndpoint(HKEY fx, const std::wstring& guid,
                    const std::wstring& device_id) {
  const std::wstring path = std::wstring(kEndpointsRoot) + L"\\" + guid;
  if (KeyExists(path)) return true;
  Key backup = OpenPrivileged(path, true);
  if (!backup) return false;
  std::vector<std::wstring> absent;
  for (const wchar_t* name : kTouched) {
    RawValue v;
    if (ReadRaw(fx, name, &v)) {
      if (!WriteRaw(backup.get(), name, v)) return false;
    } else {
      absent.push_back(name);
    }
  }
  return WriteMultiString(backup.get(), kAbsentValue, absent) &&
         WriteString(backup.get(), kDeviceIdValue, device_id);
}

bool AttachToEndpoint(const std::wstring& guid, const std::wstring& device_id,
                      const Slot& slot) {
  const std::wstring endpoint = kCaptureRoot + guid;
  if (!KeyExists(endpoint)) return false;
  Key fx = OpenPrivileged(endpoint + L"\\FxProperties", true);
  if (!fx) return false;
  if (!BackUpEndpoint(fx.get(), guid, device_id)) return false;

  const std::wstring ours = luma_apo::kVoiceEqClsidString;

  // Keep whatever the driver already runs (noise suppression, echo
  // cancellation...) and add luma last, so the EQ shapes the cleaned voice.
  std::vector<std::wstring> chain;
  RawValue v;
  if (ReadRaw(fx.get(), slot.composite, &v)) {
    chain = ParseMultiString(v);
  } else if (ReadRaw(fx.get(), slot.legacy, &v)) {
    chain = ParseMultiString(v);
  }
  std::vector<std::wstring> next;
  for (const auto& id : chain) {
    if (IsGuid(id) && !SameGuid(id, ours)) next.push_back(id);
  }
  next.push_back(ours);
  if (!WriteMultiString(fx.get(), slot.composite, next)) return false;

  RawValue association;
  if (!ReadRaw(fx.get(), kAssociation, &association) &&
      !WriteString(fx.get(), kAssociation, kAnyNodeType)) {
    return false;
  }

  // Discord records in the communications category, which Windows runs in
  // its own processing mode. When luma creates the list it claims both, so
  // the call hears the EQ too; an existing list is only extended with the
  // default mode, to leave the driver's own effects as they were.
  std::vector<std::wstring> modes;
  RawValue m;
  if (ReadRaw(fx.get(), slot.modes, &m)) {
    modes = ParseMultiString(m);
    bool has_default = false;
    for (const auto& mode : modes) has_default |= SameGuid(mode, kDefaultMode);
    if (!has_default) {
      modes.push_back(kDefaultMode);
      if (!WriteMultiString(fx.get(), slot.modes, modes)) return false;
    }
  } else if (!WriteMultiString(fx.get(), slot.modes,
                               {kDefaultMode, kCommunicationsMode})) {
    return false;
  }

  RawValue disabled;
  if (ReadRaw(fx.get(), kDisableSysFx, &disabled) && disabled.type == REG_DWORD &&
      disabled.data.size() == sizeof(DWORD) &&
      *reinterpret_cast<const DWORD*>(disabled.data.data()) != 0) {
    if (!WriteDword(fx.get(), kDisableSysFx, 0)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Uninstall.

bool DetachFromEndpoint(const std::wstring& guid) {
  const std::wstring backup_path = std::wstring(kEndpointsRoot) + L"\\" + guid;
  Key backup = OpenPrivileged(backup_path, false);
  Key fx = OpenPrivileged(kCaptureRoot + guid + L"\\FxProperties", false);

  if (fx && backup) {
    for (const wchar_t* name : kTouched) {
      RawValue v;
      if (ReadRaw(backup.get(), name, &v)) {
        WriteRaw(fx.get(), name, v);
      }
    }
    RawValue absent;
    if (ReadRaw(backup.get(), kAbsentValue, &absent)) {
      for (const auto& name : ParseMultiString(absent)) {
        bool known = false;
        for (const wchar_t* t : kTouched) known |= name == t;
        if (known) RegDeleteValueW(fx.get(), name.c_str());
      }
    }
  } else if (fx) {
    for (const Slot& slot : kSlots) {
      RawValue v;
      if (!ReadRaw(fx.get(), slot.composite, &v)) continue;
      std::vector<std::wstring> kept;
      for (const auto& id : ParseMultiString(v)) {
        if (!SameGuid(id, luma_apo::kVoiceEqClsidString)) kept.push_back(id);
      }
      if (kept.empty()) {
        RegDeleteValueW(fx.get(), slot.composite);
      } else {
        WriteMultiString(fx.get(), slot.composite, kept);
      }
    }
  }
  backup = Key();
  const LSTATUS s = RegDeleteTreeW(HKEY_LOCAL_MACHINE, backup_path.c_str());
  return s == ERROR_SUCCESS || s == ERROR_FILE_NOT_FOUND;
}

std::vector<std::wstring> InstalledEndpoints() {
  Key endpoints = OpenRead(kEndpointsRoot);
  if (!endpoints) return {};
  std::vector<std::wstring> guids;
  for (const auto& name : SubkeyNames(endpoints.get())) {
    if (IsGuid(name)) guids.push_back(name);
  }
  return guids;
}

void RemoveApoIfUnused() {
  if (!InstalledEndpoints().empty()) return;
  const std::wstring clsid = luma_apo::kVoiceEqClsidString;
  Key apos = OpenPrivileged(kApoRoot, false);
  if (apos) RegDeleteTreeW(apos.get(), clsid.c_str());
  Key classes = OpenPrivileged(kClsidRoot, false);
  if (classes) RegDeleteTreeW(classes.get(), clsid.c_str());

  const std::wstring dll = InstalledDllPath();
  if (!dll.empty() && !DeleteFileW(dll.c_str())) {
    MoveFileExW(dll.c_str(), nullptr, MOVEFILE_DELAY_UNTIL_REBOOT);
  }
  RegDeleteTreeW(HKEY_LOCAL_MACHINE, kLumaRoot);
}

// ---------------------------------------------------------------------------
// Commands.

int Status() {
  const std::wstring dll = InstalledDllPath();
  const auto guids = InstalledEndpoints();
  const bool installed = !dll.empty() && !guids.empty();
  const bool current =
      installed && SameFileContents(SelfDirectory() + L"\\luma_apo.dll", dll);
  std::wstring json = L"{\"installed\":";
  json += installed ? L"true" : L"false";
  json += L",\"current\":";
  json += current ? L"true" : L"false";
  json += L",\"endpoints\":[";
  for (size_t i = 0; i < guids.size(); i++) {
    if (i) json += L',';
    json += L"\"{0.0.1.00000000}." + guids[i] + L"\"";
  }
  json += L"]}";
  Print(json);
  return kOk;
}

// The same recording install relies on, for diagnosing a mic by hand.
int Check(const std::wstring& device_id) {
  const Recording r = Record(device_id);
  Print(L"{\"opened\":" + std::wstring(r.opened ? L"true" : L"false") +
        L",\"flowing\":" + (r.flowing() ? L"true" : L"false") +
        L",\"sound\":" + (r.sound ? L"true" : L"false") +
        L",\"frames\":" + std::to_wstring(r.frames) +
        L",\"rate\":" + std::to_wstring(r.rate) + L"}");
  return kOk;
}

int Install(const std::wstring& device_id) {
  std::wstring guid;
  if (!EndpointGuid(device_id, &guid)) return kUsage;
  if (GetFileAttributesW((SelfDirectory() + L"\\luma_apo.dll").c_str()) ==
      INVALID_FILE_ATTRIBUTES) {
    return kFilesMissing;
  }
  if (!KeyExists(kCaptureRoot + guid)) return kNoSuchDevice;

  // Without a working mic to compare against, a silent result afterwards
  // would prove nothing, so don't touch it at all.
  const Recording before = RecordWhenReady(device_id);
  if (!before.opened || !before.flowing()) {
    Log(L"install skipped for " + guid + L": the mic isn't recording");
    return kMicNotRecording;
  }

  // An audio service that won't restart means the change can't be tested,
  // and an untested change is how a mic ends up silent.
  AudioService audio;
  if (!audio.Stop()) {
    audio.Start();
    Log(L"install skipped for " + guid + L": audio service would not stop");
    return kFailed;
  }
  std::wstring dll_path;
  bool ok = PrepareConfigDirectory() && CopyDll(&dll_path);
  if (ok) {
    Key root = OpenPrivileged(kLumaRoot, true);
    ok = root && WriteString(root.get(), L"DllPath", dll_path) &&
         RegisterApo(dll_path);
  }

  bool working = false;
  for (const Slot& slot : kSlots) {
    if (!ok) break;
    DeleteFileW(HeartbeatPath().c_str());
    ok = AttachToEndpoint(guid, device_id, slot);
    const bool started = audio.Start();
    if (ok && started && StillWorks(device_id, before)) {
      Log(L"installed on " + guid + L" (" + slot.name + L" slot)");
      working = true;
      break;
    }
    Log(L"the " + std::wstring(slot.name) + L" slot didn't work on " + guid +
        L", restoring it");
    ok = ok && started && audio.Stop();
    DetachFromEndpoint(guid);
  }
  if (!working) {
    DetachFromEndpoint(guid);
    RemoveApoIfUnused();
    audio.Start();
    return ok ? kIncompatible : kFailed;
  }
  return kOk;
}

int Uninstall(const std::wstring* device_id) {
  std::vector<std::wstring> guids;
  if (device_id) {
    std::wstring guid;
    if (!EndpointGuid(*device_id, &guid)) return kUsage;
    guids.push_back(guid);
  } else {
    guids = InstalledEndpoints();
  }
  AudioService audio;
  audio.Stop();
  bool ok = true;
  for (const auto& guid : guids) {
    ok &= DetachFromEndpoint(guid);
    Log(L"removed from " + guid);
  }
  RemoveApoIfUnused();
  const bool restarted = audio.Start();
  if (!ok) return kFailed;
  return restarted && audio.stopped() ? kOk : kRestartNeeded;
}

int Run(const std::vector<std::wstring>& args) {
  if (args.size() < 2) return kUsage;
  const std::wstring& command = args[1];
  if (command == L"status") return Status();
  if (command == L"check") return args.size() == 3 ? Check(args[2]) : kUsage;

  const bool needs_device = command == L"install" || command == L"uninstall";
  if (needs_device ? args.size() != 3
                   : (command != L"uninstall-all" || args.size() != 2)) {
    return kUsage;
  }
  if (needs_device) {
    std::wstring guid;
    if (!EndpointGuid(args[2], &guid)) return kUsage;
  }
  // Nothing to undo: don't raise a UAC prompt for it (luma's uninstaller
  // calls this unconditionally).
  if (command == L"uninstall-all" && InstalledEndpoints().empty() &&
      InstalledDllPath().empty()) {
    return kOk;
  }

  if (!IsElevated()) return RelaunchElevated(args);
  if (!EnablePrivilege(SE_BACKUP_NAME) || !EnablePrivilege(SE_RESTORE_NAME)) {
    return kFailed;
  }
  if (command == L"install") return Install(args[2]);
  if (command == L"uninstall") return Uninstall(&args[2]);
  return Uninstall(nullptr);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argc = 0;
  LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) return kUsage;
  std::vector<std::wstring> args(argv, argv + argc);
  LocalFree(argv);
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const int code = Run(args);
  CoUninitialize();
  return code;
}

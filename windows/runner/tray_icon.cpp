#include "tray_icon.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include "resource.h"

namespace {

constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kTrayIconId = 1;
constexpr UINT kMenuOpen = 1;
constexpr UINT kMenuQuit = 2;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int length = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                                     static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring utf16(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                        static_cast<int>(utf8.size()), utf16.data(), length);
  return utf16;
}

std::wstring StringArgument(const flutter::EncodableMap& map, const char* key,
                            const std::wstring& fallback) {
  auto found = map.find(flutter::EncodableValue(key));
  if (found == map.end()) return fallback;
  const auto* value = std::get_if<std::string>(&found->second);
  if (value == nullptr || value->empty()) return fallback;
  return Utf16FromUtf8(*value);
}

}  // namespace

void ShowAndFocusWindow(HWND window) {
  if (window == nullptr) return;
  ::ShowWindow(window, ::IsIconic(window) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(window);
}

TrayIcon::TrayIcon(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window),
      taskbar_created_message_(::RegisterWindowMessageW(L"TaskbarCreated")) {
  icon_ = static_cast<HICON>(::LoadImageW(
      ::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      ::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CYSMICON), 0));
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "luma/tray", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "setLabels") {
      result->NotImplemented();
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args != nullptr) {
      tooltip_ = StringArgument(*args, "tooltip", tooltip_);
      open_label_ = StringArgument(*args, "open", open_label_);
      quit_label_ = StringArgument(*args, "quit", quit_label_);
      Update();
    }
    result->Success();
  });
  Add();
}

TrayIcon::~TrayIcon() {
  channel_->SetMethodCallHandler(nullptr);
  Remove();
  if (icon_ != nullptr) ::DestroyIcon(icon_);
}

void TrayIcon::FillData(NOTIFYICONDATAW* data) const {
  *data = {};
  data->cbSize = sizeof(NOTIFYICONDATAW);
  data->hWnd = window_;
  data->uID = kTrayIconId;
  data->uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data->uCallbackMessage = kTrayCallbackMessage;
  data->hIcon = icon_;
  wcsncpy_s(data->szTip, tooltip_.c_str(), _TRUNCATE);
}

void TrayIcon::Add() {
  NOTIFYICONDATAW data;
  FillData(&data);
  added_ = ::Shell_NotifyIconW(NIM_ADD, &data) != FALSE;
}

void TrayIcon::Remove() {
  if (!added_) return;
  NOTIFYICONDATAW data;
  FillData(&data);
  ::Shell_NotifyIconW(NIM_DELETE, &data);
  added_ = false;
}

void TrayIcon::Update() {
  if (!added_) {
    Add();
    return;
  }
  NOTIFYICONDATAW data;
  FillData(&data);
  ::Shell_NotifyIconW(NIM_MODIFY, &data);
}

void TrayIcon::ShowMenu() {
  HMENU menu = ::CreatePopupMenu();
  if (menu == nullptr) return;
  ::AppendMenuW(menu, MF_STRING, kMenuOpen, open_label_.c_str());
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kMenuQuit, quit_label_.c_str());
  ::SetMenuDefaultItem(menu, kMenuOpen, FALSE);

  POINT cursor;
  ::GetCursorPos(&cursor);
  // Without owning the foreground the menu never closes when the user clicks
  // elsewhere, and the trailing WM_NULL is the documented companion fix.
  ::SetForegroundWindow(window_);
  UINT command = ::TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
      cursor.x, cursor.y, 0, window_, nullptr);
  ::PostMessageW(window_, WM_NULL, 0, 0);
  ::DestroyMenu(menu);

  if (command == kMenuOpen) {
    ShowAndFocusWindow(window_);
  } else if (command == kMenuQuit) {
    // Posted rather than done here: destroying the window tears this object
    // down, which must not happen while one of its methods is running.
    ::PostMessageW(window_, kQuitAppMessage, 0, 0);
  }
}

bool TrayIcon::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == taskbar_created_message_) {
    // Explorer restarted and forgot every icon.
    added_ = false;
    Add();
    return true;
  }
  if (message != kTrayCallbackMessage) return false;
  switch (LOWORD(lparam)) {
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
      ShowAndFocusWindow(window_);
      break;
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
      ShowMenu();
      break;
  }
  return true;
}

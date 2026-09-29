#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

// Name of the message a second luma.exe posts to the running one, asking it to
// bring its window back instead of starting another copy.
constexpr const wchar_t kShowWindowMessageName[] = L"luma-show-window";

// Posted to the main window when the user picks Quit. WM_CLOSE cannot be used:
// window_manager's prevent-close turns it into a hide.
constexpr UINT kQuitAppMessage = WM_APP + 2;

// Shows a hidden, minimised or backgrounded top-level window and focuses it.
void ShowAndFocusWindow(HWND window);

// The notification-area icon for the main window.
//
// Closing luma's window only hides it: the process stays resident so the pet's
// global hotkey keeps working. Without an icon a hidden luma is invisible, and
// the only way out is Task Manager. The icon brings the window back and offers
// a real Quit. Menu labels come from Dart ("luma/tray" → setLabels) so they
// follow the app's language; English stands in until they arrive.
class TrayIcon {
 public:
  TrayIcon(flutter::BinaryMessenger* messenger, HWND window);
  ~TrayIcon();

  // Returns true when |message| belonged to the tray and has been handled.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void Add();
  void Remove();
  void Update();
  void ShowMenu();
  void FillData(NOTIFYICONDATAW* data) const;

  HWND window_;
  HICON icon_ = nullptr;
  bool added_ = false;
  UINT taskbar_created_message_;
  std::wstring tooltip_ = L"luma";
  std::wstring open_label_ = L"Open luma";
  std::wstring quit_label_ = L"Quit luma";
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_TRAY_ICON_H_

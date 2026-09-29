#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "native_webview.h"
#include "tray_icon.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Real WebView2 windows for pages too heavy for a captured texture.
  std::unique_ptr<NativeWebviewManager> native_webviews_;

  // The notification-area icon that reopens or quits a hidden luma.
  std::unique_ptr<TrayIcon> tray_icon_;

  // Posted by a second luma.exe that found this one already running.
  UINT show_window_message_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

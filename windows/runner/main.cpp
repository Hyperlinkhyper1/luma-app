#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "tray_icon.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

#ifdef NDEBUG
  // One luma per user session. Closing the window only hides it (the pet's
  // hotkey lives in this process), so launching luma again used to start a
  // second invisible copy with the same databases open. Instead, wake the one
  // that is running and step aside. Debug builds skip this so `flutter run`
  // still starts next to an installed luma.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, FALSE, L"Local\\luma-single-instance");
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"luma");
    if (existing != nullptr) {
      DWORD owner = 0;
      ::GetWindowThreadProcessId(existing, &owner);
      ::AllowSetForegroundWindow(owner);
      ::PostMessageW(existing, ::RegisterWindowMessageW(kShowWindowMessageName),
                     0, 0);
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }
#endif

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"luma", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

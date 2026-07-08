import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'usage_tracker_base.dart';

/// Windows implementation of the foreground-app tracker.
///
/// On each poll we walk: foreground HWND → owning PID → process image path →
/// filename. The window title is captured too, but only the executable name
/// is used to group sessions — switching tabs inside Chrome doesn't start a
/// new session.
class UsageTracker {
  UsageTracker._();

  static bool get supported => Platform.isWindows;

  /// Returns the foreground app right now, or null when nothing useful is
  /// focused (no user session, lock screen, etc.). Errors from the Win32
  /// calls are swallowed and treated as "no app" — a transient permission
  /// glitch shouldn't crash the whole tracker loop.
  static UsageAppInfo? current() {
    if (!Platform.isWindows) return null;

    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return null;

    final pidPtr = calloc<DWORD>();
    String? windowTitle;
    String processPath = '';
    try {
      GetWindowThreadProcessId(hwnd, pidPtr);
      final pid = pidPtr.value;
      if (pid == 0) return null;

      windowTitle = _readWindowText(hwnd);
      processPath = _readProcessPath(pid) ?? '';
    } finally {
      calloc.free(pidPtr);
    }

    if (processPath.isEmpty) return null;
    final fileName = processPath.split('\\').last;
    if (fileName.isEmpty) return null;

    return UsageAppInfo(
      appName: _friendlyName(fileName),
      processName: fileName.toLowerCase(),
      windowTitle: windowTitle,
    );
  }

  /// Reads up to 255 wide-chars from the window's title bar. Returns null
  /// when the window has no title or the call fails (common for hidden /
  /// out-of-process windows).
  static String? _readWindowText(int hwnd) {
    final buffer = calloc<Uint16>(256);
    try {
      final length = GetWindowText(hwnd, buffer.cast<Utf16>(), 256);
      if (length <= 0) return null;
      return buffer.cast<Utf16>().toDartString(length: length);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Returns the full path of the executable backing [pid], or null when the
  /// process can't be opened (already gone, access denied, …).
  static String? _readProcessPath(int pid) {
    const processQueryLimitedInformation = 0x1000;
    final hProcess = OpenProcess(processQueryLimitedInformation, FALSE, pid);
    if (hProcess == 0) return null;

    final sizePtr = calloc<DWORD>();
    final buffer = calloc<Uint16>(1024);
    try {
      sizePtr.value = 1024;
      final ok =
          QueryFullProcessImageName(hProcess, 0, buffer.cast<Utf16>(), sizePtr);
      if (ok == 0) return null;
      return buffer.cast<Utf16>().toDartString(length: sizePtr.value);
    } finally {
      calloc.free(sizePtr);
      calloc.free(buffer);
      CloseHandle(hProcess);
    }
  }

  /// Best-effort human-readable name for an executable. Falls back to the
  /// raw filename when the file can't be opened (most common case — we run
  /// in user space and don't need the version-info round-trip for the common
  /// apps). Capitalises the first letter so "chrome.exe" reads as "Chrome".
  static String _friendlyName(String fileName) {
    final base = fileName.toLowerCase();
    if (base.endsWith('.exe')) {
      final stem = base.substring(0, base.length - 4);
      if (stem.isEmpty) return fileName;
      return stem[0].toUpperCase() + stem.substring(1);
    }
    return fileName;
  }
}
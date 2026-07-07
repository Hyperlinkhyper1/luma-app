import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Which mouse button a click should use.
enum ClickButton { left, middle, right }

/// A point in screen coordinates.
class ClickPoint {
  const ClickPoint(this.x, this.y);
  final int x;
  final int y;

  @override
  String toString() => '($x, $y)';
}

/// Simulates mouse clicks via the Win32 `SendInput` API. Only Windows
/// actually sends input (guarded by [supported]); other dart:io platforms
/// compile against this same file but treat clicking as unsupported.
class ClickerEngine {
  const ClickerEngine._();

  static bool get supported => Platform.isWindows;

  /// The real system cursor position, or null if it can't be read.
  static ClickPoint? get cursorPosition {
    if (!Platform.isWindows) return null;
    final point = calloc<POINT>();
    try {
      if (GetCursorPos(point) == 0) return null;
      return ClickPoint(point.ref.x, point.ref.y);
    } finally {
      calloc.free(point);
    }
  }

  /// Clicks [button] at [at], or at the current cursor position when [at] is
  /// null. When [at] is given, the real cursor is moved there and restored
  /// to its original position afterwards, so a fixed-point click doesn't
  /// leave the mouse parked on top of the target.
  static void click({
    required ClickButton button,
    required bool doubleClick,
    ClickPoint? at,
  }) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Auto Clicker only supports Windows.');
    }

    ClickPoint? previous;
    if (at != null) {
      previous = cursorPosition;
      SetCursorPos(at.x, at.y);
    }

    final (downFlag, upFlag) = switch (button) {
      ClickButton.left => (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP),
      ClickButton.middle => (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP),
      ClickButton.right => (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP),
    };

    final clicks = doubleClick ? 2 : 1;
    for (var i = 0; i < clicks; i++) {
      _sendMouseEvent(downFlag);
      _sendMouseEvent(upFlag);
    }

    if (at != null && previous != null) {
      SetCursorPos(previous.x, previous.y);
    }
  }

  static void _sendMouseEvent(int flags) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dx = 0;
      input.ref.mi.dy = 0;
      input.ref.mi.mouseData = 0;
      input.ref.mi.dwFlags = flags;
      input.ref.mi.time = 0;
      input.ref.mi.dwExtraInfo = 0;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }
}

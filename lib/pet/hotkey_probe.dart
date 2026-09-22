import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:win32/win32.dart';

/// Whether a global hotkey can actually be claimed, asked of the OS directly.
///
/// `hotkey_manager`'s Windows plugin throws away `RegisterHotKey`'s return
/// value and reports success either way, so a chord another app already owns
/// registers "fine" and then simply never fires. This claims the same chord
/// first — on the calling thread rather than a window, which is enough for
/// Windows to tell us whether it is free — and lets it straight back go.
///
/// Returns true when the chord is available (or when we have no way to ask,
/// in which case the caller should go ahead and try).
Future<bool> isGlobalHotKeyAvailable(HotKey hotKey) async {
  if (kIsWeb || !Platform.isWindows) return true;
  final virtualKey = _windowsVirtualKey(hotKey);
  if (virtualKey == null) return true;

  // Any id will do: it only has to be unique within this thread, and the
  // registration is undone before anything else can use it.
  const probeId = 0x7107;
  final registered = RegisterHotKey(
    NULL,
    probeId,
    _windowsModifiers(hotKey.modifiers),
    virtualKey,
  );
  if (registered == 0) return false;
  UnregisterHotKey(NULL, probeId);
  return true;
}

int _windowsModifiers(List<HotKeyModifier>? modifiers) {
  var flags = 0;
  for (final modifier in modifiers ?? const <HotKeyModifier>[]) {
    flags |= switch (modifier) {
      HotKeyModifier.alt => MOD_ALT,
      HotKeyModifier.control => MOD_CONTROL,
      HotKeyModifier.shift => MOD_SHIFT,
      HotKeyModifier.meta => MOD_WIN,
      // capsLock and fn aren't modifiers Windows can register with.
      HotKeyModifier.capsLock || HotKeyModifier.fn => 0,
    };
  }
  return flags;
}

/// The Windows virtual-key code for [hotKey], or null if this key isn't one
/// we can map — in which case there is nothing useful to probe and the caller
/// simply tries the registration.
///
/// Covers what people actually bind a launcher to: letters, digits, the
/// function row and a handful of named keys. For letters and digits the
/// virtual-key code *is* the ASCII code of the uppercase character, which is
/// why the label works directly.
int? _windowsVirtualKey(HotKey hotKey) {
  final key = hotKey.logicalKey;
  if (key == LogicalKeyboardKey.space) return VK_SPACE;
  if (key == LogicalKeyboardKey.enter) return VK_RETURN;
  if (key == LogicalKeyboardKey.tab) return VK_TAB;
  if (key == LogicalKeyboardKey.escape) return VK_ESCAPE;
  if (key == LogicalKeyboardKey.backspace) return VK_BACK;

  const functionKeys = [
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9,
    LogicalKeyboardKey.f10,
    LogicalKeyboardKey.f11,
    LogicalKeyboardKey.f12,
  ];
  final function = functionKeys.indexOf(key);
  if (function >= 0) return VK_F1 + function;

  final label = key.keyLabel.toUpperCase();
  if (label.length == 1) {
    final code = label.codeUnitAt(0);
    final isLetter = code >= 0x41 && code <= 0x5A;
    final isDigit = code >= 0x30 && code <= 0x39;
    if (isLetter || isDigit) return code;
  }
  return null;
}

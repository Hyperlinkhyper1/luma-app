import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop implementation of the window chrome helpers, backed by
/// `window_manager`. On mobile (no desktop window) [hasCustomTitleBar] is false
/// and the calls fall through to no-ops, so the app keeps its default chrome.

bool get hasCustomTitleBar =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

final StreamController<void> _events = StreamController<void>.broadcast();

/// Fires whenever the window is maximized/unmaximized so a custom title bar can
/// keep its maximize/restore glyph in sync.
Stream<void> get windowEvents => _events.stream;

class _MaximizeListener extends WindowListener {
  @override
  void onWindowMaximize() => _events.add(null);
  @override
  void onWindowUnmaximize() => _events.add(null);
}

/// Hides the native title bar (keeping resize/snap) and shows the window once
/// Flutter is ready to paint, avoiding a white flash.
Future<void> initWindowChrome() async {
  if (!hasCustomTitleBar) return;
  await windowManager.ensureInitialized();
  windowManager.addListener(_MaximizeListener());
  const options = WindowOptions(
    size: Size(1200, 820),
    minimumSize: Size(940, 620),
    center: true,
    title: 'luma',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> windowStartDrag() =>
    hasCustomTitleBar ? windowManager.startDragging() : Future.value();

Future<void> windowMinimize() =>
    hasCustomTitleBar ? windowManager.minimize() : Future.value();

Future<bool> windowIsMaximized() =>
    hasCustomTitleBar ? windowManager.isMaximized() : Future.value(false);

Future<void> windowToggleMaximize() async {
  if (!hasCustomTitleBar) return;
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<void> windowClose() =>
    hasCustomTitleBar ? windowManager.close() : Future.value();

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

final StreamController<bool> _focusEvents = StreamController<bool>.broadcast();

/// Fires true when the window gains focus and false when it loses it. The pet
/// panel listens so a click anywhere else on the desktop dismisses it, the way
/// every other summoned launcher behaves.
Stream<bool> get windowFocusEvents => _focusEvents.stream;

final StreamController<void> _closeEvents = StreamController<void>.broadcast();

/// Fires when the user closes the desktop window. The process stays resident
/// for the pet, so this — not process exit — is the app's real "closing"
/// moment, and where work meant to run on close has to hook in.
Stream<void> get windowCloseEvents => _closeEvents.stream;

class _MaximizeListener extends WindowListener {
  @override
  void onWindowMaximize() => _events.add(null);
  @override
  void onWindowUnmaximize() => _events.add(null);
  @override
  void onWindowFocus() => _focusEvents.add(true);
  @override
  void onWindowBlur() => _focusEvents.add(false);

  @override
  void onWindowClose() async {
    // Keep the process resident so the pet's global hotkey continues to work
    // after the user closes the desktop window. The app can still be ended by
    // the operating system or task manager.
    _closeEvents.add(null);
    await windowManager.hide();
  }
}

/// Hides the native title bar (keeping resize/snap) and shows the window once
/// Flutter is ready to paint, avoiding a white flash.
Future<void> initWindowChrome() async {
  if (!hasCustomTitleBar) return;
  await windowManager.ensureInitialized();
  windowManager.addListener(_MaximizeListener());
  // Closing the native window must not terminate the process: the global pet
  // shortcut is owned by this process and needs to remain registered while
  // the main window is hidden.
  await windowManager.setPreventClose(true);
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

Future<void> windowClose() async {
  if (!hasCustomTitleBar) return;
  _closeEvents.add(null);
  await windowManager.hide();
}

Future<void> windowShow() async {
  if (!hasCustomTitleBar) return;
  await windowManager.show();
  await windowManager.focus();
}

// ---- Pet window ------------------------------------------------------------
//
// The luma pet is summoned with a global hotkey from anywhere on the desktop,
// so it has to be a window, not just an overlay inside an app that may well be
// hidden at the time. luma is a single-window Flutter app, so "pet mode"
// shrinks the one window we have into a small always-on-top panel and puts it
// back exactly as it was on dismiss — including a maximised or minimised
// state, which plain bounds can't describe.

/// Size of the window while the pet is up. Matches [kPetPanelSize] on the
/// Flutter side so the panel fills the window edge to edge.
const Size kPetWindowSize = Size(480, 556);

/// Everything needed to put the window back the way the user left it.
class _PetWindowRestore {
  const _PetWindowRestore({
    required this.bounds,
    required this.minimumSize,
    required this.wasMaximized,
    required this.wasMinimized,
    required this.wasVisible,
  });

  final Rect bounds;
  final Size minimumSize;
  final bool wasMaximized;
  final bool wasMinimized;
  final bool wasVisible;
}

_PetWindowRestore? _petRestore;

/// The minimum size [initWindowChrome] set. Kept here because the pet has to
/// drop below it to shrink at all, and `window_manager` has no getter for it.
const Size _appMinimumSize = Size(940, 620);

/// Whether the window is currently shrunk into the pet panel.
bool get inPetWindow => _petRestore != null;

/// Shrinks the window into the floating pet panel, remembering what it looked
/// like first. Safe to call twice — the second call is a no-op, so the
/// remembered "real" window is never overwritten with the pet's own bounds.
Future<void> enterPetWindow() async {
  if (!hasCustomTitleBar || _petRestore != null) return;
  final wasMaximized = await windowManager.isMaximized();
  final wasMinimized = await windowManager.isMinimized();
  final wasVisible = await windowManager.isVisible();
  // A maximized window reports the screen's bounds, which would restore to a
  // "manually sized to fill the screen" window rather than a maximized one —
  // so the flag above, not the rect, is what actually drives the restore.
  final bounds = await windowManager.getBounds();
  _petRestore = _PetWindowRestore(
    bounds: bounds,
    minimumSize: _appMinimumSize,
    wasMaximized: wasMaximized,
    wasMinimized: wasMinimized,
    wasVisible: wasVisible,
  );

  if (wasMinimized) await windowManager.restore();
  if (wasMaximized) await windowManager.unmaximize();
  // The app's minimum size is far larger than the panel, and setSize is
  // clamped to it, so it has to come down first.
  await windowManager.setMinimumSize(const Size(360, 380));
  await windowManager.setResizable(false);
  await windowManager.setSize(kPetWindowSize);
  // Upper third of the display, where a summoned launcher is expected to
  // appear — dead centre fights with whatever the user was reading.
  await windowManager.setAlignment(const Alignment(0, -0.45));
  await windowManager.setAlwaysOnTop(true);
  await windowManager.show();
  await windowManager.focus();
}

/// Puts the window back exactly as [enterPetWindow] found it. A no-op if the
/// pet was never up.
Future<void> exitPetWindow({bool bringToFront = false}) async {
  final restore = _petRestore;
  if (!hasCustomTitleBar || restore == null) return;
  _petRestore = null;

  await windowManager.setAlwaysOnTop(false);
  await windowManager.setResizable(true);
  await windowManager.setMinimumSize(restore.minimumSize);
  if (restore.wasMaximized) {
    await windowManager.maximize();
  } else {
    await windowManager.setBounds(restore.bounds);
  }
  // The pet had to raise the window to show itself. Unless the user is being
  // taken somewhere in the app, drop it back out of the way instead of
  // leaving a window they never asked to see sitting in front of their work.
  if (bringToFront) {
    await windowManager.show();
    await windowManager.focus();
  } else if (restore.wasMinimized) {
    await windowManager.minimize();
  } else if (!restore.wasVisible) {
    await windowManager.hide();
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Web / unsupported-platform fallback: there is no OS window to decorate, so
/// [hasCustomTitleBar] is false and every operation is a harmless no-op.

bool get hasCustomTitleBar => false;

Stream<void> get windowEvents => const Stream<void>.empty();

Stream<bool> get windowFocusEvents => const Stream<bool>.empty();

Future<void> initWindowChrome() async {}

Future<void> windowStartDrag() async {}

Future<void> windowMinimize() async {}

Future<bool> windowIsMaximized() async => false;

Future<void> windowToggleMaximize() async {}

Future<void> windowClose() async {}

Future<void> windowShow() async {}

// ---- Pet window ------------------------------------------------------------
// Without an OS window there is nothing to shrink: the pet is shown as an
// in-app overlay instead (see LumaPetOverlay).

const Size kPetWindowSize = Size(480, 556);

bool get inPetWindow => false;

Future<void> enterPetWindow() async {}

Future<void> exitPetWindow({bool bringToFront = false}) async {}

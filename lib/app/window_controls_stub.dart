import 'dart:async';

/// Web / unsupported-platform fallback: there is no OS window to decorate, so
/// [hasCustomTitleBar] is false and every operation is a harmless no-op.

bool get hasCustomTitleBar => false;

Stream<void> get windowEvents => const Stream<void>.empty();

Future<void> initWindowChrome() async {}

Future<void> windowStartDrag() async {}

Future<void> windowMinimize() async {}

Future<bool> windowIsMaximized() async => false;

Future<void> windowToggleMaximize() async {}

Future<void> windowClose() async {}

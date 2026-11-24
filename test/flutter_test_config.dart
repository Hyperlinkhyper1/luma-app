import 'dart:async';
import 'dart:ui';

import 'package:luma/l10n/current_l.dart';

/// Pins [currentL] to English for every test file.
///
/// Without this, code that reads `currentL` (enum labels, repositories,
/// anything without a BuildContext) speaks the host OS's language, so a
/// suite that passes on an English CI runner fails on a Dutch desktop.
/// Tests that want another language call `setCurrentLocale` themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setCurrentLocale(const Locale('en'));
  await testMain();
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/splash_screen.dart';

void main() {
  Widget splash(Future<void> bootstrap, VoidCallback onDone) => MaterialApp(
    home: SplashScreen(bootstrap: bootstrap, onDone: onDone),
  );

  testWidgets(
    'keeps the splash visible for five seconds when startup is ready',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(splash(Future<void>.value(), () => completed++));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4999));

      expect(completed, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(completed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('waiting for startup does not continuously draw frames', (
    tester,
  ) async {
    final bootstrap = Completer<void>();
    var completed = 0;
    await tester.pumpWidget(splash(bootstrap.future, () => completed++));
    await tester.pump(const Duration(seconds: 6));

    expect(completed, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    bootstrap.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup errors release the splash without an unhandled error', (
    tester,
  ) async {
    final bootstrap = Completer<void>();
    var completed = 0;
    await tester.pumpWidget(splash(bootstrap.future, () => completed++));
    bootstrap.completeError(StateError('Storage unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4999));

    expect(tester.takeException(), isNull);
    expect(completed, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('completion after disposal cannot call onDone', (tester) async {
    final bootstrap = Completer<void>();
    var completed = 0;
    await tester.pumpWidget(splash(bootstrap.future, () => completed++));
    await tester.pumpWidget(const SizedBox.shrink());
    bootstrap.complete();
    await tester.pump();

    expect(completed, 0);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/school/ui/quiz_pdf_options.dart';
import 'package:luma/features/plugins/installed/school/ui/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('PDF button opens the options screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(body: TestsTab()),
      ),
    );
    await tester.ensureVisible(find.text('Oefentoets als PDF'));
    await tester.tap(find.text('Oefentoets als PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Stel je oefentoets samen'), findsOneWidget);
  });
  testWidgets('export renders in the background and passes PDF bytes to save', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: QuizPdfOptions(
          save: (bytes) async {
            expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
            saved = true;
            return null;
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('pdf-total')), '3');
    await tester.pump();
    await tester.ensureVisible(find.text('PDF maken en opslaan'));
    await tester.runAsync(() async {
      final callback = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      await Function.apply(callback, []);
    });
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.text('Opslaan geannuleerd.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('custom counts, mixed order and validation work on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: LumaTheme.dark, home: const QuizPdfOptions()),
    );
    await tester.tap(find.text('Aantal per vak'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('pdf-count-rekenen')),
      '7',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Gemengd'));
    await tester.tap(find.text('Gemengd'));
    await tester.pump();
    expect(find.text('27 vragen · 3 vakken · gemengd'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('pdf-count-rekenen')));
    await tester.enterText(
      find.byKey(const ValueKey('pdf-count-rekenen')),
      '999',
    );
    await tester.pump();
    expect(find.textContaining('Kies voor Rekenen tussen'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

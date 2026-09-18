import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/logic/quiz_bank.dart';
import 'package:luma/features/plugins/installed/school/ui/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

// The Tests tab holds no repository and touches no database, so it can be
// pumped on its own — no scope, no storage guard.
Widget _app() => MaterialApp(
  theme: LumaTheme.dark,
  home: const Scaffold(body: TestsTab()),
);

/// Pumps a few frames instead of settling.
///
/// The test header carries a clock that ticks once a second, so it always has
/// another frame scheduled and `pumpAndSettle` would run until it times out.
/// 320 ms is enough for the 200 ms phase transition and stays under one tick.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Unmounts the tree so the header's periodic timer is cancelled before the
/// test ends.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// Taps the option tile whose visible text is [label].
Future<void> _tapOption(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pump();
}

// Every test widens the surface first: a phone-sized window would clip the
// subject grid and the review list off the bottom.
void main() {
  testWidgets('open spelling answers survive navigation on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.ensureVisible(find.text('Taalverzorging'));
    await tester.tap(find.text('Taalverzorging'));
    await tester.pump();
    await tester.ensureVisible(find.text('10 vragen'));
    await tester.tap(find.text('10 vragen'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start toets taalverzorging'));
    await tester.tap(find.text('Start toets taalverzorging'));
    await _settle(tester);
    var index = 0;
    while (find.byType(TextFormField).evaluate().isEmpty && index < 9) {
      await tester.tap(find.text('Volgende'));
      await tester.pump();
      index++;
    }
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'mijn antwoord');
    await tester.pump();
    expect(find.textContaining('1 beantwoord'), findsOneWidget);
    final forward = index < 9;
    await tester.tap(find.text(forward ? 'Volgende' : 'Vorige'));
    await tester.pump();
    await tester.tap(find.text(forward ? 'Vorige' : 'Volgende'));
    await tester.pump();
    expect(find.text('mijn antwoord'), findsOneWidget);
    expect(find.textContaining('Goede antwoord:'), findsNothing);
    expect(tester.takeException(), isNull);
    await _teardown(tester);
  });

  testWidgets(
    'setup lists every subject and blocks start until one is picked',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());

      for (final s in QuizBank.subjects) {
        expect(find.text(s.name), findsOneWidget);
      }
      expect(find.text('Kies eerst een vak'), findsOneWidget);

      await tester.tap(find.text('Rekenen'));
      await tester.pump();
      expect(find.text('Start toets rekenen'), findsOneWidget);
    },
  );

  testWidgets('every subject offers at least 50 questions on its card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());

    for (final s in QuizBank.subjects) {
      expect(s.questions.length, greaterThanOrEqualTo(50));
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text(s.name),
                matching: find.byType(GestureDetector),
              )
              .first,
          matching: find.textContaining('${s.questions.length} vragen'),
        ),
        findsOneWidget,
        reason: '${s.name} should advertise its pool size',
      );
    }
  });

  testWidgets(
    'running a test shows one question at a time and tracks progress',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.tap(find.text('Engels'));
      await tester.pump();
      await tester.tap(find.text('10 vragen'));
      await tester.pump();
      await tester.tap(find.text('Start toets engels'));
      await _settle(tester);

      expect(find.textContaining('Vraag 1 van 10'), findsOneWidget);
      expect(find.textContaining('0 beantwoord'), findsOneWidget);

      await tester.tap(find.text('Volgende'));
      await tester.pump();
      expect(find.textContaining('Vraag 2 van 10'), findsOneWidget);

      await tester.tap(find.text('Vorige'));
      await tester.pump();
      expect(find.textContaining('Vraag 1 van 10'), findsOneWidget);

      await _teardown(tester);
    },
  );

  testWidgets('the header shows a running clock while you answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('Rekenen'));
    await tester.pump();
    await tester.tap(find.text('Start toets rekenen'));
    await _settle(tester);

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    final clock = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data ?? ''),
    );
    expect(clock, findsOneWidget);

    // The clock keeps its own timer: crossing a tick must not throw and must
    // leave exactly one clock on screen.
    await tester.pump(const Duration(seconds: 2));
    expect(clock, findsOneWidget);

    await _teardown(tester);
  });

  testWidgets(
    'the review shows the right answer for a question you got wrong',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.tap(find.text('Rekenen'));
      await tester.pump();
      await tester.tap(find.text('10 vragen'));
      await tester.pump();
      await tester.tap(find.text('Start toets rekenen'));
      await _settle(tester);

      // Answer every question with the first option, then hand it in. Some are
      // right and some are wrong, which is exactly what the review is for.
      for (var i = 0; i < 10; i++) {
        if (find.byType(TextFormField).evaluate().isNotEmpty) {
          await tester.enterText(find.byType(TextFormField), '0');
        } else {
          await tester.tap(find.text('A').last);
        }
        await tester.pump();
        if (i < 9) {
          await tester.tap(find.text('Volgende'));
          await tester.pump();
        }
      }
      await tester.tap(find.text('Nakijken'));
      await _settle(tester);

      expect(find.textContaining('van 10 goed'), findsOneWidget);
      expect(find.text('Per onderdeel'), findsOneWidget);
      // Every reviewed question spells out the correct answer.
      expect(find.textContaining('Goede antwoord:'), findsWidgets);
      expect(find.text('Nieuwe toets'), findsOneWidget);
      expect(find.text('Ander vak'), findsOneWidget);

      await _teardown(tester);
    },
  );

  testWidgets('answering everything correctly gives 100%', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('Aardrijkskunde'));
    await tester.pump();
    await tester.tap(find.text('10 vragen'));
    await tester.pump();
    await tester.tap(find.text('Start toets aardrijkskunde'));
    await _settle(tester);

    // Read the prompt off the screen, look the question up in the bank, and
    // tap its correct option.
    final subject = QuizBank.byId('aardrijkskunde')!;
    for (var i = 0; i < 10; i++) {
      final prompt = subject.questions.firstWhere(
        (q) =>
            find.text(q.prompt).evaluate().isNotEmpty &&
            (q.passage == null ||
                find.text(q.passage!).evaluate().isNotEmpty) &&
            q.options.every(
              (option) => find.text(option).evaluate().isNotEmpty,
            ),
      );
      await _tapOption(tester, prompt.answer);
      if (i < 9) {
        await tester.tap(find.text('Volgende'));
        await tester.pump();
      }
    }
    await tester.tap(find.text('Nakijken'));
    await _settle(tester);

    expect(find.text('10 van 10 goed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // With nothing wrong, the "only mistakes" filter shows the empty state.
    await tester.tap(find.text('Alle vragen'));
    await _settle(tester);
    expect(find.text('Alles goed'), findsOneWidget);

    await _teardown(tester);
  });
}

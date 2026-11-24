import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/logic/pta/pta_chemistry.dart';
import 'package:luma/features/plugins/installed/school/logic/pta/pta_scenarios.dart';
import 'package:luma/features/plugins/installed/school/ui/pta/pta_lab_view.dart';
import 'package:luma/features/plugins/installed/school/ui/pta_trainer_tab.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app() => MaterialApp(
  theme: LumaTheme.dark,
  locale: const Locale('nl'),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: PtaTrainerTab(random: math.Random(3))),
);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'a booklet practical shows observations and reviews the worksheet',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      expect(find.text('HAVO'), findsNothing);
      await tester.tap(find.text('Start practicum'));
      await _frames(tester);
      final confirmStart = find.widgetWithText(FilledButton, 'Start practicum');
      expect(tester.widget<FilledButton>(confirmStart).onPressed, isNotNull);
      await tester.tap(find.byType(DropdownButtonFormField<PtaSet>));
      await _frames(tester);
      await tester.scrollUntilVisible(
        find.text('Stof 25'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Stof 25'));
      await _frames(tester);
      await tester.tap(confirmStart);
      await _frames(tester);

      final first = tester.widget<PtaLabView>(find.byType(PtaLabView));
      expect(first.exam, isFalse);
      expect(first.set.level, Level.havo);
      expect(first.set.bookletNumber, 25);
      expect(find.text('Hier komen je waarnemingen.'), findsOneWidget);
      expect(find.text('Ruiken'), findsNothing);

      await tester.tap(find.text('Monster toevoegen'));
      await tester.pump();
      await tester.tap(find.text('Water'));
      await _frames(tester);

      await tester.ensureVisible(find.text('zilvernitraatoplossing'));
      await tester.pump();
      await tester.tap(find.text('zilvernitraatoplossing'));
      await _frames(tester);
      await tester.tap(find.text('Enkele druppels').last);
      await _frames(tester);
      expect(
        find.textContaining('Buis 1: Zilvernitraatoplossing'),
        findsOneWidget,
      );

      await tester.tap(find.text('Antwoord inleveren'));
      await _frames(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Ba(NO3)2(s)');
      final conclusion = find.byType(DropdownButtonFormField<Substance>);
      await tester.ensureVisible(conclusion);
      await tester.tap(conclusion);
      await _frames(tester);
      await tester.tap(find.text(first.lab.unknown.name).last);
      await _frames(tester);
      final close = MaterialLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      ).closeButtonLabel;
      await tester.tap(find.text(close));
      await _frames(tester);
      await tester.tap(find.text('Inleveren'));
      await _frames(tester);

      expect(find.text('Wat elke stof zou laten zien'), findsOneWidget);
      expect(find.textContaining('De juiste stof was'), findsOneWidget);
      expect(find.text('A1 · Goed!'), findsOneWidget);
      await tester.tap(find.text('Werkblad'));
      await _frames(tester);
      expect(find.text('Ba(NO3)2(s)'), findsOneWidget);
      expect(find.text('Ba(NO₃)₂(s)'), findsWidgets);
      await tester.tap(find.text(close));
      await _frames(tester);

      await tester.tap(find.text('Nieuw practicum'));
      await _frames(tester);
      await tester.tap(confirmStart);
      await _frames(tester);
      final second = tester.widget<PtaLabView>(find.byType(PtaLabView));
      expect(second.set.level, Level.havo);
      expect(second.lab, isNot(same(first.lab)));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('four exam jars keep separate lab state and share the clock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('Start practicum'));
    await _frames(tester);
    expect(find.textContaining('45A ·'), findsNothing);
    await tester.tap(find.text('Geavanceerde instellingen'));
    await _frames(tester);
    for (final code in ['45A', '48', '49', '52A', '65A', '65B']) {
      expect(find.textContaining('$code ·'), findsOneWidget);
    }
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Start practicum'));
    await _frames(tester);
    final lab = tester.widget<PtaLabView>(find.byType(PtaLabView));
    expect(lab.set.level, Level.havo);
    expect(lab.exam, isTrue);
    expect(lab.examMinutes, 120);
    expect(find.text(lab.set.candidates.first.notation), findsNothing);
    for (final label in ['A1', 'A2', 'A3', 'A4']) {
      expect(find.widgetWithText(ChoiceChip, 'Potje $label'), findsOneWidget);
    }

    await _scrollTo(tester, 'Monster toevoegen');
    await tester.tap(find.text('Monster toevoegen'));
    await _frames(tester);
    expect(lab.lab.log, hasLength(1));
    final secondJar = find.widgetWithText(ChoiceChip, 'Potje A2');
    await tester.ensureVisible(secondJar);
    await tester.tap(secondJar);
    await _frames(tester);
    final secondLab = tester.widget<PtaLabView>(find.byType(PtaLabView));
    expect(secondLab.jarLabel, 'A2');
    expect(secondLab.lab.log, isEmpty);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Potje A1'));
    await _frames(tester);
    expect(
      tester.widget<PtaLabView>(find.byType(PtaLabView)).lab.log,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Werkblad'));
    await _frames(tester);
    final formula = find.byType(TextFormField).first;
    await tester.enterText(formula, 'eigen notatie');
    await tester.pump(const Duration(minutes: 120));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
      isTrue,
    );
    expect(find.text('eigen notatie'), findsOneWidget);
    final close = MaterialLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    ).closeButtonLabel;
    await tester.tap(find.text(close));
    await _frames(tester);
    expect(tester.widget<PtaLabView>(find.byType(PtaLabView)).examMinutes, 0);
    await _scrollTo(tester, 'De tijd is om. Lever je werk in.');
    await _scrollTo(tester, 'Monster toevoegen');
    await tester.tap(find.text('Monster toevoegen'), warnIfMissed: false);
    await _frames(tester);
    expect(lab.lab.log, hasLength(1));

    await tester.ensureVisible(find.text('Antwoord inleveren'));
    await tester.tap(find.text('Antwoord inleveren'));
    await _frames(tester);
    await tester.tap(find.text('Inleveren'));
    await _frames(tester);
    expect(find.text('0 / 4 · Potjes juist geïdentificeerd'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'A4'));
    await _frames(tester);
    expect(find.text('A4 · Geen antwoord'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

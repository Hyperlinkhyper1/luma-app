import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/logic/pta/pta_chemistry.dart';
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

Future<void> _scrollTo(WidgetTester tester, String text) =>
    tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets('start a random practical, hand in and start another', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    expect(find.text('HAVO'), findsNothing);
    await tester.tap(find.text('Start practicum'));
    await _frames(tester);
    final confirmStart = find.widgetWithText(FilledButton, 'Start practicum');
    expect(tester.widget<FilledButton>(confirmStart).onPressed, isNull);
    await tester.tap(find.text('HAVO'));
    await tester.pump();
    await tester.tap(confirmStart);
    await _frames(tester);

    final first = tester.widget<PtaLabView>(find.byType(PtaLabView));
    expect(first.exam, isFalse);
    expect(first.set.level, Level.havo);
    expect(first.set.ids.toSet(), hasLength(4));
    expect(first.set.candidates.every((c) => c.level == Level.havo), isTrue);
    expect(find.text('Hier komen je waarnemingen.'), findsOneWidget);

    await tester.tap(find.text('Spatelpunt X'));
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
    await tester.tap(find.text(first.set.candidates.first.name).last);
    await tester.pump();
    await tester.tap(find.text('Inleveren'));
    await _frames(tester);

    expect(find.text('Wat elke stof zou laten zien'), findsOneWidget);
    expect(find.textContaining('Stof X was'), findsOneWidget);
    expect(find.text('Zelfde set opnieuw'), findsNothing);

    await tester.tap(find.text('Nieuw practicum'));
    await _frames(tester);
    await tester.tap(find.text('HAVO'));
    await tester.pump();
    await tester.tap(confirmStart);
    await _frames(tester);
    final second = tester.widget<PtaLabView>(find.byType(PtaLabView));
    expect(second.set.level, Level.havo);
    expect(second.set.ids.toSet(), isNot(equals(first.set.ids.toSet())));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('advanced settings and the bench fit on a phone', (tester) async {
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
    await tester.ensureVisible(find.text('VWO'));
    await tester.tap(find.text('VWO'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Start practicum'));
    await _frames(tester);
    final lab = tester.widget<PtaLabView>(find.byType(PtaLabView));
    expect(lab.set.level, Level.vwo);
    expect(lab.exam, isTrue);
    expect(tester.takeException(), isNull);
    await _scrollTo(tester, 'Logboek');
    expect(find.text('Logboek'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

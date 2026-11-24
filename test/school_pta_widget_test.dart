import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _scrollTo(WidgetTester tester, String text) => tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets('pick a set, run tests in a tube and hand in', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _scrollTo(tester, 'Halogeniden');
    await tester.tap(find.text('Halogeniden'));
    await tester.pump();
    await _scrollTo(tester, 'Start practicum');
    await tester.tap(find.text('Start practicum'));
    await _frames(tester);

    expect(find.text('natriumbromide'), findsOneWidget);
    expect(find.text('Hier komen je waarnemingen.'), findsOneWidget);

    await tester.tap(find.text('Spatelpunt X'));
    await tester.pump();
    await tester.tap(find.text('Water'));
    await _frames(tester);
    expect(find.textContaining('De stof lost op.'), findsOneWidget);

    await tester.ensureVisible(find.text('zilvernitraatoplossing'));
    await tester.pump();
    await tester.tap(find.text('zilvernitraatoplossing'));
    await _frames(tester);
    await tester.tap(find.text('Enkele druppels').last);
    await _frames(tester);
    expect(find.textContaining('Buis 1: Zilvernitraatoplossing'), findsOneWidget);

    await tester.tap(find.text('Antwoord inleveren'));
    await _frames(tester);
    await tester.tap(find.text('natriumnitraat').last);
    await tester.pump();
    await tester.tap(find.text('Inleveren'));
    await _frames(tester);

    expect(find.text('Wat elke stof zou laten zien'), findsOneWidget);
    expect(find.textContaining('Stof X was'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the bench fits on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _scrollTo(tester, 'Start practicum');
    await tester.tap(find.text('Start practicum'));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    await _scrollTo(tester, 'Logboek');
    expect(find.text('Logboek'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

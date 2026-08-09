import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/calculator/calculator_page.dart';
import 'package:luma/features/plugins/installed/calculator/calculator_store.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app() => MaterialApp(
      theme: LumaTheme.dark,
      home: const Scaffold(body: CalculatorPage()),
    );

/// Waits for the (singleton) store to finish its first load and empties it, so
/// each test starts from the same place. Store setup touches real async I/O, so
/// it runs outside the widget tester's fake clock; there is no path_provider on
/// the host, so the store stays in memory.
Future<CalculatorStore> _freshStore(WidgetTester tester) async {
  late CalculatorStore store;
  await tester.runAsync(() async {
    store = CalculatorStore();
    for (var i = 0; i < 50 && !store.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  });
  store.clearHistory();
  for (final function in store.functions) {
    store.removeFunction(function.id);
  }
  store.setDegrees(true);
  return store;
}

/// Lets the debounced timers fire so none are left pending: the store's own
/// 400ms write and the storage guard's 3s usage re-scan.
Future<void> _settleTimers(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 4));

Future<void> _tapKeys(WidgetTester tester, List<String> labels) async {
  for (final label in labels) {
    await tester.tap(find.widgetWithText(GestureDetector, label).last);
    await tester.pump();
  }
}

void main() {
  setUpAll(() {
    StorageGuardService.instance = StorageGuardService();
  });

  testWidgets('adds up on the keypad and remembers the answer',
      (tester) async {
    final store = await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await _tapKeys(tester, ['1', '2', '×', '3', '=']);

    expect(find.text('= 36'), findsOneWidget);
    expect(store.history.first.result, '36');
    expect(store.lastAnswer, 36);

    await _settleTimers(tester);
  });

  testWidgets('previews the answer before = is pressed', (tester) async {
    await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await _tapKeys(tester, ['4', '+', '4']);

    expect(find.text('4+4'), findsOneWidget);
    expect(find.text('= 8'), findsOneWidget);

    await _settleTimers(tester);
  });

  testWidgets('AC clears and ⌫ removes the last character', (tester) async {
    await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await _tapKeys(tester, ['7', '8', '9', '⌫']);
    expect(find.text('78'), findsOneWidget);

    await _tapKeys(tester, ['AC']);
    expect(find.text('78'), findsNothing);
    // The display falls back to its 0 placeholder, alongside the 0 key.
    expect(find.text('0'), findsNWidgets(2));

    await _settleTimers(tester);
  });

  testWidgets('a bad expression explains itself instead of crashing',
      (tester) async {
    await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await _tapKeys(tester, ['5', '+', '=']);

    expect(find.text('The expression stops too early.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _settleTimers(tester);
  });

  testWidgets('advanced mode plots a function of x', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('Advanced'));
    await tester.pump();

    expect(find.text('DEG'), findsWidgets);

    await _tapKeys(tester, ['sin', 'x', ')']);
    await tester.tap(find.text('Plot as y = sin(x)'));
    await tester.pump();

    expect(store.functions.single.expression, 'sin(x)');
    expect(find.text('sin(x)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _settleTimers(tester);
  });

  testWidgets('pressing = on a function of x asks for Plot instead',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.text('Advanced'));
    await tester.pump();

    await _tapKeys(tester, ['x', '+', '1', '=']);

    expect(
      find.text('That has an x in it — press Plot to draw it.'),
      findsOneWidget,
    );
    expect(store.history, isEmpty);

    await _settleTimers(tester);
  });

  testWidgets('the ☰ button opens the unit converter', (tester) async {
    await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Convert'), findsOneWidget);
    expect(find.text('Kilometre'), findsOneWidget);
    // 1 km in miles, shown in the result box and in the all-units table.
    expect(find.text('0.621371192237'), findsWidgets);

    await _settleTimers(tester);
  });

  testWidgets('renders at phone width without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _freshStore(tester);
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Advanced'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Graph'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await _settleTimers(tester);
  });
}

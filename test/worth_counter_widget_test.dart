import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/worth_counter/worth_counter_page.dart';
import 'package:luma/features/plugins/installed/worth_counter/worth_counter_store.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app() => MaterialApp(
      theme: LumaTheme.dark,
      home: const Scaffold(body: WorthCounterPage()),
    );

/// Prepares the (singleton) store with a known set of products. Store setup
/// touches real async I/O, so it runs outside the widget tester's fake clock.
/// There is no path_provider on the host, so the store stays in memory.
Future<WorthCounterStore> _seed(
  WidgetTester tester,
  List<({String name, double price})> products,
) async {
  late WorthCounterStore store;
  await tester.runAsync(() async {
    store = WorthCounterStore();
    for (var i = 0; i < 50 && !store.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    for (final product in store.products) {
      await store.delete(product.id);
    }
    for (final product in products) {
      await store.add(
        name: product.name,
        price: product.price,
        color: 0xFF7C5AD9,
      );
    }
  });
  return store;
}

/// Lets the store's debounced write timer fire so none are left pending.
Future<void> _settleTimers(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  setUpAll(() {
    StorageGuardService.instance = StorageGuardService();
  });

  testWidgets('counting a €2 product twenty times totals €40', (tester) async {
    await _seed(tester, [(name: 'Coffee', price: 2)]);

    await tester.pumpWidget(_app());
    await tester.pump();

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump();
    }

    expect(find.text('20'), findsOneWidget);
    expect(find.text('20 items counted'), findsOneWidget);
    // Once on the product's own row, once in the bottom total bar.
    expect(find.text('€40.00'), findsNWidgets(2));

    await _settleTimers(tester);
  });

  testWidgets('two products add up, and - never goes below zero',
      (tester) async {
    final store = await _seed(tester, [
      (name: 'Coffee', price: 2),
      (name: 'Cake', price: 3.5),
    ]);

    await tester.pumpWidget(_app());
    await tester.pump();

    // Index 0 and 1 are the product rows; the floating add button is last.
    final plusButtons = find.byIcon(Icons.add_rounded);
    await tester.tap(plusButtons.at(0));
    await tester.pump();
    await tester.tap(plusButtons.at(1));
    await tester.pump();
    await tester.tap(plusButtons.at(1));
    await tester.pump();

    expect(find.text('€9.00'), findsOneWidget);

    // Coffee sits at 1: two taps on - must stop at 0, not go negative.
    final minusButtons = find.byIcon(Icons.remove_rounded);
    await tester.tap(minusButtons.at(0));
    await tester.pump();
    await tester.tap(minusButtons.at(0));
    await tester.pump();

    expect(store.products.first.count, 0);
    expect(find.text('€7.00'), findsNWidgets(2));

    await _settleTimers(tester);
  });

  testWidgets('renders at phone width without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = await _seed(
      tester,
      [(name: 'A rather long product name', price: 12.5)],
    );
    store.increment(store.products.first.id, 7);

    await tester.pumpWidget(_app());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('€87.50'), findsNWidgets(2));

    await _settleTimers(tester);
  });

  testWidgets('shows the empty state when nothing has been added',
      (tester) async {
    await _seed(tester, const []);

    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('No products yet'), findsOneWidget);
    expect(find.text('€0.00'), findsOneWidget);
  });
}

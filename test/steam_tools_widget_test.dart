import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/steam_price_chart.dart';
import 'package:luma/theme/luma_theme.dart';

SteamPricePoint _point(DateTime at, int cents, {int discount = 0}) =>
    SteamPricePoint(
      id: at.microsecondsSinceEpoch,
      appId: 1,
      observedAt: at,
      finalCents: cents,
      initialCents: discount > 0 ? 5999 : cents,
      discountPercent: discount,
      currency: 'USD',
    );

Widget _card(List<SteamPricePoint> points) => MaterialApp(
      theme: LumaTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SteamPriceHistoryCard(
            points: points,
            fallbackCurrency: 'USD',
          ),
        ),
      ),
    );

void main() {
  testWidgets('offers every range, longest first', (tester) async {
    await tester.pumpWidget(_card(const []));

    for (final label in ['5Y', '1Y', '6M', '1M', '1W', '1D']) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label');
    }
  });

  testWidgets('says so plainly when nothing has been recorded',
      (tester) async {
    await tester.pumpWidget(_card(const []));

    expect(find.byType(LineChart), findsNothing);
    expect(
      find.textContaining('No prices recorded'),
      findsOneWidget,
    );
    // The note has to explain *why* the chart is empty, not just that it is.
    expect(
      find.textContaining('Steam publishes no price history'),
      findsOneWidget,
    );
  });

  testWidgets('draws the line and the low/high once prices exist',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card([
      _point(now.subtract(const Duration(days: 40)), 5999),
      _point(now.subtract(const Duration(days: 20)), 2999, discount: 50),
      _point(now.subtract(const Duration(days: 5)), 5999),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Lowest seen'), findsOneWidget);
    expect(find.text('\$29.99'), findsOneWidget);
    expect(find.text('Highest seen'), findsOneWidget);
    expect(find.text('\$59.99'), findsOneWidget);
  });

  testWidgets('switching range redraws against the shorter window',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card([
      _point(now.subtract(const Duration(days: 40)), 5999),
      _point(now.subtract(const Duration(days: 20)), 2999, discount: 50),
      _point(now.subtract(const Duration(days: 10)), 4999),
    ]));
    await tester.pumpAndSettle();

    // The full year shows the 29.99 dip...
    expect(find.text('\$29.99'), findsOneWidget);

    await tester.tap(find.text('1W'));
    await tester.pumpAndSettle();

    // ...but the sale ended ten days ago, so across the last week the price
    // was only ever 49.99 and the card must not keep claiming a low it did
    // not observe inside that window.
    expect(find.text('\$29.99'), findsNothing);
    expect(
      find.textContaining('Unchanged at \$49.99'),
      findsOneWidget,
    );
  });

  testWidgets('warns when the window is longer than the history', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card([
      _point(now.subtract(const Duration(days: 3)), 5999),
    ]));
    await tester.pumpAndSettle();

    // Default range is 1Y against three days of data.
    expect(
      find.textContaining('3 days so far, not the last year'),
      findsOneWidget,
    );
  });
}

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

Widget _card(
  List<SteamPricePoint> points, {
  bool hasItadKey = true,
  int? lowestEverCents,
  DateTime? lowestEverAt,
  VoidCallback? onAddItadKey,
}) =>
    MaterialApp(
      theme: LumaTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SteamPriceHistoryCard(
            points: points,
            fallbackCurrency: 'USD',
            hasItadKey: hasItadKey,
            lowestEverCents: lowestEverCents,
            lowestEverAt: lowestEverAt,
            onAddItadKey: onAddItadKey,
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

  testWidgets('asks for an ITAD key instead of showing an empty chart',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_card(
      const [],
      hasItadKey: false,
      onAddItadKey: () => tapped = true,
    ));

    expect(find.byType(LineChart), findsNothing);
    expect(
      find.textContaining('Add an IsThereAnyDeal key'),
      findsOneWidget,
    );

    await tester.tap(find.text('Add key'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('says so plainly when ITAD carries no history', (tester) async {
    await tester.pumpWidget(_card(const []));

    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('No price history'), findsOneWidget);
    // The note has to explain *why* the chart is empty, not just that it is.
    expect(
      find.textContaining('IsThereAnyDeal has nothing on file'),
      findsOneWidget,
    );
  });

  testWidgets('draws the line and the range low/high once history exists',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card([
      _point(now.subtract(const Duration(days: 40)), 5999),
      _point(now.subtract(const Duration(days: 20)), 2999, discount: 50),
      _point(now.subtract(const Duration(days: 5)), 5999),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Lowest in range'), findsOneWidget);
    expect(find.text('\$29.99'), findsOneWidget);
    expect(find.text('Highest in range'), findsOneWidget);
    expect(find.text('\$59.99'), findsOneWidget);
  });

  testWidgets('shows the all-time low even when it is outside the window',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card(
      [_point(now.subtract(const Duration(days: 5)), 5999)],
      lowestEverCents: 1499,
      lowestEverAt: DateTime(2023, 11, 20),
    ));
    await tester.pumpAndSettle();

    // The window is flat at 59.99, but the number worth knowing is the 14.99
    // the game once hit — that is what people wait for.
    expect(find.textContaining('All-time low'), findsOneWidget);
    expect(find.text('\$14.99'), findsOneWidget);
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

    // The full year shows the 29.99 sale...
    expect(find.text('\$29.99'), findsOneWidget);

    await tester.tap(find.text('1W'));
    await tester.pumpAndSettle();

    // ...but the sale ended ten days ago, so across the last week the price
    // was only ever 49.99 and the card must not keep claiming a low it did
    // not observe inside that window.
    expect(find.text('\$29.99'), findsNothing);
    expect(find.textContaining('Unchanged at \$49.99'), findsOneWidget);
  });

  testWidgets('names the date the record starts when it is shorter than the '
      'range', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card([
      _point(now.subtract(const Duration(days: 3)), 5999),
    ]));
    await tester.pumpAndSettle();

    // Default range is 1Y against three days of record.
    expect(
      find.textContaining('which is less than the last year'),
      findsOneWidget,
    );
  });

  testWidgets('credits the source when the record covers the whole range',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_card([
      _point(now.subtract(const Duration(days: 900)), 5999),
      _point(now.subtract(const Duration(days: 30)), 2999, discount: 50),
    ]));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('covering all of the last year'),
      findsOneWidget,
    );
  });
}

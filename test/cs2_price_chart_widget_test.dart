import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_price_history.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_chart_curve.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_price_chart.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Cs2PriceSeries _series(int count, Duration step) {
  final start = DateTime(2026, 1, 1);
  final samples = [
    for (var i = 0; i < count; i++)
      Cs2PriceSample(at: start.add(step * i), priceCents: 1000 + (i % 5) * 10),
  ];
  return Cs2PriceSeries(
    samples: samples,
    observations: samples.sublist(1, samples.length - 1),
    range: Cs2PriceRange.week,
    currency: 'USD',
  );
}

Future<LineChart> _pumpChart(WidgetTester tester, Cs2PriceSeries series) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(body: Cs2PriceSeriesView(series: series)),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return tester.widget<LineChart>(find.byType(LineChart));
}

FlSpot _spot(Cs2PriceSample s) =>
    FlSpot(s.at.millisecondsSinceEpoch.toDouble(), s.priceCents.toDouble());

void main() {
  testWidgets('marks each reading when they are spread out', (tester) async {
    final series = _series(12, const Duration(hours: 12));
    final chart = await _pumpChart(tester, series);

    final line = chart.data.lineBarsData[0];
    final markers = chart.data.lineBarsData[1];
    expect(line.dotData.show, isFalse);
    expect(markers.spots, hasLength(series.observations.length));
    for (final sample in series.observations) {
      expect(markers.spots, contains(_spot(sample)));
      expect(line.spots, contains(_spot(sample)));
      expect(markers.dotData.checkToShowDot(_spot(sample), markers), isTrue);
    }
  });

  testWidgets('a dense history draws a thinned line with no dots', (
    tester,
  ) async {
    final series = _series(600, const Duration(minutes: 15));
    final chart = await _pumpChart(tester, series);

    final markers = chart.data.lineBarsData[1];
    expect(markers.spots.length, lessThan(series.samples.length ~/ 2));
    expect(markers.spots.first, _spot(series.samples.first));
    expect(markers.spots.last, _spot(series.samples.last));
    for (final spot in markers.spots) {
      expect(markers.dotData.checkToShowDot(spot, markers), isFalse);
    }
  });

  test('clustered readings are too close for dots', () {
    final spots = [
      const FlSpot(0, 1),
      const FlSpot(500, 1),
      const FlSpot(501, 2),
      const FlSpot(1000, 1),
    ];
    expect(cs2ChartDotsFit(spots, 0, 1000, 700), isFalse);
    expect(
      cs2ChartDotsFit([spots[0], spots[1], spots[3]], 0, 1000, 700),
      isTrue,
    );
  });

  test('thinning keeps the real endpoints and leaves sparse lines alone', () {
    final sparse = [for (var i = 0; i < 10; i++) FlSpot(i.toDouble(), 1)];
    expect(thinCs2ChartSpots(sparse, 700), same(sparse));

    final dense = [
      for (var i = 0; i < 1000; i++) FlSpot(i.toDouble(), (i % 7).toDouble()),
    ];
    final thinned = thinCs2ChartSpots(dense, 600);
    expect(thinned.length, lessThanOrEqualTo(600 ~/ kCs2ChartPixelsPerPoint));
    expect(thinned.first, dense.first);
    expect(thinned.last, dense.last);
  });
}

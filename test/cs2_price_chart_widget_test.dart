import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_price_history.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_price_chart.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('shows every check on the curve, excluding carried endpoints', (
    tester,
  ) async {
    final start = DateTime(2026, 1, 1);
    final samples = [
      for (var i = 0; i < 52; i++)
        Cs2PriceSample(
          at: start.add(Duration(hours: i)),
          priceCents: 1000 + (i % 5) * 10,
        ),
    ];
    final observations = samples.sublist(1, samples.length - 1);
    final series = Cs2PriceSeries(
      samples: samples,
      observations: observations,
      range: Cs2PriceRange.week,
      currency: 'USD',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: Cs2PriceSeriesView(series: series)),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final line = chart.data.lineBarsData[0];
    final markers = chart.data.lineBarsData[1];
    expect(line.dotData.show, isFalse);
    expect(markers.dotData.show, isTrue);
    expect(markers.spots, hasLength(observations.length));
    for (final sample in observations) {
      final spot = FlSpot(
        sample.at.millisecondsSinceEpoch.toDouble(),
        sample.priceCents.toDouble(),
      );
      expect(markers.spots, contains(spot));
      expect(line.spots, contains(spot));
    }
    expect(tester.takeException(), isNull);
  });
}

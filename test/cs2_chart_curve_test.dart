import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_chart_curve.dart';

void main() {
  test('preserves original points and stays within each uneven interval', () {
    const points = [
      FlSpot(1700000000000, 100),
      FlSpot(1700000001000, 120),
      FlSpot(1700001000000, 121),
      FlSpot(1700001001000, 80),
      FlSpot(1700002000000, 80),
      FlSpot(1700002001000, 150),
    ];
    final result = monotoneCs2ChartSpots(points);

    expect(result.length, (points.length - 1) * 6 + 1);
    for (var i = 0; i < points.length - 1; i++) {
      expect(result[i * 6], points[i]);
      final low = math.min(points[i].y, points[i + 1].y);
      final high = math.max(points[i].y, points[i + 1].y);
      for (final spot in result.skip(i * 6).take(7)) {
        expect(spot.x, inInclusiveRange(points[i].x, points[i + 1].x));
        expect(spot.y, inInclusiveRange(low, high));
      }
      final interval = result.skip(i * 6).take(7).toList();
      for (var j = 1; j < interval.length; j++) {
        if (points[i].y <= points[i + 1].y) {
          expect(interval[j].y, greaterThanOrEqualTo(interval[j - 1].y));
        } else {
          expect(interval[j].y, lessThanOrEqualTo(interval[j - 1].y));
        }
      }
    }
    expect(result.last, points.last);
  });

  test('joins equal and decreasing timestamps without invalid values', () {
    const points = [
      FlSpot(1, 100),
      FlSpot(2, 200),
      FlSpot(2, 150),
      FlSpot(1, 125),
      FlSpot(3, 175),
    ];
    final result = monotoneCs2ChartSpots(points);

    expect(result.where((spot) => points.contains(spot)).toList(), points);
    expect(result.every((spot) => spot.x.isFinite && spot.y.isFinite), isTrue);
  });

  test('handles empty and single-reading series', () {
    expect(monotoneCs2ChartSpots(const []), isEmpty);
    expect(monotoneCs2ChartSpots(const [FlSpot(1, 2)]), [const FlSpot(1, 2)]);
  });

  test('bounds interpolation work while retaining a long history', () {
    final points = List.generate(
      1001,
      (i) => FlSpot(i.toDouble(), (i % 5).toDouble()),
    );
    final result = monotoneCs2ChartSpots(points);

    expect(result.length, lessThanOrEqualTo(points.length + 2000));
    expect(result.where(points.contains).toList(), points);
  });
}

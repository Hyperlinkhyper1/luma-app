import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';

/// Interpolates between readings without creating prices outside the range of
/// either pair. The returned line passes through every original spot.
///
/// Equal or out-of-order timestamps are joined directly, with flat tangents
/// on either side, so they cannot cause a division by zero or a looping curve.
List<FlSpot> monotoneCs2ChartSpots(List<FlSpot> spots) {
  if (spots.length < 2) return List.of(spots);

  final widths = <double>[];
  final slopes = <double>[];
  for (var i = 0; i < spots.length - 1; i++) {
    final width = spots[i + 1].x - spots[i].x;
    widths.add(width);
    slopes.add(width > 0 ? (spots[i + 1].y - spots[i].y) / width : 0);
  }

  final tangents = List<double>.filled(spots.length, 0);
  if (widths.first > 0) tangents.first = slopes.first;
  if (widths.last > 0) tangents.last = slopes.last;
  for (var i = 1; i < spots.length - 1; i++) {
    final left = slopes[i - 1];
    final right = slopes[i];
    if (widths[i - 1] <= 0 ||
        widths[i] <= 0 ||
        left == 0 ||
        right == 0 ||
        left.sign != right.sign) {
      continue;
    }
    final leftWeight = 2 * widths[i] + widths[i - 1];
    final rightWeight = widths[i] + 2 * widths[i - 1];
    tangents[i] =
        (leftWeight + rightWeight) / (leftWeight / left + rightWeight / right);
  }

  final segments = (2000 ~/ (spots.length - 1)).clamp(1, 6);
  final result = <FlSpot>[spots.first];
  for (var i = 0; i < widths.length; i++) {
    final start = spots[i];
    final end = spots[i + 1];
    final width = widths[i];
    if (width > 0) {
      for (var step = 1; step < segments; step++) {
        final t = step / segments;
        final t2 = t * t;
        final t3 = t2 * t;
        final y =
            (2 * t3 - 3 * t2 + 1) * start.y +
            (t3 - 2 * t2 + t) * width * tangents[i] +
            (-2 * t3 + 3 * t2) * end.y +
            (t3 - t2) * width * tangents[i + 1];
        result.add(
          FlSpot(
            start.x + width * t,
            y.clamp(math.min(start.y, end.y), math.max(start.y, end.y)),
          ),
        );
      }
    }
    result.add(end);
  }
  return result;
}

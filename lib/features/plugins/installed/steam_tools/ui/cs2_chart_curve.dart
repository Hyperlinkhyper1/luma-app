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

/// Horizontal pixels each plotted point gets once a history is denser than
/// the chart can show. Readings closer than this are averaged together.
const double kCs2ChartPixelsPerPoint = 6;

/// Readings need at least this much horizontal room between them before
/// each one is marked with a dot; any closer and the dots merge into a
/// beaded smear, so the chart draws the line alone.
const double kCs2ChartMinDotGap = 14;

/// Averages [spots] (oldest first) into equal-width time buckets so no more
/// than one point lands in each [kCs2ChartPixelsPerPoint] of [plotWidth].
/// The first and last spots are kept exactly, so the line still starts and
/// ends on real values; a history sparse enough to fit is returned as is.
List<FlSpot> thinCs2ChartSpots(List<FlSpot> spots, double plotWidth) {
  final maxPoints = math.max(3, plotWidth ~/ kCs2ChartPixelsPerPoint);
  if (spots.length <= maxPoints) return spots;
  final first = spots.first;
  final last = spots.last;
  final span = last.x - first.x;
  if (span <= 0) return [first, last];
  final buckets = maxPoints - 2;
  final xs = List<double>.filled(buckets, 0);
  final ys = List<double>.filled(buckets, 0);
  final counts = List<int>.filled(buckets, 0);
  for (var i = 1; i < spots.length - 1; i++) {
    final index = ((spots[i].x - first.x) / span * buckets).floor().clamp(
      0,
      buckets - 1,
    );
    xs[index] += spots[i].x;
    ys[index] += spots[i].y;
    counts[index]++;
  }
  return [
    first,
    for (var i = 0; i < buckets; i++)
      if (counts[i] > 0) FlSpot(xs[i] / counts[i], ys[i] / counts[i]),
    last,
  ];
}

/// Whether every pair of neighbouring [spots] sits at least
/// [kCs2ChartMinDotGap] pixels apart on a [plotWidth]-wide axis running from
/// [minX] to [maxX] — i.e. whether a dot per reading reads as points rather
/// than clutter.
bool cs2ChartDotsFit(
  List<FlSpot> spots,
  double minX,
  double maxX,
  double plotWidth,
) {
  if (spots.length < 2) return true;
  final span = maxX - minX;
  if (span <= 0 || plotWidth <= 0) return false;
  if (spots.length * kCs2ChartMinDotGap > plotWidth) return false;
  final pxPerUnit = plotWidth / span;
  for (var i = 1; i < spots.length; i++) {
    if ((spots[i].x - spots[i - 1].x) * pxPerUnit < kCs2ChartMinDotGap) {
      return false;
    }
  }
  return true;
}

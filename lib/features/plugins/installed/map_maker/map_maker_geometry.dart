import 'dart:math' as math;
import 'dart:ui';

/// Spacing of the schematic grid stations snap to.
const kTransitGrid = 24.0;

/// Size of the infinite-feeling drawing sheet.
const kTransitSheetSize = Size(4800, 3200);

Offset snapToTransitGrid(Offset point, [double grid = kTransitGrid]) {
  if (grid <= 0) return point;
  return Offset(
    (point.dx / grid).round() * grid,
    (point.dy / grid).round() * grid,
  );
}

/// A 2- or 3-point path that only uses horizontal, vertical and 45° runs —
/// the language of printed metro diagrams.
List<Offset> octilinearPath(Offset a, Offset b) {
  const eps = 0.75;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  if (dx.abs() < eps || dy.abs() < eps) return [a, b];
  if ((dx.abs() - dy.abs()).abs() < eps) return [a, b];
  if (dx.abs() > dy.abs()) {
    return [a, Offset(a.dx + (dx.abs() - dy.abs()) * dx.sign, a.dy), b];
  }
  return [a, Offset(a.dx, a.dy + (dy.abs() - dx.abs()) * dy.sign), b];
}

/// Expands an ordered list of station positions into the octilinear polyline
/// drawn between them.
List<Offset> octilinearPolyline(List<Offset> stations) {
  if (stations.length < 2) return List<Offset>.from(stations);
  final points = <Offset>[stations.first];
  for (var i = 1; i < stations.length; i++) {
    final run = octilinearPath(stations[i - 1], stations[i]);
    points.addAll(run.skip(1));
  }
  return points;
}

double distanceToSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (length2 < 0.0001) return (point - a).distance;
  var t = ((point.dx - a.dx) * ab.dx + (point.dy - a.dy) * ab.dy) / length2;
  t = t.clamp(0.0, 1.0);
  final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (point - closest).distance;
}

double distanceToPolyline(Offset point, List<Offset> points) {
  if (points.isEmpty) return double.infinity;
  if (points.length == 1) return (point - points.first).distance;
  var best = double.infinity;
  for (var i = 1; i < points.length; i++) {
    best = math.min(best, distanceToSegment(point, points[i - 1], points[i]));
  }
  return best;
}

Path polylinePath(List<Offset> points, {bool close = false}) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  if (close && points.length > 2) path.close();
  return path;
}

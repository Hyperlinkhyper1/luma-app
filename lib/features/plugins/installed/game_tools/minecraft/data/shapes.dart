import 'dart:math' as math;

import '../../../../../../l10n/app_localizations.dart';

/// Block-grid geometry for the shape generator. Everything here returns cell
/// sets, so the same code drives the 2D plan, the 3D preview and the export.

/// A filled or hollow ellipse [width] × [height] cells across.
///
/// A cell is in when its centre is inside the ellipse; a hollow ring keeps
/// the cells within [thickness] of the edge. [thick] uses 8-connected edges
/// (no diagonal gaps) instead of the thinner 4-connected outline.
Set<(int, int)> mcEllipse(
  int width,
  int height, {
  bool filled = false,
  int thickness = 1,
  bool thick = false,
}) {
  final rx = width / 2, ry = height / 2;
  bool inside(int x, int y, double shrink) {
    final ax = rx - shrink, ay = ry - shrink;
    if (ax <= 0 || ay <= 0) return false;
    final dx = (x + 0.5 - rx) / ax;
    final dy = (y + 0.5 - ry) / ay;
    return dx * dx + dy * dy <= 1.0;
  }

  final out = <(int, int)>{};
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!inside(x, y, 0)) continue;
      if (filled) {
        out.add((x, y));
        continue;
      }
      if (thickness > 1) {
        if (!inside(x, y, thickness.toDouble())) out.add((x, y));
        continue;
      }
      final neighbours = thick
          ? const [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)]
          : const [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dx, dy) in neighbours) {
        if (!inside(x + dx, y + dy, 0)) {
          out.add((x, y));
          break;
        }
      }
    }
  }
  return out;
}

enum McArchStyle {
  round,
  pointed,
  parabolic,
  flat;

  String label(L t) => switch (this) {
    round => t.mcShapeRound,
    pointed => t.mcShapePointed,
    parabolic => t.mcShapeParabolic,
    flat => t.mcShapeSegmental,
  };
}

/// An arch [width] across and [height] tall, [thickness] blocks deep in the
/// face. Returns cells in (x, y) with y = 0 at the springing line.
Set<(int, int)> mcArch(
  int width,
  int height,
  McArchStyle style, {
  int thickness = 1,
}) {
  // The intrados curve's height above the springing at horizontal offset u
  // from the centre (|u| ≤ half), for an arch of half-width a, rise b.
  double curve(double u, double a, double b) {
    if (a <= 0 || b <= 0) return 0;
    final t = (u.abs() / a).clamp(0.0, 1.0);
    switch (style) {
      case McArchStyle.round:
        return b * math.sqrt(1 - t * t);
      case McArchStyle.parabolic:
        return b * (1 - t * t);
      case McArchStyle.pointed:
        // Two arcs of radius 2a' whose centres sit on the springing line.
        final r = 1.6;
        final cx = r - 1;
        final y = math.sqrt(math.max(0, r * r - math.pow(t + cx, 2)));
        final top = math.sqrt(r * r - cx * cx);
        return b * (y / top);
      case McArchStyle.flat:
        // A shallow segment of a circle: rise is a third of the half-span.
        const k = 0.45;
        final r = (1 + k * k) / (2 * k);
        final y = math.sqrt(math.max(0, r * r - t * t)) - (r - k);
        return b * (y / k);
    }
  }

  final out = <(int, int)>{};
  final half = width / 2;
  for (var x = 0; x < width; x++) {
    final u = x + 0.5 - half;
    final outer = curve(u, half, height.toDouble());
    final innerHalf = half - thickness;
    final inner = innerHalf <= 0 || u.abs() >= innerHalf
        ? -1.0
        : curve(u, innerHalf, (height - thickness).toDouble());
    for (var y = 0; y < height; y++) {
      final cy = y + 0.5;
      if (cy <= outer && cy > inner) out.add((x, y));
    }
  }
  return out;
}

enum McSolid {
  sphere,
  dome,
  cylinder,
  cone,
  pyramid,
  torus;

  String label(L t) => switch (this) {
    sphere => t.mcShapeSphere,
    dome => t.mcShapeDome,
    cylinder => t.mcShapeCylinder,
    cone => t.mcShapeCone,
    pyramid => t.mcShapePyramid,
    torus => t.mcShapeTorus,
  };
}

/// A 3D solid as (x, y, z) cells, y up.
Set<(int, int, int)> mcSolid(
  McSolid solid, {
  required int width,
  required int height,
  required int depth,
  bool hollow = true,
  int thickness = 1,
  int tube = 3,
}) {
  final rx = width / 2, ry = height / 2, rz = depth / 2;
  final t = thickness.toDouble();

  bool inEllipsoid(double x, double y, double z, double ax, double ay, double az) {
    if (ax <= 0 || ay <= 0 || az <= 0) return false;
    final dx = x / ax, dy = y / ay, dz = z / az;
    return dx * dx + dy * dy + dz * dz <= 1;
  }

  bool inside(int x, int y, int z, double shrink) {
    final px = x + 0.5 - rx;
    final pz = z + 0.5 - rz;
    switch (solid) {
      case McSolid.sphere:
        return inEllipsoid(px, y + 0.5 - ry, pz, rx - shrink, ry - shrink, rz - shrink);
      case McSolid.dome:
        // Height is the dome's rise; the base is the full width.
        return y >= 0 &&
            inEllipsoid(px, y + 0.5, pz, rx - shrink, height - shrink, rz - shrink);
      case McSolid.cylinder:
        if (y < 0 || y >= height) return false;
        final ax = rx - shrink, az = rz - shrink;
        if (ax <= 0 || az <= 0) return false;
        final capped = shrink > 0 && (y < shrink || y >= height - shrink);
        if (capped) return false;
        return (px / ax) * (px / ax) + (pz / az) * (pz / az) <= 1;
      case McSolid.cone:
        if (y < 0 || y >= height) return false;
        final f = 1 - (y + 0.5) / height;
        final ax = rx * f - shrink, az = rz * f - shrink;
        if (ax <= 0 || az <= 0) return false;
        return (px / ax) * (px / ax) + (pz / az) * (pz / az) <= 1;
      case McSolid.pyramid:
        if (y < 0 || y >= height) return false;
        final f = 1 - y / height;
        final hx = rx * f - shrink, hz = rz * f - shrink;
        return px.abs() <= hx && pz.abs() <= hz;
      case McSolid.torus:
        final ring = math.sqrt(px * px + pz * pz) - (rx - tube);
        final py = y + 0.5 - ry;
        final r = tube - shrink;
        return r > 0 && ring * ring + py * py <= r * r;
    }
  }

  final out = <(int, int, int)>{};
  final yRange = switch (solid) {
    McSolid.dome => height,
    McSolid.torus => (tube * 2),
    _ => height,
  };
  final ys = solid == McSolid.torus ? (tube * 2) : yRange;
  final effectiveRy = solid == McSolid.torus ? tube.toDouble() : ry;
  for (var y = 0; y < ys; y++) {
    for (var z = 0; z < depth; z++) {
      for (var x = 0; x < width; x++) {
        final yy = solid == McSolid.torus ? y : y;
        if (solid == McSolid.torus) {
          final px = x + 0.5 - rx, pz = z + 0.5 - rz;
          final ring = math.sqrt(px * px + pz * pz) - (rx - tube);
          final py = yy + 0.5 - effectiveRy;
          final inOuter = ring * ring + py * py <= tube * tube;
          if (!inOuter) continue;
          final r2 = tube - t;
          final inInner = r2 > 0 && ring * ring + py * py <= r2 * r2;
          if (!hollow || !inInner) out.add((x, y, z));
          continue;
        }
        if (!inside(x, yy, z, 0)) continue;
        if (!hollow || !inside(x, yy, z, t)) out.add((x, y, z));
      }
    }
  }
  return out;
}

/// The run lengths along one edge of a circle-like shape, read from the
/// widest row out: the "3-2-2-1-1" builders count blocks with.
List<int> mcRunLengths(Set<(int, int)> cells, int width, int height) {
  if (cells.isEmpty) return const [];
  // Walk the top-left quarter's outline from the top row down: for each row,
  // how far the outline extends left compared with the row above.
  final runs = <int>[];
  int? previousLeft;
  for (var y = 0; y < (height + 1) ~/ 2; y++) {
    var left = -1;
    for (var x = 0; x < width; x++) {
      if (cells.contains((x, y))) {
        left = x;
        break;
      }
    }
    if (left < 0) continue;
    if (previousLeft == null) {
      // The top run: the cells across the top row up to the midline.
      var right = left;
      while (right + 1 < (width + 1) ~/ 2 && cells.contains((right + 1, y))) {
        right++;
      }
      runs.add(right - left + 1);
    } else if (left < previousLeft) {
      runs.add(previousLeft - left);
    } else {
      runs.add(1);
    }
    previousLeft = left;
  }
  return runs;
}

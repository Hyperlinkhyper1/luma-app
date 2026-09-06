import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'creature_model.dart';

/// Turns what the user drew into a body that physics can move.
///
/// The pipeline is the classic one for this: rasterise the strokes into a
/// filled mask, thin the mask down to a one-pixel medial axis, read that
/// skeleton back as a graph, then simplify the graph until it is a handful of
/// bones a genetic algorithm can still search in reasonable time.
///
/// Nothing here knows about widgets — it takes stroke points in any
/// coordinate space with y pointing down (a canvas) and returns metres with y
/// pointing up (the world).
abstract final class ShapeSkeleton {
  /// The size a creature is scaled to, in metres, so a big scribble and a
  /// small one start out equally able to walk.
  static const targetSize = 1.2;

  /// More bones means a richer gait but a much larger search space, and every
  /// extra joint costs three genes.
  static const maxBones = 18;

  /// Below this the mask is a speck and there is nothing to thin.
  static const _minMaskCells = 24;

  static CreatureShape? build(
    List<List<Offset>> strokes, {
    int resolution = 110,
  }) {
    final grid = _Grid.rasterise(strokes, resolution);
    if (grid == null) return null;
    grid.keepLargestBlob();
    if (grid.filledCells < _minMaskCells) return null;

    final distance = grid.distanceTransform();
    final skeleton = grid.thinned();
    final graph = _SkeletonGraph.trace(skeleton, grid.width, grid.height);
    if (graph == null) return null;

    graph.dedupeEdges();
    graph.pruneSpurs(grid.longestSpan);
    graph.resample(grid.longestSpan);
    graph.mergeCloseNodes(grid.longestSpan * 0.05);
    graph.dedupeEdges();
    graph.capBones(maxBones);
    if (graph.bones.length < 2) graph.subdivideForJoints();
    if (graph.bones.isEmpty) return null;

    return graph.toCreature(distance: distance, grid: grid, strokes: strokes);
  }
}

// ─── Raster mask ────────────────────────────────────────────────────────────

/// The drawing, burnt onto a grid. Cell (x, y) is inside the creature when
/// [cells] is 1.
class _Grid {
  _Grid({
    required this.cells,
    required this.width,
    required this.height,
    required this.cellSize,
    required this.originX,
    required this.originY,
  });

  final Uint8List cells;
  final int width;
  final int height;

  /// Size of one cell in the caller's drawing units.
  final double cellSize;
  final double originX;
  final double originY;

  int get filledCells {
    var n = 0;
    for (final c in cells) {
      if (c != 0) n++;
    }
    return n;
  }

  /// The longer side of the drawing in cells. Every "how small is too small"
  /// threshold below is a fraction of this, so they scale with the drawing.
  double get longestSpan => math.max(width, height).toDouble();

  int at(int x, int y) => y * width + x;

  /// Both a closed fill and a stroke stamp: a fat blob gets its inside filled,
  /// while a stick figure, whose strokes enclose almost no area, still ends up
  /// with enough body to thin.
  static _Grid? rasterise(List<List<Offset>> strokes, int resolution) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    var points = 0;
    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
        points++;
      }
    }
    if (points < 2) return null;

    final spanX = maxX - minX;
    final spanY = maxY - minY;
    final span = math.max(spanX, spanY);
    if (span <= 0) return null;

    final cellSize = span / resolution;
    final brush = math.max(1.8, resolution * 0.022);
    final pad = brush.ceil() + 3;
    final width = (spanX / cellSize).ceil() + pad * 2;
    final height = (spanY / cellSize).ceil() + pad * 2;
    final grid = _Grid(
      cells: Uint8List(width * height),
      width: width,
      height: height,
      cellSize: cellSize,
      originX: minX - pad * cellSize,
      originY: minY - pad * cellSize,
    );

    for (final stroke in strokes) {
      final cellPoints = [
        for (final p in stroke)
          Offset(
            (p.dx - grid.originX) / cellSize,
            (p.dy - grid.originY) / cellSize,
          ),
      ];
      if (cellPoints.length >= 3) grid._fillPolygon(cellPoints);
      grid._stampStroke(cellPoints, brush);
    }
    return grid;
  }

  /// Even-odd scanline fill of the auto-closed stroke.
  void _fillPolygon(List<Offset> polygon) {
    final crossings = <double>[];
    for (var y = 0; y < height; y++) {
      final scan = y + 0.5;
      crossings.clear();
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i];
        final b = polygon[(i + 1) % polygon.length];
        if ((a.dy <= scan && b.dy > scan) || (b.dy <= scan && a.dy > scan)) {
          final t = (scan - a.dy) / (b.dy - a.dy);
          crossings.add(a.dx + t * (b.dx - a.dx));
        }
      }
      if (crossings.length < 2) continue;
      crossings.sort();
      for (var i = 0; i + 1 < crossings.length; i += 2) {
        final from = math.max(0, crossings[i].ceil());
        final to = math.min(width - 1, crossings[i + 1].floor());
        for (var x = from; x <= to; x++) {
          cells[at(x, y)] = 1;
        }
      }
    }
  }

  void _stampStroke(List<Offset> stroke, double radius) {
    if (stroke.length == 1) {
      _stampDisc(stroke.first.dx, stroke.first.dy, radius);
      return;
    }
    for (var i = 0; i + 1 < stroke.length; i++) {
      final a = stroke[i];
      final b = stroke[i + 1];
      final steps = math.max(1, ((b - a).distance / 0.6).ceil());
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        _stampDisc(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t, radius);
      }
    }
  }

  void _stampDisc(double cx, double cy, double radius) {
    final r2 = radius * radius;
    final x0 = math.max(0, (cx - radius).floor());
    final x1 = math.min(width - 1, (cx + radius).ceil());
    final y0 = math.max(0, (cy - radius).floor());
    final y1 = math.min(height - 1, (cy + radius).ceil());
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        if (dx * dx + dy * dy <= r2) cells[at(x, y)] = 1;
      }
    }
  }

  /// One creature per drawing: a stray dot beside the body is dropped rather
  /// than turned into a second, disconnected skeleton.
  void keepLargestBlob() {
    final label = Int32List(cells.length)..fillRange(0, cells.length, -1);
    final queue = Int32List(cells.length);
    var best = -1;
    var bestSize = 0;
    var next = 0;
    for (var start = 0; start < cells.length; start++) {
      if (cells[start] == 0 || label[start] >= 0) continue;
      final id = next++;
      var head = 0;
      var tail = 0;
      queue[tail++] = start;
      label[start] = id;
      var size = 0;
      while (head < tail) {
        final p = queue[head++];
        size++;
        final px = p % width;
        final py = p ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = px + dx;
            final ny = py + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            final n = ny * width + nx;
            if (cells[n] == 0 || label[n] >= 0) continue;
            label[n] = id;
            queue[tail++] = n;
          }
        }
      }
      if (size > bestSize) {
        bestSize = size;
        best = id;
      }
    }
    if (best < 0) return;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != 0 && label[i] != best) cells[i] = 0;
    }
  }

  /// Chamfer 3-4 distance to the nearest empty cell, in cells. Sampled at a
  /// bone's midpoint this is how thick that part of the creature is.
  Float64List distanceTransform() {
    const far = 1 << 20;
    final d = Int32List(cells.length);
    for (var i = 0; i < cells.length; i++) {
      d[i] = cells[i] == 0 ? 0 : far;
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = at(x, y);
        if (d[i] == 0) continue;
        var best = d[i];
        if (x > 0) best = math.min(best, d[i - 1] + 3);
        if (y > 0) best = math.min(best, d[i - width] + 3);
        if (x > 0 && y > 0) best = math.min(best, d[i - width - 1] + 4);
        if (x < width - 1 && y > 0) best = math.min(best, d[i - width + 1] + 4);
        d[i] = best;
      }
    }
    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final i = at(x, y);
        if (d[i] == 0) continue;
        var best = d[i];
        if (x < width - 1) best = math.min(best, d[i + 1] + 3);
        if (y < height - 1) best = math.min(best, d[i + width] + 3);
        if (x < width - 1 && y < height - 1) {
          best = math.min(best, d[i + width + 1] + 4);
        }
        if (x > 0 && y < height - 1) best = math.min(best, d[i + width - 1] + 4);
        d[i] = best;
      }
    }
    final out = Float64List(cells.length);
    for (var i = 0; i < d.length; i++) {
      out[i] = d[i] / 3.0;
    }
    return out;
  }

  /// Zhang-Suen thinning: shave the mask from both sides, one layer at a time
  /// and never breaking it apart, until only the medial axis is left.
  Uint8List thinned() {
    final img = Uint8List.fromList(cells);
    final doomed = <int>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (var step = 0; step < 2; step++) {
        doomed.clear();
        for (var y = 1; y < height - 1; y++) {
          for (var x = 1; x < width - 1; x++) {
            final i = y * width + x;
            if (img[i] == 0) continue;
            final p2 = img[i - width];
            final p3 = img[i - width + 1];
            final p4 = img[i + 1];
            final p5 = img[i + width + 1];
            final p6 = img[i + width];
            final p7 = img[i + width - 1];
            final p8 = img[i - 1];
            final p9 = img[i - width - 1];
            final b = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
            if (b < 2 || b > 6) continue;
            var a = 0;
            if (p2 == 0 && p3 == 1) a++;
            if (p3 == 0 && p4 == 1) a++;
            if (p4 == 0 && p5 == 1) a++;
            if (p5 == 0 && p6 == 1) a++;
            if (p6 == 0 && p7 == 1) a++;
            if (p7 == 0 && p8 == 1) a++;
            if (p8 == 0 && p9 == 1) a++;
            if (p9 == 0 && p2 == 1) a++;
            if (a != 1) continue;
            if (step == 0) {
              if (p2 * p4 * p6 != 0) continue;
              if (p4 * p6 * p8 != 0) continue;
            } else {
              if (p2 * p4 * p8 != 0) continue;
              if (p2 * p6 * p8 != 0) continue;
            }
            doomed.add(i);
          }
        }
        if (doomed.isEmpty) continue;
        for (final i in doomed) {
          img[i] = 0;
        }
        changed = true;
      }
    }
    return img;
  }
}

// ─── Skeleton graph ─────────────────────────────────────────────────────────

class _Node {
  _Node(this.x, this.y);
  double x;
  double y;
  bool alive = true;
}

class _Edge {
  _Edge(this.a, this.b, this.path);
  int a;
  int b;

  /// The skeleton pixels this bone was traced from, kept until the graph is
  /// simplified so pruning can measure a branch by its real, curvy length.
  List<Offset> path;
  bool alive = true;

  double get length {
    var total = 0.0;
    for (var i = 0; i + 1 < path.length; i++) {
      total += (path[i + 1] - path[i]).distance;
    }
    return total;
  }
}

/// The thinned mask read as nodes (endpoints and junctions) joined by chains
/// of one-pixel-wide skeleton, then reduced to something a physics solver can
/// carry: a handful of straight bones.
class _SkeletonGraph {
  _SkeletonGraph(this.nodes, this.edges);

  final List<_Node> nodes;
  final List<_Edge> edges;

  List<_Edge> get bones => [for (final e in edges) if (e.alive) e];
  List<int> get liveNodes => [
        for (var i = 0; i < nodes.length; i++)
          if (nodes[i].alive) i,
      ];

  static _SkeletonGraph? trace(Uint8List skeleton, int width, int height) {
    int degreeAt(int i) {
      final x = i % width;
      final y = i ~/ width;
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          if (skeleton[ny * width + nx] != 0) n++;
        }
      }
      return n;
    }

    List<int> neighboursOf(int i) {
      final x = i % width;
      final y = i ~/ width;
      final out = <int>[];
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final n = ny * width + nx;
          if (skeleton[n] != 0) out.add(n);
        }
      }
      return out;
    }

    final nodePixel = <int, int>{};
    final nodes = <_Node>[];
    final pixels = <int>[];
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] == 0) continue;
      pixels.add(i);
      final d = degreeAt(i);
      if (d != 2) {
        nodePixel[i] = nodes.length;
        nodes.add(_Node((i % width) + 0.5, (i ~/ width) + 0.5));
      }
    }
    if (pixels.isEmpty) return null;

    // A perfect ring has no endpoints and no junctions. Break it open at an
    // arbitrary pixel so it still becomes a chain of bones.
    if (nodes.isEmpty) {
      final i = pixels.first;
      nodePixel[i] = 0;
      nodes.add(_Node((i % width) + 0.5, (i ~/ width) + 0.5));
    }

    final edges = <_Edge>[];
    final walked = Uint8List(skeleton.length);
    for (final entry in nodePixel.entries) {
      final startPixel = entry.key;
      final startNode = entry.value;
      for (final first in neighboursOf(startPixel)) {
        if (nodePixel.containsKey(first)) {
          if (nodePixel[first]! < startNode) continue;
          if (nodePixel[first] == startNode) continue;
          edges.add(_Edge(startNode, nodePixel[first]!, [
            Offset(nodes[startNode].x, nodes[startNode].y),
            Offset(nodes[nodePixel[first]!].x, nodes[nodePixel[first]!].y),
          ]));
          continue;
        }
        if (walked[first] != 0) continue;
        final path = <Offset>[Offset(nodes[startNode].x, nodes[startNode].y)];
        var previous = startPixel;
        var current = first;
        while (true) {
          walked[current] = 1;
          path.add(Offset((current % width) + 0.5, (current ~/ width) + 0.5));
          final next = neighboursOf(current)
              .where((n) => n != previous && walked[n] == 0)
              .toList();
          final junction = next.where(nodePixel.containsKey).toList();
          if (junction.isNotEmpty) {
            final end = junction.first;
            path.add(Offset(nodes[nodePixel[end]!].x, nodes[nodePixel[end]!].y));
            edges.add(_Edge(startNode, nodePixel[end]!, path));
            break;
          }
          if (next.isEmpty) {
            // Ran into an already-walked chain: close it off where it stopped.
            final tip = nodes.length;
            nodes.add(_Node(path.last.dx, path.last.dy));
            edges.add(_Edge(startNode, tip, path));
            break;
          }
          previous = current;
          current = next.first;
        }
      }
    }
    if (edges.isEmpty) return null;
    return _SkeletonGraph(nodes, edges);
  }

  int degree(int node) {
    var n = 0;
    for (final e in edges) {
      if (!e.alive) continue;
      if (e.a == node || e.b == node) n++;
    }
    return n;
  }

  /// Thinning throws off a spike at every bump on the outline. Anything much
  /// shorter than the creature itself is one of those, not a limb.
  void pruneSpurs(double span) {
    final threshold = span * 0.16;
    var pruned = true;
    while (pruned) {
      pruned = false;
      for (final e in edges) {
        if (!e.alive) continue;
        final leaf = degree(e.a) == 1 || degree(e.b) == 1;
        if (!leaf) continue;
        if (e.length >= threshold) continue;
        if (bones.length <= 2) return;
        e.alive = false;
        pruned = true;
      }
      _dropOrphanNodes();
    }
    _mergeChainNodes();
  }

  /// A node joining exactly two bones in a straight-ish line adds a joint
  /// without adding any freedom worth searching, so fuse the two bones.
  void _mergeChainNodes() {
    var merged = true;
    while (merged) {
      merged = false;
      for (var n = 0; n < nodes.length; n++) {
        if (!nodes[n].alive) continue;
        final touching = [
          for (final e in edges)
            if (e.alive && (e.a == n || e.b == n)) e,
        ];
        if (touching.length != 2) continue;
        final first = touching[0];
        final second = touching[1];
        if (first.a == second.a && first.b == second.b) continue;
        final path = <Offset>[
          ..._orientedPath(first, towards: n),
          ..._orientedPath(second, towards: n).reversed.skip(1),
        ];
        final other1 = first.a == n ? first.b : first.a;
        final other2 = second.a == n ? second.b : second.a;
        if (other1 == other2) continue;
        first.alive = false;
        second.alive = false;
        nodes[n].alive = false;
        edges.add(_Edge(other1, other2, path));
        merged = true;
        break;
      }
    }
  }

  List<Offset> _orientedPath(_Edge e, {required int towards}) =>
      e.b == towards ? e.path : e.path.reversed.toList();

  void _dropOrphanNodes() {
    for (var i = 0; i < nodes.length; i++) {
      if (!nodes[i].alive) continue;
      if (degree(i) == 0) nodes[i].alive = false;
    }
  }

  /// Straight bones from curvy chains. A long chain becomes several bones so
  /// a tail or a leg can still bend; a short one stays a single bone.
  void resample(double span) {
    final maxBoneLength = span * 0.3;
    for (final e in List<_Edge>.from(edges)) {
      if (!e.alive) continue;
      final pieces = math.min(4, math.max(1, (e.length / maxBoneLength).ceil()));
      if (pieces == 1) {
        e.path = [e.path.first, e.path.last];
        continue;
      }
      e.alive = false;
      final points = _samplePath(e.path, pieces);
      var previous = e.a;
      for (var i = 1; i < points.length; i++) {
        final isLast = i == points.length - 1;
        final next = isLast ? e.b : nodes.length;
        if (!isLast) nodes.add(_Node(points[i].dx, points[i].dy));
        edges.add(_Edge(previous, next, [points[i - 1], points[i]]));
        previous = next;
      }
    }
    for (final e in edges) {
      if (!e.alive) continue;
      e.path = [
        Offset(nodes[e.a].x, nodes[e.a].y),
        Offset(nodes[e.b].x, nodes[e.b].y),
      ];
    }
  }

  /// [pieces] + 1 points spread evenly along the chain by arc length.
  static List<Offset> _samplePath(List<Offset> path, int pieces) {
    var total = 0.0;
    final cumulative = <double>[0];
    for (var i = 0; i + 1 < path.length; i++) {
      total += (path[i + 1] - path[i]).distance;
      cumulative.add(total);
    }
    final out = <Offset>[path.first];
    for (var p = 1; p < pieces; p++) {
      final target = total * p / pieces;
      var i = 0;
      while (i + 2 < path.length && cumulative[i + 1] < target) {
        i++;
      }
      final segment = cumulative[i + 1] - cumulative[i];
      final t = segment <= 0 ? 0.0 : (target - cumulative[i]) / segment;
      out.add(Offset.lerp(path[i], path[i + 1], t)!);
    }
    out.add(path.last);
    return out;
  }

  /// Two bones joining the same pair of nodes are the same bone. They appear
  /// whenever nearby junctions get merged, and left alone they eat the bone
  /// budget — which is what truncates a skeleton to a couple of limbs.
  void dedupeEdges() {
    final seen = <int>{};
    for (final e in edges) {
      if (!e.alive) continue;
      if (e.a == e.b) {
        e.alive = false;
        continue;
      }
      final key = e.a < e.b
          ? e.a * nodes.length + e.b
          : e.b * nodes.length + e.a;
      if (!seen.add(key)) e.alive = false;
    }
    _dropOrphanNodes();
  }

  void mergeCloseNodes(double minSpacing) {
    for (var i = 0; i < nodes.length; i++) {
      if (!nodes[i].alive) continue;
      for (var j = i + 1; j < nodes.length; j++) {
        if (!nodes[j].alive) continue;
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        if (dx * dx + dy * dy > minSpacing * minSpacing) continue;
        if (bones.length <= 2) return;
        for (final e in edges) {
          if (!e.alive) continue;
          if (e.a == j) e.a = i;
          if (e.b == j) e.b = i;
          if (e.a == e.b) e.alive = false;
        }
        nodes[j].alive = false;
      }
    }
    _dropOrphanNodes();
  }

  /// Every bone past the cap costs the search three more genes, so trim the
  /// least important ones — the shortest limb tips — until we are under it.
  void capBones(int max) {
    while (bones.length > max) {
      _Edge? worst;
      for (final e in bones) {
        if (degree(e.a) != 1 && degree(e.b) != 1) continue;
        if (worst == null || e.length < worst.length) worst = e;
      }
      worst ??= bones.reduce((a, b) => a.length <= b.length ? a : b);
      worst.alive = false;
      _dropOrphanNodes();
    }
  }

  /// A creature with a single bone has no joint and therefore no way to move.
  /// Split it so there is something to drive.
  void subdivideForJoints() {
    final only = bones.isEmpty ? null : bones.first;
    if (only == null) return;
    only.alive = false;
    final points = _samplePath(
      [
        Offset(nodes[only.a].x, nodes[only.a].y),
        Offset(nodes[only.b].x, nodes[only.b].y),
      ],
      3,
    );
    var previous = only.a;
    for (var i = 1; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final next = isLast ? only.b : nodes.length;
      if (!isLast) nodes.add(_Node(points[i].dx, points[i].dy));
      edges.add(_Edge(previous, next, [points[i - 1], points[i]]));
      previous = next;
    }
  }

  /// Packs the simplified graph into the flat, isolate-friendly
  /// [CreatureShape], converting grid cells into metres on the way and
  /// building the joint tree the motors drive.
  CreatureShape toCreature({
    required Float64List distance,
    required _Grid grid,
    required List<List<Offset>> strokes,
  }) {
    final live = liveNodes;
    final index = <int, int>{
      for (var i = 0; i < live.length; i++) live[i]: i,
    };
    final liveBones = bones;

    var minCellX = double.infinity;
    var maxCellX = -double.infinity;
    var minCellY = double.infinity;
    var maxCellY = -double.infinity;
    for (final n in live) {
      minCellX = math.min(minCellX, nodes[n].x);
      maxCellX = math.max(maxCellX, nodes[n].x);
      minCellY = math.min(minCellY, nodes[n].y);
      maxCellY = math.max(maxCellY, nodes[n].y);
    }
    final spanCells = math.max(
      math.max(maxCellX - minCellX, maxCellY - minCellY),
      1.0,
    );
    final metresPerCell = ShapeSkeleton.targetSize / spanCells;

    double worldX(double cellX) => (cellX - (minCellX + maxCellX) / 2) * metresPerCell;
    double worldY(double cellY) => (maxCellY - cellY) * metresPerCell;

    final nodeX = Float64List(live.length);
    final nodeY = Float64List(live.length);
    for (var i = 0; i < live.length; i++) {
      nodeX[i] = worldX(nodes[live[i]].x);
      nodeY[i] = worldY(nodes[live[i]].y);
    }

    final boneA = Int32List(liveBones.length);
    final boneB = Int32List(liveBones.length);
    final boneThickness = Float64List(liveBones.length);
    for (var i = 0; i < liveBones.length; i++) {
      final e = liveBones[i];
      boneA[i] = index[e.a]!;
      boneB[i] = index[e.b]!;
      boneThickness[i] = _thicknessOf(e, distance, grid) * metresPerCell;
    }

    final nodeRadius = Float64List(live.length);
    final nodeMass = Float64List(live.length);
    for (var b = 0; b < liveBones.length; b++) {
      final a = boneA[b];
      final c = boneB[b];
      final half = boneThickness[b] / 2;
      nodeRadius[a] = math.max(nodeRadius[a], half);
      nodeRadius[c] = math.max(nodeRadius[c], half);
      final dx = nodeX[a] - nodeX[c];
      final dy = nodeY[a] - nodeY[c];
      final mass = math.sqrt(dx * dx + dy * dy) * boneThickness[b] * 40;
      nodeMass[a] += mass / 2;
      nodeMass[c] += mass / 2;
    }
    for (var i = 0; i < nodeMass.length; i++) {
      nodeMass[i] = math.max(nodeMass[i], 0.35);
      nodeRadius[i] = nodeRadius[i].clamp(0.012, 0.12);
    }

    // Stand the creature on the ground with a hair of clearance, so the first
    // frame of a trial is a drop rather than an interpenetration.
    var lowest = double.infinity;
    for (var i = 0; i < live.length; i++) {
      lowest = math.min(lowest, nodeY[i] - nodeRadius[i]);
    }
    for (var i = 0; i < live.length; i++) {
      nodeY[i] += 0.02 - lowest;
    }

    var head = 0;
    for (var i = 1; i < live.length; i++) {
      if (nodeY[i] > nodeY[head]) head = i;
    }

    final tree = _buildJointTree(
      nodeCount: live.length,
      boneA: boneA,
      boneB: boneB,
      nodeX: nodeX,
      nodeY: nodeY,
      nodeMass: nodeMass,
    );

    final outline = <Float64List>[];
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final flat = Float64List(stroke.length * 2);
      for (var i = 0; i < stroke.length; i++) {
        final cellX = (stroke[i].dx - grid.originX) / grid.cellSize;
        final cellY = (stroke[i].dy - grid.originY) / grid.cellSize;
        flat[i * 2] = worldX(cellX);
        flat[i * 2 + 1] = worldY(cellY) + 0.02 - lowest;
      }
      outline.add(flat);
    }

    return CreatureShape(
      nodeX: nodeX,
      nodeY: nodeY,
      nodeRadius: nodeRadius,
      nodeMass: nodeMass,
      boneA: boneA,
      boneB: boneB,
      boneThickness: boneThickness,
      jointParentBone: tree.parentBone,
      jointChildBone: tree.childBone,
      jointPivot: tree.pivot,
      jointRestAngle: tree.restAngle,
      jointSubtree: tree.subtree,
      jointAnchor: tree.anchor,
      jointSubtreeMassFraction: tree.massFraction,
      headNode: head,
      outline: outline,
      drawingScale: metresPerCell / grid.cellSize,
      drawingCentreX:
          grid.originX + (minCellX + maxCellX) / 2 * grid.cellSize,
      drawingBaseY: grid.originY +
          maxCellY * grid.cellSize +
          (0.02 - lowest) / (metresPerCell / grid.cellSize),
    );
  }

  /// Median of a few samples down the middle of the bone, so a bone that
  /// clips a thin spot does not come out anorexic.
  static double _thicknessOf(_Edge e, Float64List distance, _Grid grid) {
    final samples = <double>[];
    for (var s = 1; s <= 5; s++) {
      final t = s / 6;
      final x = (e.path.first.dx + (e.path.last.dx - e.path.first.dx) * t).floor();
      final y = (e.path.first.dy + (e.path.last.dy - e.path.first.dy) * t).floor();
      if (x < 0 || y < 0 || x >= grid.width || y >= grid.height) continue;
      samples.add(distance[y * grid.width + x]);
    }
    if (samples.isEmpty) return 2;
    samples.sort();
    return math.max(1.2, samples[samples.length ~/ 2]) * 2;
  }
}

class _JointTree {
  _JointTree({
    required this.parentBone,
    required this.childBone,
    required this.pivot,
    required this.restAngle,
    required this.subtree,
    required this.anchor,
    required this.massFraction,
  });

  final Int32List parentBone;
  final Int32List childBone;
  final Int32List pivot;
  final Float64List restAngle;
  final List<Int32List> subtree;
  final List<Int32List> anchor;
  final Float64List massFraction;
}

/// Walks the bones outward from the one nearest the body's centre, so every
/// joint has a clear "this side swings, that side pushes back" split. Bones
/// that close a loop get no motor; the distance constraints hold them.
_JointTree _buildJointTree({
  required int nodeCount,
  required Int32List boneA,
  required Int32List boneB,
  required Float64List nodeX,
  required Float64List nodeY,
  required Float64List nodeMass,
}) {
  final boneCount = boneA.length;
  var centreX = 0.0;
  var centreY = 0.0;
  for (var i = 0; i < nodeCount; i++) {
    centreX += nodeX[i];
    centreY += nodeY[i];
  }
  centreX /= nodeCount;
  centreY /= nodeCount;

  var root = 0;
  var rootDistance = double.infinity;
  for (var b = 0; b < boneCount; b++) {
    final mx = (nodeX[boneA[b]] + nodeX[boneB[b]]) / 2;
    final my = (nodeY[boneA[b]] + nodeY[boneB[b]]) / 2;
    final d = (mx - centreX) * (mx - centreX) + (my - centreY) * (my - centreY);
    if (d < rootDistance) {
      rootDistance = d;
      root = b;
    }
  }

  final visited = List<bool>.filled(boneCount, false);
  final children = List<List<int>>.generate(boneCount, (_) => <int>[]);
  final parentOf = List<int>.filled(boneCount, -1);
  final pivotOf = List<int>.filled(boneCount, -1);
  final order = <int>[];
  visited[root] = true;
  final queue = <int>[root];
  while (queue.isNotEmpty) {
    final bone = queue.removeAt(0);
    order.add(bone);
    for (var other = 0; other < boneCount; other++) {
      if (visited[other]) continue;
      int shared = -1;
      if (boneA[other] == boneA[bone] || boneA[other] == boneB[bone]) {
        shared = boneA[other];
      } else if (boneB[other] == boneA[bone] || boneB[other] == boneB[bone]) {
        shared = boneB[other];
      }
      if (shared < 0) continue;
      visited[other] = true;
      parentOf[other] = bone;
      pivotOf[other] = shared;
      children[bone].add(other);
      queue.add(other);
    }
  }

  // Nodes owned by each bone's subtree, gathered from the leaves inward.
  final owned = List<Set<int>>.generate(boneCount, (_) => <int>{});
  for (final bone in order.reversed) {
    owned[bone]
      ..add(boneA[bone])
      ..add(boneB[bone]);
    for (final child in children[bone]) {
      owned[bone].addAll(owned[child]);
    }
  }

  var totalMass = 0.0;
  for (var i = 0; i < nodeCount; i++) {
    totalMass += nodeMass[i];
  }

  final parentBone = <int>[];
  final childBone = <int>[];
  final pivot = <int>[];
  final restAngle = <double>[];
  final subtree = <Int32List>[];
  final anchor = <Int32List>[];
  final massFraction = <double>[];

  for (var bone = 0; bone < boneCount; bone++) {
    final parent = parentOf[bone];
    if (parent < 0) continue;
    final p = pivotOf[bone];
    final parentFar = boneA[parent] == p ? boneB[parent] : boneA[parent];
    final childFar = boneA[bone] == p ? boneB[bone] : boneA[bone];

    final swing = <int>[
      for (final n in owned[bone])
        if (n != p) n,
    ]..sort();
    if (swing.isEmpty) continue;
    final swingSet = swing.toSet();
    final rest = <int>[
      for (var n = 0; n < nodeCount; n++)
        if (n != p && !swingSet.contains(n)) n,
    ];
    if (rest.isEmpty) continue;

    var swingMass = 0.0;
    for (final n in swing) {
      swingMass += nodeMass[n];
    }

    parentBone.add(parent);
    childBone.add(bone);
    pivot.add(p);
    restAngle.add(
      _angleBetween(
        nodeX[parentFar] - nodeX[p],
        nodeY[parentFar] - nodeY[p],
        nodeX[childFar] - nodeX[p],
        nodeY[childFar] - nodeY[p],
      ),
    );
    subtree.add(Int32List.fromList(swing));
    anchor.add(Int32List.fromList(rest));
    massFraction.add((swingMass / totalMass).clamp(0.05, 0.95));
  }

  return _JointTree(
    parentBone: Int32List.fromList(parentBone),
    childBone: Int32List.fromList(childBone),
    pivot: Int32List.fromList(pivot),
    restAngle: Float64List.fromList(restAngle),
    subtree: subtree,
    anchor: anchor,
    massFraction: Float64List.fromList(massFraction),
  );
}

/// Signed angle from (ax, ay) to (bx, by), in -pi..pi.
double _angleBetween(double ax, double ay, double bx, double by) =>
    math.atan2(ax * by - ay * bx, ax * bx + ay * by);

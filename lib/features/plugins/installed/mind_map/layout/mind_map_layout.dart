import 'dart:ui';

/// Which way a map's branches grow away from the root.
enum MindMapDirection {
  /// Classic mind map: everything flows to the right of the root.
  right,

  /// Root in the middle, branches split left and right.
  both,

  /// Org-chart style: the root on top, children below it.
  down,
}

extension MindMapDirectionLabel on MindMapDirection {
  String get label => switch (this) {
        MindMapDirection.right => 'Right',
        MindMapDirection.both => 'Both sides',
        MindMapDirection.down => 'Downward',
      };
}

/// One node handed to the layout engine.
///
/// The engine never reads the database or the widget tree — it takes measured
/// boxes in and gives positioned rectangles back, which is what makes the
/// whole arrangement testable without a Flutter binding.
class MindMapLayoutNode {
  const MindMapLayoutNode({
    required this.id,
    required this.parentId,
    required this.sortIndex,
    required this.size,
    this.collapsed = false,
  });

  final int id;
  final int? parentId;
  final int sortIndex;
  final Size size;

  /// When true this node's descendants are hidden and take up no space.
  final bool collapsed;
}

/// The computed arrangement: where every visible node sits, plus the overall
/// canvas the caller has to make room for.
class MindMapLayoutResult {
  const MindMapLayoutResult({required this.positions, required this.canvasSize});

  final Map<int, Rect> positions;
  final Size canvasSize;

  bool get isEmpty => positions.isEmpty;
}

/// Arranges a mind map so branches never overlap and the user never has to
/// place a node by hand.
///
/// Each depth gets its own column (or row, growing downward) sized to the
/// widest node in it, so sibling branches line up. Across the other axis
/// leaves are stacked in order and every parent is centred on the block its
/// children occupy — the tidy-tree shape people expect from a mind map.
class MindMapLayout {
  const MindMapLayout._();

  static const double defaultSiblingGap = 16;
  static const double defaultLevelGap = 64;

  /// Slack left around the arrangement so a node can always be dragged past
  /// the edge of the current tree without hitting the end of the canvas.
  static const double padding = 160;

  static MindMapLayoutResult compute({
    required List<MindMapLayoutNode> nodes,
    MindMapDirection direction = MindMapDirection.right,
    double siblingGap = defaultSiblingGap,
    double levelGap = defaultLevelGap,
  }) {
    if (nodes.isEmpty) {
      return const MindMapLayoutResult(positions: {}, canvasSize: Size.zero);
    }

    final byId = {for (final n in nodes) n.id: n};
    final children = <int?, List<MindMapLayoutNode>>{};
    for (final n in nodes) {
      // A parent deleted out from under a node leaves it a root rather than
      // dropping it off the canvas entirely.
      final parent =
          n.parentId != null && byId.containsKey(n.parentId) ? n.parentId : null;
      children.putIfAbsent(parent, () => []).add(n);
    }
    for (final list in children.values) {
      list.sort((a, b) {
        final byIndex = a.sortIndex.compareTo(b.sortIndex);
        return byIndex != 0 ? byIndex : a.id.compareTo(b.id);
      });
    }

    final roots = children[null] ?? const <MindMapLayoutNode>[];
    if (roots.isEmpty) {
      return const MindMapLayoutResult(positions: {}, canvasSize: Size.zero);
    }

    final vertical = direction == MindMapDirection.down;
    final depths = <int, int>{};
    _assignDepths(roots, children, depths, 0);

    // Column (or row) extents, so every node at the same depth starts on the
    // same line and sibling branches read as a tidy comb.
    final extentAtDepth = <int, double>{};
    for (final entry in depths.entries) {
      final node = byId[entry.key]!;
      final extent = vertical ? node.size.height : node.size.width;
      final current = extentAtDepth[entry.value];
      if (current == null || extent > current) {
        extentAtDepth[entry.value] = extent;
      }
    }
    final maxDepth = extentAtDepth.keys.fold<int>(0, (a, b) => a > b ? a : b);
    final mainAxisStart = <int, double>{0: 0};
    for (var d = 1; d <= maxDepth; d++) {
      mainAxisStart[d] =
          mainAxisStart[d - 1]! + (extentAtDepth[d - 1] ?? 0) + levelGap;
    }

    final positions = <int, Rect>{};

    if (direction == MindMapDirection.both && roots.length == 1) {
      _layoutBothSides(
        root: roots.first,
        children: children,
        depths: depths,
        mainAxisStart: mainAxisStart,
        extentAtDepth: extentAtDepth,
        siblingGap: siblingGap,
        levelGap: levelGap,
        positions: positions,
      );
    } else {
      var cursor = 0.0;
      for (final root in roots) {
        cursor = _place(
          node: root,
          children: children,
          depths: depths,
          mainAxisStart: mainAxisStart,
          siblingGap: siblingGap,
          positions: positions,
          cursor: cursor,
          vertical: vertical,
          mirrored: false,
        ).cursor;
        cursor += siblingGap * 2;
      }
    }

    return _normalize(positions);
  }

  static void _assignDepths(
    List<MindMapLayoutNode> level,
    Map<int?, List<MindMapLayoutNode>> children,
    Map<int, int> depths,
    int depth,
  ) {
    for (final node in level) {
      if (depths.containsKey(node.id)) continue;
      depths[node.id] = depth;
      if (node.collapsed) continue;
      _assignDepths(children[node.id] ?? const [], children, depths, depth + 1);
    }
  }

  static _Placement _place({
    required MindMapLayoutNode node,
    required Map<int?, List<MindMapLayoutNode>> children,
    required Map<int, int> depths,
    required Map<int, double> mainAxisStart,
    required double siblingGap,
    required Map<int, Rect> positions,
    required double cursor,
    required bool vertical,
    required bool mirrored,
  }) {
    final depth = depths[node.id]!;
    final kids =
        node.collapsed ? const <MindMapLayoutNode>[] : (children[node.id] ?? const []);
    final crossExtent = vertical ? node.size.width : node.size.height;

    double centre;
    var nextCursor = cursor;

    if (kids.isEmpty) {
      centre = cursor + crossExtent / 2;
      nextCursor = cursor + crossExtent + siblingGap;
    } else {
      final centres = <double>[];
      for (final kid in kids) {
        final placed = _place(
          node: kid,
          children: children,
          depths: depths,
          mainAxisStart: mainAxisStart,
          siblingGap: siblingGap,
          positions: positions,
          cursor: nextCursor,
          vertical: vertical,
          mirrored: mirrored,
        );
        centres.add(placed.centre);
        nextCursor = placed.cursor;
      }
      centre = (centres.first + centres.last) / 2;

      // A parent taller than the block of children it straddles would
      // otherwise bleed into the next sibling group.
      final parentEnd = centre + crossExtent / 2 + siblingGap;
      if (parentEnd > nextCursor) nextCursor = parentEnd;
    }

    final main = mainAxisStart[depth]!;
    final cross = centre - crossExtent / 2;
    positions[node.id] = vertical
        ? Rect.fromLTWH(cross, main, node.size.width, node.size.height)
        : Rect.fromLTWH(
            mirrored ? -main - node.size.width : main,
            cross,
            node.size.width,
            node.size.height,
          );

    return _Placement(centre: centre, cursor: nextCursor);
  }

  static void _layoutBothSides({
    required MindMapLayoutNode root,
    required Map<int?, List<MindMapLayoutNode>> children,
    required Map<int, int> depths,
    required Map<int, double> mainAxisStart,
    required Map<int, double> extentAtDepth,
    required double siblingGap,
    required double levelGap,
    required Map<int, Rect> positions,
  }) {
    final kids =
        root.collapsed ? const <MindMapLayoutNode>[] : (children[root.id] ?? const []);
    if (kids.isEmpty) {
      positions[root.id] = Rect.fromLTWH(0, 0, root.size.width, root.size.height);
      return;
    }

    // Split by accumulated leaf count rather than plain child count, so one
    // heavy branch does not leave the map lopsided.
    final weights = [for (final k in kids) _leafCount(k, children)];
    final total = weights.fold<int>(0, (a, b) => a + b);
    final right = <MindMapLayoutNode>[];
    final left = <MindMapLayoutNode>[];
    var accumulated = 0;
    for (var i = 0; i < kids.length; i++) {
      if (accumulated * 2 < total) {
        right.add(kids[i]);
      } else {
        left.add(kids[i]);
      }
      accumulated += weights[i];
    }

    final centres = <double>[];
    for (final side in [right, left]) {
      var cursor = 0.0;
      for (final kid in side) {
        final placed = _place(
          node: kid,
          children: children,
          depths: depths,
          mainAxisStart: mainAxisStart,
          siblingGap: siblingGap,
          positions: positions,
          cursor: cursor,
          vertical: false,
          mirrored: identical(side, left),
        );
        cursor = placed.cursor;
      }
      if (side.isNotEmpty) {
        final first = positions[side.first.id]!;
        final last = positions[side.last.id]!;
        centres.add((first.top + last.bottom) / 2);
      }
    }

    final centre = centres.isEmpty
        ? root.size.height / 2
        : centres.reduce((a, b) => a + b) / centres.length;

    final rootExtent = extentAtDepth[0] ?? root.size.width;

    // Both halves were laid out from x = 0, so pull them apart to leave the
    // root sitting in the gap between them.
    final shift = rootExtent / 2 + levelGap / 2;
    for (final entry in positions.entries.toList()) {
      final r = entry.value;
      positions[entry.key] =
          r.left < 0 ? r.translate(-shift, 0) : r.translate(shift, 0);
    }

    positions[root.id] = Rect.fromLTWH(
      -root.size.width / 2,
      centre - root.size.height / 2,
      root.size.width,
      root.size.height,
    );
  }

  static int _leafCount(
    MindMapLayoutNode node,
    Map<int?, List<MindMapLayoutNode>> children,
  ) {
    final kids =
        node.collapsed ? const <MindMapLayoutNode>[] : (children[node.id] ?? const []);
    if (kids.isEmpty) return 1;
    return kids.fold<int>(0, (sum, k) => sum + _leafCount(k, children));
  }

  static MindMapLayoutResult _normalize(Map<int, Rect> positions) {
    if (positions.isEmpty) {
      return const MindMapLayoutResult(positions: {}, canvasSize: Size.zero);
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final r in positions.values) {
      if (r.left < minX) minX = r.left;
      if (r.top < minY) minY = r.top;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
    }
    final shifted = <int, Rect>{
      for (final e in positions.entries)
        e.key: e.value.translate(padding - minX, padding - minY),
    };
    return MindMapLayoutResult(
      positions: shifted,
      canvasSize: Size(maxX - minX + padding * 2, maxY - minY + padding * 2),
    );
  }
}

class _Placement {
  const _Placement({required this.centre, required this.cursor});
  final double centre;
  final double cursor;
}

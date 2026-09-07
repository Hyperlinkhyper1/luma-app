import 'package:flutter/material.dart';

import '../data/mind_map_database.dart';

/// Visual rules shared by the canvas painter, the node cards and the size
/// measurement that feeds the layout engine.
///
/// Measurement lives here rather than in the widgets because the layout has
/// to know how big every node is *before* anything is built — and the numbers
/// used to measure must be the exact numbers the card then renders with, or
/// text would overflow the box the layout reserved for it.
class MindMapStyle {
  const MindMapStyle._();

  static const double maxLabelWidth = 190;
  static const double minNodeWidth = 92;
  static const double horizontalPadding = 14;
  static const double verticalPadding = 10;
  static const double minNodeHeight = 40;
  static const double badgeWidth = 22;

  /// Fixed whether the pill shows a count or a chevron, so folding a branch
  /// never changes the node's measured width.
  static const double collapsePillWidth = 26;
  static const double cornerRadius = 12;

  /// Branch colours, one per top-level branch, cycling after that.
  ///
  /// These are used as a tint and a border rather than a solid fill, so the
  /// label always sits on the theme's own surface and stays readable in both
  /// light and dark mode without a second palette.
  static const List<Color> branchColors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
    Color(0xFF84CC16),
  ];

  static TextStyle labelStyle({required bool isRoot}) => TextStyle(
        fontSize: isRoot ? 15 : 13.5,
        fontWeight: isRoot ? FontWeight.w700 : FontWeight.w600,
        height: 1.3,
      );

  /// Measures the box a node needs for [label].
  ///
  /// [extrasWidth] is the room taken by the badges rendered beside the label
  /// (note, link, collapse pill), so they never push the text out of the
  /// rectangle the layout reserved.
  static Size measure({
    required String label,
    required bool isRoot,
    required double extrasWidth,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    final text = label.trim().isEmpty ? 'New idea' : label;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 4,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    final width = (painter.width + horizontalPadding * 2 + extrasWidth)
        .clamp(minNodeWidth, maxLabelWidth + horizontalPadding * 2 + extrasWidth);
    final height =
        (painter.height + verticalPadding * 2).clamp(minNodeHeight, double.infinity);
    return Size(width, height);
  }

  /// Resolves the colour a node paints with.
  ///
  /// A node with no colour of its own inherits from the nearest ancestor that
  /// has one, so recolouring a whole branch is a single edit. Failing that,
  /// its top-level branch decides, which is what gives an untouched map its
  /// rainbow of branches.
  static Map<int, Color> resolveColors({
    required List<MindMapNode> nodes,
    required Color rootColor,
  }) {
    final byId = {for (final n in nodes) n.id: n};
    final childrenOf = <int?, List<MindMapNode>>{};
    for (final n in nodes) {
      final parent = n.parentId != null && byId.containsKey(n.parentId) ? n.parentId : null;
      childrenOf.putIfAbsent(parent, () => []).add(n);
    }
    for (final list in childrenOf.values) {
      list.sort((a, b) {
        final byIndex = a.sortIndex.compareTo(b.sortIndex);
        return byIndex != 0 ? byIndex : a.id.compareTo(b.id);
      });
    }

    final resolved = <int, Color>{};
    final seen = <int>{};

    void walk(MindMapNode node, Color inherited, int depth, int branchIndex) {
      if (!seen.add(node.id)) return;
      final own = node.color == null ? null : Color(node.color!);
      final color = own ??
          (depth == 0
              ? rootColor
              : depth == 1
                  ? branchColors[branchIndex % branchColors.length]
                  : inherited);
      resolved[node.id] = color;
      final kids = childrenOf[node.id] ?? const <MindMapNode>[];
      for (var i = 0; i < kids.length; i++) {
        walk(kids[i], color, depth + 1, depth == 0 ? i : branchIndex);
      }
    }

    final roots = childrenOf[null] ?? const <MindMapNode>[];
    for (var i = 0; i < roots.length; i++) {
      walk(roots[i], rootColor, 0, i);
    }
    return resolved;
  }

  /// Depth of every node, so the painter can taper connectors and the cards
  /// can tell a root from a leaf.
  static Map<int, int> resolveDepths(List<MindMapNode> nodes) {
    final byId = {for (final n in nodes) n.id: n};
    final depths = <int, int>{};
    for (final node in nodes) {
      var depth = 0;
      var cursor = node;
      final seen = <int>{node.id};
      while (cursor.parentId != null && byId.containsKey(cursor.parentId)) {
        final parent = byId[cursor.parentId]!;
        if (!seen.add(parent.id)) break;
        cursor = parent;
        depth++;
      }
      depths[node.id] = depth;
    }
    return depths;
  }
}

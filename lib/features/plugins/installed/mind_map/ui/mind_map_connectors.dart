import 'package:flutter/material.dart';

/// One parent-to-child link, already resolved to screen rectangles.
class MindMapConnector {
  const MindMapConnector({
    required this.parent,
    required this.child,
    required this.color,
    required this.depth,
  });

  final Rect parent;
  final Rect child;
  final Color color;
  final int depth;
}

/// Draws the curves between nodes.
///
/// Curves rather than straight lines, and anchored to the facing edges of the
/// two boxes rather than to their centres — the old School canvas drew to a
/// hard-coded centre offset, so lines visibly missed any node that was not
/// exactly the assumed size.
class MindMapConnectorPainter extends CustomPainter {
  const MindMapConnectorPainter({
    required this.connectors,
    required this.vertical,
  });

  final List<MindMapConnector> connectors;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    for (final connector in connectors) {
      final paint = Paint()
        ..color = connector.color.withValues(alpha: 0.55)
        ..strokeWidth = _strokeFor(connector.depth)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(_pathFor(connector), paint);
    }
  }

  double _strokeFor(int depth) => switch (depth) {
        0 => 3.0,
        1 => 2.4,
        2 => 1.9,
        _ => 1.5,
      };

  Path _pathFor(MindMapConnector connector) {
    final parent = connector.parent;
    final child = connector.child;
    final path = Path();

    if (vertical) {
      final start = Offset(parent.center.dx, parent.bottom);
      final end = Offset(child.center.dx, child.top);
      final midY = (start.dy + end.dy) / 2;
      path
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
      return path;
    }

    // Anchor to whichever sides actually face each other, so branches that
    // grow leftwards on a both-sides map curve the right way round.
    final growsRight = child.center.dx >= parent.center.dx;
    final start = Offset(growsRight ? parent.right : parent.left, parent.center.dy);
    final end = Offset(growsRight ? child.left : child.right, child.center.dy);
    final midX = (start.dx + end.dx) / 2;
    path
      ..moveTo(start.dx, start.dy)
      ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant MindMapConnectorPainter oldDelegate) =>
      oldDelegate.vertical != vertical ||
      oldDelegate.connectors.length != connectors.length ||
      !_sameConnectors(oldDelegate.connectors, connectors);

  static bool _sameConnectors(List<MindMapConnector> a, List<MindMapConnector> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].parent != b[i].parent || a[i].child != b[i].child || a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }
}

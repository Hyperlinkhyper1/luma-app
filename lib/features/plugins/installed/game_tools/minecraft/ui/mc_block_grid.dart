import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../theme/luma_theme.dart';

/// A top-down (or face-on) block plan: filled cells on a grid, with the
/// centre lines and every eighth line drawn heavier so blocks can be counted
/// the way builders count them in game.
class McBlockGrid extends StatelessWidget {
  const McBlockGrid({
    super.key,
    required this.width,
    required this.height,
    required this.colorAt,
    this.ghostAt,
    this.flipY = false,
    this.maxCell = 22,
    this.minCell = 3,
  });

  final int width;
  final int height;

  /// The colour of the cell at (x, y), or null when empty.
  final Color? Function(int x, int y) colorAt;

  /// A faint colour for context cells, e.g. the layer below.
  final Color? Function(int x, int y)? ghostAt;

  /// Draws y = 0 at the bottom, for face-on views like arches.
  final bool flipY;
  final double maxCell;
  final double minCell;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity;
        // Fit both ways, so a tall plan never spills out of its panel.
        final cell = math
            .min(maxW / math.max(1, width), maxH / math.max(1, height))
            .clamp(minCell, maxCell);
        final w = cell * width, h = cell * height;
        final grid = CustomPaint(
          size: Size(w, h),
          painter: _GridPainter(
            width: width,
            height: height,
            cell: cell,
            colorAt: colorAt,
            ghostAt: ghostAt,
            flipY: flipY,
            line: luma.border,
            strong: luma.textMuted.withValues(alpha: 0.5),
            centre: luma.accent.withValues(alpha: 0.55),
            background: luma.surfaceHover,
          ),
        );
        if (w <= maxW && h <= maxH) return Center(child: grid);
        return InteractiveViewer(
          constrained: false,
          minScale: 0.2,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(80),
          child: grid,
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.width,
    required this.height,
    required this.cell,
    required this.colorAt,
    required this.ghostAt,
    required this.flipY,
    required this.line,
    required this.strong,
    required this.centre,
    required this.background,
  });

  final int width;
  final int height;
  final double cell;
  final Color? Function(int x, int y) colorAt;
  final Color? Function(int x, int y)? ghostAt;
  final bool flipY;
  final Color line;
  final Color strong;
  final Color centre;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final fill = Paint();
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 0; y < height; y++) {
      final py = flipY ? (height - 1 - y) * cell : y * cell;
      for (var x = 0; x < width; x++) {
        final c = colorAt(x, y);
        final rect = Rect.fromLTWH(x * cell, py, cell, cell);
        if (c == null) {
          final g = ghostAt?.call(x, y);
          if (g != null) {
            fill.color = g;
            canvas.drawRect(rect.deflate(cell * 0.18), fill);
          }
          continue;
        }
        fill.color = c;
        canvas.drawRect(rect, fill);
        // A lighter top edge gives each block a little depth.
        if (cell >= 8) {
          fill.color = Colors.white.withValues(alpha: 0.18);
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, cell * 0.16),
            fill,
          );
          canvas.drawRect(rect.deflate(0.5), edge);
        }
      }
    }
    if (cell < 4) return;
    final thin = Paint()
      ..color = line
      ..strokeWidth = 0.6;
    final heavy = Paint()
      ..color = strong
      ..strokeWidth = 1.2;
    for (var x = 0; x <= width; x++) {
      canvas.drawLine(
        Offset(x * cell, 0),
        Offset(x * cell, size.height),
        x % 8 == 0 ? heavy : thin,
      );
    }
    for (var y = 0; y <= height; y++) {
      final py = flipY ? size.height - y * cell : y * cell;
      canvas.drawLine(
        Offset(0, py),
        Offset(size.width, py),
        y % 8 == 0 ? heavy : thin,
      );
    }
    final mid = Paint()
      ..color = centre
      ..strokeWidth = 1.6;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      mid,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      mid,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}

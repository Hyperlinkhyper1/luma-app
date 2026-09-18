import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/whiteboard_element.dart';

/// Draws the paper: a flat surface with an optional dot grid.
///
/// Dots rather than lines because at the zoom levels people actually draw at,
/// a line grid competes with the ink; dots read as texture and disappear.
class WhiteboardBackgroundPainter extends CustomPainter {
  const WhiteboardBackgroundPainter({
    required this.surface,
    required this.dot,
    required this.showGrid,
    this.spacing = 32,
  });

  final Color surface;
  final Color dot;
  final bool showGrid;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = surface);
    if (!showGrid) return;
    final paint = Paint()..color = dot;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WhiteboardBackgroundPainter old) =>
      old.surface != surface ||
      old.dot != dot ||
      old.showGrid != showGrid ||
      old.spacing != spacing;
}

/// Draws the committed elements, plus the selection chrome when one is picked.
class WhiteboardPainter extends CustomPainter {
  const WhiteboardPainter({
    required this.elements,
    required this.selectedId,
    required this.accent,
    required this.textScale,
  });

  final List<WhiteboardElement> elements;
  final int? selectedId;
  final Color accent;

  /// The viewer's scale, so the selection outline and handle stay the same
  /// size on screen however far the board is zoomed.
  final double textScale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in elements) {
      paintWhiteboardElement(canvas, element);
    }
    if (selectedId == null) return;
    final selected =
        elements.where((element) => element.id == selectedId).firstOrNull;
    if (selected == null) return;
    paintSelection(canvas, selected.bounds, accent, textScale);
  }

  @override
  bool shouldRepaint(WhiteboardPainter old) =>
      old.elements != elements ||
      old.selectedId != selectedId ||
      old.accent != accent ||
      old.textScale != textScale;
}

/// Draws the stroke or shape currently under the user's finger.
///
/// It sits in its own layer so that every pointer move repaints one in-flight
/// path instead of the whole board.
class WhiteboardDraftPainter extends CustomPainter {
  WhiteboardDraftPainter({
    required this.draft,
    required this.eraser,
    required this.eraserRadius,
    required this.danger,
  });

  final WhiteboardElement? draft;
  final Offset? eraser;
  final double eraserRadius;
  final Color danger;

  @override
  void paint(Canvas canvas, Size size) {
    final element = draft;
    if (element != null) paintWhiteboardElement(canvas, element);
    final cursor = eraser;
    if (cursor != null) {
      canvas.drawCircle(
        cursor,
        eraserRadius,
        Paint()
          ..color = danger.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(WhiteboardDraftPainter old) =>
      old.draft != draft ||
      old.eraser != eraser ||
      old.eraserRadius != eraserRadius;
}

/// The dashed box and resize handle around the selected element.
void paintSelection(Canvas canvas, Rect bounds, Color accent, double scale) {
  final box = bounds.inflate(6 / scale);
  final stroke = Paint()
    ..color = accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5 / scale;
  _strokeDashedRect(canvas, box, stroke, 6 / scale, 4 / scale);
  final handle = handleRect(bounds, scale);
  canvas.drawRRect(
    RRect.fromRectAndRadius(handle, Radius.circular(3 / scale)),
    Paint()..color = accent,
  );
}

/// The resize grip's box, in board coordinates. Shared with the hit test so
/// the grip you can see is exactly the grip you can grab.
Rect handleRect(Rect bounds, double scale) {
  final side = 12 / scale;
  final box = bounds.inflate(6 / scale);
  return Rect.fromCenter(
    center: box.bottomRight,
    width: side,
    height: side,
  );
}

void _strokeDashedRect(
  Canvas canvas,
  Rect rect,
  Paint paint,
  double dash,
  double gap,
) {
  final corners = [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
    rect.topLeft,
  ];
  for (var i = 0; i < corners.length - 1; i++) {
    final from = corners[i];
    final to = corners[i + 1];
    final length = (to - from).distance;
    if (length == 0) continue;
    final step = (to - from) / length;
    var travelled = 0.0;
    while (travelled < length) {
      final end = math.min(travelled + dash, length);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + gap;
    }
  }
}

/// Paints one element. Used by the board layer, the draft layer and the PNG
/// export, so what is exported is always exactly what was on screen.
void paintWhiteboardElement(Canvas canvas, WhiteboardElement element) {
  final color = Color(element.color);
  switch (element.kind) {
    case WhiteboardKind.pen:
      _paintPath(canvas, element, color, 1);
    case WhiteboardKind.highlighter:
      // A highlighter is ink you can read through: translucent, wide, and
      // square-capped so overlapping passes do not build up dark blobs.
      _paintPath(canvas, element, color, 3.5, alpha: 0.32, square: true);
    case WhiteboardKind.line:
      if (element.points.length < 2) return;
      canvas.drawLine(
        element.points.first,
        element.points.last,
        _strokePaint(color, element.strokeWidth),
      );
    case WhiteboardKind.arrow:
      _paintArrow(canvas, element, color);
    case WhiteboardKind.rect:
      final box = _boxOf(element);
      final radius = Radius.circular(math.min(10, box.shortestSide / 6));
      final rrect = RRect.fromRectAndRadius(box, radius);
      if (element.filled) {
        canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.18));
      }
      canvas.drawRRect(rrect, _strokePaint(color, element.strokeWidth));
    case WhiteboardKind.ellipse:
      final box = _boxOf(element);
      if (element.filled) {
        canvas.drawOval(box, Paint()..color = color.withValues(alpha: 0.18));
      }
      canvas.drawOval(box, _strokePaint(color, element.strokeWidth));
    case WhiteboardKind.note:
      _paintNote(canvas, element, color);
    case WhiteboardKind.text:
      _paintText(canvas, element, color);
  }
}

Paint _strokePaint(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Rect _boxOf(WhiteboardElement element) {
  if (element.points.length < 2) return Rect.zero;
  return Rect.fromPoints(element.points.first, element.points.last);
}

void _paintPath(
  Canvas canvas,
  WhiteboardElement element,
  Color color,
  double widthFactor, {
  double alpha = 1,
  bool square = false,
}) {
  final points = element.points;
  if (points.isEmpty) return;
  final paint = Paint()
    ..color = alpha == 1 ? color : color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = element.strokeWidth * widthFactor
    ..strokeCap = square ? StrokeCap.square : StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (points.length == 1) {
    // A tap with the pen is a dot, not nothing.
    canvas.drawCircle(
      points.first,
      element.strokeWidth * widthFactor / 2,
      Paint()..color = paint.color,
    );
    return;
  }
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  // Quadratics through the midpoints: the raw pointer samples are polyline
  // corners, and at any real zoom level those corners are visible as facets.
  for (var i = 1; i < points.length - 1; i++) {
    final midpoint = (points[i] + points[i + 1]) / 2;
    path.quadraticBezierTo(
      points[i].dx,
      points[i].dy,
      midpoint.dx,
      midpoint.dy,
    );
  }
  path.lineTo(points.last.dx, points.last.dy);
  canvas.drawPath(path, paint);
}

void _paintArrow(Canvas canvas, WhiteboardElement element, Color color) {
  if (element.points.length < 2) return;
  final from = element.points.first;
  final to = element.points.last;
  final paint = _strokePaint(color, element.strokeWidth);
  canvas.drawLine(from, to, paint);
  final length = (to - from).distance;
  if (length < 1) return;
  final head = math.max(10.0, element.strokeWidth * 4);
  final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
  const spread = math.pi / 7;
  final path = Path()
    ..moveTo(to.dx, to.dy)
    ..lineTo(
      to.dx - head * math.cos(angle - spread),
      to.dy - head * math.sin(angle - spread),
    )
    ..lineTo(
      to.dx - head * math.cos(angle + spread),
      to.dy - head * math.sin(angle + spread),
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _paintNote(Canvas canvas, WhiteboardElement element, Color color) {
  final box = element.bounds;
  final rrect = RRect.fromRectAndRadius(box, const Radius.circular(6));
  canvas.drawRRect(
    rrect.shift(const Offset(0, 2)),
    Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  canvas.drawRRect(rrect, Paint()..color = color);
  if (element.text.isEmpty) return;
  _drawParagraph(
    canvas,
    text: element.text,
    color: noteTextColor(color),
    fontSize: 14,
    maxWidth: box.width - 20,
    origin: box.topLeft + const Offset(10, 10),
    maxHeight: box.height - 20,
  );
}

void _paintText(Canvas canvas, WhiteboardElement element, Color color) {
  if (element.text.isEmpty) return;
  _drawParagraph(
    canvas,
    text: element.text,
    color: color,
    fontSize: math.max(8, element.size.height),
    maxWidth: math.max(40, element.size.width),
    origin: element.points.isEmpty ? Offset.zero : element.points.first,
  );
}

void _drawParagraph(
  Canvas canvas, {
  required String text,
  required Color color,
  required double fontSize,
  required double maxWidth,
  required Offset origin,
  double? maxHeight,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        height: 1.35,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(8, maxWidth));
  if (maxHeight != null && painter.height > maxHeight) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(origin.dx, origin.dy, maxWidth, maxHeight));
    painter.paint(canvas, origin);
    canvas.restore();
  } else {
    painter.paint(canvas, origin);
  }
  painter.dispose();
}

/// Ink that stays readable on a sticky note of any colour.
Color noteTextColor(Color background) =>
    background.computeLuminance() > 0.5
        ? const Color(0xFF1B1726)
        : const Color(0xFFF5F3FB);

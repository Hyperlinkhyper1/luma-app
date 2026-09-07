import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../creature/creature_model.dart';

/// The square you draw a creature on.
///
/// Points are kept normalised to 0..1 so the same drawing survives a resize,
/// and so the skeleton — which was extracted in that same space — can be
/// painted straight back over the sketch.
class DrawingBoard extends StatelessWidget {
  const DrawingBoard({
    super.key,
    required this.strokes,
    required this.draft,
    required this.shape,
    required this.onStart,
    required this.onExtend,
    required this.onFinish,
  });

  final List<List<Offset>> strokes;
  final List<Offset>? draft;
  final CreatureShape? shape;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onExtend;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final empty = strokes.isEmpty && draft == null;
    return Semantics(
      label: 'Drawing board. Draw a creature with one or more strokes.',
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            Offset normalise(Offset local) => Offset(
                  (local.dx / constraints.maxWidth).clamp(0.0, 1.0),
                  (local.dy / constraints.maxHeight).clamp(0.0, 1.0),
                );
            return MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => onStart(normalise(d.localPosition)),
                onPanUpdate: (d) => onExtend(normalise(d.localPosition)),
                onPanEnd: (_) => onFinish(),
                onPanCancel: onFinish,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: luma.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: luma.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: _BoardPainter(
                            strokes: strokes,
                            draft: draft,
                            shape: shape,
                            luma: luma,
                          ),
                        ),
                        if (empty)
                          IgnorePointer(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.gesture_rounded,
                                    size: 30,
                                    color: luma.textMuted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Draw a body here',
                                    style: TextStyle(
                                      color: luma.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'or start from an example below',
                                    style: TextStyle(
                                      color: luma.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.strokes,
    required this.draft,
    required this.shape,
    required this.luma,
  });

  final List<List<Offset>> strokes;
  final List<Offset>? draft;
  final CreatureShape? shape;
  final LumaPalette luma;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintStrokes(canvas, size);
    final shape = this.shape;
    if (shape != null) _paintSkeleton(canvas, size, shape);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = luma.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const divisions = 8;
    for (var i = 1; i < divisions; i++) {
      final x = size.width * i / divisions;
      final y = size.height * i / divisions;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintStrokes(Canvas canvas, Size size) {
    final hasSkeleton = shape != null;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hasSkeleton ? 1.5 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = hasSkeleton
          ? luma.textSecondary.withValues(alpha: 0.5)
          : luma.accent;
    for (final stroke in [...strokes, ?draft]) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(
            Offset(stroke.first.dx * size.width, stroke.first.dy * size.height),
            paint.strokeWidth,
            Paint()..color = paint.color,
          );
        }
        continue;
      }
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintSkeleton(Canvas canvas, Size size, CreatureShape shape) {
    Offset toCanvas(int node) {
      final drawing = shape.toDrawing(shape.nodeX[node], shape.nodeY[node]);
      return Offset(drawing.dx * size.width, drawing.dy * size.height);
    }

    final bone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = luma.accent.withValues(alpha: 0.9);
    for (var b = 0; b < shape.boneCount; b++) {
      final width =
          (shape.boneThickness[b] / shape.drawingScale * size.width).clamp(2.0, 26.0);
      bone.strokeWidth = width;
      canvas.drawLine(toCanvas(shape.boneA[b]), toCanvas(shape.boneB[b]), bone);
    }

    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = luma.onAccent.withValues(alpha: 0.65);
    for (var b = 0; b < shape.boneCount; b++) {
      canvas.drawLine(toCanvas(shape.boneA[b]), toCanvas(shape.boneB[b]), core);
    }

    final jointFill = Paint()..color = luma.success;
    final jointRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = luma.background;
    for (var j = 0; j < shape.jointCount; j++) {
      final centre = toCanvas(shape.jointPivot[j]);
      canvas.drawCircle(centre, 4, jointFill);
      canvas.drawCircle(centre, 4, jointRing);
    }

    final head = toCanvas(shape.headNode);
    canvas.drawCircle(
      head,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = luma.warning,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.strokes != strokes ||
      old.draft != draft ||
      old.shape != shape ||
      old.luma != luma;
}

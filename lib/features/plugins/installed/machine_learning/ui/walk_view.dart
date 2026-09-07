import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../creature/creature_model.dart';
import '../creature/creature_physics.dart';
import '../creature/creature_skin.dart';

/// The course: a creature walking left to right, with the ground marked out
/// in metres and the goal line waiting at the far end.
class WalkView extends StatelessWidget {
  const WalkView({
    super.key,
    required this.shape,
    required this.sim,
    required this.skin,
    required this.repaint,
    required this.showSkin,
  });

  final CreatureShape shape;
  final CreatureSim sim;
  final CreatureSkin skin;

  /// Bumped once per frame by the lab's ticker so only the canvas repaints.
  final Listenable repaint;

  final bool showSkin;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: luma.border),
        ),
        child: CustomPaint(
          painter: _WalkPainter(
            shape: shape,
            sim: sim,
            skin: skin,
            luma: luma,
            showSkin: showSkin,
            repaint: repaint,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WalkPainter extends CustomPainter {
  _WalkPainter({
    required this.shape,
    required this.sim,
    required this.skin,
    required this.luma,
    required this.showSkin,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CreatureShape shape;
  final CreatureSim sim;
  final CreatureSkin skin;
  final LumaPalette luma;
  final bool showSkin;

  /// How much of the world fits vertically. A creature is scaled to about a
  /// metre, so this keeps it around a third of the frame with room to jump.
  static const _viewHeightMetres = 3.4;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _viewHeightMetres;
    final groundY = size.height * 0.78;
    final camera = sim.centreOfMassX;
    final anchorX = size.width * 0.38;

    double screenX(double world) => (world - camera) * scale + anchorX;
    double screenY(double world) => groundY - world * scale;

    _paintGround(canvas, size, groundY);
    _paintRuler(canvas, size, scale, groundY, camera, anchorX, screenX);
    _paintCreature(canvas, screenX, screenY, scale);
  }

  void _paintGround(Canvas canvas, Size size, double groundY) {
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, size.width, size.height),
      Paint()..color = luma.surfaceHover.withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = luma.border
        ..strokeWidth = 1.5,
    );
  }

  void _paintRuler(
    Canvas canvas,
    Size size,
    double scale,
    double groundY,
    double camera,
    double anchorX,
    double Function(double) screenX,
  ) {
    final leftMetre = camera - anchorX / scale;
    final rightMetre = leftMetre + size.width / scale;
    final labelEvery = scale > 26 ? 1 : (scale > 9 ? 5 : 10);

    final tick = Paint()
      ..color = luma.border
      ..strokeWidth = 1;
    final label = TextPainter(textDirection: TextDirection.ltr);

    for (var metre = leftMetre.floor(); metre <= rightMetre.ceil(); metre++) {
      final x = screenX(metre.toDouble());
      final major = metre % labelEvery == 0;
      canvas.drawLine(
        Offset(x, groundY),
        Offset(x, groundY + (major ? 9 : 4)),
        tick,
      );
      if (!major) continue;
      label
        ..text = TextSpan(
          text: '$metre m',
          style: TextStyle(color: luma.textMuted, fontSize: 10),
        )
        ..layout();
      label.paint(canvas, Offset(x - label.width / 2, groundY + 12));
    }

    _paintMarker(canvas, screenX(0), groundY, luma.textMuted, 'start');
    _paintMarker(
      canvas,
      screenX(sim.config.goalMetres),
      groundY,
      luma.accent,
      '${sim.config.goalMetres.round()} m',
      tall: true,
    );
  }

  void _paintMarker(
    Canvas canvas,
    double x,
    double groundY,
    Color color,
    String text, {
    bool tall = false,
  }) {
    final top = groundY - (tall ? 110 : 44);
    final paint = Paint()
      ..color = color.withValues(alpha: tall ? 0.9 : 0.45)
      ..strokeWidth = tall ? 2 : 1.2;
    var y = top;
    while (y < groundY) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 6, groundY)), paint);
      y += 11;
    }
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: tall ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    )..layout();
    label.paint(canvas, Offset(x + 5, top));
  }

  void _paintCreature(
    Canvas canvas,
    double Function(double) screenX,
    double Function(double) screenY,
    double scale,
  ) {
    if (showSkin) {
      final skinPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = luma.textSecondary.withValues(alpha: 0.55);
      for (final stroke in skin.pose(shape, sim)) {
        if (stroke.length < 2) continue;
        final path = Path()
          ..moveTo(screenX(stroke.first.dx), screenY(stroke.first.dy));
        for (final p in stroke.skip(1)) {
          path.lineTo(screenX(p.dx), screenY(p.dy));
        }
        canvas.drawPath(path, skinPaint);
      }
    }

    final bone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = luma.accent;
    for (var b = 0; b < shape.boneCount; b++) {
      final a = shape.boneA[b];
      final c = shape.boneB[b];
      bone.strokeWidth = (shape.boneThickness[b] * scale).clamp(4.0, 40.0);
      canvas.drawLine(
        Offset(screenX(sim.x[a]), screenY(sim.y[a])),
        Offset(screenX(sim.x[c]), screenY(sim.y[c])),
        bone,
      );
    }

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = luma.onAccent.withValues(alpha: 0.45);
    for (var b = 0; b < shape.boneCount; b++) {
      canvas.drawLine(
        Offset(screenX(sim.x[shape.boneA[b]]), screenY(sim.y[shape.boneA[b]])),
        Offset(screenX(sim.x[shape.boneB[b]]), screenY(sim.y[shape.boneB[b]])),
        highlight,
      );
    }

    final joint = Paint()..color = luma.success;
    for (var j = 0; j < shape.jointCount; j++) {
      final n = shape.jointPivot[j];
      canvas.drawCircle(
        Offset(screenX(sim.x[n]), screenY(sim.y[n])),
        3.2,
        joint,
      );
    }

    final head = shape.headNode;
    final eye = Offset(screenX(sim.x[head]), screenY(sim.y[head]));
    canvas.drawCircle(eye, 4.5, Paint()..color = luma.onAccent);
    canvas.drawCircle(eye, 2.1, Paint()..color = luma.textPrimary);
  }

  @override
  bool shouldRepaint(_WalkPainter old) =>
      old.sim != sim ||
      old.shape != shape ||
      old.showSkin != showSkin ||
      old.luma != luma;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import 'status_pill.dart';

/// The big circular score gauge anchoring the dashboard — Device Health's
/// answer to Norton's headline dial, painted in luma's own palette rather
/// than Norton's yellow/black.
class HealthScoreDial extends StatelessWidget {
  const HealthScoreDial({super.key, required this.score, this.size = 168});

  final HealthScore score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = statusColor(context, score.status);
    final known = score.checkedCategories > 0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialPainter(
          progress: known ? score.score / 100 : 0,
          trackColor: luma.border,
          progressColor: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                known ? '${score.score}' : '—',
                style: TextStyle(
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.w800,
                  color: luma.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                known ? statusLabel(score.status) : 'Not checked',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: luma.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 14) / 2;
    final stroke = 12.0;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final fg = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../model/brush.dart';
import 'brush_textures.dart';
import 'stroke_engine.dart';

/// Draws dabs onto a canvas.
///
/// The round tip is drawn as a vector oval — crisp at 1 px and at 500 px —
/// with a blur mask filter for soft edges. Textured tips are bitmaps tinted
/// with a `srcIn` colour filter, so one white tip serves every colour.
class DabRenderer {
  const DabRenderer(this.textures);

  final BrushTextures textures;

  void paintAll(Canvas canvas, Iterable<Dab> dabs, BrushPreset brush) {
    for (final dab in dabs) {
      paint(canvas, dab, brush);
    }
  }

  void paint(Canvas canvas, Dab dab, BrushPreset brush) {
    final color = dab.color.withValues(alpha: dab.color.a * dab.alpha);
    if (color.a <= 0) return;
    final paint = Paint()..color = color;
    _shape(canvas, dab, brush, paint);
  }

  /// Draws the dab's footprint with [paint]'s blend mode and alpha — used to
  /// mask smudge and blur deposits to the tip's shape.
  void mask(Canvas canvas, Dab dab, BrushPreset brush, double alpha, BlendMode mode) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
      ..blendMode = mode;
    _shape(canvas, dab, brush, paint);
  }

  void _shape(Canvas canvas, Dab dab, BrushPreset brush, Paint paint) {
    final tipImage = brush.tip == BrushTip.round ? null : textures.tip(brush.tip);
    if (tipImage == null) {
      _round(canvas, dab, brush, paint);
    } else {
      _textured(canvas, dab, brush, paint, tipImage);
    }
  }

  void _round(Canvas canvas, Dab dab, BrushPreset brush, Paint paint) {
    final radius = dab.size / 2;
    var r = radius;
    final hardness = brush.tip == BrushTip.round ? brush.hardness : 0.85;
    if (hardness < 0.98) {
      final sigma = math.max(0.3, (1 - hardness) * radius * 0.35);
      r = math.max(0.3, radius - sigma * 1.5);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }
    final roundness = brush.roundness.clamp(0.05, 1.0);
    if (roundness >= 0.99) {
      canvas.drawCircle(dab.center, r, paint);
      return;
    }
    canvas.save();
    canvas.translate(dab.center.dx, dab.center.dy);
    canvas.rotate(dab.angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: math.max(0.6, r * 2 * roundness)),
      paint,
    );
    canvas.restore();
  }

  void _textured(Canvas canvas, Dab dab, BrushPreset brush, Paint paint, ui.Image tip) {
    // The alpha rides in the filter colour rather than the paint, so it is
    // applied the same way whichever backend is drawing the image.
    final tint = paint.color;
    paint
      ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn)
      ..color = const Color(0xFF000000)
      ..filterQuality = dab.size < tip.width * 0.5 ? FilterQuality.medium : FilterQuality.low;
    final roundness = brush.roundness.clamp(0.05, 1.0);
    canvas.save();
    canvas.translate(dab.center.dx, dab.center.dy);
    canvas.rotate(dab.angle);
    canvas.scale(dab.size / tip.width, dab.size * roundness / tip.height);
    canvas.drawImage(tip, Offset(-tip.width / 2, -tip.height / 2), paint);
    canvas.restore();
  }
}

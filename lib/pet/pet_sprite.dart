import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pet_repository.dart';

/// The pet itself: a small luna-moth-pale moonlet with a tilted ring, painted
/// rather than shipped as an asset so it tints itself with whatever accent
/// the user picked and stays crisp at any size.
///
/// It bobs while idle, blinks on its own, looks towards whatever is being
/// typed, and squashes when patted. Every one of those stops when the system
/// asks for reduced motion — the face still changes with [mood], so nothing
/// is only conveyed by movement.
class PetSprite extends StatefulWidget {
  const PetSprite({
    super.key,
    required this.mood,
    required this.patCount,
    this.size = 84,
    this.lookAt = Offset.zero,
    this.animate = true,
  });

  final PetMood mood;

  /// Bumping this plays the pat reaction. It is the running total from
  /// [PetRepository.pats], so any increment reads as "it was just patted".
  final int patCount;

  final double size;

  /// Where the eyes point, in -1..1 on each axis.
  final Offset lookAt;

  /// Whether the pet moves on its own — the idle bob and the blink. Off for
  /// the small still portrait in Settings, where a permanently running
  /// animation would cost more than it adds. Pats still react either way.
  final bool animate;

  @override
  State<PetSprite> createState() => _PetSpriteState();
}

class _PetSpriteState extends State<PetSprite>
    with TickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  late final AnimationController _pat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  final math.Random _random = math.Random();
  bool _reduceMotion = false;
  Timer? _blinkTimer;

  /// Nothing self-driven runs: either the system asked for reduced motion or
  /// this is a still portrait.
  bool get _still => _reduceMotion || !widget.animate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(PetSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) _syncMotion();
    if (widget.patCount != oldWidget.patCount && !_reduceMotion) {
      _pat.forward(from: 0);
    }
  }

  void _syncMotion() {
    if (_still) {
      // Everything that moves stops, including the blink: the mood still
      // shows in the face, so nothing is lost but the motion.
      _ambient.stop();
      _ambient.value = 0;
      _blinkTimer?.cancel();
      _blink.value = 0;
      return;
    }
    if (!_ambient.isAnimating) _ambient.repeat();
    if (_blinkTimer?.isActive != true) _scheduleBlink();
  }

  // Blinks land at an irregular rhythm; a fixed interval reads mechanical.
  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 2200 + _random.nextInt(4200)),
      () async {
        if (!mounted) return;
        if (!_still && widget.mood != PetMood.sleepy) {
          await _blink.forward();
          if (!mounted) return;
          await _blink.reverse();
        }
        if (mounted && !_still) _scheduleBlink();
      },
    );
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _ambient.dispose();
    _blink.dispose();
    _pat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _blink, _pat]),
        builder: (context, _) {
          // One arc up and back down per cycle, so the pet breathes rather
          // than jumping when the controller wraps.
          final bob = math.sin(_ambient.value * 2 * math.pi);
          // 0 -> 1 -> 0 with an overshoot at the top: squash on contact,
          // stretch on the way back.
          final pat = math.sin(_pat.value * math.pi);
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _PetPainter(
              mood: widget.mood,
              bob: bob,
              blink: Curves.easeOut.transform(_blink.value),
              pat: pat,
              lookAt: widget.lookAt,
              accent: scheme.primary,
              glow: scheme.primary.withValues(alpha: 0.20),
              ink: scheme.surface,
            ),
          );
        },
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  _PetPainter({
    required this.mood,
    required this.bob,
    required this.blink,
    required this.pat,
    required this.lookAt,
    required this.accent,
    required this.glow,
    required this.ink,
  });

  final PetMood mood;
  final double bob;
  final double blink;
  final double pat;
  final Offset lookAt;
  final Color accent;
  final Color glow;

  /// Used for the eyes and mouth: the surface colour reads as a hole in the
  /// body in both themes, where a flat black would only work in one.
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final centre = Offset(w / 2, w / 2 + bob * w * 0.035 - pat * w * 0.03);
    final radius = w * 0.31;

    // Squash on the way down, stretch on the way back up.
    final squashX = 1 + pat * 0.10;
    final squashY = 1 - pat * 0.10;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(squashX, squashY);
    canvas.translate(-centre.dx, -centre.dy);

    _paintGlow(canvas, centre, radius);
    _paintRing(canvas, centre, radius);
    _paintBody(canvas, centre, radius);
    _paintFace(canvas, centre, radius);
    if (mood == PetMood.delighted) _paintSparkles(canvas, centre, radius);

    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Offset centre, double radius) {
    final rect = Rect.fromCircle(center: centre, radius: radius * 2.1);
    canvas.drawCircle(
      centre,
      radius * 2.1,
      Paint()
        ..shader = RadialGradient(
          colors: [glow, glow.withValues(alpha: 0)],
          stops: const [0.35, 1],
        ).createShader(rect),
    );
  }

  // A tilted ring behind the body, borrowed from the lunar/orbit motif the
  // rest of the app leans on (see the splash screen).
  void _paintRing(Canvas canvas, Offset centre, double radius) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy + radius * 0.35);
    canvas.rotate(-0.34);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.1,
        height: radius * 0.92,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.11
        ..color = accent.withValues(alpha: 0.45),
    );
    canvas.restore();
  }

  void _paintBody(Canvas canvas, Offset centre, double radius) {
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, 0.42)!,
            accent,
          ],
        ).createShader(rect),
    );

    // Craters, so the body reads as a little moon rather than a ball.
    final crater = Paint()..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawCircle(
      centre + Offset(-radius * 0.52, -radius * 0.30),
      radius * 0.17,
      crater,
    );
    canvas.drawCircle(
      centre + Offset(radius * 0.50, radius * 0.40),
      radius * 0.12,
      crater,
    );
    canvas.drawCircle(
      centre + Offset(radius * 0.18, -radius * 0.62),
      radius * 0.09,
      crater,
    );
  }

  void _paintFace(Canvas canvas, Offset centre, double radius) {
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.11
      ..strokeCap = StrokeCap.round;

    final look = Offset(
      lookAt.dx.clamp(-1.0, 1.0) * radius * 0.09,
      lookAt.dy.clamp(-1.0, 1.0) * radius * 0.07,
    );
    final eyeY = centre.dy - radius * 0.10 + look.dy;
    final eyeDx = radius * 0.34;
    final left = Offset(centre.dx - eyeDx + look.dx, eyeY);
    final right = Offset(centre.dx + eyeDx + look.dx, eyeY);

    switch (mood) {
      case PetMood.happy:
      case PetMood.delighted:
        // Upturned arcs: the eyes smile too.
        for (final eye in [left, right]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: eye + Offset(0, radius * 0.06),
              width: radius * 0.40,
              height: radius * 0.34,
            ),
            math.pi,
            math.pi,
            false,
            stroke,
          );
        }
      case PetMood.sleepy:
        for (final eye in [left, right]) {
          canvas.drawLine(
            eye - Offset(radius * 0.18, 0),
            eye + Offset(radius * 0.18, 0),
            stroke,
          );
        }
      case PetMood.idle:
      case PetMood.curious:
        final openness = (1 - blink).clamp(0.08, 1.0);
        for (final eye in [left, right]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: eye,
              width: radius * 0.22,
              height: radius * 0.30 * openness,
            ),
            paint,
          );
        }
    }

    // Mouth.
    final mouthCentre = Offset(centre.dx + look.dx * 0.5, centre.dy + radius * 0.33);
    switch (mood) {
      case PetMood.delighted:
        final mouth = Rect.fromCenter(
          center: mouthCentre,
          width: radius * 0.46,
          height: radius * 0.42,
        );
        canvas.drawArc(mouth, 0, math.pi, true, paint);
      case PetMood.sleepy:
        canvas.drawCircle(mouthCentre, radius * 0.08, paint);
      case PetMood.idle:
      case PetMood.happy:
      case PetMood.curious:
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCentre,
            width: radius * 0.38,
            height: radius * 0.30,
          ),
          0.15,
          math.pi - 0.30,
          false,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = radius * 0.09,
        );
    }

    if (mood == PetMood.happy || mood == PetMood.delighted) {
      final blush = Paint()..color = Colors.white.withValues(alpha: 0.30);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centre.dx - radius * 0.60, centre.dy + radius * 0.18),
          width: radius * 0.30,
          height: radius * 0.18,
        ),
        blush,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centre.dx + radius * 0.60, centre.dy + radius * 0.18),
          width: radius * 0.30,
          height: radius * 0.18,
        ),
        blush,
      );
    }
  }

  void _paintSparkles(Canvas canvas, Offset centre, double radius) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07
      ..strokeCap = StrokeCap.round;
    const angles = [-2.5, -0.65, 3.6];
    for (var i = 0; i < angles.length; i++) {
      final distance = radius * (1.55 + 0.12 * i);
      final at = centre +
          Offset(math.cos(angles[i]) * distance, math.sin(angles[i]) * distance);
      final arm = radius * (0.16 + 0.04 * i);
      canvas.drawLine(at - Offset(arm, 0), at + Offset(arm, 0), paint);
      canvas.drawLine(at - Offset(0, arm), at + Offset(0, arm), paint);
    }
  }

  @override
  bool shouldRepaint(_PetPainter old) =>
      old.mood != mood ||
      old.bob != bob ||
      old.blink != blink ||
      old.pat != pat ||
      old.lookAt != lookAt ||
      old.accent != accent ||
      old.ink != ink;
}

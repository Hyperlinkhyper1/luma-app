import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An IntelliJ-style startup splash with a luma (lunar) theme: a deep night-sky
/// window with a star field, a glowing crescent moon, and the wordmark.
///
/// The artwork stays still while [bootstrap] runs, then briefly fades out.
/// There is no artificial minimum loading time or continuous rendering loop.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.bootstrap,
    required this.onDone,
    this.accent = const Color(0xFFB49DF5),
    this.version = 'Dev build',
    this.edition = 'Free edition',
  });

  /// Real startup work the splash is covering. The splash will not dismiss
  /// until this completes (errors are ignored — startup must never hang here).
  final Future<void> bootstrap;

  /// Called once the splash has fully faded out.
  final VoidCallback onDone;

  /// Brand accent used to tint the moonlight and wordmark.
  final Color accent;

  /// Shown small in the bottom corner, IntelliJ-style.
  final String version;

  /// Edition label shown in the bottom-left corner (e.g. "Free edition",
  /// "Orbit edition"). Driven by the active plan — see [_BootGate].
  final String edition;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: 1,
  );

  late final List<_Star> _stars = _buildStars(110);

  @override
  void initState() {
    super.initState();

    unawaited(_finishAfterBootstrap());
  }

  Future<void> _finishAfterBootstrap() async {
    try {
      await widget.bootstrap;
    } catch (_) {
      // Storage errors must still release the app.
    }
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) await _fade.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: RepaintBoundary(
        child: Material(
          color: const Color(0xFF0B0A14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final moonSize =
                  math.min(w, h) * 0.2 + 36; // gentle clamp for any window size
              final statusWidth = math.min(440.0, w * 0.62);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Night-sky wash with a soft lavender aurora bleeding from the
                  // top-right behind the moon.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.55, -0.65),
                        radius: 1.3,
                        colors: [
                          Color.lerp(
                            widget.accent,
                            const Color(0xFF0B0A14),
                            0.6,
                          )!,
                          const Color(0xFF120F1F),
                          const Color(0xFF09080F),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  CustomPaint(painter: _StarFieldPainter(stars: _stars)),

                  // Moon + wordmark, centered.
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: Size.square(moonSize),
                          painter: _MoonPainter(accent: widget.accent),
                        ),
                        const SizedBox(height: 28),
                        ShaderMask(
                          shaderCallback: (rect) => LinearGradient(
                            colors: [
                              Colors.white,
                              Color.lerp(Colors.white, widget.accent, 0.7)!,
                            ],
                          ).createShader(rect),
                          child: const Text(
                            'luma',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The utility app',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: (w - statusWidth) / 2,
                    right: (w - statusWidth) / 2,
                    bottom: math.max(48, h * 0.12),
                    child: Text(
                      'Starting luma',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Edition + version, tucked in the corners like IntelliJ.
                  Positioned(
                    left: 20,
                    bottom: 16,
                    child: Text(
                      widget.edition,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 16,
                    child: Text(
                      widget.version,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A single star in the field. Positions are normalized (0..1) so the field
/// scales to any window size.
class _Star {
  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.baseOpacity,
    required this.phase,
    required this.sparkle,
  });

  final double dx;
  final double dy;
  final double radius;
  final double baseOpacity;
  final double phase;

  /// A handful of larger 4-point "sparkle" stars for visual interest.
  final bool sparkle;
}

List<_Star> _buildStars(int count) {
  final rng = math.Random(31); // fixed seed -> stable layout across rebuilds
  return List.generate(count, (i) {
    final sparkle = i % 18 == 0;
    return _Star(
      dx: rng.nextDouble(),
      dy: rng.nextDouble(),
      radius: sparkle
          ? 1.6 + rng.nextDouble() * 1.4
          : 0.5 + rng.nextDouble() * 1.3,
      baseOpacity: 0.3 + rng.nextDouble() * 0.6,
      phase: rng.nextDouble() * 2 * math.pi,
      sparkle: sparkle,
    );
  });
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({required this.stars});

  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final star in stars) {
      final twinkle = 0.5 + 0.5 * math.sin(star.phase);
      final opacity = (star.baseOpacity * (0.45 + 0.55 * twinkle)).clamp(
        0.0,
        1.0,
      );
      final center = Offset(star.dx * size.width, star.dy * size.height);
      paint.color = Colors.white.withValues(alpha: opacity);

      if (star.sparkle) {
        _drawSparkle(canvas, center, star.radius * 2.6, paint);
      } else {
        canvas.drawCircle(center, star.radius, paint);
      }
    }
  }

  // A soft four-point sparkle drawn as two crossing tapered diamonds.
  void _drawSparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarFieldPainter oldDelegate) =>
      oldDelegate.stars != stars;
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 * 0.74;

    // Outer glow halo.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(accent, Colors.white, 0.4)!.withValues(alpha: 0.35),
          accent.withValues(alpha: 0.12),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 2.1));
    canvas.drawCircle(center, r * 2.1, glow);

    // Crescent: a full disc minus an offset disc.
    final disc = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(r * 0.52, -r * 0.16),
          radius: r * 1.02,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, disc, cut);

    final moonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color.lerp(accent, Colors.white, 0.55)!,
          const Color(0xFFFDFBFF),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(crescent, moonPaint);

    // A faint inner rim of light along the crescent's outer edge.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.save();
    canvas.clipPath(crescent);
    canvas.drawCircle(center, r, rim);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => oldDelegate.accent != accent;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An IntelliJ-style startup splash with a luma (lunar) theme: a deep night-sky
/// window with a twinkling star field, a glowing crescent moon, the wordmark,
/// and a slim progress bar with staged status text along the bottom.
///
/// It animates a determinate progress bar while the real [bootstrap] work runs
/// behind it, then fades itself out and calls [onDone] once both the animation
/// and the bootstrap future have finished — so the app is warm by the time the
/// splash lifts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.bootstrap,
    required this.onDone,
    this.accent = const Color(0xFFB49DF5),
    this.version = 'Dev build',
  });

  /// Real startup work the splash is covering. The splash will not dismiss
  /// until this completes (errors are ignored — startup must never hang here).
  final Future<void> bootstrap;

  /// Called once the splash has fully faded out.
  final VoidCallback onDone;

  /// Brand accent used to tint the moonlight and progress fill.
  final Color accent;

  /// Shown small in the bottom corner, IntelliJ-style.
  final String version;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Drives the determinate progress bar from 0 -> 1 over a fixed window. This
  // sets the minimum time the splash stays up: it only dismisses once the bar
  // has filled AND the real work is done, so the screen is actually seen.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  // Slow, looping clock that powers the star twinkle + moon drift.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Fade-out of the whole splash once everything is ready.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  late final List<_Star> _stars = _buildStars(110);
  bool _bootstrapDone = false;

  // Staged status lines, mapped to progress thresholds (IntelliJ shows the
  // current loading step beside the bar).
  static const _stages = <_Stage>[
    _Stage(0.00, 'Charting the night sky'),
    _Stage(0.28, 'Polishing the moonlight'),
    _Stage(0.55, 'Catching up your budgets'),
    _Stage(0.82, 'Almost there'),
  ];

  @override
  void initState() {
    super.initState();

    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) _ambient.stop();

    widget.bootstrap.whenComplete(() {
      if (mounted) setState(() => _bootstrapDone = true);
      _tryFinish();
    });

    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) _tryFinish();
    });
    _progress.addListener(() => setState(() {}));
    _progress.forward();
  }

  // Dismiss only once the bar has filled AND the real work is done.
  Future<void> _tryFinish() async {
    if (!_bootstrapDone || !_progress.isCompleted) return;
    if (_fade.status != AnimationStatus.completed) return; // already running
    await _fade.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _progress.dispose();
    _ambient.dispose();
    _fade.dispose();
    super.dispose();
  }

  String get _status {
    var line = _stages.first.label;
    for (final s in _stages) {
      if (_progress.value >= s.at) line = s.label;
    }
    return line;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: const Color(0xFF0B0A14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final moonSize =
                math.min(w, h) * 0.2 + 36; // gentle clamp for any window size
            final barWidth = math.min(440.0, w * 0.62);

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
                        Color.lerp(widget.accent, const Color(0xFF0B0A14), 0.6)!,
                        const Color(0xFF120F1F),
                        const Color(0xFF09080F),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),

                // Twinkling stars.
                AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => CustomPaint(
                    painter: _StarFieldPainter(
                      stars: _stars,
                      t: _ambient.value,
                    ),
                  ),
                ),

                // Moon + wordmark, centered.
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _ambient,
                        builder: (context, _) {
                          // Subtle vertical drift so the moon feels alive.
                          final drift =
                              math.sin(_ambient.value * 2 * math.pi) * 4;
                          return Transform.translate(
                            offset: Offset(0, drift),
                            child: CustomPaint(
                              size: Size.square(moonSize),
                              painter: _MoonPainter(accent: widget.accent),
                            ),
                          );
                        },
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

                // Bottom loading dock: status line, slim progress bar, version.
                Positioned(
                  left: (w - barWidth) / 2,
                  right: (w - barWidth) / 2,
                  bottom: math.max(48, h * 0.12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _status,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(_progress.value * 100).round()}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ProgressBar(
                        value: _progress.value,
                        accent: widget.accent,
                      ),
                    ],
                  ),
                ),

                // Edition + version, tucked in the corners like IntelliJ.
                Positioned(
                  left: 20,
                  bottom: 16,
                  child: Text(
                    'Free edition',
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
    );
  }
}

/// The thin IntelliJ-style track + glowing accent fill.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.accent});
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 4, color: Colors.white.withValues(alpha: 0.1)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(accent, Colors.white, 0.3)!,
                    accent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.7),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
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
  _StarFieldPainter({required this.stars, required this.t});

  final List<_Star> stars;
  final double t; // 0..1 ambient clock

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final star in stars) {
      // Twinkle: oscillate opacity around the star's base level.
      final twinkle = 0.5 + 0.5 * math.sin(t * 2 * math.pi + star.phase);
      final opacity = (star.baseOpacity * (0.45 + 0.55 * twinkle)).clamp(0.0, 1.0);
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
  bool shouldRepaint(_StarFieldPainter oldDelegate) => oldDelegate.t != t;
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
      ..addOval(Rect.fromCircle(
        center: center + Offset(r * 0.52, -r * 0.16),
        radius: r * 1.02,
      ));
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

class _Stage {
  const _Stage(this.at, this.label);
  final double at;
  final String label;
}

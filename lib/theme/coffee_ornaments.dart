import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'luma_theme.dart';

/// Draws one coffee bean centered on [center]: an ellipse [radius] wide with
/// the S-shaped crease down its long axis, rotated by [angle] radians.
///
/// Shared by the drifting backdrop and the [CoffeeBeanIcon] so the marketing
/// swatch and the wallpaper are literally the same shape.
void paintCoffeeBean(
  Canvas canvas,
  Offset center,
  double radius,
  double angle,
  Color fill,
  Color crease,
) {
  final rx = radius;
  final ry = radius * 0.68;

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);

  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
    Paint()..color = fill,
  );

  // The crease: a flattened S from end to end, which is what separates a
  // coffee bean from a plain lozenge.
  final a = rx * 0.84;
  final path = Path()
    ..moveTo(-a, 0)
    ..cubicTo(-a * 0.45, -ry * 0.52, a * 0.45, ry * 0.52, a, 0);
  canvas.drawPath(
    path,
    Paint()
      ..color = crease
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, radius * 0.13)
      ..strokeCap = StrokeCap.round,
  );

  canvas.restore();
}

/// A single coffee bean as a widget — used for the Coffee entry in the
/// Settings style picker. Vector-drawn rather than an emoji so it themes,
/// scales and stays identical across platforms.
class CoffeeBeanIcon extends StatelessWidget {
  const CoffeeBeanIcon({
    super.key,
    required this.color,
    this.size = 24,
    this.angle = -0.5,
  });

  final Color color;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BeanIconPainter(color: color, angle: angle),
      ),
    );
  }
}

class _BeanIconPainter extends CustomPainter {
  const _BeanIconPainter({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    paintCoffeeBean(
      canvas,
      size.center(Offset.zero),
      size.width * 0.46,
      angle,
      color,
      // The crease reads as a gap in the bean, so it takes the surface behind
      // it rather than a darker shade of the bean.
      Color.lerp(color, const Color(0xFF1D140D), 0.55)!,
    );
  }

  @override
  bool shouldRepaint(_BeanIconPainter old) =>
      old.color != color || old.angle != angle;
}

/// Wraps the app's content in whatever backdrop the active style asks for.
///
/// For every style but Coffee this is a straight pass-through — the widget
/// costs one [InheritedWidget] read and returns [child] untouched, so the
/// default theme pays nothing for the feature existing.
class StyleBackdrop extends StatelessWidget {
  const StyleBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decor = context.lumaDecor;
    if (decor.ornament != LumaOrnament.coffeeBeans) return child;
    return _CoffeeBackdrop(child: child);
  }
}

/// Warm gradient pools with coffee beans drifting slowly across them.
///
/// The beans sit at 4-9% opacity so body text over them still clears its
/// contrast target — this is wallpaper, not content.
class _CoffeeBackdrop extends StatefulWidget {
  const _CoffeeBackdrop({required this.child});

  final Widget child;

  @override
  State<_CoffeeBackdrop> createState() => _CoffeeBackdropState();
}

class _CoffeeBackdropState extends State<_CoffeeBackdrop>
    with SingleTickerProviderStateMixin {
  /// One full drift takes two minutes, which is slow enough to read as
  /// atmosphere rather than motion.
  static const _cycle = Duration(seconds: 120);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _cycle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs before the first build, so this is also where the drift starts.
    // Reduced motion: hold the beans on a fixed frame instead of drifting.
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Two warm pools, as if light were falling past a cup on either
        // diagonal. Very low alpha: this must not fight the cards on top.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.85, -0.9),
                radius: 1.25,
                colors: [
                  luma.accent.withValues(alpha: isDark ? 0.10 : 0.09),
                  luma.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.95, 1.0),
                radius: 1.1,
                colors: [
                  luma.accent.withValues(alpha: isDark ? 0.08 : 0.07),
                  luma.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _BeanFieldPainter(
                    progress: _controller.value,
                    bean: luma.accent.withValues(alpha: isDark ? 0.09 : 0.07),
                    crease: luma.background,
                    steam: luma.accent.withValues(alpha: isDark ? 0.05 : 0.04),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

/// One bean's fixed properties. Positions are fractions of the paint size so
/// the field reflows with the window instead of clustering in a corner.
class _Bean {
  const _Bean(this.x, this.y, this.radius, this.angle, this.speed);

  final double x;
  final double y;
  final double radius;
  final double angle;

  /// Vertical drift per cycle, again as a fraction of height.
  final double speed;
}

/// A hand-placed scatter. Fixed rather than random so the layout is stable
/// across rebuilds and identical on every device.
const _beans = <_Bean>[
  _Bean(0.06, 0.12, 15, -0.55, 0.9),
  _Bean(0.17, 0.68, 11, 0.90, 1.3),
  _Bean(0.25, 0.31, 19, -1.15, 0.7),
  _Bean(0.33, 0.88, 13, 0.35, 1.1),
  _Bean(0.41, 0.06, 10, 1.35, 1.5),
  _Bean(0.48, 0.52, 22, -0.25, 0.6),
  _Bean(0.56, 0.79, 12, 1.05, 1.2),
  _Bean(0.63, 0.22, 16, -0.85, 0.85),
  _Bean(0.71, 0.61, 14, 0.55, 1.0),
  _Bean(0.78, 0.09, 20, -1.45, 0.75),
  _Bean(0.85, 0.44, 11, 0.15, 1.4),
  _Bean(0.92, 0.83, 17, -0.65, 0.8),
  _Bean(0.11, 0.44, 13, 1.25, 1.15),
  _Bean(0.36, 0.63, 9, -0.35, 1.6),
  _Bean(0.59, 0.36, 10, 0.75, 1.45),
  _Bean(0.88, 0.19, 12, -1.05, 1.05),
  _Bean(0.03, 0.75, 18, 0.45, 0.65),
  _Bean(0.68, 0.94, 15, -0.95, 0.95),
];

class _BeanFieldPainter extends CustomPainter {
  const _BeanFieldPainter({
    required this.progress,
    required this.bean,
    required this.crease,
    required this.steam,
  });

  /// 0 → 1 over one drift cycle.
  final double progress;
  final Color bean;
  final Color crease;
  final Color steam;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSteam(canvas, size);

    for (final b in _beans) {
      // Wrap around the top edge as each bean falls off the bottom, so the
      // field never empties out and the cycle seams invisibly.
      final drift = (b.y + progress * b.speed) % 1.0;
      // Scale beans with the window's short side: the same field would look
      // like gravel on a desktop and boulders on a phone.
      final scale = (size.shortestSide / 700).clamp(0.55, 1.35);
      paintCoffeeBean(
        canvas,
        Offset(b.x * size.width, drift * size.height),
        b.radius * scale,
        b.angle + progress * 0.6,
        bean,
        crease,
      );
    }
  }

  /// Three steam ribbons curling up from the bottom edge, drifting sideways
  /// on the same clock as the beans.
  void _paintSteam(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = steam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const origins = [0.22, 0.55, 0.82];
    for (var i = 0; i < origins.length; i++) {
      final x = origins[i] * size.width;
      final phase = progress * 2 * math.pi + i * 2.1;
      final sway = math.sin(phase) * size.width * 0.02;
      final height = size.height * 0.42;
      final bottom = size.height;

      final path = Path()..moveTo(x, bottom);
      // Two stacked S-bends: the classic rising-steam curl.
      path.cubicTo(
        x + 26 + sway, bottom - height * 0.28,
        x - 26 - sway, bottom - height * 0.52,
        x + sway, bottom - height * 0.78,
      );
      path.cubicTo(
        x + 20 - sway, bottom - height * 0.90,
        x - 14 + sway, bottom - height * 1.02,
        x - sway * 0.5, bottom - height * 1.15,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BeanFieldPainter old) =>
      old.progress != progress ||
      old.bean != bean ||
      old.crease != crease ||
      old.steam != steam;
}

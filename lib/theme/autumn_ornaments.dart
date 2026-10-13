import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'luma_theme.dart';

/// The harvest colors the leaves fall in, straight from the Autumn palette
/// cards: rust, harvest gold, brick and olive.
const kAutumnLeafColors = <Color>[
  Color(0xFFC84C22),
  Color(0xFFE8A939),
  Color(0xFFA44916),
  Color(0xFF8A6A1F),
];

/// Half of a maple leaf's outline, from the top lobe's tip clockwise down to
/// the stem, in a unit box (y grows downward). Mirrored for the left half.
const _mapleHalf = <Offset>[
  Offset(0.00, -1.00),
  Offset(0.13, -0.68),
  Offset(0.34, -0.80),
  Offset(0.28, -0.44),
  Offset(0.62, -0.60),
  Offset(0.55, -0.38),
  Offset(0.96, -0.30),
  Offset(0.78, -0.12),
  Offset(0.88, 0.02),
  Offset(0.50, 0.12),
  Offset(0.56, 0.34),
  Offset(0.18, 0.24),
  Offset(0.05, 0.44),
];

Path _maplePath(double r) {
  final path = Path()..moveTo(_mapleHalf.first.dx * r, _mapleHalf.first.dy * r);
  for (final p in _mapleHalf.skip(1)) {
    path.lineTo(p.dx * r, p.dy * r);
  }
  for (final p in _mapleHalf.reversed) {
    path.lineTo(-p.dx * r, p.dy * r);
  }
  return path..close();
}

/// Draws a maple leaf centered on [center], [radius] from middle to tip,
/// rotated by [angle]. [flip] squashes it horizontally (−1…1) so a falling
/// leaf can seem to turn over as it tumbles.
///
/// Shared by the backdrop and [MapleLeafIcon], so the Settings swatch and
/// the wallpaper are the same leaf.
void paintMapleLeaf(
  Canvas canvas,
  Offset center,
  double radius,
  double angle,
  Color fill,
  Color vein, {
  double flip = 1,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  canvas.scale(flip, 1);

  canvas.drawPath(_maplePath(radius), Paint()..color = fill);

  final veins = Paint()
    ..color = vein
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, radius * 0.07)
    ..strokeCap = StrokeCap.round;
  final base = Offset(0, radius * 0.40);
  // The stem, then one vein out to each of the three main lobes.
  canvas.drawLine(Offset(0, radius * 0.95), base, veins);
  canvas.drawLine(base, Offset(0, -radius * 0.72), veins);
  canvas.drawLine(base, Offset(radius * 0.70, -radius * 0.26), veins);
  canvas.drawLine(base, Offset(-radius * 0.70, -radius * 0.26), veins);
  canvas.restore();
}

/// A birch leaf: a pointed oval with a midrib — the plainer leaf in the
/// mix, so the fall doesn't read as one stamp repeated.
void paintBirchLeaf(
  Canvas canvas,
  Offset center,
  double radius,
  double angle,
  Color fill,
  Color vein, {
  double flip = 1,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  canvas.scale(flip, 1);

  final w = radius * 0.58;
  final path = Path()
    ..moveTo(0, -radius)
    ..quadraticBezierTo(w * 1.5, -radius * 0.15, 0, radius * 0.72)
    ..quadraticBezierTo(-w * 1.5, -radius * 0.15, 0, -radius)
    ..close();
  canvas.drawPath(path, Paint()..color = fill);
  canvas.drawLine(
    Offset(0, radius),
    Offset(0, -radius * 0.78),
    Paint()
      ..color = vein
      ..strokeWidth = math.max(0.8, radius * 0.07)
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();
}

/// A single maple leaf as a widget — the Autumn entry in the Settings style
/// picker. Vector-drawn so it themes and scales like the coffee bean does.
class MapleLeafIcon extends StatelessWidget {
  const MapleLeafIcon({
    super.key,
    required this.color,
    this.size = 24,
    this.angle = -0.35,
  });

  final Color color;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LeafIconPainter(color: color, angle: angle),
      ),
    );
  }
}

class _LeafIconPainter extends CustomPainter {
  const _LeafIconPainter({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    paintMapleLeaf(
      canvas,
      size.center(Offset.zero),
      size.width * 0.44,
      angle,
      color,
      Color.lerp(color, const Color(0xFF2D0E09), 0.55)!,
    );
  }

  @override
  bool shouldRepaint(_LeafIconPainter old) =>
      old.color != color || old.angle != angle;
}

/// Rust and gold light pooling in two corners, a faint Tetris-board grid,
/// two big still leaves tucked into the corners and a slow fall of leaves
/// across everything.
///
/// The leaves sit at 12–24% opacity and the grid at ~1%, so text over them
/// still clears its contrast target — this is wallpaper, not content.
class AutumnBackdrop extends StatefulWidget {
  const AutumnBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<AutumnBackdrop> createState() => _AutumnBackdropState();
}

class _AutumnBackdropState extends State<AutumnBackdrop>
    with SingleTickerProviderStateMixin {
  /// One full fall takes ninety seconds: slow enough to read as weather,
  /// not as something asking to be looked at.
  static const _cycle = Duration(seconds: 90);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _cycle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the leaves hang where they are instead of falling.
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
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, -0.95),
                radius: 1.2,
                colors: [
                  kAutumnLeafColors[0].withValues(alpha: isDark ? 0.12 : 0.07),
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
                center: const Alignment(1.0, 1.0),
                radius: 1.1,
                colors: [
                  kAutumnLeafColors[1].withValues(alpha: isDark ? 0.09 : 0.08),
                  luma.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _StillLifePainter(
                  grid: luma.border.withValues(alpha: isDark ? 0.10 : 0.09),
                  leafAlpha: isDark ? 0.12 : 0.12,
                  vein: luma.background,
                ),
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
                  painter: _LeafFallPainter(
                    progress: _controller.value,
                    alpha: isDark ? 0.24 : 0.22,
                    vein: luma.background,
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

/// The parts of the backdrop that never move, on their own layer so the
/// falling leaves don't repaint them every frame.
class _StillLifePainter extends CustomPainter {
  const _StillLifePainter({
    required this.grid,
    required this.leafAlpha,
    required this.vein,
  });

  final Color grid;
  final double leafAlpha;
  final Color vein;

  @override
  void paint(Canvas canvas, Size size) {
    // A board grid like the falling-block game the palette came from.
    const cell = 28.0;
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var x = cell; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Two big leaves tucked into opposite corners, half off the edge.
    final scale = (size.shortestSide / 700).clamp(0.6, 1.4);
    paintMapleLeaf(
      canvas,
      Offset(size.width + 10 * scale, -14 * scale),
      120 * scale,
      2.6,
      kAutumnLeafColors[0].withValues(alpha: leafAlpha),
      vein.withValues(alpha: leafAlpha),
    );
    paintMapleLeaf(
      canvas,
      Offset(-18 * scale, size.height + 6 * scale),
      104 * scale,
      0.5,
      kAutumnLeafColors[1].withValues(alpha: leafAlpha),
      vein.withValues(alpha: leafAlpha),
    );
  }

  @override
  bool shouldRepaint(_StillLifePainter old) =>
      old.grid != grid || old.leafAlpha != leafAlpha || old.vein != vein;
}

/// One leaf's fixed properties. Positions are fractions of the paint size so
/// the fall reflows with the window instead of clustering in a corner.
class _Leaf {
  const _Leaf(
    this.x,
    this.y,
    this.radius,
    this.speed,
    this.sway,
    this.spin,
    this.color,
    this.maple,
  );

  final double x;
  final double y;
  final double radius;

  /// Screen heights fallen per cycle. A whole number, like [spin], so the
  /// loop seams invisibly when the controller wraps back to 0.
  final double speed;

  /// Side-to-side drift, as a fraction of width.
  final double sway;

  /// Whole turns per cycle; the sign is the direction.
  final double spin;

  /// Index into [kAutumnLeafColors].
  final int color;
  final bool maple;
}

/// A hand-placed scatter, fixed rather than random so the layout is stable
/// across rebuilds and identical on every device.
const _leaves = <_Leaf>[
  _Leaf(0.05, 0.10, 16, 1, 0.020, 1, 0, true),
  _Leaf(0.14, 0.62, 11, 2, 0.030, -2, 1, false),
  _Leaf(0.22, 0.30, 19, 1, 0.025, 1, 2, true),
  _Leaf(0.31, 0.85, 12, 2, 0.035, -1, 3, false),
  _Leaf(0.39, 0.05, 14, 3, 0.020, 2, 1, true),
  _Leaf(0.46, 0.50, 21, 1, 0.030, -1, 0, true),
  _Leaf(0.54, 0.76, 10, 2, 0.040, 2, 1, false),
  _Leaf(0.61, 0.20, 17, 1, 0.025, -1, 2, true),
  _Leaf(0.69, 0.58, 13, 2, 0.030, 1, 3, false),
  _Leaf(0.77, 0.08, 20, 1, 0.020, -1, 0, true),
  _Leaf(0.84, 0.42, 11, 3, 0.035, 2, 1, false),
  _Leaf(0.92, 0.80, 18, 1, 0.025, -1, 2, true),
  _Leaf(0.10, 0.40, 12, 2, 0.030, 1, 1, false),
  _Leaf(0.35, 0.60, 9, 3, 0.040, -2, 0, true),
  _Leaf(0.58, 0.35, 10, 2, 0.030, 1, 3, false),
  _Leaf(0.88, 0.16, 13, 1, 0.025, -1, 0, true),
  _Leaf(0.02, 0.72, 17, 1, 0.020, 1, 2, true),
  _Leaf(0.71, 0.93, 14, 1, 0.030, -1, 1, true),
];

class _LeafFallPainter extends CustomPainter {
  const _LeafFallPainter({
    required this.progress,
    required this.alpha,
    required this.vein,
  });

  /// 0 → 1 over one fall cycle.
  final double progress;
  final double alpha;
  final Color vein;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale leaves with the window's short side: the same scatter would look
    // like confetti on a desktop and like a pile on a phone.
    final scale = (size.shortestSide / 700).clamp(0.55, 1.35);
    final veinColor = vein.withValues(alpha: alpha);
    for (var i = 0; i < _leaves.length; i++) {
      final l = _leaves[i];
      // The fall runs from just above the top edge to just below the bottom,
      // so a leaf is out of sight at the moment it wraps around.
      final fall = (l.y + progress * l.speed) % 1.0;
      final y = -0.08 + fall * 1.16;
      // Every periodic term turns a whole number of times per cycle, so the
      // frame at progress 1 is exactly the frame at progress 0.
      final turn = progress * 2 * math.pi;
      final sway = math.sin(turn * (3 + i % 4) + i * 1.7);
      final x = l.x + sway * l.sway;
      final center = Offset(x * size.width, y * size.height);
      final angle = sway * 0.6 + turn * l.spin;
      // cos of the tumble: the leaf narrows to an edge and widens again.
      final flip = math.cos(turn * (2 + i % 3) + i);
      final fill = kAutumnLeafColors[l.color].withValues(alpha: alpha);
      final r = l.radius * scale * 1.3;
      if (l.maple) {
        paintMapleLeaf(canvas, center, r, angle, fill, veinColor, flip: flip);
      } else {
        paintBirchLeaf(canvas, center, r, angle, fill, veinColor, flip: flip);
      }
    }
  }

  @override
  bool shouldRepaint(_LeafFallPainter old) =>
      old.progress != progress || old.alpha != alpha || old.vein != vein;
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../logic/pta/pta_chemistry.dart';
import '../../logic/pta/pta_lab.dart';

const _plainWater = Color(0x2E8EC5F0);
const _plainHexane = Color(0x22FFF3C4);

/// Everything the painter needs to draw one tube, so a change can be
/// animated by blending two of these.
class TubeVisual {
  const TubeVisual({
    this.water = 0,
    this.hexane = 0,
    this.waterColor = _plainWater,
    this.hexaneColor = _plainHexane,
    this.solid = 0,
    this.solidColor = Colors.white,
    this.turbidity = 0,
    this.turbidColor = Colors.white,
    this.heap = 0,
    this.heapColor = Colors.white,
    this.metal,
    this.deposit,
  });

  final double water;
  final double hexane;
  final Color waterColor;
  final Color hexaneColor;
  final double solid;
  final Color solidColor;
  final double turbidity;
  final Color turbidColor;
  final double heap;
  final Color heapColor;
  final Color? metal;
  final Color? deposit;

  static TubeVisual of(Tube t) {
    final look = lookOf(t);
    var settled = 0.0;
    var r = 0.0, g = 0.0, b = 0.0;
    for (final e in t.pp.entries) {
      if (!settlesAtBottom(e.key) || e.value < 0.002) continue;
      settled += e.value;
      r += e.key.color.r * e.value;
      g += e.key.color.g * e.value;
      b += e.key.color.b * e.value;
    }
    final sulfur = t.ppAmt(Pp.sulfur);
    Color? metal;
    for (final m in Metal.values) {
      if ((t.metals[m] ?? 0) > 0.05) metal = Color(m.argb);
    }
    Color? deposit;
    var best = 0.0;
    for (final e in t.deposits.entries) {
      if (e.value > best && e.value > 0.005) {
        best = e.value;
        deposit = Color(e.key.argb);
      }
    }
    return TubeVisual(
      water: (t.waterMl / kMaxMl).clamp(0.0, 1.0),
      hexane: (t.hexaneMl / kMaxMl).clamp(0.0, 1.0),
      waterColor: look.water ?? _plainWater,
      hexaneColor: look.organic ?? _plainHexane,
      solid: settled <= 0 ? 0 : math.min(0.16, 0.015 + settled * 0.14),
      solidColor: settled <= 0
          ? Colors.white
          : Color.from(
              alpha: 1,
              red: r / settled,
              green: g / settled,
              blue: b / settled,
            ),
      turbidity: math.min(1, sulfur * 12),
      turbidColor: Pp.sulfur.color,
      heap: t.solid == null ? 0 : math.min(0.08, 0.03 + t.solidMmol * 0.04),
      heapColor: t.solid?.solidColor ?? Colors.white,
      metal: metal,
      deposit: deposit,
    );
  }

  static TubeVisual lerp(TubeVisual a, TubeVisual b, double t) {
    double d(double x, double y) => x + (y - x) * t;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return TubeVisual(
      water: d(a.water, b.water),
      hexane: d(a.hexane, b.hexane),
      waterColor: c(a.waterColor, b.waterColor),
      hexaneColor: c(a.hexaneColor, b.hexaneColor),
      solid: d(a.solid, b.solid),
      solidColor: a.solid <= 0 ? b.solidColor : c(a.solidColor, b.solidColor),
      turbidity: d(a.turbidity, b.turbidity),
      turbidColor: b.turbidColor,
      heap: d(a.heap, b.heap),
      heapColor: b.heap > 0 ? b.heapColor : a.heapColor,
      metal: t < 0.5 ? a.metal ?? b.metal : b.metal,
      deposit: t < 0.5 ? a.deposit : b.deposit,
    );
  }
}

/// One test tube in the rack. [version] goes up after every action on
/// the tube; that is when the contents blend to their new look and the
/// bubbles or burner play.
class PtaTubeView extends StatefulWidget {
  const PtaTubeView({
    super.key,
    required this.tube,
    required this.version,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.glass,
    required this.accent,
    required this.labelStyle,
  });

  final Tube tube;
  final int version;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Color glass;
  final Color accent;
  final TextStyle? labelStyle;

  @override
  State<PtaTubeView> createState() => _PtaTubeViewState();
}

class _PtaTubeViewState extends State<PtaTubeView>
    with TickerProviderStateMixin {
  late TubeVisual _from;
  late TubeVisual _to;
  late final AnimationController _morph;
  late final AnimationController _bubbles;
  late final AnimationController _burner;
  Timer? _stopBubbles;

  @override
  void initState() {
    super.initState();
    _from = _to = TubeVisual.of(widget.tube);
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    );
    _bubbles = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _burner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didUpdateWidget(PtaTubeView old) {
    super.didUpdateWidget(old);
    if (old.version == widget.version) return;
    _from = TubeVisual.lerp(_from, _to, _morph.value);
    _to = TubeVisual.of(widget.tube);
    _morph.forward(from: 0);
    if (widget.tube.heating) _burner.forward(from: 0);
    _stopBubbles?.cancel();
    if (widget.tube.bubbling) {
      _bubbles.repeat();
      _stopBubbles = Timer(const Duration(seconds: 5), () {
        if (mounted) _bubbles.stop();
      });
    } else {
      _bubbles.stop();
      _bubbles.value = 0;
    }
  }

  @override
  void dispose() {
    _stopBubbles?.cancel();
    _morph.dispose();
    _bubbles.dispose();
    _burner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? widget.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.selected
                    ? widget.accent
                    : widget.glass.withValues(alpha: 0.0),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 54,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_morph, _bubbles, _burner]),
                    builder: (context, _) => CustomPaint(
                      painter: _TubePainter(
                        visual: TubeVisual.lerp(
                          _from,
                          _to,
                          Curves.easeOut.transform(_morph.value),
                        ),
                        bubbles: _bubbles.isAnimating ? _bubbles.value : null,
                        burner: _burner.isAnimating ? _burner.value : null,
                        glass: widget.glass,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(widget.label, style: widget.labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TubePainter extends CustomPainter {
  _TubePainter({
    required this.visual,
    required this.bubbles,
    required this.burner,
    required this.glass,
  });

  final TubeVisual visual;
  final double? bubbles;
  final double? burner;
  final Color glass;

  static const _burnerSpace = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.62;
    final left = (size.width - w) / 2;
    final top = 6.0;
    final bottom = size.height - _burnerSpace;
    final body = RRect.fromLTRBAndCorners(
      left,
      top,
      left + w,
      bottom,
      bottomLeft: Radius.circular(w / 2),
      bottomRight: Radius.circular(w / 2),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
    );
    final inner = body.deflate(2.2);
    final h = inner.height;

    canvas.save();
    canvas.clipRRect(inner);
    final waterTop = inner.bottom - visual.water * h;
    if (visual.water > 0) {
      canvas.drawRect(
        Rect.fromLTRB(inner.left, waterTop, inner.right, inner.bottom),
        Paint()..color = visual.waterColor,
      );
    }
    if (visual.hexane > 0) {
      final hexTop = waterTop - visual.hexane * h;
      canvas.drawRect(
        Rect.fromLTRB(inner.left, hexTop, inner.right, waterTop),
        Paint()..color = visual.hexaneColor,
      );
      canvas.drawLine(
        Offset(inner.left, waterTop),
        Offset(inner.right, waterTop),
        Paint()
          ..color = glass.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
    if (visual.turbidity > 0.02 && visual.water > 0) {
      final rnd = math.Random(7);
      final p = Paint()
        ..color = visual.turbidColor.withValues(
          alpha: 0.35 + 0.4 * visual.turbidity,
        );
      final n = (60 * visual.turbidity).round() + 8;
      for (var i = 0; i < n; i++) {
        final x = inner.left + rnd.nextDouble() * inner.width;
        final y = waterTop + rnd.nextDouble() * (inner.bottom - waterTop);
        canvas.drawCircle(Offset(x, y), 0.9 + rnd.nextDouble() * 0.9, p);
      }
    }
    if (visual.solid > 0.001) {
      final sTop = inner.bottom - visual.solid * h;
      final rnd = math.Random(3);
      final path = Path()..moveTo(inner.left, sTop + 2);
      for (var x = 0.0; x <= inner.width; x += 4) {
        path.lineTo(inner.left + x, sTop + rnd.nextDouble() * 3);
      }
      path
        ..lineTo(inner.right, inner.bottom)
        ..lineTo(inner.left, inner.bottom)
        ..close();
      canvas.drawPath(path, Paint()..color = visual.solidColor);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    if (visual.heap > 0.001) {
      final hh = visual.heap * h;
      final heap = Path()
        ..moveTo(inner.left + 3, inner.bottom)
        ..quadraticBezierTo(
          inner.center.dx,
          inner.bottom - hh * 2.2,
          inner.right - 3,
          inner.bottom,
        )
        ..close();
      canvas.drawPath(heap, Paint()..color = visual.heapColor);
      canvas.drawPath(
        heap,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    if (visual.metal != null) {
      final m = Rect.fromCenter(
        center: Offset(inner.center.dx, inner.bottom - 12),
        width: inner.width * 0.5,
        height: 7,
      );
      canvas.save();
      canvas.translate(m.center.dx, m.center.dy);
      canvas.rotate(-0.35);
      canvas.translate(-m.center.dx, -m.center.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(m, const Radius.circular(2)),
        Paint()..color = visual.metal!,
      );
      if (visual.deposit != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(m.deflate(1.2), const Radius.circular(2)),
          Paint()..color = visual.deposit!.withValues(alpha: 0.85),
        );
      }
      canvas.restore();
    }
    final phase = bubbles;
    if (phase != null && visual.water > 0) {
      final rnd = math.Random(11);
      final p = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var i = 0; i < 14; i++) {
        final x = inner.left + 3 + rnd.nextDouble() * (inner.width - 6);
        final offset = rnd.nextDouble();
        final speed = 0.6 + rnd.nextDouble() * 0.8;
        final f = ((phase * speed) + offset) % 1.0;
        final y = inner.bottom - 4 - f * (inner.bottom - 4 - waterTop);
        canvas.drawCircle(
          Offset(x + math.sin((f + offset) * 12) * 1.5, y),
          1.2 + rnd.nextDouble() * 1.6,
          p,
        );
      }
    }
    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..color = glass.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(left + 5, top + 10),
      Offset(left + 5, bottom - w * 0.6),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(left - 3, top - 2, left + w + 3, top + 3,
          const Radius.circular(2)),
      Paint()..color = glass.withValues(alpha: 0.9),
    );

    final heat = burner;
    if (heat != null) {
      final fade = heat < 0.15
          ? heat / 0.15
          : heat > 0.85
              ? (1 - heat) / 0.15
              : 1.0;
      final cx = size.width / 2;
      final base = size.height - 2;
      final flicker = math.sin(heat * 60) * 2;
      final outer = Path()
        ..moveTo(cx - 8, base)
        ..quadraticBezierTo(cx - 9, base - 14, cx, base - 26 - flicker)
        ..quadraticBezierTo(cx + 9, base - 14, cx + 8, base)
        ..close();
      canvas.drawPath(
        outer,
        Paint()..color = const Color(0xFF4F8DFF).withValues(alpha: 0.75 * fade),
      );
      final core = Path()
        ..moveTo(cx - 4, base)
        ..quadraticBezierTo(cx - 4, base - 8, cx, base - 15 - flicker / 2)
        ..quadraticBezierTo(cx + 4, base - 8, cx + 4, base)
        ..close();
      canvas.drawPath(
        core,
        Paint()..color = const Color(0xFFBFE3FF).withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_TubePainter old) => true;
}

/// The jar with substance X.
class PtaJar extends StatelessWidget {
  const PtaJar({super.key, required this.color, required this.glass});
  final Color color;
  final Color glass;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(84, 96),
        painter: _JarPainter(color, glass),
      );
}

class _JarPainter extends CustomPainter {
  _JarPainter(this.color, this.glass);
  final Color color;
  final Color glass;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromLTRBR(
      6,
      20,
      size.width - 6,
      size.height - 2,
      const Radius.circular(12),
    );
    final rnd = math.Random(5);
    canvas.save();
    canvas.clipRRect(body.deflate(2));
    final fillTop = size.height - 36;
    final grains = Path()..moveTo(6, fillTop + 6);
    for (var x = 6.0; x <= size.width - 6; x += 6) {
      grains.lineTo(x, fillTop + rnd.nextDouble() * 6);
    }
    grains
      ..lineTo(size.width - 6, size.height)
      ..lineTo(6, size.height)
      ..close();
    canvas.drawPath(grains, Paint()..color = color);
    final dot = Paint()..color = Colors.black.withValues(alpha: 0.07);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(10 + rnd.nextDouble() * (size.width - 20),
            fillTop + 8 + rnd.nextDouble() * 24),
        0.9,
        dot,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..color = glass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(10, 8, size.width - 10, 22, const Radius.circular(4)),
      Paint()..color = glass.withValues(alpha: 0.85),
    );
    final label = RRect.fromLTRBR(
      18,
      34,
      size.width - 18,
      54,
      const Radius.circular(4),
    );
    canvas.drawRRect(label, Paint()..color = Colors.white.withValues(alpha: 0.9));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'X',
        style: TextStyle(
          color: Color(0xFF2B2440),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(label.center.dx - tp.width / 2, label.center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_JarPainter old) =>
      old.color != color || old.glass != glass;
}

/// A burner flame in the colour of the last flame test.
class PtaFlame extends StatefulWidget {
  const PtaFlame({super.key, required this.color, required this.version});
  final Color? color;
  final int version;

  @override
  State<PtaFlame> createState() => _PtaFlameState();
}

class _PtaFlameState extends State<PtaFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didUpdateWidget(PtaFlame old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: const Size(40, 72),
          painter: _FlamePainter(
            widget.color,
            _c.isAnimating ? _c.value : null,
          ),
        ),
      );
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.color, this.t);
  final Color? color;
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height - 22;
    final metal = Paint()..color = const Color(0xFF8C8C96);
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 14, size.height - 5, cx + 14, size.height,
          const Radius.circular(2)),
      metal,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 4, base, cx + 4, size.height - 4,
          const Radius.circular(1.5)),
      metal,
    );
    canvas.drawRect(
      Rect.fromLTRB(cx - 4, size.height - 13, cx + 4, size.height - 10),
      Paint()..color = const Color(0xFF5E5E68),
    );
    final v = t;
    if (v == null) return;
    final fade = v < 0.1 ? v / 0.1 : (v > 0.85 ? (1 - v) / 0.15 : 1.0);
    final flicker = math.sin(v * 70) * 2.5;
    final blue = Path()
      ..moveTo(cx - 7, base)
      ..quadraticBezierTo(cx - 9, base - 18, cx, base - 34 - flicker)
      ..quadraticBezierTo(cx + 9, base - 18, cx + 7, base)
      ..close();
    final tint = color ?? const Color(0xFF4F8DFF);
    canvas.drawPath(
      blue,
      Paint()..color = tint.withValues(alpha: 0.85 * fade),
    );
    final core = Path()
      ..moveTo(cx - 3, base)
      ..quadraticBezierTo(cx - 3, base - 8, cx, base - 14)
      ..quadraticBezierTo(cx + 3, base - 8, cx + 3, base)
      ..close();
    canvas.drawPath(
      core,
      Paint()..color = const Color(0xFFBFE3FF).withValues(alpha: 0.9 * fade),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) => true;
}

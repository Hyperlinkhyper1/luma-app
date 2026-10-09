import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_dyes.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

enum _Shape {
  smallBall('small_ball', null),
  largeBall('large_ball', 'fire_charge'),
  star('star', 'gold_nugget'),
  creeper('creeper', 'creeper_head'),
  burst('burst', 'feather');

  const _Shape(this.id, this.item);
  final String id;

  String label(L t) => switch (this) {
    smallBall => t.mcFwSmallBall,
    largeBall => t.mcFwLargeBall,
    star => t.mcFwStar,
    creeper => t.mcFwCreeper,
    burst => t.mcFwBurst,
  };

  /// The ingredient that gives the star this shape.
  final String? item;
}

class _Star {
  _Star({List<McDye>? colors, List<McDye>? fades, this.trail = false})
    : colors = colors ?? [McDye.red],
      fades = fades ?? [];

  _Shape shape = _Shape.largeBall;
  final List<McDye> colors;
  final List<McDye> fades;
  bool trail;
  bool twinkle = false;

  String get component {
    String ints(List<McDye> d) => '[I;${d.map((c) => c.fireworkRgb).join(',')}]';
    return [
      'shape:"${shape.id}"',
      'colors:${ints(colors)}',
      if (fades.isNotEmpty) 'fade_colors:${ints(fades)}',
      if (trail) 'has_trail:true',
      if (twinkle) 'has_twinkle:true',
    ].join(',');
  }
}

/// Builds a firework rocket star by star, with a live burst, the crafting
/// steps and a `/give` command.
class FireworkTool extends StatefulWidget {
  const FireworkTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<FireworkTool> createState() => _FireworkToolState();
}

class _FireworkToolState extends State<FireworkTool>
    with SingleTickerProviderStateMixin {
  int _flight = 2;
  final List<_Star> _stars = [
    _Star(colors: [McDye.lightBlue, McDye.white], fades: [McDye.purple], trail: true),
  ];
  int _selected = 0;
  int _count = 1;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  _Star get _star => _stars[_selected];

  String get _command {
    final explosions = _stars.map((s) => '{${s.component}}').join(',');
    return '/give @p firework_rocket[fireworks={flight_duration:$_flight'
        '${_stars.isEmpty ? '' : ',explosions:[$explosions]'}}] $_count';
  }

  void _toggleDye(List<McDye> list, McDye d) {
    setState(() {
      if (list.contains(d)) {
        list.remove(d);
      } else if (list.length < 8) {
        list.add(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 400,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcFwRocket,
              icon: Icons.rocket_launch_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.mcFwFlight,
                          style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      McChoice<int>(
                        values: const [1, 2, 3],
                        selected: _flight,
                        label: (v) => '$v',
                        onSelect: (v) => setState(() => _flight = v),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.mcFwCount,
                          style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      McStepper(
                        value: _count,
                        min: 1,
                        max: 64,
                        onChanged: (v) => setState(() => _count = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcFwStars,
              icon: Icons.auto_awesome_rounded,
              trailing: TextButton.icon(
                onPressed: _stars.length >= 7
                    ? null
                    : () => setState(() {
                        _stars.add(_Star(colors: [McDye.values[math.Random().nextInt(16)]]));
                        _selected = _stars.length - 1;
                      }),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(t.mcFwAddStar),
              ),
              child: _stars.isEmpty
                  ? Text(
                      t.mcFwNoStars,
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _stars.length; i++)
                          InputChip(
                            label: Text('${i + 1}. ${_stars[i].shape.label(t)}'),
                            selected: i == _selected,
                            avatar: CircleAvatar(
                              backgroundColor: _stars[i].colors.isEmpty
                                  ? luma.border
                                  : _stars[i].colors.first.fireworkColor,
                              radius: 7,
                            ),
                            onPressed: () => setState(() => _selected = i),
                            onDeleted: () => setState(() {
                              _stars.removeAt(i);
                              _selected = _selected.clamp(0, math.max(0, _stars.length - 1));
                            }),
                          ),
                      ],
                    ),
            ),
            if (_stars.isNotEmpty)
              McPanel(
                title: t.mcFwStarN(_selected + 1),
                icon: Icons.star_rounded,
                child: McFormColumn(
                  gap: 12,
                  children: [
                    McField(
                      label: t.mcFwShape,
                      child: McChoice<_Shape>(
                        values: _Shape.values,
                        selected: _star.shape,
                        label: (s) => s.label(t),
                        onSelect: (s) => setState(() => _star.shape = s),
                      ),
                    ),
                    McField(
                      label: t.mcFwColours(_star.colors.length),
                      child: _MultiDye(
                        selected: _star.colors,
                        onTap: (d) => _toggleDye(_star.colors, d),
                      ),
                    ),
                    McField(
                      label: t.mcFwFade(_star.fades.length),
                      child: _MultiDye(
                        selected: _star.fades,
                        onTap: (d) => _toggleDye(_star.fades, d),
                      ),
                    ),
                    McSwitch(
                      label: t.mcFwTrail,
                      detail: t.mcFwTrailDetail,
                      value: _star.trail,
                      onChanged: (v) => setState(() => _star.trail = v),
                    ),
                    McSwitch(
                      label: t.mcFwTwinkle,
                      detail: t.mcFwTwinkleDetail,
                      value: _star.twinkle,
                      onChanged: (v) => setState(() => _star.twinkle = v),
                    ),
                  ],
                ),
              ),
          ],
        ),
        result: McFormColumn(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 320,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => CustomPaint(
                    painter: _FireworkPainter(
                      t: _anim.value,
                      stars: _stars,
                      flight: _flight,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            McPanel(
              title: t.mcFwCrafting,
              icon: Icons.grid_on_rounded,
              child: McFormColumn(
                gap: 6,
                children: [
                  for (var i = 0; i < _stars.length; i++) ...[
                    _Recipe(
                      t.mcFwStarN(i + 1),
                      [
                        '1 Gunpowder',
                        for (final d in _stars[i].colors) '1 ${d.label} Dye',
                        if (_stars[i].shape.item != null) '1 ${mcPretty(_stars[i].shape.item!)}',
                        if (_stars[i].trail) '1 Diamond',
                        if (_stars[i].twinkle) '1 Glowstone Dust',
                      ],
                    ),
                    if (_stars[i].fades.isNotEmpty)
                      _Recipe(t.mcFwFadeN(i + 1), [
                        t.mcFwStarN(i + 1),
                        for (final d in _stars[i].fades) '1 ${d.label} Dye',
                      ]),
                  ],
                  _Recipe(t.mcFwRocketX3, [
                    '1 Paper',
                    '$_flight Gunpowder',
                    for (var i = 0; i < _stars.length; i++) t.mcFwStarN(i + 1),
                  ]),
                ],
              ),
            ),
            McCodeBox(code: _command, title: t.mcCommand),
          ],
        ),
      ),
    );
  }
}

class _MultiDye extends StatelessWidget {
  const _MultiDye({required this.selected, required this.onTap});

  final List<McDye> selected;
  final ValueChanged<McDye> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final d in McDye.values)
          McSwatch(
            color: d.fireworkColor,
            tooltip: d.label,
            selected: selected.contains(d),
            size: 24,
            onTap: () => onTap(d),
            child: selected.contains(d)
                ? Center(
                    child: Text(
                      '${selected.indexOf(d) + 1}',
                      style: TextStyle(
                        color: d.fireworkColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
          ),
      ],
    );
  }
}

class _Recipe extends StatelessWidget {
  const _Recipe(this.name, this.parts);

  final String name;
  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            name,
            style: TextStyle(color: luma.accent, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Text(
            parts.join(' + '),
            style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _FireworkPainter extends CustomPainter {
  _FireworkPainter({required this.t, required this.stars, required this.flight});

  final double t;
  final List<_Star> stars;
  final int flight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070B1E), Color(0xFF1B1F44)],
        ).createShader(Offset.zero & size),
    );
    final ground = Paint()..color = const Color(0xFF0E1226);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 18, size.width, 18), ground);

    final launch = 0.22 + flight * 0.06;
    final burstAt = Offset(size.width / 2, size.height * (0.5 - flight * 0.08));
    if (t < launch) {
      final p = t / launch;
      final y = size.height - 18 - (size.height - 18 - burstAt.dy) * p;
      final trail = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.orange.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(burstAt.dx - 2, y, 4, 40));
      canvas.drawRect(Rect.fromLTWH(burstAt.dx - 1.5, y, 3, 40), trail);
      canvas.drawCircle(Offset(burstAt.dx, y), 3, Paint()..color = Colors.white);
      return;
    }
    final p = ((t - launch) / (1 - launch)).clamp(0.0, 1.0);
    for (var s = 0; s < stars.length; s++) {
      _burst(canvas, stars[s], burstAt + Offset((s - (stars.length - 1) / 2) * 6, 0), p, s);
    }
  }

  void _burst(Canvas canvas, _Star star, Offset c, double p, int seed) {
    if (star.colors.isEmpty) return;
    final rnd = math.Random(seed * 97 + star.shape.index);
    final points = <Offset>[];
    switch (star.shape) {
      case _Shape.smallBall:
      case _Shape.largeBall:
        final n = star.shape == _Shape.largeBall ? 90 : 50;
        for (var i = 0; i < n; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final r = 0.6 + rnd.nextDouble() * 0.4;
          points.add(Offset(math.cos(a), math.sin(a)) * r);
        }
      case _Shape.star:
        for (var i = 0; i < 60; i++) {
          final f = i / 60;
          final k = (f * 10).floor();
          final local = f * 10 - k;
          final a0 = k * math.pi / 5 - math.pi / 2;
          final a1 = (k + 1) * math.pi / 5 - math.pi / 2;
          final r0 = k.isEven ? 1.0 : 0.45;
          final r1 = k.isEven ? 0.45 : 1.0;
          final p0 = Offset(math.cos(a0), math.sin(a0)) * r0;
          final p1 = Offset(math.cos(a1), math.sin(a1)) * r1;
          points.add(Offset.lerp(p0, p1, local)!);
        }
      case _Shape.creeper:
        const face = [
          '........', '.XX..XX.', '.XX..XX.', '...XX...',
          '..XXXX..', '..XXXX..', '..X..X..', '........',
        ];
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            if (face[y][x] == 'X') points.add(Offset((x - 3.5) / 4, (y - 3.5) / 4));
          }
        }
      case _Shape.burst:
        for (var i = 0; i < 70; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final r = rnd.nextDouble();
          points.add(Offset(math.cos(a), math.sin(a)) * r);
        }
    }
    final radius = (star.shape == _Shape.largeBall ? 120.0 : 80.0) * Curves.easeOut.transform(math.min(1, p * 1.6));
    final fadePhase = ((p - 0.45) / 0.55).clamp(0.0, 1.0);
    final alpha = (1 - math.max(0, p - 0.7) / 0.3).clamp(0.0, 1.0);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length; i++) {
      final base = star.colors[i % star.colors.length].fireworkColor;
      final fade = star.fades.isEmpty ? base : star.fades[i % star.fades.length].fireworkColor;
      var color = Color.lerp(base, fade, fadePhase)!;
      var a = alpha;
      if (star.twinkle && p > 0.4 && ((i * 31 + (p * 40).floor()) % 3 == 0)) a *= 0.2;
      color = color.withValues(alpha: a);
      final gravity = Offset(0, p * p * 40);
      final pos = c + points[i] * radius + gravity;
      if (star.trail) {
        final prev = c + points[i] * radius * 0.82 + gravity * 0.7;
        paint
          ..color = color.withValues(alpha: a * 0.45)
          ..strokeWidth = 1.6;
        canvas.drawLine(prev, pos, paint);
      }
      canvas.drawCircle(pos, 2.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_FireworkPainter old) => true;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_data_types.dart';
import '../../data/ores_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

const _oreColors = {
  'coal': Color(0xFF3B3B3B),
  'iron': Color(0xFFD8AF93),
  'copper': Color(0xFFE0784A),
  'gold': Color(0xFFF2C94C),
  'redstone': Color(0xFFE53935),
  'lapis': Color(0xFF3F6FE0),
  'diamond': Color(0xFF4FD8D0),
  'emerald': Color(0xFF2ECC71),
  'nether_quartz': Color(0xFFE8E0D0),
  'nether_gold': Color(0xFFF5B83D),
  'ancient_debris': Color(0xFF8A5A44),
};

String _note(L t, String ore) => switch (ore) {
  'coal' => t.mcOreTipCoal,
  'iron' => t.mcOreTipIron,
  'copper' => t.mcOreTipCopper,
  'gold' => t.mcOreTipGold,
  'redstone' => t.mcOreTipRedstone,
  'lapis' => t.mcOreTipLapis,
  'diamond' => t.mcOreTipDiamond,
  'emerald' => t.mcOreTipEmerald,
  'nether_quartz' => t.mcOreTipQuartz,
  'nether_gold' => t.mcOreTipNetherGold,
  'ancient_debris' => t.mcOreTipDebris,
  _ => '',
};

/// Ore distribution from the world generator's own placement data: where
/// each ore is attempted, how often, and the best place to dig for it.
class OreGuideTool extends StatefulWidget {
  const OreGuideTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<OreGuideTool> createState() => _OreGuideToolState();
}

class _OreGuideToolState extends State<OreGuideTool> {
  McOre _ore = kMcOres.firstWhere((o) => o.id == 'diamond');
  bool _biomes = true;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final stats = _OreStats.of(_ore);
    return widget.host.frame(
      context,
      child: McFormColumn(
        children: [
          McPanel(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ore in kMcOres)
                  _OreChip(
                    ore: ore,
                    selected: ore == _ore,
                    onTap: () => setState(() => _ore = ore),
                  ),
              ],
            ),
          ),
          McStatRow(
            stats: [
              McStat(
                value: 'Y ${stats.practicalBest}',
                label: t.mcOreBestLevel,
                hue: McHue.violet,
              ),
              McStat(
                value: 'Y ${stats.minY} → ${stats.maxY}',
                label: t.mcOreRange,
                hue: McHue.indigo,
              ),
              McStat(
                value: stats.attempts >= 1
                    ? stats.attempts.toStringAsFixed(0)
                    : stats.attempts.toStringAsFixed(2),
                label: t.mcOreAttempts,
                hue: McHue.mint,
              ),
              McStat(
                value: '${stats.maxSize}',
                label: t.mcOreLargest,
                hue: McHue.orange,
              ),
            ],
          ),
          McPanel(
            title: t.mcOreDistribution(mcPretty(_ore.id)),
            icon: Icons.area_chart_rounded,
            trailing: _ore.placements.any((p) => p.biome != null)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.mcOreBiomeBonus,
                        style: TextStyle(color: luma.textSecondary, fontSize: 12),
                      ),
                      Switch(
                        value: _biomes,
                        onChanged: (v) => setState(() => _biomes = v),
                      ),
                    ],
                  )
                : null,
            child: SizedBox(
              height: 340,
              child: _OreChart(
                ore: _ore,
                biomes: _biomes,
                color: _oreColors[_ore.id] ?? luma.accent,
                best: stats.best,
                peakLabel: t.mcOrePeak(stats.best),
              ),
            ),
          ),
          McPanel(
            title: t.mcOreTips,
            icon: Icons.lightbulb_outline_rounded,
            child: Text(
              _note(t, _ore.id),
              style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.45),
            ),
          ),
          McPanel(
            title: t.mcOrePlacements,
            icon: Icons.table_rows_rounded,
            child: Column(
              children: [
                for (final p in _ore.placements) _PlacementRow(placement: p),
              ],
            ),
          ),
          McPanel(
            title: t.mcOreAllOverworld,
            icon: Icons.stacked_line_chart_rounded,
            child: SizedBox(height: 300, child: _OverviewChart(onPick: (o) => setState(() => _ore = o))),
          ),
        ],
      ),
    );
  }
}

class _OreStats {
  _OreStats({
    required this.best,
    required this.practicalBest,
    required this.minY,
    required this.maxY,
    required this.attempts,
    required this.maxSize,
  });

  final int best;
  final int practicalBest;
  final int minY;
  final int maxY;
  final double attempts;
  final int maxSize;

  static _OreStats of(McOre ore) {
    final bottom = ore.nether ? 0 : -64;
    final top = ore.nether ? 127 : 319;
    var best = bottom;
    var bestValue = -1.0;
    var minY = top, maxY = bottom;
    for (var y = bottom; y <= top; y++) {
      var v = 0.0;
      for (final p in ore.placements) {
        if (p.biome != null) continue;
        v += p.densityAt(y) * p.size * (1 - p.airDiscard * 0.5);
      }
      if (v > bestValue + 1e-9) {
        bestValue = v;
        best = y;
      }
      final any = ore.placements.any((p) => p.densityAt(y) > 0);
      if (any) {
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
    // Bedrock fills the bottom few layers; dig just above it.
    final practical = ore.nether ? best : math.max(best, -58);
    return _OreStats(
      best: best,
      practicalBest: practical,
      minY: minY,
      maxY: maxY,
      attempts: ore.placements
          .where((p) => p.biome == null)
          .fold(0.0, (s, p) => s + p.perChunk),
      maxSize: ore.placements.fold(0, (s, p) => math.max(s, p.size)),
    );
  }
}

class _OreChip extends StatelessWidget {
  const _OreChip({required this.ore, required this.selected, required this.onTap});

  final McOre ore;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _oreColors[ore.id] ?? luma.accent;
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: selected ? color : luma.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                mcPretty(ore.id),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (ore.nether) ...[
                const SizedBox(width: 6),
                McTag(L.of(context).mcOreNether, hue: McHue.rose),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacementRow extends StatelessWidget {
  const _PlacementRow({required this.placement});

  final McOrePlacement placement;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final p = placement;
    final shape = p.trapezoid
        ? t.mcOreTriangle(((p.minY + p.maxY) / 2).round())
        : t.mcOreEven;
    final attempts = p.perChunk >= 1
        ? t.mcOrePerChunk(p.perChunk.round())
        : t.mcOreOneIn((1 / p.perChunk).round());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.feature,
                  style: mcMono(context, size: 12.5),
                ),
                Text(
                  t.mcOrePlacementLine(p.minY, p.maxY, shape, attempts, p.size) +
                      (p.airDiscard > 0 ? ' · ${t.mcOreAirSkip((p.airDiscard * 100).round())}' : ''),
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (p.biome != null) McTag(mcPretty(p.biome!), hue: McHue.amber),
        ],
      ),
    );
  }
}

class _OreChart extends StatelessWidget {
  const _OreChart({
    required this.ore,
    required this.biomes,
    required this.color,
    required this.best,
    required this.peakLabel,
  });

  final McOre ore;
  final bool biomes;
  final Color color;
  final int best;
  final String peakLabel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return CustomPaint(
      size: Size.infinite,
      painter: _ChartPainter(
        series: [
          _Series(
            ore,
            color,
            biomeOnly: false,
          ),
          if (biomes && ore.placements.any((p) => p.biome != null))
            _Series(ore, McHue.amber.color, biomeOnly: true),
        ],
        bottom: ore.nether ? 0 : -64,
        top: ore.nether ? 128 : 320,
        best: best,
        peakLabel: peakLabel,
        text: luma.textMuted,
        grid: luma.border,
        accent: luma.accent,
      ),
    );
  }
}

class _Series {
  _Series(this.ore, this.color, {required this.biomeOnly});
  final McOre ore;
  final Color color;
  final bool biomeOnly;

  double at(int y) {
    var v = 0.0;
    for (final p in ore.placements) {
      if ((p.biome != null) != biomeOnly) continue;
      v += p.densityAt(y) * p.size * (1 - p.airDiscard * 0.5);
    }
    return v;
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.bottom,
    required this.top,
    required this.best,
    this.peakLabel = '',
    required this.text,
    required this.grid,
    required this.accent,
  });

  final List<_Series> series;
  final int bottom;
  final int top;
  final int best;
  final String peakLabel;
  final Color text;
  final Color grid;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0, bottomPad = 10.0, right = 10.0;
    final plot = Rect.fromLTRB(left, 8, size.width - right, size.height - bottomPad);
    var maxV = 0.0;
    for (final s in series) {
      for (var y = bottom; y < top; y++) {
        maxV = math.max(maxV, s.at(y));
      }
    }
    if (maxV <= 0) maxV = 1;
    double py(int y) => plot.bottom - (y - bottom) / (top - bottom) * plot.height;
    double px(double v) => plot.left + v / maxV * plot.width;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final step = top - bottom > 200 ? 32 : 16;
    for (var y = (bottom ~/ step) * step; y <= top; y += step) {
      if (y < bottom) continue;
      canvas.drawLine(Offset(plot.left, py(y)), Offset(plot.right, py(y)), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Y $y',
          style: TextStyle(color: text, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, py(y) - tp.height / 2));
    }

    for (final s in series.reversed) {
      final path = Path()..moveTo(plot.left, py(bottom));
      for (var y = bottom; y < top; y++) {
        path.lineTo(px(s.at(y)), py(y));
      }
      path
        ..lineTo(plot.left, py(top - 1))
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [s.color.withValues(alpha: 0.15), s.color.withValues(alpha: 0.55)],
          ).createShader(plot),
      );
      final line = Path();
      for (var y = bottom; y < top; y++) {
        final p = Offset(px(s.at(y)), py(y));
        if (y == bottom) {
          line.moveTo(p.dx, p.dy);
        } else {
          line.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final bestPaint = Paint()
      ..color = accent
      ..strokeWidth = 1.5;
    final by = py(best);
    for (var x = plot.left; x < plot.right; x += 8) {
      canvas.drawLine(Offset(x, by), Offset(x + 4, by), bestPaint);
    }
    final label = TextPainter(
      text: TextSpan(
        text: peakLabel,
        style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(plot.right - label.width - 4, by - label.height - 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

class _OverviewChart extends StatelessWidget {
  const _OverviewChart({required this.onPick});

  final ValueChanged<McOre> onPick;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final ores = kMcOres.where((o) => !o.nether).toList();
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(
              series: [
                for (final o in ores) _NormalizedSeries(o, _oreColors[o.id]!),
              ],
              bottom: -64,
              top: 320,
              best: 0,
              text: luma.textMuted,
              grid: luma.border,
              accent: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final o in ores)
              InkWell(
                onTap: () => onPick(o),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: _oreColors[o.id]),
                    const SizedBox(width: 4),
                    Text(
                      mcPretty(o.id),
                      style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Each ore scaled to its own peak, so rare ores are visible next to coal.
class _NormalizedSeries extends _Series {
  _NormalizedSeries(super.ore, super.color) : super(biomeOnly: false) {
    for (var y = -64; y < 320; y++) {
      _peak = math.max(_peak, super.at(y));
    }
  }

  double _peak = 0;

  @override
  double at(int y) => _peak == 0 ? 0 : super.at(y) / _peak;
}

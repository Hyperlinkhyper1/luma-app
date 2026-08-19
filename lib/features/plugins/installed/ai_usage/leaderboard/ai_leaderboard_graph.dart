import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_catalog_scope.dart';
import 'ai_leaderboard_metric.dart';
import 'ai_model.dart';

const List<Color> _kVendorPalette = [
  Color(0xFFC4B5FD),
  Color(0xFF6EE7B7),
  Color(0xFFFCA5A5),
  Color(0xFFFDE68A),
  Color(0xFF93C5FD),
  Color(0xFFD8B4FE),
  Color(0xFFFDBA74),
  Color(0xFF67E8F9),
];

/// The Leaderboard's **Graph** view: any two metrics plotted against each
/// other, with picked models highlighted.
///
/// Every model is one dot; hovering shows exactly what it is. The two axis
/// pickers can never both be set to the same metric — comparing a metric
/// against itself is always a straight line and never a question worth
/// asking, so the picker enforces it instead of leaving it to notice.
class AiLeaderboardGraphView extends StatefulWidget {
  const AiLeaderboardGraphView({super.key});

  @override
  State<AiLeaderboardGraphView> createState() => _AiLeaderboardGraphViewState();
}

class _AiLeaderboardGraphViewState extends State<AiLeaderboardGraphView> {
  AiMetric _x = AiMetric.blendedPrice;
  AiMetric _y = AiMetric.llmStats;
  bool _logX = true;
  bool _logY = false;
  final Set<String> _highlighted = {};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiCatalogScope.of(context).load();
  }

  void _setX(AiMetric m) {
    setState(() {
      if (m == _y) _y = _x; // swap rather than collide
      _x = m;
      if (!_x.logUseful) _logX = false;
    });
  }

  void _setY(AiMetric m) {
    setState(() {
      if (m == _x) _x = _y;
      _y = m;
      if (!_y.logUseful) _logY = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiCatalogScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.loading) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        if (repo.catalog.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.scatter_plot_outlined,
              title: 'No model data yet',
              subtitle: 'The graph needs the model catalogue to plot.',
            ),
          );
        }

        final models = repo.catalog.models;
        final points = pointsFor(models, _x, _y, logX: _logX, logY: _logY);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: points.length < 2
                    ? Center(
                        child: Text(
                          'Not enough models have both ${_x.label} and '
                          '${_y.label} to plot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.luma.textMuted),
                        ),
                      )
                    : _Scatter(
                        points: points,
                        x: _x,
                        y: _y,
                        logX: _logX,
                        logY: _logY,
                        highlighted: _highlighted,
                      ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 240,
                child: _AxisControls(
                  x: _x,
                  y: _y,
                  logX: _logX,
                  logY: _logY,
                  onX: _setX,
                  onY: _setY,
                  onLogX: (v) => setState(() => _logX = v),
                  onLogY: (v) => setState(() => _logY = v),
                  models: models,
                  highlighted: _highlighted,
                  onToggleHighlight: (id) => setState(() {
                    if (!_highlighted.remove(id)) _highlighted.add(id);
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AxisControls extends StatelessWidget {
  const _AxisControls({
    required this.x,
    required this.y,
    required this.logX,
    required this.logY,
    required this.onX,
    required this.onY,
    required this.onLogX,
    required this.onLogY,
    required this.models,
    required this.highlighted,
    required this.onToggleHighlight,
  });

  final AiMetric x;
  final AiMetric y;
  final bool logX;
  final bool logY;
  final ValueChanged<AiMetric> onX;
  final ValueChanged<AiMetric> onY;
  final ValueChanged<bool> onLogX;
  final ValueChanged<bool> onLogY;
  final List<AiModel> models;
  final Set<String> highlighted;
  final ValueChanged<String> onToggleHighlight;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('X AXIS', style: _labelStyle(luma)),
          const SizedBox(height: 6),
          // The other axis's metric is excluded here — plotting a value
          // against itself is never a useful question.
          _MetricDropdown(value: x, exclude: y, onChanged: onX),
          if (x.logUseful) ...[
            const SizedBox(height: 6),
            _LogToggle(value: logX, onChanged: onLogX),
          ],
          const SizedBox(height: 18),
          Text('Y AXIS', style: _labelStyle(luma)),
          const SizedBox(height: 6),
          _MetricDropdown(value: y, exclude: x, onChanged: onY),
          if (y.logUseful) ...[
            const SizedBox(height: 6),
            _LogToggle(value: logY, onChanged: onLogY),
          ],
          const SizedBox(height: 22),
          Text('HIGHLIGHT MODELS', style: _labelStyle(luma)),
          const SizedBox(height: 4),
          Text(
            'Pick models to pick out on the plot.',
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          LumaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 260,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in models)
                    _HighlightRow(
                      model: m,
                      selected: highlighted.contains(m.id),
                      onTap: () => onToggleHighlight(m.id),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle(LumaPalette luma) => TextStyle(
        color: luma.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      );
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final AiModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 17,
              color: selected ? luma.accent : luma.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                model.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricDropdown extends StatelessWidget {
  const _MetricDropdown({
    required this.value,
    required this.exclude,
    required this.onChanged,
  });

  final AiMetric value;
  final AiMetric exclude;
  final ValueChanged<AiMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border.all(color: luma.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AiMetric>(
          value: value,
          isExpanded: true,
          dropdownColor: luma.surface,
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          items: [
            for (final m in AiMetric.values)
              DropdownMenuItem(
                // Disabled rather than omitted: the item stays visible so the
                // picker doesn't seem to have lost an option, it's just not
                // choosable while the other axis holds it.
                enabled: m != exclude,
                value: m,
                child: Text(
                  m.label,
                  style: m == exclude
                      ? TextStyle(color: luma.textMuted)
                      : null,
                ),
              ),
          ],
          onChanged: (m) {
            if (m != null && m != exclude) onChanged(m);
          },
        ),
      ),
    );
  }
}

class _LogToggle extends StatelessWidget {
  const _LogToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: luma.accent,
        ),
        const SizedBox(width: 4),
        Text('Log scale', style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
      ],
    );
  }
}

class _Scatter extends StatelessWidget {
  const _Scatter({
    required this.points,
    required this.x,
    required this.y,
    required this.logX,
    required this.logY,
    required this.highlighted,
  });

  final List<({AiModel model, double x, double y})> points;
  final AiMetric x;
  final AiMetric y;
  final bool logX;
  final bool logY;
  final Set<String> highlighted;

  double _scale(double v, bool log) => log ? math.log(v) / math.ln10 : v;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final vendorColor = <String, Color>{};
    var nextColor = 0;
    Color colorFor(String vendor) => vendorColor.putIfAbsent(vendor, () {
          final c = _kVendorPalette[nextColor % _kVendorPalette.length];
          nextColor++;
          return c;
        });

    final anyHighlighted = highlighted.isNotEmpty;
    final spots = [
      for (final p in points)
        ScatterSpot(
          _scale(p.x, logX),
          _scale(p.y, logY),
          show: true,
          dotPainter: FlDotCirclePainter(
            radius: highlighted.contains(p.model.id) ? 8 : 4.5,
            color: highlighted.contains(p.model.id)
                ? luma.accent
                : colorFor(p.model.vendor).withValues(
                    alpha: anyHighlighted ? 0.35 : 0.85),
            strokeWidth: highlighted.contains(p.model.id) ? 2 : 0,
            strokeColor: luma.textPrimary,
          ),
        ),
    ];

    final xs = [for (final p in points) _scale(p.x, logX)];
    final ys = [for (final p in points) _scale(p.y, logY)];
    final xPad = (xs.reduce(math.max) - xs.reduce(math.min)) * 0.08 + 0.01;
    final yPad = (ys.reduce(math.max) - ys.reduce(math.min)) * 0.08 + 0.01;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${points.length} models plotted',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: xs.reduce(math.min) - xPad,
                maxX: xs.reduce(math.max) + xPad,
                minY: ys.reduce(math.min) - yPad,
                maxY: ys.reduce(math.max) + yPad,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: luma.border, strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      FlLine(color: luma.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: luma.border),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(x.axisLabel,
                        style: TextStyle(color: luma.textMuted, fontSize: 11)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          x.formatTick(logX ? math.pow(10, value).toDouble() : value),
                          style: TextStyle(color: luma.textMuted, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(y.axisLabel,
                        style: TextStyle(color: luma.textMuted, fontSize: 11)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) => Text(
                        y.formatTick(logY ? math.pow(10, value).toDouble() : value),
                        style: TextStyle(color: luma.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (_) => luma.surfaceHover,
                    getTooltipItems: (spot) {
                      final index = spots.indexOf(spot);
                      if (index < 0 || index >= points.length) return null;
                      final p = points[index];
                      return ScatterTooltipItem(
                        '${p.model.name}\n'
                        '${x.label}: ${x.format(p.x)}   '
                        '${y.label}: ${y.format(p.y)}',
                        textStyle:
                            TextStyle(color: luma.textPrimary, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

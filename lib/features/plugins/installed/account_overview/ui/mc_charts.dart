import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../mc_history.dart';
import '../mc_models.dart';
import 'account_shared.dart';

/// How far back a trend chart looks.
enum McRange {
  week('7D', 7),
  month('30D', 30),
  quarter('90D', 90),
  year('1Y', 365),
  all('All', 100000);

  const McRange(this.label, this.days);
  final String label;
  final int days;
}

List<McDailyPoint> _within(List<McDailyPoint> points, McRange range) {
  if (range == McRange.all) return points;
  final cutoff = DateTime.now().subtract(Duration(days: range.days));
  return points.where((p) => !p.day.isBefore(cutoff)).toList();
}

List<McDelta> _deltasWithin(List<McDelta> deltas, McRange range) {
  if (range == McRange.all) return deltas;
  final cutoff = DateTime.now().subtract(Duration(days: range.days));
  return deltas.where((d) => !d.day.isBefore(cutoff)).toList();
}

/// Cumulative totals over time.
///
/// The y-axis deliberately does not start at zero: a download count of two
/// million that grew by a thousand this month is a flat line from zero, and
/// the point of the chart is the shape of the growth. The axis labels state
/// the real values, so nothing is hidden by the choice.
class McTrendChart extends StatelessWidget {
  const McTrendChart({
    super.key,
    required this.points,
    required this.range,
    this.metric = McMetric.downloads,
  });

  final List<McDailyPoint> points;
  final McRange range;
  final McMetric metric;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final visible = _within(points, range);

    if (visible.length < 2) {
      return _CollectingState(pointCount: visible.length);
    }

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final values = [for (final p in visible) metric.read(p).toDouble()];
    final minX = visible.first.day.millisecondsSinceEpoch.toDouble();
    final maxX = visible.last.day.millisecondsSinceEpoch.toDouble();
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);

    // A series that never moved would draw a zero-height chart, so a flat
    // line gets a band around it instead of a degenerate axis.
    final span = high - low;
    final pad = span == 0 ? math.max(high * 0.1, 1) : span * 0.2;
    final minY = math.max(0.0, low - pad);
    final maxY = high + pad;

    return Semantics(
      label: '${metric.label} from ${formatDate(visible.first.day)} to '
          '${formatDate(visible.last.day)}: '
          '${formatCount(low)} up to ${formatCount(high)}',
      excludeSemantics: true,
      child: LineChart(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        LineChartData(
          minX: minX,
          maxX: maxX == minX ? minX + 1 : maxX,
          minY: minY,
          maxY: maxY == minY ? minY + 1 : maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max((maxY - minY) / 3, 1),
            getDrawingHorizontalLine: (_) => FlLine(
              color: luma.border.withValues(alpha: 0.6),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: math.max((maxY - minY) / 3, 1),
                getTitlesWidget: (value, meta) {
                  if (value <= meta.min || value >= meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      formatCompact(value),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: math.max((maxX - minX) / 3, 1),
                getTitlesWidget: (value, meta) {
                  if (value <= meta.min || value >= meta.max) {
                    return const SizedBox.shrink();
                  }
                  final at = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${at.day} ${monthLabel(at.month)}',
                      style: TextStyle(color: luma.textMuted, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => luma.rail,
              tooltipRoundedRadius: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${formatCount(spot.y)} ${metric.label.toLowerCase()}\n'
                    '${formatDate(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}',
                    TextStyle(
                      color: luma.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final point in visible)
                  FlSpot(
                    point.day.millisecondsSinceEpoch.toDouble(),
                    metric.read(point).toDouble(),
                  ),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: metric.color(context),
              barWidth: 2.5,
              dotData: FlDotData(show: visible.length <= 20),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    metric.color(context).withValues(alpha: 0.28),
                    metric.color(context).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which number a chart is drawing.
enum McMetric {
  downloads('Downloads'),
  followers('Followers'),
  views('Views');

  const McMetric(this.label);
  final String label;

  int read(McDailyPoint point) => switch (this) {
        McMetric.downloads => point.downloads,
        McMetric.followers => point.followers,
        McMetric.views => point.views,
      };

  Color color(BuildContext context) {
    final luma = context.luma;
    return switch (this) {
      McMetric.downloads => luma.accent,
      McMetric.followers => luma.warning,
      McMetric.views => luma.success,
    };
  }
}

/// One project's share of a day's gain, for a gain chart's tooltip.
class McProjectGain {
  const McProjectGain({required this.name, required this.gained});

  final String name;
  final int gained;
}

/// Buckets every project's own daily gains by day, highest first — the
/// per-project breakdown a combined "downloads gained per day" bar cannot
/// show on its own.
Map<DateTime, List<McProjectGain>> projectGainsByDay(
  McHistoryStore history,
  List<McProject> projects,
) {
  final byDay = <DateTime, List<McProjectGain>>{};
  for (final project in projects) {
    for (final delta in history.deltasFor(project.historyKey)) {
      if (delta.gained <= 0) continue;
      (byDay[delta.day] ??= [])
          .add(McProjectGain(name: project.name, gained: delta.gained));
    }
  }
  for (final gains in byDay.values) {
    gains.sort((a, b) => b.gained.compareTo(a.gained));
  }
  return byDay;
}

/// Per-day gains as bars — the "how am I doing lately" view that a
/// cumulative line hides.
class McDailyGainChart extends StatelessWidget {
  const McDailyGainChart({
    super.key,
    required this.deltas,
    required this.range,
    this.projectBreakdown = const {},
  });

  final List<McDelta> deltas;
  final McRange range;

  /// Which projects made up a day's gain, keyed by that day — shown as extra
  /// lines in the bar's tooltip. Empty when the caller has nothing to break
  /// a day down by (e.g. a single-platform chart).
  final Map<DateTime, List<McProjectGain>> projectBreakdown;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final visible = _deltasWithin(deltas, range);

    if (visible.isEmpty) return _CollectingState(pointCount: visible.length);

    final maxY = visible
        .map((d) => d.gained.toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      label: 'Daily gain over ${visible.length} days, '
          'peaking at ${formatCount(maxY)}',
      excludeSemantics: true,
      child: BarChart(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(maxY / 3, 1),
            getDrawingHorizontalLine: (_) => FlLine(
              color: luma.border.withValues(alpha: 0.6),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: math.max(maxY / 3, 1),
                getTitlesWidget: (value, meta) {
                  if (value <= meta.min || value >= meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      formatCompact(value),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: luma.textMuted, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                // Label roughly four days across the axis rather than every
                // bar, which would overlap into mush on a 90-day range.
                interval: math.max(visible.length / 4, 1).floorToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= visible.length) {
                    return const SizedBox.shrink();
                  }
                  final day = visible[index].day;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${day.day} ${monthLabel(day.month)}',
                      style: TextStyle(color: luma.textMuted, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => luma.rail,
              tooltipRoundedRadius: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = visible[group.x.toInt()].day;
                final topProjects = (projectBreakdown[day] ?? const [])
                    .take(5);
                return BarTooltipItem(
                  '+${formatCount(rod.toY)} downloads\n${formatDate(day)}',
                  TextStyle(
                    color: luma.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    for (final project in topProjects)
                      TextSpan(
                        text: '\n${project.name}: '
                            '+${formatCount(project.gained)}',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < visible.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: visible[i].gained.toDouble(),
                    color: luma.accent,
                    width: math.max(2, 140 / visible.length).clamp(2, 14).toDouble(),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// What a chart shows before it has enough history to be a chart.
///
/// This is the honest face of the local-snapshot approach: CurseForge and
/// Planet Minecraft publish a running total and no history at all, so the
/// first days after setup genuinely have nothing to draw. Saying so beats an
/// empty axis frame that looks broken.
class _CollectingState extends StatelessWidget {
  const _CollectingState({required this.pointCount});

  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_rounded, size: 26, color: luma.textMuted),
            const SizedBox(height: 10),
            Text(
              pointCount == 0
                  ? 'No history yet'
                  : 'One day recorded so far',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'These platforms publish a running total and no history, so '
              'luma records one point per day. The line appears once there '
              'are two.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

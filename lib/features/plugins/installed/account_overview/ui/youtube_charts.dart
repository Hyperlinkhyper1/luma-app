import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import 'account_shared.dart';

/// One value per day, drawn as a line.
///
/// Visually the same language as `McTrendChart` (`ui/mc_charts.dart`) but
/// generic over any daily metric: the Analytics API already returns a real
/// time series and needs no locally-grown history to backfill, so there is
/// no per-platform metric picker to carry here.
class YoutubeTrendChart extends StatelessWidget {
  const YoutubeTrendChart({
    super.key,
    required this.points,
    required this.color,
    required this.valueLabel,
  });

  final List<({DateTime day, num value})> points;
  final Color color;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (points.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'Not enough data yet.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final values = [for (final p in points) p.value.toDouble()];
    final minX = points.first.day.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.day.millisecondsSinceEpoch.toDouble();
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);

    // A series that never moved would draw a zero-height chart, so a flat
    // line gets a band around it instead of a degenerate axis.
    final span = high - low;
    final pad = span == 0 ? math.max(high * 0.1, 1) : span * 0.2;
    final minY = math.max(0.0, low - pad);
    final maxY = high + pad;

    return Semantics(
      label: '$valueLabel from ${formatDate(points.first.day)} to '
          '${formatDate(points.last.day)}: '
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
                    '${formatCount(spot.y)} ${valueLabel.toLowerCase()}\n'
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
                for (final point in points)
                  FlSpot(
                    point.day.millisecondsSinceEpoch.toDouble(),
                    point.value.toDouble(),
                  ),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(show: points.length <= 20),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.0),
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

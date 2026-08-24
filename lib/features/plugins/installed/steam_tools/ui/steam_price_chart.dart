import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/steam_database.dart';
import '../steam_price_history.dart';

/// The price-history card: a range selector, a step chart of every price
/// this device has recorded, and an honest note about how much history that
/// actually is.
///
/// Steam publishes no price history of its own — only what a game costs
/// right now — so the line is built from luma's own observations. That makes
/// the "tracking since" note load-bearing rather than decorative: without
/// it, a flat line under a "5Y" button reads as five years of unchanged
/// price instead of a week of watching.
class SteamPriceHistoryCard extends StatefulWidget {
  const SteamPriceHistoryCard({
    super.key,
    required this.points,
    required this.fallbackCurrency,
    this.loading = false,
  });

  final List<SteamPricePoint> points;
  final String fallbackCurrency;
  final bool loading;

  @override
  State<SteamPriceHistoryCard> createState() => _SteamPriceHistoryCardState();
}

class _SteamPriceHistoryCardState extends State<SteamPriceHistoryCard> {
  SteamPriceRange _range = SteamPriceRange.year;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final series = buildSteamPriceSeries(
      widget.points,
      _range,
      DateTime.now(),
      fallbackCurrency: widget.fallbackCurrency,
    );

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Price history',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LumaSegmentedTabs(
            tabs: [for (final r in SteamPriceRange.values) r.label],
            selectedIndex: _range.index,
            onSelect: (i) =>
                setState(() => _range = SteamPriceRange.values[i]),
            scrollable: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: widget.loading && widget.points.isEmpty
                ? const _ChartSkeleton()
                : series.isEmpty
                    ? _ChartEmpty(range: _range)
                    : _PriceChart(series: series),
          ),
          if (!series.isEmpty) ...[
            const SizedBox(height: 14),
            _SeriesSummary(series: series),
          ],
          const SizedBox(height: 10),
          _TrackingNote(series: series, range: _range),
        ],
      ),
    );
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.series});

  final SteamPriceSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // The chart animates between ranges, which is motion the user did not
    // ask for if they have reduced motion on.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final samples = series.samples;
    final minX = samples.first.at.millisecondsSinceEpoch.toDouble();
    final maxX = samples.last.at.millisecondsSinceEpoch.toDouble();
    final low = (series.lowestCents ?? 0).toDouble();
    final high = (series.highestCents ?? 0).toDouble();

    // A price that never moved would otherwise draw a zero-height chart, so
    // a flat line gets a band around it instead of a degenerate axis.
    final span = high - low;
    final pad = span == 0 ? math.max(high * 0.2, 100) : span * 0.18;
    final minY = math.max(0.0, low - pad);
    final maxY = high + pad;

    final formatter = _AxisDates(series.range);

    return Semantics(
      label: _chartSummary(series),
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
                reservedSize: 52,
                interval: math.max((maxY - minY) / 3, 1),
                getTitlesWidget: (value, meta) {
                  if (value <= meta.min || value >= meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      formatSteamPrice(value.round(), series.currency),
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      textAlign: TextAlign.right,
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
                  final at =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      formatter.axis(at),
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
                    '${formatSteamPrice(spot.y.round(), series.currency)}\n'
                    '${formatter.tooltip(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}',
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
                for (final sample in series.samples)
                  FlSpot(
                    sample.at.millisecondsSinceEpoch.toDouble(),
                    sample.finalCents.toDouble(),
                  ),
              ],
              // A price holds its value until it changes; a curve between
              // two observations would draw a slow slide that never
              // happened.
              isStepLineChart: true,
              lineChartStepData: const LineChartStepData(
                stepDirection: LineChartStepData.stepDirectionForward,
              ),
              color: luma.accent,
              barWidth: 2.5,
              dotData: FlDotData(
                // Dots only where a price actually changed, so the carried
                // start point and the "as of now" point do not read as
                // observations that were never made.
                show: series.samples.length <= 60,
                checkToShowDot: (spot, bar) {
                  final index = bar.spots.indexOf(spot);
                  return index > 0 && index < bar.spots.length - 1;
                },
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: luma.accent,
                  strokeWidth: 2,
                  strokeColor: luma.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    luma.accent.withValues(alpha: 0.22),
                    luma.accent.withValues(alpha: 0.02),
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

/// Chooses date formats that suit the window — a five-year chart labelled to
/// the minute is unreadable, and a one-day chart labelled by month says
/// nothing.
class _AxisDates {
  _AxisDates(this.range);

  final SteamPriceRange range;

  String axis(DateTime at) => switch (range) {
        SteamPriceRange.day => DateFormat.Hm().format(at),
        SteamPriceRange.week => DateFormat.MMMd().format(at),
        SteamPriceRange.month => DateFormat.MMMd().format(at),
        SteamPriceRange.sixMonths => DateFormat.MMM().format(at),
        SteamPriceRange.year => DateFormat.MMM().format(at),
        SteamPriceRange.fiveYears => DateFormat('MMM yyyy').format(at),
      };

  String tooltip(DateTime at) => switch (range) {
        SteamPriceRange.day ||
        SteamPriceRange.week =>
          DateFormat('d MMM, HH:mm').format(at),
        _ => DateFormat.yMMMd().format(at),
      };
}

String _chartSummary(SteamPriceSeries series) {
  final low = series.lowestCents;
  final high = series.highestCents;
  if (low == null || high == null) return 'No price history yet.';
  if (series.isFlat) {
    return 'Price history over ${series.range.blurb}: unchanged at '
        '${formatSteamPrice(low, series.currency)}.';
  }
  return 'Price history over ${series.range.blurb}: between '
      '${formatSteamPrice(low, series.currency)} and '
      '${formatSteamPrice(high, series.currency)}.';
}

/// Lowest / highest across the shown window. Suppressed when the price never
/// moved, where it would print the same number twice and imply a range that
/// does not exist.
class _SeriesSummary extends StatelessWidget {
  const _SeriesSummary({required this.series});

  final SteamPriceSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final low = series.lowestCents;
    final high = series.highestCents;
    if (low == null || high == null) return const SizedBox.shrink();

    if (series.isFlat) {
      return Text(
        'Unchanged at ${formatSteamPrice(low, series.currency)} across '
        '${series.range.blurb}.',
        style: TextStyle(color: luma.textSecondary, fontSize: 12),
      );
    }

    return Row(
      children: [
        _Stat(
          label: 'Lowest seen',
          value: formatSteamPrice(low, series.currency),
          color: luma.success,
        ),
        const SizedBox(width: 20),
        _Stat(
          label: 'Highest seen',
          value: formatSteamPrice(high, series.currency),
          color: luma.textPrimary,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: luma.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Says plainly how much of the selected window is real data.
class _TrackingNote extends StatelessWidget {
  const _TrackingNote({required this.series, required this.range});

  final SteamPriceSeries series;
  final SteamPriceRange range;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final since = series.trackedSince;

    final String message;
    if (since == null) {
      message = 'Steam publishes no price history, so luma records the price '
          'itself. Nothing has been recorded for this game yet.';
    } else if (series.coversFullRange) {
      message = 'Recorded by luma on this device since '
          '${DateFormat.yMMMd().format(since)}.';
    } else {
      final days = DateTime.now().difference(since).inDays;
      final tracked = days < 1
          ? 'today'
          : days == 1
              ? '1 day'
              : '$days days';
      message = 'Steam publishes no price history, so this chart is what luma '
          'has recorded on this device — $tracked so far, not '
          '${range.blurb}.';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: luma.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.range});

  final SteamPriceRange range;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline_rounded, size: 26, color: luma.textMuted),
          const SizedBox(height: 10),
          Text(
            'No prices recorded over ${range.blurb}',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Refresh prices to take the first reading.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A shimmerless placeholder — the chart's own frame, greyed, so the card
/// does not change height when the data lands.
class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
      ),
    );
  }
}

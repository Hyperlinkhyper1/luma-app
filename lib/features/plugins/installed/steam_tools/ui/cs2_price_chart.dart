import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../cs2_price_history.dart';
import '../data/steam_database.dart';
import '../steam_price_history.dart' show formatSteamPrice;

/// The chart-plus-summary body of a [Cs2PriceSeries] on its own, with no
/// card chrome, title or range selector around it.
///
/// [Cs2PriceHistoryCard] below builds one of these for a single listing,
/// wrapped with a title, its own range tabs, and a tracked/loading switch.
/// The Tracked tab's combined "total value" card wants the same chart body
/// — empty/single-reading/line-chart plus the lowest/highest summary — but
/// inside its own card with its own headline numbers above it, so this is
/// pulled out rather than duplicated.
class Cs2PriceSeriesView extends StatelessWidget {
  const Cs2PriceSeriesView({super.key, required this.series, this.height = 200});

  final Cs2PriceSeries series;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: series.isEmpty
              ? const _ChartEmpty()
              : series.isSingle
                  ? _SingleReading(series: series)
                  : _PriceChart(series: series),
        ),
        if (series.samples.length >= 2) ...[
          const SizedBox(height: 14),
          _SeriesSummary(series: series),
        ],
      ],
    );
  }
}

/// The CS2 price-history card: a range selector and a line of every
/// Community Market reading luma has taken for this listing.
///
/// Steam publishes no history for a market item — not even to a logged-in
/// browser — so unlike [SteamPriceHistoryCard] there is no external record
/// to draw. Every point here is something this device itself observed,
/// which is also why watching starts the moment the listing is tracked, not
/// before: an untracked item has nothing to plot yet, honestly.
class Cs2PriceHistoryCard extends StatefulWidget {
  const Cs2PriceHistoryCard({
    super.key,
    required this.points,
    required this.fallbackCurrency,
    required this.tracked,
    this.startingPriceCents,
    this.loading = false,
    this.onTrack,
  });

  final List<Cs2MarketPricePoint> points;
  final String fallbackCurrency;
  final bool tracked;

  /// The cost basis gain/loss is measured from, when the user set one — see
  /// `Cs2StartingPriceDialog`. Null hides the Price/Gain & Loss toggle
  /// entirely rather than showing a mode with nothing to compare against.
  final int? startingPriceCents;
  final bool loading;
  final VoidCallback? onTrack;

  @override
  State<Cs2PriceHistoryCard> createState() => _Cs2PriceHistoryCardState();
}

class _Cs2PriceHistoryCardState extends State<Cs2PriceHistoryCard> {
  Cs2PriceRange _range = Cs2PriceRange.week;
  bool _gainLoss = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final series = buildCs2PriceSeries(
      widget.points,
      _range,
      DateTime.now(),
      fallbackCurrency: widget.fallbackCurrency,
    );
    final startingPriceCents = widget.startingPriceCents;
    final showGainLoss = _gainLoss && startingPriceCents != null;
    final gainSeries =
        startingPriceCents == null ? null : buildCs2GainLossSeries(series, startingPriceCents);

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
          if (startingPriceCents != null) ...[
            const SizedBox(height: 12),
            LumaSegmentedTabs(
              tabs: const ['Price', 'Gain & Loss'],
              selectedIndex: _gainLoss ? 1 : 0,
              onSelect: (i) => setState(() => _gainLoss = i == 1),
            ),
          ],
          const SizedBox(height: 12),
          LumaSegmentedTabs(
            tabs: [for (final r in Cs2PriceRange.values) r.label],
            selectedIndex: _range.index,
            onSelect: (i) => setState(() => _range = Cs2PriceRange.values[i]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: !widget.tracked
                ? _NotTracked(onTrack: widget.onTrack)
                : widget.loading && widget.points.isEmpty
                    ? const _ChartSkeleton()
                    : showGainLoss
                        ? _gainLossBody(gainSeries!)
                        : _priceBody(series),
          ),
          if (widget.tracked && !showGainLoss && series.samples.length >= 2) ...[
            const SizedBox(height: 14),
            _SeriesSummary(series: series),
          ],
          if (widget.tracked && showGainLoss && gainSeries!.samples.length >= 2) ...[
            const SizedBox(height: 14),
            _GainLossSeriesSummary(series: gainSeries),
          ],
        ],
      ),
    );
  }

  Widget _priceBody(Cs2PriceSeries series) => series.isEmpty
      ? const _ChartEmpty()
      : series.isSingle
          ? _SingleReading(series: series)
          : _PriceChart(series: series);

  Widget _gainLossBody(Cs2GainLossSeries series) => series.isEmpty
      ? const _ChartEmpty()
      : series.isSingle
          ? _SingleGainLossReading(series: series)
          : _GainLossChart(series: series);
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.series});

  final Cs2PriceSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final samples = series.samples;
    final minX = samples.first.at.millisecondsSinceEpoch.toDouble();
    final maxX = samples.last.at.millisecondsSinceEpoch.toDouble();
    final low = (series.lowestCents ?? 0).toDouble();
    final high = (series.highestCents ?? 0).toDouble();

    final span = high - low;
    final pad = span == 0 ? math.max(high * 0.2, 50) : span * 0.18;
    final minY = math.max(0.0, low - pad);
    final maxY = high + pad;

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
                reservedSize: 56,
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
                      _axisLabel(series.range, at),
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
                    '${DateFormat('d MMM, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}',
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
                    sample.priceCents.toDouble(),
                  ),
              ],
              isCurved: false,
              color: luma.accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: series.samples.length <= 40,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
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

  static String _axisLabel(Cs2PriceRange range, DateTime at) => switch (range) {
        Cs2PriceRange.day => DateFormat.Hm().format(at),
        Cs2PriceRange.week => DateFormat.MMMd().format(at),
        Cs2PriceRange.month => DateFormat.MMMd().format(at),
        Cs2PriceRange.all => DateFormat.yMMMd().format(at),
      };
}

/// "$12.34" for a gain, "-$5.00" for a loss, sign always shown even for a
/// gain since this is a delta, not a price — an unsigned figure here would
/// read as ambiguous about which direction it moved.
String _formatDelta(int cents, String currency) {
  if (cents == 0) return formatSteamPrice(0, currency);
  final sign = cents > 0 ? '+' : '-';
  return '$sign${formatSteamPrice(cents.abs(), currency)}';
}

/// Same line chart as [_PriceChart] but recentred on zero: values can go
/// negative, the line is coloured by whether the listing is currently up or
/// down against the starting price, and a dashed reference line marks where
/// "no change" sits.
class _GainLossChart extends StatelessWidget {
  const _GainLossChart({required this.series});

  final Cs2GainLossSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final samples = series.samples;
    final minX = samples.first.at.millisecondsSinceEpoch.toDouble();
    final maxX = samples.last.at.millisecondsSinceEpoch.toDouble();
    final low = (series.lowestDeltaCents ?? 0).toDouble();
    final high = (series.highestDeltaCents ?? 0).toDouble();

    final span = high - low;
    final double pad =
        span == 0 ? math.max(high.abs() * 0.2, 50.0) : span * 0.18;
    var minY = low - pad;
    var maxY = high + pad;
    // Keep the zero line inside the visible range even when every reading
    // sits on one side of it, so a pure gain or pure loss run still shows
    // what it's being measured against.
    if (minY > 0) minY = -pad;
    if (maxY < 0) maxY = pad;

    final gain = (series.currentDeltaCents ?? 0) >= 0;
    final lineColor = gain ? luma.success : luma.danger;

    return Semantics(
      label: _gainLossSummary(series),
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
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: luma.textMuted.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: const [5, 4],
              ),
            ],
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
                reservedSize: 56,
                interval: math.max((maxY - minY) / 3, 1),
                getTitlesWidget: (value, meta) {
                  if (value <= meta.min || value >= meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _formatDelta(value.round(), series.currency),
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
                      _axisLabel(series.range, at),
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
                    '${_formatDelta(spot.y.round(), series.currency)}\n'
                    '${DateFormat('d MMM, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}',
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
                    sample.deltaCents.toDouble(),
                  ),
              ],
              isCurved: false,
              color: lineColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: series.samples.length <= 40,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: lineColor,
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
                    lineColor.withValues(alpha: 0.22),
                    lineColor.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _axisLabel(Cs2PriceRange range, DateTime at) => switch (range) {
        Cs2PriceRange.day => DateFormat.Hm().format(at),
        Cs2PriceRange.week => DateFormat.MMMd().format(at),
        Cs2PriceRange.month => DateFormat.MMMd().format(at),
        Cs2PriceRange.all => DateFormat.yMMMd().format(at),
      };
}

String _gainLossSummary(Cs2GainLossSeries series) {
  final low = series.lowestDeltaCents;
  final high = series.highestDeltaCents;
  if (low == null || high == null) return 'No price readings available.';
  if (low == high) {
    return 'Unchanged at ${_formatDelta(low, series.currency)} against the '
        'starting price across the readings shown.';
  }
  return 'Between ${_formatDelta(low, series.currency)} and '
      '${_formatDelta(high, series.currency)} against the starting price '
      'across the readings shown.';
}

class _SingleGainLossReading extends StatelessWidget {
  const _SingleGainLossReading({required this.series});

  final Cs2GainLossSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final delta = series.samples.first.deltaCents;
    final color = delta == 0
        ? luma.textSecondary
        : delta > 0
            ? luma.success
            : luma.danger;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline_rounded, size: 26, color: luma.textMuted),
          const SizedBox(height: 10),
          Text(
            _formatDelta(delta, series.currency),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One reading so far — a trend needs at least two.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GainLossSeriesSummary extends StatelessWidget {
  const _GainLossSeriesSummary({required this.series});

  final Cs2GainLossSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final low = series.lowestDeltaCents;
    final high = series.highestDeltaCents;
    if (low == null || high == null) return const SizedBox.shrink();

    if (low == high) {
      return Text(
        'Unchanged at ${_formatDelta(low, series.currency)} across '
        '${series.samples.length} readings.',
        style: TextStyle(color: luma.textSecondary, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        _Stat(
          label: 'Best',
          value: _formatDelta(high, series.currency),
          color: high >= 0 ? luma.success : luma.danger,
        ),
        _Stat(
          label: 'Worst',
          value: _formatDelta(low, series.currency),
          color: low >= 0 ? luma.success : luma.danger,
        ),
      ],
    );
  }
}

String _chartSummary(Cs2PriceSeries series) {
  final low = series.lowestCents;
  final high = series.highestCents;
  if (low == null || high == null) return 'No price readings available.';
  if (series.isFlat) {
    return 'Unchanged at ${formatSteamPrice(low, series.currency)} across '
        'the readings shown.';
  }
  return 'Between ${formatSteamPrice(low, series.currency)} and '
      '${formatSteamPrice(high, series.currency)} across the readings shown.';
}

class _SeriesSummary extends StatelessWidget {
  const _SeriesSummary({required this.series});

  final Cs2PriceSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final low = series.lowestCents;
    final high = series.highestCents;
    if (low == null || high == null) return const SizedBox.shrink();

    if (series.isFlat) {
      return Text(
        'Unchanged at ${formatSteamPrice(low, series.currency)} across '
        '${series.samples.length} readings.',
        style: TextStyle(color: luma.textSecondary, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        _Stat(
          label: 'Lowest',
          value: formatSteamPrice(low, series.currency),
          color: luma.success,
        ),
        _Stat(
          label: 'Highest',
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

/// Shown for a listing that is not being watched. There is nothing to chart
/// yet by construction — history only starts accumulating once tracking
/// does — so this offers the one action that changes that, rather than an
/// empty axis with no explanation.
class _NotTracked extends StatelessWidget {
  const _NotTracked({this.onTrack});

  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_rounded, size: 26, color: luma.textMuted),
            const SizedBox(height: 10),
            Text(
              'No history yet',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Steam's market publishes no history of its own — track this "
              'listing and luma starts building one from here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (onTrack != null) ...[
              const SizedBox(height: 14),
              LumaPrimaryButton(
                label: 'Track this listing',
                icon: Icons.star_rounded,
                onTap: onTrack,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SingleReading extends StatelessWidget {
  const _SingleReading({required this.series});

  final Cs2PriceSeries series;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final cents = series.samples.first.priceCents;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline_rounded, size: 26, color: luma.textMuted),
          const SizedBox(height: 10),
          Text(
            formatSteamPrice(cents, series.currency),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One reading so far — a trend needs at least two.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

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
            'No readings in this range',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a wider range, or check the price again.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

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

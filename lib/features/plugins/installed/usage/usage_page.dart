import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'data/usage_database.dart';
import 'usage_repository.dart';
import 'usage_scope.dart';
import 'usage_stats.dart';

/// How many apps get their own pie slice / bar-stack colour before the rest
/// are folded into a single "Other" bucket.
const int _kTopAppLimit = 7;

const List<Color> _kPalette = [
  Color(0xFFB49DF5), // lavender
  Color(0xFF57D9A3), // mint
  Color(0xFFFF6B81), // coral
  Color(0xFFFFD166), // gold
  Color(0xFF6ECBF5), // sky
  Color(0xFFBC96E6), // purple
  Color(0xFF85E0C3), // seafoam
];

/// The Usage plugin: tracks the foreground app throughout the day and
/// visualizes it as pie / stacked-bar charts over a chosen time range.
class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  UsageRangePreset _preset = UsageRangePreset.today;
  DateTimeRange? _customRange;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    if (_preset == UsageRangePreset.custom) {
      final r = _customRange;
      if (r == null) return resolveUsageRange(UsageRangePreset.today, now);
      return (r.start, r.end.add(const Duration(days: 1)));
    }
    return resolveUsageRange(_preset, now);
  }

  Future<void> _selectPreset(UsageRangePreset preset) async {
    if (preset == UsageRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: now,
        initialDateRange: _customRange,
      );
      if (picked == null) return;
      setState(() {
        _preset = UsageRangePreset.custom;
        _customRange = picked;
      });
    } else {
      setState(() => _preset = preset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = UsageScope.of(context);

    if (!repo.supported) {
      return const LumaEmptyState(
        icon: Icons.desktop_windows_outlined,
        title: 'Windows only',
        subtitle:
            'Usage reads the foreground window, which luma can only do in the Windows desktop app.',
      );
    }

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!repo.loaded) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        final (start, end) = _range();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                repo: repo,
                preset: _preset,
                customRange: _customRange,
                onSelectPreset: _selectPreset,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamData<List<UsageSession>>(
                  stream: repo.watchRange(start, end),
                  builder: (context, sessions) =>
                      _UsageBody(sessions: sessions, start: start, end: end),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Top bar: range presets, live status, settings ──────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.repo,
    required this.preset,
    required this.customRange,
    required this.onSelectPreset,
  });

  final UsageRepository repo;
  final UsageRangePreset preset;
  final DateTimeRange? customRange;
  final ValueChanged<UsageRangePreset> onSelectPreset;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final current = repo.currentApp;
    final statusLabel = repo.paused
        ? 'Paused'
        : (current != null ? 'Tracking ${current.appName}' : 'Idle');
    final statusColor =
        repo.paused ? luma.textMuted : (current != null ? luma.success : luma.textMuted);

    return Row(
      children: [
        Flexible(
          child: LumaSegmentedTabs(
            tabs: [for (final p in UsageRangePreset.values) p.label],
            selectedIndex: preset.index,
            onSelect: (i) => onSelectPreset(UsageRangePreset.values[i]),
          ),
        ),
        if (preset == UsageRangePreset.custom && customRange != null) ...[
          const SizedBox(width: 12),
          Text(
            '${DateFormat('MMM d, y').format(customRange!.start)} '
            '– ${DateFormat('MMM d, y').format(customRange!.end)}',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(statusLabel,
                  style: TextStyle(color: luma.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Usage settings',
          icon: Icon(Icons.tune_rounded, color: luma.textSecondary),
          onPressed: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (_) => _UsageSettingsDialog(repo: repo),
          ),
        ),
      ],
    );
  }
}

// ─── Body: summary + charts + list, once sessions for the range arrive ─────

class _UsageBody extends StatelessWidget {
  const _UsageBody({
    required this.sessions,
    required this.start,
    required this.end,
  });

  final List<UsageSession> sessions;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final appTotals = aggregateByApp(sessions, start: start, end: end);

    if (appTotals.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.insights_outlined,
        title: 'No activity yet',
        subtitle: 'Usage will show up here once you use apps on this PC.',
      );
    }

    final dayBuckets = aggregateByDay(sessions, start: start, end: end);
    final totalSeconds = appTotals.fold<int>(0, (a, b) => a + b.seconds);
    final colorByProcess = <String, Color>{
      for (var i = 0; i < appTotals.length && i < _kTopAppLimit; i++)
        appTotals[i].processName: _kPalette[i % _kPalette.length],
    };
    const otherColor = Color(0xFF8A8A9A);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                  label: 'Total tracked',
                  value: formatUsageDuration(totalSeconds)),
              _SummaryChip(label: 'Apps used', value: '${appTotals.length}'),
              _SummaryChip(label: 'Top app', value: appTotals.first.appName),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final pie = LumaCard(
                child: SizedBox(
                  height: 280,
                  child: _AppPieChart(
                    appTotals: appTotals,
                    colorByProcess: colorByProcess,
                    otherColor: otherColor,
                    totalSeconds: totalSeconds,
                  ),
                ),
              );
              final bars = LumaCard(
                child: SizedBox(
                  height: 280,
                  child: dayBuckets.length <= 1
                      ? Center(
                          child: Text(
                            'Pick a wider range to see a daily breakdown',
                            style: TextStyle(color: luma.textMuted, fontSize: 13),
                          ),
                        )
                      : _DailyBarChart(
                          dayBuckets: dayBuckets,
                          colorByProcess: colorByProcess,
                          otherColor: otherColor,
                        ),
                ),
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  children: [pie, const SizedBox(height: 16), bars],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: pie),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: bars),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < appTotals.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _AppListRow(
                    total: appTotals[i],
                    totalSeconds: totalSeconds,
                    color: colorByProcess[appTotals[i].processName] ?? otherColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: luma.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
                color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Pie chart: share of total time by app ──────────────────────────────────

class _AppPieChart extends StatefulWidget {
  const _AppPieChart({
    required this.appTotals,
    required this.colorByProcess,
    required this.otherColor,
    required this.totalSeconds,
  });

  final List<AppUsageTotal> appTotals;
  final Map<String, Color> colorByProcess;
  final Color otherColor;
  final int totalSeconds;

  @override
  State<_AppPieChart> createState() => _AppPieChartState();
}

class _AppPieChartState extends State<_AppPieChart> {
  int? _touchedIndex;

  List<(String label, int seconds, Color color)> _slices() {
    final top = widget.appTotals.take(_kTopAppLimit).toList();
    final rest = widget.appTotals.skip(_kTopAppLimit);
    final otherSeconds = rest.fold<int>(0, (a, b) => a + b.seconds);
    return [
      for (final t in top)
        (t.appName, t.seconds, widget.colorByProcess[t.processName]!),
      if (otherSeconds > 0) ('Other', otherSeconds, widget.otherColor),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final slices = _slices();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex = response?.touchedSection?.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    color: slices[i].$3,
                    value: slices[i].$2.toDouble(),
                    title: '',
                    radius: _touchedIndex == i ? 58 : 50,
                    badgeWidget: _touchedIndex == i
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: luma.surfaceHover,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: luma.border),
                            ),
                            child: Text(
                              formatUsageDuration(slices[i].$2),
                              style: TextStyle(
                                  color: luma.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        : null,
                    badgePositionPercentageOffset: 1.2,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices) ...[
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: s.$3, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.$1,
                          style:
                              TextStyle(color: luma.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        widget.totalSeconds == 0
                            ? '0%'
                            : '${(s.$2 / widget.totalSeconds * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stacked bar chart: per-day breakdown ───────────────────────────────────

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({
    required this.dayBuckets,
    required this.colorByProcess,
    required this.otherColor,
  });

  final List<DayUsageBucket> dayBuckets;
  final Map<String, Color> colorByProcess;
  final Color otherColor;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final maxSeconds = dayBuckets
        .map((d) => d.totalSeconds)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final topY = maxSeconds == 0 ? 3600.0 : maxSeconds * 1.15;

    return BarChart(
      BarChartData(
        maxY: topY,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${DateFormat('MMM d').format(dayBuckets[groupIndex].day)}\n'
              '${formatUsageDuration(dayBuckets[groupIndex].totalSeconds)}',
              TextStyle(color: luma.textPrimary, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (dayBuckets.length / 8).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dayBuckets.length || value != idx.toDouble()) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('M/d').format(dayBuckets[idx].day),
                    style: TextStyle(color: luma.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) => Text(
                '${(value / 3600).toStringAsFixed(value >= 3600 ? 0 : 1)}h',
                style: TextStyle(color: luma.textMuted, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: luma.border.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < dayBuckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [_stackedRod(dayBuckets[i])],
            ),
        ],
      ),
    );
  }

  BarChartRodData _stackedRod(DayUsageBucket bucket) {
    final entries = bucket.secondsByApp.entries.toList()
      ..sort((a, b) {
        final ai = colorByProcess.containsKey(a.key) ? 0 : 1;
        final bi = colorByProcess.containsKey(b.key) ? 0 : 1;
        return ai != bi ? ai - bi : b.value.compareTo(a.value);
      });

    var cursor = 0.0;
    final stackItems = <BarChartRodStackItem>[];
    for (final entry in entries) {
      final color = colorByProcess[entry.key] ?? otherColor;
      final next = cursor + entry.value;
      stackItems.add(BarChartRodStackItem(cursor, next, color));
      cursor = next;
    }

    return BarChartRodData(
      toY: cursor,
      rodStackItems: stackItems,
      width: 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
  }
}

// ─── App list row ────────────────────────────────────────────────────────────

class _AppListRow extends StatelessWidget {
  const _AppListRow({
    required this.total,
    required this.totalSeconds,
    required this.color,
  });

  final AppUsageTotal total;
  final int totalSeconds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final share = totalSeconds == 0 ? 0.0 : total.seconds / totalSeconds;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            total.appName,
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1),
              minHeight: 6,
              backgroundColor: luma.background,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          child: Text(
            '${(share * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            formatUsageDuration(total.seconds),
            textAlign: TextAlign.right,
            style: TextStyle(
                color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ─── Settings dialog ─────────────────────────────────────────────────────────

class _UsageSettingsDialog extends StatelessWidget {
  const _UsageSettingsDialog({required this.repo});
  final UsageRepository repo;

  Future<void> _confirmClear(BuildContext context) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text('Clear all usage history?',
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'This deletes every tracked session and cannot be undone.',
          style: TextStyle(color: luma.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Clear', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.clearHistory();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text('Usage settings', style: TextStyle(color: luma.textPrimary)),
      content: ListenableBuilder(
        listenable: repo,
        builder: (context, _) => SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pause tracking',
                        style: TextStyle(color: luma.textPrimary, fontSize: 14)),
                  ),
                  Switch(
                    value: repo.paused,
                    onChanged: repo.setPaused,
                    activeTrackColor: luma.accent,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sample every ${repo.intervalSeconds}s',
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
              ),
              Slider(
                value: repo.intervalSeconds.toDouble(),
                min: kUsageMinIntervalSeconds.toDouble(),
                max: kUsageMaxIntervalSeconds.toDouble(),
                divisions: kUsageMaxIntervalSeconds - kUsageMinIntervalSeconds,
                activeColor: luma.accent,
                label: '${repo.intervalSeconds}s',
                onChanged: (v) => repo.setIntervalSeconds(v.round()),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _confirmClear(context),
                  icon: Icon(Icons.delete_outline_rounded, color: luma.danger, size: 18),
                  label: Text('Clear all history',
                      style: TextStyle(color: luma.danger)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done', style: TextStyle(color: luma.accent)),
        ),
      ],
    );
  }
}

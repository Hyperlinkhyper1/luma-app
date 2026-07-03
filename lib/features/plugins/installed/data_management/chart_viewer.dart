import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'data_management_repository.dart';

/// Tries hard to read a date out of a free-text cell: ISO first, then the
/// common European day-first forms (dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy).
DateTime? parseFlexibleDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})$').firstMatch(s);
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  var year = int.parse(m.group(3)!);
  if (year < 100) year += 2000;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// How the y-values inside one group get collapsed to a single number.
enum ChartAggregation {
  sum('Sum'),
  average('Average'),
  count('Count'),
  min('Min'),
  maxAgg('Max');

  const ChartAggregation(this.label);
  final String label;
}

/// Quick time-range presets applied against the chosen date column.
enum ChartDateRange {
  all('All time'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  last90('Last 90 days'),
  thisMonth('This month'),
  thisYear('This year'),
  custom('Custom…');

  const ChartDateRange(this.label);
  final String label;
}

enum ChartSort {
  valueDesc('Value ↓'),
  valueAsc('Value ↑'),
  labelAsc('Label A-Z');

  const ChartSort(this.label);
  final String label;
}

/// Renders interactive charts from a dataset's rows and columns, with
/// grouping (by any column or by tags), aggregation, date filtering,
/// sorting and top-N limiting.
class ChartViewer extends StatefulWidget {
  const ChartViewer({
    super.key,
    required this.dataset,
    required this.rows,
  });

  final DatasetRecord dataset;
  final List<DataRowRecord> rows;

  @override
  State<ChartViewer> createState() => _ChartViewerState();
}

/// Sentinel "column index" meaning "group rows by their tags".
const int kGroupByTags = -1;

class _ChartViewerState extends State<ChartViewer> {
  String _chartType = 'bar'; // 'bar', 'line', 'area', 'pie', 'donut'
  int _groupByIndex = 0; // column index, or kGroupByTags
  int _yColumnIndex = 1;
  ChartAggregation _aggregation = ChartAggregation.sum;
  ChartSort _sort = ChartSort.valueDesc;
  int _topN = 0; // 0 = all
  int? _dateColumnIndex;
  ChartDateRange _dateRange = ChartDateRange.all;
  DateTimeRange? _customRange;

  static const _chartTypes = [
    ('bar', 'Bar', Icons.bar_chart_rounded),
    ('line', 'Line', Icons.show_chart_rounded),
    ('area', 'Area', Icons.area_chart_rounded),
    ('pie', 'Pie', Icons.pie_chart_rounded),
    ('donut', 'Donut', Icons.donut_large_rounded),
  ];

  List<int> get _numericColumnIndexes => [
        for (var i = 0; i < widget.dataset.columns.length; i++)
          if (widget.dataset.columns[i].type == 'number') i
      ];

  List<int> get _dateColumnIndexes => [
        for (var i = 0; i < widget.dataset.columns.length; i++)
          if (widget.dataset.columns[i].type == 'date') i
      ];

  @override
  void initState() {
    super.initState();
    _pickDefaults();
  }

  @override
  void didUpdateWidget(ChartViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Columns may have been renamed/removed since the last build.
    final colCount = widget.dataset.columns.length;
    if (_groupByIndex != kGroupByTags && _groupByIndex >= colCount) _pickDefaults();
    if (_yColumnIndex >= colCount) _pickDefaults();
    if (_dateColumnIndex != null && _dateColumnIndex! >= colCount) {
      _dateColumnIndex = null;
    }
  }

  void _pickDefaults() {
    final numeric = _numericColumnIndexes;
    final texts = [
      for (var i = 0; i < widget.dataset.columns.length; i++)
        if (widget.dataset.columns[i].type != 'number') i
    ];
    _groupByIndex = widget.dataset.tags.isNotEmpty
        ? kGroupByTags
        : (texts.isNotEmpty ? texts.first : 0);
    _yColumnIndex = numeric.isNotEmpty ? numeric.first : 0;
    final dates = _dateColumnIndexes;
    _dateColumnIndex = dates.isNotEmpty ? dates.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final numericCols = _numericColumnIndexes;
    final needsValueColumn = _aggregation != ChartAggregation.count;

    if (widget.dataset.columns.isEmpty ||
        (needsValueColumn && numericCols.isEmpty)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_chart_outlined, color: luma.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'Add a numeric column to chart values,\nor switch aggregation to "Count".',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final chartData = _buildChartData();
    final total = chartData.fold<double>(0, (a, p) => a + p.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // Chart type selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (type, label, icon) in _chartTypes)
                _ChartTypeChip(
                  label: label,
                  icon: icon,
                  selected: _chartType == type,
                  onTap: () => setState(() => _chartType = type),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Option selectors
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OptionDropdown<int>(
                label: 'Group by',
                value: _groupByIndex,
                options: [
                  if (widget.dataset.tags.isNotEmpty)
                    (kGroupByTags, 'Tags'),
                  for (var i = 0; i < widget.dataset.columns.length; i++)
                    (i, widget.dataset.columns[i].name),
                ],
                onChanged: (v) => setState(() => _groupByIndex = v),
              ),
              _OptionDropdown<ChartAggregation>(
                label: 'Aggregation',
                value: _aggregation,
                options: [
                  for (final a in ChartAggregation.values) (a, a.label),
                ],
                onChanged: (v) => setState(() => _aggregation = v),
              ),
              if (needsValueColumn)
                _OptionDropdown<int>(
                  label: 'Value',
                  value: numericCols.contains(_yColumnIndex)
                      ? _yColumnIndex
                      : numericCols.first,
                  options: [
                    for (final i in numericCols)
                      (i, widget.dataset.columns[i].name),
                  ],
                  onChanged: (v) => setState(() => _yColumnIndex = v),
                ),
              _OptionDropdown<ChartSort>(
                label: 'Sort',
                value: _sort,
                options: [for (final s in ChartSort.values) (s, s.label)],
                onChanged: (v) => setState(() => _sort = v),
              ),
              _OptionDropdown<int>(
                label: 'Show',
                value: _topN,
                options: const [
                  (0, 'All'),
                  (5, 'Top 5'),
                  (10, 'Top 10'),
                  (20, 'Top 20'),
                ],
                onChanged: (v) => setState(() => _topN = v),
              ),
              if (_dateColumnIndexes.isNotEmpty) ...[
                _OptionDropdown<int>(
                  label: 'Date column',
                  value: _dateColumnIndex ?? _dateColumnIndexes.first,
                  options: [
                    for (final i in _dateColumnIndexes)
                      (i, widget.dataset.columns[i].name),
                  ],
                  onChanged: (v) => setState(() => _dateColumnIndex = v),
                ),
                _OptionDropdown<ChartDateRange>(
                  label: 'Period',
                  value: _dateRange,
                  options: [
                    for (final r in ChartDateRange.values) (r, r.label),
                  ],
                  onChanged: (v) async {
                    if (v == ChartDateRange.custom) {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: _customRange,
                      );
                      if (picked != null) {
                        setState(() {
                          _dateRange = ChartDateRange.custom;
                          _customRange = picked;
                        });
                      }
                    } else {
                      setState(() => _dateRange = v);
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (chartData.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Text('No data matches the current filters',
                    style: TextStyle(color: luma.textMuted)),
              ),
            )
          else ...[
            // Summary chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                    label: 'Total', value: _fmt(total), luma: luma),
                _SummaryChip(
                    label: 'Groups',
                    value: '${chartData.length}',
                    luma: luma),
                _SummaryChip(
                    label: 'Top',
                    value: chartData
                        .reduce((a, b) => a.value >= b.value ? a : b)
                        .label,
                    luma: luma),
                _SummaryChip(
                    label: 'Average',
                    value: _fmt(total / chartData.length),
                    luma: luma),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 340,
              child: (_chartType == 'pie' || _chartType == 'donut')
                  ? _PieChartView(
                      data: chartData,
                      luma: luma,
                      donut: _chartType == 'donut',
                    )
                  : _CartesianChart(
                      type: _chartType,
                      data: chartData,
                      luma: luma,
                      title: _chartTitle(),
                    ),
            ),
          ],
      ],
    );
  }

  String _chartTitle() {
    final agg = _aggregation.label;
    final value = _aggregation == ChartAggregation.count
        ? 'rows'
        : widget.dataset.columns[_yColumnIndex].name;
    final group = _groupByIndex == kGroupByTags
        ? 'tag'
        : widget.dataset.columns[_groupByIndex].name;
    return '$agg of $value by $group';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  (DateTime, DateTime)? _activeRange() {
    final now = DateTime.now();
    switch (_dateRange) {
      case ChartDateRange.all:
        return null;
      case ChartDateRange.last7:
        return (now.subtract(const Duration(days: 7)), now);
      case ChartDateRange.last30:
        return (now.subtract(const Duration(days: 30)), now);
      case ChartDateRange.last90:
        return (now.subtract(const Duration(days: 90)), now);
      case ChartDateRange.thisMonth:
        return (DateTime(now.year, now.month, 1), now);
      case ChartDateRange.thisYear:
        return (DateTime(now.year, 1, 1), now);
      case ChartDateRange.custom:
        final r = _customRange;
        if (r == null) return null;
        return (r.start, r.end.add(const Duration(days: 1)));
    }
  }

  List<ChartPoint> _buildChartData() {
    // 1. Date filter
    var rows = widget.rows;
    final range = _activeRange();
    final dateCol = _dateColumnIndex;
    if (range != null && dateCol != null) {
      rows = [
        for (final row in rows)
          if (_inRange(parseFlexibleDate(row.valueAt(dateCol)), range)) row,
      ];
    }

    // 2. Group
    final groups = <String, List<double>>{};
    final colors = <String, Color?>{};
    double yOf(DataRowRecord row) =>
        double.tryParse(row.valueAt(_yColumnIndex).replaceAll(',', '.')) ?? 0;

    if (_groupByIndex == kGroupByTags) {
      for (final row in rows) {
        final tags = row.tags.isEmpty ? const ['Untagged'] : row.tags;
        for (final tag in tags) {
          groups.putIfAbsent(tag, () => []).add(yOf(row));
          colors[tag] ??= widget.dataset.tagByName(tag) != null
              ? Color(widget.dataset.tagByName(tag)!.colorValue)
              : null;
        }
      }
    } else {
      for (final row in rows) {
        final key = row.valueAt(_groupByIndex).trim();
        final label = key.isEmpty ? '(empty)' : key;
        groups.putIfAbsent(label, () => []).add(yOf(row));
      }
    }

    // 3. Aggregate
    var points = <ChartPoint>[
      for (final entry in groups.entries)
        ChartPoint(
          label: entry.key,
          value: _aggregate(entry.value),
          color: colors[entry.key],
        ),
    ];

    // 4. Sort
    switch (_sort) {
      case ChartSort.valueDesc:
        points.sort((a, b) => b.value.compareTo(a.value));
      case ChartSort.valueAsc:
        points.sort((a, b) => a.value.compareTo(b.value));
      case ChartSort.labelAsc:
        points.sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    }

    // 5. Top N with an "Other" bucket
    if (_topN > 0 && points.length > _topN) {
      final kept = points.take(_topN).toList();
      final rest = points.skip(_topN);
      final otherTotal = rest.fold<double>(0, (a, p) => a + p.value);
      if (otherTotal != 0) {
        kept.add(ChartPoint(label: 'Other', value: otherTotal));
      }
      points = kept;
    }
    return points;
  }

  static bool _inRange(DateTime? d, (DateTime, DateTime) range) =>
      d != null && !d.isBefore(range.$1) && d.isBefore(range.$2);

  double _aggregate(List<double> values) {
    if (values.isEmpty) return 0;
    switch (_aggregation) {
      case ChartAggregation.sum:
        return values.fold(0, (a, b) => a + b);
      case ChartAggregation.average:
        return values.fold<double>(0, (a, b) => a + b) / values.length;
      case ChartAggregation.count:
        return values.length.toDouble();
      case ChartAggregation.min:
        return values.reduce((a, b) => a < b ? a : b);
      case ChartAggregation.maxAgg:
        return values.reduce((a, b) => a > b ? a : b);
    }
  }
}

class ChartPoint {
  const ChartPoint({required this.label, required this.value, this.color});
  final String label;
  final double value;
  final Color? color;
}

// ─── Chart Type Chip ─────────────────────────────────────────────────────────

class _ChartTypeChip extends StatefulWidget {
  const _ChartTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ChartTypeChip> createState() => _ChartTypeChipState();
}

class _ChartTypeChipState extends State<_ChartTypeChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? luma.accentSubtle
                : (_hover ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected ? luma.accent : luma.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected ? luma.accent : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Option Dropdown ─────────────────────────────────────────────────────────

class _OptionDropdown<T> extends StatelessWidget {
  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: luma.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: options.any((o) => o.$1 == value)
                    ? value
                    : options.first.$1,
                dropdownColor: luma.surface,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                icon: Icon(Icons.arrow_drop_down, color: luma.textMuted),
                items: [
                  for (final (v, name) in options)
                    DropdownMenuItem(
                      value: v,
                      child: Text(name,
                          style: TextStyle(color: luma.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Chip ────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.label, required this.value, required this.luma});
  final String label;
  final String value;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: TextStyle(color: luma.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Cartesian Chart (Bar / Line / Area) ─────────────────────────────────────

class _CartesianChart extends StatelessWidget {
  const _CartesianChart({
    required this.type,
    required this.data,
    required this.luma,
    required this.title,
  });

  final String type;
  final List<ChartPoint> data;
  final LumaPalette luma;
  final String title;

  @override
  Widget build(BuildContext context) {
    final maxY =
        data.map((d) => d.value).fold<double>(0, (a, b) => max(a, b).toDouble());
    final minY =
        data.map((d) => d.value).fold<double>(0, (a, b) => a < b ? a : b);
    final topY = maxY == 0 ? 10.0 : maxY * 1.15;
    final bottomY = minY < 0 ? minY * 1.15 : 0.0;

    Widget chart;
    if (type == 'bar') {
      chart = BarChart(
        BarChartData(
          maxY: topY,
          minY: bottomY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${data[groupIndex].label}\n${rod.toY.toStringAsFixed(2)}',
                  TextStyle(color: luma.textPrimary, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: _titles(),
          gridData: _grid(),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].value,
                    color: data[i].color ?? luma.accent,
                    width: 20,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              ),
          ],
        ),
      );
    } else {
      final spots = [
        for (var i = 0; i < data.length; i++)
          FlSpot(i.toDouble(), data[i].value),
      ];
      chart = LineChart(
        LineChartData(
          maxY: topY,
          minY: bottomY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    '${data[s.x.toInt()].label}\n${s.y.toStringAsFixed(2)}',
                    TextStyle(color: luma.textPrimary, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: _titles(),
          gridData: _grid(),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: luma.accent,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: luma.accent,
                  strokeWidth: 2,
                  strokeColor: luma.surface,
                ),
              ),
              belowBarData: type == 'area'
                  ? BarAreaData(
                      show: true,
                      color: luma.accent.withValues(alpha: 0.15),
                    )
                  : BarAreaData(show: false),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: chart),
      ],
    );
  }

  FlTitlesData _titles() => FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= data.length || value != idx.toDouble()) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  data[idx].label,
                  style: TextStyle(color: luma.textMuted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(0),
                style: TextStyle(color: luma.textMuted, fontSize: 10),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  FlGridData _grid() => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: luma.border.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      );
}

// ─── Pie / Donut Chart ───────────────────────────────────────────────────────

class _PieChartView extends StatefulWidget {
  const _PieChartView(
      {required this.data, required this.luma, required this.donut});
  final List<ChartPoint> data;
  final LumaPalette luma;
  final bool donut;

  @override
  State<_PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<_PieChartView> {
  int? _touchedIndex;

  static const _palette = [
    Color(0xFFB49DF5), // lavender
    Color(0xFF57D9A3), // mint
    Color(0xFFFF6B81), // coral
    Color(0xFFFFD166), // gold
    Color(0xFF6ECBF5), // sky
    Color(0xFFBC96E6), // purple
    Color(0xFF85E0C3), // seafoam
    Color(0xFFFF9E6D), // peach
    Color(0xFFE58FB1), // rose
    Color(0xFF9BD770), // leaf
  ];

  Color _colorFor(int i) => widget.data[i].color ?? _palette[i % _palette.length];

  @override
  Widget build(BuildContext context) {
    final total =
        widget.data.map((d) => d.value).fold<double>(0, (a, b) => a + b);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        response?.touchedSection?.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: widget.donut ? 70 : 40,
              sections: [
                for (var i = 0; i < widget.data.length; i++)
                  PieChartSectionData(
                    color: _colorFor(i),
                    value: widget.data[i].value.abs(),
                    title: '',
                    radius: _touchedIndex == i
                        ? (widget.donut ? 46 : 60)
                        : (widget.donut ? 38 : 50),
                    badgeWidget: _touchedIndex == i
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.luma.surfaceHover,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: widget.luma.border),
                            ),
                            child: Text(
                              widget.data[i].value.toStringAsFixed(1),
                              style: TextStyle(
                                color: widget.luma.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
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
                for (var i = 0; i < widget.data.length; i++) ...[
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _colorFor(i),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.data[i].label,
                          style: TextStyle(
                              color: widget.luma.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        widget.data[i].value.toStringAsFixed(1),
                        style: TextStyle(
                            color: widget.luma.textMuted, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${total == 0 ? 0 : (widget.data[i].value / total * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: widget.luma.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'data_management_repository.dart';

/// Renders interactive charts from a dataset's rows and columns.
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

class _ChartViewerState extends State<ChartViewer> {
  String _chartType = 'bar'; // 'bar', 'line', 'pie', 'area'
  int _xColumnIndex = 0;
  int _yColumnIndex = 1;

  static const _chartTypes = [
    ('bar', 'Bar', Icons.bar_chart_rounded),
    ('line', 'Line', Icons.show_chart_rounded),
    ('area', 'Area', Icons.area_chart_rounded),
    ('pie', 'Pie', Icons.pie_chart_rounded),
  ];

  List<int> get _numericColumnIndexes => [
        for (var i = 0; i < widget.dataset.columns.length; i++)
          if (widget.dataset.columns[i].type == 'number') i
      ];

  List<int> get _textColumnIndexes => [
        for (var i = 0; i < widget.dataset.columns.length; i++)
          if (widget.dataset.columns[i].type == 'text') i
      ];

  @override
  void initState() {
    super.initState();
    // Pick sensible defaults
    final numeric = _numericColumnIndexes;
    final text = _textColumnIndexes;
    if (text.isNotEmpty) _xColumnIndex = text.first;
    if (numeric.isNotEmpty) _yColumnIndex = numeric.first;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final numericCols = _numericColumnIndexes;

    if (widget.dataset.columns.length < 2 || numericCols.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_chart_outlined, color: luma.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'Need at least 2 columns\nand 1 numeric column for charts',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final chartData = _buildChartData();
    if (chartData.isEmpty) {
      return Center(
        child: Text('No data to chart', style: TextStyle(color: luma.textMuted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chart type selector
        Wrap(
          spacing: 8,
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
        // Column selectors
        Row(
          children: [
            Expanded(
              child: _ColumnSelector(
                label: 'X-axis',
                value: _xColumnIndex,
                options: [
                  for (var i = 0; i < widget.dataset.columns.length; i++)
                    (i, widget.dataset.columns[i].name),
                ],
                onChanged: (v) => setState(() => _xColumnIndex = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ColumnSelector(
                label: 'Y-axis',
                value: _yColumnIndex,
                options: [
                  for (final i in numericCols)
                    (i, widget.dataset.columns[i].name),
                ],
                onChanged: (v) => setState(() => _yColumnIndex = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Chart
        Expanded(
          child: _chartType == 'pie'
              ? _PieChart(data: chartData, luma: luma)
              : _CartesianChart(
                  type: _chartType,
                  data: chartData,
                  luma: luma,
                  xLabel: widget.dataset.columns[_xColumnIndex].name,
                  yLabel: widget.dataset.columns[_yColumnIndex].name,
                ),
        ),
      ],
    );
  }

  List<_ChartPoint> _buildChartData() {
    final points = <_ChartPoint>[];
    for (final row in widget.rows) {
      final xVal = row.valueAt(_xColumnIndex);
      final yStr = row.valueAt(_yColumnIndex);
      final yVal = double.tryParse(yStr.replaceAll(',', '.')) ?? 0;
      if (xVal.isNotEmpty) {
        points.add(_ChartPoint(label: xVal, value: yVal));
      }
    }
    return points;
  }
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.value});
  final String label;
  final double value;
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

// ─── Column Selector ─────────────────────────────────────────────────────────

class _ColumnSelector extends StatelessWidget {
  const _ColumnSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<(int, String)> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: luma.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
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
            child: DropdownButton<int>(
              isExpanded: true,
              value: value,
              dropdownColor: luma.surface,
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
              icon: Icon(Icons.arrow_drop_down, color: luma.textMuted),
              items: [
                for (final (idx, name) in options)
                  DropdownMenuItem(
                    value: idx,
                    child: Text(name, style: TextStyle(color: luma.textPrimary)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Cartesian Chart (Bar / Line / Area) ─────────────────────────────────────

class _CartesianChart extends StatelessWidget {
  const _CartesianChart({
    required this.type,
    required this.data,
    required this.luma,
    required this.xLabel,
    required this.yLabel,
  });

  final String type;
  final List<_ChartPoint> data;
  final LumaPalette luma;
  final String xLabel;
  final String yLabel;

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((d) => d.value).fold<double>(0, (a, b) => max(a, b).toDouble());
    final double topY = maxY == 0 ? 10 : maxY * 1.15;

    Widget chart;
    if (type == 'bar') {
      chart = BarChart(
        BarChartData(
          maxY: topY,
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
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
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
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: luma.border.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].value,
                    color: luma.accent,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              ),
          ],
        ),
      );
    } else {
      // Line or Area
      final spots = [
        for (var i = 0; i < data.length; i++)
          FlSpot(i.toDouble(), data[i].value),
      ];
      chart = LineChart(
        LineChartData(
          maxY: topY,
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
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
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
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: luma.border.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: luma.accent,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
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
            '$yLabel vs $xLabel',
            style: TextStyle(color: luma.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: chart),
      ],
    );
  }
}

// ─── Pie Chart ───────────────────────────────────────────────────────────────

class _PieChart extends StatefulWidget {
  const _PieChart({required this.data, required this.luma});
  final List<_ChartPoint> data;
  final LumaPalette luma;

  @override
  State<_PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<_PieChart> {
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
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.data.map((d) => d.value).fold<double>(0, (a, b) => a + b);

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
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < widget.data.length; i++)
                  PieChartSectionData(
                    color: _palette[i % _palette.length],
                    value: widget.data[i].value,
                    title: '',
                    radius: _touchedIndex == i ? 60 : 50,
                    badgeWidget: _touchedIndex == i
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.data[i].label,
                          style: TextStyle(color: widget.luma.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../data/database.dart';

class CategorySpendingChart extends StatelessWidget {
  const CategorySpendingChart({
    super.key,
    required this.txns,
    required this.categories,
  });

  final List<FinanceTransaction> txns;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final byCategory = <int?, int>{};
    var total = 0;
    for (final t in txns) {
      if (t.kind != TxnKind.expense) continue;
      if (t.date.isBefore(monthStart)) continue;
      byCategory[t.categoryId] =
          (byCategory[t.categoryId] ?? 0) + t.amountCents;
      total += t.amountCents;
    }

    if (total == 0) {
      return const _EmptyGraph(message: 'No expenses this month');
    }

    final catById = {for (final c in categories) c.id: c};
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.take(5).toList();

    final otherSum = entries.skip(5).fold<int>(0, (sum, e) => sum + e.value);
    if (otherSum > 0) {
      topEntries.add(MapEntry(null, otherSum)); // null means 'Other'
    }

    return SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The ring's outer diameter must not exceed the shorter of the
          // box's two dimensions, otherwise it gets clipped by the card —
          // deriving the radii from the actual available space (instead of
          // hard-coding them) keeps the donut fully visible at any size.
          final outerRadius = constraints.biggest.shortestSide / 2;
          final centerSpaceRadius = outerRadius * 0.45;
          final sectionRadius = outerRadius - centerSpaceRadius;
          return PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: centerSpaceRadius,
              sections: topEntries.map((e) {
                final cat = e.key != null ? catById[e.key] : null;
                final color = cat != null
                    ? Color(cat.colorValue)
                    : luma.textMuted;
                final value = e.value.toDouble();
                final percentage = (e.value / total * 100).toStringAsFixed(1);
                return PieChartSectionData(
                  color: color,
                  value: value,
                  title: '$percentage%',
                  radius: sectionRadius,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class IncomeVsExpenseChart extends StatelessWidget {
  const IncomeVsExpenseChart({super.key, required this.txns});

  final List<FinanceTransaction> txns;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final now = DateTime.now();

    // Last 6 months
    final data = <DateTime, _IncExp>{};
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      data[DateTime(d.year, d.month, 1)] = _IncExp(0, 0);
    }

    for (final t in txns) {
      final month = DateTime(t.date.year, t.date.month, 1);
      if (data.containsKey(month)) {
        if (t.kind == TxnKind.income) {
          data[month]!.income += t.amountCents;
        } else if (t.kind == TxnKind.expense) {
          data[month]!.expense += t.amountCents;
        }
      }
    }

    final months = data.keys.toList()..sort();
    var maxY = 1.0;
    for (final v in data.values) {
      if (v.income > maxY) maxY = v.income.toDouble();
      if (v.expense > maxY) maxY = v.expense.toDouble();
    }

    // Add 10% padding
    maxY = maxY * 1.1;

    return SizedBox(
      height: 120,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= months.length) {
                    return const SizedBox();
                  }
                  final month = months[index];
                  const m = [
                    'J',
                    'F',
                    'M',
                    'A',
                    'M',
                    'J',
                    'J',
                    'A',
                    'S',
                    'O',
                    'N',
                    'D',
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      m[month.month - 1],
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).clamp(1.0, double.infinity),
            getDrawingHorizontalLine: (value) =>
                FlLine(color: luma.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: months.asMap().entries.map((e) {
            final val = data[e.value]!;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: val.income.toDouble(),
                  color: luma.success,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: val.expense.toDouble(),
                  color: luma.danger,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _IncExp {
  _IncExp(this.income, this.expense);
  int income;
  int expense;
}

class NetWorthChart extends StatelessWidget {
  const NetWorthChart({super.key, required this.snapshots});

  /// Real daily net-worth history (see
  /// FinanceRepository.recordDailyNetWorthSnapshot), oldest first — not a
  /// reconstruction from the ledger, so it only has as much history as the
  /// app has actually been opened on since this feature shipped.
  final List<BalanceSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (snapshots.length < 2) {
      return const _EmptyGraph(
        message: 'Come back tomorrow to start seeing your net worth trend.',
      );
    }

    final points = [
      for (var i = 0; i < snapshots.length; i++)
        FlSpot(i.toDouble(), snapshots[i].totalCents.toDouble()),
    ];

    var minY = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    var maxY = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);

    if (minY == maxY) {
      minY -= 10000;
      maxY += 10000;
    } else {
      final diff = maxY - minY;
      minY -= diff * 0.1;
      maxY += diff * 0.1;
    }

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: luma.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: luma.accent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: luma.accent.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGraph extends StatelessWidget {
  const _EmptyGraph({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: context.luma.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

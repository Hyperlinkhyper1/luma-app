import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../logic/money.dart';
import '../logic/planning.dart';
import 'finance_form.dart';
import 'lookups.dart';

/// This month's spending against each category budget, with a button to set
/// the budgets.
class BudgetsCard extends StatelessWidget {
  const BudgetsCard({
    super.key,
    required this.repo,
    required this.categories,
    required this.txns,
    required this.now,
  });

  final FinanceRepository repo;
  final List<Category> categories;
  final List<FinanceTransaction> txns;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final usage = budgetUsage(categories: categories, txns: txns, month: now);
    final totalBudget = usage.fold<int>(0, (s, u) => s + u.budgetCents);
    final totalSpent = usage.fold<int>(0, (s, u) => s + u.spentCents);

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  usage.isEmpty
                      ? 'No budgets yet'
                      : '${formatCents(totalSpent)} of ${formatCents(totalBudget)} · ${monthYear(now)}',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: () => showFinanceDialog<void>(
                  context,
                  _BudgetEditor(repo: repo, categories: categories),
                  maxWidth: 480,
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(usage.isEmpty ? 'Set budgets' : 'Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: luma.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          if (usage.isEmpty)
            Text(
              'Give categories a monthly limit and see how close you are.',
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          else ...[
            const SizedBox(height: 8),
            for (final u in usage) ...[
              _BudgetRow(usage: u),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.usage});
  final BudgetUsage usage;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final c = usage.category;
    final barColor = usage.isOver
        ? luma.danger
        : usage.isNear
        ? luma.warning
        : Color(c.colorValue);
    final status = usage.isOver
        ? '${formatCents(-usage.remainingCents)} over'
        : '${formatCents(usage.remainingCents)} left';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              materialIcon(c.iconCodepoint),
              size: 16,
              color: Color(c.colorValue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
              ),
            ),
            Text(
              '${formatCents(usage.spentCents)} / ${formatCents(usage.budgetCents)}',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: usage.fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            color: usage.isOver ? luma.danger : luma.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({required this.repo, required this.categories});
  final FinanceRepository repo;
  final List<Category> categories;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late final Map<int, TextEditingController> _fields = {
    for (final c in widget.categories)
      c.id: TextEditingController(
        text: c.monthlyBudgetCents == null
            ? ''
            : (c.monthlyBudgetCents! / 100)
                  .toStringAsFixed(2)
                  .replaceAll('.', ','),
      ),
  };
  String? _error;

  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final budgets = <int, int?>{};
    for (final e in _fields.entries) {
      final text = e.value.text.trim();
      if (text.isEmpty) {
        budgets[e.key] = null;
        continue;
      }
      final cents = parseToCents(text);
      if (cents == null || cents < 0) {
        final name = widget.categories.firstWhere((c) => c.id == e.key).name;
        setState(() => _error = '"$text" for $name isn\'t an amount.');
        return;
      }
      budgets[e.key] = cents;
    }
    await widget.repo.setCategoryBudgets(budgets);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return FinanceDialogScaffold(
      title: 'Monthly budgets',
      confirmLabel: 'Save',
      onConfirm: _save,
      error: _error,
      children: [
        Text(
          'Leave a category empty for no limit.',
          style: TextStyle(color: luma.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final c in widget.categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                LumaIconBadge(
                  icon: materialIcon(c.iconCodepoint),
                  color: Color(c.colorValue),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textPrimary),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _fields[c.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: luma.textPrimary),
                    decoration: financeInputDecoration(
                      luma,
                      hint: 'No limit',
                      prefix: '€ ',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The main balance projected 30 or 90 days ahead from recurring rules and
/// allocations, with a warning if it's heading below zero.
class CashFlowForecastCard extends StatefulWidget {
  const CashFlowForecastCard({
    super.key,
    required this.mainCents,
    required this.recurring,
    required this.allocations,
    required this.now,
  });

  final int mainCents;
  final List<RecurringRule> recurring;
  final List<AllocationRule> allocations;
  final DateTime now;

  @override
  State<CashFlowForecastCard> createState() => _CashFlowForecastCardState();
}

class _CashFlowForecastCardState extends State<CashFlowForecastCard> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final f = forecastMainBalance(
      startCents: widget.mainCents,
      now: widget.now,
      recurring: widget.recurring,
      allocations: widget.allocations,
      days: _days,
    );
    final negative = f.firstNegativeDate;
    final change = f.endCents - widget.mainCents;
    final upcoming = f.events.take(4).toList();

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available in $_days days',
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(
                          formatCents(f.endCents),
                          style: TextStyle(
                            color: f.endCents < 0
                                ? luma.danger
                                : luma.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatSignedCents(change),
                          style: TextStyle(
                            color: change >= 0 ? luma.success : luma.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              LumaSegmentedTabs(
                tabs: const ['30d', '90d'],
                selectedIndex: _days == 30 ? 0 : 1,
                onSelect: (i) => setState(() => _days = i == 0 ? 30 : 90),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 110, child: _ForecastChart(forecast: f)),
          const SizedBox(height: 12),
          if (negative != null)
            _Notice(
              icon: Icons.warning_amber_rounded,
              color: luma.danger,
              text:
                  'Heading below €0 on ${shortDate(negative)} — lowest ${formatCents(f.lowestCents)} on ${shortDate(f.lowestDate)}.',
            )
          else
            Text(
              'Lowest point ${formatCents(f.lowestCents)} on ${shortDate(f.lowestDate)}.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in upcoming)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        shortDate(e.date),
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      formatSignedCents(e.deltaCents),
                      style: TextStyle(
                        color: e.deltaCents >= 0
                            ? luma.success
                            : luma.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Nothing scheduled — add fixed costs and income in the Recurring tab.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.forecast});
  final CashFlowForecast forecast;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final values = forecast.dailyCents;
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i] / 100),
    ];
    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (minY > 0) minY = 0;
    if (maxY == minY) maxY = minY + 100;
    final pad = (maxY - minY) * 0.1;
    final goesNegative = forecast.lowestCents < 0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY - (goesNegative ? pad : 0),
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: luma.border,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => luma.surface,
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  '${shortDate(forecast.start.add(Duration(days: t.x.round())))}\n${formatCents(values[t.x.round()])}',
                  TextStyle(color: luma.textPrimary, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            isStepLineChart: true,
            color: goesNegative ? luma.danger : luma.accent,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: (goesNegative ? luma.danger : luma.accent).withValues(
                alpha: 0.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.luma.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// A slim goal bar for a pot: progress, target and the monthly top-up.
class PotGoalBar extends StatelessWidget {
  const PotGoalBar({
    super.key,
    required this.progress,
    required this.color,
    required this.now,
    this.compact = false,
  });

  final GoalProgress progress;
  final Color color;
  final DateTime now;

  /// Only the bar and the percentage (for the overview chips).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final p = progress;
    final pct = '${(p.fraction * 100).floor()}%';
    final String detail;
    Color detailColor = luma.textMuted;
    if (p.reached) {
      detail = 'Goal reached';
      detailColor = luma.success;
    } else if (p.isOverdue(now)) {
      detail =
          '${formatCents(p.remainingCents)} short · was due ${shortDate(p.goalDate!)}';
      detailColor = luma.danger;
    } else if (p.monthlyNeededCents != null) {
      detail =
          '${formatCents(p.monthlyNeededCents!)}/month until ${monthYear(p.goalDate!)}';
    } else {
      detail = '${formatCents(p.remainingCents)} to go';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Goal ${formatCents(p.goalCents)}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
              Text(
                pct,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        if (!compact) const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.fraction,
            minHeight: compact ? 4 : 6,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(
              p.reached ? luma.success : color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          compact ? '$pct of ${formatCents(p.goalCents)}' : detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: compact ? luma.textMuted : detailColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

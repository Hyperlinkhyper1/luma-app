import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_scope.dart';
import '../logic/finance_logic.dart';
import '../logic/money.dart';
import 'lookups.dart';
import 'overview_graphs.dart';

/// The total overview: net worth, this month's flows, pots, weekly spending
/// review, investments and upcoming recurring entries.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Pot>>(
      stream: repo.watchPots(),
      builder: (context, pots) => StreamData<List<Category>>(
        stream: repo.watchCategories(),
        builder: (context, categories) => StreamData<List<Holding>>(
          stream: repo.watchHoldings(),
          builder: (context, holdings) => StreamData<List<RecurringRule>>(
            stream: repo.watchRecurring(),
            builder: (context, recurring) => StreamData<List<FinanceTransaction>>(
              stream: repo.watchTransactions(),
              builder: (context, txns) => StreamData<List<OverviewGraph>>(
                stream: repo.watchOverviewGraphs(),
                builder: (context, graphs) => _OverviewBody(
                  pots: pots,
                  categories: categories,
                  holdings: holdings,
                  recurring: recurring,
                  txns: txns,
                  graphs: graphs,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewBody extends StatefulWidget {
  const _OverviewBody({
    required this.pots,
    required this.categories,
    required this.holdings,
    required this.recurring,
    required this.txns,
    required this.graphs,
  });

  final List<Pot> pots;
  final List<Category> categories;
  final List<Holding> holdings;
  final List<RecurringRule> recurring;
  final List<FinanceTransaction> txns;
  final List<OverviewGraph> graphs;

  @override
  State<_OverviewBody> createState() => _OverviewBodyState();
}

class _OverviewBodyState extends State<_OverviewBody> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final balances = computeBalances(widget.txns);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    var monthIncome = 0;
    var monthExpense = 0;
    for (final t in widget.txns) {
      if (t.date.isBefore(monthStart) || !t.date.isBefore(nextMonth)) continue;
      if (t.kind == TxnKind.income) monthIncome += t.amountCents;
      if (t.kind == TxnKind.expense) monthExpense += t.amountCents;
    }

    final portfolio = widget.holdings.fold<int>(0, (sum, h) {
      final price = h.lastPriceCents ?? h.avgCostCents;
      return sum + (price * h.shares).round();
    });
    final netWorth = balances.totalCents + portfolio;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCard(
            netWorthCents: netWorth,
            availableCents: balances.mainCents,
            potsCents: balances.potsTotalCents,
            investmentsCents: portfolio,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Income this month',
                  amountCents: monthIncome,
                  color: luma.success,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'Spent this month',
                  amountCents: monthExpense,
                  color: luma.danger,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SectionTitle('Dashboard')),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, size: 16),
                label: Text(_isEditing ? 'Done' : 'Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: luma.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DashboardGraphs(
            graphs: widget.graphs,
            txns: widget.txns,
            categories: widget.categories,
            holdings: widget.holdings,
            isEditing: _isEditing,
          ),
          const SizedBox(height: 24),
          _SectionTitle('Pots'),
          const SizedBox(height: 12),
          if (widget.pots.isEmpty)
            _MutedHint(
              'No pots yet — create one in the Pots tab to start dividing your money.',
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final pot in widget.pots)
                  _PotChip(pot: pot, balanceCents: balances.balanceForPot(pot.id)),
              ],
            ),
          const SizedBox(height: 24),
          _SectionTitle('This week'),
          const SizedBox(height: 12),
          _WeeklyReview(txns: widget.txns, categories: widget.categories, now: now),
          if (widget.holdings.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle('Investments'),
            const SizedBox(height: 12),
            _InvestmentsSummary(holdings: widget.holdings),
          ],
          const SizedBox(height: 24),
          _SectionTitle('Upcoming'),
          const SizedBox(height: 12),
          _UpcomingRecurring(recurring: widget.recurring),
        ],
      ),
    );
  }
}

class _DashboardGraphs extends StatelessWidget {
  const _DashboardGraphs({
    required this.graphs,
    required this.txns,
    required this.categories,
    required this.holdings,
    required this.isEditing,
  });

  final List<OverviewGraph> graphs;
  final List<FinanceTransaction> txns;
  final List<Category> categories;
  final List<Holding> holdings;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    if (graphs.isEmpty && !isEditing) {
      return const SizedBox();
    }

    return Column(
      children: [
        if (isEditing) ...[
          // Reorderable list inside a finite height or just standard column for simplicity
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: graphs.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final list = List<OverviewGraph>.from(graphs);
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
              FinanceScope.of(context).reorderOverviewGraphs(list);
            },
            itemBuilder: (context, index) {
              final g = graphs[index];
              return ListTile(
                key: ValueKey(g.id),
                title: Text(_titleFor(g)),
                subtitle: Text(_subtitleFor(g)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => FinanceScope.of(context).deleteOverviewGraph(g.id),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddGraphDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Graph'),
          ),
        ] else ...[
          for (final g in graphs) ...[
            _GraphCard(
              title: _titleFor(g),
              child: _buildGraph(g),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  String _titleFor(OverviewGraph g) {
    if (g.dataSource == 'net_worth') return 'Net Worth Over Time';
    if (g.dataSource == 'category_spending') return 'Spending by Category';
    if (g.dataSource == 'income_vs_expense') return 'Income vs Expense';
    return 'Unknown Graph';
  }
  
  String _subtitleFor(OverviewGraph g) {
    if (g.graphType == 'line') return 'Line Chart';
    if (g.graphType == 'pie') return 'Pie Chart';
    if (g.graphType == 'bar') return 'Bar Chart';
    return 'Chart';
  }

  Widget _buildGraph(OverviewGraph g) {
    if (g.dataSource == 'net_worth') {
      return NetWorthChart(txns: txns, holdings: holdings);
    } else if (g.dataSource == 'category_spending') {
      return CategorySpendingChart(txns: txns, categories: categories);
    } else if (g.dataSource == 'income_vs_expense') {
      return IncomeVsExpenseChart(txns: txns);
    }
    return const SizedBox();
  }
  
  void _showAddGraphDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Graph'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Net Worth Over Time'),
              onTap: () {
                FinanceScope.of(context).addOverviewGraph(graphType: 'line', dataSource: 'net_worth');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Spending by Category'),
              onTap: () {
                FinanceScope.of(context).addOverviewGraph(graphType: 'pie', dataSource: 'category_spending');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Income vs Expense'),
              onTap: () {
                FinanceScope.of(context).addOverviewGraph(graphType: 'bar', dataSource: 'income_vs_expense');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphCard extends StatelessWidget {
  const _GraphCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(color: context.luma.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.netWorthCents,
    required this.availableCents,
    required this.potsCents,
    required this.investmentsCents,
  });
  final int netWorthCents;
  final int availableCents;
  final int potsCents;
  final int investmentsCents;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            luma.accent.withValues(alpha: 0.22),
            luma.accent.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: luma.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth',
              style: TextStyle(color: luma.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            formatCents(netWorthCents),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(label: 'Available', cents: availableCents),
              _HeroDivider(),
              _HeroStat(label: 'In pots', cents: potsCents),
              _HeroDivider(),
              _HeroStat(label: 'Investments', cents: investmentsCents),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.cents});
  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            formatCents(cents),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: context.luma.border);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amountCents,
    required this.color,
    required this.icon,
  });
  final String label;
  final int amountCents;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCents(amountCents),
                    maxLines: 1,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PotChip extends StatelessWidget {
  const _PotChip({required this.pot, required this.balanceCents});
  final Pot pot;
  final int balanceCents;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LumaIconBadge(
                icon: materialIcon(pot.iconCodepoint),
                color: Color(pot.colorValue),
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatCents(balanceCents),
            style: TextStyle(
              color: balanceCents < 0 ? luma.danger : luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReview extends StatelessWidget {
  const _WeeklyReview({
    required this.txns,
    required this.categories,
    required this.now,
  });
  final List<FinanceTransaction> txns;
  final List<Category> categories;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final catById = {for (final c in categories) c.id: c};

    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final byCategory = <int?, int>{};
    var total = 0;
    for (final t in txns) {
      if (t.kind != TxnKind.expense) continue;
      if (t.date.isBefore(weekStart) || !t.date.isBefore(weekEnd)) continue;
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amountCents;
      total += t.amountCents;
    }

    if (total == 0) {
      return LumaCard(
        child: _MutedHint('No spending recorded yet this week.'),
      );
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.first.value;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spent this week',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              Text(
                formatCents(total),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final e in entries) ...[
            _ReviewRow(
              category: e.key == null ? null : catById[e.key],
              amountCents: e.value,
              fraction: e.value / maxValue,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.category,
    required this.amountCents,
    required this.fraction,
  });
  final Category? category;
  final int amountCents;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color =
        category != null ? Color(category!.colorValue) : luma.textMuted;
    final name = category?.name ?? 'Uncategorized';
    final icon = category != null
        ? materialIcon(category!.iconCodepoint)
        : Icons.help_outline_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(name,
                style: TextStyle(color: luma.textPrimary, fontSize: 13)),
            const Spacer(),
            Text(
              formatCents(amountCents),
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
            value: fraction.clamp(0.04, 1.0),
            minHeight: 6,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _InvestmentsSummary extends StatelessWidget {
  const _InvestmentsSummary({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    var value = 0;
    var cost = 0;
    for (final h in holdings) {
      final price = h.lastPriceCents ?? h.avgCostCents;
      value += (price * h.shares).round();
      cost += (h.avgCostCents * h.shares).round();
    }
    final gain = value - cost;
    final gainColor = gain >= 0 ? luma.success : luma.danger;

    return LumaCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Portfolio value',
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  formatCents(value),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Gain / loss',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                formatSignedCents(gain),
                style: TextStyle(
                  color: gainColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingRecurring extends StatelessWidget {
  const _UpcomingRecurring({required this.recurring});
  final List<RecurringRule> recurring;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = recurring.where((r) => r.active).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final upcoming = active.take(4).toList();

    if (upcoming.isEmpty) {
      return LumaCard(
        child: _MutedHint(
          'No fixed costs or income yet — add them in the Recurring tab.',
        ),
      );
    }

    return LumaCard(
      child: Column(
        children: [
          for (var i = 0; i < upcoming.length; i++) ...[
            if (i > 0) Divider(color: luma.border, height: 20),
            _UpcomingRow(rule: upcoming[i]),
          ],
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.rule});
  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isIncome = rule.kind == TxnKind.income;
    final color = isIncome ? luma.success : luma.danger;
    return Row(
      children: [
        LumaIconBadge(
          icon: isIncome
              ? Icons.south_west_rounded
              : Icons.autorenew_rounded,
          color: color,
          size: 34,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rule.name,
                  style: TextStyle(
                      color: luma.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                '${rule.cadence == Cadence.weekly ? 'Weekly' : 'Monthly'} · next ${_shortDate(rule.nextDue)}',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          formatSignedCents(isIncome ? rule.amountCents : -rule.amountCents),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.luma.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _MutedHint extends StatelessWidget {
  const _MutedHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: context.luma.textMuted, fontSize: 13),
      );
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

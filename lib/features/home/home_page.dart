import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../finance/data/database.dart';
import '../../finance/finance_scope.dart';
import '../../finance/logic/finance_logic.dart';
import '../../finance/logic/money.dart';
import '../../finance/ui/lookups.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';

/// The landing dashboard: a friendly greeting, a live snapshot of finances and
/// quick shortcuts into the rest of the app.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  /// Jumps the shell to another destination (1 = Converter, 2 = Finance,
  /// 3 = Password Manager, 4 = Settings).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Pot>>(
      stream: repo.watchPots(),
      builder: (context, pots) => StreamData<List<Holding>>(
        stream: repo.watchHoldings(),
        builder: (context, holdings) => StreamData<List<Category>>(
          stream: repo.watchCategories(),
          builder: (context, categories) =>
              StreamData<List<FinanceTransaction>>(
            stream: repo.watchTransactions(),
            builder: (context, txns) => _HomeBody(
              pots: pots,
              holdings: holdings,
              categories: categories,
              txns: txns,
              onNavigate: onNavigate,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.pots,
    required this.holdings,
    required this.categories,
    required this.txns,
    required this.onNavigate,
  });

  final List<Pot> pots;
  final List<Holding> holdings;
  final List<Category> categories;
  final List<FinanceTransaction> txns;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);
    final hide = settings.hideAmounts;
    String money(int cents) => hide ? '••••••' : formatCents(cents);

    final balances = computeBalances(txns);
    final portfolio = holdings.fold<int>(0, (sum, h) {
      final price = h.lastPriceCents ?? h.avgCostCents;
      return sum + (price * h.shares).round();
    });
    final netWorth = balances.totalCents + portfolio;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    var monthIncome = 0;
    var monthExpense = 0;
    for (final t in txns) {
      if (t.date.isBefore(monthStart) || !t.date.isBefore(nextMonth)) continue;
      if (t.kind == TxnKind.income) monthIncome += t.amountCents;
      if (t.kind == TxnKind.expense) monthExpense += t.amountCents;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GreetingCard(now: now, netWorthLabel: money(netWorth)),
          const SizedBox(height: 20),
          _SectionTitle('At a glance'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Income this month',
                  value: money(monthIncome),
                  color: luma.success,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'Spent this month',
                  value: money(monthExpense),
                  color: luma.danger,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'In pots',
                  value: money(balances.potsTotalCents),
                  color: luma.accent,
                  icon: Icons.savings_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'Investments',
                  value: money(portfolio),
                  color: luma.accent,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionTitle('Jump back in'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Finance',
                  subtitle: 'Budgets, pots & stocks',
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickAction(
                  icon: Icons.swap_horiz_rounded,
                  title: 'File Converter',
                  subtitle: 'Convert images & files',
                  onTap: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickAction(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'Theme, colors & more',
                  onTap: () => onNavigate(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionTitle('Recent activity'),
          const SizedBox(height: 12),
          _RecentActivity(
            txns: txns,
            categories: categories,
            pots: pots,
            hide: hide,
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.now, required this.netWorthLabel});
  final DateTime now;
  final String netWorthLabel;

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
          Text(
            _greeting(now.hour),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _longDate(now),
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Text('Net worth',
              style: TextStyle(color: luma.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            netWorthLabel,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
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
                    style:
                        TextStyle(color: luma.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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

class _QuickAction extends StatefulWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? luma.accent : luma.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumaIconBadge(icon: widget.icon, color: luma.accent),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.txns,
    required this.categories,
    required this.pots,
    required this.hide,
  });
  final List<FinanceTransaction> txns;
  final List<Category> categories;
  final List<Pot> pots;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final recent = txns.take(5).toList();

    if (recent.isEmpty) {
      return LumaCard(
        child: Text(
          'Nothing here yet — add a transaction in the Finance tab and it will '
          'show up here.',
          style: TextStyle(color: luma.textMuted, fontSize: 13),
        ),
      );
    }

    final catById = {for (final c in categories) c.id: c};
    final potById = {for (final p in pots) p.id: p};

    return LumaCard(
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) Divider(color: luma.border, height: 20),
            _ActivityRow(
              txn: recent[i],
              category:
                  recent[i].categoryId == null ? null : catById[recent[i].categoryId],
              pot: recent[i].potId == null ? null : potById[recent[i].potId],
              hide: hide,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.txn,
    required this.category,
    required this.pot,
    required this.hide,
  });
  final FinanceTransaction txn;
  final Category? category;
  final Pot? pot;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    final IconData icon;
    final Color color;
    switch (txn.kind) {
      case TxnKind.income:
        icon = Icons.south_west_rounded;
        color = luma.success;
      case TxnKind.expense:
        icon = category != null
            ? materialIcon(category!.iconCodepoint)
            : Icons.north_east_rounded;
        color = category != null ? Color(category!.colorValue) : luma.danger;
      case TxnKind.allocation:
        icon = Icons.savings_rounded;
        color = pot != null ? Color(pot!.colorValue) : luma.accent;
    }

    final title = txn.note?.isNotEmpty == true
        ? txn.note!
        : (category?.name ?? pot?.name ?? _kindLabel(txn.kind));

    final signed = switch (txn.kind) {
      TxnKind.income => txn.amountCents,
      TxnKind.expense => -txn.amountCents,
      TxnKind.allocation => txn.amountCents,
    };
    final amountColor = txn.kind == TxnKind.income
        ? luma.success
        : (txn.kind == TxnKind.expense ? luma.danger : luma.textSecondary);

    return Row(
      children: [
        LumaIconBadge(icon: icon, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: luma.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _shortDate(txn.date),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          hide ? '••••' : formatSignedCents(signed),
          style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
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

String _greeting(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _kindLabel(TxnKind kind) => switch (kind) {
      TxnKind.income => 'Income',
      TxnKind.expense => 'Expense',
      TxnKind.allocation => 'Allocation',
    };

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _longDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

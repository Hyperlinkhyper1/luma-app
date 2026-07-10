import 'package:flutter/material.dart';

import '../../app/nav_rail.dart';
import '../../app/widgets.dart';
import '../../finance/data/database.dart';
import '../../finance/finance_scope.dart';
import '../../finance/logic/finance_logic.dart';
import '../../finance/logic/money.dart';
import '../../finance/ui/lookups.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';

/// The landing dashboard: a friendly greeting, a live snapshot of finances and
/// quick shortcuts into the rest of the app.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  /// Jumps the shell to another destination (1 = Converter, 2 = Finance,
  /// 3 = Password Manager, 5 = Assistant, [NavRail.settingsIndex] = Settings).
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
    final t = L.of(context);
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
    for (final txn in txns) {
      if (txn.date.isBefore(monthStart) || !txn.date.isBefore(nextMonth)) continue;
      if (txn.kind == TxnKind.income) monthIncome += txn.amountCents;
      if (txn.kind == TxnKind.expense) monthExpense += txn.amountCents;
    }

    final statCards = [
      _StatCard(
        label: t.homeIncomeMonth,
        value: money(monthIncome),
        color: luma.success,
        icon: Icons.south_west_rounded,
      ),
      _StatCard(
        label: t.homeSpentMonth,
        value: money(monthExpense),
        color: luma.danger,
        icon: Icons.north_east_rounded,
      ),
      _StatCard(
        label: t.homeInPots,
        value: money(balances.potsTotalCents),
        color: luma.accent,
        icon: Icons.savings_rounded,
      ),
      _StatCard(
        label: t.homeInvestments,
        value: money(portfolio),
        color: luma.accent,
        icon: Icons.trending_up_rounded,
      ),
    ];

    final quickActions = [
      _QuickAction(
        icon: Icons.smart_toy_rounded,
        title: t.homeAskAssistant,
        subtitle: t.homeAskAssistantSub,
        onTap: () => onNavigate(5),
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        title: t.homeFinance,
        subtitle: t.homeFinanceSub,
        onTap: () => onNavigate(2),
      ),
      _QuickAction(
        icon: Icons.swap_horiz_rounded,
        title: t.homeFileConverter,
        subtitle: t.homeFileConverterSub,
        onTap: () => onNavigate(1),
      ),
      _QuickAction(
        icon: Icons.settings_rounded,
        title: t.homeSettings,
        subtitle: t.homeSettingsSub,
        onTap: () => onNavigate(NavRail.settingsIndex),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        final hPadding = narrow ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPadding, 12, hPadding, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(now: now, netWorthLabel: money(netWorth)),
              const SizedBox(height: 20),
              _SectionTitle(t.homeAtAGlance),
              const SizedBox(height: 12),
              _ResponsiveGrid(
                narrow: narrow,
                desktopColumns: 2,
                children: statCards,
              ),
              const SizedBox(height: 28),
              _SectionTitle(t.homeJumpBackIn),
              const SizedBox(height: 12),
              _ResponsiveGrid(narrow: narrow, children: quickActions),
              const SizedBox(height: 28),
              _SectionTitle(t.homeRecentActivity),
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
      },
    );
  }
}

/// Lays [children] out as a fixed-column grid on wide screens, or as a single
/// stacked column when [narrow] — avoids squeezing card text into a column so
/// thin that words wrap letter-by-letter.
class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.narrow,
    required this.children,
    this.desktopColumns,
  });

  final bool narrow;
  final List<Widget> children;
  final int? desktopColumns;

  static const _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: _spacing),
            SizedBox(width: double.infinity, child: children[i]),
          ],
        ],
      );
    }

    final columns = desktopColumns ?? children.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
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
    final t = L.of(context);
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
            _greeting(now.hour, t),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _longDate(now, t),
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Text(t.homeNetWorth,
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
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
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
    final t = L.of(context);
    final recent = txns.take(5).toList();

    if (recent.isEmpty) {
      return LumaCard(
        child: Text(
          t.homeNoTransactions,
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
    final t = L.of(context);

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
        : (category?.name ?? pot?.name ?? _kindLabel(txn.kind, t));

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
                _shortDate(txn.date, t),
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

String _greeting(int hour, L t) {
  if (hour < 12) return t.homeGreetingMorning;
  if (hour < 18) return t.homeGreetingAfternoon;
  return t.homeGreetingEvening;
}

String _kindLabel(TxnKind kind, L t) => switch (kind) {
      TxnKind.income => t.homeIncome,
      TxnKind.expense => t.homeExpense,
      TxnKind.allocation => t.homeAllocation,
    };

List<String> _months(L t) => [
      t.monthJan, t.monthFeb, t.monthMar, t.monthApr,
      t.monthMay, t.monthJun, t.monthJul, t.monthAug,
      t.monthSep, t.monthOct, t.monthNov, t.monthDec,
    ];

List<String> _weekdays(L t) => [
      t.weekdayMon, t.weekdayTue, t.weekdayWed, t.weekdayThu,
      t.weekdayFri, t.weekdaySat, t.weekdaySun,
    ];

String _shortDate(DateTime d, L t) => '${d.day} ${_months(t)[d.month - 1]}';

String _longDate(DateTime d, L t) =>
    '${_weekdays(t)[d.weekday - 1]}, ${d.day} ${_months(t)[d.month - 1]} ${d.year}';

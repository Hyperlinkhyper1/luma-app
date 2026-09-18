import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../finance/data/database.dart';
import '../../finance/finance_scope.dart';
import '../../finance/logic/finance_logic.dart';
import '../../finance/logic/money.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
import 'home_layout.dart';

class HomeGreeting extends StatefulWidget {
  const HomeGreeting({super.key, required this.layout, this.onEdit});
  final HomeLayout layout;
  final VoidCallback? onEdit;

  @override
  State<HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends State<HomeGreeting> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context
        .dependOnInheritedWidgetOfExactType<FinanceScope>()
        ?.repository;
    final layout = widget.layout;
    if (layout.heroMetric == 'custom') {
      return _card(layout.heroLabel, layout.heroText);
    }
    if (repo == null) return _card(_label(context, layout.heroMetric), '—');
    return StreamBuilder<List<FinanceTransaction>>(
      stream: repo.watchTransactions(),
      builder: (context, transactions) => StreamBuilder<List<Holding>>(
        stream: repo.watchHoldings(),
        builder: (context, holdings) {
          final metric = layout.heroMetric;
          final needsTransactions = metric != 'investments';
          final needsHoldings = metric == 'investments' || metric == 'netWorth';
          if ((needsTransactions && transactions.hasError) ||
              (needsHoldings && holdings.hasError)) {
            return _card(_label(context, metric), 'Unavailable');
          }
          if ((needsTransactions && !transactions.hasData) ||
              (needsHoldings && !holdings.hasData)) {
            return _card(_label(context, metric), '—');
          }
          final txns = transactions.data ?? const <FinanceTransaction>[];
          final balances = computeBalances(txns);
          final portfolio = (holdings.data ?? const <Holding>[]).fold<int>(
            0,
            (sum, h) =>
                sum + ((h.lastPriceCents ?? h.avgCostCents) * h.shares).round(),
          );
          final now = DateTime.now();
          final monthly = txns.where(
            (t) => t.date.year == now.year && t.date.month == now.month,
          );
          final value = switch (metric) {
            'cash' => balances.totalCents,
            'investments' => portfolio,
            'income' =>
              monthly
                  .where((t) => t.kind == TxnKind.income)
                  .fold<int>(0, (sum, t) => sum + t.amountCents),
            'spending' =>
              monthly
                  .where((t) => t.kind == TxnKind.expense)
                  .fold<int>(0, (sum, t) => sum + t.amountCents),
            _ => balances.totalCents + portfolio,
          };
          final hide =
              context
                  .dependOnInheritedWidgetOfExactType<SettingsScope>()
                  ?.notifier
                  ?.hideAmounts ??
              false;
          return _card(
            _label(context, metric),
            hide ? '••••••' : formatCents(value),
          );
        },
      ),
    );
  }

  Widget _card(String label, String value) {
    final palette = context.luma;
    final t = Localizations.of<L>(context, L);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? (t?.homeGreetingMorning ?? 'Good morning')
        : now.hour < 18
        ? (t?.homeGreetingAfternoon ?? 'Good afternoon')
        : (t?.homeGreetingEvening ?? 'Good evening');
    return Container(
      key: const ValueKey('home-greeting'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: context.lumaDecor.cardBorderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              palette.accent.withValues(alpha: .22),
              palette.background,
            ),
            Color.alphaBlend(
              palette.accent.withValues(alpha: .06),
              palette.background,
            ),
          ],
        ),
        border: Border.all(color: palette.accent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: context.lumaDecor.applyDisplayFont(
              TextStyle(
                color: palette.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat(
              'EEEE, d MMM yyyy',
              Localizations.localeOf(context).toString(),
            ).format(now),
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Text(
            label.isEmpty ? 'A little inspiration' : label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: context.lumaDecor.applyDisplayFont(
              TextStyle(
                color: palette.textPrimary,
                fontSize: widget.layout.heroMetric == 'custom' ? 26 : 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          if (widget.onEdit != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit summary'),
              ),
            ),
        ],
      ),
    );
  }
}

String _label(BuildContext context, String metric) {
  final t = Localizations.of<L>(context, L);
  return switch (metric) {
    'cash' => 'Cash balance',
    'investments' => t?.homeInvestments ?? 'Investments',
    'income' => t?.homeIncomeMonth ?? 'Came in this month',
    'spending' => t?.homeSpentMonth ?? 'Went out this month',
    'custom' => 'Custom text',
    _ => t?.homeNetWorth ?? 'All together',
  };
}

Future<HomeLayout?> editHomeSummary(BuildContext context, HomeLayout layout) =>
    showDialog<HomeLayout>(
      context: context,
      builder: (_) => _SummaryDialog(layout: layout),
    );

class _SummaryDialog extends StatefulWidget {
  const _SummaryDialog({required this.layout});
  final HomeLayout layout;
  @override
  State<_SummaryDialog> createState() => _SummaryDialogState();
}

class _SummaryDialogState extends State<_SummaryDialog> {
  late String metric = widget.layout.heroMetric;
  late final label = TextEditingController(text: widget.layout.heroLabel);
  late final text = TextEditingController(text: widget.layout.heroText);
  @override
  void dispose() {
    label.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Greeting summary'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your greeting always stays at the top. Choose what appears beneath it.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: metric,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Show in greeting'),
              items: [
                for (final item in HomeLayout.heroMetrics)
                  DropdownMenuItem(
                    value: item,
                    child: Text(_label(context, item)),
                  ),
              ],
              onChanged: (value) => setState(() => metric = value!),
            ),
            if (metric == 'custom') ...[
              const SizedBox(height: 16),
              TextField(
                controller: label,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Today’s focus',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  hintText: 'Make time for what matters.',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          widget.layout.copyWith(
            heroMetric: metric,
            heroLabel: label.text.trim(),
            heroText: text.text.trim(),
          ),
        ),
        child: const Text('Apply'),
      ),
    ],
  );
}

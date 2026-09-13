import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../finance/data/database.dart';
import '../../finance/finance_scope.dart';
import '../../finance/logic/finance_logic.dart';
import '../../finance/logic/money.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';

class HomeClassicMetric extends StatelessWidget {
  const HomeClassicMetric({
    super.key,
    required this.kind,
    this.editing = false,
  });
  final String kind;

  /// While the grid shows its own header the tile only needs its number. The
  /// rest of the time it carries the whole dashboard card, badge and label
  /// included, the way the home page looked before it became a grid.
  final bool editing;

  static const _icons = {
    'income': Icons.south_west_rounded,
    'spending': Icons.north_east_rounded,
    'pots': Icons.savings_rounded,
    'investments': Icons.trending_up_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final repo = context
        .dependOnInheritedWidgetOfExactType<FinanceScope>()
        ?.repository;
    if (repo == null) {
      return const Text('Connect your finances to see this summary.');
    }
    final hide =
        context
            .dependOnInheritedWidgetOfExactType<SettingsScope>()
            ?.notifier
            ?.hideAmounts ??
        false;
    Widget amount(int value) => _card(
      context,
      Text(
        hide ? '••••••' : formatCents(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
          color: context.luma.textPrimary,
        ),
      ),
    );
    if (kind == 'investments') {
      return StreamBuilder<List<Holding>>(
        stream: repo.watchHoldings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Could not load investments.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return amount(
            snapshot.data!.fold<int>(
              0,
              (sum, h) =>
                  sum +
                  ((h.lastPriceCents ?? h.avgCostCents) * h.shares).round(),
            ),
          );
        },
      );
    }
    return StreamBuilder<List<FinanceTransaction>>(
      stream: repo.watchTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Could not load finances.');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final txns = snapshot.data!;
        if (kind == 'pots') return amount(computeBalances(txns).potsTotalCents);
        final now = DateTime.now();
        return amount(
          txns
              .where(
                (t) =>
                    t.date.year == now.year &&
                    t.date.month == now.month &&
                    t.kind ==
                        (kind == 'income' ? TxnKind.income : TxnKind.expense),
              )
              .fold<int>(0, (sum, t) => sum + t.amountCents),
        );
      },
    );
  }

  Widget _card(BuildContext context, Widget value) {
    if (editing) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(fit: BoxFit.scaleDown, child: value),
      );
    }
    final palette = context.luma;
    final color = switch (kind) {
      'income' => palette.success,
      'spending' => palette.danger,
      _ => palette.accent,
    };
    return Row(
      children: [
        LumaIconBadge(
          icon: _icons[kind] ?? Icons.savings_rounded,
          color: color,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  _label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: value,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _label(BuildContext context) {
    final t = Localizations.of<L>(context, L);
    return switch (kind) {
      'income' => t?.homeIncomeMonth ?? 'Came in this month',
      'spending' => t?.homeSpentMonth ?? 'Went out this month',
      'investments' => t?.homeInvestments ?? 'Investments',
      _ => t?.homeInPots ?? 'Set aside in pots',
    };
  }
}

class HomeClassicShortcut extends StatelessWidget {
  const HomeClassicShortcut({
    super.key,
    required this.destination,
    required this.onNavigate,
    this.editing = false,
  });
  final int destination;
  final ValueChanged<int> onNavigate;

  /// See [HomeClassicMetric.editing]: the badge is the grid header's job while
  /// a tile is being moved, and the card's own the rest of the time.
  final bool editing;

  static const icons = {
    5: Icons.smart_toy_rounded,
    2: Icons.account_balance_wallet_rounded,
    1: Icons.swap_horiz_rounded,
    7: Icons.settings_rounded,
    4: Icons.sticky_note_2_rounded,
    3: Icons.lock_rounded,
    6: Icons.extension_rounded,
  };
  static const labels = {
    5: 'Ask Assistant',
    2: 'Finance',
    1: 'File Converter',
    7: 'Settings',
    4: 'Notes',
    3: 'Passwords',
    6: 'Plugins',
  };
  static const subtitles = {
    5: 'Have a chat, ask anything',
    2: 'Your money, pots & stocks',
    1: 'Change up images & files',
    7: 'Colours, theme & stuff',
    4: 'Your ideas, close at hand',
    3: 'Keep your secrets safe',
    6: 'Discover your next little helper',
  };

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: context.lumaDecor.cardBorderRadius,
      onTap: () =>
          onNavigate(labels.containsKey(destination) ? destination : 5),
      child: Padding(
        padding: editing ? EdgeInsets.zero : const EdgeInsets.all(16),
        child: FilledTileBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!editing) ...[
                LumaIconBadge(
                  icon: icons[destination] ?? Icons.arrow_forward_rounded,
                  color: context.luma.accent,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                labels[destination] ?? 'Ask Assistant',
                style: TextStyle(
                  color: context.luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitles[destination] ?? subtitles[5]!,
                style: TextStyle(color: context.luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context
        .dependOnInheritedWidgetOfExactType<FinanceScope>()
        ?.repository;
    if (repo == null) {
      return const Text('Your recent transactions will appear here.');
    }
    final hide =
        context
            .dependOnInheritedWidgetOfExactType<SettingsScope>()
            ?.notifier
            ?.hideAmounts ??
        false;
    return StreamBuilder<List<FinanceTransaction>>(
      stream: repo.watchTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load recent activity.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final txns = [...snapshot.data!]
          ..sort((a, b) => b.date.compareTo(a.date));
        if (txns.isEmpty) {
          return FilledTileBody(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 28,
                  color: context.luma.textMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nothing here yet. Your next chapter starts with your first transaction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.luma.textSecondary),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: txns.take(5).length,
          separatorBuilder: (_, index) =>
              Divider(color: context.luma.border, height: 18),
          itemBuilder: (context, index) {
            final t = txns[index];
            final color = t.kind == TxnKind.income
                ? context.luma.success
                : t.kind == TxnKind.expense
                ? context.luma.danger
                : context.luma.accent;
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    t.kind == TxnKind.income
                        ? Icons.south_west_rounded
                        : t.kind == TxnKind.expense
                        ? Icons.north_east_rounded
                        : Icons.savings_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.note?.isNotEmpty == true
                            ? t.note!
                            : switch (t.kind) {
                                TxnKind.income => 'Income',
                                TxnKind.expense => 'Expense',
                                TxnKind.allocation => 'Set aside in pots',
                              },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${t.date.day}/${t.date.month}/${t.date.year}',
                        style: TextStyle(
                          color: context.luma.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hide
                        ? '••••••'
                        : formatCents(
                            t.kind == TxnKind.expense
                                ? -t.amountCents
                                : t.amountCents,
                          ),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Fills the tile it is given so short content can sit centred instead of
/// stranded at the top, while still scrolling when the tile is too small for
/// it — a tile can be resized down to three rows, or carry a large text scale.
class FilledTileBody extends StatelessWidget {
  const FilledTileBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}

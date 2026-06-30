import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_scope.dart';
import '../logic/money.dart';
import 'add_transaction_sheet.dart';
import 'lookups.dart';
import '../import/bank_selection_dialog.dart';

class TransactionsTab extends StatelessWidget {
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Category>>(
      stream: repo.watchCategories(),
      builder: (context, categories) => StreamData<List<Merchant>>(
        stream: repo.watchMerchants(),
        builder: (context, merchants) => StreamData<List<Pot>>(
          stream: repo.watchPots(),
          builder: (context, pots) => StreamData<List<FinanceTransaction>>(
            stream: repo.watchTransactions(),
            builder: (context, txns) => _TransactionsBody(
              txns: txns,
              categories: categories,
              merchants: merchants,
              pots: pots,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionsBody extends StatelessWidget {
  const _TransactionsBody({
    required this.txns,
    required this.categories,
    required this.merchants,
    required this.pots,
  });
  final List<FinanceTransaction> txns;
  final List<Category> categories;
  final List<Merchant> merchants;
  final List<Pot> pots;

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    final catById = {for (final c in categories) c.id: c};
    final merchantById = {for (final m in merchants) m.id: m};
    final potById = {for (final p in pots) p.id: p};

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${txns.length} entries',
                style: TextStyle(color: context.luma.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              LumaGhostButton(
                label: 'Import data',
                icon: Icons.upload_file_rounded,
                onTap: () => showImportFlow(
                  context,
                  repo: repo,
                  merchants: merchants,
                  categories: categories,
                  pots: pots,
                ),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add entry',
                icon: Icons.add_rounded,
                onTap: () => showAddTransaction(
                  context,
                  repo: repo,
                  merchants: merchants,
                  categories: categories,
                  pots: pots,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: txns.isEmpty
                ? LumaEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No entries yet',
                    subtitle: 'Add your first expense or income to get started.',
                  )
                : ListView.separated(
                    itemCount: txns.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = txns[i];
                      return _TxnRow(
                        txn: t,
                        category: t.categoryId == null ? null : catById[t.categoryId],
                        merchant: t.merchantId == null ? null : merchantById[t.merchantId],
                        pot: t.potId == null ? null : potById[t.potId],
                        onDelete: () => repo.deleteTransaction(t.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.txn,
    required this.category,
    required this.merchant,
    required this.pot,
    required this.onDelete,
  });
  final FinanceTransaction txn;
  final Category? category;
  final Merchant? merchant;
  final Pot? pot;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    late final IconData icon;
    late final Color color;
    late final String title;
    late final int signedAmount;

    switch (txn.kind) {
      case TxnKind.income:
        icon = Icons.south_west_rounded;
        color = luma.success;
        title = txn.note ?? 'Income';
        signedAmount = txn.amountCents;
      case TxnKind.allocation:
        icon = Icons.savings_rounded;
        color = luma.accent;
        title = txn.note ?? 'Allocation';
        signedAmount = txn.amountCents; // shown neutral below
      case TxnKind.expense:
        icon = category != null
            ? materialIcon(category!.iconCodepoint)
            : Icons.shopping_bag_rounded;
        color = category != null ? Color(category!.colorValue) : luma.textMuted;
        title = merchant?.name ?? category?.name ?? txn.note ?? 'Expense';
        signedAmount = -txn.amountCents;
    }

    final subtitleParts = <String>[
      _shortDate(txn.date),
      if (category != null) category!.name,
      if (pot != null) pot!.name,
    ];

    final amountColor = switch (txn.kind) {
      TxnKind.income => luma.success,
      TxnKind.allocation => luma.accent,
      TxnKind.expense => luma.danger,
    };
    final amountText = switch (txn.kind) {
      TxnKind.allocation => '→ ${formatCents(txn.amountCents)}',
      _ => formatSignedCents(signedAmount),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          LumaIconBadge(icon: icon, color: color, size: 38),
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
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join('  ·  '),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amountText,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
          ),
          _DeleteButton(onDelete: onDelete),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: luma.textMuted),
      color: luma.surface,
      onSelected: (_) => onDelete(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: luma.danger),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: luma.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

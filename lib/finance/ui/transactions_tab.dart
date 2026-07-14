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

class _TransactionsBody extends StatefulWidget {
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
  State<_TransactionsBody> createState() => _TransactionsBodyState();
}

class _TransactionsBodyState extends State<_TransactionsBody> {
  final _searchController = TextEditingController();
  String _query = '';
  TxnKind? _kind;
  int? _categoryId;
  int? _potId;

  /// Selected month (first day), or null for all time.
  DateTime? _month;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _query.isNotEmpty ||
      _kind != null ||
      _categoryId != null ||
      _potId != null ||
      _month != null;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _kind = null;
      _categoryId = null;
      _potId = null;
      _month = null;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      final base = _month ?? DateTime(DateTime.now().year, DateTime.now().month);
      _month = DateTime(base.year, base.month + delta);
    });
  }

  List<FinanceTransaction> _filtered(
    Map<int, Category> catById,
    Map<int, Merchant> merchantById,
    Map<int, Pot> potById,
  ) {
    final q = _query.trim().toLowerCase();
    return widget.txns.where((t) {
      if (_kind != null && t.kind != _kind) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_potId != null && t.potId != _potId) return false;
      if (_month != null &&
          (t.date.year != _month!.year || t.date.month != _month!.month)) {
        return false;
      }
      if (q.isNotEmpty) {
        final haystack = [
          t.note ?? '',
          if (t.merchantId != null) merchantById[t.merchantId]?.name ?? '',
          if (t.categoryId != null) catById[t.categoryId]?.name ?? '',
          if (t.potId != null) potById[t.potId]?.name ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    final luma = context.luma;
    final catById = {for (final c in widget.categories) c.id: c};
    final merchantById = {for (final m in widget.merchants) m.id: m};
    final potById = {for (final p in widget.pots) p.id: p};

    final filtered = _filtered(catById, merchantById, potById);

    var incomeTotal = 0;
    var expenseTotal = 0;
    for (final t in filtered) {
      if (t.kind == TxnKind.income) incomeTotal += t.amountCents;
      if (t.kind == TxnKind.expense) expenseTotal += t.amountCents;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildSearchField(luma)),
              const SizedBox(width: 10),
              LumaGhostButton(
                label: 'Import data',
                icon: Icons.upload_file_rounded,
                onTap: () => showImportFlow(
                  context,
                  repo: repo,
                  merchants: widget.merchants,
                  categories: widget.categories,
                  pots: widget.pots,
                ),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add entry',
                icon: Icons.add_rounded,
                onTap: () => showAddTransaction(
                  context,
                  repo: repo,
                  merchants: widget.merchants,
                  categories: widget.categories,
                  pots: widget.pots,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFilterRow(luma),
          const SizedBox(height: 12),
          _SummaryBar(
            entryCount: filtered.length,
            incomeCents: incomeTotal,
            expenseCents: expenseTotal,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? (widget.txns.isEmpty
                    ? LumaEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No entries yet',
                        subtitle:
                            'Add your first expense or income to get started.',
                      )
                    : LumaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching entries',
                        subtitle:
                            'Try a different search or clear the filters.',
                        action: LumaGhostButton(
                          label: 'Clear filters',
                          icon: Icons.filter_alt_off_rounded,
                          onTap: _clearFilters,
                        ),
                      ))
                : _GroupedTxnList(
                    txns: filtered,
                    catById: catById,
                    merchantById: merchantById,
                    potById: potById,
                    onEdit: (t) => showAddTransaction(
                      context,
                      repo: repo,
                      merchants: widget.merchants,
                      categories: widget.categories,
                      pots: widget.pots,
                      existing: t,
                    ),
                    onDuplicate: (t) => repo.addTransaction(
                      kind: t.kind,
                      amountCents: t.amountCents,
                      date: DateTime.now(),
                      note: t.note,
                      potId: t.potId,
                      merchantId: t.merchantId,
                      categoryId: t.categoryId,
                    ),
                    onDelete: (t) => repo.deleteTransaction(t.id),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(LumaPalette luma) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(color: luma.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search notes, companies, categories…',
          hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
          prefixIcon:
              Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: luma.textMuted),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _query = '';
                  }),
                ),
          filled: true,
          fillColor: luma.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: luma.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: luma.accent),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(LumaPalette luma) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MonthStepper(
          month: _month,
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onToggle: () => setState(() {
            _month = _month == null
                ? DateTime(DateTime.now().year, DateTime.now().month)
                : null;
          }),
        ),
        _KindFilterChip(
          value: _kind,
          onChanged: (v) => setState(() => _kind = v),
        ),
        _PickerChip<int?>(
          icon: Icons.sell_rounded,
          label: _categoryId == null
              ? 'Category'
              : (widget.categories
                      .where((c) => c.id == _categoryId)
                      .map((c) => c.name)
                      .firstOrNull ??
                  'Category'),
          active: _categoryId != null,
          items: [
            const _PickerItem<int?>(value: null, label: 'All categories'),
            for (final c in widget.categories)
              _PickerItem<int?>(
                value: c.id,
                label: c.name,
                icon: materialIcon(c.iconCodepoint),
                iconColor: Color(c.colorValue),
              ),
          ],
          onSelected: (v) => setState(() => _categoryId = v),
        ),
        _PickerChip<int?>(
          icon: Icons.savings_rounded,
          label: _potId == null
              ? 'Pot'
              : (widget.pots
                      .where((p) => p.id == _potId)
                      .map((p) => p.name)
                      .firstOrNull ??
                  'Pot'),
          active: _potId != null,
          items: [
            const _PickerItem<int?>(value: null, label: 'All pots'),
            for (final p in widget.pots)
              _PickerItem<int?>(
                value: p.id,
                label: p.name,
                icon: materialIcon(p.iconCodepoint),
                iconColor: Color(p.colorValue),
              ),
          ],
          onSelected: (v) => setState(() => _potId = v),
        ),
        if (_hasFilters)
          _ChipButton(
            icon: Icons.filter_alt_off_rounded,
            label: 'Clear',
            active: false,
            onTap: _clearFilters,
          ),
      ],
    );
  }
}

// ---- Filter chips -----------------------------------------------------------

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToggle,
  });
  final DateTime? month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = month == null
        ? 'All time'
        : '${_monthName(month!.month)} ${month!.year}';
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: month == null ? luma.surface : luma.accentSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: month == null ? luma.border : luma.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: TextStyle(
                  color: month == null ? luma.textSecondary : luma.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _StepperArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _StepperArrow extends StatelessWidget {
  const _StepperArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 18, color: context.luma.textSecondary),
      ),
    );
  }
}

class _KindFilterChip extends StatelessWidget {
  const _KindFilterChip({required this.value, required this.onChanged});
  final TxnKind? value;
  final ValueChanged<TxnKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = switch (value) {
      null => 'All types',
      TxnKind.income => 'Income',
      TxnKind.expense => 'Expenses',
      TxnKind.allocation => 'Allocations',
    };
    return _PickerChip<TxnKind?>(
      icon: Icons.swap_vert_rounded,
      label: label,
      active: value != null,
      items: const [
        _PickerItem<TxnKind?>(value: null, label: 'All types'),
        _PickerItem<TxnKind?>(
            value: TxnKind.expense,
            label: 'Expenses',
            icon: Icons.north_east_rounded),
        _PickerItem<TxnKind?>(
            value: TxnKind.income,
            label: 'Income',
            icon: Icons.south_west_rounded),
        _PickerItem<TxnKind?>(
            value: TxnKind.allocation,
            label: 'Allocations',
            icon: Icons.savings_rounded),
      ],
      onSelected: onChanged,
    );
  }
}

class _PickerItem<T> {
  const _PickerItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });
  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

/// Compact filter chip that opens a popup menu of options.
class _PickerChip<T> extends StatelessWidget {
  const _PickerChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.items,
    required this.onSelected,
  });
  final IconData icon;
  final String label;
  final bool active;
  final List<_PickerItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<int>(
      tooltip: '',
      color: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (i) => onSelected(items[i].value),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 38,
            child: Row(
              children: [
                if (items[i].icon != null) ...[
                  Icon(items[i].icon,
                      size: 16, color: items[i].iconColor ?? luma.textSecondary),
                  const SizedBox(width: 8),
                ],
                Text(items[i].label,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13)),
              ],
            ),
          ),
      ],
      child: _ChipBody(icon: icon, label: label, active: active),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: _ChipBody(icon: icon, label: label, active: active),
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({
    required this.icon,
    required this.label,
    required this.active,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? luma.accentSubtle : luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? luma.accent : luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? luma.accent : luma.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 15, color: active ? luma.accent : luma.textMuted),
        ],
      ),
    );
  }
}

// ---- Summary ----------------------------------------------------------------

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.entryCount,
    required this.incomeCents,
    required this.expenseCents,
  });
  final int entryCount;
  final int incomeCents;
  final int expenseCents;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final net = incomeCents - expenseCents;
    return LumaCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Text(
            '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const Spacer(),
          _SummaryStat(label: 'In', cents: incomeCents, color: luma.success),
          const SizedBox(width: 20),
          _SummaryStat(label: 'Out', cents: -expenseCents, color: luma.danger),
          const SizedBox(width: 20),
          _SummaryStat(
            label: 'Net',
            cents: net,
            color: net >= 0 ? luma.success : luma.danger,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.cents,
    required this.color,
  });
  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        const SizedBox(width: 6),
        Text(
          formatSignedCents(cents),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ---- Grouped list -----------------------------------------------------------

class _GroupedTxnList extends StatelessWidget {
  const _GroupedTxnList({
    required this.txns,
    required this.catById,
    required this.merchantById,
    required this.potById,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });
  final List<FinanceTransaction> txns;
  final Map<int, Category> catById;
  final Map<int, Merchant> merchantById;
  final Map<int, Pot> potById;
  final ValueChanged<FinanceTransaction> onEdit;
  final ValueChanged<FinanceTransaction> onDuplicate;
  final ValueChanged<FinanceTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    // txns arrive sorted by date desc; flatten into day headers + rows.
    final items = <Object>[];
    DateTime? currentDay;
    var dayNet = 0;
    var headerIndex = -1;
    for (final t in txns) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (currentDay == null || day != currentDay) {
        if (headerIndex >= 0) {
          items[headerIndex] = _DayHeaderData(currentDay!, dayNet);
        }
        currentDay = day;
        dayNet = 0;
        headerIndex = items.length;
        items.add(_DayHeaderData(day, 0));
      }
      if (t.kind == TxnKind.income) dayNet += t.amountCents;
      if (t.kind == TxnKind.expense) dayNet -= t.amountCents;
      items.add(t);
    }
    if (headerIndex >= 0) {
      items[headerIndex] = _DayHeaderData(currentDay!, dayNet);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is _DayHeaderData) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 8),
            child: _DayHeader(data: item),
          );
        }
        final t = item as FinanceTransaction;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TxnRow(
            txn: t,
            category: t.categoryId == null ? null : catById[t.categoryId],
            merchant: t.merchantId == null ? null : merchantById[t.merchantId],
            pot: t.potId == null ? null : potById[t.potId],
            onEdit: () => onEdit(t),
            onDuplicate: () => onDuplicate(t),
            onDelete: () => onDelete(t),
          ),
        );
      },
    );
  }
}

class _DayHeaderData {
  const _DayHeaderData(this.day, this.netCents);
  final DateTime day;
  final int netCents;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.data});
  final _DayHeaderData data;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Text(
          _dayLabel(data.day),
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: luma.border)),
        const SizedBox(width: 10),
        Text(
          formatSignedCents(data.netCents),
          style: TextStyle(
            color: data.netCents >= 0 ? luma.success : luma.danger,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.txn,
    required this.category,
    required this.merchant,
    required this.pot,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });
  final FinanceTransaction txn;
  final Category? category;
  final Merchant? merchant;
  final Pot? pot;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
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
      if (category != null) category!.name,
      if (pot != null) pot!.name,
      if (txn.kind == TxnKind.expense &&
          merchant != null &&
          txn.note != null &&
          txn.note!.isNotEmpty)
        txn.note!,
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
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amountText,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
          ),
          _RowMenu(
            onEdit: onEdit,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: luma.textMuted),
      color: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit();
          case 'duplicate':
            onDuplicate();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18, color: luma.textSecondary),
              const SizedBox(width: 8),
              Text('Edit', style: TextStyle(color: luma.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18, color: luma.textSecondary),
              const SizedBox(width: 8),
              Text('Duplicate', style: TextStyle(color: luma.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 38,
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

String _monthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final label = '${day.day} ${_monthName(day.month)}';
  return day.year == now.year ? label : '$label ${day.year}';
}

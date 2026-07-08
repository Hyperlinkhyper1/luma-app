import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../storage/storage_guard.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../logic/money.dart';
import 'lookups.dart';

/// Opens the dialog for adding an expense or income entry.
Future<void> showAddTransaction(
  BuildContext context, {
  required FinanceRepository repo,
  required List<Merchant> merchants,
  required List<Category> categories,
  required List<Pot> pots,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _AddTransactionForm(
          repo: repo,
          merchants: merchants,
          categories: categories,
          pots: pots,
        ),
      ),
    ),
  );
}

class _AddTransactionForm extends StatefulWidget {
  const _AddTransactionForm({
    required this.repo,
    required this.merchants,
    required this.categories,
    required this.pots,
  });
  final FinanceRepository repo;
  final List<Merchant> merchants;
  final List<Category> categories;
  final List<Pot> pots;

  @override
  State<_AddTransactionForm> createState() => _AddTransactionFormState();
}

class _AddTransactionFormState extends State<_AddTransactionForm> {
  TxnKind _kind = TxnKind.expense;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  Merchant? _merchant;
  int? _categoryId;
  int? _potId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onMerchantPicked(Merchant? m) {
    setState(() {
      _merchant = m;
      if (m?.defaultCategoryId != null) _categoryId = m!.defaultCategoryId;
    });
  }

  Future<void> _save() async {
    final cents = parseToCents(_amountController.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.addTransaction(
        kind: _kind,
        amountCents: cents,
        date: _date,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        potId: _potId,
        merchantId: _kind == TxnKind.expense ? _merchant?.id : null,
        categoryId: _kind == TxnKind.expense ? _categoryId : null,
      );
    } on StorageLimitExceededException catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = '$e';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isExpense = _kind == TxnKind.expense;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New entry',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          LumaSegmentedTabs(
            tabs: const ['Expense', 'Income'],
            selectedIndex: isExpense ? 0 : 1,
            onSelect: (i) =>
                setState(() => _kind = i == 0 ? TxnKind.expense : TxnKind.income),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Amount'),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(color: luma.textPrimary),
            decoration: _inputDecoration(luma, hint: '0,00', prefix: '€ '),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Date'),
          _DateField(
            date: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          if (isExpense) ...[
            const SizedBox(height: 14),
            _FieldLabel('Company'),
            _MerchantField(
              merchants: widget.merchants,
              selected: _merchant,
              onPicked: _onMerchantPicked,
            ),
            const SizedBox(height: 14),
            _FieldLabel('Category'),
            _CategoryDropdown(
              categories: widget.categories,
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          const SizedBox(height: 14),
          _FieldLabel('Pot'),
          _PotDropdown(
            pots: widget.pots,
            value: _potId,
            hintNull: isExpense ? 'From main balance' : 'To main balance',
            onChanged: (v) => setState(() => _potId = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Note (optional)'),
          TextField(
            controller: _noteController,
            style: TextStyle(color: luma.textPrimary),
            decoration: _inputDecoration(luma, hint: 'e.g. weekly groceries'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add entry',
                icon: Icons.check_rounded,
                loading: _saving,
                onTap: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(LumaPalette luma,
    {String? hint, String? prefix}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    prefixText: prefix,
    prefixStyle: TextStyle(color: luma.textSecondary),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            color: context.luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onChanged});
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: luma.textSecondary),
            const SizedBox(width: 10),
            Text(
              '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
              style: TextStyle(color: luma.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantField extends StatelessWidget {
  const _MerchantField({
    required this.merchants,
    required this.selected,
    required this.onPicked,
  });
  final List<Merchant> merchants;
  final Merchant? selected;
  final ValueChanged<Merchant?> onPicked;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final result = await showDialog<Merchant>(
          context: context,
          builder: (_) => _MerchantSearchDialog(merchants: merchants),
        );
        if (result != null) onPicked(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_rounded, size: 16, color: luma.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected?.name ?? 'Pick a company (optional)',
                style: TextStyle(
                  color: selected == null ? luma.textMuted : luma.textPrimary,
                ),
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () => onPicked(null),
                child: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
              )
            else
              Icon(Icons.search_rounded, size: 16, color: luma.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MerchantSearchDialog extends StatefulWidget {
  const _MerchantSearchDialog({required this.merchants});
  final List<Merchant> merchants;

  @override
  State<_MerchantSearchDialog> createState() => _MerchantSearchDialogState();
}

class _MerchantSearchDialogState extends State<_MerchantSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final filtered = widget.merchants
        .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                style: TextStyle(color: luma.textPrimary),
                decoration: _inputDecoration(luma, hint: 'Search companies'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final m = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text(m.name,
                          style: TextStyle(color: luma.textPrimary)),
                      onTap: () => Navigator.of(context).pop(m),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });
  final List<Category> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: value,
          dropdownColor: luma.surface,
          hint: Text('No category',
              style: TextStyle(color: luma.textMuted, fontSize: 14)),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('No category',
                  style: TextStyle(color: luma.textMuted)),
            ),
            for (final c in categories)
              DropdownMenuItem<int?>(
                value: c.id,
                child: Row(
                  children: [
                    Icon(materialIcon(c.iconCodepoint),
                        size: 16, color: Color(c.colorValue)),
                    const SizedBox(width: 8),
                    Text(c.name, style: TextStyle(color: luma.textPrimary)),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PotDropdown extends StatelessWidget {
  const _PotDropdown({
    required this.pots,
    required this.value,
    required this.onChanged,
    this.hintNull = 'From main balance',
  });
  final List<Pot> pots;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String hintNull;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: value,
          dropdownColor: luma.surface,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(hintNull,
                  style: TextStyle(color: luma.textMuted)),
            ),
            for (final p in pots)
              DropdownMenuItem<int?>(
                value: p.id,
                child: Row(
                  children: [
                    Icon(materialIcon(p.iconCodepoint),
                        size: 16, color: Color(p.colorValue)),
                    const SizedBox(width: 8),
                    Text(p.name, style: TextStyle(color: luma.textPrimary)),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

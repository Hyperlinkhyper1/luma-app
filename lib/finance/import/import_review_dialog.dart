import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../logic/money.dart';
import '../../theme/luma_theme.dart';
import '../ui/lookups.dart';
import 'import_models.dart';

/// Second step of the import flow: review each parsed entry one-by-one,
/// choose a pot (and optionally category / merchant), then save it.
class ImportReviewDialog extends StatefulWidget {
  const ImportReviewDialog({
    super.key,
    required this.repo,
    required this.entries,
    required this.pots,
    required this.categories,
    required this.merchants,
  });

  final FinanceRepository repo;
  final List<ParsedBankEntry> entries;
  final List<Pot> pots;
  final List<Category> categories;
  final List<Merchant> merchants;

  @override
  State<ImportReviewDialog> createState() => _ImportReviewDialogState();
}

class _ImportReviewDialogState extends State<ImportReviewDialog> {
  int _index = 0;
  int? _potId;
  int? _categoryId;
  Merchant? _merchant;
  bool _saving = false;
  int _savedCount = 0;
  int _skippedCount = 0;

  ParsedBankEntry get _current => widget.entries[_index];

  @override
  void initState() {
    super.initState();
    _potId = widget.pots.isNotEmpty ? widget.pots.first.id : null;
    _autofillFromExisting();
  }

  void _autofillFromExisting() {
    final entry = _current;

    // Try to match merchant by name.
    if (entry.merchantName != null) {
      final match = widget.merchants
          .where((m) => m.name.toLowerCase() == entry.merchantName!.toLowerCase())
          .firstOrNull;
      if (match != null) {
        _merchant = match;
        if (match.defaultCategoryId != null) _categoryId = match.defaultCategoryId;
      }
    }

    // Try to match category by suggestion.
    if (_categoryId == null && entry.categorySuggestion != null) {
      final match = widget.categories
          .where((c) => c.name.toLowerCase() == entry.categorySuggestion!.toLowerCase())
          .firstOrNull;
      if (match != null) _categoryId = match.id;
    }
  }

  Future<void> _saveCurrent() async {
    setState(() => _saving = true);

    await widget.repo.addTransaction(
      kind: _current.isIncome ? TxnKind.income : TxnKind.expense,
      amountCents: _current.amountCents,
      date: _current.date,
      note: _current.description,
      potId: _current.isIncome ? null : _potId,
      merchantId: _merchant?.id,
      categoryId: _categoryId,
    );

    // The dialog may have been dismissed while the insert was in flight.
    if (!mounted) return;
    _savedCount++;
    _nextEntry();
  }

  void _skipCurrent() {
    _skippedCount++;
    _nextEntry();
  }

  void _nextEntry() {
    if (_index + 1 >= widget.entries.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _potId = widget.pots.isNotEmpty ? widget.pots.first.id : null;
      _categoryId = null;
      _merchant = null;
      _saving = false;
    });
    _autofillFromExisting();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = _current;
    final total = widget.entries.length;
    final progress = '${_index + 1} / $total';

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Review entry',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress,
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_savedCount saved · $_skippedCount skipped',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Entry card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: luma.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: luma.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LumaIconBadge(
                              icon: entry.isIncome
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              color: entry.isIncome ? luma.success : luma.danger,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.typeLabel,
                                    style: TextStyle(
                                      color: entry.isIncome ? luma.success : luma.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatCents(entry.amountCents),
                                    style: TextStyle(
                                      color: luma.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _DetailRow(label: 'Date', value: _formatDate(entry.date)),
                        if (entry.merchantName != null)
                          _DetailRow(label: 'Merchant', value: entry.merchantName!),
                        _DetailRow(label: 'Description', value: entry.description),
                        if (entry.iban != null)
                          _DetailRow(label: 'IBAN', value: entry.iban!),
                        if (entry.bic != null)
                          _DetailRow(label: 'BIC', value: entry.bic!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Assignment fields
                  if (!entry.isIncome) ...[
                    _FieldLabel('Pot'),
                    _PotDropdown(
                      pots: widget.pots,
                      value: _potId,
                      onChanged: (v) => setState(() => _potId = v),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _FieldLabel('Category'),
                  _CategoryDropdown(
                    categories: widget.categories,
                    value: _categoryId,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Company'),
                  _MerchantPicker(
                    merchants: widget.merchants,
                    selected: _merchant,
                    onPicked: (m) => setState(() {
                      _merchant = m;
                      if (m?.defaultCategoryId != null) _categoryId = m!.defaultCategoryId;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Buttons pinned at bottom
          const SizedBox(height: 16),
          Row(
            children: [
              LumaGhostButton(
                label: 'Skip',
                onTap: _skipCurrent,
              ),
              const Spacer(),
              LumaGhostButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add & next',
                icon: Icons.check_rounded,
                loading: _saving,
                onTap: _saveCurrent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
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

class _PotDropdown extends StatelessWidget {
  const _PotDropdown({
    required this.pots,
    required this.value,
    required this.onChanged,
  });
  final List<Pot> pots;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // Every expense must be assigned to a pot; if nothing has been picked
    // yet, fall back to the first pot the user has.
    final effectiveValue = (value != null && pots.any((p) => p.id == value))
        ? value
        : (pots.isNotEmpty ? pots.first.id : null);
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
          value: effectiveValue,
          dropdownColor: luma.surface,
          items: [
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

class _MerchantPicker extends StatelessWidget {
  const _MerchantPicker({
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
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search companies',
                  hintStyle: TextStyle(color: luma.textMuted),
                  filled: true,
                  fillColor: luma.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.accent),
                  ),
                ),
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

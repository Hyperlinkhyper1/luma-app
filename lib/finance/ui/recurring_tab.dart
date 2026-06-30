import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../finance_scope.dart';
import '../logic/money.dart';
import 'lookups.dart';

class RecurringTab extends StatelessWidget {
  const RecurringTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Pot>>(
      stream: repo.watchPots(),
      builder: (context, pots) => StreamData<List<Category>>(
        stream: repo.watchCategories(),
        builder: (context, categories) => StreamData<List<RecurringRule>>(
          stream: repo.watchRecurring(),
          builder: (context, rules) => StreamData<List<AllocationRule>>(
            stream: repo.watchAllocationRules(),
            builder: (context, allocations) => _RecurringBody(
              repo: repo,
              pots: pots,
              categories: categories,
              rules: rules,
              allocations: allocations,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecurringBody extends StatelessWidget {
  const _RecurringBody({
    required this.repo,
    required this.pots,
    required this.categories,
    required this.rules,
    required this.allocations,
  });
  final FinanceRepository repo;
  final List<Pot> pots;
  final List<Category> categories;
  final List<RecurringRule> rules;
  final List<AllocationRule> allocations;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final potById = {for (final p in pots) p.id: p};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: LumaGhostButton(
              label: 'Apply due now',
              icon: Icons.play_arrow_rounded,
              onTap: () async {
                final n = await repo.applyDue(DateTime.now());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Applied $n due entries.')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SectionHeader('Fixed costs & income'),
              const Spacer(),
              LumaPrimaryButton(
                label: 'Add',
                icon: Icons.add_rounded,
                onTap: () => _openRecurringEditor(context, repo, pots, categories),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            LumaCard(
              child: Text(
                'Add fixed costs like Spotify, rent, or your salary as income.',
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
            )
          else
            ...rules.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecurringRow(
                    rule: r,
                    onDelete: () => repo.deleteRecurring(r.id),
                  ),
                )),
          const SizedBox(height: 28),
          Row(
            children: [
              _SectionHeader('Automatic distribution'),
              const Spacer(),
              LumaPrimaryButton(
                label: 'Add',
                icon: Icons.add_rounded,
                onTap: pots.isEmpty
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Create a pot first.')),
                        )
                    : () => _openAllocationEditor(context, repo, pots),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Automatically move money from your main balance into pots, weekly or monthly.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (allocations.isEmpty)
            LumaCard(
              child: Text(
                'No distribution rules yet.',
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
            )
          else
            ...allocations.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AllocationRow(
                    rule: a,
                    pot: potById[a.potId],
                    onDelete: () => repo.deleteAllocationRule(a.id),
                  ),
                )),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.rule, required this.onDelete});
  final RecurringRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isIncome = rule.kind == TxnKind.income;
    final color = isIncome ? luma.success : luma.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          LumaIconBadge(
            icon: isIncome ? Icons.south_west_rounded : Icons.autorenew_rounded,
            color: color,
            size: 38,
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
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: luma.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.rule,
    required this.pot,
    required this.onDelete,
  });
  final AllocationRule rule;
  final Pot? pot;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final amountText = rule.mode == AllocMode.fixed
        ? formatCents(rule.valueCents)
        : '${(rule.percentBps / 100).toStringAsFixed(rule.percentBps % 100 == 0 ? 0 : 1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          LumaIconBadge(
            icon: pot != null
                ? materialIcon(pot!.iconCodepoint)
                : Icons.savings_rounded,
            color: pot != null ? Color(pot!.colorValue) : luma.accent,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('To ${pot?.name ?? 'pot'}',
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
          Text(amountText,
              style: TextStyle(color: luma.accent, fontWeight: FontWeight.w700)),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: luma.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
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

// ---- Editors ---------------------------------------------------------------

Future<void> _openRecurringEditor(BuildContext context, FinanceRepository repo,
    List<Pot> pots, List<Category> categories) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _RecurringEditor(repo: repo, pots: pots, categories: categories),
      ),
    ),
  );
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({
    required this.repo,
    required this.pots,
    required this.categories,
  });
  final FinanceRepository repo;
  final List<Pot> pots;
  final List<Category> categories;

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  TxnKind _kind = TxnKind.expense;
  Cadence _cadence = Cadence.monthly;
  DateTime _firstDue = DateTime.now();
  int? _potId;
  int? _categoryId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final cents = parseToCents(_amount.text);
    if (name.isEmpty || cents == null || cents <= 0) {
      setState(() => _error = 'Enter a name and a valid amount.');
      return;
    }
    await widget.repo.createRecurring(RecurringRulesCompanion.insert(
      name: name,
      kind: _kind,
      amountCents: cents,
      cadence: _cadence,
      nextDue: _firstDue,
      potId: Value(_kind == TxnKind.expense ? _potId : null),
      categoryId: Value(_kind == TxnKind.expense ? _categoryId : null),
    ));
    if (mounted) Navigator.pop(context);
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
          Text('New recurring entry',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          LumaSegmentedTabs(
            tabs: const ['Fixed cost', 'Fixed income'],
            selectedIndex: isExpense ? 0 : 1,
            onSelect: (i) =>
                setState(() => _kind = i == 0 ? TxnKind.expense : TxnKind.income),
          ),
          const SizedBox(height: 16),
          _editorField(luma, 'Name', _name, hint: 'e.g. Spotify'),
          const SizedBox(height: 12),
          _editorField(luma, 'Amount', _amount,
              hint: '0,00', prefix: '€ ', number: true),
          const SizedBox(height: 12),
          _label(luma, 'Repeats'),
          _CadenceToggle(
            cadence: _cadence,
            onChanged: (c) => setState(() => _cadence = c),
          ),
          const SizedBox(height: 12),
          _label(luma, 'First due date'),
          _DateRow(date: _firstDue, onChanged: (d) => setState(() => _firstDue = d)),
          if (isExpense) ...[
            const SizedBox(height: 12),
            _label(luma, 'Pot (optional)'),
            _SimpleDropdown<int?>(
              value: _potId,
              hintNull: 'From main balance',
              items: {
                for (final p in widget.pots) p.id: p.name,
              },
              onChanged: (v) => setState(() => _potId = v),
            ),
            const SizedBox(height: 12),
            _label(luma, 'Category (optional)'),
            _SimpleDropdown<int?>(
              value: _categoryId,
              hintNull: 'No category',
              items: {
                for (final c in widget.categories) c.id: c.name,
              },
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          _editorActions(context, _save, 'Add'),
        ],
      ),
    );
  }
}

Future<void> _openAllocationEditor(
    BuildContext context, FinanceRepository repo, List<Pot> pots) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _AllocationEditor(repo: repo, pots: pots),
      ),
    ),
  );
}

class _AllocationEditor extends StatefulWidget {
  const _AllocationEditor({required this.repo, required this.pots});
  final FinanceRepository repo;
  final List<Pot> pots;

  @override
  State<_AllocationEditor> createState() => _AllocationEditorState();
}

class _AllocationEditorState extends State<_AllocationEditor> {
  late int _potId = widget.pots.first.id;
  AllocMode _mode = AllocMode.fixed;
  Cadence _cadence = Cadence.monthly;
  DateTime _firstDue = DateTime.now();
  final _value = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int valueCents = 0;
    int percentBps = 0;
    if (_mode == AllocMode.fixed) {
      final cents = parseToCents(_value.text);
      if (cents == null || cents <= 0) {
        setState(() => _error = 'Enter a valid amount.');
        return;
      }
      valueCents = cents;
    } else {
      final pct = double.tryParse(_value.text.replaceAll(',', '.'));
      if (pct == null || pct <= 0 || pct > 100) {
        setState(() => _error = 'Enter a percentage between 0 and 100.');
        return;
      }
      percentBps = (pct * 100).round();
    }
    await widget.repo.createAllocationRule(AllocationRulesCompanion.insert(
      potId: _potId,
      mode: _mode,
      cadence: _cadence,
      nextDue: _firstDue,
      valueCents: Value(valueCents),
      percentBps: Value(percentBps),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New distribution rule',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _label(luma, 'Pot'),
          _SimpleDropdown<int>(
            value: _potId,
            items: {for (final p in widget.pots) p.id: p.name},
            onChanged: (v) => setState(() => _potId = v as int),
          ),
          const SizedBox(height: 12),
          _label(luma, 'Amount type'),
          LumaSegmentedTabs(
            tabs: const ['Fixed €', '% of balance'],
            selectedIndex: _mode == AllocMode.fixed ? 0 : 1,
            onSelect: (i) =>
                setState(() => _mode = i == 0 ? AllocMode.fixed : AllocMode.percent),
          ),
          const SizedBox(height: 12),
          _editorField(
            luma,
            _mode == AllocMode.fixed ? 'Amount per period' : 'Percent',
            _value,
            hint: _mode == AllocMode.fixed ? '0,00' : 'e.g. 25',
            prefix: _mode == AllocMode.fixed ? '€ ' : null,
            number: true,
          ),
          const SizedBox(height: 12),
          _label(luma, 'Repeats'),
          _CadenceToggle(
            cadence: _cadence,
            onChanged: (c) => setState(() => _cadence = c),
          ),
          const SizedBox(height: 12),
          _label(luma, 'First run date'),
          _DateRow(date: _firstDue, onChanged: (d) => setState(() => _firstDue = d)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          _editorActions(context, _save, 'Add rule'),
        ],
      ),
    );
  }
}

// ---- Small shared editor widgets ------------------------------------------

Widget _label(LumaPalette luma, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );

Widget _editorField(
  LumaPalette luma,
  String label,
  TextEditingController controller, {
  String? hint,
  String? prefix,
  bool number = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(luma, label),
      TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(color: luma.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: luma.textMuted),
          prefixText: prefix,
          prefixStyle: TextStyle(color: luma.textSecondary),
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
      ),
    ],
  );
}

Widget _editorActions(BuildContext context, VoidCallback onSave, String label) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      LumaGhostButton(label: 'Cancel', onTap: () => Navigator.pop(context)),
      const SizedBox(width: 10),
      LumaPrimaryButton(label: label, icon: Icons.check_rounded, onTap: onSave),
    ],
  );
}

class _CadenceToggle extends StatelessWidget {
  const _CadenceToggle({required this.cadence, required this.onChanged});
  final Cadence cadence;
  final ValueChanged<Cadence> onChanged;

  @override
  Widget build(BuildContext context) {
    return LumaSegmentedTabs(
      tabs: const ['Weekly', 'Monthly'],
      selectedIndex: cadence == Cadence.weekly ? 0 : 1,
      onSelect: (i) => onChanged(i == 0 ? Cadence.weekly : Cadence.monthly),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onChanged});
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
            Icon(Icons.calendar_today_rounded,
                size: 16, color: luma.textSecondary),
            const SizedBox(width: 10),
            Text(_shortDate(date), style: TextStyle(color: luma.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _SimpleDropdown<T> extends StatelessWidget {
  const _SimpleDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintNull,
  });
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final String? hintNull;

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
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: luma.surface,
          items: [
            if (hintNull != null)
              DropdownMenuItem<T>(
                value: null as T,
                child: Text(hintNull!, style: TextStyle(color: luma.textMuted)),
              ),
            for (final entry in items.entries)
              DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value,
                    style: TextStyle(color: luma.textPrimary)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
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

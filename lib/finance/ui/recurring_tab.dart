import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../finance_scope.dart';
import '../logic/money.dart';
import 'finance_form.dart';
import 'lookups.dart';
import 'subscription_suggestions.dart';

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
            builder: (context, allocations) => StreamData<List<RecurringRule>>(
              stream: repo.watchDueBills(),
              builder: (context, dueBills) => _RecurringBody(
                repo: repo,
                pots: pots,
                categories: categories,
                rules: rules,
                allocations: allocations,
                dueBills: dueBills,
              ),
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
    required this.dueBills,
  });
  final FinanceRepository repo;
  final List<Pot> pots;
  final List<Category> categories;
  final List<RecurringRule> rules;
  final List<AllocationRule> allocations;
  final List<RecurringRule> dueBills;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final potById = {for (final p in pots) p.id: p};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: LumaGhostButton(
              label: t.financeRecurringApplyDue,
              icon: Icons.play_arrow_rounded,
              onTap: () async {
                final n = await repo.applyDue(DateTime.now());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.financeRecurringApplied(n))),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          if (dueBills.isNotEmpty) ...[
            _BillsDueSoonCard(bills: dueBills),
            const SizedBox(height: 20),
          ],
          SubscriptionSuggestions(repo: repo, rules: rules),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _SectionHeader(t.financeRecurringFixedHeader),
              LumaPrimaryButton(
                label: t.commonAdd,
                icon: Icons.add_rounded,
                onTap: () =>
                    _openRecurringEditor(context, repo, pots, categories),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            LumaCard(
              child: Text(
                t.financeRecurringEmpty,
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
            )
          else
            ...rules.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RecurringRow(
                  rule: r,
                  onDelete: () => repo.deleteRecurring(r.id),
                ),
              ),
            ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _SectionHeader(t.financeRecurringAutoHeader),
              LumaPrimaryButton(
                label: t.commonAdd,
                icon: Icons.add_rounded,
                onTap: pots.isEmpty
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.financeRecurringCreatePotFirst)),
                      )
                    : () => _openAllocationEditor(context, repo, pots),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.financeRecurringAutoHint,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (allocations.isEmpty)
            LumaCard(
              child: Text(
                t.financeRecurringNoRules,
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
            )
          else
            ...allocations.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AllocationRow(
                  rule: a,
                  pot: potById[a.potId],
                  onDelete: () => repo.deleteAllocationRule(a.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A prominent reminder banner for bills due within the next 7 days — the
/// closest thing to a push notification this app can do without a
/// platform notification plugin, but shown wherever the user actually
/// looks (Recurring tab), not buried.
class _BillsDueSoonCard extends StatelessWidget {
  const _BillsDueSoonCard({required this.bills});
  final List<RecurringRule> bills;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                size: 18,
                color: luma.danger,
              ),
              const SizedBox(width: 8),
              Text(
                t.financeRecurringBillsDueSoon(bills.length),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final bill in bills)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bill.name,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                  ),
                  Text(
                    _dueLabel(t, bill.nextDue),
                    style: TextStyle(
                      color: luma.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

String _dueLabel(L t, DateTime due) {
  final today = DateTime.now();
  final days = DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (days < 0) return t.financeRecurringOverdue;
  if (days == 0) return t.financeRecurringDueToday;
  if (days == 1) return t.financeRecurringDueTomorrow;
  return t.financeRecurringDueInDays(days);
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.rule, required this.onDelete});
  final RecurringRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final isIncome = rule.kind == TxnKind.income;
    final color = isIncome ? luma.success : luma.danger;
    final cadence = rule.cadence == Cadence.weekly
        ? t.financeRecurringWeekly
        : t.financeRecurringMonthly;
    final nextDate = shortDate(rule.nextDue);
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
                Text(
                  rule.name,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rule.isBill
                      ? t.financeRecurringRowBillSubtitle(
                          cadence,
                          rule.reminderDaysBefore,
                          nextDate,
                        )
                      : t.financeRecurringRowSubtitle(cadence, nextDate),
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
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: luma.textMuted,
            ),
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
    final t = L.of(context);
    final amountText = rule.mode == AllocMode.fixed
        ? formatCents(rule.valueCents)
        : '${(rule.percentBps / 100).toStringAsFixed(rule.percentBps % 100 == 0 ? 0 : 1)}%';
    final cadence = rule.cadence == Cadence.weekly
        ? t.financeRecurringWeekly
        : t.financeRecurringMonthly;
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
                Text(
                  t.financeRecurringToPot(
                    pot?.name ?? t.financeRecurringPotFallback,
                  ),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.financeRecurringRowSubtitle(cadence, shortDate(rule.nextDue)),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amountText,
            style: TextStyle(color: luma.accent, fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: luma.textMuted,
            ),
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

Future<void> _openRecurringEditor(
  BuildContext context,
  FinanceRepository repo,
  List<Pot> pots,
  List<Category> categories,
) {
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
  bool _isBill = false;
  final _reminderDays = TextEditingController(text: '7');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _reminderDays.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = L.of(context);
    final name = _name.text.trim();
    final cents = parseToCents(_amount.text);
    if (name.isEmpty || cents == null || cents <= 0) {
      setState(() => _error = t.financeRecurringEnterNameAndAmount);
      return;
    }
    final isBill = _kind == TxnKind.expense && _isBill;
    int reminderDays = 7;
    if (isBill) {
      final parsed = int.tryParse(_reminderDays.text.trim());
      if (parsed == null || parsed < 0) {
        setState(() => _error = t.financeRecurringInvalidReminder);
        return;
      }
      reminderDays = parsed;
    }
    await widget.repo.createRecurring(
      RecurringRulesCompanion.insert(
        name: name,
        kind: _kind,
        amountCents: cents,
        cadence: _cadence,
        nextDue: _firstDue,
        potId: Value(_potId),
        categoryId: Value(_kind == TxnKind.expense ? _categoryId : null),
        isBill: Value(isBill),
        reminderDaysBefore: Value(reminderDays),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final isExpense = _kind == TxnKind.expense;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.financeRecurringNewEntry,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          LumaSegmentedTabs(
            tabs: [t.financeRecurringFixedCost, t.financeRecurringFixedIncome],
            selectedIndex: isExpense ? 0 : 1,
            onSelect: (i) => setState(
              () => _kind = i == 0 ? TxnKind.expense : TxnKind.income,
            ),
          ),
          const SizedBox(height: 16),
          _editorField(luma, t.commonName, _name, hint: t.financeRecurringNameHint),
          const SizedBox(height: 12),
          _editorField(
            luma,
            t.commonAmount,
            _amount,
            hint: '0,00',
            prefix: '€ ',
            number: true,
          ),
          const SizedBox(height: 12),
          _label(luma, t.financeRecurringRepeats),
          _CadenceToggle(
            cadence: _cadence,
            onChanged: (c) => setState(() => _cadence = c),
          ),
          const SizedBox(height: 12),
          _label(luma, t.financeRecurringFirstDue),
          _DateRow(
            date: _firstDue,
            onChanged: (d) => setState(() => _firstDue = d),
          ),
          const SizedBox(height: 12),
          _label(luma, t.financeRecurringPotOptional),
          _SimpleDropdown<int?>(
            value: _potId,
            hintNull: isExpense
                ? t.financeRecurringFromMain
                : t.financeRecurringToMain,
            items: {for (final p in widget.pots) p.id: p.name},
            onChanged: (v) => setState(() => _potId = v),
          ),
          if (isExpense) ...[
            const SizedBox(height: 12),
            _label(luma, t.financeRecurringCategoryOptional),
            _SimpleDropdown<int?>(
              value: _categoryId,
              hintNull: t.financeRecurringNoCategory,
              items: {for (final c in widget.categories) c.id: c.name},
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _isBill = !_isBill),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isBill,
                      onChanged: (v) => setState(() => _isBill = v ?? false),
                      activeColor: luma.accent,
                    ),
                    Expanded(
                      child: Text(
                        t.financeRecurringTreatAsBill,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isBill) ...[
              const SizedBox(height: 8),
              _editorField(
                luma,
                t.financeRecurringRemindDays,
                _reminderDays,
                hint: '7',
                number: true,
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          _editorActions(context, _save, t.commonAdd),
        ],
      ),
    );
  }
}

Future<void> _openAllocationEditor(
  BuildContext context,
  FinanceRepository repo,
  List<Pot> pots,
) {
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
    final t = L.of(context);
    int valueCents = 0;
    int percentBps = 0;
    if (_mode == AllocMode.fixed) {
      final cents = parseToCents(_value.text);
      if (cents == null || cents <= 0) {
        setState(() => _error = t.financeRecurringEnterValidAmount);
        return;
      }
      valueCents = cents;
    } else {
      final pct = double.tryParse(_value.text.replaceAll(',', '.'));
      if (pct == null || pct <= 0 || pct > 100) {
        setState(() => _error = t.financeRecurringPercentRange);
        return;
      }
      percentBps = (pct * 100).round();
    }
    await widget.repo.createAllocationRule(
      AllocationRulesCompanion.insert(
        potId: _potId,
        mode: _mode,
        cadence: _cadence,
        nextDue: _firstDue,
        valueCents: Value(valueCents),
        percentBps: Value(percentBps),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.financeRecurringNewRule,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _label(luma, t.financeRecurringPot),
          _SimpleDropdown<int>(
            value: _potId,
            items: {for (final p in widget.pots) p.id: p.name},
            onChanged: (v) => setState(() => _potId = v as int),
          ),
          const SizedBox(height: 12),
          _label(luma, t.financeRecurringAmountType),
          LumaSegmentedTabs(
            tabs: [t.financeRecurringFixedEuro, t.financeRecurringPercentOfBalance],
            selectedIndex: _mode == AllocMode.fixed ? 0 : 1,
            onSelect: (i) => setState(
              () => _mode = i == 0 ? AllocMode.fixed : AllocMode.percent,
            ),
          ),
          const SizedBox(height: 12),
          _editorField(
            luma,
            _mode == AllocMode.fixed
                ? t.financeRecurringAmountPerPeriod
                : t.financeRecurringPercent,
            _value,
            hint: _mode == AllocMode.fixed ? '0,00' : t.financeRecurringPercentHint,
            prefix: _mode == AllocMode.fixed ? '€ ' : null,
            number: true,
          ),
          const SizedBox(height: 12),
          _label(luma, t.financeRecurringRepeats),
          _CadenceToggle(
            cadence: _cadence,
            onChanged: (c) => setState(() => _cadence = c),
          ),
          const SizedBox(height: 12),
          _label(luma, t.financeRecurringFirstRun),
          _DateRow(
            date: _firstDue,
            onChanged: (d) => setState(() => _firstDue = d),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          _editorActions(context, _save, t.financeRecurringAddRule),
        ],
      ),
    );
  }
}

// ---- Small shared editor widgets ------------------------------------------

Widget _label(LumaPalette luma, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: TextStyle(
      color: luma.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
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
      LumaGhostButton(
        label: L.of(context).commonCancel,
        onTap: () => Navigator.pop(context),
      ),
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
    final t = L.of(context);
    return LumaSegmentedTabs(
      tabs: [t.financeRecurringWeekly, t.financeRecurringMonthly],
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
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: luma.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(shortDate(date), style: TextStyle(color: luma.textPrimary)),
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
                child: Text(
                  entry.value,
                  style: TextStyle(color: luma.textPrimary),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

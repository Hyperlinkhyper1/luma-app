import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../finance_scope.dart';
import '../logic/money.dart';
import '../logic/planning.dart';
import 'finance_form.dart';

/// Loans and IOUs: what's left on each, a payoff projection, and a payment
/// log. Debts count toward net worth on the overview.
class DebtsTab extends StatelessWidget {
  const DebtsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Debt>>(
      stream: repo.watchDebts(),
      builder: (context, debts) => StreamData<List<DebtPayment>>(
        stream: repo.watchDebtPayments(),
        builder: (context, payments) =>
            _DebtsBody(repo: repo, debts: debts, payments: payments),
      ),
    );
  }
}

class _DebtsBody extends StatelessWidget {
  const _DebtsBody({
    required this.repo,
    required this.debts,
    required this.payments,
  });

  final FinanceRepository repo;
  final List<Debt> debts;
  final List<DebtPayment> payments;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    var owe = 0, owed = 0;
    for (final d in debts) {
      final balance = debtBalanceCents(d, payments);
      if (balance <= 0) continue;
      if (d.direction == DebtDirection.owe) {
        owe += balance;
      } else {
        owed += balance;
      }
    }
    // Open debts first, biggest first; settled ones sink to the bottom.
    final sorted = [...debts]
      ..sort((a, b) {
        final ba = debtBalanceCents(a, payments);
        final bb = debtBalanceCents(b, payments);
        if ((ba <= 0) != (bb <= 0)) return ba <= 0 ? 1 : -1;
        return bb.compareTo(ba);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 16,
                children: [
                  _Total(
                    label: L.of(context).financeYouOwe,
                    cents: owe,
                    color: luma.danger,
                  ),
                  _Total(
                    label: L.of(context).financeOwedToYou,
                    cents: owed,
                    color: luma.success,
                  ),
                ],
              ),
              LumaPrimaryButton(
                label: L.of(context).financeAddDebt,
                icon: Icons.add_rounded,
                onTap: () =>
                    showFinanceDialog<void>(context, _DebtEditor(repo: repo)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: debts.isEmpty
                ? LumaEmptyState(
                    icon: Icons.handshake_rounded,
                    title: L.of(context).financeDebtsEmpty,
                    subtitle:
                        L.of(context).financeDebtsEmptySubtitle,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _DebtCard(
                      repo: repo,
                      debt: sorted[i],
                      payments: payments
                          .where((p) => p.debtId == sorted[i].id)
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.cents, required this.color});
  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        Text(
          formatCents(cents),
          style: TextStyle(
            color: cents == 0 ? luma.textPrimary : color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.repo,
    required this.debt,
    required this.payments,
  });

  final FinanceRepository repo;
  final Debt debt;
  final List<DebtPayment> payments;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final balance = debtBalanceCents(debt, payments);
    final owe = debt.direction == DebtDirection.owe;
    final settled = balance <= 0;
    final color = owe ? luma.danger : luma.success;
    final paidFraction = debt.principalCents <= 0
        ? 1.0
        : (1 - balance / debt.principalCents).clamp(0.0, 1.0);

    final String outlook;
    Color outlookColor = luma.textMuted;
    if (settled) {
      outlook = owe ? t.financePaidOff : t.financeFullyRepaid;
      outlookColor = luma.success;
    } else if (debt.monthlyPaymentCents <= 0) {
      outlook = t.financeDebtsSetMonthlyPayment;
    } else {
      final p = projectPayoff(
        balanceCents: balance,
        interestBps: debt.interestBps,
        monthlyPaymentCents: debt.monthlyPaymentCents,
        from: DateTime.now(),
      );
      if (p == null) {
        outlook = t.financeDebtsDoesNotCoverInterest(
          formatCents(debt.monthlyPaymentCents),
        );
        outlookColor = luma.danger;
      } else {
        final interest = p.totalInterestCents > 0
            ? ' · ${t.financeDebtsInterest(formatCents(p.totalInterestCents))}'
            : '';
        outlook = t.financeDebtsPayoffOutlook(
          owe ? t.financePaidOff : t.financeRepaid,
          monthYear(p.payoffDate),
          p.months,
          interest,
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaIconBadge(
                icon: owe
                    ? Icons.account_balance_rounded
                    : Icons.volunteer_activism_rounded,
                color: settled ? luma.textMuted : color,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        owe ? t.financeYouOwe : t.financeOwedToYou,
                        if (debt.interestBps > 0)
                          t.financeDebtsInterestRate(
                            (debt.interestBps / 100).toStringAsFixed(2),
                          ),
                        if (debt.monthlyPaymentCents > 0)
                          t.financeDebtsMonthlyAmount(
                            formatCents(debt.monthlyPaymentCents),
                          ),
                      ].join(' · '),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCents(balance < 0 ? 0 : balance),
                    style: TextStyle(
                      color: settled ? luma.textMuted : luma.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    t.financeDebtsOfTotal(formatCents(debt.principalCents)),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: luma.textMuted,
                ),
                color: luma.surface,
                onSelected: (v) => _onMenu(context, v, balance),
                itemBuilder: (context) => [
                  _item(
                    'pay',
                    Icons.payments_rounded,
                    owe ? t.financeDebtsLogPayment : t.financeDebtsLogRepayment,
                    luma,
                  ),
                  _item(
                    'adjust',
                    Icons.tune_rounded,
                    t.financeDebtsUpdateBalance,
                    luma,
                  ),
                  _item(
                    'history',
                    Icons.history_rounded,
                    t.financeDebtsPaymentHistory,
                    luma,
                  ),
                  _item('edit', Icons.edit_rounded, t.financeEntryEdit, luma),
                  _item(
                    'delete',
                    Icons.delete_outline_rounded,
                    t.commonDelete,
                    luma,
                    danger: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: paidFraction,
              minHeight: 6,
              backgroundColor: luma.surfaceHover,
              valueColor: AlwaysStoppedAnimation(
                settled ? luma.success : luma.accent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            owe
                ? t.financeDebtsProgressPaid(
                    '${(paidFraction * 100).floor()}',
                    outlook,
                  )
                : t.financeDebtsProgressRepaid(
                    '${(paidFraction * 100).floor()}',
                    outlook,
                  ),
            style: TextStyle(color: outlookColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String action, int balance) async {
    switch (action) {
      case 'pay':
        await showFinanceDialog<void>(
          context,
          _PaymentEditor(
            repo: repo,
            debt: debt,
            suggestedCents: debt.monthlyPaymentCents,
          ),
        );
      case 'adjust':
        await showFinanceDialog<void>(
          context,
          _AdjustEditor(repo: repo, debt: debt, current: balance),
        );
      case 'history':
        await showFinanceDialog<void>(
          context,
          _History(repo: repo, debt: debt, payments: payments),
          maxWidth: 480,
        );
      case 'edit':
        await showFinanceDialog<void>(
          context,
          _DebtEditor(repo: repo, debt: debt),
        );
      case 'delete':
        final ok = await confirmFinanceDelete(
          context,
          L.of(context).financeDebtsDeleteTitle(debt.name),
          L.of(context).financeDebtsDeleteMessage,
        );
        if (ok) await repo.deleteDebt(debt.id);
    }
  }
}

PopupMenuItem<String> _item(
  String value,
  IconData icon,
  String label,
  LumaPalette luma, {
  bool danger = false,
}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: danger ? luma.danger : luma.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: luma.textPrimary)),
      ],
    ),
  );
}

String _centsText(int cents) =>
    cents == 0 ? '' : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

class _DebtEditor extends StatefulWidget {
  const _DebtEditor({required this.repo, this.debt});
  final FinanceRepository repo;
  final Debt? debt;

  @override
  State<_DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<_DebtEditor> {
  late final _name = TextEditingController(text: widget.debt?.name ?? '');
  late final _principal = TextEditingController(
    text: _centsText(widget.debt?.principalCents ?? 0),
  );
  late final _interest = TextEditingController(
    text: (widget.debt?.interestBps ?? 0) == 0
        ? ''
        : (widget.debt!.interestBps / 100).toString().replaceAll('.', ','),
  );
  late final _monthly = TextEditingController(
    text: _centsText(widget.debt?.monthlyPaymentCents ?? 0),
  );
  late final _note = TextEditingController(text: widget.debt?.note ?? '');
  late DebtDirection _direction = widget.debt?.direction ?? DebtDirection.owe;
  late DateTime _start = widget.debt?.startDate ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _principal, _interest, _monthly, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final principal = parseToCents(_principal.text);
    final interestText = _interest.text.trim().replaceAll(',', '.');
    final interest = interestText.isEmpty ? 0.0 : double.tryParse(interestText);
    final monthlyText = _monthly.text.trim();
    final monthly = monthlyText.isEmpty ? 0 : parseToCents(monthlyText);
    if (name.isEmpty || principal == null || principal <= 0) {
      setState(() => _error = L.of(context).financeDebtsNameAmountRequired);
      return;
    }
    if (interest == null || interest < 0 || monthly == null || monthly < 0) {
      setState(() => _error = L.of(context).financeDebtsNumbersRequired);
      return;
    }
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final bps = (interest * 100).round();
    final existing = widget.debt;
    if (existing == null) {
      await widget.repo.createDebt(
        DebtsCompanion.insert(
          name: name,
          direction: _direction,
          principalCents: principal,
          interestBps: Value(bps),
          monthlyPaymentCents: Value(monthly),
          startDate: _start,
          note: Value(note),
        ),
      );
    } else {
      await widget.repo.updateDebt(
        existing.copyWith(
          name: name,
          direction: _direction,
          principalCents: principal,
          interestBps: bps,
          monthlyPaymentCents: monthly,
          startDate: _start,
          note: Value(note),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return FinanceDialogScaffold(
      title: widget.debt == null ? t.financeAddDebt : t.financeEditDebt,
      confirmLabel: widget.debt == null ? t.commonAdd : t.commonSave,
      onConfirm: _save,
      error: _error,
      children: [
        LumaSegmentedTabs(
          tabs: [t.financeDebtsIOwe, t.financeDebtsOwedToMe],
          selectedIndex: _direction == DebtDirection.owe ? 0 : 1,
          onSelect: (i) => setState(
            () => _direction = i == 0 ? DebtDirection.owe : DebtDirection.owed,
          ),
        ),
        const SizedBox(height: 14),
        FinanceField(
          label: L.of(context).commonName,
          controller: _name,
          autofocus: widget.debt == null,
          hint: _direction == DebtDirection.owe
              ? t.financeDebtsNameHintOwe
              : t.financeDebtsNameHintOwed,
        ),
        const SizedBox(height: 12),
        FinanceField(
          label: L.of(context).financeDebtsOriginalAmount,
          controller: _principal,
          hint: '0,00',
          prefix: '€ ',
          number: true,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FinanceField(
                label: L.of(context).financeDebtsInterestOptional,
                controller: _interest,
                hint: '0',
                suffix: t.financeDebtsPerYear,
                number: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FinanceField(
                label: L.of(context).financeDebtsMonthlyPayment,
                controller: _monthly,
                hint: '0,00',
                prefix: '€ ',
                number: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FinanceDateField(
          label: L.of(context).financeDebtsStarted,
          date: _start,
          onChanged: (d) => setState(() => _start = d),
        ),
        const SizedBox(height: 12),
        FinanceField(
          label: L.of(context).financeNoteOptional,
          controller: _note,
        ),
      ],
    );
  }
}

class _PaymentEditor extends StatefulWidget {
  const _PaymentEditor({
    required this.repo,
    required this.debt,
    required this.suggestedCents,
  });
  final FinanceRepository repo;
  final Debt debt;
  final int suggestedCents;

  @override
  State<_PaymentEditor> createState() => _PaymentEditorState();
}

class _PaymentEditorState extends State<_PaymentEditor> {
  late final _amount = TextEditingController(
    text: _centsText(widget.suggestedCents),
  );
  DateTime _date = DateTime.now();
  bool _book = true;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = parseToCents(_amount.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = L.of(context).financeDebtsAmountAboveZero);
      return;
    }
    await widget.repo.addDebtPayment(
      debt: widget.debt,
      amountCents: cents,
      date: _date,
      bookInLedger: _book,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final owe = widget.debt.direction == DebtDirection.owe;
    return FinanceDialogScaffold(
      title: owe
          ? L.of(context).financeDebtsPaymentOn(widget.debt.name)
          : L.of(context).financeDebtsRepaymentFrom(widget.debt.name),
      confirmLabel: L.of(context).financeDebtsLog,
      onConfirm: _save,
      error: _error,
      children: [
        FinanceField(
          label: L.of(context).commonAmount,
          controller: _amount,
          autofocus: true,
          hint: '0,00',
          prefix: '€ ',
          number: true,
        ),
        const SizedBox(height: 12),
        FinanceDateField(
          label: L.of(context).commonDate,
          date: _date,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 8),
        FinanceCheckRow(
          value: _book,
          onChanged: (v) => setState(() => _book = v),
          label: owe
              ? L.of(context).financeDebtsBookExpense
              : L.of(context).financeDebtsBookIncome,
        ),
      ],
    );
  }
}

class _AdjustEditor extends StatefulWidget {
  const _AdjustEditor({
    required this.repo,
    required this.debt,
    required this.current,
  });
  final FinanceRepository repo;
  final Debt debt;
  final int current;

  @override
  State<_AdjustEditor> createState() => _AdjustEditorState();
}

class _AdjustEditorState extends State<_AdjustEditor> {
  late final _amount = TextEditingController(
    text: widget.current <= 0 ? '0' : _centsText(widget.current),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = parseToCents(_amount.text);
    if (cents == null || cents < 0) {
      setState(() => _error = L.of(context).financeDebtsEnterBalance);
      return;
    }
    await widget.repo.adjustDebtBalance(widget.debt, cents);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return FinanceDialogScaffold(
      title: L.of(context).financeDebtsUpdateBalance,
      confirmLabel: L.of(context).commonSave,
      onConfirm: _save,
      error: _error,
      children: [
        Text(
          L.of(context).financeDebtsAdjustExplainer,
          style: TextStyle(color: luma.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        FinanceField(
          label: L.of(context).financeDebtsCurrentBalance,
          controller: _amount,
          autofocus: true,
          prefix: '€ ',
          number: true,
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({
    required this.repo,
    required this.debt,
    required this.payments,
  });
  final FinanceRepository repo;
  final Debt debt;
  final List<DebtPayment> payments;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).financeDebtsHistoryTitle(debt.name),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Text(
              L.of(context).financeDebtsNoPayments,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in payments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.note ??
                            (p.transactionId != null
                                ? L.of(context).financeDebtsPaymentBooked
                                : L.of(context).financeDebtsPayment),
                        style: TextStyle(color: luma.textPrimary),
                      ),
                      subtitle: Text(
                        longDate(p.date),
                        style: TextStyle(color: luma.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatSignedCents(-p.amountCents),
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            tooltip: L.of(context).commonDelete,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: luma.textMuted,
                            ),
                            onPressed: () async {
                              await repo.deleteDebtPayment(p);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: LumaGhostButton(
              label: L.of(context).commonClose,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

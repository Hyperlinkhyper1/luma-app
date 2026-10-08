import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../import/bank_selection_dialog.dart';
import '../import/import_models.dart';
import '../import/import_review_dialog.dart';
import '../logic/money.dart';
import '../logic/statement_reconciliation.dart';
import 'add_transaction_sheet.dart';
import 'finance_form.dart';

Future<void> showStatementReconciliation(
  BuildContext context, {
  required FinanceRepository repo,
}) => showFinanceDialog<void>(
  context,
  StatementReconciliationDialog(repo: repo),
  maxWidth: 760,
);

class StatementReconciliationDialog extends StatefulWidget {
  const StatementReconciliationDialog({super.key, required this.repo});
  final FinanceRepository repo;

  @override
  State<StatementReconciliationDialog> createState() =>
      _StatementReconciliationDialogState();
}

class _StatementReconciliationDialogState
    extends State<StatementReconciliationDialog> {
  final _opening = TextEditingController();
  final _closing = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  late final Stream<List<FinanceTransaction>> _transactions;
  late final Stream<List<Merchant>> _merchants;
  List<ParsedBankEntry>? _entries;
  final _excluded = <int>{};
  bool _checked = false;
  bool? _invalidDates;

  String? get _error => switch (_invalidDates) {
    true => L.of(context).financeReconEndBeforeStart,
    false => L.of(context).financeReconInvalidBalances,
    null => null,
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month);
    _end = DateTime(now.year, now.month, now.day);
    _transactions = widget.repo.watchTransactions();
    _merchants = widget.repo.watchMerchants();
    _opening.addListener(_invalidate);
    _closing.addListener(_invalidate);
  }

  void _invalidate() {
    setState(() {
      _checked = false;
      _invalidDates = null;
    });
  }

  @override
  void dispose() {
    _opening.dispose();
    _closing.dispose();
    super.dispose();
  }

  int? _balance(String input) {
    // Restrict input before using the common parser (reject NaN/infinity).
    if (input.length > 24 ||
        !RegExp(r'^[+\-€\d\s.,]+$').hasMatch(input.trim())) {
      return null;
    }
    return parseToCents(input);
  }

  void _compare() {
    setState(() {
      _invalidDates = _end.isBefore(_start)
          ? true
          : _balance(_opening.text) == null || _balance(_closing.text) == null
          ? false
          : null;
      _checked = _error == null;
    });
  }

  Future<void> _loadStatement() async {
    final entries = await pickStatementEntries(context);
    if (!mounted || entries == null || entries.isEmpty) return;
    setState(() {
      _entries = entries;
      _checked = false;
      _invalidDates = null;
    });
  }

  Future<void> _edit(FinanceTransaction transaction) async {
    final repo = widget.repo;
    final merchants = await repo.allMerchants();
    final categories = await repo.allCategories();
    final pots = await repo.allPots();
    if (!mounted) return;
    await showAddTransaction(
      context,
      repo: repo,
      merchants: merchants,
      categories: categories,
      pots: pots,
      existing: transaction,
    );
  }

  Future<void> _reviewMissing(List<ParsedBankEntry> entries) async {
    final repo = widget.repo;
    final merchants = await repo.allMerchants();
    final categories = await repo.allCategories();
    var pots = await repo.allPots();
    if (!mounted) return;
    if (pots.isEmpty) {
      await repo.createPot(
        name: L.of(context).financeReconMainPot,
        colorValue: 0xFF7C5AD9,
        iconCodepoint: Icons.savings_rounded.codePoint,
      );
      pots = await repo.allPots();
    }
    if (!mounted) return;
    await showFinanceDialog<void>(
      context,
      SizedBox(
        height: 650,
        child: ImportReviewDialog(
          repo: repo,
          entries: entries,
          pots: pots,
          categories: categories,
          merchants: merchants,
        ),
      ),
      maxWidth: 520,
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).financeReconTitle,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    L.of(context).financeReconIntro,
                    style: TextStyle(color: luma.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  FinanceDateField(
                    label: L.of(context).financeReconStartDate,
                    date: _start,
                    onChanged: (date) {
                      _start = date;
                      _invalidate();
                    },
                  ),
                  const SizedBox(height: 12),
                  FinanceDateField(
                    label: L.of(context).financeReconClosingDate,
                    date: _end,
                    onChanged: (date) {
                      _end = date;
                      _invalidate();
                    },
                  ),
                  const SizedBox(height: 12),
                  FinanceField(
                    label: L.of(context).financeReconOpeningBalance,
                    controller: _opening,
                    prefix: '€ ',
                    number: true,
                  ),
                  const SizedBox(height: 12),
                  FinanceField(
                    label: L.of(context).financeReconClosingBalance,
                    controller: _closing,
                    prefix: '€ ',
                    number: true,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loadStatement,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(
                          _entries == null
                              ? L.of(context).financeReconLoadEntries
                              : L.of(context).financeReconReplaceEntries,
                        ),
                      ),
                      if (_entries != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _entries = null;
                              _checked = false;
                            });
                          },
                          child: Text(L.of(context).financeReconClearEntries),
                        ),
                    ],
                  ),
                  Text(
                    _entries == null
                        ? L.of(context).financeReconOptionalHelp
                        : L
                              .of(context)
                              .financeReconEntriesLoaded(_entries!.length),
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: luma.danger),
                      ),
                    ),
                  if (_checked)
                    StreamBuilder<List<Merchant>>(
                      stream: _merchants,
                      builder: (context, merchants) {
                        if (merchants.hasError) {
                          return Text(
                            L.of(context).financeReconReadMerchantsFailed,
                          );
                        }
                        if (!merchants.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }
                        return StreamBuilder<List<FinanceTransaction>>(
                          stream: _transactions,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                L
                                    .of(context)
                                    .financeReconReadTransactionsFailed,
                              );
                            }
                            if (!snapshot.hasData) {
                              return Center(child: CircularProgressIndicator());
                            }
                            final result = reconcileStatement(
                              transactions: snapshot.data!,
                              startDate: _start,
                              endDate: _end,
                              openingCents: _balance(_opening.text)!,
                              closingCents: _balance(_closing.text)!,
                              statementEntries: _entries,
                              excludedIds: _excluded,
                              merchantNames: {
                                for (final m in merchants.data!) m.id: m.name,
                              },
                            );
                            return _results(result, snapshot.data!);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(L.of(context).commonClose),
              ),
              FilledButton(
                onPressed: _compare,
                child: Text(L.of(context).financeReconCompare),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _results(
    StatementReconciliation result,
    List<FinanceTransaction> all,
  ) {
    final luma = context.luma;
    final difference = result.differenceCents;
    final periodEntries = all.where(_inPeriod).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          L
              .of(context)
              .financeReconCalculatedClosing(
                formatCents(result.calculatedClosingCents),
              ),
          style: TextStyle(
            color: luma.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          L
              .of(context)
              .financeReconStatementClosing(
                formatCents(_balance(_closing.text)!),
              ),
        ),
        Text(
          difference == 0
              ? L.of(context).financeReconMatch
              : (difference > 0
                    ? L
                          .of(context)
                          .financeReconDifferenceLower(
                            formatSignedCents(difference),
                          )
                    : L
                          .of(context)
                          .financeReconDifferenceHigher(
                            formatSignedCents(difference),
                          )),
          style: TextStyle(
            color: difference == 0 ? luma.success : luma.danger,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          L.of(context).financeReconCheckHint,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        if (result.statementCalculatedClosingCents != null) ...[
          const SizedBox(height: 8),
          Text(
            L
                .of(context)
                .financeReconClosingFromFile(
                  formatCents(result.statementCalculatedClosingCents!),
                ),
          ),
          if (result.statementCalculatedClosingCents != _balance(_closing.text))
            Text(
              L.of(context).financeReconFileDoesNotReach,
              style: TextStyle(color: luma.danger),
            ),
          if (result.statementOutsidePeriodCount > 0)
            Text(
              L
                  .of(context)
                  .financeReconOutsidePeriod(
                    result.statementOutsidePeriodCount,
                  ),
            ),
          Text(L.of(context).financeReconMatchedCount(result.matchedCount)),
          if (result.amountOnlyMatches.isNotEmpty)
            _entryList(
              L
                  .of(context)
                  .financeReconReviewPairs(result.amountOnlyMatches.length),
              result.amountOnlyMatches.length,
              (i) {
                final pair = result.amountOnlyMatches.entries.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(
                    L
                        .of(context)
                        .financeReconLumaEntry(
                          pair.key.note ?? '#${pair.key.id}',
                        ),
                  ),
                  subtitle: Text(
                    L
                        .of(context)
                        .financeReconStatementSubtitle(
                          pair.value.description,
                          '${longDate(pair.key.date)} · ${formatCents(pair.key.amountCents)}',
                        ),
                  ),
                  trailing: IconButton(
                    tooltip: L.of(context).moodJournalEditEntry,
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _edit(pair.key),
                  ),
                );
              },
            ),
          if (result.missingEntries.isEmpty &&
              result.extraEntries.isEmpty &&
              result.amountOnlyMatches.isEmpty)
            Text(L.of(context).financeReconNoUnmatched),
          if (result.missingEntries.isNotEmpty) ...[
            _entryList(
              L
                  .of(context)
                  .financeReconPossiblyMissing(result.missingEntries.length),
              result.missingEntries.length,
              (i) {
                final e = result.missingEntries[i];
                return ListTile(
                  dense: true,
                  title: Text(e.description),
                  subtitle: Text(longDate(e.date)),
                  trailing: Text(
                    formatSignedCents(
                      e.isIncome ? e.amountCents : -e.amountCents,
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _reviewMissing(result.missingEntries),
                child: Text(L.of(context).financeReconReviewMissing),
              ),
            ),
          ],
          if (result.extraEntries.isNotEmpty)
            _entryList(
              L.of(context).financeReconNotPaired(result.extraEntries.length),
              result.extraEntries.length,
              (i) => _transaction(result.extraEntries[i]),
            ),
        ],
        if (result.possibleDuplicates.isNotEmpty)
          _entryList(
            L
                .of(context)
                .financeReconPossibleDuplicates(
                  result.possibleDuplicates.length,
                ),
            result.possibleDuplicates.length,
            (i) {
              final group = result.possibleDuplicates[i];
              return ListTile(
                dense: true,
                title: Text(
                  L
                      .of(context)
                      .financeReconDuplicateTitle(
                        group.length,
                        group.first.note ??
                            L.of(context).financeReconSameDescription,
                      ),
                ),
                subtitle: Text(
                  L
                      .of(context)
                      .financeReconDuplicateDetail(
                        longDate(group.first.date),
                        formatSignedCents(reconciliationDelta(group.first)),
                        group.map((t) => t.id).join(', '),
                      ),
                ),
              );
            },
          ),
        if (result.amountCandidates.isNotEmpty)
          _entryList(
            L.of(context).financeReconRemovalExplains,
            result.amountCandidates.length,
            (i) => _transaction(result.amountCandidates[i]),
          ),
        _entryList(
          L.of(context).financeReconReviewIncluded,
          periodEntries.length,
          (i) {
            final t = periodEntries[i];
            return CheckboxListTile(
              dense: true,
              value: !_excluded.contains(t.id),
              onChanged: (included) => setState(() {
                if (included == true) {
                  _excluded.remove(t.id);
                } else {
                  _excluded.add(t.id);
                }
              }),
              title: Text(t.note ?? '${t.kind.name} #${t.id}'),
              subtitle: Text(
                '#${t.id} · ${longDate(t.date)} · '
                '${formatSignedCents(reconciliationDelta(t))}',
              ),
            );
          },
        ),
        if (_excluded.isNotEmpty)
          TextButton(
            onPressed: () => setState(_excluded.clear),
            child: Text(L.of(context).financeReconIncludeAll),
          ),
      ],
    );
  }

  bool _inPeriod(FinanceTransaction t) {
    final date = DateTime(t.date.year, t.date.month, t.date.day);
    return t.kind != TxnKind.allocation &&
        !date.isBefore(_start) &&
        !date.isAfter(_end);
  }

  Widget _transaction(FinanceTransaction t) => ListTile(
    dense: true,
    title: Text(t.note ?? '${t.kind.name} #${t.id}'),
    subtitle: Text(
      '#${t.id} · ${longDate(t.date)} · '
      '${formatSignedCents(reconciliationDelta(t))}',
    ),
    trailing: IconButton(
      tooltip: L.of(context).moodJournalEditEntry,
      icon: const Icon(Icons.edit_rounded),
      onPressed: () => _edit(t),
    ),
  );

  Widget _entryList(String title, int count, Widget Function(int) builder) =>
      ExpansionTile(
        title: Text(title),
        children: [
          SizedBox(
            height: count == 0 ? 48 : 220,
            child: count == 0
                ? Center(child: Text(L.of(context).financeReconNoCashEntries))
                : ListView.builder(
                    itemCount: count,
                    itemBuilder: (context, i) => builder(i),
                  ),
          ),
        ],
      );
}

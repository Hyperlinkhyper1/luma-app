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
  String? _error;

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
      _error = null;
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
      _error = _end.isBefore(_start)
          ? 'The closing date must be on or after the start date.'
          : _balance(_opening.text) == null || _balance(_closing.text) == null
          ? 'Enter valid opening and closing balances in euros.'
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
      _error = null;
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
        name: 'Main',
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
            'Statement reconciliation',
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
                    'Enter the opening balance immediately before the start date '
                    'and the closing balance at the end of the closing date. '
                    'Luma includes income and expenses across all pots; '
                    'allocations between pots do not change this balance.',
                    style: TextStyle(color: luma.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  FinanceDateField(
                    label: 'Start date',
                    date: _start,
                    onChanged: (date) {
                      _start = date;
                      _invalidate();
                    },
                  ),
                  const SizedBox(height: 12),
                  FinanceDateField(
                    label: 'Closing date',
                    date: _end,
                    onChanged: (date) {
                      _end = date;
                      _invalidate();
                    },
                  ),
                  const SizedBox(height: 12),
                  FinanceField(
                    label: 'Statement opening balance',
                    controller: _opening,
                    prefix: '€ ',
                    number: true,
                  ),
                  const SizedBox(height: 12),
                  FinanceField(
                    label: 'Statement closing balance',
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
                              ? 'Load statement entries'
                              : 'Replace statement entries',
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
                          child: const Text('Clear statement entries'),
                        ),
                    ],
                  ),
                  Text(
                    _entries == null
                        ? 'Optional: read an exported transaction file to locate entries. '
                              'Enter the statement balances above; loading a file adds nothing.'
                        : '${_entries!.length} statement entries loaded. '
                              'Use the dates of the full statement period above.',
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
                          return const Text('Unable to read merchants.');
                        }
                        if (!merchants.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return StreamBuilder<List<FinanceTransaction>>(
                          stream: _transactions,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Text('Unable to read transactions.');
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
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
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: _compare,
                child: const Text('Compare balances'),
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
          'Calculated closing balance: ${formatCents(result.calculatedClosingCents)}',
          style: TextStyle(
            color: luma.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Statement closing balance: ${formatCents(_balance(_closing.text)!)}',
        ),
        Text(
          difference == 0
              ? 'Balances match'
              : 'Difference: ${formatSignedCents(difference)} '
                    '(Luma is ${difference > 0 ? 'lower' : 'higher'})',
          style: TextStyle(
            color: difference == 0 ? luma.success : luma.danger,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Check the opening balance, dates and included entries. '
          'If you track multiple bank accounts, exclude movements belonging '
          'to other accounts below. Suggestions do not prove an entry is wrong.',
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        if (result.statementCalculatedClosingCents != null) ...[
          const SizedBox(height: 8),
          Text(
            'Closing from file entries: '
            '${formatCents(result.statementCalculatedClosingCents!)}',
          ),
          if (result.statementCalculatedClosingCents != _balance(_closing.text))
            Text(
              'The file entries and opening balance do not reach the statement '
              'closing balance. Check that the export covers the whole period.',
              style: TextStyle(color: luma.danger),
            ),
          if (result.statementOutsidePeriodCount > 0)
            Text(
              '${result.statementOutsidePeriodCount} file entries are outside the selected period.',
            ),
          Text(
            '${result.matchedCount} entries paired by date, direction and amount. '
            'Descriptions may differ; shifted booking dates appear as unmatched.',
          ),
          if (result.amountOnlyMatches.isNotEmpty)
            _entryList(
              'Review pairs with different descriptions (${result.amountOnlyMatches.length})',
              result.amountOnlyMatches.length,
              (i) {
                final pair = result.amountOnlyMatches.entries.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text('Luma: ${pair.key.note ?? '#${pair.key.id}'}'),
                  subtitle: Text(
                    'Statement: ${pair.value.description}\n'
                    '${longDate(pair.key.date)} · ${formatCents(pair.key.amountCents)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit entry',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _edit(pair.key),
                  ),
                );
              },
            ),
          if (result.missingEntries.isEmpty &&
              result.extraEntries.isEmpty &&
              result.amountOnlyMatches.isEmpty)
            const Text('No unmatched entries.'),
          if (result.missingEntries.isNotEmpty) ...[
            _entryList(
              'Possibly missing from Luma (${result.missingEntries.length})',
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
                child: const Text('Review missing entries for import'),
              ),
            ),
          ],
          if (result.extraEntries.isNotEmpty)
            _entryList(
              'Luma entries not paired with statement (${result.extraEntries.length})',
              result.extraEntries.length,
              (i) => _transaction(result.extraEntries[i]),
            ),
        ],
        if (result.possibleDuplicates.isNotEmpty)
          _entryList(
            'Possible duplicates (${result.possibleDuplicates.length} groups)',
            result.possibleDuplicates.length,
            (i) {
              final group = result.possibleDuplicates[i];
              return ListTile(
                dense: true,
                title: Text(
                  '${group.length} entries: ${group.first.note ?? 'Same description'}',
                ),
                subtitle: Text(
                  '${longDate(group.first.date)} · '
                  '${formatSignedCents(reconciliationDelta(group.first))} each · '
                  'IDs ${group.map((t) => t.id).join(', ')}',
                ),
              );
            },
          ),
        if (result.amountCandidates.isNotEmpty)
          _entryList(
            'Entries whose removal would explain the difference',
            result.amountCandidates.length,
            (i) => _transaction(result.amountCandidates[i]),
          ),
        _entryList('Review included cash entries', periodEntries.length, (i) {
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
        }),
        if (_excluded.isNotEmpty)
          TextButton(
            onPressed: () => setState(_excluded.clear),
            child: const Text('Include all entries again'),
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
      tooltip: 'Edit entry',
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
                ? const Center(child: Text('No cash entries in this period.'))
                : ListView.builder(
                    itemCount: count,
                    itemBuilder: (context, i) => builder(i),
                  ),
          ),
        ],
      );
}

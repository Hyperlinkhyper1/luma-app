import '../data/database.dart';
import '../import/import_models.dart';

int reconciliationDelta(FinanceTransaction entry) => switch (entry.kind) {
  TxnKind.income => entry.amountCents,
  TxnKind.expense => -entry.amountCents,
  TxnKind.allocation => 0,
};

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
String _text(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class StatementReconciliation {
  const StatementReconciliation({
    required this.calculatedClosingCents,
    required this.differenceCents,
    required this.transactions,
    required this.possibleDuplicates,
    required this.amountCandidates,
    required this.missingEntries,
    required this.extraEntries,
    required this.matchedCount,
    required this.amountOnlyMatches,
    required this.statementCalculatedClosingCents,
    required this.statementOutsidePeriodCount,
  });

  final int calculatedClosingCents;

  /// Statement closing minus calculated closing; positive means Luma is lower.
  final int differenceCents;
  final List<FinanceTransaction> transactions;
  final List<List<FinanceTransaction>> possibleDuplicates;

  /// Removing any one of these entries would close the balance difference.
  final List<FinanceTransaction> amountCandidates;
  final List<ParsedBankEntry> missingEntries;
  final List<FinanceTransaction> extraEntries;
  final int matchedCount;
  final Map<FinanceTransaction, ParsedBankEntry> amountOnlyMatches;
  final int? statementCalculatedClosingCents;
  final int statementOutsidePeriodCount;
}

/// Reconciles cash movements against an opening balance immediately before
/// [startDate]. Both boundary days are included, regardless of time of day.
/// Pots are envelopes: expenses in pots count, allocations do not.
StatementReconciliation reconcileStatement({
  required Iterable<FinanceTransaction> transactions,
  required DateTime startDate,
  required DateTime endDate,
  required int openingCents,
  required int closingCents,
  List<ParsedBankEntry>? statementEntries,
  Map<int, String> merchantNames = const {},
  Set<int> excludedIds = const {},
}) {
  final start = _day(startDate);
  final end = _day(endDate);
  if (end.isBefore(start)) {
    throw ArgumentError('The closing date must be on or after the start date.');
  }
  bool within(DateTime date) =>
      !_day(date).isBefore(start) && !_day(date).isAfter(end);
  final ledger =
      transactions
          .where(
            (t) =>
                t.kind != TxnKind.allocation &&
                !excludedIds.contains(t.id) &&
                within(t.date),
          )
          .toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate == 0 ? a.id.compareTo(b.id) : byDate;
        });
  final calculated = ledger.fold(
    openingCents,
    (balance, entry) => balance + reconciliationDelta(entry),
  );
  final difference = closingCents - calculated;
  final groups = <String, List<FinanceTransaction>>{};
  for (final t in ledger) {
    final identity = _text(t.note).isNotEmpty
        ? _text(t.note)
        : _text(merchantNames[t.merchantId]);
    if (identity.isEmpty) continue;
    final key = '${_day(t.date)}|${t.kind}|${t.amountCents}|$identity';
    groups.putIfAbsent(key, () => []).add(t);
  }

  final bank = statementEntries?.where((e) => within(e.date)).toList();
  final usedIds = <int>{};
  final matchedBank = <int>{};
  final amountOnlyMatches = <FinanceTransaction, ParsedBankEntry>{};
  final movements = <(DateTime, TxnKind, int), List<FinanceTransaction>>{};
  for (final t in ledger) {
    movements
        .putIfAbsent((_day(t.date), t.kind, t.amountCents), () => [])
        .add(t);
  }
  bool sameIdentity(ParsedBankEntry e, FinanceTransaction t) =>
      (_text(e.description).isNotEmpty &&
          _text(e.description) == _text(t.note)) ||
      (_text(e.merchantName).isNotEmpty &&
          _text(e.merchantName) == _text(merchantNames[t.merchantId]));

  if (bank != null) {
    // Reserve descriptive matches first so a generic row cannot consume them.
    for (final requireIdentity in [true, false]) {
      for (var i = 0; i < bank.length; i++) {
        if (matchedBank.contains(i)) continue;
        final entry = bank[i];
        final bucket =
            movements[(
              _day(entry.date),
              entry.isIncome ? TxnKind.income : TxnKind.expense,
              entry.amountCents,
            )] ??
            const <FinanceTransaction>[];
        final candidates = bucket.where(
          (t) =>
              !usedIds.contains(t.id) &&
              (!requireIdentity || sameIdentity(bank[i], t)),
        );
        final match = candidates.firstOrNull;
        if (match != null) {
          usedIds.add(match.id);
          matchedBank.add(i);
          if (!requireIdentity) amountOnlyMatches[match] = bank[i];
        }
      }
    }
  }
  return StatementReconciliation(
    calculatedClosingCents: calculated,
    differenceCents: difference,
    transactions: ledger,
    possibleDuplicates: groups.values.where((g) => g.length > 1).toList(),
    amountCandidates: difference == 0
        ? []
        : ledger.where((t) => reconciliationDelta(t) == -difference).toList(),
    missingEntries: bank == null
        ? []
        : [
            for (var i = 0; i < bank.length; i++)
              if (!matchedBank.contains(i)) bank[i],
          ],
    extraEntries: bank == null
        ? []
        : ledger.where((t) => !usedIds.contains(t.id)).toList(),
    matchedCount: matchedBank.length,
    amountOnlyMatches: amountOnlyMatches,
    statementCalculatedClosingCents: bank?.fold<int>(
      openingCents,
      (balance, e) => balance + (e.isIncome ? e.amountCents : -e.amountCents),
    ),
    statementOutsidePeriodCount: statementEntries == null
        ? 0
        : statementEntries.length - bank!.length,
  );
}

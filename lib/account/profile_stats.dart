import '../finance/data/database.dart';

/// Lifetime totals behind the Account -> Stats tab, folded out of the finance
/// ledger. Allocations only move money between the main balance and a pot, so
/// they never count towards income or spending.
class ProfileStats {
  const ProfileStats({
    required this.incomeCents,
    required this.spentCents,
    required this.entryCount,
    required this.firstEntry,
    required this.lastEntry,
  });

  /// Everything ever earned — the "net worth" headline.
  final int incomeCents;

  /// Everything ever spent.
  final int spentCents;

  /// How many income/expense entries the ledger holds.
  final int entryCount;

  /// Oldest and newest income/expense dates, or null on an empty ledger.
  final DateTime? firstEntry;
  final DateTime? lastEntry;

  static const empty = ProfileStats(
    incomeCents: 0,
    spentCents: 0,
    entryCount: 0,
    firstEntry: null,
    lastEntry: null,
  );

  /// What's left of the lifetime income after everything spent.
  int get keptCents => incomeCents - spentCents;

  /// Share of lifetime income that wasn't spent again, 0..1.
  double get keptFraction =>
      incomeCents <= 0 ? 0 : (keptCents / incomeCents).clamp(0.0, 1.0);

  /// Calendar months covered by the ledger, counting a partial month as one
  /// so a fresh ledger never divides by zero.
  int get monthsTracked {
    final first = firstEntry;
    final last = lastEntry;
    if (first == null || last == null) return 0;
    final months =
        (last.year - first.year) * 12 + (last.month - first.month) + 1;
    return months < 1 ? 1 : months;
  }

  /// Average income per month over [monthsTracked].
  int get averageMonthlyIncomeCents {
    final months = monthsTracked;
    return months == 0 ? 0 : incomeCents ~/ months;
  }

  /// Folds the whole ledger into the numbers above.
  static ProfileStats fromTransactions(Iterable<FinanceTransaction> txns) {
    var income = 0;
    var spent = 0;
    var count = 0;
    DateTime? first;
    DateTime? last;

    for (final txn in txns) {
      switch (txn.kind) {
        case TxnKind.income:
          income += txn.amountCents;
        case TxnKind.expense:
          spent += txn.amountCents;
        case TxnKind.allocation:
          continue;
      }
      count++;
      if (first == null || txn.date.isBefore(first)) first = txn.date;
      if (last == null || txn.date.isAfter(last)) last = txn.date;
    }

    return ProfileStats(
      incomeCents: income,
      spentCents: spent,
      entryCount: count,
      firstEntry: first,
      lastEntry: last,
    );
  }
}

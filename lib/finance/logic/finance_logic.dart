import '../data/database.dart';

/// Returns the next due date after [from] for the given [cadence].
/// Dates are normalized to midnight (the time-of-day is irrelevant for dues).
DateTime advanceDate(DateTime from, Cadence cadence) {
  final d = DateTime(from.year, from.month, from.day);
  switch (cadence) {
    case Cadence.weekly:
      return d.add(const Duration(days: 7));
    case Cadence.monthly:
      return _addMonthClamped(d, 1);
  }
}

/// Adds [months] to [date], clamping the day to the target month's length
/// (so Jan 31 + 1 month -> Feb 28/29).
DateTime _addMonthClamped(DateTime date, int months) {
  final total = date.month - 1 + months;
  final year = date.year + (total ~/ 12);
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
}

/// Main (unallocated) balance plus per-pot balances, derived from the ledger.
class Balances {
  Balances(this.mainCents, this.potCents);
  final int mainCents;
  final Map<int, int> potCents;

  int balanceForPot(int potId) => potCents[potId] ?? 0;
  int get potsTotalCents => potCents.values.fold(0, (a, b) => a + b);

  /// Net worth across the main balance and every pot. Allocations net to zero,
  /// so this always equals total income minus total expenses.
  int get totalCents => mainCents + potsTotalCents;
}

/// Folds the full ledger into main + pot balances using these rules:
/// income -> +(pot or main); expense -> -(pot or main); allocation -> main to pot.
Balances computeBalances(Iterable<FinanceTransaction> txns) {
  var main = 0;
  final pots = <int, int>{};
  void addPot(int id, int delta) => pots[id] = (pots[id] ?? 0) + delta;

  for (final t in txns) {
    switch (t.kind) {
      case TxnKind.income:
        if (t.potId != null) {
          addPot(t.potId!, t.amountCents);
        } else {
          main += t.amountCents;
        }
      case TxnKind.expense:
        if (t.potId != null) {
          addPot(t.potId!, -t.amountCents);
        } else {
          main -= t.amountCents;
        }
      case TxnKind.allocation:
        main -= t.amountCents;
        if (t.potId != null) addPot(t.potId!, t.amountCents);
    }
  }
  return Balances(main, pots);
}

/// Amount in cents an allocation rule contributes for one run, given the
/// current main balance ([baseCents]) for percentage rules.
int allocationAmountCents({
  required AllocMode mode,
  required int valueCents,
  required int percentBps,
  required int baseCents,
}) {
  switch (mode) {
    case AllocMode.fixed:
      return valueCents;
    case AllocMode.percent:
      if (baseCents <= 0) return 0;
      return (baseCents * percentBps / 10000).round();
  }
}

/// True if [nextDue] is on or before [now] (i.e. the rule should fire).
bool isDue(DateTime nextDue, DateTime now) => !nextDue.isAfter(now);

/// Advances [nextDue] forward by [cadence] until it is in the future relative
/// to [now], returning every occurrence date that was passed (so a rule that
/// was missed for several periods fires once per missed period).
List<DateTime> dueOccurrences(DateTime nextDue, Cadence cadence, DateTime now) {
  final occurrences = <DateTime>[];
  var due = nextDue;
  // Guard against pathological loops (e.g. far-past anchors).
  var safety = 0;
  while (isDue(due, now) && safety < 600) {
    occurrences.add(due);
    due = advanceDate(due, cadence);
    safety++;
  }
  return occurrences;
}

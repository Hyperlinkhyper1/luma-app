import 'package:flutter_test/flutter_test.dart';
import 'package:luma/account/profile_stats.dart';
import 'package:luma/finance/data/database.dart';

FinanceTransaction _txn({
  required TxnKind kind,
  required int amountCents,
  DateTime? date,
}) {
  final when = date ?? DateTime(2026, 1, 1);
  return FinanceTransaction(
    id: 0,
    kind: kind,
    amountCents: amountCents,
    date: when,
    createdAt: when,
  );
}

void main() {
  group('ProfileStats', () {
    test('an empty ledger reads as all zeroes', () {
      final stats = ProfileStats.fromTransactions(const []);
      expect(stats.incomeCents, 0);
      expect(stats.spentCents, 0);
      expect(stats.entryCount, 0);
      expect(stats.firstEntry, isNull);
      expect(stats.monthsTracked, 0);
      expect(stats.averageMonthlyIncomeCents, 0);
      expect(stats.keptFraction, 0);
    });

    test('sums lifetime income and spending', () {
      final stats = ProfileStats.fromTransactions([
        _txn(kind: TxnKind.income, amountCents: 250000),
        _txn(kind: TxnKind.income, amountCents: 125050),
        _txn(kind: TxnKind.expense, amountCents: 75000),
      ]);
      expect(stats.incomeCents, 375050);
      expect(stats.spentCents, 75000);
      expect(stats.keptCents, 300050);
      expect(stats.entryCount, 3);
    });

    test('allocations move money around and never count', () {
      final stats = ProfileStats.fromTransactions([
        _txn(kind: TxnKind.income, amountCents: 100000),
        _txn(kind: TxnKind.allocation, amountCents: 40000),
      ]);
      expect(stats.incomeCents, 100000);
      expect(stats.spentCents, 0);
      expect(stats.entryCount, 1);
    });

    test('tracks the ledger span and the monthly average', () {
      final stats = ProfileStats.fromTransactions([
        _txn(
          kind: TxnKind.income,
          amountCents: 100000,
          date: DateTime(2025, 11, 20),
        ),
        _txn(
          kind: TxnKind.income,
          amountCents: 200000,
          date: DateTime(2026, 2, 3),
        ),
      ]);
      expect(stats.firstEntry, DateTime(2025, 11, 20));
      expect(stats.lastEntry, DateTime(2026, 2, 3));
      // November through February inclusive.
      expect(stats.monthsTracked, 4);
      expect(stats.averageMonthlyIncomeCents, 75000);
    });

    test('a single day of entries still counts as one month', () {
      final stats = ProfileStats.fromTransactions([
        _txn(kind: TxnKind.income, amountCents: 50000),
      ]);
      expect(stats.monthsTracked, 1);
      expect(stats.averageMonthlyIncomeCents, 50000);
    });

    test('kept fraction is clamped for an overspent ledger', () {
      final stats = ProfileStats.fromTransactions([
        _txn(kind: TxnKind.income, amountCents: 10000),
        _txn(kind: TxnKind.expense, amountCents: 25000),
      ]);
      expect(stats.keptCents, -15000);
      expect(stats.keptFraction, 0);
    });
  });
}

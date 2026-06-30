import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/logic/finance_logic.dart';
import 'package:luma/finance/logic/money.dart';

FinanceTransaction _txn({
  required TxnKind kind,
  required int amountCents,
  int? potId,
}) {
  return FinanceTransaction(
    id: 0,
    kind: kind,
    amountCents: amountCents,
    date: DateTime(2026, 1, 1),
    potId: potId,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('parseToCents', () {
    test('plain and Dutch number styles', () {
      expect(parseToCents('10'), 1000);
      expect(parseToCents('12,50'), 1250);
      expect(parseToCents('12.50'), 1250);
      expect(parseToCents('1.234,56'), 123456);
      expect(parseToCents('1,234.56'), 123456);
      expect(parseToCents('€ 9,99'), 999);
    });

    test('rejects non-numbers', () {
      expect(parseToCents(''), isNull);
      expect(parseToCents('abc'), isNull);
    });
  });

  group('advanceDate', () {
    test('weekly adds 7 days', () {
      expect(
        advanceDate(DateTime(2026, 6, 1), Cadence.weekly),
        DateTime(2026, 6, 8),
      );
    });

    test('monthly clamps to month length', () {
      expect(
        advanceDate(DateTime(2026, 1, 31), Cadence.monthly),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('allocationAmountCents', () {
    test('fixed returns its value', () {
      expect(
        allocationAmountCents(
            mode: AllocMode.fixed,
            valueCents: 5000,
            percentBps: 0,
            baseCents: 99999),
        5000,
      );
    });

    test('percent is computed against the base', () {
      expect(
        allocationAmountCents(
            mode: AllocMode.percent,
            valueCents: 0,
            percentBps: 2500, // 25%
            baseCents: 20000),
        5000,
      );
    });

    test('percent of a non-positive base is zero', () {
      expect(
        allocationAmountCents(
            mode: AllocMode.percent,
            valueCents: 0,
            percentBps: 2500,
            baseCents: 0),
        0,
      );
    });
  });

  group('dueOccurrences', () {
    test('fires once per missed period', () {
      final now = DateTime(2026, 6, 29);
      final occ = dueOccurrences(DateTime(2026, 6, 8), Cadence.weekly, now);
      // 8 Jun, 15 Jun, 22 Jun, 29 Jun => 4 occurrences.
      expect(occ.length, 4);
    });

    test('nothing due in the future', () {
      final now = DateTime(2026, 6, 1);
      expect(dueOccurrences(DateTime(2026, 7, 1), Cadence.monthly, now), isEmpty);
    });
  });

  group('computeBalances', () {
    test('income, allocation and pot/main expenses', () {
      final balances = computeBalances([
        _txn(kind: TxnKind.income, amountCents: 200000), // +2000 main
        _txn(kind: TxnKind.allocation, amountCents: 50000, potId: 1), // main->pot1
        _txn(kind: TxnKind.expense, amountCents: 12000, potId: 1), // -120 pot1
        _txn(kind: TxnKind.expense, amountCents: 8000), // -80 main
      ]);

      expect(balances.mainCents, 200000 - 50000 - 8000); // 142000
      expect(balances.balanceForPot(1), 50000 - 12000); // 38000
      expect(balances.totalCents, 200000 - 12000 - 8000); // 180000
    });

    test('total always equals income minus expenses', () {
      final balances = computeBalances([
        _txn(kind: TxnKind.income, amountCents: 100000),
        _txn(kind: TxnKind.allocation, amountCents: 40000, potId: 7),
        _txn(kind: TxnKind.allocation, amountCents: 10000, potId: 9),
        _txn(kind: TxnKind.expense, amountCents: 2500, potId: 7),
      ]);
      expect(balances.totalCents, 100000 - 2500);
    });
  });
}

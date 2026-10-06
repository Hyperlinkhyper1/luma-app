import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/import/import_models.dart';
import 'package:luma/finance/logic/statement_reconciliation.dart';

FinanceTransaction txn(
  int id,
  int amount, {
  TxnKind kind = TxnKind.expense,
  DateTime? date,
  String? note = 'Shop',
  int? potId,
  int? merchantId,
}) => FinanceTransaction(
  id: id,
  kind: kind,
  amountCents: amount,
  date: date ?? DateTime(2026, 10, 5),
  note: note,
  potId: potId,
  merchantId: merchantId,
  createdAt: DateTime(2026, 10, 6),
);

ParsedBankEntry bank(
  int amount, {
  String description = 'Shop',
  bool income = false,
  DateTime? date,
}) => ParsedBankEntry(
  date: date ?? DateTime(2026, 10, 5),
  description: description,
  isIncome: income,
  amountCents: amount,
);

StatementReconciliation report(
  List<FinanceTransaction> transactions, {
  int opening = 10000,
  int closing = 8000,
  List<ParsedBankEntry>? entries,
  Set<int> excluded = const {},
  Map<int, String> merchants = const {},
}) => reconcileStatement(
  transactions: transactions,
  startDate: DateTime(2026, 10, 1),
  endDate: DateTime(2026, 10, 5),
  openingCents: opening,
  closingCents: closing,
  statementEntries: entries,
  excludedIds: excluded,
  merchantNames: merchants,
);

void main() {
  test(
    'inclusive dates count pot cash, ignore allocations and future entries',
    () {
      final r = report([
        txn(1, 5000, kind: TxnKind.income, date: DateTime(2026, 10, 1, 12)),
        txn(2, 7000, potId: 4, date: DateTime(2026, 10, 5, 23, 59)),
        txn(3, 9000, kind: TxnKind.allocation, potId: 4),
        txn(4, 1000, date: DateTime(2026, 9, 30)),
        txn(5, 2000, date: DateTime(2026, 10, 6)),
      ]);
      expect(r.calculatedClosingCents, 8000);
      expect(r.differenceCents, 0);
      expect(r.transactions.map((t) => t.id), [1, 2]);
    },
  );

  test('negative opening and zero closing balances are valid', () {
    final r = report(
      [txn(1, 1000, kind: TxnKind.income)],
      opening: -1000,
      closing: 0,
    );
    expect(r.calculatedClosingCents, 0);
    expect(r.differenceCents, 0);
  });

  test('duplicate rows consume only one statement entry each', () {
    final r = report([txn(1, 2000), txn(2, 2000)], entries: [bank(2000)]);
    expect(r.differenceCents, 2000);
    expect(r.possibleDuplicates.single.map((t) => t.id), [1, 2]);
    expect(r.matchedCount, 1);
    expect(r.extraEntries.single.id, 2);
    expect(r.amountCandidates.map((t) => t.id), [1, 2]);
  });

  test('equal legitimate statement payments are paired separately', () {
    final r = report(
      [txn(1, 1000), txn(2, 1000)],
      entries: [bank(1000), bank(1000)],
    );
    expect(r.matchedCount, 2);
    expect(r.missingEntries, isEmpty);
    expect(r.extraEntries, isEmpty);
  });

  test(
    'missing and extra entries remain visible even when balance matches',
    () {
      final r = report(
        [txn(1, 2000)],
        entries: [bank(2000, date: DateTime(2026, 10, 4))],
      );
      expect(r.differenceCents, 0);
      expect(r.missingEntries, hasLength(1));
      expect(r.extraEntries, hasLength(1));
    },
  );

  test('description matches are reserved before amount-only pairs', () {
    final r = report(
      [txn(1, 1000, note: 'Specific'), txn(2, 1000, note: 'Other')],
      entries: [
        bank(1000, description: 'Generic'),
        bank(1000, description: 'Specific'),
      ],
    );
    expect(r.matchedCount, 2);
    expect(r.amountOnlyMatches.keys.single.id, 2);
    expect(r.amountOnlyMatches.values.single.description, 'Generic');
  });

  test('direction matters and file coverage is reported', () {
    final r = report(
      [txn(1, 2000)],
      entries: [
        bank(2000, income: true),
        bank(500, date: DateTime(2026, 10, 6)),
      ],
    );
    expect(r.matchedCount, 0);
    expect(r.missingEntries, hasLength(1));
    expect(r.extraEntries, hasLength(1));
    expect(r.statementCalculatedClosingCents, 12000);
    expect(r.statementOutsidePeriodCount, 1);
  });

  test(
    'exclusions affect totals and diagnostics without changing the input',
    () {
      final txns = [txn(1, 2000), txn(2, 2000)];
      final r = report(txns, excluded: {2}, entries: [bank(2000)]);
      expect(r.calculatedClosingCents, 8000);
      expect(r.possibleDuplicates, isEmpty);
      expect(r.extraEntries, isEmpty);
      expect(txns, hasLength(2));
    },
  );

  test(
    'merchant-only duplicate detection avoids grouping anonymous entries',
    () {
      final r = report(
        [
          txn(1, 500, note: null, merchantId: 3),
          txn(2, 500, note: null, merchantId: 3),
          txn(3, 500, note: null),
          txn(4, 500, note: null),
        ],
        merchants: {3: 'Shop'},
      );
      expect(r.possibleDuplicates, hasLength(1));
      expect(r.possibleDuplicates.single.map((t) => t.id), [1, 2]);
    },
  );

  test('removal candidates use the correct sign for excess income', () {
    final r = report([txn(1, 2000, kind: TxnKind.income)], closing: 10000);
    expect(r.differenceCents, -2000);
    expect(r.amountCandidates.single.id, 1);
  });

  test('invalid periods are rejected', () {
    expect(
      () => reconcileStatement(
        transactions: [],
        startDate: DateTime(2026, 10, 6),
        endDate: DateTime(2026, 10, 5),
        openingCents: 0,
        closingCents: 0,
      ),
      throwsArgumentError,
    );
  });
}

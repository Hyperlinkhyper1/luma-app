import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/fx_service.dart';
import 'package:luma/finance/logic/holding_value.dart';
import 'package:luma/finance/logic/insights.dart';
import 'package:luma/finance/logic/planning.dart';
import 'package:luma/storage/storage_guard.dart';

var _nextId = 1;

FinanceTransaction _txn(
  TxnKind kind,
  int cents,
  DateTime date, {
  int? categoryId,
  int? merchantId,
  int? potId,
  String? note,
}) => FinanceTransaction(
  id: _nextId++,
  kind: kind,
  amountCents: cents,
  date: date,
  categoryId: categoryId,
  merchantId: merchantId,
  potId: potId,
  note: note,
  createdAt: date,
);

Category _cat(int id, {int? budget}) => Category(
  id: id,
  name: 'Cat $id',
  colorValue: 0,
  iconCodepoint: 0,
  monthlyBudgetCents: budget,
);

RecurringRule _rule(
  String name,
  TxnKind kind,
  int cents,
  DateTime nextDue, {
  Cadence cadence = Cadence.monthly,
  int? potId,
  int? merchantId,
}) => RecurringRule(
  id: _nextId++,
  name: name,
  kind: kind,
  amountCents: cents,
  cadence: cadence,
  nextDue: nextDue,
  potId: potId,
  merchantId: merchantId,
  active: true,
  isBill: false,
  reminderDaysBefore: 7,
);

void main() {
  group('budgetUsage', () {
    test(
      'sums this month\'s expenses per budgeted category, pots included',
      () {
        final usage = budgetUsage(
          categories: [_cat(1, budget: 10000), _cat(2), _cat(3, budget: 5000)],
          txns: [
            _txn(TxnKind.expense, 6000, DateTime(2026, 9, 3), categoryId: 1),
            _txn(
              TxnKind.expense,
              3000,
              DateTime(2026, 9, 20),
              categoryId: 1,
              potId: 4,
            ),
            _txn(TxnKind.expense, 9999, DateTime(2026, 8, 31), categoryId: 1),
            _txn(TxnKind.income, 9999, DateTime(2026, 9, 5), categoryId: 1),
            _txn(TxnKind.expense, 6000, DateTime(2026, 9, 5), categoryId: 3),
            _txn(TxnKind.expense, 500, DateTime(2026, 9, 5), categoryId: 2),
          ],
          month: DateTime(2026, 9, 27),
        );
        expect(usage.map((u) => u.category.id), [3, 1]);
        final groceries = usage.firstWhere((u) => u.category.id == 1);
        expect(groceries.spentCents, 9000);
        expect(groceries.isNear, isTrue);
        expect(usage.first.isOver, isTrue);
        expect(usage.first.remainingCents, -1000);
      },
    );
  });

  group('goalProgress', () {
    Pot pot({int? goal, DateTime? date}) => Pot(
      id: 1,
      name: 'Holiday',
      colorValue: 0,
      iconCodepoint: 0,
      sortOrder: 0,
      goalCents: goal,
      goalDate: date,
    );

    test('no goal means no progress', () {
      expect(goalProgress(pot(), 500, DateTime(2026, 9, 1)), isNull);
    });

    test('monthly top-up rounds up over the months left', () {
      final p = goalProgress(
        pot(goal: 100000, date: DateTime(2027, 1, 15)),
        40000,
        DateTime(2026, 9, 27),
      )!;
      expect(p.monthsLeft, 4);
      expect(p.monthlyNeededCents, 15000);
      expect(p.fraction, closeTo(0.4, 1e-9));
    });

    test('reached goals need nothing more', () {
      final p = goalProgress(
        pot(goal: 1000, date: DateTime(2026, 10, 1)),
        1500,
        DateTime(2026, 9, 27),
      )!;
      expect(p.reached, isTrue);
      expect(p.monthlyNeededCents, isNull);
      expect(p.remainingCents, 0);
    });

    test('a past date is overdue and asks for everything now', () {
      final p = goalProgress(
        pot(goal: 1000, date: DateTime(2026, 9, 1)),
        200,
        DateTime(2026, 9, 27),
      )!;
      expect(p.isOverdue(DateTime(2026, 9, 27)), isTrue);
      expect(p.monthlyNeededCents, 800);
    });
  });

  group('forecastMainBalance', () {
    final now = DateTime(2026, 9, 27, 14);

    test('applies main-balance rules and skips pot rules', () {
      final f = forecastMainBalance(
        startCents: 10000,
        now: now,
        recurring: [
          _rule('Salary', TxnKind.income, 250000, DateTime(2026, 10, 1)),
          _rule('Rent', TxnKind.expense, 120000, DateTime(2026, 10, 2)),
          _rule('Gym', TxnKind.expense, 3000, DateTime(2026, 10, 1), potId: 9),
        ],
        allocations: const [],
      );
      expect(f.dailyCents.length, 31);
      expect(f.dailyCents[0], 10000);
      expect(f.dailyCents[4], 260000);
      expect(f.dailyCents[5], 140000);
      expect(f.endCents, 140000);
      expect(f.events.map((e) => e.label), ['Salary', 'Rent']);
    });

    test('flags the first day the balance goes negative', () {
      final f = forecastMainBalance(
        startCents: 5000,
        now: now,
        recurring: [
          _rule(
            'Insurance',
            TxnKind.expense,
            2000,
            DateTime(2026, 9, 28),
            cadence: Cadence.weekly,
          ),
        ],
        allocations: const [],
      );
      expect(f.firstNegativeDate, DateTime(2026, 10, 12));
      expect(f.lowestCents, 5000 - 5 * 2000);
    });

    test('percentage allocations take a share of the projected balance', () {
      final f = forecastMainBalance(
        startCents: 0,
        now: now,
        recurring: [
          _rule('Salary', TxnKind.income, 200000, DateTime(2026, 10, 1)),
        ],
        allocations: [
          AllocationRule(
            id: 1,
            potId: 1,
            mode: AllocMode.percent,
            valueCents: 0,
            percentBps: 1000,
            cadence: Cadence.monthly,
            nextDue: DateTime(2026, 10, 1),
            active: true,
          ),
        ],
      );
      expect(f.endCents, 180000);
    });

    test('overdue rules land today', () {
      final f = forecastMainBalance(
        startCents: 1000,
        now: now,
        recurring: [
          _rule(
            'Late',
            TxnKind.expense,
            300,
            DateTime(2026, 9, 20),
            cadence: Cadence.monthly,
          ),
        ],
        allocations: const [],
        days: 5,
      );
      expect(f.dailyCents.first, 700);
    });
  });

  group('debts', () {
    final debt = Debt(
      id: 1,
      name: 'Student loan',
      direction: DebtDirection.owe,
      principalCents: 1000000,
      interestBps: 0,
      monthlyPaymentCents: 10000,
      startDate: DateTime(2026, 1, 1),
    );

    test('balance and net worth effect', () {
      final payments = [
        DebtPayment(
          id: 1,
          debtId: 1,
          amountCents: 250000,
          date: DateTime(2026, 2, 1),
        ),
        DebtPayment(
          id: 2,
          debtId: 2,
          amountCents: 999,
          date: DateTime(2026, 2, 1),
        ),
      ];
      expect(debtBalanceCents(debt, payments), 750000);
      final owedToMe = debt.copyWith(
        id: 2,
        direction: DebtDirection.owed,
        principalCents: 5000,
      );
      expect(debtsNetCents([debt, owedToMe], payments), -750000 + 4001);
    });

    test('interest-free payoff is balance over payment', () {
      final p = projectPayoff(
        balanceCents: 30000,
        interestBps: 0,
        monthlyPaymentCents: 10000,
        from: DateTime(2026, 9, 27),
      )!;
      expect(p.months, 3);
      expect(p.totalInterestCents, 0);
      expect(p.payoffDate, DateTime(2026, 12, 27));
    });

    test('interest stretches payoff and payments below interest never end', () {
      final p = projectPayoff(
        balanceCents: 1000000,
        interestBps: 600,
        monthlyPaymentCents: 20000,
        from: DateTime(2026, 1, 1),
      )!;
      expect(p.months, greaterThan(50));
      expect(p.totalInterestCents, greaterThan(0));
      expect(
        projectPayoff(
          balanceCents: 1000000,
          interestBps: 1200,
          monthlyPaymentCents: 10000,
          from: DateTime(2026, 1, 1),
        ),
        isNull,
      );
    });
  });

  group('detectSubscriptions', () {
    final now = DateTime(2026, 9, 27);

    List<FinanceTransaction> monthly(
      int merchantId,
      int cents,
      int count, {
      int lastDay = 15,
      int lastMonth = 9,
    }) => [
      for (var i = 0; i < count; i++)
        _txn(
          TxnKind.expense,
          cents,
          DateTime(2026, lastMonth - i, lastDay),
          merchantId: merchantId,
          categoryId: 7,
        ),
    ];

    test('finds a steady monthly charge', () {
      final found = detectSubscriptions(
        txns: monthly(3, 1399, 4),
        rules: const [],
        merchantNames: {3: 'Netflix'},
        now: now,
      );
      expect(found, hasLength(1));
      expect(found.single.name, 'Netflix');
      expect(found.single.cadence, Cadence.monthly);
      expect(found.single.nextDue, DateTime(2026, 10, 15));
      expect(found.single.categoryId, 7);
    });

    test('skips tracked, dismissed, stopped and irregular charges', () {
      final txns = [
        ...monthly(3, 1399, 4),
        ...monthly(4, 999, 4, lastMonth: 5),
        _txn(TxnKind.expense, 2000, DateTime(2026, 9, 1), merchantId: 5),
        _txn(TxnKind.expense, 2000, DateTime(2026, 9, 11), merchantId: 5),
        _txn(TxnKind.expense, 2000, DateTime(2026, 9, 25), merchantId: 5),
      ];
      expect(
        detectSubscriptions(
          txns: txns,
          rules: [_rule('Netflix', TxnKind.expense, 1399, now, merchantId: 3)],
          merchantNames: const {},
          now: now,
        ),
        isEmpty,
      );
      expect(
        detectSubscriptions(
          txns: monthly(3, 1399, 4),
          rules: const [],
          merchantNames: const {},
          now: now,
          dismissed: {'m:3'},
        ),
        isEmpty,
      );
    });

    test('groups merchant-less charges by their note, ignoring numbers', () {
      final found = detectSubscriptions(
        txns: [
          for (var i = 0; i < 5; i++)
            _txn(
              TxnKind.expense,
              500,
              DateTime(2026, 9, 22 - 7 * i),
              note: 'Gym visit #${100 + i}',
            ),
        ],
        rules: const [],
        merchantNames: const {},
        now: now,
      );
      expect(found.single.cadence, Cadence.weekly);
      expect(found.single.key, 'n:gym visit');
    });
  });

  group('PeriodReport', () {
    test('month totals, previous month and top merchants', () {
      final txns = [
        _txn(TxnKind.income, 300000, DateTime(2026, 9, 1)),
        _txn(
          TxnKind.expense,
          5000,
          DateTime(2026, 9, 2),
          categoryId: 1,
          merchantId: 1,
        ),
        _txn(
          TxnKind.expense,
          7000,
          DateTime(2026, 9, 9),
          categoryId: 1,
          merchantId: 1,
        ),
        _txn(TxnKind.expense, 2000, DateTime(2026, 9, 9), note: 'Market'),
        _txn(TxnKind.allocation, 50000, DateTime(2026, 9, 3), potId: 1),
        _txn(TxnKind.expense, 4000, DateTime(2026, 8, 30), categoryId: 1),
      ];
      final report = PeriodReport.build(
        period: ReportPeriod(ReportSpan.month, DateTime(2026, 9, 15)),
        txns: txns,
        merchantNames: {1: 'Albert Heijn'},
      );
      expect(report.incomeCents, 300000);
      expect(report.expenseCents, 14000);
      expect(report.netCents, 286000);
      expect(report.byCategory[1], 12000);
      expect(report.byCategory[null], 2000);
      expect(report.previousByCategory[1], 4000);
      expect(report.previousExpenseCents, 4000);
      expect(report.topMerchants.first.name, 'Albert Heijn');
      expect(report.topMerchants.first.count, 2);
      expect(report.transactions, hasLength(5));
      expect(report.savingsRate, closeTo(286000 / 300000, 1e-9));
    });

    test('year periods step by year', () {
      final p = ReportPeriod(ReportSpan.year, DateTime(2026, 6, 1));
      expect(p.start, DateTime(2026));
      expect(p.previous.start, DateTime(2025));
      expect(p.next.start, DateTime(2027));
      expect(
        ReportPeriod(ReportSpan.month, DateTime(2026, 1, 9)).previous.start,
        DateTime(2025, 12),
      );
    });
  });

  test('transactionsToCsv signs amounts and escapes fields', () {
    final csv = transactionsToCsv(
      txns: [
        _txn(
          TxnKind.expense,
          1250,
          DateTime(2026, 9, 3),
          categoryId: 1,
          merchantId: 2,
          note: 'Lunch, "big"',
        ),
        _txn(TxnKind.income, 5, DateTime(2026, 9, 4), note: '=SUM(A1)'),
      ],
      categoryNames: {1: 'Food'},
      merchantNames: {2: 'Cafe'},
      potNames: const {},
    );
    final lines = csv.split('\r\n');
    expect(lines[0], 'Date,Type,Amount,Category,Merchant,Pot,Note');
    expect(lines[1], '2026-09-03,expense,-12.50,Food,Cafe,,"Lunch, ""big"""');
    expect(lines[2], "2026-09-04,income,0.05,,,,'=SUM(A1)");
  });

  group('holding FX', () {
    Holding holding({String? currency, double? rate}) => Holding(
      id: 1,
      ticker: 'AAPL',
      name: 'Apple',
      shares: 2,
      avgCostCents: 10000,
      lastPriceCents: 15000,
      currency: currency,
      eurPerUnit: rate,
    );

    test('converts foreign holdings and leaves euro ones alone', () {
      expect(holding().valueEurCents, 30000);
      expect(holding(currency: 'USD', rate: 0.9).valueEurCents, 27000);
      expect(holding(currency: 'USD', rate: 0.9).costEurCents, 18000);
      expect(holding(currency: 'USD').missingFxRate, isTrue);
      expect(holding(currency: 'EUR').missingFxRate, isFalse);
    });

    test('pence quotes convert through pounds', () {
      expect(majorCurrency('GBp'), ('GBP', 100));
      expect(majorCurrency('usd'), ('USD', 1));
    });

    test('parses the ECB daily feed', () {
      const body = '''<?xml version="1.0" encoding="UTF-8"?>
<gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
  <Cube><Cube time="2026-09-25">
    <Cube currency="USD" rate="1.0823"/>
    <Cube currency="GBP" rate="0.8412"/>
  </Cube></Cube>
</gesmes:Envelope>''';
      expect(parseEcbRates(body), {'USD': 1.0823, 'GBP': 0.8412});
      expect(parseEcbRates('not xml'), isEmpty);
    });
  });

  group('FinanceRepository', () {
    late AppDatabase db;
    late FinanceRepository repo;

    setUp(() {
      // Every write pokes the storage-usage display; outside main.dart's
      // startup nothing has created it.
      StorageGuardService.instance = StorageGuardService();
      db = AppDatabase(NativeDatabase.memory());
      repo = FinanceRepository(db);
    });
    tearDown(() async {
      StorageGuardService.instance.dispose();
      await db.close();
    });

    test('debt payments book the ledger and net worth moves once', () async {
      final id = await repo.createDebt(
        DebtsCompanion.insert(
          name: 'Loan',
          direction: DebtDirection.owe,
          principalCents: 100000,
          startDate: DateTime(2026, 1, 1),
        ),
      );
      await repo.addTransaction(
        kind: TxnKind.income,
        amountCents: 200000,
        date: DateTime(2026, 1, 1),
      );
      expect(await repo.currentNetWorthCents(), 100000);

      final debt = await (db.select(
        db.debts,
      )..where((d) => d.id.equals(id))).getSingle();
      await repo.addDebtPayment(
        debt: debt,
        amountCents: 30000,
        date: DateTime(2026, 2, 1),
      );
      expect(await repo.currentMainCents(), 170000);
      expect(await repo.currentNetWorthCents(), 100000);

      await repo.adjustDebtBalance(debt, 75000);
      final payments = await db.select(db.debtPayments).get();
      expect(debtBalanceCents(debt, payments), 75000);
      expect(await repo.currentMainCents(), 170000);

      final booked = payments.firstWhere((p) => p.transactionId != null);
      await repo.deleteDebtPayment(booked);
      expect(await repo.currentMainCents(), 200000);
    });

    test('dividends book income and deleting one removes it', () async {
      await repo.upsertHolding(
        HoldingsCompanion.insert(
          ticker: 'ASML',
          name: 'ASML',
          shares: 1,
          avgCostCents: 60000,
          currency: const Value('EUR'),
        ),
      );
      final holding = (await db.select(db.holdings).get()).single;
      await repo.addDividend(
        holding: holding,
        amountCents: 164,
        date: DateTime(2026, 8, 1),
      );
      expect(await repo.currentMainCents(), 164);

      await repo.deleteHolding(holding.id);
      final dividend = (await db.select(db.dividends).get()).single;
      expect(dividend.holdingId, isNull);
      expect(dividend.ticker, 'ASML');

      await repo.deleteDividend(dividend);
      expect(await repo.currentMainCents(), 0);
    });

    test('price updates keep the last known currency and rate', () async {
      await repo.upsertHolding(
        HoldingsCompanion.insert(
          ticker: 'AAPL',
          name: 'Apple',
          shares: 1,
          avgCostCents: 100,
        ),
      );
      final id = (await db.select(db.holdings).get()).single.id;
      await repo.updateHoldingPrice(id, 200, currency: 'USD', eurPerUnit: 0.9);
      await repo.updateHoldingPrice(id, 300);
      final h = (await db.select(db.holdings).get()).single;
      expect(h.currency, 'USD');
      expect(h.eurPerUnit, 0.9);
      expect(h.lastPriceCents, 300);
    });

    test('budgets, goals and subscription dismissals persist', () async {
      final cat = (await repo.allCategories()).first;
      await repo.setCategoryBudgets({cat.id: 25000});
      expect(
        (await repo.allCategories())
            .firstWhere((c) => c.id == cat.id)
            .monthlyBudgetCents,
        25000,
      );
      await repo.setCategoryBudgets({cat.id: null});
      expect(
        (await repo.allCategories())
            .firstWhere((c) => c.id == cat.id)
            .monthlyBudgetCents,
        isNull,
      );

      final potId = await repo.createPot(
        name: 'Car',
        colorValue: 0,
        iconCodepoint: 0,
      );
      await repo.setPotGoal(
        potId,
        goalCents: 500000,
        goalDate: DateTime(2027, 6, 1),
      );
      var pot = (await repo.allPots()).single;
      expect(pot.goalCents, 500000);
      await repo.setPotGoal(potId);
      pot = (await repo.allPots()).single;
      expect(pot.goalCents, isNull);
      expect(pot.goalDate, isNull);

      await repo.dismissSubscription('m:3');
      await repo.dismissSubscription('n:gym');
      expect(await repo.watchDismissedSubscriptions().first, {'m:3', 'n:gym'});
    });
  });
}

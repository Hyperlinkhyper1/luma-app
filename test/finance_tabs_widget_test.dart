import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_page.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/finance_scope.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

/// Renders every Finance tab touched by budgets, goals, debts, the forecast,
/// the subscription detector, reports and dividends — on a desktop window and
/// on a phone — against a real in-memory database. A layout overflow fails
/// the test on its own.
///
/// Drift's futures only complete in real time, so every query runs through
/// `runAsync` and frames are driven by [settle] rather than `pumpAndSettle`
/// (StreamData's spinner never stops animating).
void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FinanceRepository(db);
    StorageGuardService.instance = StorageGuardService();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
  }

  Future<void> seed() async {
    final now = DateTime.now();
    final cats = await repo.allCategories();
    await repo.setCategoryBudgets({cats[0].id: 20000, cats[1].id: 5000});

    final potId = await repo.createPot(
        name: 'Holiday', colorValue: 0xFF2196F3, iconCodepoint: 0xe0b0);
    await repo.setPotGoal(potId,
        goalCents: 150000, goalDate: DateTime(now.year + 1, now.month, 1));
    await repo.allocateToPot(potId, 40000);

    await repo.addTransaction(
        kind: TxnKind.income, amountCents: 300000, date: now);
    await repo.addTransaction(
        kind: TxnKind.expense,
        amountCents: 18000,
        date: now,
        categoryId: cats[0].id,
        note: 'Groceries');
    await repo.addTransaction(
        kind: TxnKind.expense,
        amountCents: 7000,
        date: now,
        categoryId: cats[1].id,
        note: 'Night out');
    final merchant = (await repo.allMerchants()).first;
    for (var i = 0; i < 4; i++) {
      await repo.addTransaction(
        kind: TxnKind.expense,
        amountCents: 1399,
        date: DateTime(now.year, now.month - i, 3),
        merchantId: merchant.id,
      );
    }

    await repo.createRecurring(RecurringRulesCompanion.insert(
      name: 'Rent',
      kind: TxnKind.expense,
      amountCents: 450000,
      cadence: Cadence.monthly,
      nextDue: now.add(const Duration(days: 5)),
    ));

    final debtId = await repo.createDebt(DebtsCompanion.insert(
      name: 'Student loan with a rather long name',
      direction: DebtDirection.owe,
      principalCents: 2500000,
      interestBps: const Value(256),
      monthlyPaymentCents: const Value(25000),
      startDate: DateTime(2022),
    ));
    final debt = (await db.select(db.debts).get())
        .firstWhere((d) => d.id == debtId);
    await repo.addDebtPayment(debt: debt, amountCents: 25000, date: now);
    await repo.createDebt(DebtsCompanion.insert(
      name: 'Sam',
      direction: DebtDirection.owed,
      principalCents: 4500,
      startDate: now,
    ));

    await repo.upsertHolding(HoldingsCompanion.insert(
      ticker: 'AAPL',
      name: 'Apple Inc.',
      shares: 3,
      avgCostCents: 15000,
      lastPriceCents: const Value(22000),
      lastPriceAt: Value(now),
      currency: const Value('USD'),
      eurPerUnit: const Value(0.92),
    ));
    final holding = (await db.select(db.holdings).get()).single;
    await repo.addDividend(holding: holding, amountCents: 120, date: now);
  }

  for (final size in const [Size(1280, 900), Size(390, 844)]) {
    final label = size.width < 600 ? 'phone' : 'desktop';

    testWidgets('finance tabs render on $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(seed);
      await tester.pumpWidget(MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: FinanceScope(repository: repo, child: const FinancePage()),
        ),
      ));
      await settle(tester);

      Future<void> open(String tab) async {
        final finder = find.text(tab).first;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await settle(tester);
      }

      // Overview: forecast, budgets and the pot goal.
      expect(find.text('Cash-flow forecast'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.textContaining('Heading below'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('% of '),
        200,
        scrollable: find
            .ancestor(of: find.text('Budgets'), matching: find.byType(Scrollable))
            .first,
      );
      expect(find.textContaining('% of '), findsWidgets);

      await open('Pots');
      expect(find.textContaining('/month until'), findsOneWidget);

      await open('Recurring');
      expect(find.text('1 possible subscription'), findsOneWidget);

      await open('Debts');
      expect(find.textContaining('Paid off by'), findsOneWidget);
      expect(find.text('Owed to you'), findsWidgets);

      await open('Stocks');
      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.textContaining('Dividends'), findsWidgets);

      await open('Reports');
      expect(find.text('Spending by category'), findsOneWidget);
      expect(find.text('Top merchants'), findsOneWidget);
      await open('Year');
      expect(find.text('Month by month'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      StorageGuardService.instance.dispose();
      await tester.pump(const Duration(seconds: 4));
    });
  }
}

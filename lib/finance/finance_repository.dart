import 'dart:convert';

import 'package:drift/drift.dart';

import '../storage/storage_guard.dart';
import 'data/database.dart';
import 'logic/finance_logic.dart';
import 'logic/holding_value.dart';
import 'logic/insights.dart';
import 'logic/planning.dart';

class FinanceImportMatch {
  const FinanceImportMatch({this.transaction, this.rule, required this.date});

  final FinanceTransaction? transaction;
  final RecurringRule? rule;
  final DateTime date;

  String get name => transaction?.note ?? rule?.name ?? 'Existing transaction';
}

/// Application-facing API over the drift database: reactive reads, commands,
/// and the engine that applies due recurring rules and allocations.
class FinanceRepository {
  FinanceRepository(this.db);

  final AppDatabase db;

  // ---- Reactive reads -------------------------------------------------------

  Stream<List<Pot>> watchPots() => (db.select(
    db.pots,
  )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();

  Stream<List<FinanceTransaction>> watchTransactions({int? limit}) {
    final q = db.select(db.financeTransactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Stream<List<Category>> watchCategories() => (db.select(
    db.categories,
  )..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();

  Stream<List<Merchant>> watchMerchants() => (db.select(
    db.merchants,
  )..orderBy([(m) => OrderingTerm(expression: m.name)])).watch();

  Stream<List<RecurringRule>> watchRecurring() => (db.select(
    db.recurringRules,
  )..orderBy([(r) => OrderingTerm(expression: r.nextDue)])).watch();

  /// Active bills/subscriptions currently within their own
  /// [RecurringRule.reminderDaysBefore] window of [now], soonest first â€”
  /// the "due soon" reminder list.
  Stream<List<RecurringRule>> watchDueBills({DateTime? now}) {
    final today = now ?? DateTime.now();
    return (db.select(db.recurringRules)
          ..where((r) => r.active.equals(true) & r.isBill.equals(true))
          ..orderBy([(r) => OrderingTerm(expression: r.nextDue)]))
        .watch()
        .map(
          (rules) => rules
              .where(
                (r) => !r.nextDue.isAfter(
                  today.add(Duration(days: r.reminderDaysBefore)),
                ),
              )
              .toList(),
        );
  }

  Stream<List<AllocationRule>> watchAllocationRules() =>
      db.select(db.allocationRules).watch();

  Stream<List<Holding>> watchHoldings() => (db.select(
    db.holdings,
  )..orderBy([(h) => OrderingTerm(expression: h.ticker)])).watch();

  Stream<List<OverviewGraph>> watchOverviewGraphs() => (db.select(
    db.overviewGraphs,
  )..orderBy([(g) => OrderingTerm(expression: g.sortOrder)])).watch();

  Stream<List<Debt>> watchDebts() => (db.select(
    db.debts,
  )..orderBy([(d) => OrderingTerm(expression: d.name)])).watch();

  Stream<List<DebtPayment>> watchDebtPayments() =>
      (db.select(db.debtPayments)..orderBy([
            (p) => OrderingTerm.desc(p.date),
            (p) => OrderingTerm.desc(p.id),
          ]))
          .watch();

  Stream<List<Dividend>> watchDividends() =>
      (db.select(db.dividends)..orderBy([
            (d) => OrderingTerm.desc(d.date),
            (d) => OrderingTerm.desc(d.id),
          ]))
          .watch();

  Future<List<Category>> allCategories() => db.select(db.categories).get();
  Future<List<Merchant>> allMerchants() => (db.select(
    db.merchants,
  )..orderBy([(m) => OrderingTerm(expression: m.name)])).get();
  Future<List<Pot>> allPots() => (db.select(
    db.pots,
  )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();

  // ---- Transactions ---------------------------------------------------------

  /// Suggestions require confirmation: two payments can share an amount/date.
  Future<List<FinanceImportMatch>> findImportMatches({
    required TxnKind kind,
    required int amountCents,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final start = day.subtract(const Duration(days: 3));
    final end = day.add(const Duration(days: 4));
    final existing =
        await (db.select(db.financeTransactions)..where(
              (t) =>
                  t.kind.equalsValue(kind) &
                  t.amountCents.equals(amountCents) &
                  t.date.isBiggerOrEqualValue(start) &
                  t.date.isSmallerThanValue(end),
            ))
            .get();
    final matches = [
      for (final t in existing)
        FinanceImportMatch(transaction: t, date: t.date),
    ];
    final rules =
        await (db.select(db.recurringRules)..where(
              (r) =>
                  r.active.equals(true) &
                  r.kind.equalsValue(kind) &
                  r.amountCents.equals(amountCents),
            ))
            .get();
    for (final rule in rules) {
      for (final due in dueOccurrences(rule.nextDue, rule.cadence, end)) {
        if (due.isBefore(start) || !due.isBefore(end)) continue;
        if (await _occurrenceTransaction(rule.id, due) != null) continue;
        matches.add(FinanceImportMatch(rule: rule, date: due));
      }
    }
    return matches;
  }

  static String _occurrenceKey(int ruleId, DateTime due) =>
      'finance_recurring_${ruleId}_${due.year}_${due.month}_${due.day}';

  Future<int?> _occurrenceTransaction(int ruleId, DateTime due) async {
    final row =
        await (db.select(db.metaItems)
              ..where((m) => m.key.equals(_occurrenceKey(ruleId, due))))
            .getSingleOrNull();
    return int.tryParse(row?.value ?? '');
  }

  Future<void> _linkOccurrence(int ruleId, DateTime due, int transactionId) =>
      db
          .into(db.metaItems)
          .insertOnConflictUpdate(
            MetaItemsCompanion.insert(
              key: _occurrenceKey(ruleId, due),
              value: '$transactionId',
            ),
          );

  /// Reuses a confirmed ledger entry or books a confirmed recurring occurrence.
  /// The occurrence link survives restarts and prevents applyDue booking twice.
  Future<int> importTransaction({
    required TxnKind kind,
    required int amountCents,
    required DateTime date,
    String? note,
    int? potId,
    int? merchantId,
    int? categoryId,
    FinanceImportMatch? match,
  }) => db.transaction(() async {
    if (match != null) {
      final current = await findImportMatches(
        kind: kind,
        amountCents: amountCents,
        date: date,
      );
      final valid = current.any(
        (m) =>
            m.transaction?.id == match.transaction?.id &&
            m.rule?.id == match.rule?.id &&
            m.date == match.date,
      );
      if (!valid) {
        throw StateError('This match changed. Review the entry again.');
      }
      if (match.transaction != null) return match.transaction!.id;
    }
    final rule = match?.rule;
    final id = await addTransaction(
      kind: kind,
      amountCents: amountCents,
      date: date,
      note: note,
      potId: rule == null ? potId : rule.potId,
      merchantId: rule == null ? merchantId : rule.merchantId,
      categoryId: rule == null ? categoryId : rule.categoryId,
    );
    if (rule != null) await _linkOccurrence(rule.id, match!.date, id);
    return id;
  });

  Future<int> addTransaction({
    required TxnKind kind,
    required int amountCents,
    required DateTime date,
    String? note,
    int? potId,
    int? merchantId,
    int? categoryId,
  }) async {
    final id = await db
        .into(db.financeTransactions)
        .insert(
          FinanceTransactionsCompanion.insert(
            kind: kind,
            amountCents: amountCents,
            date: date,
            note: Value(note),
            potId: Value(potId),
            merchantId: Value(merchantId),
            categoryId: Value(categoryId),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> updateTransaction({
    required int id,
    required TxnKind kind,
    required int amountCents,
    required DateTime date,
    String? note,
    int? potId,
    int? merchantId,
    int? categoryId,
  }) =>
      (db.update(db.financeTransactions)..where((t) => t.id.equals(id))).write(
        FinanceTransactionsCompanion(
          kind: Value(kind),
          amountCents: Value(amountCents),
          date: Value(date),
          note: Value(note),
          potId: Value(potId),
          merchantId: Value(merchantId),
          categoryId: Value(categoryId),
        ),
      );

  /// Deletes a ledger entry, unlinking any dividend or debt payment that
  /// booked it (the dividend or payment itself stays on record).
  Future<void> deleteTransaction(int id) => db.transaction(() async {
    await (db.update(db.dividends)..where((d) => d.transactionId.equals(id)))
        .write(const DividendsCompanion(transactionId: Value(null)));
    await (db.update(db.debtPayments)..where((p) => p.transactionId.equals(id)))
        .write(const DebtPaymentsCompanion(transactionId: Value(null)));
    await (db.delete(
      db.financeTransactions,
    )..where((t) => t.id.equals(id))).go();
  });

  // ---- Pots -----------------------------------------------------------------

  Future<int> createPot({
    required String name,
    required int colorValue,
    required int iconCodepoint,
  }) async {
    final pots = await allPots();
    final nextOrder = pots.isEmpty ? 0 : pots.last.sortOrder + 1;
    final id = await db
        .into(db.pots)
        .insert(
          PotsCompanion.insert(
            name: name,
            colorValue: colorValue,
            iconCodepoint: iconCodepoint,
            sortOrder: Value(nextOrder),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> updatePot(Pot pot) => db.update(db.pots).replace(pot);

  /// Sets or clears (null [goalCents]) a pot's savings goal.
  Future<void> setPotGoal(int potId, {int? goalCents, DateTime? goalDate}) =>
      (db.update(db.pots)..where((p) => p.id.equals(potId))).write(
        PotsCompanion(
          goalCents: Value(goalCents),
          goalDate: Value(goalCents == null ? null : goalDate),
        ),
      );

  // ---- Budgets --------------------------------------------------------------

  /// Sets or clears (null) the monthly budgets of several categories at once.
  Future<void> setCategoryBudgets(Map<int, int?> budgetByCategory) => db.batch((
    b,
  ) {
    budgetByCategory.forEach((id, cents) {
      b.update(
        db.categories,
        CategoriesCompanion(
          monthlyBudgetCents: Value(cents == null || cents <= 0 ? null : cents),
        ),
        where: (c) => c.id.equals(id),
      );
    });
  });

  /// Deletes a pot, detaching its transactions and removing its allocation
  /// rules. Detached expenses fall back to the main balance.
  Future<void> deletePot(int id) async {
    await (db.update(db.financeTransactions)..where((t) => t.potId.equals(id)))
        .write(const FinanceTransactionsCompanion(potId: Value(null)));
    await (db.delete(
      db.allocationRules,
    )..where((a) => a.potId.equals(id))).go();
    await (db.delete(db.pots)..where((p) => p.id.equals(id))).go();
  }

  /// Moves [amountCents] from the main balance into [potId] right now.
  Future<void> allocateToPot(int potId, int amountCents, {String? note}) {
    return addTransaction(
      kind: TxnKind.allocation,
      amountCents: amountCents,
      date: DateTime.now(),
      potId: potId,
      note: note ?? 'Manual allocation',
    );
  }

  // ---- Recurring & allocation rules ----------------------------------------

  Future<int> createRecurring(RecurringRulesCompanion rule) async {
    final id = await db.into(db.recurringRules).insert(rule);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> deleteRecurring(int id) =>
      (db.delete(db.recurringRules)..where((r) => r.id.equals(id))).go();
  Future<void> setRecurringActive(int id, bool active) =>
      (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(active: Value(active)),
      );

  Future<int> createAllocationRule(AllocationRulesCompanion rule) async {
    final id = await db.into(db.allocationRules).insert(rule);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> deleteAllocationRule(int id) =>
      (db.delete(db.allocationRules)..where((a) => a.id.equals(id))).go();

  // ---- Holdings -------------------------------------------------------------

  Future<int> upsertHolding(HoldingsCompanion holding) async {
    final id = await db
        .into(db.holdings)
        .insert(holding, mode: InsertMode.insertOrReplace);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  /// Deletes a holding. Its dividends stay in the history under their
  /// ticker, just no longer linked to a position.
  Future<void> deleteHolding(int id) async {
    await (db.update(db.dividends)..where((d) => d.holdingId.equals(id))).write(
      const DividendsCompanion(holdingId: Value(null)),
    );
    await (db.delete(db.holdings)..where((h) => h.id.equals(id))).go();
  }

  /// Stores a fresh quote. [currency] and [eurPerUnit] are only overwritten
  /// when given, so a price from a source that doesn't report its currency
  /// keeps the holding's last known one — and a failed rate lookup keeps
  /// the last good rate rather than silently treating a dollar as a euro.
  Future<void> updateHoldingPrice(
    int id,
    int priceCents, {
    String? currency,
    double? eurPerUnit,
  }) => (db.update(db.holdings)..where((h) => h.id.equals(id))).write(
    HoldingsCompanion(
      lastPriceCents: Value(priceCents),
      lastPriceAt: Value(DateTime.now()),
      currency: currency == null ? const Value.absent() : Value(currency),
      eurPerUnit: eurPerUnit == null ? const Value.absent() : Value(eurPerUnit),
    ),
  );

  // ---- Dividends ------------------------------------------------------------

  /// Logs a dividend of [amountCents] euros. With [bookAsIncome] it is also
  /// added to the main balance as an income entry.
  Future<int> addDividend({
    required Holding holding,
    required int amountCents,
    required DateTime date,
    String? note,
    bool bookAsIncome = true,
  }) async {
    int? txnId;
    if (bookAsIncome) {
      txnId = await addTransaction(
        kind: TxnKind.income,
        amountCents: amountCents,
        date: date,
        note: 'Dividend ${holding.ticker}',
      );
    }
    final id = await db
        .into(db.dividends)
        .insert(
          DividendsCompanion.insert(
            holdingId: Value(holding.id),
            ticker: holding.ticker,
            amountCents: amountCents,
            date: date,
            note: Value(note),
            transactionId: Value(txnId),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  /// Deletes a dividend and the income entry it booked, if any.
  Future<void> deleteDividend(Dividend dividend) => db.transaction(() async {
    await (db.delete(
      db.dividends,
    )..where((d) => d.id.equals(dividend.id))).go();
    final txnId = dividend.transactionId;
    if (txnId != null) await deleteTransaction(txnId);
  });

  // ---- Debts ----------------------------------------------------------------

  Future<int> createDebt(DebtsCompanion debt) async {
    final id = await db.into(db.debts).insert(debt);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> updateDebt(Debt debt) => db.update(db.debts).replace(debt);

  /// Deletes a debt and its payment history. Ledger entries the payments
  /// booked are kept: that money really did leave or reach the main balance.
  Future<void> deleteDebt(int id) => db.transaction(() async {
    await (db.delete(db.debtPayments)..where((p) => p.debtId.equals(id))).go();
    await (db.delete(db.debts)..where((d) => d.id.equals(id))).go();
  });

  /// Records a payment on [debt]. With [bookInLedger], a debt the user owes
  /// books an expense from the main balance and a debt owed to the user
  /// books an income, so net worth doesn't move twice.
  Future<int> addDebtPayment({
    required Debt debt,
    required int amountCents,
    required DateTime date,
    String? note,
    bool bookInLedger = true,
  }) async {
    int? txnId;
    if (bookInLedger && amountCents > 0) {
      final owe = debt.direction == DebtDirection.owe;
      txnId = await addTransaction(
        kind: owe ? TxnKind.expense : TxnKind.income,
        amountCents: amountCents,
        date: date,
        note: owe ? 'Repayment: ${debt.name}' : 'Repaid to me: ${debt.name}',
      );
    }
    final id = await db
        .into(db.debtPayments)
        .insert(
          DebtPaymentsCompanion.insert(
            debtId: debt.id,
            amountCents: amountCents,
            date: date,
            note: Value(note),
            transactionId: Value(txnId),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  /// Corrects [debt]'s outstanding balance to [targetCents] (e.g. from a
  /// lender's statement, after interest) without touching the ledger.
  Future<void> adjustDebtBalance(Debt debt, int targetCents) async {
    final payments = await (db.select(
      db.debtPayments,
    )..where((p) => p.debtId.equals(debt.id))).get();
    final current = debtBalanceCents(debt, payments);
    if (current == targetCents) return;
    await addDebtPayment(
      debt: debt,
      amountCents: current - targetCents,
      date: DateTime.now(),
      note: 'Balance adjustment',
      bookInLedger: false,
    );
  }

  /// Deletes a payment and the ledger entry it booked, if any.
  Future<void> deleteDebtPayment(DebtPayment payment) =>
      db.transaction(() async {
        await (db.delete(
          db.debtPayments,
        )..where((p) => p.id.equals(payment.id))).go();
        final txnId = payment.transactionId;
        if (txnId != null) await deleteTransaction(txnId);
      });

  // ---- Subscription detector ------------------------------------------------

  static const _dismissedSubscriptionsKey = 'dismissed_subscriptions';

  Stream<Set<String>> watchDismissedSubscriptions() =>
      (db.select(db.metaItems)
            ..where((m) => m.key.equals(_dismissedSubscriptionsKey)))
          .watchSingleOrNull()
          .map((row) => _decodeKeys(row?.value));

  /// Hides a detected subscription for good.
  Future<void> dismissSubscription(String key) async {
    final row =
        await (db.select(db.metaItems)
              ..where((m) => m.key.equals(_dismissedSubscriptionsKey)))
            .getSingleOrNull();
    final keys = _decodeKeys(row?.value)..add(key);
    await db
        .into(db.metaItems)
        .insertOnConflictUpdate(
          MetaItemsCompanion.insert(
            key: _dismissedSubscriptionsKey,
            value: jsonEncode(keys.toList()..sort()),
          ),
        );
  }

  /// Turns a detected subscription into a tracked bill whose next charge is
  /// one period after the last one seen.
  Future<int> trackSubscription(SubscriptionCandidate c) => createRecurring(
    RecurringRulesCompanion.insert(
      name: c.name,
      kind: TxnKind.expense,
      amountCents: c.amountCents,
      cadence: c.cadence,
      nextDue: c.nextDue,
      merchantId: Value(c.merchantId),
      categoryId: Value(c.categoryId),
      isBill: const Value(true),
    ),
  );

  static Set<String> _decodeKeys(String? json) {
    if (json == null) return <String>{};
    try {
      return (jsonDecode(json) as List).cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  // ---- Overview Graphs ------------------------------------------------------

  Future<int> addOverviewGraph({
    required String graphType,
    required String dataSource,
  }) async {
    final current = await (db.select(
      db.overviewGraphs,
    )..orderBy([(g) => OrderingTerm(expression: g.sortOrder)])).get();
    final nextOrder = current.isEmpty ? 0 : current.last.sortOrder + 1;
    final id = await db
        .into(db.overviewGraphs)
        .insert(
          OverviewGraphsCompanion.insert(
            graphType: graphType,
            dataSource: dataSource,
            sortOrder: Value(nextOrder),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> deleteOverviewGraph(int id) =>
      (db.delete(db.overviewGraphs)..where((g) => g.id.equals(id))).go();

  Future<void> reorderOverviewGraphs(List<OverviewGraph> graphs) async {
    await db.batch((b) {
      for (var i = 0; i < graphs.length; i++) {
        final g = graphs[i];
        b.update(
          db.overviewGraphs,
          const OverviewGraphsCompanion().copyWith(sortOrder: Value(i)),
          where: (t) => t.id.equals(g.id),
        );
      }
    });
  }

  // ---- Derived values -------------------------------------------------------

  Future<int> currentMainCents() async {
    final txns = await db.select(db.financeTransactions).get();
    return computeBalances(txns).mainCents;
  }

  /// Cash net worth (main + pots) plus the market value of every holding
  /// (falling back to cost basis for holdings with no live price yet), in
  /// euros, plus money owed to the user minus money the user owes — the
  /// same total the net-worth chart tracks over time.
  Future<int> currentNetWorthCents() async {
    final txns = await db.select(db.financeTransactions).get();
    final cash = computeBalances(txns).totalCents;
    final invested = portfolioEurCents(await db.select(db.holdings).get());
    final debts = debtsNetCents(
      await db.select(db.debts).get(),
      await db.select(db.debtPayments).get(),
    );
    return cash + invested + debts;
  }

  /// Records today's net worth in [BalanceSnapshots] if it hasn't been
  /// recorded yet today â€” safe to call on every app start (see
  /// FinanceRepository.applyDue's callers). Overwrites today's snapshot if
  /// one already exists, so calling it more than once a day just keeps the
  /// total current rather than creating duplicates.
  Future<void> recordDailyNetWorthSnapshot({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final total = await currentNetWorthCents();
    await db
        .into(db.balanceSnapshots)
        .insertOnConflictUpdate(
          BalanceSnapshotsCompanion.insert(date: today, totalCents: total),
        );
  }

  /// Net worth history, oldest first, for the overview chart.
  Stream<List<BalanceSnapshot>> watchNetWorthHistory() => (db.select(
    db.balanceSnapshots,
  )..orderBy([(s) => OrderingTerm(expression: s.date)])).watch();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Applies every recurring rule and allocation rule that is due on or before
  /// [now], catching up one entry per missed period. Returns how many ledger
  /// entries were created. Safe to call on every app start.
  Future<int> applyDue(DateTime now) => db.transaction(() async {
    var created = 0;

    final rules = await (db.select(
      db.recurringRules,
    )..where((r) => r.active.equals(true))).get();
    for (final r in rules) {
      final occurrences = dueOccurrences(r.nextDue, r.cadence, now);
      if (occurrences.isEmpty) continue;
      DateTime? lastApplied;
      for (final date in occurrences) {
        if (await _occurrenceTransaction(r.id, date) != null) {
          lastApplied = date;
          continue;
        }
        final id = await addTransaction(
          kind: r.kind,
          amountCents: r.amountCents,
          date: date,
          note: r.name,
          potId: r.potId,
          merchantId: r.merchantId,
          categoryId: r.categoryId,
        );
        await _linkOccurrence(r.id, date, id);
        created++;
        lastApplied = date;
      }
      if (lastApplied != null) {
        await (db.update(
          db.recurringRules,
        )..where((x) => x.id.equals(r.id))).write(
          RecurringRulesCompanion(
            nextDue: Value(advanceDate(lastApplied, r.cadence)),
            lastApplied: Value(lastApplied),
          ),
        );
      }
    }

    final allocRules = await (db.select(
      db.allocationRules,
    )..where((a) => a.active.equals(true))).get();
    for (final a in allocRules) {
      final occurrences = dueOccurrences(a.nextDue, a.cadence, now);
      if (occurrences.isEmpty) continue;
      DateTime? lastApplied;
      for (final date in occurrences) {
        final base = await currentMainCents();
        final amount = allocationAmountCents(
          mode: a.mode,
          valueCents: a.valueCents,
          percentBps: a.percentBps,
          baseCents: base,
        );
        if (amount <= 0) {
          lastApplied = date;
          continue;
        }
        await db
            .into(db.financeTransactions)
            .insert(
              FinanceTransactionsCompanion.insert(
                kind: TxnKind.allocation,
                amountCents: amount,
                date: date,
                potId: Value(a.potId),
                note: const Value('Auto-allocation'),
              ),
            );
        StorageGuard.instance.scheduleRefresh();
        created++;
        lastApplied = date;
      }
      if (lastApplied != null) {
        await (db.update(
          db.allocationRules,
        )..where((x) => x.id.equals(a.id))).write(
          AllocationRulesCompanion(
            nextDue: Value(advanceDate(lastApplied, a.cadence)),
            lastApplied: Value(lastApplied),
          ),
        );
      }
    }

    return created;
  });
}

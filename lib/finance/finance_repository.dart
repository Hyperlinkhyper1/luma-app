import 'package:drift/drift.dart';

import 'data/database.dart';
import 'logic/finance_logic.dart';

/// Application-facing API over the drift database: reactive reads, commands,
/// and the engine that applies due recurring rules and allocations.
class FinanceRepository {
  FinanceRepository(this.db);

  final AppDatabase db;

  // ---- Reactive reads -------------------------------------------------------

  Stream<List<Pot>> watchPots() =>
      (db.select(db.pots)..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .watch();

  Stream<List<FinanceTransaction>> watchTransactions({int? limit}) {
    final q = db.select(db.financeTransactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Stream<List<Category>> watchCategories() =>
      (db.select(db.categories)..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .watch();

  Stream<List<Merchant>> watchMerchants() =>
      (db.select(db.merchants)..orderBy([(m) => OrderingTerm(expression: m.name)]))
          .watch();

  Stream<List<RecurringRule>> watchRecurring() =>
      (db.select(db.recurringRules)..orderBy([(r) => OrderingTerm(expression: r.nextDue)]))
          .watch();

  Stream<List<AllocationRule>> watchAllocationRules() =>
      db.select(db.allocationRules).watch();

  Stream<List<Holding>> watchHoldings() =>
      (db.select(db.holdings)..orderBy([(h) => OrderingTerm(expression: h.ticker)]))
          .watch();

  Stream<List<OverviewGraph>> watchOverviewGraphs() =>
      (db.select(db.overviewGraphs)..orderBy([(g) => OrderingTerm(expression: g.sortOrder)]))
          .watch();

  Future<List<Category>> allCategories() => db.select(db.categories).get();
  Future<List<Merchant>> allMerchants() =>
      (db.select(db.merchants)..orderBy([(m) => OrderingTerm(expression: m.name)]))
          .get();
  Future<List<Pot>> allPots() =>
      (db.select(db.pots)..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();

  // ---- Transactions ---------------------------------------------------------

  Future<int> addTransaction({
    required TxnKind kind,
    required int amountCents,
    required DateTime date,
    String? note,
    int? potId,
    int? merchantId,
    int? categoryId,
  }) {
    return db.into(db.financeTransactions).insert(
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
  }

  Future<void> deleteTransaction(int id) =>
      (db.delete(db.financeTransactions)..where((t) => t.id.equals(id))).go();

  // ---- Pots -----------------------------------------------------------------

  Future<int> createPot({
    required String name,
    required int colorValue,
    required int iconCodepoint,
  }) async {
    final pots = await allPots();
    final nextOrder = pots.isEmpty ? 0 : pots.last.sortOrder + 1;
    return db.into(db.pots).insert(PotsCompanion.insert(
          name: name,
          colorValue: colorValue,
          iconCodepoint: iconCodepoint,
          sortOrder: Value(nextOrder),
        ));
  }

  Future<void> updatePot(Pot pot) => db.update(db.pots).replace(pot);

  /// Deletes a pot, detaching its transactions and removing its allocation
  /// rules. Detached expenses fall back to the main balance.
  Future<void> deletePot(int id) async {
    await (db.update(db.financeTransactions)..where((t) => t.potId.equals(id)))
        .write(const FinanceTransactionsCompanion(potId: Value(null)));
    await (db.delete(db.allocationRules)..where((a) => a.potId.equals(id))).go();
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

  Future<int> createRecurring(RecurringRulesCompanion rule) =>
      db.into(db.recurringRules).insert(rule);
  Future<void> deleteRecurring(int id) =>
      (db.delete(db.recurringRules)..where((r) => r.id.equals(id))).go();
  Future<void> setRecurringActive(int id, bool active) =>
      (db.update(db.recurringRules)..where((r) => r.id.equals(id)))
          .write(RecurringRulesCompanion(active: Value(active)));

  Future<int> createAllocationRule(AllocationRulesCompanion rule) =>
      db.into(db.allocationRules).insert(rule);
  Future<void> deleteAllocationRule(int id) =>
      (db.delete(db.allocationRules)..where((a) => a.id.equals(id))).go();

  // ---- Holdings -------------------------------------------------------------

  Future<int> upsertHolding(HoldingsCompanion holding) =>
      db.into(db.holdings).insert(holding, mode: InsertMode.insertOrReplace);
  Future<void> deleteHolding(int id) =>
      (db.delete(db.holdings)..where((h) => h.id.equals(id))).go();
  Future<void> updateHoldingPrice(int id, int priceCents) =>
      (db.update(db.holdings)..where((h) => h.id.equals(id))).write(
        HoldingsCompanion(
          lastPriceCents: Value(priceCents),
          lastPriceAt: Value(DateTime.now()),
        ),
      );

  // ---- Overview Graphs ------------------------------------------------------

  Future<int> addOverviewGraph({required String graphType, required String dataSource}) async {
    final current = await (db.select(db.overviewGraphs)..orderBy([(g) => OrderingTerm(expression: g.sortOrder)])).get();
    final nextOrder = current.isEmpty ? 0 : current.last.sortOrder + 1;
    return db.into(db.overviewGraphs).insert(OverviewGraphsCompanion.insert(
      graphType: graphType,
      dataSource: dataSource,
      sortOrder: Value(nextOrder),
    ));
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

  /// Applies every recurring rule and allocation rule that is due on or before
  /// [now], catching up one entry per missed period. Returns how many ledger
  /// entries were created. Safe to call on every app start.
  Future<int> applyDue(DateTime now) async {
    var created = 0;

    final rules = await (db.select(db.recurringRules)
          ..where((r) => r.active.equals(true)))
        .get();
    for (final r in rules) {
      final occurrences = dueOccurrences(r.nextDue, r.cadence, now);
      if (occurrences.isEmpty) continue;
      for (final date in occurrences) {
        await addTransaction(
          kind: r.kind,
          amountCents: r.amountCents,
          date: date,
          note: r.name,
          potId: r.potId,
          merchantId: r.merchantId,
          categoryId: r.categoryId,
        );
        created++;
      }
      await (db.update(db.recurringRules)..where((x) => x.id.equals(r.id))).write(
        RecurringRulesCompanion(
          nextDue: Value(advanceDate(occurrences.last, r.cadence)),
          lastApplied: Value(occurrences.last),
        ),
      );
    }

    final allocRules = await (db.select(db.allocationRules)
          ..where((a) => a.active.equals(true)))
        .get();
    for (final a in allocRules) {
      final occurrences = dueOccurrences(a.nextDue, a.cadence, now);
      if (occurrences.isEmpty) continue;
      for (final date in occurrences) {
        final base = await currentMainCents();
        final amount = allocationAmountCents(
          mode: a.mode,
          valueCents: a.valueCents,
          percentBps: a.percentBps,
          baseCents: base,
        );
        if (amount <= 0) continue;
        await db.into(db.financeTransactions).insert(
              FinanceTransactionsCompanion.insert(
                kind: TxnKind.allocation,
                amountCents: amount,
                date: date,
                potId: Value(a.potId),
                note: const Value('Auto-allocation'),
              ),
            );
        created++;
      }
      await (db.update(db.allocationRules)..where((x) => x.id.equals(a.id)))
          .write(
        AllocationRulesCompanion(
          nextDue: Value(advanceDate(occurrences.last, a.cadence)),
          lastApplied: Value(occurrences.last),
        ),
      );
    }

    return created;
  }
}

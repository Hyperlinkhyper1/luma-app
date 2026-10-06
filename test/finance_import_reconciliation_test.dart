import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;
  setUp(() {
    StorageGuardService.instance = _TestStorageGuard();
    db = AppDatabase(NativeDatabase.memory());
    repo = FinanceRepository(db);
  });
  tearDown(() async {
    StorageGuardService.instance.dispose();
    await db.close();
  });

  Future<int> rule(TxnKind kind) => repo.createRecurring(
    RecurringRulesCompanion.insert(
      name: 'Recurring payment',
      kind: kind,
      amountCents: 200000,
      cadence: Cadence.monthly,
      nextDue: DateTime(2026, 10, 5),
    ),
  );

  for (final kind in [TxnKind.income, TxnKind.expense]) {
    final balance = kind == TxnKind.income ? 200000 : -200000;
    test('$kind imported before recurring processing counts once', () async {
      await rule(kind);
      final matches = await repo.findImportMatches(
        kind: kind,
        amountCents: 200000,
        date: DateTime(2026, 10, 7),
      );
      expect(matches, hasLength(1));
      await repo.importTransaction(
        kind: kind,
        amountCents: 200000,
        date: DateTime(2026, 10, 7),
        note: 'Bank description',
        match: matches.single,
      );
      repo = FinanceRepository(db);
      expect(await repo.applyDue(DateTime(2026, 10, 8)), 0);
      expect(await repo.currentMainCents(), balance);
      final saved = (await repo.watchTransactions().first).single;
      expect(saved.date, DateTime(2026, 10, 7));
      expect(saved.note, 'Bank description');
      final updated = (await repo.watchRecurring().first).single;
      expect(updated.nextDue, DateTime(2026, 11, 5));
      expect(await repo.applyDue(DateTime(2026, 11, 5)), 1);
      expect(await repo.currentMainCents(), balance * 2);
    });

    test(
      '$kind imported after recurring processing reuses the ledger',
      () async {
        await rule(kind);
        await repo.applyDue(DateTime(2026, 10, 5));
        final original = (await repo.watchTransactions().first).single;
        final matches = await repo.findImportMatches(
          kind: kind,
          amountCents: 200000,
          date: DateTime(2026, 10, 6),
        );
        final id = await repo.importTransaction(
          kind: kind,
          amountCents: 200000,
          date: DateTime(2026, 10, 6),
          match: matches.single,
        );
        expect(id, original.id);
        expect(await repo.currentMainCents(), balance);
        expect(await repo.watchTransactions().first, [original]);
      },
    );
  }

  test(
    'unconfirmed equal payments remain separate and candidates are bounded',
    () async {
      await rule(TxnKind.income);
      await repo.addTransaction(
        kind: TxnKind.income,
        amountCents: 200000,
        date: DateTime(2026, 10, 5),
      );
      expect(
        await repo.findImportMatches(
          kind: TxnKind.expense,
          amountCents: 200000,
          date: DateTime(2026, 10, 5),
        ),
        isEmpty,
      );
      expect(
        await repo.findImportMatches(
          kind: TxnKind.income,
          amountCents: 200001,
          date: DateTime(2026, 10, 5),
        ),
        isEmpty,
      );
      expect(
        await repo.findImportMatches(
          kind: TxnKind.income,
          amountCents: 200000,
          date: DateTime(2026, 10, 15),
        ),
        isEmpty,
      );
      await repo.importTransaction(
        kind: TxnKind.income,
        amountCents: 200000,
        date: DateTime(2026, 10, 5),
      );
      expect(await repo.currentMainCents(), 400000);
    },
  );

  test('a stale recurring match cannot create another payment', () async {
    await rule(TxnKind.income);
    final match = (await repo.findImportMatches(
      kind: TxnKind.income,
      amountCents: 200000,
      date: DateTime(2026, 10, 5),
    )).single;
    await repo.applyDue(DateTime(2026, 10, 5));
    await expectLater(
      repo.importTransaction(
        kind: TxnKind.income,
        amountCents: 200000,
        date: DateTime(2026, 10, 5),
        match: match,
      ),
      throwsStateError,
    );
    expect(await repo.currentMainCents(), 200000);
  });

  test('recurring import preserves rule pot and category', () async {
    final pot = await repo.createPot(
      name: 'Bills',
      colorValue: 0,
      iconCodepoint: 0,
    );
    final category = (await repo.allCategories()).first.id;
    await repo.createRecurring(
      RecurringRulesCompanion.insert(
        name: 'Rent',
        kind: TxnKind.expense,
        amountCents: 90000,
        cadence: Cadence.monthly,
        nextDue: DateTime(2026, 10, 5),
        potId: Value(pot),
        categoryId: Value(category),
      ),
    );
    final match = (await repo.findImportMatches(
      kind: TxnKind.expense,
      amountCents: 90000,
      date: DateTime(2026, 10, 5),
    )).single;
    await repo.importTransaction(
      kind: TxnKind.expense,
      amountCents: 90000,
      date: DateTime(2026, 10, 5),
      match: match,
    );
    final saved = (await repo.watchTransactions().first).single;
    expect(saved.potId, pot);
    expect(saved.categoryId, category);
    expect(await repo.applyDue(DateTime(2026, 10, 5)), 0);
    expect(await repo.currentNetWorthCents(), -90000);
  });
}

class _TestStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

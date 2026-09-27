import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/finance_ai_tools.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/stock_service.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;
  late FinanceAiTools tools;

  setUp(() {
    StorageGuardService.instance = StorageGuardService();
    db = AppDatabase(NativeDatabase.memory());
    repo = FinanceRepository(db);
    tools = FinanceAiTools(repo);
  });

  tearDown(() async {
    StorageGuardService.instance.dispose();
    await db.close();
  });

  test(
    'transaction tool validates date, amount and names before writing',
    () async {
      final invalidDate = await tools.execute('add_finance_transaction', {
        'kind': 'expense',
        'amount_eur': 12.34,
        'date': '2026-02-30',
      });
      expect(invalidDate['status'], 'needs_info');
      final invalidCategory = await tools.execute('add_finance_transaction', {
        'kind': 'expense',
        'amount_eur': 12.34,
        'date': '2026-02-28',
        'category': 'Made up category',
      });
      expect(invalidCategory['status'], 'needs_info');
      expect(await repo.watchTransactions().first, isEmpty);

      final category = (await repo.allCategories()).first;
      final potId = await repo.createPot(
        name: 'Holiday',
        colorValue: 0,
        iconCodepoint: 0,
      );
      final options = await tools.execute('list_finance_options', {});
      expect((options['pots'] as List).single['name'], 'Holiday');
      final result = await tools.execute('add_finance_transaction', {
        'kind': 'expense',
        'amount_eur': 12.34,
        'date': '2026-02-28',
        'category': category.name,
        'note': 'Lunch',
        'pot': 'Holiday',
      });
      expect(result['status'], 'created');
      expect(result['amount_cents'], 1234);
      final saved = (await repo.watchTransactions().first).single;
      expect(saved.categoryId, category.id);
      expect(saved.potId, potId);
      expect(saved.date, DateTime(2026, 2, 28));
      expect(saved.note, 'Lunch');
    },
  );

  test('summary and recent entries use the same ledger', () async {
    await repo.addTransaction(
      kind: TxnKind.expense,
      amountCents: 2500,
      date: DateTime(2026, 8, 31),
    );
    await repo.addTransaction(
      kind: TxnKind.income,
      amountCents: 10000,
      date: DateTime(2026, 9, 1),
    );
    await repo.addTransaction(
      kind: TxnKind.expense,
      amountCents: 3000,
      date: DateTime(2026, 9, 2),
    );
    final summary = await tools.execute('get_finance_summary', {
      'month': '2026-09',
    });
    expect(summary['income_cents'], 10000);
    expect(summary['expense_cents'], 3000);
    expect(summary['net_cents'], 7000);
    expect(summary['previous_expense_cents'], 2500);

    final recent = await tools.execute('list_finance_transactions', {
      'limit': 2,
    });
    final entries = recent['transactions'] as List;
    expect(entries, hasLength(2));
    expect(entries.first['date'], '2026-09-02');
  });

  test('market trend reports observed change without network access', () async {
    tools = FinanceAiTools(
      repo,
      fetchHistory: (ticker, range) async {
        expect(ticker, 'ASML.AS');
        expect(range, ChartRange.month);
        return [
          PricePoint(DateTime(2026, 9, 1), 80000),
          PricePoint(DateTime(2026, 9, 27), 84000),
        ];
      },
    );
    final result = await tools.execute('get_market_trend', {
      'ticker': 'asml.as',
      'range': '1M',
    });
    expect(result['status'], 'ok');
    expect(result['change_cents'], 4000);
    expect(result['change_percent'], 5);
    expect(result['currency'], 'unknown');
  });
}

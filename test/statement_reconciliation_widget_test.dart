import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/ui/statement_reconciliation_dialog.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

import 'support/bank_statements.dart';

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStatementReconciliation(context, repo: repo),
              child: const Text('Reconcile'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reconcile'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 1000.0]) {
    testWidgets('balance comparison and exclusions at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(
        () => repo.addTransaction(
          kind: TxnKind.expense,
          amountCents: 2000,
          date: DateTime.now(),
          note: 'Example payment',
        ),
      );
      await open(tester);
      await tester.enterText(find.byType(TextField).at(0), '100,00');
      await tester.enterText(find.byType(TextField).at(1), '80,00');
      await tester.tap(find.text('Compare balances'));
      await settle(tester);
      await tester.ensureVisible(find.text('Balances match'));
      expect(find.text('Balances match'), findsOneWidget);
      await tester.ensureVisible(find.text('Review included cash entries'));
      await tester.tap(find.text('Review included cash entries'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(find.textContaining('(Luma is higher)'), findsOneWidget);
      expect(await tester.runAsync(repo.currentMainCents), -2000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('invalid balance stays in form without throwing', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(0), 'NaN');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.tap(find.text('Compare balances'));
    await tester.pump();
    expect(
      find.text('Enter valid opening and closing balances in euros.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'statement comparison reads file without creating pots or entries',
    (tester) async {
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('luma-reconcile-'),
      ))!;
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/statement.csv');
      await tester.runAsync(() => file.writeAsString(bankStatements['bunq']!));
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => [
          {
            'name': 'statement.csv',
            'path': file.path,
            'size': file.lengthSync(),
          },
        ],
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await open(tester);
      await tester.ensureVisible(find.text('Load statement entries'));
      await tester.tap(find.text('Load statement entries'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('bunq'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(Dialog).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('bunq'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bunq'));
      await settle(tester);
      expect(
        find.textContaining('2 statement entries loaded.'),
        findsOneWidget,
      );
      expect(await tester.runAsync(repo.allPots), isEmpty);
      expect(
        await tester.runAsync(() => repo.watchTransactions().first),
        isEmpty,
      );
      await tester.enterText(find.byType(TextField).at(0), '2000');
      await tester.enterText(find.byType(TextField).at(1), '3265,44');
      await tester.tap(find.text('Compare balances'));
      await settle(tester);
      expect(
        find.textContaining('Possibly missing from Luma ('),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.text('Review missing entries for import'),
      );
      await tester.tap(find.text('Review missing entries for import'));
      await settle(tester);
      expect(find.text('Review entry'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Add & next'));
        await tester.tap(find.text('Add & next'));
        await settle(tester);
      }
      expect(find.text('Balances match'), findsOneWidget);
      expect(find.text('No unmatched entries.'), findsOneWidget);
      expect(await tester.runAsync(repo.currentMainCents), 250000);
      expect(
        await tester.runAsync(() => repo.watchTransactions().first),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

class _TestStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/import/bank_selection_dialog.dart';
import 'package:luma/finance/import/dutch_bank_parser.dart';
import 'package:luma/finance/import/import_models.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

import 'support/bank_statements.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    StorageGuardService.instance = _ImportTestStorageGuard();
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

  testWidgets('all seven banks are reachable in the 320px picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportFlow(
                context,
                repo: repo,
                pots: [],
                categories: [],
                merchants: [],
              ),
              child: const Text('Import'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    for (final bank in supportedBanks) {
      await tester.scrollUntilVisible(
        find.text(bank.name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(bank.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => repo.watchTransactions().first),
      isEmpty,
    );
  });

  for (final fixture in bankStatements.entries) {
    testWidgets(
      '${fixture.key} selected file reaches review and saves exact transactions',
      (tester) async {
        final size = fixture.key == 'bunq'
            ? const Size(320, 720)
            : const Size(1000, 800);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final temp = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('luma-bank-ui-'),
        ))!;
        addTearDown(() => temp.delete(recursive: true));
        final bank = supportedBanks.singleWhere((b) => b.id == fixture.key);
        final file = File(
          '${temp.path}/statement.${bank.allowedExtensions.first}',
        );
        await tester.runAsync(() => file.writeAsString(fixture.value));
        const pickerChannel = MethodChannel(
          'miguelruivo.flutter.plugins.filepicker',
        );
        var picks = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pickerChannel,
          (call) async {
            expect(call.method, 'custom');
            expect(
              (call.arguments as Map)['allowedExtensions'],
              bank.allowedExtensions,
            );
            picks++;
            return [
              {
                'name': file.uri.pathSegments.last,
                'path': file.path,
                'size': fixture.value.length,
              },
            ];
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            pickerChannel,
            null,
          ),
        );
        final entries = DutchBankParser.parseText(fixture.key, fixture.value);
        await tester.pumpWidget(
          MaterialApp(
            theme: LumaTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showImportFlow(
                    context,
                    repo: repo,
                    pots: [],
                    categories: [],
                    merchants: [],
                  ),
                  child: const Text('Review'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(bank.name),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(bank.name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(bank.name));
        await settle(tester);
        expect(picks, 1);
        expect(find.text('Review entry'), findsOneWidget);
        expect(
          await tester.runAsync(() => repo.watchTransactions().first),
          isEmpty,
        );
        expect(find.text('Income'), findsOneWidget);
        expect(find.text('Example Employer'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Add & next'));
        await settle(tester);
        expect(find.text('Expense'), findsOneWidget);
        expect(find.text('Café Example'), findsOneWidget);
        await tester.tap(find.text('Add & next'));
        await settle(tester);
        final saved = (await tester.runAsync(
          () => repo.watchTransactions().first,
        ))!;
        expect(saved, hasLength(2));
        for (var i = 0; i < saved.length; i++) {
          expect(saved[i].date, entries[i].date);
          expect(saved[i].note, entries[i].description);
          expect(saved[i].amountCents, entries[i].amountCents);
          expect(
            saved[i].kind,
            entries[i].isIncome ? TxnKind.income : TxnKind.expense,
          );
        }
        expect(saved[0].potId, isNull);
        final pots = (await tester.runAsync(repo.allPots))!;
        expect(pots.single.name, 'Main');
        expect(saved[1].potId, pots.single.id);
        expect(find.text('Review entry'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ImportTestStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

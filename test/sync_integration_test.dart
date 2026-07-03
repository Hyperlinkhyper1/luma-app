// End-to-end test of the whole sync stack (client crypto + sync engine +
// real server): two "devices" share one account; device A pushes finance
// data, device B pulls it, then B edits and A picks the change up.
//
// Skipped unless a local sync server is running and announced via an
// environment variable:
//
//   cd server; dart run bin/luma_server.dart
//   $env:LUMA_SYNC_TEST_SERVER="http://127.0.0.1:8091"; flutter test test/sync_integration_test.dart
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/cloud_files/cloud_files_controller.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_service.dart';

void main() {
  final serverUrl = Platform.environment['LUMA_SYNC_TEST_SERVER'];

  if (serverUrl == null) {
    test('sync integration', () {},
        skip: 'Set LUMA_SYNC_TEST_SERVER (see file header) to run.');
    return;
  }

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('two devices sync finance data through the server', () async {
    final email =
        'it-${Random().nextInt(1 << 30)}@test.local';
    const password = 'a-long-test-password-123';

    // ---- Device A: fresh database with one custom pot -----------------
    final dbA = AppDatabase(NativeDatabase.memory());
    addTearDown(dbA.close);
    final potId = await dbA.into(dbA.pots).insert(PotsCompanion.insert(
        name: 'Vakantie', colorValue: 0xFF112233, iconCodepoint: 42));
    await dbA.into(dbA.financeTransactions).insert(
        FinanceTransactionsCompanion.insert(
          kind: TxnKind.expense,
          amountCents: 4200,
          date: DateTime(2026, 7, 1),
          note: const Value('device A lunch'),
          potId: Value(potId),
        ));

    final serviceA = SyncService(collections: [
      DriftSyncCollection(
          id: 'finance', label: 'Finance', icon: Icons.wallet, db: dbA),
    ]);
    await serviceA.init();
    addTearDown(serviceA.dispose);

    await serviceA.register(
      serverUrl: serverUrl,
      email: email,
      password: password,
    );
    await serviceA.enableCollection('finance');
    await serviceA.syncNow();
    expect(serviceA.lastError, isNull);
    expect(serviceA.account, isNotNull);
    expect(serviceA.account!.usedBytes, greaterThan(0));
    expect(serviceA.account!.quotaBytes, 3 * 1024 * 1024 * 1024);

    // ---- Device B: empty database, same account ------------------------
    final dbB = AppDatabase(NativeDatabase.memory());
    addTearDown(dbB.close);
    final serviceB = SyncService(collections: [
      DriftSyncCollection(
          id: 'finance', label: 'Finance', icon: Icons.wallet, db: dbB),
    ]);
    await serviceB.init();
    addTearDown(serviceB.dispose);

    await serviceB.signIn(
        serverUrl: serverUrl, email: email, password: password);
    await serviceB.enableCollection('finance');
    await serviceB.syncNow();
    expect(serviceB.lastError, isNull);

    // Wait: enableCollection/signIn fire async syncs; run one explicit
    // deterministic pass to be sure.
    await serviceB.syncNow();

    final potsB = await dbB.select(dbB.pots).get();
    expect(potsB.any((p) => p.name == 'Vakantie'), isTrue,
        reason: 'device B should have pulled device A\'s data');
    final txnsB = await dbB.select(dbB.financeTransactions).get();
    expect(txnsB.single.note, 'device A lunch');

    // ---- Device B edits; device A picks it up --------------------------
    await dbB.into(dbB.financeTransactions).insert(
        FinanceTransactionsCompanion.insert(
          kind: TxnKind.income,
          amountCents: 100000,
          date: DateTime(2026, 7, 2),
          note: const Value('device B salary'),
        ));
    // Mimic the change listener (no event loop wait needed in tests).
    await serviceB.syncNow();
    expect(serviceB.lastError, isNull);

    await serviceA.syncNow();
    expect(serviceA.lastError, isNull);
    final txnsA = await dbA.select(dbA.financeTransactions).get();
    expect(txnsA.any((t) => t.note == 'device B salary'), isTrue,
        reason: 'device A should have pulled device B\'s edit');

    // ---- Wrong password must fail cleanly -------------------------------
    final serviceC = SyncService(collections: []);
    await serviceC.init();
    addTearDown(serviceC.dispose);
    await expectLater(
      serviceC.signIn(
          serverUrl: serverUrl, email: email, password: 'wrong-password!!'),
      throwsA(anything),
    );

    // ---- Cleanup: delete the account ------------------------------------
    await serviceA.deleteAccount(password: password);
    expect(serviceA.signedIn, isFalse);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('cloud files: upload, download and delete round trip', () async {
    final email = 'cf-${Random().nextInt(1 << 30)}@test.local';
    const password = 'another-long-test-password-456';

    final sync = SyncService(collections: []);
    await sync.init();
    addTearDown(sync.dispose);
    await sync.register(serverUrl: serverUrl, email: email, password: password);

    final cloud = CloudFilesController(sync);
    addTearDown(cloud.dispose);
    await cloud.refresh();
    expect(cloud.files, isEmpty);
    final baseUsed = cloud.usedBytes;

    // A file larger than one chunk so the multi-chunk path is exercised.
    final tmp = await Directory.systemTemp.createTemp('luma_cf_test');
    addTearDown(() => tmp.delete(recursive: true));
    final source = File('${tmp.path}/hello.bin');
    final payload = List<int>.generate(
        CloudFilesController.chunkSize * 2 + 12345, (i) => (i * 7 + 3) & 0xff);
    await source.writeAsBytes(payload);

    // ---- Upload --------------------------------------------------------
    await cloud.upload(source.path, 'hello.bin');
    expect(cloud.files, hasLength(1));
    final file = cloud.files.single;
    expect(file.name, 'hello.bin');
    expect(file.size, payload.length);
    expect(file.chunks, 3); // 2 full chunks + a remainder
    expect(cloud.usedBytes, greaterThan(baseUsed + payload.length - 1));

    // ---- Download and verify byte-for-byte -----------------------------
    final outPath = '${tmp.path}/downloaded.bin';
    await cloud.download(file, outPath);
    final got = await File(outPath).readAsBytes();
    expect(got, equals(payload));

    // ---- Delete frees the space ----------------------------------------
    await cloud.delete(file);
    expect(cloud.files, isEmpty);
    expect(cloud.usedBytes, lessThan(baseUsed + 1024)); // only the tiny index

    await sync.deleteAccount(password: password);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

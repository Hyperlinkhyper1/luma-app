import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_crypto.dart';

void main() {
  // Tests intentionally open several in-memory databases of the same class.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('SyncCrypto', () {
    test('PBKDF2-HMAC-SHA256 matches published test vectors', () {
      // Known answers for password="password", salt="salt".
      String hex(List<int> b) =>
          b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      final one = pbkdf2Sha256(
          'password'.codeUnits, 'salt'.codeUnits, 1, 32);
      expect(hex(one),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      final two = pbkdf2Sha256(
          'password'.codeUnits, 'salt'.codeUnits, 2, 32);
      expect(hex(two),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    });

    test('key derivation is deterministic and split per purpose', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await SyncCrypto.deriveKeys(
          password: 'correct horse', kdfSalt: salt, iterations: 1000);
      final b = await SyncCrypto.deriveKeys(
          password: 'correct horse', kdfSalt: salt, iterations: 1000);
      expect(a.authKey, b.authKey);
      expect(a.encryptionKey, b.encryptionKey);
      // Auth key (goes to server) must not reveal the encryption key.
      expect(a.authKey, isNot(equals(a.encryptionKey)));

      final other = await SyncCrypto.deriveKeys(
          password: 'wrong horse', kdfSalt: salt, iterations: 1000);
      expect(other.authKey, isNot(equals(a.authKey)));
    });

    test('seal/open round trip', () async {
      final key = SyncCrypto.randomBytes(32);
      final payload = {
        'collection': 'notes',
        'data': ['hello', 1, 2.5, null, '€ünïcodé'],
      };
      final sealed = await SyncCrypto.sealPayload(payload, key);
      final opened = await SyncCrypto.openPayload(sealed, key);
      expect(opened, payload);
    });

    test('raw byte seal/open round trip (file chunks)', () async {
      final key = SyncCrypto.randomBytes(32);
      final data = SyncCrypto.randomBytes(200000); // ~200 KB of random bytes
      final sealed = await SyncCrypto.sealBytes(data, key);
      final opened = await SyncCrypto.openBytes(sealed, key);
      expect(opened, data);

      // Empty payload (0-byte file) must round-trip too.
      final empty = await SyncCrypto.sealBytes(SyncCrypto.randomBytes(0), key);
      expect(await SyncCrypto.openBytes(empty, key), isEmpty);

      // Wrong key is rejected.
      await expectLater(
        SyncCrypto.openBytes(sealed, SyncCrypto.randomBytes(32)),
        throwsA(isA<SyncCryptoException>()),
      );
    });

    test('wrong key and tampering are rejected', () async {
      final key = SyncCrypto.randomBytes(32);
      final sealed = await SyncCrypto.sealPayload({'a': 1}, key);

      expect(
        () => SyncCrypto.openPayload(sealed, SyncCrypto.randomBytes(32)),
        throwsA(isA<SyncCryptoException>()),
      );

      final tampered = Uint8List.fromList(sealed);
      tampered[tampered.length ~/ 2] ^= 0xFF;
      expect(
        () => SyncCrypto.openPayload(tampered, key),
        throwsA(isA<SyncCryptoException>()),
      );
    });
  });

  group('DriftSyncCollection', () {
    test('export/import round trip restores every table', () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);

      // Add data referencing seeded rows plus fresh rows in several tables.
      final potId = await source.into(source.pots).insert(
          PotsCompanion.insert(
              name: 'Vakantie', colorValue: 0xFF112233, iconCodepoint: 42));
      final categoryId = (await source.select(source.categories).get())
          .first
          .id;
      await source.into(source.financeTransactions).insert(
          FinanceTransactionsCompanion.insert(
            kind: TxnKind.expense,
            amountCents: 1250,
            date: DateTime(2026, 6, 1, 12, 30),
            note: const Value('lunch'),
            potId: Value(potId),
            categoryId: Value(categoryId),
          ));
      await source.into(source.holdings).insert(HoldingsCompanion.insert(
          ticker: 'ASML', name: 'ASML', shares: 1.5, avgCostCents: 65000));

      final collection = DriftSyncCollection(
        id: 'finance',
        label: 'Finance',
        icon: Icons.wallet,
        db: source,
      );
      final snapshot = await collection.export();

      // Target starts with different content (its own seed data only).
      final targetCollection = DriftSyncCollection(
        id: 'finance',
        label: 'Finance',
        icon: Icons.wallet,
        db: target,
      );
      await targetCollection.import(snapshot);

      final sourcePots = await source.select(source.pots).get();
      final targetPots = await target.select(target.pots).get();
      expect(targetPots, sourcePots);

      final sourceTxns =
          await source.select(source.financeTransactions).get();
      final targetTxns =
          await target.select(target.financeTransactions).get();
      expect(targetTxns, sourceTxns);

      final sourceHoldings = await source.select(source.holdings).get();
      final targetHoldings = await target.select(target.holdings).get();
      expect(targetHoldings, sourceHoldings);

      // Re-export from the target must produce the identical snapshot, so
      // sync does not see a phantom "local change" after a pull.
      final reExport = await targetCollection.export();
      expect(reExport, snapshot);
    });

    test('import replaces existing rows instead of merging', () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);

      await target.into(target.pots).insert(PotsCompanion.insert(
          name: 'Old pot', colorValue: 1, iconCodepoint: 1));

      final collection = DriftSyncCollection(
          id: 'finance', label: 'Finance', icon: Icons.wallet, db: source);
      final snapshot = await collection.export();

      final targetCollection = DriftSyncCollection(
          id: 'finance', label: 'Finance', icon: Icons.wallet, db: target);
      await targetCollection.import(snapshot);

      final pots = await target.select(target.pots).get();
      expect(pots.where((p) => p.name == 'Old pot'), isEmpty);
    });

    test('rejects snapshots from a newer schema', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final collection = DriftSyncCollection(
          id: 'finance', label: 'Finance', icon: Icons.wallet, db: db);
      expect(
        () => collection.import({
          'format': 1,
          'schemaVersion': 999,
          'tables': <String, Object?>{},
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}

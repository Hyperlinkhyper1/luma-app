import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/passwords/data/password_database.dart';
import 'package:luma/features/passwords/password_crypto.dart';
import 'package:luma/features/passwords/password_repository.dart';
import 'package:luma/security/authenticated_cipher.dart';
import 'package:luma/security/secure_secret_store.dart';
import 'package:luma/security/password_hash.dart';
import 'package:luma/security/network_policy.dart';
import 'package:luma/sync/sync_state.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_crypto.dart';

const secret = 'LUMA_SECURITY_TEST_PASSWORD_7H3K92';
const seed = 'JBSWY3DPEHPK3PXP';

// Reproduces the shipped v2 format; deliberately restricted to test fixtures.
String legacyPassword(List<int> key, String clear, int id, String field) {
  final nonce = List<int>.generate(12, (i) => i + 10);
  final input = utf8.encode(clear);
  final cipher = <int>[];
  for (var offset = 0, counter = 0; offset < input.length; counter++) {
    final bytes = (ByteData(4)..setUint32(0, counter)).buffer.asUint8List();
    final block = Hmac(sha256, key).convert([...nonce, ...bytes]).bytes;
    for (var i = 0; i < block.length && offset < input.length; i++, offset++) {
      cipher.add(input[offset] ^ block[i]);
    }
  }
  final tag = Hmac(sha256, key)
      .convert([
        ...utf8.encode('luma-pw-entry|id:$id|field:$field'),
        ...nonce,
        ...cipher,
      ])
      .bytes
      .take(16);
  return base64Encode([2, ...nonce, ...cipher, ...tag]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  test(
    'vault metadata never enters plaintext rows and survives sync to another key',
    () async {
      StorageGuardService.instance = StorageGuardService();
      final directory = await Directory.systemTemp.createTemp(
        'luma-vault-security-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/vault.sqlite');
      final source = PasswordDatabase(NativeDatabase(databaseFile));
      final target = PasswordDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      final crypto = PasswordCrypto.forTesting(key);
      final other = PasswordCrypto.forTesting(Uint8List(32));
      final repo = PasswordRepository(source, crypto);
      const draft = PasswordDraft(
        service: 'PRIVATE_SERVICE_8JK',
        email: 'PRIVATE_EMAIL_8JK',
        password: secret,
        username: 'PRIVATE_USER_8JK',
        phone: 'PRIVATE_PHONE_8JK',
        info: 'PRIVATE_NOTE_8JK',
        totpSecret: seed,
      );
      await repo.add(draft);
      final row = (await source.select(source.passwordEntries).get()).single;
      final raw = jsonEncode(
        (await source.customSelect('SELECT * FROM password_entries').get())
            .single
            .data,
      );
      final disk = utf8.decode(
        await databaseFile.readAsBytes(),
        allowMalformed: true,
      );
      for (final value in [
        draft.service,
        draft.email,
        draft.password,
        draft.username!,
        draft.phone!,
        draft.info!,
        seed,
      ]) {
        expect(raw, isNot(contains(value)));
        expect(disk, isNot(contains(value)));
      }
      expect((await repo.watchAll().first).single.info, draft.info);
      final exported = await PasswordVaultSyncCollection(
        db: source,
        crypto: crypto,
      ).export();
      await PasswordVaultSyncCollection(
        db: target,
        crypto: other,
      ).import(exported);
      final restored = (await PasswordRepository(
        target,
        other,
      ).watchAll().first).single;
      expect(restored.password, secret);
      expect(restored.totpSecret, seed);
      expect(restored.service, draft.service);
      expect(restored.info, draft.info);
      await (source.update(
        source.passwordEntries,
      )..where((t) => t.id.equals(row.id))).write(
        const PasswordEntriesCompanion(info: Value('plaintext substitution')),
      );
      expect((await repo.watchAll().first).single.decryptFailed, isTrue);
      await expectLater(
        PasswordVaultSyncCollection(db: source, crypto: crypto).export(),
        throwsFormatException,
      );
    },
  );

  test(
    'Argon2id app-lock verifier is salted, rejects wrong input and accepts legacy',
    () async {
      final first = await PasswordHash.create(secret);
      final second = await PasswordHash.create(secret);
      expect(first, isNot(second));
      expect(await PasswordHash.verify(secret, first), isTrue);
      expect(await PasswordHash.verify('wrong', first), isFalse);
      expect(
        await PasswordHash.verify(secret, first.replaceFirst('v1', 'v999')),
        isFalse,
      );
      final old = sha256.convert(utf8.encode(secret)).toString();
      expect(await PasswordHash.verify(secret, old), isTrue);
      expect(PasswordHash.needsUpgrade(old), isTrue);
    },
  );

  test('production transport rejects plaintext and URL credentials', () {
    for (final url in [
      'http://localhost',
      'http://127.0.0.1',
      'http://example.com',
      'https://user:secret@example.com',
    ]) {
      expect(
        () => requirePrivateTransport(Uri.parse(url), debugBuild: false),
        throwsFormatException,
      );
    }
    requirePrivateTransport(
      Uri.parse('https://example.com'),
      debugBuild: false,
    );
    requirePrivateTransport(Uri.parse('http://127.0.0.1'), debugBuild: true);
    expect(
      () => requirePrivateTransport(
        Uri.parse('http://127.0.0.1.example.com'),
        debugBuild: true,
      ),
      throwsFormatException,
    );
  });

  test(
    'sync credentials migrate out of JSON and bind token to protected origin',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('luma-sync-security-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/sync.json');
      await file.writeAsString(
        jsonEncode({
          'serverUrl': 'https://trusted.example',
          'email': 'test@example.invalid',
          'token': secret,
          'encryptionKey': base64Encode(key),
          'accountApproved': true,
          'kdfIterations': 200000,
        }),
      );
      final state = await SyncStateStore.load(stateFile: file);
      expect(state.token, secret);
      final disk = await file.readAsString();
      expect(disk, isNot(contains(secret)));
      expect(disk, isNot(contains(base64Encode(key))));
      final modified = jsonDecode(disk) as Map<String, dynamic>;
      modified['serverUrl'] = 'https://attacker.example';
      await file.writeAsString(jsonEncode(modified));
      final restored = await SyncStateStore.load(stateFile: file);
      expect(restored.serverUrl, 'https://trusted.example');
      expect(restored.encryptionKey, key);
      restored.clearAccount();
      await restored.save();
      expect((await SyncStateStore.load(stateFile: file)).token, isNull);
    },
  );

  test(
    'AEAD rejects every modified envelope byte, wrong context and wrong key',
    () {
      final clear = utf8.encode(secret);
      final sealed = AuthenticatedCipher.seal(clear, key, 'test');
      expect(AuthenticatedCipher.open(sealed, key, 'test'), clear);
      expect(
        () => AuthenticatedCipher.open(sealed, key, 'other'),
        throwsA(anything),
      );
      expect(
        () => AuthenticatedCipher.open(sealed, Uint8List(32), 'test'),
        throwsA(anything),
      );
      for (var i = 0; i < sealed.length; i++) {
        final corrupt = Uint8List.fromList(sealed)..[i] ^= 1;
        expect(
          () => AuthenticatedCipher.open(corrupt, key, 'test'),
          throwsA(anything),
        );
      }
      final nonces = <String>{};
      for (var i = 0; i < 1000; i++) {
        nonces.add(
          base64Encode(
            AuthenticatedCipher.seal(clear, key, 'test').sublist(3, 15),
          ),
        );
      }
      expect(nonces, hasLength(1000));
    },
  );

  test('vault roundtrip, row and field binding, and legacy reader', () {
    final crypto = PasswordCrypto.forTesting(key);
    final token = crypto.encrypt(secret, entryId: 1, field: 'password');
    expect(token, startsWith('pw3:'));
    expect(crypto.decrypt(token, entryId: 1, field: 'password'), secret);
    expect(crypto.decrypt(token, entryId: 2, field: 'password'), isNull);
    expect(crypto.decrypt(token, entryId: 1, field: 'totp'), isNull);
    expect(
      PasswordCrypto.forTesting(
        Uint8List(32),
      ).decrypt(token, entryId: 1, field: 'password'),
      isNull,
    );
    expect(
      crypto.decrypt(
        legacyPassword(key, secret, 1, 'password'),
        entryId: 1,
        field: 'password',
      ),
      secret,
    );
  });

  test(
    'migration is repeatable and preserves corrupt TOTP rows byte for byte',
    () async {
      final db = PasswordDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final crypto = PasswordCrypto.forTesting(key);
      final repo = PasswordRepository(db, crypto);
      for (var id = 1; id <= 2; id++) {
        await db
            .into(db.passwordEntries)
            .insert(
              PasswordEntriesCompanion.insert(
                id: Value(id),
                service: 'test',
                email: 'test@example.invalid',
                passwordCipher: legacyPassword(key, secret, id, 'password'),
                totpSecretCipher: Value(
                  id == 1 ? legacyPassword(key, seed, id, 'totp') : 'corrupted',
                ),
              ),
            );
      }
      final before = await db.select(db.passwordEntries).get();
      await repo.migrateLegacyCiphertexts();
      final after = await db.select(db.passwordEntries).get();
      expect(after[0].passwordCipher, startsWith('pw3:'));
      expect(
        crypto.decrypt(after[0].totpSecretCipher!, entryId: 1, field: 'totp'),
        seed,
      );
      expect(after[1].passwordCipher, before[1].passwordCipher);
      expect(after[1].totpSecretCipher, 'corrupted');
      await repo.migrateLegacyCiphertexts();
      expect(
        (await db.select(db.passwordEntries).get())[0].passwordCipher,
        after[0].passwordCipher,
      );
      final raw = jsonEncode(
        (await db.customSelect('SELECT * FROM password_entries').get())
            .map((r) => r.data)
            .toList(),
      );
      expect(raw, isNot(contains(secret)));
      expect(raw, isNot(contains(seed)));
      expect(
        (await repo.watchAll().first)
            .where((r) => r.id == 2)
            .single
            .decryptFailed,
        isTrue,
      );
      final sync = PasswordVaultSyncCollection(db: db, crypto: crypto);
      await expectLater(sync.export(), throwsStateError);
      await expectLater(
        sync.import({
          'format': 1,
          'schemaVersion': 3,
          'tables': {
            'password_entries': [
              {'id': 1, 'service': 'bad', 'email': 'bad'},
            ],
          },
        }),
        throwsFormatException,
      );
      expect(await db.select(db.passwordEntries).get(), after);
    },
  );

  test(
    'secure key migration validates, preserves failures and refuses key loss',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('luma-security-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/legacy.key');
      await file.writeAsString(base64Encode(key));
      final store = SecureSecretStore();
      expect(
        await store.loadKey('test.key', file, encryptedDataExists: true),
        key,
      );
      expect(await file.exists(), isFalse);
      expect(
        await store.loadKey('test.key', file, encryptedDataExists: true),
        key,
      );
      await file.writeAsString('broken');
      await expectLater(
        store.loadKey('broken.key', file, encryptedDataExists: true),
        throwsA(anything),
      );
      expect(await file.readAsString(), 'broken');
      await expectLater(
        store.loadKey(
          'missing.key',
          File('${dir.path}/missing'),
          encryptedDataExists: true,
        ),
        throwsStateError,
      );
    },
  );

  test('sync uses versioned AES-GCM and rejects unknown versions', () {
    final sealed = SyncCrypto.sealRaw(
      Uint8List.fromList(utf8.encode(secret)),
      key,
    );
    expect(sealed.take(3), [0x4c, 0x41, 1]);
    expect(utf8.decode(SyncCrypto.openRaw(sealed, key)), secret);
    sealed[2] = 99;
    expect(
      () => SyncCrypto.openRaw(sealed, key),
      throwsA(isA<SyncCryptoException>()),
    );
  });
}

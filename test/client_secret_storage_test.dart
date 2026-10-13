import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_credentials.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/data/minecraft_launcher_database.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/logic/instance_launch_orchestrator.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/minecraft_launcher_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_credentials.dart';
import 'package:luma/security/authenticated_cipher.dart';
import 'package:luma/security/encrypted_credential_file.dart';
import 'package:luma/security/secure_secret_store.dart';
import 'package:luma/storage/storage_guard.dart';

const _legacyKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';
const _legacyMc =
    'AQIDBAUGBwgJCgsMw4L5Uqycx6/riqKjqOx3hBqeXKukoQBGR7E/KS9TqVSzPMbfzzEOCb2ktSkEsIWvaAXmDEtu99Q1DnJ3QoY8CPuvvf6xCBIm4b0wEAAAX4s3BQgkQszSo/rnJ/TGcRRPx21yv6eRmWUxO0fhjwj6qHah4FVuBKAFc6uQbP9gfna4f/qOdQuxJag=';
const _legacySteam =
    'AQIDBAUGBwgJCgsMw4L7V7ekx7CmwueqjPt/rAbKDeXjrAgDCvA1cClHtm6yeJOPn2IZE67443VG6dvrMGClWQki6yqUJ3kO/fjo8DBCKkSNzQY=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SecureSecretStore secrets;

  setUp(() async {
    StorageGuard.instance = StorageGuardService();
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('luma-client-secrets-');
    secrets = SecureSecretStore(storageDir: directory);
  });

  tearDown(() async {
    StorageGuard.instance.dispose();
    await directory.delete(recursive: true);
  });

  MinecraftLauncherDatabase database() {
    final db = MinecraftLauncherDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Future<int> signIn(MinecraftLauncherRepository repository) =>
      repository.addOrUpdateMicrosoftAccount(
        username: 'Alex',
        uuid: 'account-uuid',
        accessToken: 'minecraft-access',
        refreshToken: 'microsoft-refresh',
        accessTokenExpiresAt: DateTime.utc(2030),
      );

  test('launcher encrypts writes and decrypts reads after reopening', () async {
    final db = database();
    final repository = MinecraftLauncherRepository(db, secretStore: secrets);
    final id = await signIn(repository);
    final raw = await db.select(db.mcAccounts).getSingle();
    expect(raw.id, id);
    expect(raw.accessToken, startsWith('enc:v1:'));
    expect(raw.refreshToken, startsWith('enc:v1:'));
    expect(raw.accessToken, isNot(contains('minecraft-access')));
    final reopened = MinecraftLauncherRepository(
      db,
      secretStore: SecureSecretStore(storageDir: directory),
    );
    final account = (await reopened.watchAccounts().first).single;
    expect(account.accessToken, 'minecraft-access');
    expect(account.refreshToken, 'microsoft-refresh');
    expect((await reopened.watchActiveAccount().first)?.id, id);
    expect(db.schemaVersion, 2);
  });

  test(
    'launcher migrates plaintext rows once without changing metadata',
    () async {
      final db = database();
      await db
          .into(db.mcAccounts)
          .insert(
            McAccountsCompanion.insert(
              type: 'microsoft',
              username: 'Alex',
              uuid: 'legacy-uuid',
              accessToken: const Value('legacy-access'),
              refreshToken: const Value('legacy-refresh'),
              isActive: const Value(true),
            ),
          );
      final repository = MinecraftLauncherRepository(db, secretStore: secrets);
      final account = (await repository.watchAccounts().first).single;
      expect(account.username, 'Alex');
      expect(account.uuid, 'legacy-uuid');
      expect(account.isActive, isTrue);
      expect(account.accessToken, 'legacy-access');
      expect(account.refreshToken, 'legacy-refresh');
      final migrated = await db.select(db.mcAccounts).getSingle();
      expect(migrated.accessToken, startsWith('enc:v1:'));
      final reopened = MinecraftLauncherRepository(db, secretStore: secrets);
      await reopened.watchAccounts().first;
      expect(
        (await db.select(db.mcAccounts).getSingle()).accessToken,
        migrated.accessToken,
      );
    },
  );

  test(
    'launcher key loss requires sign-in and preserves account identity',
    () async {
      final db = database();
      final repository = MinecraftLauncherRepository(db, secretStore: secrets);
      final id = await signIn(repository);
      await secrets.delete(MinecraftLauncherRepository.tokenKeyName);
      final freshSecrets = SecureSecretStore(storageDir: directory);
      final reopened = MinecraftLauncherRepository(
        db,
        secretStore: freshSecrets,
      );
      final account = (await reopened.watchAccounts().first).single;
      expect(account.id, id);
      expect(account.uuid, 'account-uuid');
      expect(MinecraftLauncherRepository.requiresSignIn(account), isTrue);
      expect(await reopened.watchActiveAccount().first, isNull);
      expect(
        freshSecrets.lostKeys,
        contains(MinecraftLauncherRepository.tokenKeyName),
      );
      final raw = await db.select(db.mcAccounts).getSingle();
      expect(raw.accessToken, isNull);
      expect(raw.refreshToken, isNull);
      final instanceId = await reopened.createInstance(
        name: 'test',
        versionId: '1.21',
      );
      final instance = (await reopened.watchInstance(instanceId).first)!;
      var reportedStatus = false;
      await expectLater(
        InstanceLaunchOrchestrator.prepareAndLaunch(
          instance: instance,
          account: account,
          onStatus: (_, _) => reportedStatus = true,
        ),
        throwsA(isA<LaunchOrchestratorException>()),
      );
      expect(reportedStatus, isFalse);
      expect(await signIn(reopened), id);
      expect(
        (await reopened.watchActiveAccount().first)?.accessToken,
        'minecraft-access',
      );
      final reopenedAgain = MinecraftLauncherRepository(
        db,
        secretStore: freshSecrets,
      );
      expect(
        (await reopenedAgain.watchActiveAccount().first)?.accessToken,
        'minecraft-access',
      );
    },
  );

  test('launcher rejects tokens copied to a different account', () async {
    final db = database();
    final repository = MinecraftLauncherRepository(db, secretStore: secrets);
    await signIn(repository);
    await db
        .update(db.mcAccounts)
        .write(const McAccountsCompanion(uuid: Value('other-account')));
    final account = (await repository.watchAccounts().first).single;
    expect(MinecraftLauncherRepository.requiresSignIn(account), isTrue);
    expect(await repository.watchActiveAccount().first, isNull);
  });

  test(
    'MC Content credentials round-trip with no plaintext key file',
    () async {
      final store = await McCredentialStore.load(
        storageDir: directory,
        secretStore: secrets,
      );
      const credentials = McCredentials(
        curseforgeApiKey: 'curseforge-secret',
        curseforgeAuthorId: '123',
        curseforgeProjectIds: ['1', '2'],
        modrinthUsername: 'alex',
        modrinthToken: 'modrinth-secret',
        pmcUsername: 'alex',
      );
      await store.save(credentials);
      final file = File('${directory.path}/luma_mc_accounts.dat');
      expect(await file.readAsString(), startsWith('enc:v1:'));
      expect(await file.readAsString(), isNot(contains('modrinth-secret')));
      expect(await File('${directory.path}/luma_mc.key').exists(), isFalse);
      final reopened = await McCredentialStore.load(
        storageDir: directory,
        secretStore: SecureSecretStore(storageDir: directory),
      );
      expect((await reopened.read())?.toJson(), credentials.toJson());
      await reopened.clear();
      expect(await reopened.read(), isNull);
    },
  );

  test('MC Content migrates legacy data under a new secure key', () async {
    final keyFile = File('${directory.path}/luma_mc.key');
    final file = File('${directory.path}/luma_mc_accounts.dat');
    await keyFile.writeAsString(_legacyKey);
    await file.writeAsString(_legacyMc);
    final store = await McCredentialStore.load(
      storageDir: directory,
      secretStore: secrets,
    );
    final credentials = await store.read();
    expect(credentials?.curseforgeApiKey, 'legacy-curseforge');
    expect(credentials?.modrinthToken, 'legacy-modrinth');
    expect(await keyFile.exists(), isFalse);
    expect(await secrets.read('luma_mc.key'), isNot(_legacyKey));
    final key = base64Decode((await secrets.read('luma_mc.key'))!);
    final token = await file.readAsString();
    final payload = utf8.decode(
      AuthenticatedCipher.open(
        base64Decode(token.substring('enc:v1:'.length)),
        key,
        'luma-mc-content-credentials',
      ),
    );
    expect(jsonDecode(payload)['modrinthToken'], 'legacy-modrinth');
  });

  test('Steam credentials round-trip with no plaintext key file', () async {
    final store = await SteamCredentialStore.load(
      storageDir: directory,
      secretStore: secrets,
    );
    const credentials = SteamCredentials(
      apiKey: 'steam-secret',
      steamId: '76561198000000000',
    );
    await store.save(credentials);
    final file = File('${directory.path}/luma_steam_account.dat');
    expect(await file.readAsString(), startsWith('enc:v1:'));
    expect(await file.readAsString(), isNot(contains('steam-secret')));
    expect(await File('${directory.path}/luma_steam.key').exists(), isFalse);
    final reopened = await SteamCredentialStore.load(
      storageDir: directory,
      secretStore: SecureSecretStore(storageDir: directory),
    );
    expect((await reopened.read())?.apiKey, credentials.apiKey);
    expect((await reopened.read())?.steamId, credentials.steamId);
  });

  test('Steam migrates legacy data under a new secure key', () async {
    final keyFile = File('${directory.path}/luma_steam.key');
    final file = File('${directory.path}/luma_steam_account.dat');
    await keyFile.writeAsString(_legacyKey);
    await file.writeAsString(_legacySteam);
    final store = await SteamCredentialStore.load(
      storageDir: directory,
      secretStore: secrets,
    );
    expect((await store.read())?.apiKey, 'legacy-steam');
    expect((await store.read())?.steamId, '76561198000000000');
    expect(await keyFile.exists(), isFalse);
    expect(await secrets.read('luma_steam.key'), isNot(_legacyKey));
    final reopened = await SteamCredentialStore.load(
      storageDir: directory,
      secretStore: secrets,
    );
    expect((await reopened.read())?.apiKey, 'legacy-steam');
  });

  test(
    'MC Content can replace non-UTF8 legacy data without losing its key early',
    () async {
      final keyFile = File('${directory.path}/luma_mc.key');
      final file = File('${directory.path}/luma_mc_accounts.dat');
      await keyFile.writeAsString(_legacyKey);
      await file.writeAsBytes([0xff, 0xfe]);
      final store = await McCredentialStore.load(
        storageDir: directory,
        secretStore: secrets,
      );
      expect(await store.read(), isNull);
      expect(await file.readAsBytes(), [0xff, 0xfe]);
      expect(await keyFile.readAsString(), _legacyKey);
      await store.save(
        const McCredentials(modrinthToken: 'replacement-secret'),
      );
      expect((await store.read())?.modrinthToken, 'replacement-secret');
      expect(await keyFile.exists(), isFalse);
    },
  );

  test(
    'Steam can disconnect a non-UTF8 legacy key while preserving data until then',
    () async {
      final keyFile = File('${directory.path}/luma_steam.key');
      final file = File('${directory.path}/luma_steam_account.dat');
      await keyFile.writeAsBytes([0xff, 0xfe]);
      await file.writeAsString(_legacySteam);
      final store = await SteamCredentialStore.load(
        storageDir: directory,
        secretStore: secrets,
      );
      expect(await store.read(), isNull);
      expect(await keyFile.readAsBytes(), [0xff, 0xfe]);
      expect(await file.readAsString(), _legacySteam);
      await store.clear();
      expect(await keyFile.exists(), isFalse);
      expect(await file.exists(), isFalse);
    },
  );

  for (final (keyName, fileName, fixture, context) in [
    (
      'luma_mc.key',
      'luma_mc_accounts.dat',
      _legacyMc,
      'luma-mc-content-credentials',
    ),
    (
      'luma_steam.key',
      'luma_steam_account.dat',
      _legacySteam,
      'luma-steam-credentials',
    ),
  ]) {
    for (final replaceCredentials in [true, false]) {
      test(
        '$keyName corrupt legacy credentials can be ${replaceCredentials ? 'replaced' : 'disconnected'}',
        () async {
          final keyFile = File('${directory.path}/$keyName');
          final file = File('${directory.path}/$fileName');
          await keyFile.writeAsString(_legacyKey);
          final broken = base64Decode(fixture)..[15] ^= 1;
          final original = base64Encode(broken);
          await file.writeAsString(original);

          late final Future<Object?> Function() read;
          late final Future<void> Function() save;
          late final Future<void> Function() clear;
          if (keyName == 'luma_mc.key') {
            final store = await McCredentialStore.load(
              storageDir: directory,
              secretStore: secrets,
            );
            read = store.read;
            save = () => store.save(
              const McCredentials(
                modrinthUsername: 'alex',
                modrinthToken: 'replacement-secret',
              ),
            );
            clear = store.clear;
            final reopened = await McCredentialStore.load(
              storageDir: directory,
              secretStore: secrets,
            );
            expect(await reopened.read(), isNull);
          } else {
            final store = await SteamCredentialStore.load(
              storageDir: directory,
              secretStore: secrets,
            );
            read = store.read;
            save = () => store.save(
              const SteamCredentials(
                apiKey: 'replacement-secret',
                steamId: '76561198000000000',
              ),
            );
            clear = store.clear;
            final reopened = await SteamCredentialStore.load(
              storageDir: directory,
              secretStore: secrets,
            );
            expect(await reopened.read(), isNull);
          }

          expect(await read(), isNull);
          expect(await keyFile.readAsString(), _legacyKey);
          expect(await file.readAsString(), original);
          if (replaceCredentials) {
            await save();
            expect(await read(), isNotNull);
            expect(await file.readAsString(), startsWith('enc:v1:'));
            expect(
              await file.readAsString(),
              isNot(contains('replacement-secret')),
            );
          } else {
            await clear();
            expect(await read(), isNull);
            expect(await file.exists(), isFalse);
          }
          expect(await keyFile.exists(), isFalse);
        },
      );
    }

    test(
      '$keyName migration preserves key and data on authentication failure',
      () async {
        final keyFile = File('${directory.path}/$keyName');
        final file = File('${directory.path}/$fileName');
        await keyFile.writeAsString(_legacyKey);
        final broken = base64Decode(fixture)..[15] ^= 1;
        final token = base64Encode(broken);
        await file.writeAsString(token);
        await expectLater(
          EncryptedCredentialFile.load(
            directory: directory,
            keyName: keyName,
            fileName: fileName,
            context: context,
            secretStore: secrets,
          ),
          throwsFormatException,
        );
        expect(await keyFile.readAsString(), _legacyKey);
        expect(await file.readAsString(), token);
        expect(await secrets.read(keyName), isNull);
      },
    );

    test(
      '$keyName migration preserves legacy files when atomic write fails',
      () async {
        final keyFile = File('${directory.path}/$keyName');
        final file = File('${directory.path}/$fileName');
        await keyFile.writeAsString(_legacyKey);
        await file.writeAsString(fixture);
        await Directory('${file.path}.tmp').create();
        await expectLater(
          EncryptedCredentialFile.load(
            directory: directory,
            keyName: keyName,
            fileName: fileName,
            context: context,
            secretStore: secrets,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(await keyFile.readAsString(), _legacyKey);
        expect(await file.readAsString(), fixture);
        await Directory('${file.path}.tmp').delete();
        final recovered = await EncryptedCredentialFile.load(
          directory: directory,
          keyName: keyName,
          fileName: fileName,
          context: context,
          secretStore: secrets,
        );
        expect(await recovered.read(), contains('legacy-'));
        expect(await keyFile.exists(), isFalse);
      },
    );

    test(
      '$keyName key loss starts empty and preserves inaccessible ciphertext',
      () async {
        final store = await EncryptedCredentialFile.load(
          directory: directory,
          keyName: keyName,
          fileName: fileName,
          context: context,
          secretStore: secrets,
        );
        await store.write('secret');
        await secrets.delete(keyName);
        final freshSecrets = SecureSecretStore(storageDir: directory);
        final reopened = await EncryptedCredentialFile.load(
          directory: directory,
          keyName: keyName,
          fileName: fileName,
          context: context,
          secretStore: freshSecrets,
        );
        expect(await reopened.read(), isNull);
        expect(freshSecrets.lostKeys, contains(keyName));
        expect(
          directory.listSync().where(
            (file) => file.path.contains('$fileName.lost-key-'),
          ),
          hasLength(1),
        );
      },
    );
  }
}

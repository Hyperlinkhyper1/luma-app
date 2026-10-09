import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' show Icons;
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/account_overview/account_connections_sync.dart';
import 'package:luma/security/secure_secret_store.dart';
import 'package:luma/sync/sync_state.dart';

class _RealHttpOverrides extends HttpOverrides {}

class _Secrets extends SecureSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Connection extends ChangeNotifier {
  Map<String, dynamic>? credential;
  AccountConnectionEndpoint get endpoint => AccountConnectionEndpoint(
    changes: this,
    read: () async => credential,
    write: (data) async {
      credential = data;
      notifyListeners();
    },
  );
  void set(Map<String, dynamic>? data) {
    credential = data;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  test('connections automatically sync on every plan', () {
    expect(
      isAutomaticSyncCollection(AccountConnectionsSync.collectionId),
      isTrue,
    );
  });
  test(
    'devices merge independent connections and keep disconnect tombstones',
    () async {
      final githubA = _Connection();
      final spotifyA = _Connection();
      final githubB = _Connection();
      final spotifyB = _Connection();
      final a = AccountConnectionsSync(
        endpoints: {'github': githubA.endpoint, 'spotify': spotifyA.endpoint},
        secrets: _Secrets(),
      );
      final bSecrets = _Secrets();
      var b = AccountConnectionsSync(
        endpoints: {'github': githubB.endpoint, 'spotify': spotifyB.endpoint},
        secrets: bSecrets,
      );
      addTearDown(() {
        a.dispose();
        b.dispose();
        githubA.dispose();
        githubB.dispose();
        spotifyA.dispose();
        spotifyB.dispose();
      });
      await a.exportData();
      await b.exportData();
      githubA.set({'token': 'fixture-github', 'login': 'alice'});
      spotifyB.set({'refreshToken': 'fixture-spotify', 'accountId': 'alice'});
      final oldA = await a.exportData();
      await a.importData(await b.exportData());
      await b.importData(await a.exportData());
      expect(githubB.credential, githubA.credential);
      expect(spotifyA.credential, spotifyB.credential);
      githubB.set(null);
      await a.importData(await b.exportData());
      expect(githubA.credential, isNull);
      b.dispose();
      b = AccountConnectionsSync(
        endpoints: {'github': githubB.endpoint, 'spotify': spotifyB.endpoint},
        secrets: bSecrets,
      );
      await b.importData(oldA);
      expect(githubB.credential, isNull);
      expect(spotifyB.credential?['accountId'], 'alice');
    },
  );
  test(
    'encrypted sync engine merges devices and retries version conflicts',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Uint8List? blob;
      var version = 0;
      var savedAt = 0;
      var conflictOnce = false;
      var conflicts = 0;
      server.listen((request) async {
        final response = request.response;
        final path = request.uri.path;
        Object result = {};
        if (path.endsWith('/auth/params')) {
          result = {
            'kdfSalt': base64Encode(List<int>.filled(16, 7)),
            'kdfIterations': 1000,
          };
        } else if (path.endsWith('/auth/login')) {
          result = {'token': 'fixture-session'};
        } else if (path.endsWith('/account')) {
          result = {
            'email': 'alice@example.test',
            'status': 'active',
            'collections': [
              if (blob != null)
                {
                  'name': AccountConnectionsSync.collectionId,
                  'version': version,
                  'size': blob!.length,
                  'payloadSavedAtMs': savedAt,
                },
            ],
          };
        } else if (path.endsWith('/sync/account_connections') &&
            request.method == 'GET') {
          if (blob == null) {
            response.statusCode = 404;
          } else {
            response.headers.set('x-version', version);
            response.headers.set('x-payload-saved-at', savedAt);
            response.add(blob!);
            await response.close();
            return;
          }
        } else if (path.endsWith('/sync/account_connections') &&
            request.method == 'PUT') {
          final bytes = await request.fold<List<int>>(
            [],
            (buffer, chunk) => buffer..addAll(chunk),
          );
          final base = int.parse(request.headers.value('x-base-version')!);
          if (base != version || conflictOnce) {
            conflictOnce = false;
            conflicts++;
            response.statusCode = 409;
            result = {
              'error': 'version_conflict',
              'message': 'fixture conflict',
              'version': version,
              'payloadSavedAtMs': savedAt,
            };
          } else {
            blob = Uint8List.fromList(bytes);
            savedAt = int.parse(request.headers.value('x-payload-saved-at')!);
            result = {'version': ++version};
          }
        } else {
          response.statusCode = 404;
          result = {'code': 'not_found', 'message': 'unexpected fixture path'};
        }
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(result));
        await response.close();
      });
      addTearDown(() => server.close(force: true));
      final githubA = _Connection();
      final spotifyA = _Connection();
      final githubB = _Connection();
      final spotifyB = _Connection();
      final a = AccountConnectionsSync(
        endpoints: {'github': githubA.endpoint, 'spotify': spotifyA.endpoint},
        secrets: _Secrets(),
      );
      final b = AccountConnectionsSync(
        endpoints: {'github': githubB.endpoint, 'spotify': spotifyB.endpoint},
        secrets: _Secrets(),
      );
      SyncService device(AccountConnectionsSync connections) => SyncService(
        collections: [
          JsonStoreSyncCollection(
            id: AccountConnectionsSync.collectionId,
            label: 'Connections',
            icon: Icons.link,
            mergeOnImport: true,
            listenable: connections,
            exporter: connections.exportData,
            importer: connections.importData,
          ),
        ],
      );
      final serviceA = device(a);
      final serviceB = device(b);
      addTearDown(() {
        serviceA.dispose();
        serviceB.dispose();
        a.dispose();
        b.dispose();
        githubA.dispose();
        spotifyA.dispose();
        githubB.dispose();
        spotifyB.dispose();
      });
      await a.exportData();
      await b.exportData();
      githubA.set({'token': 'fixture-github-private', 'login': 'alice'});
      spotifyB.set({'refreshToken': 'fixture-spotify-private'});
      await serviceA.init();
      final url = 'http://127.0.0.1:${server.port}';
      await serviceA.signIn(
        serverUrl: url,
        email: 'alice@example.test',
        password: 'fixture-password',
      );
      await serviceA.syncNow();
      expect(serviceA.lastError, isNull);
      await serviceB.init();
      await serviceB.signIn(
        serverUrl: url,
        email: 'alice@example.test',
        password: 'fixture-password',
      );
      await serviceB.syncNow();
      expect(serviceB.lastError, isNull);
      await serviceA.syncNow();
      expect(githubB.credential, githubA.credential);
      expect(spotifyA.credential, spotifyB.credential);
      expect(latin1.decode(blob!), isNot(contains('fixture-github-private')));
      githubA.set({'token': 'fixture-github-updated', 'login': 'alice'});
      spotifyB.set({'refreshToken': 'fixture-spotify-updated'});
      conflictOnce = true;
      await serviceA.syncNow();
      expect(serviceA.lastError, isNull);
      expect(conflicts, 1);
      await serviceB.syncNow();
      await serviceA.syncNow();
      expect(githubB.credential?['token'], 'fixture-github-updated');
      expect(spotifyA.credential?['refreshToken'], 'fixture-spotify-updated');
      githubA.set(null);
      await serviceA.syncNow();
      await serviceB.syncNow();
      expect(githubB.credential, isNull);
    }, _RealHttpOverrides()),
  );

  test(
    'all credential fields survive sync without aliasing exported records',
    () async {
      final source = _Connection();
      final target = _Connection();
      final a = AccountConnectionsSync(
        endpoints: {'youtube': source.endpoint},
        secrets: _Secrets(),
      );
      final b = AccountConnectionsSync(
        endpoints: {'youtube': target.endpoint},
        secrets: _Secrets(),
      );
      addTearDown(() {
        a.dispose();
        b.dispose();
        source.dispose();
        target.dispose();
      });
      source.credential = {
        'clientId': 'fixture-id',
        'clientSecret': 'fixture-secret',
        'accessToken': 'fixture-access',
        'refreshToken': 'fixture-refresh',
        'expiresAt': '2026-10-10T12:00:00Z',
        'channelId': 'channel',
      };
      final exported = await a.exportData();
      await b.importData(exported);
      expect(target.credential, source.credential);
      target.credential!['channelId'] = 'other';
      expect(source.credential!['channelId'], 'channel');
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Covers the benchmark scenes that used to ship inside the app bundle
/// (`assets/tests/`, ~6 MB of HTML): the store that serves them from disk and
/// the `/api/v1/ai-benchmarks/*` endpoints the app downloads them through.
void main() {
  group('AiBenchmarkStore', () {
    late Directory dir;
    late Directory seed;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_bench_test');
      seed = await Directory.systemTemp.createTemp('luma_bench_seed');
      await Directory('${seed.path}/scenes').create(recursive: true);
      await Directory('${seed.path}/previews').create(recursive: true);
      await File('${seed.path}/manifest.json').writeAsString(jsonEncode({
        'fallbackPreviews': {'pagoda': 'pagoda-preview.png'},
        'benchmarks': [
          {
            'id': 'pagoda_demo',
            'kind': 'pagoda',
            'model': 'Demo 1.0',
            'description': 'A demo scene',
          },
          {
            'id': 'engine_demo',
            'kind': 'engine',
            'model': 'Demo Engine',
            'description': 'A demo engine',
          },
          {
            // No scene file for this one: listed in the roster but skipped.
            'id': 'pagoda_missing',
            'kind': 'pagoda',
            'model': 'Missing',
            'description': 'Has no file',
          },
        ],
      }));
      await File('${seed.path}/scenes/pagoda_demo.html')
          .writeAsString('<html>demo</html>');
      await File('${seed.path}/scenes/engine_demo.html')
          .writeAsString('<html>engine</html>');
      await File('${seed.path}/previews/pagoda_demo.png')
          .writeAsBytes([1, 2, 3, 4]);
      await File('${seed.path}/previews/pagoda-preview.png')
          .writeAsBytes([9, 9, 9]);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
      if (await seed.exists()) await seed.delete(recursive: true);
    });

    test('lists roster entries that have a scene file', () async {
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final entries = await store.list();
      expect([for (final e in entries) e.id], ['pagoda_demo', 'engine_demo']);
      final pagoda = entries.firstWhere((e) => e.id == 'pagoda_demo');
      expect(pagoda.kind, 'pagoda');
      expect(pagoda.model, 'Demo 1.0');
      expect(pagoda.description, 'A demo scene');
      expect(pagoda.sizeBytes, '<html>demo</html>'.length);
      expect(pagoda.sha256, isNotEmpty);
      expect(pagoda.hasPreview, isTrue);
      expect(entries.firstWhere((e) => e.id == 'engine_demo').hasPreview,
          isFalse);
    });

    test('advertises the generic tile artwork', () async {
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      expect(await store.fallbackPreviews(), {'pagoda': 'pagoda-preview.png'});
    });

    test('reads scenes, previews and fallbacks', () async {
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final scene = (await store.readScene('pagoda_demo'))!;
      expect(utf8.decode(scene.bytes), '<html>demo</html>');
      expect(scene.etag, isNotEmpty);

      final preview = (await store.readPreview('pagoda_demo'))!;
      expect(preview.bytes, [1, 2, 3, 4]);

      expect(await store.readPreview('engine_demo'), isNull);
      expect(await store.readScene('pagoda_missing'), isNull);
      expect(await store.readScene('../ai_models'), isNull);
      expect(await store.readScene('pagoda_demo;rm'), isNull);

      final fallback = (await store.readFallback('pagoda-preview.png'))!;
      expect(fallback.bytes, [9, 9, 9]);
      expect(await store.readFallback('pagoda_demo.png'), isNotNull);
      expect(await store.readFallback('../../secret.txt'), isNull);
      expect(await store.readFallback('absent.png'), isNull);
    });

    test('a data-directory file overrides the seed', () async {
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      await File('${dir.path}/ai_benchmarks/engine_demo.html')
          .writeAsString('<html>override</html>');
      final scene = (await store.readScene('engine_demo'))!;
      expect(utf8.decode(scene.bytes), '<html>override</html>');
    });

    test('a scene missing from the roster still shows up', () async {
      await File('${seed.path}/scenes/pagoda_extra.html')
          .writeAsString('<html>extra</html>');
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final ids = [for (final e in await store.list()) e.id];
      expect(ids, contains('pagoda_extra'));
    });

    test('the template file is never a benchmark', () async {
      await File('${seed.path}/scenes/pagoda.html')
          .writeAsString('<html>template</html>');
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final ids = [for (final e in await store.list()) e.id];
      expect(ids, isNot(contains('pagoda')));
      expect(await store.readScene('pagoda'), isNull);
    });

    test('manifest carries hashes and a stable etag', () async {
      final store =
          await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final first = await store.manifest();
      final second = await store.manifest();
      expect(first.etag, second.etag);
      final decoded = first.json;
      expect(decoded['fallbackPreviews'], {'pagoda': 'pagoda-preview.png'});
      final benchmarks = decoded['benchmarks'] as List;
      expect(benchmarks.length, 2);
      expect(benchmarks.first['sha256'], isNotEmpty);
      expect(benchmarks.first['sizeBytes'], greaterThan(0));
    });

    test('works with no seed at all', () async {
      final store = await AiBenchmarkStore.open(dir.path);
      expect(await store.list(), isEmpty);
      expect((await store.manifest()).json['benchmarks'], isEmpty);
    });
  });

  group('ai-benchmarks endpoints', () {
    late Directory dir;
    late Directory seed;
    late Store store;
    late Handler handler;

    Future<Handler> buildHandler() async {
      final config = ServerConfig(
        port: 0,
        dataDir: dir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(hours: 24),
        approvalMode: ApprovalMode.open,
        adminKey: null,
        mistralApiKey: null,
        mistralAgentId: null,
        googleApiKey: null,
        itadApiKey: null,
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: null,
        wikiDir: null,
        publicUrl: 'https://sync.example.com',
        oauthProviders: const {},
      );
      return Api(
        store,
        config,
        Mailer(MailConfig.fromEnvironment(const {})),
        await FamilyStore.open(dir.path),
        await ChatStore.open(dir.path),
        await AiUsageStore.open(dir.path),
        await SubwayStore.open(dir.path),
        await RecipeStore.open(dir.path),
        await AiModelCatalogStore.open(dir.path),
        await AiBenchmarkStore.open(dir.path, seedDir: seed.path),
      ).handler;
    }

    Future<String> seedApprovedUser() async {
      const token = 'test-bearer-token-0123456789';
      final filler = base64Encode(List.filled(32, 1));
      final user = StoredUser(
        id: 'u1',
        email: 'alice@example.com',
        authHash: filler,
        authSalt: filler,
        kdfSalt: base64Encode(List.filled(16, 2)),
        kdfIterations: 200000,
        quotaBytes: 1024,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      store.usersById[user.id] = user;
      store.userIdByEmail[user.email] = user.id;
      // Sessions persist to sqlite with a foreign key onto the users table, so
      // the user row has to exist there too — not just in the in-memory maps.
      await store.saveUsers();
      final tokenHash = sha256.convert(utf8.encode(token)).toString();
      store.sessionsByTokenHash[tokenHash] = StoredSession(
        tokenHash: tokenHash,
        userId: user.id,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        expiresAtMs:
            DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      return token;
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_bench_api_test');
      seed = await Directory.systemTemp.createTemp('luma_bench_api_seed');
      await Directory('${seed.path}/scenes').create(recursive: true);
      await Directory('${seed.path}/previews').create(recursive: true);
      await File('${seed.path}/manifest.json').writeAsString(jsonEncode({
        'fallbackPreviews': {'pagoda': 'pagoda-preview.png'},
        'benchmarks': [
          {
            'id': 'pagoda_demo',
            'kind': 'pagoda',
            'model': 'Demo 1.0',
            'description': 'A demo scene',
          },
        ],
      }));
      await File('${seed.path}/scenes/pagoda_demo.html')
          .writeAsString('<html>demo</html>');
      await File('${seed.path}/previews/pagoda_demo.png')
          .writeAsBytes([1, 2, 3, 4]);
      await File('${seed.path}/previews/pagoda-preview.png')
          .writeAsBytes([9, 9, 9]);
      store = await Store.open(dir.path);
      handler = await buildHandler();
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
      if (await seed.exists()) await seed.delete(recursive: true);
    });

    Future<Response> get(String path,
        {String? token, Map<String, String>? headers}) async {
      return handler(Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          ...?headers,
        },
      ));
    }

    test('refuses every route without a bearer token', () async {
      for (final path in [
        '/api/v1/ai-benchmarks',
        '/api/v1/ai-benchmarks/scene/pagoda_demo',
        '/api/v1/ai-benchmarks/preview/pagoda_demo',
        '/api/v1/ai-benchmarks/fallback/pagoda-preview.png',
      ]) {
        expect((await get(path)).statusCode, 401, reason: path);
      }
    });

    test('manifest lists scenes with hashes', () async {
      final token = await seedApprovedUser();
      final response = await get('/api/v1/ai-benchmarks', token: token);
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final etag = response.headers['etag'];
      expect(etag, isNotNull);
      final decoded =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect((decoded['benchmarks'] as List).length, 1);
      expect((decoded['benchmarks'] as List).first['id'], 'pagoda_demo');

      final notModified = await get('/api/v1/ai-benchmarks',
          token: token, headers: {'If-None-Match': etag!});
      expect(notModified.statusCode, 304);
    });

    test('serves scenes, previews and fallback art', () async {
      final token = await seedApprovedUser();

      final scene =
          await get('/api/v1/ai-benchmarks/scene/pagoda_demo', token: token);
      expect(scene.statusCode, 200);
      expect(scene.headers['content-type'], contains('text/html'));
      expect(await scene.readAsString(), '<html>demo</html>');

      final preview =
          await get('/api/v1/ai-benchmarks/preview/pagoda_demo', token: token);
      expect(preview.statusCode, 200);
      expect(preview.headers['content-type'], 'image/png');

      final fallback = await get(
          '/api/v1/ai-benchmarks/fallback/pagoda-preview.png',
          token: token);
      expect(fallback.statusCode, 200);
      expect(fallback.headers['content-type'], 'image/png');
    });

    test('unknown scenes, previews and art 404', () async {
      final token = await seedApprovedUser();
      expect(
          (await get('/api/v1/ai-benchmarks/scene/pagoda_nope', token: token))
              .statusCode,
          404);
      expect(
          (await get('/api/v1/ai-benchmarks/scene/pagoda_demo!',
                  token: token))
              .statusCode,
          400);
      expect(
          (await get('/api/v1/ai-benchmarks/preview/pagoda_nope', token: token))
              .statusCode,
          404);
      expect(
          (await get('/api/v1/ai-benchmarks/fallback/nope.png', token: token))
              .statusCode,
          404);
      expect(
          (await get('/api/v1/ai-benchmarks/fallback/../x.png', token: token))
              .statusCode,
          404);
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_api.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/sync/sync_service.dart';

AiBenchmarkManifest _manifest(List<AiBenchmark> benchmarks) =>
    AiBenchmarkManifest(
      benchmarks: benchmarks,
      fallbackPreviews: const {'pagoda': 'pagoda-preview.png'},
      refreshedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

AiBenchmark _benchmark({
  String id = 'pagoda_demo',
  String kind = 'pagoda',
  String model = 'Demo 1.0',
  String html = '<html>demo</html>',
  bool hasPreview = true,
}) {
  final bytes = utf8.encode(html);
  return AiBenchmark(
    id: id,
    kind: kind,
    model: model,
    description: 'A demo scene',
    sizeBytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    hasPreview: hasPreview,
  );
}

/// An [AiBenchmarkApi] that answers from memory instead of the network.
class _FakeApi extends AiBenchmarkApi {
  _FakeApi({AiBenchmarkManifest? manifest, this.sceneHtml = const {}})
      : _manifest = manifest ?? AiBenchmarkManifest.empty,
        super('https://sync.example.com');

  final AiBenchmarkManifest _manifest;
  final Map<String, String> sceneHtml;
  int manifestCalls = 0;
  int sceneCalls = 0;

  @override
  Future<AiBenchmarkFetchResult> fetchManifest({String? knownEtag}) async {
    manifestCalls++;
    return AiBenchmarkFetchResult(manifest: _manifest, etag: '"fake"');
  }

  @override
  Future<Uint8List> fetchScene(String id) async {
    sceneCalls++;
    final html = sceneHtml[id];
    if (html == null) {
      throw const AiBenchmarkApiException(404, 'No such benchmark scene.');
    }
    return Uint8List.fromList(utf8.encode(html));
  }

  @override
  Future<Uint8List?> fetchPreview(String id) async => null;

  @override
  Future<Uint8List?> fetchFallback(String file) async => null;
}

/// A [SyncService] that only answers the three questions the benchmark
/// repository asks: is there an approved account, where, and with what token.
class _FakeSync implements SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #serverReady) return true;
    if (invocation.memberName == #serverUrl) {
      return 'https://sync.example.com';
    }
    if (invocation.memberName == #authToken) return 'token';
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('AiBenchmark.fromJson', () {
    test('parses a manifest entry', () {
      final b = AiBenchmark.fromJson({
        'id': 'pagoda_haiku45',
        'kind': 'pagoda',
        'model': 'Haiku 4.5',
        'description': 'Fast vision model',
        'sizeBytes': 32824,
        'sha256': 'abc123',
        'updatedAtMs': 1789052389000,
        'hasPreview': true,
      });
      expect(b.id, 'pagoda_haiku45');
      expect(b.isPagoda, isTrue);
      expect(b.isEngine, isFalse);
      expect(b.model, 'Haiku 4.5');
      expect(b.sizeBytes, 32824);
      expect(b.updatedAt?.millisecondsSinceEpoch, 1789052389000);
      expect(b.hasPreview, isTrue);
    });

    test('missing fields degrade to an empty-but-valid entry', () {
      final b = AiBenchmark.fromJson({'id': 'engine_x'});
      expect(b.model, '');
      expect(b.sizeBytes, 0);
      expect(b.updatedAt, isNull);
      expect(b.hasPreview, isFalse);
    });
  });

  group('AiBenchmarkManifest.fromJson', () {
    test('parses roster and generic artwork', () {
      final m = AiBenchmarkManifest.fromJson({
        'refreshedAtMs': 1000,
        'fallbackPreviews': {'pagoda': 'pagoda-preview.png'},
        'benchmarks': [
          {
            'id': 'pagoda_a',
            'kind': 'pagoda',
            'model': 'A',
            'description': '',
            'sizeBytes': 10,
            'sha256': 'x',
          },
          {
            'id': 'engine_b',
            'kind': 'engine',
            'model': 'B',
            'description': '',
            'sizeBytes': 20,
            'sha256': 'y',
          },
        ],
      });
      expect(m.benchmarks.length, 2);
      expect(m.ofKind('pagoda').single.id, 'pagoda_a');
      expect(m.ofKind('engine').single.id, 'engine_b');
      expect(m.byId('nope'), isNull);
      expect(m.fallbackPreviews, {'pagoda': 'pagoda-preview.png'});
    });
  });

  group('AiBenchmarkRepository', () {
    late Directory support;

    setUp(() async {
      support =
          await Directory.systemTemp.createTemp('luma_bench_client_test');
    });

    tearDown(() async {
      if (await support.exists()) await support.delete(recursive: true);
    });

    AiBenchmarkRepository repoWith(
      AiBenchmarkManifest manifest, {
      SyncService? sync,
      _FakeApi? api,
    }) =>
        AiBenchmarkRepository(
          sync,
          apiFactory: (baseUrl, token) => api ?? _FakeApi(),
          cacheDirProvider: () async => support,
        );

    test('load with no account leaves an empty roster, not an error', () async {
      final repo = repoWith(AiBenchmarkManifest.empty);
      await repo.load();
      expect(repo.loading, isFalse);
      expect(repo.manifest.isEmpty, isTrue);
      expect(repo.canRefresh, isFalse);
    });

    test('refreshFromServer fills the roster when signed in', () async {
      final manifest = _manifest([_benchmark()]);
      final api = _FakeApi(manifest: manifest);
      final repo = repoWith(AiBenchmarkManifest.empty,
          sync: _FakeSync(), api: api);
      await repo.refreshFromServer();
      expect(api.manifestCalls, 1);
      expect(repo.manifest.benchmarks.single.id, 'pagoda_demo');
    });

    test('sceneFile throws without an account to fetch from', () async {
      final repo = AiBenchmarkRepository.withManifest(
        _manifest([_benchmark()]),
        cacheDir: support,
      );
      await expectLater(
        repo.sceneFile('pagoda_demo'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.sceneFile('pagoda_nope'),
        throwsA(isA<StateError>()),
      );
    });

    test('sceneFile downloads, verifies and caches', () async {
      final benchmark = _benchmark();
      final api = _FakeApi(
        manifest: _manifest([benchmark]),
        sceneHtml: {'pagoda_demo': '<html>demo</html>'},
      );
      final repo = repoWith(_manifest([benchmark]),
          sync: _FakeSync(), api: api);
      await repo.refreshFromServer();

      final file = await repo.sceneFile('pagoda_demo');
      expect(await file.readAsString(), '<html>demo</html>');
      expect(api.sceneCalls, 1);

      // Second open serves the cache — no second download.
      final again = await repo.sceneFile('pagoda_demo');
      expect(again.path, file.path);
      expect(api.sceneCalls, 1);
    });

    test('sceneFile rejects bytes that fail the integrity check', () async {
      final benchmark = _benchmark();
      final api = _FakeApi(
        manifest: _manifest([benchmark]),
        sceneHtml: {'pagoda_demo': '<html>tampered</html>'},
      );
      final repo = repoWith(_manifest([benchmark]),
          sync: _FakeSync(), api: api);
      await repo.refreshFromServer();

      await expectLater(
        repo.sceneFile('pagoda_demo'),
        throwsA(isA<AiBenchmarkApiException>()),
      );
    });

    test('previews read from the disk cache', () async {
      final cache = Directory(
          '${support.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir'
          '${Platform.pathSeparator}previews');
      await cache.create(recursive: true);
      await File('${cache.path}/pagoda_demo.png')
          .writeAsBytes([1, 2, 3]);
      final fallbacks = Directory(
          '${support.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir'
          '${Platform.pathSeparator}fallbacks');
      await fallbacks.create(recursive: true);
      await File('${fallbacks.path}/pagoda-preview.png')
          .writeAsBytes([9]);

      final repo = AiBenchmarkRepository.withManifest(
        _manifest([_benchmark()]),
        cacheDir: support,
      );
      expect(repo.previewFile('pagoda_demo'), isNotNull);
      expect(repo.previewFile('engine_demo'), isNull);
      expect(repo.fallbackFile('pagoda'), isNotNull);
      expect(repo.fallbackFile('engine'), isNull);
    });
  });
}

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
  String previewSha256 = '',
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
    previewSha256: previewSha256,
  );
}

/// An [AiBenchmarkApi] that answers from memory instead of the network.
class _FakeApi extends AiBenchmarkApi {
  _FakeApi(
      {AiBenchmarkManifest? manifest,
      this.sceneHtml = const {},
      this.previews = const {},
      this.fallbacks = const {}})
      : _manifest = manifest ?? AiBenchmarkManifest.empty,
        super('https://sync.example.com');

  final AiBenchmarkManifest _manifest;
  final Map<String, String> sceneHtml;
  final Map<String, List<int>> previews;
  final Map<String, List<int>> fallbacks;
  int manifestCalls = 0;
  int sceneCalls = 0;
  int previewCalls = 0;
  int fallbackCalls = 0;

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
  Future<Uint8List?> fetchPreview(String id) async {
    previewCalls++;
    final bytes = previews[id];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> fetchFallback(String file) async {
    fallbackCalls++;
    final bytes = fallbacks[file];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }
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

    test('parses preview hashes into entries and maps', () {
      final m = AiBenchmarkManifest.fromJson({
        'refreshedAtMs': 1000,
        'fallbackPreviews': {'pagoda': 'pagoda-preview.png'},
        'fallbackHashes': {'pagoda-preview.png': 'fallbackhash'},
        'previewHashes': {'pagoda_a': 'maphash'},
        'benchmarks': [
          {
            'id': 'pagoda_a',
            'kind': 'pagoda',
            'model': 'A',
            'description': '',
            'sizeBytes': 10,
            'sha256': 'x',
            'hasPreview': true,
          },
          {
            'id': 'pagoda_b',
            'kind': 'pagoda',
            'model': 'B',
            'description': '',
            'sizeBytes': 10,
            'sha256': 'x',
            'hasPreview': true,
            'previewSha256': 'inlinehash',
          },
        ],
      });
      expect(m.previewHashes, {'pagoda_a': 'maphash'});
      expect(m.fallbackHashes, {'pagoda-preview.png': 'fallbackhash'});
      expect(m.byId('pagoda_a')!.previewSha256, 'maphash');
      expect(m.byId('pagoda_b')!.previewSha256, 'inlinehash');
    });

    test('missing hashes degrade to empty, not an error', () {
      final m = AiBenchmarkManifest.fromJson({'benchmarks': []});
      expect(m.previewHashes, isEmpty);
      expect(m.fallbackHashes, isEmpty);
      expect(m.byId('x'), isNull);
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

    test('warmPreviews re-downloads a preview whose hash changed', () async {
      final fresh = [10, 20, 30];
      final freshHash = sha256.convert(fresh).toString();
      final manifest = AiBenchmarkManifest(
        benchmarks: [_benchmark(previewSha256: freshHash)],
        fallbackPreviews: const {'pagoda': 'pagoda-preview.png'},
        previewHashes: const {},
        fallbackHashes: const {},
        refreshedAt: null,
      );
      final api = _FakeApi(manifest: manifest, previews: {
        'pagoda_demo': fresh,
      });
      final repo = repoWith(manifest, sync: _FakeSync(), api: api);

      // A stale file from before the re-render sits in the cache.
      final root = Directory(
          '${support.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir'
          '${Platform.pathSeparator}previews');
      await root.create(recursive: true);
      await File('${root.path}/pagoda_demo.png').writeAsBytes([1, 2, 3]);

      await repo.refreshFromServer();
      await repo.warmPreviews();
      expect(api.previewCalls, 1);
      expect(await File('${root.path}/pagoda_demo.png').readAsBytes(), fresh);

      // Second warm sees matching bytes and leaves the network alone.
      await repo.warmPreviews();
      expect(api.previewCalls, 1);
    });

    test('warmPreviews keeps a preview with no hash to compare', () async {
      final manifest = _manifest([_benchmark()]);
      final api = _FakeApi(manifest: manifest);
      final repo = repoWith(manifest, sync: _FakeSync(), api: api);
      final dir = Directory(
          '${support.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir'
          '${Platform.pathSeparator}previews');
      await dir.create(recursive: true);
      await File('${dir.path}/pagoda_demo.png').writeAsBytes([1, 2, 3]);

      await repo.refreshFromServer();
      await repo.warmPreviews();
      expect(api.previewCalls, 0);
      expect(await File('${dir.path}/pagoda_demo.png').readAsBytes(), [1, 2, 3]);
    });

    test('warmPreviews re-downloads generic artwork whose hash changed',
        () async {
      const file = 'pagoda-preview.png';
      final fresh = [7, 8, 9];
      final manifest = AiBenchmarkManifest(
        benchmarks: [_benchmark(hasPreview: false)],
        fallbackPreviews: const {'pagoda': file},
        previewHashes: const {},
        fallbackHashes: {file: sha256.convert(fresh).toString()},
        refreshedAt: null,
      );
      final api = _FakeApi(manifest: manifest, fallbacks: {file: fresh});
      final repo = repoWith(manifest, sync: _FakeSync(), api: api);
      final dir = Directory(
          '${support.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir'
          '${Platform.pathSeparator}fallbacks');
      await dir.create(recursive: true);
      await File('${dir.path}/$file').writeAsBytes([9]);

      await repo.refreshFromServer();
      await repo.warmPreviews();
      expect(api.fallbackCalls, 1);
      expect(await File('${dir.path}/$file').readAsBytes(), fresh);
    });
  });
}

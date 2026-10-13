import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/benchmark_github.dart';
import 'package:luma_sync_server/benchmark_run_stats.dart';
import 'package:test/test.dart';

/// Legacy estimators remain deterministic, while served scene metadata no
/// longer exposes the removed run-cost fields.
void main() {
  group('estimateBenchmarkRun', () {
    test('is stable for the same scene', () {
      final a = estimateBenchmarkRun(
          id: 'pc_demo_high',
          kind: 'pc',
          model: 'Demo (High)',
          sizeBytes: 40000);
      final b = estimateBenchmarkRun(
          id: 'pc_demo_high',
          kind: 'pc',
          model: 'Demo (High)',
          sizeBytes: 40000);
      expect(a, b);
    });

    test('higher effort and bigger scenes cost more', () {
      int tokens(String id, String model, int size) => estimateBenchmarkRun(
              id: id, kind: 'engine', model: model, sizeBytes: size)
          .tokens;
      expect(tokens('engine_a_xhigh', 'A (XHigh)', 40000),
          greaterThan(tokens('engine_a_minimal', 'A (Minimal)', 40000)));
      expect(tokens('engine_b_low', 'B (Low)', 120000),
          greaterThan(tokens('engine_b_low2', 'B (Low)', 20000)));
    });

    test('stays in a believable range', () {
      final run = estimateBenchmarkRun(
          id: 'server_rack_big_max',
          kind: 'server_rack',
          model: 'Big (Max)',
          sizeBytes: 900000);
      expect(run.tokens, inInclusiveRange(1000, 5000000));
      expect(run.durationSec, inInclusiveRange(20, 4800));
      final tiny = estimateBenchmarkRun(
          id: 'pagoda_tiny', kind: 'pagoda', model: 'Tiny', sizeBytes: 10);
      expect(tiny.durationSec, greaterThanOrEqualTo(20));
      expect(tiny.tokens, greaterThan(0));
    });
  });

  group('AiBenchmarkStore scene metadata', () {
    late Directory dir;
    late Directory seed;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_stats_test');
      seed = await Directory.systemTemp.createTemp('luma_stats_seed');
      await Directory('${seed.path}/scenes').create(recursive: true);
      await File('${seed.path}/manifest.json').writeAsString(jsonEncode({
        'benchmarks': [
          {
            'id': 'pagoda_logged',
            'kind': 'pagoda',
            'model': 'Logged',
            'description': '',
            'tokens': 41200,
            'durationSec': 372,
          },
          {
            'id': 'pagoda_unlogged',
            'kind': 'pagoda',
            'model': 'Unlogged',
            'description': '',
          },
        ],
      }));
      for (final id in ['pagoda_logged', 'pagoda_unlogged']) {
        await File('${seed.path}/scenes/$id.html')
            .writeAsString('<canvas>$id</canvas>');
      }
    });

    tearDown(() async {
      await dir.delete(recursive: true);
      await seed.delete(recursive: true);
    });

    test('legacy run stats are omitted from served scene metadata', () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final entries = {for (final e in await store.list()) e.id: e};
      expect(entries.keys, containsAll(['pagoda_logged', 'pagoda_unlogged']));
      for (final entry in entries.values) {
        final json = entry.toJson();
        expect(json, isNot(contains('tokens')));
        expect(json, isNot(contains('durationSec')));
        expect(entry.sizeBytes, greaterThan(0));
      }
    });

    test('upload edits retain content integrity without removed run stats',
        () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final bytes = utf8.encode('<canvas>fresh</canvas>');
      final entry = await store.saveUpload(
        kind: 'engine',
        id: 'engine_fresh',
        model: 'Fresh',
        vendor: '',
        description: 'run',
        bytes: bytes,
      );
      expect(entry, isNot(contains('tokens')));
      expect(entry, isNot(contains('durationSec')));
      final uploaded =
          (await store.list()).firstWhere((e) => e.id == 'engine_fresh');

      await store.saveUpload(
        kind: 'engine',
        id: 'engine_fresh',
        model: 'Fresh',
        vendor: '',
        description: 'edited',
        bytes: null,
      );
      final kept =
          (await store.list()).firstWhere((e) => e.id == 'engine_fresh');
      expect(kept.description, 'edited');
      expect(kept.sizeBytes, bytes.length);
      expect(kept.sha256, uploaded.sha256);
      expect(kept.toJson(), isNot(contains('tokens')));
      expect(kept.toJson(), isNot(contains('durationSec')));
    });

    test('a hand upload does not add estimated run stats', () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final entry = await store.saveUpload(
        kind: 'engine',
        id: 'engine_by_hand',
        model: 'By Hand',
        vendor: '',
        description: '',
        bytes: utf8.encode('<canvas>${'x' * 5000}</canvas>'),
      );
      expect(entry, isNot(contains('tokens')));
      expect(entry, isNot(contains('durationSec')));
    });
  });

  test('upsertManifest replaces metadata and preserves explicitly supplied fields', () {
    final manifest = jsonEncode({
      'benchmarks': [
        {
          'id': 'pagoda_a',
          'kind': 'pagoda',
          'model': 'A',
          'description': '',
          'tokens': 100,
          'durationSec': 5,
        },
      ],
    });
    final edited =
        jsonDecode(BenchmarkGithubPublisher.upsertManifest(manifest, {
      'id': 'pagoda_a',
      'kind': 'pagoda',
      'model': 'A2',
      'description': 'x',
    })) as Map<String, dynamic>;
    final stanza =
        (edited['benchmarks'] as List).single as Map<String, dynamic>;
    expect(stanza['model'], 'A2');
    expect(stanza, isNot(contains('tokens')));
    expect(stanza, isNot(contains('durationSec')));

    final reRun = jsonDecode(BenchmarkGithubPublisher.upsertManifest(manifest, {
      'id': 'pagoda_a',
      'kind': 'pagoda',
      'model': 'A2',
      'description': 'x',
      'tokens': 777,
      'durationSec': 9,
    })) as Map<String, dynamic>;
    final fresh = (reRun['benchmarks'] as List).single as Map<String, dynamic>;
    expect(fresh['model'], 'A2');
    expect(fresh['tokens'], 777);
    expect(fresh['durationSec'], 9);
  });
}

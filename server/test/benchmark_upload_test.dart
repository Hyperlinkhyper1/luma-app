import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/benchmark_github.dart';
import 'package:test/test.dart';

/// Covers the admin dashboard's "Upload test…": the store keeping uploads
/// apart from the seed until a deploy brings them in, and the publisher that
/// commits them to the repo.
void main() {
  group('AiBenchmarkStore uploads', () {
    late Directory dir;
    late Directory seed;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_upload_test');
      seed = await Directory.systemTemp.createTemp('luma_upload_seed');
      await Directory('${seed.path}/scenes').create(recursive: true);
      await File('${seed.path}/manifest.json').writeAsString(jsonEncode({
        'benchmarks': [
          {
            'id': 'pagoda_demo',
            'kind': 'pagoda',
            'model': 'Demo 1.0',
            'description': 'Seeded',
          },
        ],
      }));
      await File('${seed.path}/scenes/pagoda_demo.html')
          .writeAsString('<html>seed</html>');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
      await seed.delete(recursive: true);
    });

    test(
      'landing pages without a canvas are listed, editable and served as HTML',
      () async {
        final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
        const kind = 'website_landing_page';
        const id = '${kind}_demo';
        final bytes =
            utf8.encode('<!doctype html><html><body><main><h1>Forma</h1>'
                '<button>Start free</button></main></body></html>');
        await store.saveUpload(
          kind: kind,
          id: id,
          model: 'Demo',
          vendor: 'openai',
          description: 'A landing page',
          bytes: bytes,
        );
        final entry = (await store.list()).firstWhere((e) => e.id == id);
        expect(entry.kind, kind);
        expect(entry.vendor, 'openai');
        expect(
            (await store.editableEntries()).any((e) => e['id'] == id), isTrue);
        expect((await store.readScene(id))!.bytes, bytes);
        await store.saveUpload(
          kind: kind,
          id: id,
          model: 'Demo',
          vendor: 'openai',
          description: 'Edited landing page',
          bytes: null,
        );
        expect((await store.list()).firstWhere((e) => e.id == id).description,
            'Edited landing page');
        expect((await store.readScene(id))!.bytes, bytes);
      },
    );

    test(
      'server rack uploads are listed, editable and served as HTML',
      () async {
        final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
        const id = 'server_rack_demo_high';
        final bytes = utf8.encode('<html><canvas></canvas></html>');
        await store.saveUpload(
          kind: 'server_rack',
          id: id,
          model: 'Demo (High)',
          vendor: 'openai',
          description: 'A server rack',
          bytes: bytes,
        );
        final entry = (await store.list()).firstWhere((e) => e.id == id);
        expect(entry.kind, 'server_rack');
        expect(entry.vendor, 'openai');
        expect(
          (await store.editableEntries()).any((e) => e['id'] == id),
          isTrue,
        );
        expect((await store.readScene(id))!.bytes, bytes);
        await store.saveUpload(
          kind: 'server_rack',
          id: id,
          model: 'Demo (High)',
          vendor: 'openai',
          description: 'Edited rack',
          bytes: null,
        );
        expect(
          (await store.list()).firstWhere((e) => e.id == id).description,
          'Edited rack',
        );
        expect((await store.readScene(id))!.bytes, bytes);
      },
    );

    test('an upload is listed and served with its vendor', () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      await store.saveUpload(
        kind: 'keyboard',
        id: 'keyboard_sonnet55_high',
        model: 'Sonnet 5.5 (High)',
        vendor: 'anthropic',
        description: 'A keyboard',
        bytes: utf8.encode('<html>keys</html>'),
      );
      final entries = await store.list();
      final upload =
          entries.firstWhere((e) => e.id == 'keyboard_sonnet55_high');
      expect(upload.kind, 'keyboard');
      expect(upload.model, 'Sonnet 5.5 (High)');
      expect(upload.vendor, 'anthropic');
      expect(upload.toJson()['vendor'], 'anthropic');
      final scene = await store.readScene('keyboard_sonnet55_high');
      expect(utf8.decode(scene!.bytes), '<html>keys</html>');
      // Entries without a vendor keep leaving it out of the manifest.
      final demo = entries.firstWhere((e) => e.id == 'pagoda_demo');
      expect(demo.toJson().containsKey('vendor'), isFalse);
    });

    test('a pasted reply is trimmed to its page', () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      for (final (id, reply) in [
        ('keyboard_prose', 'I will write it now.<!DOCTYPE html>\n<html>k</html>'),
        ('keyboard_fenced', '```html\n<!DOCTYPE html>\n<html>k</html>\n```\n'),
      ]) {
        await store.saveUpload(
          kind: 'keyboard',
          id: id,
          model: 'Demo',
          vendor: '',
          description: 'A keyboard',
          bytes: utf8.encode(reply),
        );
        expect(utf8.decode((await store.readScene(id))!.bytes),
            '<!DOCTYPE html>\n<html>k</html>\n');
      }
      final clean = utf8.encode('<!DOCTYPE html>\n<html>k</html>\n');
      expect(AiBenchmarkStore.trimToPage(clean), same(clean));
    });

    test('an upload replaces a seeded scene until the seed is newer', () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      final past = DateTime.now().subtract(const Duration(hours: 1));
      await File('${seed.path}/scenes/pagoda_demo.html').setLastModified(past);
      await File('${seed.path}/manifest.json').setLastModified(past);
      await store.saveUpload(
        kind: 'pagoda',
        id: 'pagoda_demo',
        model: 'Demo 2.0',
        vendor: '',
        description: 'Uploaded',
        bytes: utf8.encode('<canvas>upload</canvas>'),
      );
      expect(utf8.decode((await store.readScene('pagoda_demo'))!.bytes),
          '<canvas>upload</canvas>');
      expect((await store.list()).single.model, 'Demo 2.0');

      // A deploy lands the committed files: the seed is newer now and wins.
      final later = DateTime.now().add(const Duration(minutes: 5));
      await File('${seed.path}/scenes/pagoda_demo.html')
          .writeAsString('<html>deployed</html>');
      await File('${seed.path}/scenes/pagoda_demo.html').setLastModified(later);
      await File('${seed.path}/manifest.json').setLastModified(later);
      expect(utf8.decode((await store.readScene('pagoda_demo'))!.bytes),
          '<html>deployed</html>');
      expect((await store.list()).single.model, 'Demo 1.0');
    });

    test('an edit changes the roster fields and keeps the scene', () async {
      final store = await AiBenchmarkStore.open(dir.path, seedDir: seed.path);
      await File('${seed.path}/manifest.json')
          .setLastModified(DateTime.now().subtract(const Duration(hours: 1)));
      await store.saveUpload(
        kind: 'pagoda',
        id: 'pagoda_demo',
        model: 'Demo 1.0 (Max)',
        vendor: 'openai',
        description: 'Edited',
        bytes: null,
      );
      final entry = (await store.editableEntries()).single;
      expect(entry['model'], 'Demo 1.0 (Max)');
      expect(entry['vendor'], 'openai');
      expect(entry['description'], 'Edited');
      expect(utf8.decode((await store.readScene('pagoda_demo'))!.bytes),
          '<html>seed</html>');

      expect(
          () => store.saveUpload(
                kind: 'pagoda',
                id: 'pagoda_nothing',
                model: 'Nothing',
                vendor: '',
                description: '',
                bytes: null,
              ),
          throwsArgumentError);
    });

    test('rejects uploads that do not fit the test', () {
      Map<String, dynamic> check(
              {String kind = 'pagoda',
              String id = 'pagoda_x',
              String model = 'X',
              String vendor = '',
              List<int>? bytes}) =>
          AiBenchmarkStore.validateUpload(
            kind: kind,
            id: id,
            model: model,
            vendor: vendor,
            description: '',
            bytes: bytes ?? utf8.encode('<canvas></canvas>'),
          );
      final glb = [...ascii.encode('glTF'), 2, 0, 0, 0, 12, 0, 0, 0];

      expect(check()['id'], 'pagoda_x');
      expect(check(kind: 'cathedral', id: 'cathedral_x', bytes: glb)['kind'],
          'cathedral');
      expect(() => check(kind: 'nope'), throwsArgumentError);
      expect(() => check(id: 'engine_x'), throwsArgumentError);
      expect(() => check(id: 'pagoda_'), throwsArgumentError);
      expect(() => check(id: 'pagoda_../x'), throwsArgumentError);
      expect(() => check(model: '  '), throwsArgumentError);
      expect(() => check(vendor: 'Evil Corp'), throwsArgumentError);
      expect(() => check(bytes: []), throwsArgumentError);
      expect(() => check(bytes: glb), throwsArgumentError);
      expect(() => check(kind: 'cathedral', id: 'cathedral_x'),
          throwsArgumentError);
      // A CSS-only keyboard filed under a WebGL test can never get a banner.
      final cssKeyboard =
          utf8.encode('<html><div class="keycap"></div></html>');
      expect(() => check(bytes: cssKeyboard), throwsArgumentError);
      expect(() => check(kind: 'pc', id: 'pc_x', bytes: cssKeyboard),
          throwsArgumentError);
      expect(
          check(kind: 'keyboard', id: 'keyboard_x', bytes: cssKeyboard)['id'],
          'keyboard_x');
      expect(
          check(
              bytes: utf8
                  .encode("<script>import * as T from 'three'</script>"))['id'],
          'pagoda_x');
    });
  });

  group('BenchmarkGithubPublisher', () {
    test('upsertManifest replaces in place or appends, keeping the layout', () {
      const manifest = '{"benchmarks":[{"id":"pagoda_a","kind":"pagoda",'
          '"model":"A"}],"fallbackPreviews":{"pagoda":"p.png"}}\n';
      final replaced = BenchmarkGithubPublisher.upsertManifest(
          manifest, {'model': 'A2', 'id': 'pagoda_a', 'kind': 'pagoda'});
      expect(
          replaced,
          '{"benchmarks":[{"id":"pagoda_a","kind":"pagoda","model":"A2"}],'
          '"fallbackPreviews":{"pagoda":"p.png"}}\n');
      final appended = BenchmarkGithubPublisher.upsertManifest(
          manifest, {'id': 'pagoda_b', 'kind': 'pagoda', 'model': 'B'});
      final list = (jsonDecode(appended) as Map)['benchmarks'] as List;
      expect([for (final e in list) e['id']], ['pagoda_a', 'pagoda_b']);
    });

    test('is off without a token', () {
      expect(BenchmarkGithubPublisher(environment: const {}).enabled, isFalse);
      expect(
          BenchmarkGithubPublisher(environment: const {
            'LUMA_BENCHMARK_GITHUB_TOKEN': ' ',
            'LUMA_BENCHMARK_GITHUB_REPO': '',
          }).repo,
          'Hyperlinkhyper1/luma-app');
    });

    test('commits scene and manifest in one [skip ci] commit', () async {
      final calls = <String>[];
      Map<String, dynamic>? commitBody;
      Map<String, dynamic>? treeBody;
      var refAttempts = 0;
      final publisher = BenchmarkGithubPublisher(
        environment: const {'LUMA_BENCHMARK_GITHUB_TOKEN': 'tok'},
        transport: (method, url, headers, body) async {
          expect(headers['Authorization'], 'Bearer tok');
          final path =
              url.path.replaceFirst('/repos/Hyperlinkhyper1/luma-app', '');
          calls.add('$method $path');
          final json = body == null ? null : jsonDecode(body);
          switch ('$method $path') {
            case 'POST /git/blobs':
              return (
                status: 201,
                body: jsonEncode({'sha': 'blob${calls.length}'})
              );
            case 'GET /git/ref/heads/master':
              return (
                status: 200,
                body: jsonEncode({
                  'object': {'sha': 'head'}
                })
              );
            case 'GET /git/commits/head':
              return (
                status: 200,
                body: jsonEncode({
                  'tree': {'sha': 'tree0'}
                })
              );
            case 'GET /contents/server/benchmarks/manifest.json':
              return (status: 200, body: '{"benchmarks":[]}');
            case 'POST /git/trees':
              treeBody = json as Map<String, dynamic>;
              return (status: 201, body: jsonEncode({'sha': 'tree1'}));
            case 'POST /git/commits':
              commitBody = json as Map<String, dynamic>;
              return (status: 201, body: jsonEncode({'sha': 'c1'}));
            case 'PATCH /git/refs/heads/master':
              // First attempt races someone else's push.
              return refAttempts++ == 0
                  ? (status: 422, body: '{"message":"not a fast forward"}')
                  : (status: 200, body: '{}');
          }
          return (status: 500, body: '{}');
        },
      );
      final url = await publisher.publish(
        entry: {'id': 'keyboard_x', 'kind': 'keyboard', 'model': 'X'},
        fileName: 'keyboard_x.html',
        bytes: utf8.encode('<html></html>'),
      );
      expect(url, 'https://github.com/Hyperlinkhyper1/luma-app/commit/c1');
      expect(commitBody!['message'], contains('[skip ci]'));
      expect(commitBody!['parents'], ['head']);
      final paths = [
        for (final t in treeBody!['tree'] as List) (t as Map)['path'],
      ];
      expect(paths, [
        'server/benchmarks/scenes/keyboard_x.html',
        'server/benchmarks/manifest.json',
      ]);
      expect(refAttempts, 2);
    });
  });
}

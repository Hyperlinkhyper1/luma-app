import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:test/test.dart';

void main() {
  test('seed serves the single canonical Astra cruise scene', () async {
    final data = await Directory.systemTemp.createTemp('cruise_seed_test');
    addTearDown(() => data.delete(recursive: true));
    final store = await AiBenchmarkStore.open(
      data.path,
      seedDir: Directory('benchmarks').absolute.path,
    );
    final entries = (await store.list())
        .where((entry) => entry.id == 'cruise_ship_gpt6_astra_ultra');
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.kind, 'cruise_ship');
    expect(entry.model, 'GPT 6 Astra (Ultra)');
    expect(entry.vendor, 'openai');
    final scene = await store.readScene(entry.id);
    expect(scene, isNotNull);
    expect(
        scene!.bytes,
        await File(
          'benchmarks/scenes/cruise_ship_gpt6_astra_ultra/index.html',
        ).readAsBytes());
    expect(scene.bytes.length, entry.sizeBytes);
    expect(sha256.convert(scene.bytes).toString(), entry.sha256);
    expect(utf8.decode(scene.bytes), contains('cruise-ready'));
    final catalog = await store.bannerCatalog();
    expect(catalog.where((tile) => tile['id'] == entry.id).single['kind'],
        'cruise_ship');
  });

  test('cruise folders are discovered and keep their complete kind prefix',
      () async {
    final data = await Directory.systemTemp.createTemp('cruise_discovery_test');
    addTearDown(() => data.delete(recursive: true));
    final seed = Directory('${data.path}/seed');
    final folder = Directory('${seed.path}/scenes/cruise_ship_demo');
    await folder.create(recursive: true);
    await File('${folder.path}/index.html').writeAsString('<canvas></canvas>');
    final store = await AiBenchmarkStore.open(data.path, seedDir: seed.path);
    final entry = (await store.list()).single;
    expect(entry.id, 'cruise_ship_demo');
    expect(entry.kind, 'cruise_ship');
    expect(entry.model, 'Demo');
    expect(await store.readScene(entry.id), isNotNull);
    expect((await store.previewCoverage()).single.id, entry.id);
  });

  test('admin accepts cruise HTML and rejects content without a canvas',
      () async {
    final data = await Directory.systemTemp.createTemp('cruise_upload_test');
    addTearDown(() => data.delete(recursive: true));
    final store = await AiBenchmarkStore.open(data.path);
    await store.saveUpload(
      kind: 'cruise_ship',
      id: 'cruise_ship_uploaded',
      model: 'Uploaded ship',
      vendor: 'openai',
      description: 'A ship',
      bytes: utf8.encode('<html><canvas></canvas></html>'),
    );
    expect((await store.list()).single.kind, 'cruise_ship');
    expect(await store.readScene('cruise_ship_uploaded'), isNotNull);
    expect(
      () => AiBenchmarkStore.validateUpload(
        kind: 'cruise_ship',
        id: 'cruise_ship_empty',
        model: 'Empty',
        vendor: '',
        description: '',
        bytes: utf8.encode('<html><p>No scene</p></html>'),
      ),
      throwsArgumentError,
    );
  });

  test('a deployed canonical folder supersedes an older admin upload',
      () async {
    final data = await Directory.systemTemp.createTemp('cruise_deploy_test');
    addTearDown(() => data.delete(recursive: true));
    final seed = Directory('${data.path}/seed');
    final folder = Directory('${seed.path}/scenes/cruise_ship_demo');
    await folder.create(recursive: true);
    final file = File('${folder.path}/index.html');
    await file.writeAsString('<canvas>seed</canvas>');
    await file
        .setLastModified(DateTime.now().subtract(const Duration(hours: 1)));
    final store = await AiBenchmarkStore.open(data.path, seedDir: seed.path);
    await store.saveUpload(
      kind: 'cruise_ship',
      id: 'cruise_ship_demo',
      model: 'Demo',
      vendor: 'openai',
      description: '',
      bytes: utf8.encode('<canvas>upload</canvas>'),
    );
    expect(utf8.decode((await store.readScene('cruise_ship_demo'))!.bytes),
        '<canvas>upload</canvas>');
    await file.writeAsString('<canvas>deployed</canvas>');
    await file.setLastModified(DateTime.now().add(const Duration(minutes: 1)));
    expect(utf8.decode((await store.readScene('cruise_ship_demo'))!.bytes),
        '<canvas>deployed</canvas>');
  });
}

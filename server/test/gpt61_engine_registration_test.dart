import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:test/test.dart';

void main() {
  test('seed roster serves GPT 6.1 Sol Low as an engine benchmark', () async {
    final data = await Directory.systemTemp.createTemp('gpt61_engine_test');
    addTearDown(() => data.delete(recursive: true));
    final store = await AiBenchmarkStore.open(
      data.path,
      seedDir: Directory('benchmarks').absolute.path,
    );
    final entries = (await store.list())
        .where((entry) => entry.id == 'engine_gpt61_sol_low');
    expect(entries, hasLength(1));
    expect(entries.single.kind, 'engine');
    expect(entries.single.model, 'GPT 6.1 Sol (Low)');
    final scene = await store.readScene('engine_gpt61_sol_low');
    expect(scene, isNotNull);
    expect(utf8.decode(scene!.bytes), contains('window.engineDebug'));
    expect(scene.bytes.length, entries.single.sizeBytes);
  });

  test('seed roster serves the separate GPT 6.1 Sol Xhigh folder entry',
      () async {
    final data =
        await Directory.systemTemp.createTemp('gpt61_engine_xhigh_test');
    addTearDown(() => data.delete(recursive: true));
    final store = await AiBenchmarkStore.open(
      data.path,
      seedDir: Directory('benchmarks').absolute.path,
    );
    final entries = await store.list();
    expect(
      entries.where((entry) => entry.id == 'engine_gpt61_sol_low'),
      hasLength(1),
    );
    final xhigh =
        entries.where((entry) => entry.id == 'engine_gpt61_sol_xhigh');
    expect(xhigh, hasLength(1));
    expect(xhigh.single.kind, 'engine');
    expect(xhigh.single.model, 'GPT 6.1 Sol (Xhigh)');
    final scene = await store.readScene('engine_gpt61_sol_xhigh');
    expect(scene, isNotNull);
    expect(utf8.decode(scene!.bytes), contains('GPT 6.1 Sol (Xhigh)'));
    expect(utf8.decode(scene.bytes), contains('window.engineDebug'));
    expect(scene.bytes.length, xhigh.single.sizeBytes);
    expect(
      scene.bytes,
      await File('benchmarks/scenes/engine_gpt61_sol_xhigh/index.html')
          .readAsBytes(),
    );
  });

  test('folder HTML scenes are discovered without a roster', () async {
    final data = await Directory.systemTemp.createTemp('engine_folder_test');
    addTearDown(() => data.delete(recursive: true));
    final seed = Directory('${data.path}/seed');
    final sceneDir = Directory('${seed.path}/scenes/engine_folder');
    await sceneDir.create(recursive: true);
    await File('${sceneDir.path}/index.html')
        .writeAsString('<p>Folder scene</p>');
    final store = await AiBenchmarkStore.open(data.path, seedDir: seed.path);

    final entries = await store.list();
    expect(entries.map((entry) => entry.id), ['engine_folder']);
    expect(entries.single.kind, 'engine');
    expect(
      utf8.decode((await store.readScene('engine_folder'))!.bytes),
      '<p>Folder scene</p>',
    );
    expect((await store.previewCoverage()).single.id, 'engine_folder');
  });

  test('folder scenes keep flat-file precedence and operator overrides',
      () async {
    final data =
        await Directory.systemTemp.createTemp('engine_precedence_test');
    addTearDown(() => data.delete(recursive: true));
    final seed = Directory('${data.path}/seed');
    final seedFolder = Directory('${seed.path}/scenes/engine_demo');
    await seedFolder.create(recursive: true);
    await File('${seedFolder.path}/index.html').writeAsString('seed folder');
    final store = await AiBenchmarkStore.open(data.path, seedDir: seed.path);

    Future<String> sceneText() async =>
        utf8.decode((await store.readScene('engine_demo'))!.bytes);
    expect(await sceneText(), 'seed folder');
    final seedFlat = File('${seed.path}/scenes/engine_demo.html');
    await seedFlat.writeAsString('seed flat');
    expect(await sceneText(), 'seed flat');

    final overrideFolder = Directory('${data.path}/ai_benchmarks/engine_demo');
    await overrideFolder.create();
    final overrideIndex = File('${overrideFolder.path}/index.html');
    await overrideIndex.writeAsString('override folder');
    expect(await sceneText(), 'override folder');
    final overrideFlat = File('${data.path}/ai_benchmarks/engine_demo.html');
    await overrideFlat.writeAsString('override flat');
    expect(await sceneText(), 'override flat');
    expect((await store.list()).map((entry) => entry.id), ['engine_demo']);

    await overrideFlat.delete();
    expect(await sceneText(), 'override folder');
    await overrideIndex.delete();
    expect(await sceneText(), 'seed flat');
  });
}

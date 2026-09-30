import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:test/test.dart';

void main() {
  test('seed roster serves Qwen 3.8 (27B) as a keyboard benchmark', () async {
    final data = await Directory.systemTemp.createTemp('keyboard_qwen_test');
    addTearDown(() => data.delete(recursive: true));
    final store = await AiBenchmarkStore.open(
      data.path,
      seedDir: Directory('benchmarks').absolute.path,
    );
    final entries = (await store.list())
        .where((entry) => entry.id == 'keyboard_qwen_3_8_27b');
    expect(entries, hasLength(1));
    expect(entries.single.kind, 'keyboard');
    expect(entries.single.model, 'Qwen 3.8 (27B)');
    final scene = await store.readScene('keyboard_qwen_3_8_27b');
    expect(scene, isNotNull);
    expect(scene!.bytes.length, entries.single.sizeBytes);
    expect(scene.bytes.length, greaterThan(10000));
  });

  test('keyboard scenes are framable html in the banner catalog', () async {
    final data =
        await Directory.systemTemp.createTemp('keyboard_catalog_test');
    addTearDown(() => data.delete(recursive: true));
    final store = await AiBenchmarkStore.open(
      data.path,
      seedDir: Directory('benchmarks').absolute.path,
    );
    final tiles = (await store.bannerCatalog())
        .where((tile) => tile['id'] == 'keyboard_qwen_3_8_27b');
    expect(tiles, hasLength(1));
    expect(tiles.single['kind'], 'keyboard');
    expect(tiles.single['framable'], isTrue);
  });

  test('keyboard scenes are discovered without a roster', () async {
    final data = await Directory.systemTemp.createTemp('keyboard_folder_test');
    addTearDown(() => data.delete(recursive: true));
    final seed = Directory('${data.path}/seed');
    await Directory('${seed.path}/scenes').create(recursive: true);
    await File('${seed.path}/scenes/keyboard_demo.html')
        .writeAsString('<p>Keyboard scene</p>');
    final store = await AiBenchmarkStore.open(data.path, seedDir: seed.path);

    final entries = await store.list();
    expect(entries.map((entry) => entry.id), ['keyboard_demo']);
    expect(entries.single.kind, 'keyboard');
  });
}

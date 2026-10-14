import 'dart:io';

import 'package:luma_sync_server/storage_usage.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('luma_storage_usage_test');
  });
  tearDown(() async => temp.delete(recursive: true));

  Future<void> write(String path, int bytes) async {
    final file = File('${temp.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(bytes, 1));
  }

  test('includes all data, hidden files, website, seeds and runtime', () async {
    await write('data/blobs/account/snapshot', 10);
    await write('data/new_store/deep/media', 20);
    await write('data/.pending-upload', 30);
    await write('wiki/site/index.html', 40);
    await write('seed/scene.glb', 50);
    await write('runtime/bundle/lib/server.so', 60);
    await write('unrelated/file', 100);

    final usage = await measureStorageUsage({
      '${temp.path}/data': 'Server data',
      '${temp.path}/wiki': 'Website',
      '${temp.path}/seed': 'Scenes',
      '${temp.path}/runtime': 'Runtime',
    });

    expect(usage.complete, isTrue);
    expect(usage.totalBytes, 210);
    expect(usage.entries, hasLength(4));
  });

  test('overlapping roots count each file once in either order', () async {
    await write('data/blobs/file', 10);
    await write('data/other', 20);
    for (final roots in [
      {'${temp.path}/data': 'Data', '${temp.path}/data/blobs': 'Blobs'},
      {'${temp.path}/data/blobs': 'Blobs', '${temp.path}/data': 'Data'},
    ]) {
      expect((await measureStorageUsage(roots)).totalBytes, 30);
    }
  });

  test('refresh detects newly added and removed files', () async {
    final roots = {'${temp.path}/data': 'Data'};
    await write('data/original', 10);
    expect((await measureStorageUsage(roots)).totalBytes, 10);
    await write('data/new_store/new_file', 25);
    expect((await measureStorageUsage(roots)).totalBytes, 35);
    await File('${temp.path}/data/original').delete();
    expect((await measureStorageUsage(roots)).totalBytes, 25);
  });

  test('empty or absent optional roots report zero', () async {
    final usage = await measureStorageUsage({'${temp.path}/absent': 'Absent'});
    expect(usage.totalBytes, 0);
    expect(usage.complete, isTrue);
    expect(usage.capacityText, '0.00/256GB');
  });

  test('formats decimal GB against the fixed capacity without capping usage',
      () {
    final usage = StorageUsage([
      {'bytes': 12340000000},
    ], complete: true);
    expect(usage.capacityText, '12.34/256GB');
    final overCapacity = StorageUsage([
      {'bytes': 257000000000},
    ], complete: true);
    expect(overCapacity.capacityText, '257.00/256GB');
    expect(StorageUsage([], complete: false).capacityText, '–/256GB');
  });

  test('does not follow links outside the Luma roots', () async {
    await write('data/file', 10);
    await write('unrelated/file', 50);
    await Link('${temp.path}/data/link').create('${temp.path}/unrelated');
    final usage = await measureStorageUsage({'${temp.path}/data': 'Data'});
    expect(usage.totalBytes, 10);
    expect(usage.complete, isTrue);
  },
      skip: Platform.isWindows
          ? 'Windows link creation requires privileges.'
          : false);
}

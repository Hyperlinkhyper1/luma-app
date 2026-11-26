import 'dart:io';

import 'package:luma_sync_server/wiki_flags.dart';
import 'package:test/test.dart';

/// In the Docker setup the wiki checkout is mounted read-only, so a publish
/// has to reach the builder through the data volume and deploy-watcher.sh.
/// A folder that doesn't exist stands in for the read-only mount here: both
/// refuse the write with a FileSystemException.
void main() {
  late Directory root;
  late String wiki;
  late String data;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('luma_wiki_flags_');
    wiki = '${root.path}/wiki';
    data = '${root.path}/data';
    await Directory(wiki).create();
    await Directory(data).create();
  });

  tearDown(() => root.delete(recursive: true));

  test('a writable wiki checkout gets the flag directly', () {
    final now = DateTime.utc(2026, 11, 26, 12);
    expect(requestWikiFlag(WikiFlag.build, wikiDir: wiki, dataDir: data, now: now),
        isTrue);

    expect(File('$wiki/.build-request').readAsStringSync(),
        now.toIso8601String());
    expect(File('$data/wiki-build.request').existsSync(), isFalse);
    expect(wikiFlagQueued(WikiFlag.build, dataDir: data), isFalse);
    expect(wikiFlagPending(WikiFlag.build, wikiDir: wiki, dataDir: data),
        isTrue);
  });

  test('a read-only wiki checkout queues the flag for the host watcher', () {
    final readOnly = '${root.path}/read-only-wiki';

    expect(
        requestWikiFlag(WikiFlag.fishRefresh,
            wikiDir: readOnly, dataDir: data),
        isTrue);

    expect(File('$data/wiki-fish-refresh.request').existsSync(), isTrue);
    expect(File('$readOnly/.fish-refresh-request').existsSync(), isFalse);
    expect(wikiFlagQueued(WikiFlag.fishRefresh, dataDir: data), isTrue);
    expect(wikiFlagPending(WikiFlag.fishRefresh, wikiDir: readOnly, dataDir: data),
        isTrue);
    expect(wikiFlagPending(WikiFlag.build, wikiDir: readOnly, dataDir: data),
        isFalse);
  });

  test('nowhere to write is reported, not thrown', () {
    expect(
        requestWikiFlag(WikiFlag.build,
            wikiDir: '${root.path}/missing-wiki',
            dataDir: '${root.path}/missing-data'),
        isFalse);
  });

  test('the names match the ones the builder and the watcher look for', () {
    // build-loop.sh (the wiki builder) and deploy-watcher.sh hard-code these.
    expect(WikiFlag.build.wikiName, '.build-request');
    expect(WikiFlag.fishRefresh.wikiName, '.fish-refresh-request');
    final watcher = File('deploy-watcher.sh').readAsStringSync();
    for (final flag in WikiFlag.values) {
      expect(watcher, contains('\$DATA_DIR/${flag.relayName}'));
      expect(watcher, contains('flag=${flag.wikiName}'));
    }
  });
}

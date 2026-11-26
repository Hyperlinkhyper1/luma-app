import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/cs2_heatmap.dart';
import 'package:luma_sync_server/cs2_replay.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _digest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// Stands in for the Go parser: records which file it was handed, checks the
/// replay really is on disk while it runs, then answers like the real one.
const _fakeParser = r'''
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final [record, mode, replay] = args;
  File(record).writeAsStringSync(replay);
  if (!File(replay).existsSync()) exit(3);
  if (mode == 'fail') exit(1);
  stdout.write(jsonEncode({
    'map': 'de_mirage',
    'blocks': ['ab'],
    'digest': '%DIGEST%',
    'heat': [[100, 200, 2], [110, 210, 2], [-500, 900, 3], [5000, 5000, 3]],
  }));
}
''';

void main() {
  late Directory temp;
  late File script;
  late File record;
  late Directory scratchRoot;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cs2-replay-test-');
    script = File('${temp.path}/fake_parser.dart')
      ..writeAsStringSync(_fakeParser.replaceFirst('%DIGEST%', _digest));
    record = File('${temp.path}/record.txt');
    scratchRoot = Directory('${temp.path}/scratch');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Cs2ReplayImporter importer(String mode) => Cs2ReplayImporter(
        Platform.resolvedExecutable,
        arguments: [script.path, record.path, mode],
        scratchRoot: scratchRoot,
      );

  Request upload() => Request(
        'POST',
        Uri.parse('http://localhost/admin/databases/cs2/replay?name=m.dem'),
        headers: {'content-type': 'application/octet-stream'},
        body: utf8.encode('PBDEMS2\x00 not really a demo'),
      );

  void expectReplayGone() {
    final path = record.readAsStringSync();
    expect(path, startsWith(scratchRoot.path));
    expect(File(path).existsSync(), isFalse);
    expect(scratchRoot.listSync(), isEmpty);
  }

  test('deletes the replay before the extracted data is stored', () async {
    late bool replayExistedDuringAccept;
    late Cs2Heatmap heat;
    final response = await importer('ok').import(upload(), (match, digest, h) {
      replayExistedDuringAccept = File(record.readAsStringSync()).existsSync();
      heat = h;
      expect(match.map, 'de_mirage');
      expect(digest, _digest);
      return Response.ok('staged');
    });

    expect(response.statusCode, 200);
    expect(replayExistedDuringAccept, isFalse);
    expectReplayGone();
    expect(heat.samples, 4);
    expect(heat.replays, 1);
  });

  test('deletes the replay when the parser rejects it', () async {
    final response = await importer('fail')
        .import(upload(), (_, __, ___) => fail('should not accept'));

    expect(response.statusCode, 422);
    expectReplayGone();
  });

  test('deletes the replay when storing the result fails', () async {
    await expectLater(
      importer('ok').import(upload(), (_, __, ___) => throw StateError('disk')),
      throwsStateError,
    );
    expectReplayGone();
  });

  test('sweeps replays a crash left behind on startup', () {
    final stale = Directory('${scratchRoot.path}/replay-old')
      ..createSync(recursive: true);
    File('${stale.path}/replay').writeAsStringSync('left over');

    importer('ok');

    expect(scratchRoot.listSync(), isEmpty);
  });

  group('Cs2Heatmap', () {
    test('bins samples into cells per side', () {
      final heat = Cs2Heatmap.fromSamples([
        [10, 10, 2],
        [60, 63, 2],
        [10, 10, 3],
        [-1, -64, 3],
      ]);
      final cells = {
        for (final cell in heat.toJson()['cells'] as List)
          ((cell as List)[0], cell[1]): [cell[2], cell[3]],
      };
      expect(cells, {
        (0, 0): [2, 1],
        (-1, -1): [0, 1],
      });
      expect(heat.samples, 4);
    });

    test('rejects malformed samples', () {
      for (final bad in [
        'nope',
        [
          [1, 2]
        ],
        [
          [1, 2, 1]
        ],
        [
          [1.5, 2, 2]
        ],
        [
          [100000, 0, 3]
        ],
      ]) {
        expect(() => Cs2Heatmap.fromSamples(bad), throwsFormatException,
            reason: '$bad');
      }
    });

    test('store accumulates replays per map and survives a restart',
        () async {
      final store = Cs2HeatmapStore(temp.path);
      await store.add(
          'de_mirage',
          Cs2Heatmap.fromSamples([
            [0, 0, 2],
          ]));
      await store.add(
          'de_mirage',
          Cs2Heatmap.fromSamples([
            [0, 0, 3],
            [640, 0, 2],
          ]));
      await store.add('de_nuke', Cs2Heatmap.fromSamples(const []));

      final reloaded = Cs2HeatmapStore(temp.path);
      expect(reloaded.samplesByMap, {'de_mirage': 3});
      final mirage = reloaded.describe('de_mirage');
      expect(mirage['replays'], 2);
      expect(mirage['name'], 'Mirage');
      expect(
          (mirage['cells'] as List).map((cell) => (cell as List).join(',')),
          unorderedEquals(['0,0,1,1', '10,0,1,0']));
    });
  });
}

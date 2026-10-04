import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/world/world_conversion.dart';
import 'package:luma/features/converter/world/world_converter_service_io.dart';

void main() {
  test(
    'inspect accepts a quoted .mcworld path and reads the extracted world',
    () async {
      final root = await Directory.systemTemp.createTemp('luma-world-archive-');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/resort - Kopiëren.mcworld');
      final bytes = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile('level.dat', 5, [1, 2, 3, 4, 5]))
          ..addFile(ArchiveFile('db/CURRENT', 3, [6, 7, 8])),
      );
      await file.writeAsBytes(bytes);
      final service = WorldConverterService(
        worker: (args) async {
          expect(await File('${args[1]}/level.dat').readAsBytes(), [
            1,
            2,
            3,
            4,
            5,
          ]);
          expect(await File('${args[1]}/db/CURRENT').readAsBytes(), [6, 7, 8]);
          return const WorldCensus(
            edition: WorldEdition.bedrock,
            entities: [],
            localPlayer: false,
            remotePlayers: 0,
            version: [1, 21, 120],
          );
        },
      );
      expect(
        (await service.inspect('"${file.path}"')).edition,
        WorldEdition.bedrock,
      );
      expect(await file.readAsBytes(), bytes);
    },
  );
  test(
    'convert a wrapped .zip world and restore its archived statistics',
    () async {
      final root = await Directory.systemTemp.createTemp('luma-world-archive-');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/resort.zip');
      final bytes = ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile('resort/level.dat', 1, [1]))
          ..addFile(ArchiveFile('resort/db/CURRENT', 1, [2]))
          ..addFile(
            ArchiveFile('resort/luma-java-statistics/player.json', 2, [
              123,
              125,
            ]),
          ),
      );
      await file.writeAsBytes(bytes);
      final service = WorldConverterService(
        worker: (args) async {
          if (args.first == 'scan') {
            return const WorldCensus(
              edition: WorldEdition.bedrock,
              entities: [],
              localPlayer: false,
              remotePlayers: 0,
              version: [1, 21, 120],
              warnings: ['Normalized repeated index references.'],
            );
          }
          expect(await File('${args[1]}/db/CURRENT').readAsBytes(), [2]);
          await Directory(args[2]).create();
          await File('${args[2]}/level.dat').writeAsBytes([3]);
          return const WorldCensus(
            edition: WorldEdition.java,
            entities: [],
            localPlayer: false,
            remotePlayers: 0,
            version: 4556,
          );
        },
      );
      final result = await service.convert(
        source: '"${file.path}"',
        destination: '${root.path}/output',
        options: const WorldConversionOptions(
          target: WorldTarget(WorldEdition.java, '1.21.10'),
        ),
      );
      expect(
        await File('${result.path}/stats/player.json').readAsString(),
        '{}',
      );
      expect(result.notes, contains('Normalized repeated index references.'));
      expect(await file.readAsBytes(), bytes);
      expect(await root.list().length, 2);
    },
  );
  test(
    'archive paths cannot escape staging and ambiguous worlds are refused',
    () async {
      final root = await Directory.systemTemp.createTemp('luma-world-archive-');
      addTearDown(() => root.delete(recursive: true));
      for (final name in [
        '../escaped.dat',
        r'C:\escaped.dat',
        '/escaped.dat',
        'second/level.dat',
      ]) {
        final file = File('${root.path}/invalid.mcworld');
        await file.writeAsBytes(
          ZipEncoder().encode(
            Archive()
              ..addFile(ArchiveFile('level.dat', 1, [1]))
              ..addFile(ArchiveFile(name, 1, [2])),
          ),
        );
        final service = WorldConverterService(
          worker: (_) async =>
              throw StateError('Invalid archive reached the worker'),
        );
        await expectLater(
          service.convert(
            source: file.path,
            destination: '${root.path}/output',
            options: const WorldConversionOptions(
              target: WorldTarget(WorldEdition.java, '1.21.10'),
            ),
          ),
          throwsFormatException,
        );
        expect(await Directory('${root.path}/output').exists(), false);
        expect(await root.list().length, 1);
      }
      expect(
        worldSourceName(r'"C:\Downloads\resort - Kopiëren.mcworld"'),
        'resort - Kopiëren',
      );
    },
  );
}

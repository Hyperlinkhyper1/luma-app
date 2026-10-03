import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/world/world_conversion.dart';
import 'package:luma/features/converter/world/world_converter_service_io.dart';

WorldCensus census(
  List<WorldEntityRecord> entities, {
  bool player = true,
  int remote = 0,
  WorldEdition edition = WorldEdition.java,
}) => WorldCensus(
  edition: edition,
  entities: entities,
  localPlayer: player,
  remotePlayers: remote,
  version: edition == WorldEdition.java ? 4556 : [1, 21, 120],
);
const cow = WorldEntityRecord('minecraft:cow', 0, [2, 64, 2]);
const options = WorldConversionOptions(
  target: WorldTarget(WorldEdition.bedrock, '1.21.120'),
);

void main() {
  test('catalog includes historical and newest actual release schemas', () {
    expect(WorldTarget.supported.length, 124);
    expect(WorldTarget.latest(WorldEdition.java).version, '26.3.0');
    expect(WorldTarget.latest(WorldEdition.bedrock).version, '1.26.60');
    expect(const WorldTarget(WorldEdition.java, '26.3.0').savedVersion, 5017);
    expect(const WorldTarget(WorldEdition.java, '1.8.8').savedVersion, 0);
    expect(const WorldTarget(WorldEdition.java, '1.21.11').savedVersion, 4671);
    expect(
      const WorldTarget(WorldEdition.bedrock, '1.26.60').format,
      'BEDROCK_1_26_60',
    );
  });
  test(
    'verification uses the selected version rather than the old fixed version',
    () {
      final source = census([cow]);
      final output = WorldCensus(
        edition: WorldEdition.java,
        entities: [cow],
        localPlayer: true,
        remotePlayers: 0,
        version: 5017,
      );
      final options = WorldConversionOptions(
        target: WorldTarget.latest(WorldEdition.java),
      );
      verifyWorldConversion(source, output, options);
      expect(
        () => verifyWorldConversion(source, census([cow]), options),
        throwsFormatException,
      );
    },
  );
  test('rejects a successful engine result that lost an entity', () {
    expect(
      () => verifyWorldConversion(
        census([cow]),
        census([], edition: WorldEdition.bedrock),
        options,
      ),
      throwsFormatException,
    );
  });
  test(
    'matching records cannot mask entities absent from the selected release',
    () {
      final entity = WorldEntityRecord('minecraft:armadillo', 0, [2, 64, 2]);
      expect(
        () => verifyWorldEntityTarget(
          census([entity]),
          const WorldTarget(WorldEdition.java, '1.20.4'),
        ),
        throwsFormatException,
      );
      verifyWorldEntityTarget(
        census([entity]),
        const WorldTarget(WorldEdition.java, '1.20.5'),
      );
      final bees = census([
        WorldEntityRecord('minecraft:bee@hive', 0, [2, 64, 2]),
      ]);
      expect(
        () => verifyWorldEntityTarget(
          bees,
          const WorldTarget(WorldEdition.java, '1.14.4'),
        ),
        throwsFormatException,
      );
      verifyWorldEntityTarget(
        bees,
        const WorldTarget(WorldEdition.java, '1.15.2'),
      );
    },
  );
  test('equal counts cannot mask changed kinds, dimensions or positions', () {
    for (final replacement in [
      const WorldEntityRecord('minecraft:zombie', 0, [2, 64, 2]),
      const WorldEntityRecord('minecraft:cow', 1, [2, 64, 2]),
      const WorldEntityRecord('minecraft:cow', 0, [20, 64, 2]),
    ]) {
      expect(
        () => verifyWorldConversion(
          census([cow]),
          census([replacement], edition: WorldEdition.bedrock),
          options,
        ),
        throwsFormatException,
      );
    }
  });
  test('cannot match two source entities to one saved entity', () {
    expect(
      () => verifyWorldConversion(
        census([cow, cow]),
        census([cow], edition: WorldEdition.bedrock),
        options,
      ),
      throwsFormatException,
    );
  });
  test('accepts edition type aliases and hanging position offsets', () {
    verifyWorldConversion(
      census([
        const WorldEntityRecord('minecraft:villager', 0, [2, 64, 2]),
      ]),
      census([
        const WorldEntityRecord('minecraft:villager_v2', 0, [2, 64.5, 2]),
      ], edition: WorldEdition.bedrock),
      options,
    );
  });
  test('does not claim unmapped additional players were converted', () {
    expect(
      () => verifyWorldConversion(
        census([], remote: 1),
        census([], edition: WorldEdition.bedrock),
        options,
      ),
      throwsFormatException,
    );
    expect(
      () => verifyWorldConversion(
        census([]),
        census([], player: false, edition: WorldEdition.bedrock),
        options,
      ),
      throwsFormatException,
    );
  });
  test('unchecked entities and players must actually be absent', () {
    const excluded = WorldConversionOptions(
      target: WorldTarget(WorldEdition.bedrock, '1.21.120'),
      entities: false,
      players: false,
    );
    expect(
      () => verifyWorldConversion(
        census([cow]),
        census([cow], player: false, edition: WorldEdition.bedrock),
        excluded,
      ),
      throwsFormatException,
    );
    verifyWorldConversion(
      census([cow]),
      census([], player: false, edition: WorldEdition.bedrock),
      excluded,
    );
  });
  test('wrong saved version fails verification', () {
    const wrong = WorldCensus(
      edition: WorldEdition.bedrock,
      entities: [],
      localPlayer: true,
      remotePlayers: 0,
      version: [1, 21, 130],
    );
    expect(
      () => verifyWorldConversion(census([]), wrong, options),
      throwsFormatException,
    );
  });
  test(
    'failed entity audit never publishes the output or modifies source',
    () async {
      final root = await Directory.systemTemp.createTemp('luma-world-test-');
      addTearDown(() => root.delete(recursive: true));
      final source = await Directory('${root.path}/source').create();
      final original = File('${source.path}/level.dat');
      await original.writeAsString('source bytes');
      final service = WorldConverterService(
        worker: (args) async {
          if (args.first == 'scan') return census([cow]);
          await Directory(args[2]).create();
          await File('${args[2]}/level.dat').writeAsString('converted bytes');
          return census([], edition: WorldEdition.bedrock);
        },
      );
      await expectLater(
        service.convert(
          source: source.path,
          destination: '${root.path}/result',
          options: options,
        ),
        throwsFormatException,
      );
      expect(await original.readAsString(), 'source bytes');
      expect(await Directory('${root.path}/result').exists(), false);
      expect(await root.list().length, 1);
    },
  );
  test(
    'archives and restores Java statistics; unchecked stats are absent',
    () async {
      final root = await Directory.systemTemp.createTemp('luma-world-stats-');
      addTearDown(() => root.delete(recursive: true));
      final source = await Directory('${root.path}/source').create();
      await File('${source.path}/level.dat').writeAsString('source');
      await Directory('${source.path}/stats').create();
      await File(
        '${source.path}/stats/player.json',
      ).writeAsString('{"stats":{"walk":42}}');
      var from = WorldEdition.java;
      final service = WorldConverterService(
        worker: (args) async {
          if (args.first == 'scan') return census([], edition: from);
          await Directory(args[2]).create();
          await File('${args[2]}/level.dat').writeAsString('converted');
          return census([], edition: WorldEdition.values.byName(args[3]));
        },
      );
      final bedrock = await service.convert(
        source: source.path,
        destination: '${root.path}/bedrock',
        options: options,
      );
      expect(
        await File(
          '${bedrock.path}/luma-java-statistics/player.json',
        ).readAsString(),
        '{"stats":{"walk":42}}',
      );
      from = WorldEdition.bedrock;
      final java = await service.convert(
        source: bedrock.path,
        destination: '${root.path}/java',
        options: const WorldConversionOptions(
          target: WorldTarget(WorldEdition.java, '1.21.10'),
        ),
      );
      expect(
        await File('${java.path}/stats/player.json').readAsString(),
        '{"stats":{"walk":42}}',
      );
      from = WorldEdition.java;
      final excluded = await service.convert(
        source: source.path,
        destination: '${root.path}/excluded',
        options: const WorldConversionOptions(
          target: WorldTarget(WorldEdition.bedrock, '1.21.120'),
          statistics: false,
        ),
      );
      expect(
        await Directory('${excluded.path}/luma-java-statistics').exists(),
        false,
      );
    },
  );
  test(
    'legacy Bedrock refuses selected records before invoking an engine',
    () async {
      final root = await Directory.systemTemp.createTemp('luma-world-legacy-');
      addTearDown(() => root.delete(recursive: true));
      final source = await Directory('${root.path}/source').create();
      await File('${source.path}/level.dat').writeAsString('source');
      final service = WorldConverterService(
        worker: (args) async {
          expect(args.first, 'scan');
          return census([cow]);
        },
        versionWorker: (_, _, _, _) async =>
            fail('Unsafe record conversion invoked'),
      );
      await expectLater(
        service.convert(
          source: source.path,
          destination: '${root.path}/result',
          options: const WorldConversionOptions(
            target: WorldTarget(WorldEdition.bedrock, '1.12.0'),
          ),
        ),
        throwsFormatException,
      );
      expect(await Directory('${root.path}/result').exists(), false);
      expect(await File('${source.path}/level.dat').readAsString(), 'source');
      expect(await root.list().length, 1);
    },
  );
}

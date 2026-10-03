import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:luma/features/converter/schematic/nbt.dart';
import 'package:luma/features/converter/world/world_conversion.dart';
import 'package:luma/features/converter/world/world_converter_service_io.dart';

NbtList doubles(List<double> values) =>
    NbtList.of(values.map(NbtDouble.new).toList());
NbtIntArray uuid(int n) => NbtIntArray(Int32List.fromList([0, 0, 1, n]));
NbtCompound mob(
  String id,
  int n,
  double x, {
  Map<String, NbtTag> extra = const {},
}) => NbtCompound({
  'id': NbtString('minecraft:$id'),
  'UUID': uuid(n),
  'Pos': doubles([x, 64, 4]),
  'Motion': doubles([0, 0, 0]),
  'Rotation': NbtList.of([const NbtFloat(0), const NbtFloat(0)]),
  'Health': const NbtFloat(20),
  'Air': const NbtShort(300),
  'Fire': const NbtShort(-1),
  'OnGround': const NbtByte(1),
  'PersistenceRequired': const NbtByte(1),
  ...extra,
});
void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  final executable = args.isEmpty
      ? 'build/world_converter/Release/luma-world-converter.exe'
      : args.single;
  final root = await Directory('.dart_tool').createTemp('world-round-trip-');
  try {
    final source = await Directory('${root.path}/source').create();
    final player = NbtCompound({
      'UUID': uuid(100),
      'Pos': doubles([8, 64, 8]),
      'Motion': doubles([0, 0, 0]),
      'Rotation': NbtList.of([const NbtFloat(0), const NbtFloat(0)]),
      'Dimension': const NbtString('minecraft:overworld'),
      'Health': const NbtFloat(20),
      'foodLevel': const NbtInt(20),
      'Inventory': NbtList.of([
        NbtCompound({
          'Slot': const NbtByte(0),
          'id': const NbtString('minecraft:diamond'),
          'count': const NbtInt(3),
        }),
      ]),
    });
    final data = NbtCompound({
      'DataVersion': const NbtInt(4556),
      'LevelName': const NbtString('Luma fixture'),
      'Version': NbtCompound({
        'Id': const NbtInt(4556),
        'Name': const NbtString('1.21.10'),
        'Snapshot': const NbtByte(0),
      }),
      'SpawnX': const NbtInt(8),
      'SpawnY': const NbtInt(64),
      'SpawnZ': const NbtInt(8),
      'Time': const NbtLong(0),
      'DayTime': const NbtLong(0),
      'GameType': const NbtInt(0),
      'Difficulty': const NbtByte(2),
      'WorldGenSettings': NbtCompound({
        'seed': const NbtLong(123),
        'generate_features': const NbtByte(1),
      }),
      'Player': player,
    });
    final levelBytes = Nbt.write(NamedTag('', NbtCompound({'Data': data})));
    await File('${source.path}/level.dat').writeAsBytes(levelBytes);
    await Directory('${source.path}/region').create();
    final chunk = NbtCompound({
      'DataVersion': const NbtInt(4556),
      'xPos': const NbtInt(0),
      'zPos': const NbtInt(0),
      'yPos': const NbtInt(-4),
      'Status': const NbtString('minecraft:full'),
      'LastUpdate': const NbtLong(0),
      'InhabitedTime': const NbtLong(0),
      'sections': NbtList.of([
        for (var y = -4; y < 20; y++)
          NbtCompound({
            'Y': NbtByte(y),
            'block_states': NbtCompound({
              'palette': NbtList.of([
                NbtCompound({
                  'Name': NbtString(
                    y == 3 ? 'minecraft:stone' : 'minecraft:air',
                  ),
                }),
              ]),
            }),
            'biomes': NbtCompound({
              'palette': NbtList.of([const NbtString('minecraft:plains')]),
            }),
          }),
      ]),
      'block_entities': NbtList.of([], emptyType: 10),
      'block_ticks': NbtList.of([], emptyType: 10),
      'fluid_ticks': NbtList.of([], emptyType: 10),
    });
    await File('${source.path}/region/r.0.0.mca').writeAsBytes(region(chunk));
    await Directory('${source.path}/entities').create();
    final entities = [
      mob('cow', 1, 2),
      mob('cow', 2, 3),
      mob(
        'villager',
        3,
        4,
        extra: {
          'VillagerData': NbtCompound({
            'type': const NbtString('minecraft:plains'),
            'profession': const NbtString('minecraft:farmer'),
            'level': const NbtInt(2),
          }),
        },
      ),
      mob(
        'wolf',
        4,
        5,
        extra: {'Owner': uuid(100), 'CollarColor': const NbtByte(11)},
      ),
      mob('armor_stand', 5, 6),
      mob(
        'oak_boat',
        6,
        7,
        extra: {
          'Passengers': NbtList.of([mob('chicken', 7, 7)]),
        },
      ),
      mob(
        'item_frame',
        8,
        9,
        extra: {
          'Facing': const NbtByte(2),
          'TileX': const NbtInt(9),
          'TileY': const NbtInt(64),
          'TileZ': const NbtInt(4),
        },
      ),
    ];
    chunk.values['block_entities'] = NbtList.of([
      NbtCompound({
        'id': const NbtString('minecraft:beehive'),
        'x': const NbtInt(1),
        'y': const NbtInt(64),
        'z': const NbtInt(1),
        'bees': NbtList.of([
          NbtCompound({
            'entity_data': NbtCompound({
              'id': const NbtString('minecraft:bee'),
              'Health': const NbtFloat(10),
            }),
            'ticks_in_hive': const NbtInt(1),
            'min_ticks_in_hive': const NbtInt(600),
          }),
        ]),
      }),
    ]);
    final sections = chunk.list('sections')!;
    final section = sections.items[8] as NbtCompound;
    final states = section.compound('block_states')!;
    states.values['palette'] = NbtList.of([
      NbtCompound({'Name': const NbtString('minecraft:air')}),
      NbtCompound({'Name': const NbtString('minecraft:beehive')}),
    ]);
    final packed = Int64List(256);
    packed[17 ~/ 16] = 1 << ((17 % 16) * 4);
    states.values['data'] = NbtLongArray(packed);
    await File('${source.path}/region/r.0.0.mca').writeAsBytes(region(chunk));
    await File('${source.path}/entities/r.0.0.mca').writeAsBytes(
      region(
        NbtCompound({
          'DataVersion': const NbtInt(4556),
          'Position': NbtIntArray(Int32List.fromList([0, 0])),
          'Entities': NbtList.of(entities),
        }),
      ),
    );
    await Directory('${source.path}/stats').create();
    await File(
      '${source.path}/stats/player.json',
    ).writeAsString('{"stats":{"minecraft:custom":{"minecraft:jump":42}}}');
    final service = WorldConverterService(
      worker: (arguments) async {
        final result = await Process.run(
          File(executable).absolute.path,
          arguments,
        );
        if (result.exitCode != 0) {
          throw FormatException(result.stderr.toString().trim());
        }
        final payload = const LineSplitter()
            .convert(result.stdout.toString())
            .lastWhere((s) => s.startsWith('{'));
        return WorldCensus.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        );
      },
    );
    final before = await service.inspect(source.path);
    check(
      before.entities.length == 9,
      'Source census must include both cows, passengers and item frame',
    );
    final bedrock = await service.convert(
      source: source.path,
      destination: '${root.path}/bedrock',
      options: const WorldConversionOptions(
        target: WorldTarget(WorldEdition.bedrock, '1.21.120'),
      ),
    );
    final java = await service.convert(
      source: bedrock.path,
      destination: '${root.path}/java',
      options: const WorldConversionOptions(
        target: WorldTarget(WorldEdition.java, '1.21.10'),
      ),
    );
    final after = await service.inspect(java.path);
    check(after.entities.length >= 9, 'Round trip dropped entities');
    check(after.localPlayer, 'Round trip dropped local player');
    final savedPlayer = Nbt.read(
      Uint8List.fromList(await File('${java.path}/level.dat').readAsBytes()),
    ).asCompound.compound('Data')!.compound('Player')!;
    check(
      savedPlayer.intArray('UUID')!.toString() == uuid(100).value.toString(),
      'Original player UUID was not preserved',
    );
    final inventory = savedPlayer.list('Inventory')!;
    final diamond = inventory.items.cast<NbtCompound>().firstWhere(
      (item) => item.stringValue('id') == 'minecraft:diamond',
    );
    check(
      diamond.intValue('count') == 3,
      'Player inventory did not round trip',
    );
    check(
      await File('${java.path}/stats/player.json').readAsString() ==
          await File('${source.path}/stats/player.json').readAsString(),
      'Statistics did not round trip',
    );
    check(
      base64Encode(await File('${source.path}/level.dat').readAsBytes()) ==
          base64Encode(levelBytes),
      'Source world changed',
    );
    final excluded = await service.convert(
      source: source.path,
      destination: '${root.path}/excluded',
      options: const WorldConversionOptions(
        target: WorldTarget(WorldEdition.bedrock, '1.21.120'),
        entities: false,
        players: false,
        statistics: false,
      ),
    );
    check(excluded.entityCount == 0, 'Excluded entities remain');
    check(
      !(await service.inspect(excluded.path)).localPlayer,
      'Excluded player remains',
    );
    entities.add(mob('luma:unsupported', 999, 10));
    // A namespaced entity unknown to the engine must fail instead of disappearing.
    entities.last.values['id'] = const NbtString('luma:unsupported');
    await File('${source.path}/entities/r.0.0.mca').writeAsBytes(
      region(
        NbtCompound({
          'DataVersion': const NbtInt(4556),
          'Position': NbtIntArray(Int32List.fromList([0, 0])),
          'Entities': NbtList.of(entities),
        }),
      ),
    );
    try {
      await service.convert(
        source: source.path,
        destination: '${root.path}/unsupported',
        options: const WorldConversionOptions(
          target: WorldTarget(WorldEdition.bedrock, '1.21.120'),
        ),
      );
      throw StateError('Unknown entity conversion must fail');
    } on FormatException catch (e) {
      check(
        e.message.contains('luma:unsupported'),
        'Failure must identify the missing entity',
      );
      check(
        !await Directory('${root.path}/unsupported').exists(),
        'Failed entity conversion published output',
      );
    }
    stdout.writeln(
      'PASS: Java → Bedrock → Java: entities, passengers, hive occupants, player UUID/inventory, stats, exclusions, unsupported-entity rejection and source preservation.',
    );
  } finally {
    final resolved = await root.resolveSymbolicLinks();
    check(
      resolved.startsWith(Directory('.dart_tool').absolute.path),
      'Unsafe fixture cleanup path',
    );
    await root.delete(recursive: true);
  }
}

Uint8List region(NbtCompound chunk) {
  final compressed = Nbt.write(
    NamedTag('', chunk),
    compression: NbtCompression.zlib,
  );
  final sectors = (compressed.length + 5 + 4095) ~/ 4096;
  final bytes = Uint8List(8192 + sectors * 4096);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, (2 << 8) | sectors, Endian.big);
  data.setUint32(8192, compressed.length + 1, Endian.big);
  bytes[8196] = 2;
  bytes.setRange(8197, 8197 + compressed.length, compressed);
  return bytes;
}

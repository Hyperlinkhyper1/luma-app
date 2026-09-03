import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/schematic/bedrock_blocks.dart';
import 'package:luma/features/converter/schematic/block_colors.dart';
import 'package:luma/features/converter/schematic/legacy_blocks.dart';
import 'package:luma/features/converter/schematic/nbt.dart';
import 'package:luma/features/converter/schematic/schematic_model.dart';
import 'package:luma/features/converter/schematic/schematic_service.dart';

/// Builds a small but awkward test volume: a palette size that forces
/// Litematica's packed entries to straddle long boundaries, and a shape whose
/// three axes are all different so an axis-order mistake cannot hide.
Schematic buildSample({int width = 5, int height = 3, int length = 7}) {
  final builder = PaletteBuilder();
  final stone = builder.add(BlockState('minecraft:stone'));
  final planks = builder.add(BlockState('minecraft:oak_planks'));
  final glass = builder.add(BlockState('minecraft:glass'));
  final stairs = builder.add(
    BlockState('minecraft:oak_stairs', const {
      'facing': 'north',
      'half': 'bottom',
    }),
  );

  final blocks = Uint16List(width * height * length);
  for (var y = 0; y < height; y++) {
    for (var z = 0; z < length; z++) {
      for (var x = 0; x < width; x++) {
        final i = x + z * width + y * width * length;
        if (y == 0) {
          blocks[i] = stone;
        } else if (x == 0 && z == 0) {
          blocks[i] = stairs;
        } else if ((x + z) % 3 == 0) {
          blocks[i] = planks;
        } else if ((x + z) % 5 == 0) {
          blocks[i] = glass;
        }
      }
    }
  }

  return Schematic(
    width: width,
    height: height,
    length: length,
    palette: builder.build(),
    blocks: blocks,
    name: 'Test build',
    author: 'luma tests',
  );
}

void main() {
  group('NBT codec', () {
    test('round-trips every tag type big-endian', () {
      final root = NbtCompound.empty()
        ..['byte'] = const NbtByte(-7)
        ..['short'] = const NbtShort(-30000)
        ..['int'] = const NbtInt(123456789)
        ..['long'] = const NbtLong(-9007199254740993)
        ..['float'] = const NbtFloat(0.5)
        ..['double'] = const NbtDouble(3.25)
        ..['string'] = const NbtString('héllo ✓')
        ..['bytes'] = NbtByteArray(Int8List.fromList([1, -2, 3]))
        ..['ints'] = NbtIntArray(Int32List.fromList([9, -9, 0]))
        ..['longs'] = NbtLongArray(Int64List.fromList([1 << 40, -1]))
        ..['list'] = const NbtList(3, [NbtInt(1), NbtInt(2)])
        ..['nested'] = (NbtCompound.empty()..['x'] = const NbtInt(5));

      final bytes = Nbt.write(NamedTag('Root', root));
      final back = Nbt.read(bytes);

      expect(back.name, 'Root');
      final c = back.asCompound;
      expect(c.intValue('byte'), -7);
      expect(c.intValue('short'), -30000);
      expect(c.intValue('int'), 123456789);
      expect(c.intValue('long'), -9007199254740993);
      expect((c['float']! as NbtFloat).value, 0.5);
      expect((c['double']! as NbtDouble).value, 3.25);
      expect(c.stringValue('string'), 'héllo ✓');
      expect(c.byteArray('bytes'), [1, -2, 3]);
      expect(c.intArray('ints'), [9, -9, 0]);
      expect(c.longArray('longs'), [1 << 40, -1]);
      expect(c.list('list')!.items.length, 2);
      expect(c.compound('nested')!.intValue('x'), 5);
    });

    test('round-trips little-endian, uncompressed', () {
      final root = NbtCompound.empty()
        ..['format_version'] = const NbtInt(1)
        ..['name'] = const NbtString('bedrock');

      final bytes = Nbt.write(
        NamedTag('', root),
        endian: Endian.little,
        compression: NbtCompression.none,
      );
      // Uncompressed little-endian starts with the raw compound tag.
      expect(bytes[0], 0x0A);

      final back = Nbt.read(bytes, endian: Endian.little).asCompound;
      expect(back.intValue('format_version'), 1);
      expect(back.stringValue('name'), 'bedrock');
    });

    test('rejects a file that is not NBT', () {
      expect(
        () => Nbt.read(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('legacy block ids', () {
    test('maps well-known ids to modern states', () {
      expect(LegacyBlocks.fromLegacy(1, 0)!.name, 'minecraft:stone');
      expect(LegacyBlocks.fromLegacy(1, 1)!.name, 'minecraft:granite');
      expect(LegacyBlocks.fromLegacy(5, 2)!.name, 'minecraft:birch_planks');
      expect(LegacyBlocks.fromLegacy(35, 14)!.name, 'minecraft:red_wool');
      expect(LegacyBlocks.fromLegacy(0, 0)!.isAir, isTrue);
    });

    test('keeps stair orientation', () {
      final stair = LegacyBlocks.fromLegacy(53, 4 | 2)!;
      expect(stair.name, 'minecraft:oak_stairs');
      expect(stair.properties['facing'], 'south');
      expect(stair.properties['half'], 'top');
    });

    test('inverts back to the same id and data', () {
      for (final pair in const [(1, 0), (5, 3), (35, 9), (53, 6), (98, 2)]) {
        final state = LegacyBlocks.fromLegacy(pair.$1, pair.$2)!;
        final back = LegacyBlocks.toLegacy(state);
        expect(back, isNotNull, reason: '$state should map back');
        expect(back!.exact, isTrue, reason: '$state should map back exactly');
        expect((back.id, back.data), pair);
      }
    });

    test('reports blocks that post-date the flattening', () {
      expect(LegacyBlocks.toLegacy(BlockState('minecraft:deepslate')), isNull);
    });
  });

  group('format round trips', () {
    final sample = buildSample();

    for (final format in [
      SchematicFormat.sponge,
      SchematicFormat.litematic,
      SchematicFormat.structure,
    ]) {
      test('${format.label} preserves every block', () {
        final export = SchematicService.save(sample, format);
        final back = SchematicService.load(
          export.bytes,
          'build.${format.extension}',
        );

        expect(back.width, sample.width);
        expect(back.height, sample.height);
        expect(back.length, sample.length);
        expect(back.sourceFormat, format);

        for (var y = 0; y < sample.height; y++) {
          for (var z = 0; z < sample.length; z++) {
            for (var x = 0; x < sample.width; x++) {
              expect(
                back.blockAt(x, y, z).toStateString(),
                sample.blockAt(x, y, z).toStateString(),
                reason: 'block at $x,$y,$z differs',
              );
            }
          }
        }
      });
    }

    test('MCEDIT preserves blocks that existed before 1.13', () {
      final export = SchematicService.save(sample, SchematicFormat.mcedit);
      final back = SchematicService.load(export.bytes, 'build.schematic');

      expect(back.width, sample.width);
      expect(back.height, sample.height);
      expect(back.length, sample.length);
      for (var y = 0; y < sample.height; y++) {
        for (var z = 0; z < sample.length; z++) {
          for (var x = 0; x < sample.width; x++) {
            expect(
              back.blockAt(x, y, z).toStateString(),
              sample.blockAt(x, y, z).toStateString(),
              reason: 'block at $x,$y,$z differs',
            );
          }
        }
      }
    });

    test('MCSTRUCTURE keeps the shape and the recognised blocks', () {
      final export =
          SchematicService.save(sample, SchematicFormat.mcstructure);
      final back = SchematicService.load(export.bytes, 'build.mcstructure');

      expect(back.width, sample.width);
      expect(back.height, sample.height);
      expect(back.length, sample.length);
      expect(back.sourceFormat, SchematicFormat.mcstructure);

      // Bedrock drops some state detail, so compare block ids rather than
      // whole states, and check air stays air so the shape is intact.
      for (var y = 0; y < sample.height; y++) {
        for (var z = 0; z < sample.length; z++) {
          for (var x = 0; x < sample.width; x++) {
            expect(
              back.blockAt(x, y, z).isAir,
              sample.blockAt(x, y, z).isAir,
              reason: 'solidity at $x,$y,$z differs',
            );
            expect(
              back.blockAt(x, y, z).name,
              sample.blockAt(x, y, z).name,
              reason: 'block id at $x,$y,$z differs',
            );
          }
        }
      }
      expect(export.notes, isNotEmpty);
    });

    test('a Litematica palette that forces bit-spanning survives', () {
      // 5 palette entries means 3 bits each, so entries straddle the 64-bit
      // words — the case a naive packer gets wrong.
      final builder = PaletteBuilder();
      final states = [
        for (final name in const [
          'minecraft:stone',
          'minecraft:dirt',
          'minecraft:oak_planks',
          'minecraft:glass',
        ])
          builder.add(BlockState(name)),
      ];
      const width = 9;
      const height = 5;
      const length = 11;
      final blocks = Uint16List(width * height * length);
      for (var i = 0; i < blocks.length; i++) {
        blocks[i] = states[i % states.length];
      }
      final source = Schematic(
        width: width,
        height: height,
        length: length,
        palette: builder.build(),
        blocks: blocks,
      );

      final export =
          SchematicService.save(source, SchematicFormat.litematic);
      final back =
          SchematicService.load(export.bytes, 'packed.litematic');

      for (var i = 0; i < blocks.length; i++) {
        expect(
          back.palette[back.blocks[i]].toStateString(),
          source.palette[source.blocks[i]].toStateString(),
          reason: 'entry $i differs',
        );
      }
    });

    test('converting between every pair of formats keeps the size', () {
      for (final from in SchematicFormat.values) {
        final intermediate = SchematicService.load(
          SchematicService.save(sample, from).bytes,
          'x.${from.extension}',
        );
        for (final to in SchematicFormat.values) {
          final result = SchematicService.save(intermediate, to);
          final back =
              SchematicService.load(result.bytes, 'x.${to.extension}');
          expect(
            [back.width, back.height, back.length],
            [sample.width, sample.height, sample.length],
            reason: '${from.label} to ${to.label} changed the size',
          );
        }
      }
    });
  });

  group('format detection', () {
    test('identifies each format from its bytes, ignoring the name', () {
      final sample = buildSample();
      for (final format in SchematicFormat.values) {
        final bytes = SchematicService.save(sample, format).bytes;
        final loaded = SchematicService.load(bytes, 'mystery.dat');
        expect(loaded.sourceFormat, format);
      }
    });

    test('refuses a file that is not a schematic', () {
      expect(
        () => SchematicService.load(
          Uint8List.fromList(List.filled(64, 0x42)),
          'notes.txt',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Bedrock mapping', () {
    test('renames blocks whose ids differ between editions', () {
      expect(
        BedrockBlocks.toBedrock(BlockState('minecraft:cobweb')).state.name,
        'minecraft:web',
      );
      expect(
        BedrockBlocks.toJava(BlockState('minecraft:web')).state.name,
        'minecraft:cobweb',
      );
    });

    test('translates stair orientation into weirdo_direction and back', () {
      final java = BlockState('minecraft:oak_stairs', const {
        'facing': 'west',
        'half': 'top',
      });
      final bedrock = BedrockBlocks.toBedrock(java).state;
      expect(bedrock.properties['weirdo_direction'], '1');
      expect(bedrock.properties['upside_down_bit'], '1');

      final back = BedrockBlocks.toJava(bedrock).state;
      expect(back.properties['facing'], 'west');
      expect(back.properties['half'], 'top');
    });
  });

  group('block colours', () {
    test('gives known blocks their own colour', () {
      expect(
        BlockColors.of(BlockState('minecraft:gold_block')),
        isNot(BlockColors.of(BlockState('minecraft:stone'))),
      );
    });

    test('derives the dyed families from the dye palette', () {
      expect(
        BlockColors.of(BlockState('minecraft:red_wool')),
        BlockColors.of(BlockState('minecraft:red_carpet')),
      );
      expect(
        BlockColors.of(BlockState('minecraft:lime_concrete')),
        isNot(BlockColors.of(BlockState('minecraft:red_concrete'))),
      );
    });

    test('falls back to a stable colour for unknown blocks', () {
      final first = BlockColors.of(BlockState('minecraft:not_a_real_block'));
      final second = BlockColors.of(BlockState('minecraft:not_a_real_block'));
      final other = BlockColors.of(BlockState('minecraft:also_not_real'));
      expect(first, second);
      expect(first, isNot(other));
    });
  });

  group('guards', () {
    test('refuses an implausibly large volume before allocating', () {
      expect(
        () => guardVolume(4096, 4096, 4096),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses an empty volume', () {
      expect(() => guardVolume(0, 10, 10), throwsA(isA<FormatException>()));
    });

    test('refuses to write the per-position formats at absurd sizes', () {
      // These two list every position as its own tag, so they need a much
      // tighter limit than the packed formats — and the packed ones must
      // still take the same build without complaint.
      final huge = Schematic(
        width: 200,
        height: 200,
        length: 200,
        palette: [BlockState.air, BlockState('minecraft:stone')],
        blocks: Uint16List(200 * 200 * 200),
      );

      for (final format in [
        SchematicFormat.structure,
        SchematicFormat.mcstructure,
      ]) {
        expect(
          () => SchematicService.save(huge, format),
          throwsA(isA<FormatException>()),
          reason: '${format.label} should refuse a build this size',
        );
      }

      for (final format in [
        SchematicFormat.sponge,
        SchematicFormat.litematic,
        SchematicFormat.mcedit,
      ]) {
        expect(
          SchematicService.save(huge, format).bytes,
          isNotEmpty,
          reason: '${format.label} packs its blocks and should cope',
        );
      }
    });
  });

  group('materials', () {
    test('counts blocks, most used first, without air', () {
      final materials = buildSample().materials();
      expect(materials, isNotEmpty);
      expect(materials.first.state.name, 'minecraft:stone');
      for (final m in materials) {
        expect(m.state.isAir, isFalse);
      }
      for (var i = 1; i < materials.length; i++) {
        expect(materials[i - 1].count >= materials[i].count, isTrue);
      }
    });
  });
}

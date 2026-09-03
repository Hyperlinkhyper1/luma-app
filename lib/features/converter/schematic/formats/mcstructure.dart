import 'dart:typed_data';

import '../bedrock_blocks.dart';
import '../nbt.dart';
import '../schematic_model.dart';
import 'nbt_block_state.dart';

/// The Bedrock Edition `.mcstructure` format.
///
/// Three things set it apart from the Java formats: the NBT is little-endian
/// and never compressed, the block array runs in XZY order rather than YZX,
/// and there are two block layers — the second one exists so water can sit in
/// the same cell as a fence or a stair, which is Java's `waterlogged`.
class Mcstructure {
  const Mcstructure._();

  /// Bedrock block-state schema version stamped on new palette entries,
  /// corresponding to 1.21.
  static const int blockVersion = 18168865;

  static Schematic read(NbtCompound root) {
    final size = root.list('size');
    if (size == null || size.items.length < 3) {
      throw const FormatException(
        'This .mcstructure file has no size tag.',
      );
    }
    int axis(int i) => switch (size.items[i]) {
          NbtInt(:final value) => value,
          NbtShort(:final value) => value,
          NbtByte(:final value) => value,
          _ => 0,
        };
    final width = axis(0);
    final height = axis(1);
    final length = axis(2);
    guardVolume(width, height, length);

    final structure = root.compound('structure');
    final indices = structure?.list('block_indices');
    if (structure == null || indices == null || indices.items.isEmpty) {
      throw const FormatException(
        'This .mcstructure file has no block indices.',
      );
    }

    final bedrockPalette = structure
        .compound('palette')
        ?.compound('default')
        ?.list('block_palette');
    if (bedrockPalette == null) {
      throw const FormatException(
        'This .mcstructure file has no block palette.',
      );
    }

    // Translate the Bedrock palette into Java states once, up front.
    final builder = PaletteBuilder();
    final remap = <int>[];
    var approximate = 0;
    final waterIndices = <int>{};
    for (var i = 0; i < bedrockPalette.items.length; i++) {
      final item = bedrockPalette.items[i];
      if (item is! NbtCompound) {
        remap.add(0);
        continue;
      }
      final bedrockState = blockStateFromNbt(
        item,
        nameKey: 'name',
        propertiesKey: 'states',
      );
      if (bedrockState.shortName == 'water' ||
          bedrockState.shortName == 'flowing_water') {
        waterIndices.add(i);
      }
      final converted = BedrockBlocks.toJava(bedrockState);
      if (!converted.exact) approximate++;
      remap.add(builder.add(converted.state));
    }

    final layer0 = _intList(indices.items[0]);
    final layer1 =
        indices.items.length > 1 ? _intList(indices.items[1]) : null;

    final blocks = Uint16List(width * height * length);
    // Interning a waterlogged variant is a palette insert, so remember the
    // ones already made rather than re-deriving them per block.
    final waterloggedVariants = <int, int>{};
    // Bedrock walks X first, then Y, then Z.
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        for (var z = 0; z < length; z++) {
          final source = (x * height + y) * length + z;
          if (source >= layer0.length) continue;
          final value = layer0[source];
          // -1 means "leave whatever is already here".
          if (value < 0 || value >= remap.length) continue;
          var index = remap[value];

          // A water block on the second layer is Java's waterlogged flag.
          if (index != 0 && layer1 != null && source < layer1.length) {
            final second = layer1[source];
            if (second >= 0 && waterIndices.contains(second)) {
              final baseIndex = index;
              index = waterloggedVariants.putIfAbsent(baseIndex, () {
                final base = builder[baseIndex];
                if (base.isAir ||
                    base.properties.containsKey('waterlogged')) {
                  return baseIndex;
                }
                return builder.add(
                  BlockState(base.name, {
                    ...base.properties,
                    'waterlogged': 'true',
                  }),
                );
              });
            }
          }

          blocks[x + z * width + y * width * length] = index;
        }
      }
    }

    final notes = <String>[
      'Bedrock and Java do not share a block vocabulary, so this conversion '
          'is approximate.',
      if (approximate > 0)
        '$approximate palette ${approximate == 1 ? 'entry' : 'entries'} had '
            'properties Java has no equivalent for.',
    ];

    return Schematic(
      width: width,
      height: height,
      length: length,
      palette: builder.build(),
      blocks: blocks,
      sourceFormat: SchematicFormat.mcstructure,
      notes: notes,
    );
  }

  static List<int> _intList(NbtTag tag) {
    if (tag is NbtIntArray) return tag.value;
    if (tag is! NbtList) return const <int>[];
    return [
      for (final item in tag.items)
        switch (item) {
          NbtInt(:final value) => value,
          NbtShort(:final value) => value,
          NbtByte(:final value) => value,
          _ => -1,
        },
    ];
  }

  /// The point past which a Bedrock structure stops being worth writing: the
  /// block indices are a tag per position per layer, and Bedrock itself only
  /// loads 64 blocks per side.
  static const int maxWritableVolume = 2000000;

  static ({Uint8List bytes, List<String> notes}) write(Schematic schematic) {
    if (schematic.volume > maxWritableVolume) {
      throw FormatException(
        'This build is ${schematic.width}×${schematic.height}×'
        '${schematic.length}. A Bedrock structure stores every position in two '
        'index lists, so one that size would be unusably large — and Bedrock '
        'only loads 64 blocks per side. Convert to .litematic or .schem '
        'instead.',
      );
    }

    // Build the Bedrock palette, de-duplicating as we go: several Java states
    // can collapse onto the same Bedrock one once unsupported properties are
    // dropped, and Bedrock rejects a palette with duplicates.
    final bedrockPalette = <BlockState>[];
    final bedrockIndex = <String, int>{};
    final remap = List<int>.filled(schematic.palette.length, 0);
    final waterlogged = List<bool>.filled(schematic.palette.length, false);
    var approximate = 0;

    int intern(BlockState state) {
      final key = state.toStateString();
      final existing = bedrockIndex[key];
      if (existing != null) return existing;
      bedrockPalette.add(state);
      bedrockIndex[key] = bedrockPalette.length - 1;
      return bedrockPalette.length - 1;
    }

    intern(BlockState('minecraft:air'));

    for (var i = 0; i < schematic.palette.length; i++) {
      final java = schematic.palette[i];
      waterlogged[i] = java.properties['waterlogged'] == 'true';
      final converted = BedrockBlocks.toBedrock(java);
      if (!converted.exact) approximate++;
      remap[i] = intern(converted.state);
    }

    const airIndex = 0;
    final needsWaterLayer = waterlogged.any((w) => w);
    final waterIndex =
        needsWaterLayer ? intern(BlockState('minecraft:water')) : airIndex;

    final total = schematic.volume;
    final layer0 = <NbtTag>[];
    final layer1 = <NbtTag>[];
    for (var x = 0; x < schematic.width; x++) {
      for (var y = 0; y < schematic.height; y++) {
        for (var z = 0; z < schematic.length; z++) {
          final source = schematic.blocks[schematic.indexOf(x, y, z)];
          layer0.add(NbtInt(remap[source]));
          layer1.add(NbtInt(waterlogged[source] ? waterIndex : airIndex));
        }
      }
    }

    final palette = NbtCompound.empty()
      ..['block_palette'] = NbtList(10, [
        for (final state in bedrockPalette)
          blockStateToNbt(
            state,
            nameKey: 'name',
            propertiesKey: 'states',
            typedValues: true,
            omitEmptyProperties: false,
          )..['version'] = const NbtInt(blockVersion),
      ])
      ..['block_position_data'] = NbtCompound.empty();

    final structure = NbtCompound.empty()
      ..['block_indices'] = NbtList(9, [
        NbtList(3, layer0),
        NbtList(3, layer1),
      ])
      ..['entities'] = const NbtList(10, <NbtTag>[])
      ..['palette'] = (NbtCompound.empty()..['default'] = palette);

    final root = NbtCompound.empty()
      ..['format_version'] = const NbtInt(1)
      ..['size'] = NbtList(3, [
        NbtInt(schematic.width),
        NbtInt(schematic.height),
        NbtInt(schematic.length),
      ])
      ..['structure'] = structure
      ..['structure_world_origin'] = NbtList(3, const [
        NbtInt(0),
        NbtInt(0),
        NbtInt(0),
      ]);

    final notes = <String>[
      'Bedrock and Java do not share a block vocabulary, so this conversion '
          'is approximate.',
      if (approximate > 0)
        '$approximate palette ${approximate == 1 ? 'entry' : 'entries'} lost '
            'a property Bedrock has no equivalent for.',
      if (total > 64 * 64 * 64)
        'Bedrock structure blocks load at most 64×64×64 at a time, so this '
            'build will need splitting up in-game.',
    ];

    return (
      bytes: Nbt.write(
        NamedTag('', root),
        endian: Endian.little,
        compression: NbtCompression.none,
      ),
      notes: notes,
    );
  }
}

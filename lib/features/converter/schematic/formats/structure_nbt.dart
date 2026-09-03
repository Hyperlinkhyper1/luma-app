import 'dart:typed_data';

import '../nbt.dart';
import '../schematic_model.dart';
import 'nbt_block_state.dart';

/// The vanilla structure-block `.nbt` format.
///
/// Unlike the other formats this one is sparse: instead of an array covering
/// the whole box it lists only the positions it cares about, each carrying its
/// own palette index. Anything not listed stays air.
class StructureNbt {
  const StructureNbt._();

  static const int defaultDataVersion = 3700;

  /// The largest box a structure block will load in-game.
  static const int structureBlockLimit = 48;

  static Schematic read(NbtCompound root) {
    final size = root.list('size');
    if (size == null || size.items.length < 3) {
      throw const FormatException(
        'This .nbt file has no size tag, so it is not a structure file.',
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

    // `palettes` holds several alternative palettes for structures with
    // randomised variants; the first is the one the game uses by default.
    var paletteTag = root.list('palette');
    if (paletteTag == null) {
      final alternatives = root.list('palettes');
      if (alternatives != null && alternatives.items.isNotEmpty) {
        final first = alternatives.items.first;
        if (first is NbtList) paletteTag = first;
      }
    }
    if (paletteTag == null) {
      throw const FormatException('This structure file has no palette.');
    }

    final builder = PaletteBuilder();
    final remap = <int>[];
    for (final item in paletteTag.items) {
      remap.add(
        item is NbtCompound ? builder.add(blockStateFromNbt(item)) : 0,
      );
    }

    final blocks = Uint16List(width * height * length);
    final blockList = root.list('blocks');
    var outOfBounds = 0;
    for (final item in blockList?.items ?? const <NbtTag>[]) {
      if (item is! NbtCompound) continue;
      final state = item.intValue('state');
      final pos = item.list('pos');
      if (state == null || pos == null || pos.items.length < 3) continue;
      int coord(int i) => switch (pos.items[i]) {
            NbtInt(:final value) => value,
            NbtShort(:final value) => value,
            NbtByte(:final value) => value,
            _ => -1,
          };
      final x = coord(0);
      final y = coord(1);
      final z = coord(2);
      if (x < 0 || y < 0 || z < 0 || x >= width || y >= height || z >= length) {
        outOfBounds++;
        continue;
      }
      if (state < 0 || state >= remap.length) continue;
      blocks[x + z * width + y * width * length] = remap[state];
    }

    final notes = <String>[];
    if (outOfBounds > 0) {
      notes.add(
        '$outOfBounds ${outOfBounds == 1 ? 'block sat' : 'blocks sat'} outside '
        'the declared size and were skipped.',
      );
    }

    return Schematic(
      width: width,
      height: height,
      length: length,
      palette: builder.build(),
      blocks: blocks,
      author: root.stringValue('author'),
      dataVersion: root.intValue('DataVersion'),
      sourceFormat: SchematicFormat.structure,
      notes: notes,
    );
  }

  /// The point past which a structure file stops being worth writing.
  ///
  /// This format lists every position as its own compound tag rather than
  /// packing them, so the file grows about two orders of magnitude faster than
  /// the others — and a build this size is already twenty times what a
  /// structure block will load.
  static const int maxWritableVolume = 2000000;

  static ({Uint8List bytes, List<String> notes}) write(Schematic schematic) {
    if (schematic.volume > maxWritableVolume) {
      throw FormatException(
        'This build is ${schematic.width}×${schematic.height}×'
        '${schematic.length}. A vanilla structure file stores every position '
        'separately, so one that size would be unusably large — and a '
        'structure block only loads $structureBlockLimit blocks per side. '
        'Convert to .litematic or .schem instead.',
      );
    }

    final blocks = <NbtTag>[];
    for (var y = 0; y < schematic.height; y++) {
      for (var z = 0; z < schematic.length; z++) {
        for (var x = 0; x < schematic.width; x++) {
          // Air is written out too, the way the game's own structure blocks
          // do it: a position the list omits is left untouched on load rather
          // than cleared, which would leave the build embedded in terrain.
          final index = schematic.blocks[schematic.indexOf(x, y, z)];
          blocks.add(
            NbtCompound.empty()
              ..['state'] = NbtInt(index)
              ..['pos'] = NbtList(
                3,
                [NbtInt(x), NbtInt(y), NbtInt(z)],
              ),
          );
        }
      }
    }

    final root = NbtCompound.empty()
      ..['DataVersion'] =
          NbtInt(schematic.dataVersion ?? defaultDataVersion)
      ..['size'] = NbtList(3, [
        NbtInt(schematic.width),
        NbtInt(schematic.height),
        NbtInt(schematic.length),
      ])
      ..['palette'] = NbtList(
        10,
        [for (final state in schematic.palette) blockStateToNbt(state)],
      )
      ..['blocks'] = NbtList(10, blocks)
      ..['entities'] = const NbtList(10, <NbtTag>[])
      ..['author'] = NbtString(schematic.author ?? 'luma');

    final notes = <String>[];
    final longest = [schematic.width, schematic.height, schematic.length]
        .reduce((a, b) => a > b ? a : b);
    if (longest > structureBlockLimit) {
      notes.add(
        'This build is ${schematic.width}×${schematic.height}×'
        '${schematic.length}, past the $structureBlockLimit-block limit a '
        'structure block can load. It will need splitting up in-game.',
      );
    }

    return (bytes: Nbt.write(NamedTag('', root)), notes: notes);
  }
}

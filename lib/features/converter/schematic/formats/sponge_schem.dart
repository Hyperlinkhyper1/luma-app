import 'dart:typed_data';

import '../nbt.dart';
import '../schematic_model.dart';

/// The Sponge schematic format — what WorldEdit and FAWE write as `.schem`.
///
/// Handles all three revisions on the way in. Version 1 and 2 keep the fields
/// on the root `Schematic` compound; version 3 moved the blocks into a nested
/// `Blocks` compound and renamed `BlockData` to `Data`. Version 2 is what gets
/// written back out, because every tool that reads the format reads that one.
class SpongeSchematic {
  const SpongeSchematic._();

  /// Data version written when the source did not carry one — 1.20.4.
  static const int defaultDataVersion = 3700;

  static Schematic read(NbtCompound root) {
    // v3 nests everything one level down; v1/v2 keep it on the root, which is
    // itself the tag named "Schematic".
    final s = root.compound('Schematic') ?? root;

    final version = s.intValue('Version') ?? 1;
    final width = s.unsignedShortValue('Width');
    final height = s.unsignedShortValue('Height');
    final length = s.unsignedShortValue('Length');
    if (width == null || height == null || length == null) {
      throw const FormatException(
        'This .schem file is missing its Width/Height/Length tags.',
      );
    }
    guardVolume(width, height, length);

    final NbtCompound? paletteTag;
    final Int8List? data;
    if (version >= 3) {
      final blocks = s.compound('Blocks');
      if (blocks == null) {
        throw const FormatException(
          'This version 3 .schem file has no Blocks compound.',
        );
      }
      paletteTag = blocks.compound('Palette');
      data = blocks.byteArray('Data');
    } else {
      paletteTag = s.compound('Palette');
      data = s.byteArray('BlockData');
    }

    if (paletteTag == null || data == null) {
      throw const FormatException(
        'This .schem file has no block palette or block data.',
      );
    }

    // The palette maps a state string to its own index, which is not
    // necessarily dense or in order, so index by the value not the position.
    final builder = PaletteBuilder();
    final remap = <int, int>{};
    paletteTag.values.forEach((stateString, indexTag) {
      final index = switch (indexTag) {
        NbtInt(:final value) => value,
        NbtShort(:final value) => value,
        NbtByte(:final value) => value,
        _ => null,
      };
      if (index == null) return;
      remap[index] = builder.add(BlockState.parse(stateString));
    });

    final volume = width * height * length;
    final blocks = Uint16List(volume);
    var cursor = 0;
    var written = 0;
    // BlockData is a stream of varints, one per position, in YZX order.
    while (cursor < data.length && written < volume) {
      var value = 0;
      var shift = 0;
      while (true) {
        if (cursor >= data.length) {
          throw const FormatException(
            'The block data ends in the middle of a value.',
          );
        }
        final byte = data[cursor++] & 0xFF;
        value |= (byte & 0x7F) << shift;
        if ((byte & 0x80) == 0) break;
        shift += 7;
        if (shift > 35) {
          throw const FormatException('The block data is corrupt.');
        }
      }
      blocks[written++] = remap[value] ?? 0;
    }

    return Schematic(
      width: width,
      height: height,
      length: length,
      palette: builder.build(),
      blocks: blocks,
      name: s.compound('Metadata')?.stringValue('Name'),
      author: s.compound('Metadata')?.stringValue('Author'),
      dataVersion: s.intValue('DataVersion'),
      sourceFormat: SchematicFormat.sponge,
      notes: written < volume
          ? [
              'The block data stopped ${volume - written} blocks short of the '
                  'declared size; the rest was filled with air.',
            ]
          : const <String>[],
    );
  }

  static Uint8List write(Schematic schematic) {
    final palette = NbtCompound.empty();
    for (var i = 0; i < schematic.palette.length; i++) {
      palette[schematic.palette[i].toStateString()] = NbtInt(i);
    }

    final data = BytesBuilder(copy: false);
    for (final index in schematic.blocks) {
      var value = index;
      while (true) {
        if ((value & ~0x7F) == 0) {
          data.addByte(value);
          break;
        }
        data.addByte((value & 0x7F) | 0x80);
        value >>= 7;
      }
    }

    final metadata = NbtCompound.empty();
    if (schematic.name != null) {
      metadata['Name'] = NbtString(schematic.name!);
    }
    if (schematic.author != null) {
      metadata['Author'] = NbtString(schematic.author!);
    }

    final body = NbtCompound.empty()
      ..['Version'] = const NbtInt(2)
      ..['DataVersion'] = NbtInt(schematic.dataVersion ?? defaultDataVersion)
      ..['Width'] = NbtShort(schematic.width)
      ..['Height'] = NbtShort(schematic.height)
      ..['Length'] = NbtShort(schematic.length)
      ..['Offset'] = NbtIntArray(Int32List.fromList(const [0, 0, 0]))
      ..['PaletteMax'] = NbtInt(schematic.palette.length)
      ..['Palette'] = palette
      ..['BlockData'] =
          NbtByteArray(Int8List.sublistView(data.takeBytes()))
      ..['BlockEntities'] = const NbtList(10, <NbtTag>[])
      ..['Metadata'] = metadata;

    return Nbt.write(NamedTag('Schematic', body));
  }
}

import 'dart:typed_data';

import '../legacy_blocks.dart';
import '../nbt.dart';
import '../schematic_model.dart';

/// The MCEdit `.schematic` format: the pre-flattening one, where every block
/// is a numeric id plus a 4-bit data value rather than a namespaced state.
///
/// Ids above 255 are stored as a second nibble array (`AddBlocks`), so the
/// full id is `Blocks[i] | add << 8`.
class MceditSchematic {
  const MceditSchematic._();

  static Schematic read(NbtCompound root) {
    final width = root.unsignedShortValue('Width');
    final height = root.unsignedShortValue('Height');
    final length = root.unsignedShortValue('Length');
    if (width == null || height == null || length == null) {
      throw const FormatException(
        'This .schematic file is missing its Width/Height/Length tags.',
      );
    }
    guardVolume(width, height, length);

    final rawBlocks = root.byteArray('Blocks');
    if (rawBlocks == null) {
      throw const FormatException(
        'This .schematic file has no Blocks array.',
      );
    }
    final rawData = root.byteArray('Data');
    final add = root.byteArray('AddBlocks') ?? root.byteArray('Add');

    final volume = width * height * length;
    final builder = PaletteBuilder();
    final blocks = Uint16List(volume);
    final unmapped = <int>{};

    // Cache per (id, data) pair: a schematic is thousands of repeats of a
    // handful of blocks, and the legacy lookup is not free.
    final cache = <int, int>{};

    final count = volume < rawBlocks.length ? volume : rawBlocks.length;
    for (var i = 0; i < count; i++) {
      var id = rawBlocks[i] & 0xFF;
      if (add != null && i >> 1 < add.length) {
        final nibble = (i & 1) == 0
            ? (add[i >> 1] >> 4) & 0x0F
            : add[i >> 1] & 0x0F;
        id |= nibble << 8;
      }
      final data = (rawData != null && i < rawData.length)
          ? rawData[i] & 0x0F
          : 0;

      final key = (id << 4) | data;
      final cached = cache[key];
      if (cached != null) {
        blocks[i] = cached;
        continue;
      }

      final state = LegacyBlocks.fromLegacy(id, data);
      if (state == null) unmapped.add(id);
      final index = builder.add(state ?? BlockState.air);
      cache[key] = index;
      blocks[i] = index;
    }

    final notes = <String>[];
    if (unmapped.isNotEmpty) {
      final ids = unmapped.toList()..sort();
      final shown = ids.take(8).join(', ');
      notes.add(
        '${ids.length} legacy block ${ids.length == 1 ? 'id' : 'ids'} had no '
        'modern equivalent and became air (id $shown'
        '${ids.length > 8 ? ', …' : ''}).',
      );
    }
    if (root.list('TileEntities')?.items.isNotEmpty ?? false) {
      notes.add(
        'Tile entity contents (chest inventories, sign text) are not carried '
        'across.',
      );
    }

    return Schematic(
      width: width,
      height: height,
      length: length,
      palette: builder.build(),
      blocks: blocks,
      sourceFormat: SchematicFormat.mcedit,
      notes: notes,
    );
  }

  static ({Uint8List bytes, List<String> notes}) write(Schematic schematic) {
    final palette = schematic.palette;
    final ids = Uint16List(palette.length);
    final datas = Uint8List(palette.length);
    final unmapped = <String>{};
    var inexact = 0;

    for (var i = 0; i < palette.length; i++) {
      final state = palette[i];
      if (state.isAir) continue;
      final legacy = LegacyBlocks.toLegacy(state);
      if (legacy == null) {
        unmapped.add(state.name);
        ids[i] = 1;
        datas[i] = 0;
        continue;
      }
      ids[i] = legacy.id;
      datas[i] = legacy.data;
      if (!legacy.exact) inexact++;
    }

    final volume = schematic.volume;
    final blocks = Int8List(volume);
    final data = Int8List(volume);
    var needsAdd = false;
    for (var i = 0; i < volume; i++) {
      final id = ids[schematic.blocks[i]];
      if (id > 255) needsAdd = true;
      blocks[i] = id & 0xFF;
      data[i] = datas[schematic.blocks[i]];
    }

    final root = NbtCompound.empty()
      ..['Width'] = NbtShort(schematic.width)
      ..['Height'] = NbtShort(schematic.height)
      ..['Length'] = NbtShort(schematic.length)
      ..['Materials'] = const NbtString('Alpha')
      ..['Blocks'] = NbtByteArray(blocks)
      ..['Data'] = NbtByteArray(data);

    if (needsAdd) {
      final addArray = Uint8List((volume + 1) >> 1);
      for (var i = 0; i < volume; i++) {
        final high = (ids[schematic.blocks[i]] >> 8) & 0x0F;
        if (high == 0) continue;
        addArray[i >> 1] |= (i & 1) == 0 ? high << 4 : high;
      }
      root['AddBlocks'] = NbtByteArray(Int8List.sublistView(addArray));
    }

    root['Entities'] = const NbtList(10, <NbtTag>[]);
    root['TileEntities'] = const NbtList(10, <NbtTag>[]);

    final notes = <String>[];
    if (unmapped.isNotEmpty) {
      final names = unmapped.toList()..sort();
      notes.add(
        '${names.length} block ${names.length == 1 ? 'type' : 'types'} did not '
        'exist before Minecraft 1.13 and became stone '
        '(${names.take(5).map((n) => n.split(':').last).join(', ')}'
        '${names.length > 5 ? ', …' : ''}).',
      );
    }
    if (inexact > 0) {
      notes.add(
        '$inexact block ${inexact == 1 ? 'state' : 'states'} kept the right '
        'block but lost its orientation or variant.',
      );
    }

    return (bytes: Nbt.write(NamedTag('Schematic', root)), notes: notes);
  }
}

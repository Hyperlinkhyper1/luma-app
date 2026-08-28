import 'dart:typed_data';

import '../nbt.dart';
import '../schematic_model.dart';
import 'nbt_block_state.dart';

/// The Litematica `.litematic` format.
///
/// Two things make it more involved than the other formats. Block indices are
/// bit-packed into a long array at the narrowest width the palette fits in,
/// and entries are allowed to straddle a long boundary. And a schematic holds
/// any number of independently positioned *regions*, whose sizes may be
/// negative to mean "extends the other way" — so reading one means unioning
/// the regions into a single box.
class Litematic {
  const Litematic._();

  /// Written into new files. Version 6 is what current Litematica produces.
  static const int schematicVersion = 6;
  static const int defaultDataVersion = 3700;

  static Schematic read(NbtCompound root) {
    final regions = root.compound('Regions');
    if (regions == null || regions.values.isEmpty) {
      throw const FormatException(
        'This .litematic file contains no regions.',
      );
    }

    final parsed = <_Region>[];
    for (final entry in regions.values.entries) {
      final tag = entry.value;
      if (tag is! NbtCompound) continue;
      final region = _Region.parse(tag);
      if (region != null) parsed.add(region);
    }
    if (parsed.isEmpty) {
      throw const FormatException(
        'None of the regions in this .litematic file could be read.',
      );
    }

    // Union the regions into one box in schematic-local coordinates.
    var minX = parsed.first.minX;
    var minY = parsed.first.minY;
    var minZ = parsed.first.minZ;
    var maxX = parsed.first.minX + parsed.first.sizeX;
    var maxY = parsed.first.minY + parsed.first.sizeY;
    var maxZ = parsed.first.minZ + parsed.first.sizeZ;
    for (final r in parsed.skip(1)) {
      if (r.minX < minX) minX = r.minX;
      if (r.minY < minY) minY = r.minY;
      if (r.minZ < minZ) minZ = r.minZ;
      if (r.minX + r.sizeX > maxX) maxX = r.minX + r.sizeX;
      if (r.minY + r.sizeY > maxY) maxY = r.minY + r.sizeY;
      if (r.minZ + r.sizeZ > maxZ) maxZ = r.minZ + r.sizeZ;
    }

    final width = maxX - minX;
    final height = maxY - minY;
    final length = maxZ - minZ;
    guardVolume(width, height, length);

    final builder = PaletteBuilder();
    final blocks = Uint16List(width * height * length);

    for (final region in parsed) {
      final remap = List<int>.generate(
        region.palette.length,
        (i) => builder.add(region.palette[i]),
        growable: false,
      );
      final bits = _bitsFor(region.palette.length);
      final mask = (1 << bits) - 1;
      final longs = region.blockStates;

      for (var y = 0; y < region.sizeY; y++) {
        for (var z = 0; z < region.sizeZ; z++) {
          for (var x = 0; x < region.sizeX; x++) {
            final local =
                y * region.sizeX * region.sizeZ + z * region.sizeX + x;
            final value = _readPacked(longs, local, bits, mask);
            if (value < 0 || value >= remap.length) continue;
            final mapped = remap[value];
            if (mapped == 0) continue;
            final gx = region.minX - minX + x;
            final gy = region.minY - minY + y;
            final gz = region.minZ - minZ + z;
            blocks[gx + gz * width + gy * width * length] = mapped;
          }
        }
      }
    }

    final metadata = root.compound('Metadata');
    final notes = <String>[];
    if (parsed.length > 1) {
      notes.add(
        'The source had ${parsed.length} regions; they were merged into one '
        '$width×$height×$length box.',
      );
    }

    return Schematic(
      width: width,
      height: height,
      length: length,
      palette: builder.build(),
      blocks: blocks,
      name: metadata?.stringValue('Name'),
      author: metadata?.stringValue('Author'),
      description: metadata?.stringValue('Description'),
      dataVersion: root.intValue('MinecraftDataVersion'),
      sourceFormat: SchematicFormat.litematic,
      notes: notes,
    );
  }

  /// Litematica sizes its packed entries to the palette, never narrower than
  /// two bits.
  static int _bitsFor(int paletteSize) {
    final needed = paletteSize <= 1 ? 0 : (paletteSize - 1).bitLength;
    return needed < 2 ? 2 : needed;
  }

  /// Reads entry [index] out of the packed long array. Entries may span two
  /// longs, which is what the second branch handles.
  static int _readPacked(Int64List longs, int index, int bits, int mask) {
    final startOffset = index * bits;
    final startIndex = startOffset >> 6;
    final endIndex = ((index + 1) * bits - 1) >> 6;
    if (endIndex >= longs.length) return 0;
    final startBit = startOffset & 0x3F;
    if (startIndex == endIndex) {
      return (longs[startIndex] >>> startBit) & mask;
    }
    return ((longs[startIndex] >>> startBit) |
            (longs[endIndex] << (64 - startBit))) &
        mask;
  }

  static Uint8List write(Schematic schematic) {
    final palette = schematic.palette;
    final bits = _bitsFor(palette.length);
    final total = schematic.volume;
    final longCount = ((total * bits) + 63) >> 6;
    final longs = Int64List(longCount);

    for (var i = 0; i < total; i++) {
      final value = schematic.blocks[i];
      if (value == 0) continue;
      final startOffset = i * bits;
      final startIndex = startOffset >> 6;
      final endIndex = ((i + 1) * bits - 1) >> 6;
      final startBit = startOffset & 0x3F;
      longs[startIndex] |= value << startBit;
      if (startIndex != endIndex) {
        longs[endIndex] |= value >>> (64 - startBit);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final size = NbtCompound.empty()
      ..['x'] = NbtInt(schematic.width)
      ..['y'] = NbtInt(schematic.height)
      ..['z'] = NbtInt(schematic.length);

    final region = NbtCompound.empty()
      ..['Position'] = (NbtCompound.empty()
        ..['x'] = const NbtInt(0)
        ..['y'] = const NbtInt(0)
        ..['z'] = const NbtInt(0))
      ..['Size'] = size
      ..['BlockStatePalette'] = NbtList(
        10,
        [for (final state in palette) blockStateToNbt(state)],
      )
      ..['BlockStates'] = NbtLongArray(longs)
      ..['Entities'] = const NbtList(10, <NbtTag>[])
      ..['TileEntities'] = const NbtList(10, <NbtTag>[])
      ..['PendingBlockTicks'] = const NbtList(10, <NbtTag>[])
      ..['PendingFluidTicks'] = const NbtList(10, <NbtTag>[]);

    final enclosing = NbtCompound.empty()
      ..['x'] = NbtInt(schematic.width)
      ..['y'] = NbtInt(schematic.height)
      ..['z'] = NbtInt(schematic.length);

    final metadata = NbtCompound.empty()
      ..['Name'] = NbtString(schematic.name ?? 'Converted with luma')
      ..['Author'] = NbtString(schematic.author ?? '')
      ..['Description'] = NbtString(schematic.description ?? '')
      ..['EnclosingSize'] = enclosing
      ..['TimeCreated'] = NbtLong(now)
      ..['TimeModified'] = NbtLong(now)
      ..['RegionCount'] = const NbtInt(1)
      ..['TotalBlocks'] = NbtInt(schematic.blockCount)
      ..['TotalVolume'] = NbtInt(schematic.volume);

    final root = NbtCompound.empty()
      ..['Version'] = const NbtInt(schematicVersion)
      ..['SubVersion'] = const NbtInt(1)
      ..['MinecraftDataVersion'] =
          NbtInt(schematic.dataVersion ?? defaultDataVersion)
      ..['Metadata'] = metadata
      ..['Regions'] = (NbtCompound.empty()
        ..[schematic.name?.isNotEmpty == true ? schematic.name! : 'Main'] =
            region);

    return Nbt.write(NamedTag('', root));
  }
}

/// One parsed Litematica region, normalised so its size is positive and its
/// origin is the minimum corner.
class _Region {
  _Region({
    required this.minX,
    required this.minY,
    required this.minZ,
    required this.sizeX,
    required this.sizeY,
    required this.sizeZ,
    required this.palette,
    required this.blockStates,
  });

  final int minX;
  final int minY;
  final int minZ;
  final int sizeX;
  final int sizeY;
  final int sizeZ;
  final List<BlockState> palette;
  final Int64List blockStates;

  static _Region? parse(NbtCompound tag) {
    final position = tag.compound('Position');
    final size = tag.compound('Size');
    final paletteTag = tag.list('BlockStatePalette');
    final states = tag.longArray('BlockStates');
    if (position == null ||
        size == null ||
        paletteTag == null ||
        states == null) {
      return null;
    }

    final px = position.intValue('x') ?? 0;
    final py = position.intValue('y') ?? 0;
    final pz = position.intValue('z') ?? 0;
    final sx = size.intValue('x') ?? 0;
    final sy = size.intValue('y') ?? 0;
    final sz = size.intValue('z') ?? 0;
    if (sx == 0 || sy == 0 || sz == 0) return null;

    // A negative size means the region grows towards negative coordinates
    // from its position, so the minimum corner is at the far end.
    return _Region(
      minX: sx < 0 ? px + sx + 1 : px,
      minY: sy < 0 ? py + sy + 1 : py,
      minZ: sz < 0 ? pz + sz + 1 : pz,
      sizeX: sx.abs(),
      sizeY: sy.abs(),
      sizeZ: sz.abs(),
      palette: [
        for (final item in paletteTag.items)
          if (item is NbtCompound) blockStateFromNbt(item),
      ],
      blockStates: states,
    );
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
import '../nbt.dart';
import '../schematic_model.dart';
import 'axiom_thumbnail.dart';
import 'nbt_block_state.dart';

/// Axiom's length-prefixed header, PNG thumbnail and gzip NBT block regions.
class AxiomBlueprint {
  const AxiomBlueprint._();

  static const magic = 0x0AE5BB36;

  static bool matches(Uint8List bytes) =>
      bytes.length >= 4 && ByteData.sublistView(bytes).getUint32(0) == magic;

  static Schematic read(Uint8List bytes) {
    if (!matches(bytes)) throw const FormatException('Invalid Axiom header.');
    var offset = 4;
    Uint8List part() {
      if (offset + 4 > bytes.length) {
        throw const FormatException('Truncated Axiom blueprint.');
      }
      final size = ByteData.sublistView(bytes).getInt32(offset);
      offset += 4;
      if (size < 0 || size > bytes.length - offset) {
        throw const FormatException('Invalid Axiom section length.');
      }
      final result = Uint8List.sublistView(bytes, offset, offset + size);
      offset += size;
      return result;
    }

    try {
      final header = Nbt.read(part()).asCompound;
      final version = header.intValue('Version');
      if (version != 1 && version != 2) {
        throw const FormatException('Unsupported Axiom blueprint version.');
      }
      part();
      final root = Nbt.read(part()).asCompound;
      final regions = root.list('BlockRegion');
      if (regions == null ||
          regions.items.isEmpty ||
          regions.items.length > kMaxSchematicVolume ~/ 4096) {
        throw const FormatException('Invalid Axiom block regions.');
      }
      final builder = PaletteBuilder();
      final decoded =
          <({int x, int y, int z, Uint16List blocks, List<bool> voids})>[];
      var minX = 1 << 62, minY = 1 << 62, minZ = 1 << 62;
      var maxX = -(1 << 62), maxY = -(1 << 62), maxZ = -(1 << 62);
      final seen = <(int, int, int)>{};
      for (final item in regions.items) {
        if (item is! NbtCompound) {
          throw const FormatException('Invalid Axiom region.');
        }
        final rx = item.intValue('X'),
            ry = item.intValue('Y'),
            rz = item.intValue('Z');
        if (rx == null ||
            ry == null ||
            rz == null ||
            rx.abs() > 2000000 ||
            ry.abs() > 2000000 ||
            rz.abs() > 2000000 ||
            !seen.add((rx, ry, rz))) {
          throw const FormatException(
            'Invalid or duplicate Axiom region position.',
          );
        }
        final states = item.compound('BlockStates');
        final palette = states?.list('palette');
        if (palette == null ||
            palette.items.isEmpty ||
            palette.items.length > 4096) {
          throw const FormatException('Invalid Axiom palette.');
        }
        final remap = <int>[];
        final voids = <bool>[];
        for (final tag in palette.items) {
          if (tag is! NbtCompound || tag.stringValue('Name') == null) {
            throw const FormatException('Invalid Axiom block state.');
          }
          final state = blockStateFromNbt(tag);
          remap.add(builder.add(state));
          voids.add(
            state.name == 'minecraft:structure_void' ||
                state.name == 'minecraft:void_air',
          );
        }
        final bits = math.max(4, (remap.length - 1).bitLength);
        final perLong = 64 ~/ bits;
        final data = states!.longArray('data');
        if (remap.length > 1 &&
            (data == null || data.length != (4096 + perLong - 1) ~/ perLong)) {
          throw const FormatException('Invalid Axiom packed block data.');
        }
        final blocks = Uint16List(4096);
        final excluded = List<bool>.filled(4096, false);
        for (var i = 0; i < 4096; i++) {
          final id = remap.length == 1
              ? 0
              : (data![i ~/ perLong] >>> ((i % perLong) * bits)) &
                    ((1 << bits) - 1);
          if (id >= remap.length) {
            throw const FormatException('Invalid Axiom palette index.');
          }
          blocks[i] = remap[id];
          excluded[i] = voids[id];
          if (excluded[i]) continue;
          final x = rx * 16 + (i & 15);
          final y = ry * 16 + (i >> 8);
          final z = rz * 16 + ((i >> 4) & 15);
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
          minZ = math.min(minZ, z);
          maxZ = math.max(maxZ, z);
        }
        decoded.add((
          x: rx * 16,
          y: ry * 16,
          z: rz * 16,
          blocks: blocks,
          voids: excluded,
        ));
      }
      // Axiom stores only selected positions. Retain luma's source dimensions
      // separately so ignored air borders survive conversion to other formats.
      final sourceSize = header.intArray('LumaSize');
      if (sourceSize != null) {
        if (sourceSize.length != 3 ||
            (maxX >= minX &&
                (minX < 0 ||
                    minY < 0 ||
                    minZ < 0 ||
                    maxX >= sourceSize[0] ||
                    maxY >= sourceSize[1] ||
                    maxZ >= sourceSize[2]))) {
          throw const FormatException('Invalid Axiom source dimensions.');
        }
        minX = minY = minZ = 0;
        maxX = sourceSize[0] - 1;
        maxY = sourceSize[1] - 1;
        maxZ = sourceSize[2] - 1;
      }
      final width = maxX - minX + 1,
          height = maxY - minY + 1,
          length = maxZ - minZ + 1;
      guardVolume(width, height, length);
      final blocks = Uint16List(width * height * length);
      for (final region in decoded) {
        for (var i = 0; i < 4096; i++) {
          if (region.voids[i]) continue;
          final x = region.x + (i & 15) - minX;
          final y = region.y + (i >> 8) - minY;
          final z = region.z + ((i >> 4) & 15) - minZ;
          blocks[x + z * width + y * width * length] = region.blocks[i];
        }
      }
      return Schematic(
        width: width,
        height: height,
        length: length,
        palette: builder.build(),
        blocks: blocks,
        name: header.stringValue('Name'),
        author: header.stringValue('Author'),
        dataVersion: root.intValue('DataVersion'),
        sourceFormat: SchematicFormat.axiom,
        notes: [
          if (root.list('BlockEntities')?.items.isNotEmpty == true)
            currentL.schematicMceditTileEntities,
          if (root.list('Entities')?.items.isNotEmpty == true)
            currentL.schematicAxiomEntities,
        ],
      );
    } on RangeError {
      throw const FormatException('Truncated Axiom blueprint data.');
    }
  }

  static Uint8List write(Schematic schematic, {bool includeAir = false}) {
    guardVolume(schematic.width, schematic.height, schematic.length);
    final regions = <NbtTag>[];
    final nx = (schematic.width + 15) ~/ 16;
    final ny = (schematic.height + 15) ~/ 16;
    final nz = (schematic.length + 15) ~/ 16;
    guardVolume(nx * 16, ny * 16, nz * 16);
    for (var ry = 0; ry < ny; ry++) {
      for (var rz = 0; rz < nz; rz++) {
        for (var rx = 0; rx < nx; rx++) {
          final palette = <BlockState>[];
          final ids = <String, int>{};
          final values = Uint16List(4096);
          for (var i = 0; i < 4096; i++) {
            final x = rx * 16 + (i & 15),
                y = ry * 16 + (i >> 8),
                z = rz * 16 + ((i >> 4) & 15);
            var state = schematic.contains(x, y, z)
                ? schematic.blockAt(x, y, z)
                : BlockState('minecraft:void_air');
            if (!includeAir && state.isAir) {
              state = BlockState('minecraft:void_air');
            }
            final key = state.toStateString();
            values[i] = ids.putIfAbsent(key, () {
              palette.add(state);
              return palette.length - 1;
            });
          }
          final bits = math.max(4, (palette.length - 1).bitLength);
          final perLong = 64 ~/ bits;
          final data = Int64List((4096 + perLong - 1) ~/ perLong);
          for (var i = 0; i < 4096; i++) {
            data[i ~/ perLong] |= values[i] << ((i % perLong) * bits);
          }
          regions.add(
            NbtCompound.empty()
              ..['X'] = NbtInt(rx)
              ..['Y'] = NbtInt(ry)
              ..['Z'] = NbtInt(rz)
              ..['BlockStates'] = (NbtCompound.empty()
                ..['palette'] = NbtList(
                  10,
                  palette.map(blockStateToNbt).toList(),
                )
                ..['data'] = NbtLongArray(data)),
          );
        }
      }
    }
    final header = NbtCompound.empty()
      ..['Version'] = const NbtInt(2)
      ..['Name'] = NbtString(schematic.name ?? 'Blueprint')
      ..['Author'] = NbtString(schematic.author ?? 'luma')
      ..['Tags'] = const NbtList(8, [])
      ..['ThumbnailYaw'] = const NbtFloat(0)
      ..['ThumbnailPitch'] = const NbtFloat(45)
      ..['LockedThumbnail'] = const NbtByte(0)
      ..['LumaSize'] = NbtIntArray(
        Int32List.fromList([
          schematic.width,
          schematic.height,
          schematic.length,
        ]),
      )
      // This flag describes the contents; void_air in the palette is what
      // actually makes Axiom skip empty positions when previewing and pasting.
      ..['ContainsAir'] = NbtByte(includeAir ? 1 : 0)
      ..['BlockCount'] = NbtInt(
        includeAir ? schematic.volume : schematic.blockCount,
      );
    final root = NbtCompound.empty()
      ..['DataVersion'] = NbtInt(schematic.dataVersion ?? 3700)
      ..['BlockRegion'] = NbtList(10, regions)
      ..['BlockEntities'] = const NbtList(10, [])
      ..['Entities'] = const NbtList(10, []);
    final out = BytesBuilder();
    void integer(int value) {
      out.add((ByteData(4)..setUint32(0, value)).buffer.asUint8List());
    }

    void part(Uint8List bytes) {
      integer(bytes.length);
      out.add(bytes);
    }

    integer(magic);
    part(Nbt.write(NamedTag('', header), compression: NbtCompression.none));
    part(axiomThumbnail(schematic));
    part(Nbt.write(NamedTag('', root)));
    return out.takeBytes();
  }
}

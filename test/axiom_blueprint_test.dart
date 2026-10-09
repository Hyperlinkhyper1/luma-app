import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/converter/schematic/formats/axiom_blueprint.dart';
import 'package:luma/features/converter/schematic/nbt.dart';
import 'package:luma/features/converter/schematic/schematic_model.dart';
import 'package:luma/features/converter/schematic/schematic_service.dart';

Uint8List fixture({bool broken = false}) {
  final data = Int64List(342);
  for (var i = 0; i < 4096; i++) {
    data[i ~/ 12] |= (i % 17) << ((i % 12) * 5);
  }
  if (broken) data[0] = 31;
  final region = NbtCompound.empty()
    ..['X'] = const NbtInt(-2)
    ..['Y'] = const NbtInt(3)
    ..['Z'] = const NbtInt(-1)
    ..['BlockStates'] = (NbtCompound.empty()
      ..['palette'] = NbtList(10, [
        for (var i = 0; i < 17; i++)
          NbtCompound.empty()..['Name'] = NbtString('test:block_$i'),
      ])
      ..['data'] = NbtLongArray(data));
  final header = NbtCompound.empty()
    ..['Version'] = const NbtLong(1)
    ..['Name'] = const NbtString('Independent fixture');
  final root = NbtCompound.empty()
    ..['DataVersion'] = const NbtInt(4189)
    ..['BlockRegion'] = NbtList(10, [region])
    ..['Entities'] = NbtList(10, [NbtCompound.empty()])
    ..['BlockEntities'] = NbtList(10, [NbtCompound.empty()]);
  final out = BytesBuilder();
  void integer(int value) =>
      out.add((ByteData(4)..setUint32(0, value)).buffer.asUint8List());
  void part(Uint8List bytes) {
    integer(bytes.length);
    out.add(bytes);
  }

  integer(0x0AE5BB36);
  part(Nbt.write(NamedTag('', header), compression: NbtCompression.none));
  part(Uint8List.fromList([1, 2, 3]));
  part(Nbt.write(NamedTag('', root)));
  return out.takeBytes();
}

void main() {
  ({NbtCompound header, Uint8List png, NbtCompound root}) unpack(
    Uint8List bytes,
  ) {
    var offset = 4;
    Uint8List part() {
      final length = ByteData.sublistView(bytes).getUint32(offset);
      offset += 4;
      final result = Uint8List.sublistView(bytes, offset, offset + length);
      offset += length;
      return result;
    }

    final header = Nbt.read(part()).asCompound;
    final png = part();
    return (header: header, png: png, root: Nbt.read(part()).asCompound);
  }

  Schematic tinyBuild() => Schematic(
    width: 2,
    height: 1,
    length: 1,
    palette: [BlockState.air, BlockState('minecraft:stone')],
    blocks: Uint16List.fromList([1, 0]),
  );

  test(
    'export thumbnail is a valid build preview rather than one red pixel',
    () {
      final exported = unpack(AxiomBlueprint.write(tinyBuild()));
      final image = img.decodePng(exported.png)!;
      expect([image.width, image.height], [128, 128]);
      final pixels = image.map((p) => '${p.r},${p.g},${p.b},${p.a}').toSet();
      expect(pixels.length, greaterThan(2));
    },
  );

  test(
    'Axiom ignores air and section padding instead of pasting empty volume',
    () {
      final exported = unpack(AxiomBlueprint.write(tinyBuild()));
      expect(exported.header.intValue('ContainsAir'), 0);
      final region =
          exported.root.list('BlockRegion')!.items.single as NbtCompound;
      final names = region
          .compound('BlockStates')!
          .list('palette')!
          .items
          .cast<NbtCompound>()
          .map((entry) => entry.stringValue('Name'))
          .toSet();
      expect(names, contains('minecraft:void_air'));
      expect(names, isNot(contains('minecraft:air')));
      expect(names, isNot(contains('minecraft:structure_void')));
      expect(exported.header.intValue('Version'), 2);
      expect(exported.header.intArray('LumaSize'), [2, 1, 1]);
    },
  );

  test('ignored air borders and an entirely empty volume still round-trip', () {
    final source = Schematic(
      width: 3,
      height: 4,
      length: 5,
      palette: [BlockState.air, BlockState('minecraft:stone')],
      blocks: Uint16List(60)..[31] = 1,
    );
    for (final schematic in [source, source.copyWith(blocks: Uint16List(60))]) {
      final back = AxiomBlueprint.read(AxiomBlueprint.write(schematic));
      expect([back.width, back.height, back.length], [3, 4, 5]);
      expect(back.blocks, schematic.blocks);
    }
    final explicitAir = unpack(
      AxiomBlueprint.write(tinyBuild(), includeAir: true),
    );
    expect(explicitAir.header.intValue('ContainsAir'), 1);
    expect(explicitAir.header.intValue('BlockCount'), 2);
  });

  test('reads negative sections and padded five-bit entries independently', () {
    final schematic = SchematicService.load(fixture(), 'external.bp');
    expect([schematic.width, schematic.height, schematic.length], [16, 16, 16]);
    expect(schematic.dataVersion, 4189);
    expect(schematic.name, 'Independent fixture');
    expect(schematic.notes, hasLength(2));
    for (var i = 0; i < 4096; i++) {
      expect(
        schematic.palette[schematic.blocks[i]].name,
        'test:block_${i % 17}',
      );
    }
  });

  test('rejects invalid indexes and truncated container lengths', () {
    expect(
      () => AxiomBlueprint.read(fixture(broken: true)),
      throwsFormatException,
    );
    final bytes = fixture();
    expect(
      () => AxiomBlueprint.read(
        Uint8List.sublistView(bytes, 0, bytes.length - 1),
      ),
      throwsFormatException,
    );
    ByteData.sublistView(bytes).setInt32(4, -1);
    expect(() => AxiomBlueprint.read(bytes), throwsFormatException);
  });

  test('writes multiple sections without padding changing size or states', () {
    final palette = [
      BlockState.air,
      for (var i = 0; i < 20; i++) BlockState('test:block_$i'),
    ];
    final blocks = Uint16List.fromList(
      List.generate(19 * 17 * 3, (i) => i % palette.length),
    );
    final source = Schematic(
      width: 19,
      height: 17,
      length: 3,
      palette: palette,
      blocks: blocks,
      name: 'Sections',
      author: 'Author',
      dataVersion: 4189,
    );
    final bytes = SchematicService.save(source, SchematicFormat.axiom).bytes;
    final back = SchematicService.load(bytes, 'unknown.dat');
    expect([back.width, back.height, back.length], [19, 17, 3]);
    expect(back.sourceFormat, SchematicFormat.axiom);
    expect(back.author, 'Author');
    expect(back.dataVersion, 4189);
    for (var i = 0; i < blocks.length; i++) {
      expect(back.palette[back.blocks[i]], palette[blocks[i]]);
    }
    expect(SchematicFormat.allExtensions, contains('bp'));
    expect(SchematicFormat.fromExtension('EXTERNAL.BP'), SchematicFormat.axiom);
    expect(
      SchematicService.suggestFileName('build.schem', SchematicFormat.axiom),
      'build.bp',
    );
  });
}

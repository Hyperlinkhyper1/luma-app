import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

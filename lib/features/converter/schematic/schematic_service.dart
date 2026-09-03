import 'dart:typed_data';

import 'formats/litematic.dart';
import 'formats/mcedit_schematic.dart';
import 'formats/mcstructure.dart';
import 'formats/sponge_schem.dart';
import 'formats/structure_nbt.dart';
import 'nbt.dart';
import 'schematic_model.dart';

/// The outcome of writing a schematic out in some format.
class SchematicExport {
  const SchematicExport({
    required this.bytes,
    required this.format,
    required this.notes,
  });

  final Uint8List bytes;
  final SchematicFormat format;

  /// Everything lossy about this particular conversion, phrased for the user.
  final List<String> notes;
}

/// Reads and writes Minecraft block formats, converting through the shared
/// [Schematic] model so any format can become any other.
class SchematicService {
  const SchematicService._();

  /// Identifies and parses a file in one pass.
  ///
  /// The extension is trusted first — the file picker filters on it and the
  /// formats are hard to tell apart cheaply — but a file whose extension lies
  /// still gets sniffed rather than rejected.
  static Schematic load(Uint8List bytes, String fileName) {
    final byExtension = SchematicFormat.fromExtension(fileName);
    if (byExtension != null) {
      try {
        return _readAs(bytes, byExtension);
      } on FormatException {
        // Fall through to sniffing: a `.nbt` holding a Sponge schematic, or a
        // `.schem` that is really a legacy `.schematic`, are both common.
      }
    }

    final sniffed = _sniff(bytes);
    if (sniffed != null) return _readAs(bytes, sniffed);

    throw const FormatException(
      'This file is not a Minecraft schematic, structure or litematic that '
      'luma recognises.',
    );
  }

  static Schematic _readAs(Uint8List bytes, SchematicFormat format) {
    if (format == SchematicFormat.mcstructure) {
      return Mcstructure.read(Nbt.read(bytes, endian: Endian.little).asCompound);
    }
    final root = Nbt.read(bytes).asCompound;
    return switch (format) {
      SchematicFormat.sponge => SpongeSchematic.read(root),
      SchematicFormat.litematic => Litematic.read(root),
      SchematicFormat.mcedit => MceditSchematic.read(root),
      SchematicFormat.structure => StructureNbt.read(root),
      SchematicFormat.mcstructure => throw StateError('handled above'),
    };
  }

  /// Works out the format from the file's own contents.
  static SchematicFormat? _sniff(Uint8List bytes) {
    try {
      final root = Nbt.read(bytes).asCompound;
      final schematic = root.compound('Schematic') ?? root;
      if (root.has('Regions') && root.has('Metadata')) {
        return SchematicFormat.litematic;
      }
      if (schematic.has('BlockData') ||
          schematic.compound('Blocks')?.has('Data') == true) {
        return SchematicFormat.sponge;
      }
      if (root.has('Blocks') && root.byteArray('Blocks') != null) {
        return SchematicFormat.mcedit;
      }
      if (root.has('size') && (root.has('palette') || root.has('palettes'))) {
        return SchematicFormat.structure;
      }
    } on FormatException {
      // Not a Java-flavoured NBT file; try Bedrock below.
    } on RangeError {
      // Same, but the misread ran off the end of the buffer first.
    }

    try {
      final root = Nbt.read(bytes, endian: Endian.little).asCompound;
      if (root.has('structure') && root.has('size')) {
        return SchematicFormat.mcstructure;
      }
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
    return null;
  }

  /// Serialises a schematic in [target].
  static SchematicExport save(Schematic schematic, SchematicFormat target) {
    final notes = <String>[];
    final Uint8List bytes;
    switch (target) {
      case SchematicFormat.sponge:
        bytes = SpongeSchematic.write(schematic);
      case SchematicFormat.litematic:
        bytes = Litematic.write(schematic);
      case SchematicFormat.mcedit:
        final result = MceditSchematic.write(schematic);
        bytes = result.bytes;
        notes.addAll(result.notes);
      case SchematicFormat.structure:
        final result = StructureNbt.write(schematic);
        bytes = result.bytes;
        notes.addAll(result.notes);
      case SchematicFormat.mcstructure:
        final result = Mcstructure.write(schematic);
        bytes = result.bytes;
        notes.addAll(result.notes);
    }

    if (schematic.palette.length > 4096 &&
        target == SchematicFormat.mcedit) {
      notes.add(
        'The legacy format has no palette, so builds with many block variants '
        'lose the most detail here.',
      );
    }

    return SchematicExport(bytes: bytes, format: target, notes: notes);
  }

  /// Suggests an output file name, swapping the extension for the target's.
  static String suggestFileName(String sourceName, SchematicFormat target) {
    final dot = sourceName.lastIndexOf('.');
    final stem = dot <= 0 ? sourceName : sourceName.substring(0, dot);
    return '$stem.${target.extension}';
  }
}

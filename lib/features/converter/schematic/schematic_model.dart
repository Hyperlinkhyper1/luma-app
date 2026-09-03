import 'dart:typed_data';

/// The block formats luma can read and write.
enum SchematicFormat {
  sponge('schem', 'SCHEM', 'Sponge schematic (WorldEdit)'),
  litematic('litematic', 'LITEMATIC', 'Litematica'),
  mcedit('schematic', 'SCHEMATIC', 'MCEdit legacy'),
  structure('nbt', 'NBT', 'Vanilla structure block'),
  mcstructure('mcstructure', 'MCSTRUCTURE', 'Bedrock structure');

  const SchematicFormat(this.extension, this.label, this.description);

  /// The file extension, without a dot.
  final String extension;

  /// Short uppercase name used on the format chips.
  final String label;

  /// One-line explanation shown next to the format picker.
  final String description;

  /// True for the Bedrock edition format, whose block names and states are a
  /// different vocabulary from the Java ones every other format uses.
  bool get isBedrock => this == SchematicFormat.mcstructure;

  static SchematicFormat? fromExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = fileName.substring(dot + 1).toLowerCase();
    for (final f in SchematicFormat.values) {
      if (f.extension == ext) return f;
    }
    return null;
  }

  static List<String> get allExtensions =>
      SchematicFormat.values.map((f) => f.extension).toList();
}

/// The largest volume the converter will allocate for, about 33 million
/// blocks — a 320×320×320 box. Past that a malformed size field would ask for
/// gigabytes before anything else had a chance to fail.
const int kMaxSchematicVolume = 32 * 1024 * 1024;

/// Rejects sizes that are absent, negative or larger than
/// [kMaxSchematicVolume] before anything tries to allocate for them.
void guardVolume(int width, int height, int length) {
  if (width <= 0 || height <= 0 || length <= 0) {
    throw const FormatException(
      'This file declares an empty area, so there is nothing to convert.',
    );
  }
  if (width * height * length > kMaxSchematicVolume) {
    throw FormatException(
      'This build is $width×$height×$length, which is larger than the '
      '${kMaxSchematicVolume ~/ (1024 * 1024)} million blocks the converter '
      'can hold in memory.',
    );
  }
}

/// One entry of a schematic's palette: a block id plus its block-state
/// properties, e.g. `minecraft:oak_stairs[facing=north,half=top]`.
class BlockState {
  BlockState(this.name, [Map<String, String>? properties])
      : properties = properties == null || properties.isEmpty
            ? const <String, String>{}
            : Map.unmodifiable(properties);

  /// Namespaced block id, always carrying its namespace (`minecraft:stone`).
  final String name;

  /// Block-state properties, e.g. `{facing: north}`. Sorted on output so two
  /// states that differ only in property order compare equal.
  final Map<String, String> properties;

  static final BlockState air = BlockState('minecraft:air');

  bool get isAir =>
      name == 'minecraft:air' ||
      name == 'minecraft:cave_air' ||
      name == 'minecraft:void_air' ||
      name == 'minecraft:structure_void';

  /// The block id without its namespace — what the viewer's colour table and
  /// the material list key off.
  String get shortName {
    final colon = name.indexOf(':');
    return colon < 0 ? name : name.substring(colon + 1);
  }

  /// Parses the `namespace:id[key=value,...]` form used by Sponge palettes.
  factory BlockState.parse(String raw) {
    final bracket = raw.indexOf('[');
    if (bracket < 0) return BlockState(_withNamespace(raw));
    final name = raw.substring(0, bracket);
    final body = raw.substring(bracket + 1, raw.lastIndexOf(']'));
    final props = <String, String>{};
    for (final pair in body.split(',')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      props[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
    }
    return BlockState(_withNamespace(name), props);
  }

  static String _withNamespace(String name) {
    final trimmed = name.trim();
    return trimmed.contains(':') ? trimmed : 'minecraft:$trimmed';
  }

  /// Renders back to the `namespace:id[key=value,...]` form.
  String toStateString() {
    if (properties.isEmpty) return name;
    final keys = properties.keys.toList()..sort();
    final body = keys.map((k) => '$k=${properties[k]}').join(',');
    return '$name[$body]';
  }

  BlockState withName(String newName) => BlockState(newName, properties);

  BlockState withProperties(Map<String, String> newProperties) =>
      BlockState(name, newProperties);

  @override
  String toString() => toStateString();

  @override
  bool operator ==(Object other) =>
      other is BlockState && other.toStateString() == toStateString();

  @override
  int get hashCode => toStateString().hashCode;
}

/// A format-neutral block volume: the shape every reader produces and every
/// writer consumes, so adding a format is one reader plus one writer rather
/// than a converter per format pair.
class Schematic {
  Schematic({
    required this.width,
    required this.height,
    required this.length,
    required this.palette,
    required this.blocks,
    this.name,
    this.author,
    this.description,
    this.dataVersion,
    this.sourceFormat,
    this.notes = const <String>[],
  });

  /// Size along X (width), Y (height) and Z (length).
  final int width;
  final int height;
  final int length;

  /// Distinct block states. Index 0 is always air, so an untouched volume can
  /// be a zero-filled array and writers that require an air entry (Litematica)
  /// need no special case.
  final List<BlockState> palette;

  /// One palette index per position, in YZX order:
  /// `index = x + z * width + y * width * length`.
  final Uint16List blocks;

  final String? name;
  final String? author;
  final String? description;

  /// The Minecraft world data version the source declared, carried across so
  /// a round trip does not silently relabel the schematic's game version.
  final int? dataVersion;

  final SchematicFormat? sourceFormat;

  /// Anything lossy that happened on the way in, surfaced in the UI rather
  /// than swallowed — unmapped legacy ids, dropped entities, and so on.
  final List<String> notes;

  int get volume => width * height * length;

  /// Number of positions holding something other than air.
  late final int blockCount = _countNonAir();

  int _countNonAir() {
    var count = 0;
    for (var i = 0; i < blocks.length; i++) {
      if (!palette[blocks[i]].isAir) count++;
    }
    return count;
  }

  int indexOf(int x, int y, int z) => x + z * width + y * width * length;

  BlockState blockAt(int x, int y, int z) => palette[blocks[indexOf(x, y, z)]];

  bool contains(int x, int y, int z) =>
      x >= 0 && y >= 0 && z >= 0 && x < width && y < height && z < length;

  Schematic copyWith({
    List<BlockState>? palette,
    Uint16List? blocks,
    String? name,
    String? author,
    List<String>? notes,
    SchematicFormat? sourceFormat,
  }) =>
      Schematic(
        width: width,
        height: height,
        length: length,
        palette: palette ?? this.palette,
        blocks: blocks ?? this.blocks,
        name: name ?? this.name,
        author: author ?? this.author,
        description: description,
        dataVersion: dataVersion,
        sourceFormat: sourceFormat ?? this.sourceFormat,
        notes: notes ?? this.notes,
      );

  /// Counts how many times each palette entry is used, most-used first, with
  /// air excluded. Drives the material list under the viewer.
  List<MaterialCount> materials() {
    final counts = List<int>.filled(palette.length, 0);
    for (var i = 0; i < blocks.length; i++) {
      counts[blocks[i]]++;
    }
    final out = <MaterialCount>[];
    for (var i = 0; i < palette.length; i++) {
      if (counts[i] == 0 || palette[i].isAir) continue;
      out.add(MaterialCount(palette[i], counts[i]));
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }
}

/// One row of the material list: a block state and how often it occurs.
class MaterialCount {
  const MaterialCount(this.state, this.count);
  final BlockState state;
  final int count;
}

/// Incrementally builds a [Schematic]'s palette, de-duplicating block states
/// and keeping air pinned at index 0.
class PaletteBuilder {
  PaletteBuilder() {
    _index[BlockState.air.toStateString()] = 0;
    _states.add(BlockState.air);
  }

  final Map<String, int> _index = <String, int>{};
  final List<BlockState> _states = <BlockState>[];

  int add(BlockState state) {
    if (state.isAir) return 0;
    final key = state.toStateString();
    final existing = _index[key];
    if (existing != null) return existing;
    if (_states.length >= 0xFFFF) {
      throw const FormatException(
        'This build uses more than 65535 distinct block states, which is more '
        'than the converter can hold.',
      );
    }
    _states.add(state);
    _index[key] = _states.length - 1;
    return _states.length - 1;
  }

  /// The state already interned at [index]. Cheap, unlike [build], so it is
  /// safe to call from inside a per-block loop.
  BlockState operator [](int index) => _states[index];

  List<BlockState> build() => List<BlockState>.unmodifiable(_states);

  int get length => _states.length;
}

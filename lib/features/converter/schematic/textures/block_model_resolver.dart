import 'dart:convert';

import '../schematic_model.dart';

/// The six cube faces, in the order the voxel renderer uses them.
///
/// Minecraft names directions rather than axes, so the mapping is:
/// `+X = east`, `-X = west`, `+Y = up`, `-Y = down`, `+Z = south`, `-Z = north`.
enum CubeFace {
  east,
  west,
  up,
  down,
  south,
  north;

  static const List<CubeFace> renderOrder = [
    CubeFace.east,
    CubeFace.west,
    CubeFace.up,
    CubeFace.down,
    CubeFace.south,
    CubeFace.north,
  ];
}

/// Which texture goes on each face of a block, plus the biome tint that face
/// is multiplied by.
class BlockFaces {
  const BlockFaces(this.textures, this.tints);

  /// Texture name per [CubeFace.renderOrder] entry, e.g. `block/grass_block_top`.
  /// Null when the model gave nothing for that face.
  final List<String?> textures;

  /// ARGB tint per face, 0xFFFFFFFF when the face is not tinted.
  final List<int> tints;

  static final BlockFaces none = BlockFaces(
    List<String?>.filled(6, null),
    List<int>.filled(6, 0xFFFFFFFF),
  );
}

/// Works out the per-face textures for a block state by reading the game's own
/// blockstate and model JSON, the same files the game itself renders from.
///
/// This is what makes the preview look like Minecraft rather than a colour
/// chart: a grass block gets grass on top, dirt underneath and the fringed
/// side texture, and a log lying on its side gets its end grain on the right
/// two faces.
///
/// Nothing here ships with luma — the JSON and the textures are read out of
/// the player's own installed copy of the game (see `texture_pack_source.dart`).
class BlockModelResolver {
  BlockModelResolver({required this.blockstates, required this.models});

  /// Block name (without namespace) to the raw `blockstates/<name>.json`.
  final Map<String, String> blockstates;

  /// Model name (e.g. `block/cube_all`) to the raw `models/<name>.json`.
  final Map<String, String> models;

  final Map<String, BlockFaces> _cache = <String, BlockFaces>{};

  /// Biome-tinted blocks. Their textures ship greyscale, so without this grass
  /// and leaves come out white.
  static const Map<String, int> _tints = {
    'grass_block': 0xFF7CBD6B,
    'short_grass': 0xFF7CBD6B,
    'grass': 0xFF7CBD6B,
    'tall_grass': 0xFF7CBD6B,
    'fern': 0xFF7CBD6B,
    'large_fern': 0xFF7CBD6B,
    'sugar_cane': 0xFF7CBD6B,
    'vine': 0xFF48B518,
    'lily_pad': 0xFF71C35C,
    'oak_leaves': 0xFF48B518,
    'jungle_leaves': 0xFF48B518,
    'acacia_leaves': 0xFF48B518,
    'dark_oak_leaves': 0xFF48B518,
    'mangrove_leaves': 0xFF48B518,
    'spruce_leaves': 0xFF619961,
    'birch_leaves': 0xFF80A755,
    'water': 0xFF3F76E4,
    'water_cauldron': 0xFF3F76E4,
    'bubble_column': 0xFF3F76E4,
  };

  /// Blocks where only the top face carries the tint — the sides ship with
  /// their own already-coloured fringe.
  static const Set<String> _tintTopOnly = {'grass_block'};

  BlockFaces facesFor(BlockState state) {
    final key = state.toStateString();
    final cached = _cache[key];
    if (cached != null) return cached;
    final resolved = _resolve(state);
    _cache[key] = resolved;
    return resolved;
  }

  BlockFaces _resolve(BlockState state) {
    final name = state.shortName;
    final variant = _selectVariant(name, state.properties);

    var textures = <String, String>{};
    if (variant != null) {
      final modelName = _stripNamespace(variant.model);
      textures = _collectTextures(modelName, 0);
    }
    if (textures.isEmpty) {
      // No model, or a model that resolved to nothing. Guess at the texture
      // that shares the block's name, which covers most simple blocks even
      // from a resource pack that only replaces textures.
      textures = {'all': 'block/$name'};
    }

    final faces = List<String?>.filled(6, null);
    final tints = List<int>.filled(6, 0xFFFFFFFF);
    final tint = _tints[name];

    for (var i = 0; i < CubeFace.renderOrder.length; i++) {
      final face = CubeFace.renderOrder[i];
      // The variant may rotate the model, so the texture shown on this face is
      // the one the unrotated model had on whichever face rotates onto it.
      final sourceFace = variant == null
          ? face
          : _unrotate(face, variant.x, variant.y);
      faces[i] = _textureForFace(textures, sourceFace);
      if (tint != null &&
          (!_tintTopOnly.contains(name) || face == CubeFace.up)) {
        tints[i] = tint;
      }
    }

    return BlockFaces(faces, tints);
  }

  /// Picks the model entry from a blockstate file that matches [properties].
  _Variant? _selectVariant(String block, Map<String, String> properties) {
    final raw = blockstates[block];
    if (raw == null) return null;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final variants = json['variants'];
    if (variants is Map) {
      // An empty key matches everything; otherwise every `k=v` in the key has
      // to hold. Prefer the most specific match that fits.
      _Variant? best;
      var bestScore = -1;
      variants.forEach((key, value) {
        final conditions = (key as String).isEmpty
            ? const <String, String>{}
            : _parseConditions(key);
        var score = 0;
        for (final entry in conditions.entries) {
          if (properties[entry.key] != entry.value) {
            score = -1;
            break;
          }
          score++;
        }
        if (score > bestScore) {
          final chosen = value is List ? (value.isEmpty ? null : value.first) : value;
          if (chosen is Map) {
            bestScore = score;
            best = _Variant.fromJson(chosen);
          }
        }
      });
      return best;
    }

    final multipart = json['multipart'];
    if (multipart is List) {
      // Multipart blocks (fences, walls, redstone) stack several models. For a
      // block-sized preview the first applicable part is the representative
      // one — it is the post or the centre piece.
      for (final part in multipart) {
        if (part is! Map) continue;
        final when = part['when'];
        if (when is Map && !_multipartMatches(when, properties)) continue;
        final apply = part['apply'];
        final chosen = apply is List ? (apply.isEmpty ? null : apply.first) : apply;
        if (chosen is Map) return _Variant.fromJson(chosen);
      }
    }
    return null;
  }

  bool _multipartMatches(Map<dynamic, dynamic> when, Map<String, String> props) {
    final or = when['OR'];
    if (or is List) {
      for (final clause in or) {
        if (clause is Map && _multipartMatches(clause, props)) return true;
      }
      return false;
    }
    for (final entry in when.entries) {
      if (entry.key == 'OR' || entry.key == 'AND') continue;
      final expected = '${entry.value}'.split('|');
      if (!expected.contains(props[entry.key])) return false;
    }
    return true;
  }

  static Map<String, String> _parseConditions(String key) {
    final out = <String, String>{};
    for (final pair in key.split(',')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      out[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
    }
    return out;
  }

  /// Walks a model's `parent` chain and merges the `textures` maps, child
  /// winning, then resolves the `#reference` values once over the result.
  ///
  /// Resolving per model on the way up would be wrong: a parent like
  /// `block/orientable` says `"north": "#front"` while only the child defines
  /// `front`, so a reference has to be looked up in the *merged* map rather
  /// than in the scope of the model that wrote it.
  Map<String, String> _collectTextures(String modelName, int depth) {
    final merged = _mergeTextures(modelName, depth);

    final resolved = <String, String>{};
    merged.forEach((key, value) {
      var current = value;
      for (var i = 0; i < 8 && current.startsWith('#'); i++) {
        final next = merged[current.substring(1)];
        if (next == null) break;
        current = next;
      }
      if (!current.startsWith('#')) resolved[key] = _stripNamespace(current);
    });
    return resolved;
  }

  /// The raw `textures` entries of a model and everything it inherits from,
  /// with `#` references left alone.
  Map<String, String> _mergeTextures(String modelName, int depth) {
    if (depth > 12) return <String, String>{};
    final raw = models[modelName];
    if (raw == null) return <String, String>{};

    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, String>{};
    }

    final parent = json['parent'];
    final merged = parent is String
        ? _mergeTextures(_stripNamespace(parent), depth + 1)
        : <String, String>{};

    final textures = json['textures'];
    if (textures is Map) {
      textures.forEach((key, value) {
        if (value is String) merged['$key'] = value;
      });
    }
    return merged;
  }

  /// Model texture keys, in the order to try them for each face.
  static const Map<CubeFace, List<String>> _faceKeys = {
    CubeFace.up: ['up', 'top', 'end', 'all', 'texture', 'side', 'cross'],
    CubeFace.down: ['down', 'bottom', 'end', 'all', 'texture', 'side', 'cross'],
    CubeFace.north: ['north', 'side', 'all', 'texture', 'cross', 'front'],
    CubeFace.south: ['south', 'side', 'all', 'texture', 'cross', 'front'],
    CubeFace.east: ['east', 'side', 'all', 'texture', 'cross', 'front'],
    CubeFace.west: ['west', 'side', 'all', 'texture', 'cross', 'front'],
  };

  static String? _textureForFace(Map<String, String> textures, CubeFace face) {
    for (final key in _faceKeys[face]!) {
      final value = textures[key];
      if (value != null) return value;
    }
    // Last resort: anything but the particle texture, which is only a colour
    // hint and is often a completely different block.
    for (final entry in textures.entries) {
      if (entry.key != 'particle') return entry.value;
    }
    return textures['particle'];
  }

  /// Rotating a model by `x`/`y` moves textures onto different faces, so to
  /// paint face [face] we need the texture the unrotated model had on the face
  /// that rotates onto it.
  static CubeFace _unrotate(CubeFace face, int x, int y) {
    var current = face;
    // Undo y first, then x, reversing the order the game applies them.
    for (var i = 0; i < ((360 - (y % 360)) ~/ 90) % 4; i++) {
      current = _rotateY90(current);
    }
    for (var i = 0; i < ((360 - (x % 360)) ~/ 90) % 4; i++) {
      current = _rotateX90(current);
    }
    return current;
  }

  static CubeFace _rotateY90(CubeFace face) => switch (face) {
        CubeFace.north => CubeFace.east,
        CubeFace.east => CubeFace.south,
        CubeFace.south => CubeFace.west,
        CubeFace.west => CubeFace.north,
        _ => face,
      };

  static CubeFace _rotateX90(CubeFace face) => switch (face) {
        CubeFace.down => CubeFace.north,
        CubeFace.north => CubeFace.up,
        CubeFace.up => CubeFace.south,
        CubeFace.south => CubeFace.down,
        _ => face,
      };

  static String _stripNamespace(String value) {
    final colon = value.indexOf(':');
    return colon < 0 ? value : value.substring(colon + 1);
  }
}

class _Variant {
  const _Variant(this.model, this.x, this.y);

  final String model;
  final int x;
  final int y;

  factory _Variant.fromJson(Map<dynamic, dynamic> json) => _Variant(
        '${json['model'] ?? ''}',
        (json['x'] as num?)?.toInt() ?? 0,
        (json['y'] as num?)?.toInt() ?? 0,
      );
}

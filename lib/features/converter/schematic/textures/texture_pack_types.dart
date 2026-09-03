import 'dart:typed_data';

/// A place block textures can be read from: a Minecraft client jar, or a
/// resource pack zip.
class TexturePackSource {
  const TexturePackSource({
    required this.path,
    required this.label,
    required this.version,
    this.isResourcePack = false,
  });

  /// Absolute path to the `.jar` or `.zip`.
  final String path;

  /// What to show the user, e.g. "Minecraft 1.21.4".
  final String label;

  /// The version id the file was found under, used to prefer newer ones.
  final String version;

  final bool isResourcePack;
}

/// The raw asset bytes pulled out of a pack, before they become an atlas.
class RawTextureData {
  const RawTextureData({
    required this.textures,
    required this.blockstates,
    required this.models,
    required this.label,
  });

  /// `block/<name>` to the raw PNG bytes.
  final Map<String, Uint8List> textures;

  /// Block name to the raw `blockstates/<name>.json` text.
  final Map<String, String> blockstates;

  /// `block/<name>` to the raw `models/<name>.json` text.
  final Map<String, String> models;

  /// Where these came from, for the UI to name.
  final String label;

  bool get isEmpty => textures.isEmpty;
}

/// An atlas ready to be uploaded as an image: tightly packed RGBA pixels plus
/// the index that says which tile each texture landed on.
class AtlasBitmap {
  const AtlasBitmap({
    required this.pixels,
    required this.width,
    required this.height,
    required this.tileStride,
    required this.tileSize,
    required this.columns,
    required this.tiles,
    required this.transparentTextures,
    required this.blockstates,
    required this.models,
    required this.label,
  });

  /// RGBA8888, [width] * [height] * 4 bytes.
  final Uint8List pixels;
  final int width;
  final int height;

  /// Distance between tile origins, which is [tileSize] plus the one-pixel
  /// border each tile carries.
  final int tileStride;

  /// Size of the usable image inside each tile.
  final int tileSize;

  final int columns;

  /// Texture name (`block/stone`) to tile index.
  final Map<String, int> tiles;

  /// Textures with at least one non-opaque pixel — leaves, glass, iron bars.
  /// The renderer must not treat these as hiding whatever is behind them.
  final Set<String> transparentTextures;

  /// Block name to its raw `blockstates/<name>.json`, carried along so the
  /// whole read is a single hop off the UI isolate.
  final Map<String, String> blockstates;

  /// `block/<name>` to its raw `models/<name>.json`.
  final Map<String, String> models;

  final String label;
}

/// The reserved tile of plain white pixels every atlas carries.
///
/// Faces are shaded by multiplying their texture with a vertex colour, so a
/// block that has no texture can ride along in the same pass — and therefore
/// the same single draw call — by pointing at a white tile and letting its
/// flat colour through unchanged.
const String kSolidTileName = 'luma:solid';

/// How far along a texture download is, for the UI to show.
class TextureDownloadProgress {
  const TextureDownloadProgress({
    required this.stage,
    this.received = 0,
    this.total = 0,
  });

  /// What the downloader is doing, phrased for the user.
  final String stage;

  final int received;
  final int total;

  /// 0..1 once the total is known, null while it is not.
  double? get fraction =>
      total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

class TextureDownloadException implements Exception {
  TextureDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

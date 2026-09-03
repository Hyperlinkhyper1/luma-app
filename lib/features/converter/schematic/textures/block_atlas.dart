import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../schematic_model.dart';
import 'block_model_resolver.dart';
import 'texture_downloader.dart';
import 'texture_pack_source.dart';

/// A loaded block-texture atlas plus the model data needed to decide which
/// tile goes on which face.
///
/// One of these is built per app run and shared by every preview, because
/// unpacking a client jar is a second or two of work.
class BlockAtlas {
  BlockAtlas._({
    required this.image,
    required this.resolver,
    required this.label,
    required this.tiles,
    required this.transparentTextures,
    required this.columns,
    required this.tileStride,
    required this.tileSize,
    required this.width,
    required this.height,
  });

  final ui.Image image;
  final BlockModelResolver resolver;

  /// Where the textures came from, e.g. "Minecraft 1.21.4".
  final String label;

  final Map<String, int> tiles;
  final Set<String> transparentTextures;
  final int columns;
  final int tileStride;
  final int tileSize;
  final int width;
  final int height;

  int get textureCount => tiles.length;

  /// The atlas pixel rectangle for a texture name, or null when the pack has
  /// no such texture.
  ///
  /// Returned in atlas pixels because that is what [ui.Vertices]'
  /// `textureCoordinates` wants when the shader is an untransformed
  /// [ui.ImageShader].
  ({double left, double top, double right, double bottom})? uvFor(
    String? name,
  ) {
    if (name == null) return null;
    final index = tiles[name];
    if (index == null) return null;
    final left = (index % columns) * tileStride + 1.0;
    final top = (index ~/ columns) * tileStride + 1.0;
    return (
      left: left,
      top: top,
      right: left + tileSize,
      bottom: top + tileSize,
    );
  }

  /// The reserved all-white tile. A face pointed here shows its vertex colour
  /// unchanged, which is how untextured blocks share the textured draw call.
  late final ({double left, double top, double right, double bottom}) solidUv =
      uvFor(kSolidTileName) ??
          (left: 0, top: 0, right: tileSize.toDouble(), bottom: tileSize.toDouble());

  /// Per-face atlas rectangles and tints for one block state. Faces are in the
  /// renderer's order (+X, -X, +Y, -Y, +Z, -Z).
  BlockFaceTextures texturesFor(BlockState state) {
    final faces = resolver.facesFor(state);
    final rects = <({double left, double top, double right, double bottom})?>[];
    var transparent = false;
    for (var i = 0; i < 6; i++) {
      final name = faces.textures[i];
      rects.add(uvFor(name));
      if (name != null && transparentTextures.contains(name)) transparent = true;
    }
    return BlockFaceTextures(rects, faces.tints, transparent);
  }

  bool get isUsable => width > 0 && height > 0 && tiles.isNotEmpty;

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  static Future<BlockAtlas?>? _pending;
  static BlockAtlas? _current;
  static String? _failure;

  /// The atlas if one has already been loaded this run.
  static BlockAtlas? get current => _current;

  /// Why the last load attempt produced nothing, for the UI to explain.
  static String? get failure => _failure;

  /// Set false to stop [load] going and looking at the filesystem. Tests turn
  /// this off so they do not depend on whether the machine running them has
  /// Minecraft installed.
  static bool autoLoad = true;

  /// Loads the atlas once per app run. Concurrent callers share one future.
  static Future<BlockAtlas?> load() {
    final existing = _current;
    if (existing != null) return Future<BlockAtlas?>.value(existing);
    if (!autoLoad) return Future<BlockAtlas?>.value(null);
    return _pending ??= _load();
  }

  /// Rebuilds from a specific jar or resource pack, replacing whatever is
  /// loaded — used when the user picks a pack by hand.
  static Future<BlockAtlas?> loadFrom(String path) async {
    _current = null;
    _pending = null;
    await saveTextureSourcePath(path);
    return _pending ??= _load(explicitPath: path);
  }

  /// Fetches the vanilla client jar from Mojang and builds the atlas from it.
  ///
  /// For the common case of a machine that has never had Minecraft on it. The
  /// preview needs textures from somewhere, and "go and install the game
  /// first" is not an answer.
  static Future<BlockAtlas?> downloadAndLoad({
    void Function(TextureDownloadProgress)? onProgress,
  }) async {
    try {
      final path = await downloadVanillaTextures(onProgress: onProgress);
      return await loadFrom(path);
    } catch (e) {
      _current = null;
      _pending = null;
      _failure = e is TextureDownloadException
          ? e.message
          : 'Could not download block textures: $e';
      return null;
    }
  }

  static Future<BlockAtlas?> _load({String? explicitPath}) async {
    try {
      var path = explicitPath ?? await loadSavedTextureSourcePath();
      if (path == null) {
        final sources = await findTextureSources();
        if (sources.isEmpty) {
          _failure = 'No Minecraft installation found on this device.';
          _pending = null;
          return null;
        }
        path = sources.first.path;
      }

      // Unzipping a client jar and decoding a few thousand PNGs would drop
      // frames for seconds on the UI isolate.
      final bitmap = await compute(readAndBuildAtlas, path);
      if (bitmap.width == 0 || bitmap.tiles.isEmpty) {
        _failure = 'That file has no block textures in it.';
        _pending = null;
        return null;
      }

      final image = await _decode(bitmap);
      final atlas = BlockAtlas._(
        image: image,
        resolver: BlockModelResolver(
          blockstates: bitmap.blockstates,
          models: bitmap.models,
        ),
        label: bitmap.label,
        tiles: bitmap.tiles,
        transparentTextures: bitmap.transparentTextures,
        columns: bitmap.columns,
        tileStride: bitmap.tileStride,
        tileSize: bitmap.tileSize,
        width: bitmap.width,
        height: bitmap.height,
      );
      _current = atlas;
      _failure = null;
      return atlas;
    } catch (e) {
      _failure = 'Could not read block textures: $e';
      _pending = null;
      return null;
    }
  }

  /// Builds an atlas from an already-packed bitmap, without touching the
  /// filesystem. Lets tests exercise the textured render path against a known
  /// set of pixels instead of whatever Minecraft happens to be installed.
  @visibleForTesting
  static Future<BlockAtlas> fromBitmap(AtlasBitmap bitmap) async =>
      BlockAtlas._(
        image: await _decode(bitmap),
        resolver: BlockModelResolver(
          blockstates: bitmap.blockstates,
          models: bitmap.models,
        ),
        label: bitmap.label,
        tiles: bitmap.tiles,
        transparentTextures: bitmap.transparentTextures,
        columns: bitmap.columns,
        tileStride: bitmap.tileStride,
        tileSize: bitmap.tileSize,
        width: bitmap.width,
        height: bitmap.height,
      );

  /// Makes [atlas] the one every preview picks up, as a real load would.
  @visibleForTesting
  static void installForTesting(BlockAtlas? atlas) {
    _current = atlas;
    _pending = null;
    _failure = null;
  }

  /// Forgets any loaded atlas, so one test cannot leak into the next.
  @visibleForTesting
  static void resetForTesting() {
    _current = null;
    _pending = null;
    _failure = null;
  }

  static Future<ui.Image> _decode(AtlasBitmap bitmap) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bitmap.pixels,
      bitmap.width,
      bitmap.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// Atlas rectangles and tints for the six faces of one block.
class BlockFaceTextures {
  const BlockFaceTextures(this.rects, this.tints, this.hasTransparency);

  final List<({double left, double top, double right, double bottom})?> rects;
  final List<int> tints;

  /// True when any face texture has holes in it, so the block must not be
  /// treated as hiding its neighbours.
  final bool hasTransparency;

  bool get hasAny => rects.any((r) => r != null);
}

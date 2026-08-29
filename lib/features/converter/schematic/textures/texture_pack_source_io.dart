import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'texture_pack_types.dart';

/// Finds and reads the block assets out of the player's own Minecraft
/// installation.
///
/// luma ships no Minecraft textures — they are Mojang's, not ours to
/// redistribute — so the preview borrows them from a copy of the game that is
/// already on this machine: the one luma's own launcher plugin downloaded, or
/// a standard `.minecraft` install, or a jar/resource pack the user points at.

/// Where the user's manual choice is remembered between runs.
Future<File> _choiceFile() async {
  final support = await getApplicationSupportDirectory();
  return File(
    '${support.path}${Platform.pathSeparator}schematic_texture_source.txt',
  );
}

Future<String?> loadSavedTextureSourcePath() async {
  try {
    final file = await _choiceFile();
    if (!await file.exists()) return null;
    final path = (await file.readAsString()).trim();
    if (path.isEmpty || !await File(path).exists()) return null;
    return path;
  } catch (_) {
    return null;
  }
}

Future<void> saveTextureSourcePath(String path) async {
  try {
    await (await _choiceFile()).writeAsString(path);
  } catch (_) {
    // A missing support directory only costs us the remembered choice.
  }
}

/// Every directory that might hold a `versions/<id>/<id>.jar` tree: the
/// official launcher's, and the third-party launchers that copy its layout.
List<Directory> _gameDirectories() {
  final dirs = <Directory>[];
  final env = Platform.environment;

  void add(String? base, List<String> relatives) {
    if (base == null) return;
    for (final relative in relatives) {
      dirs.add(Directory(
        '$base${Platform.pathSeparator}'
        '${relative.replaceAll('/', Platform.pathSeparator)}',
      ));
    }
  }

  if (Platform.isWindows) {
    add(env['APPDATA'], const [
      '.minecraft',
      'PrismLauncher',
      'com.modrinth.theseus/meta',
      '.technic/modpacks',
    ]);
    add(env['USERPROFILE'], const [
      'curseforge/minecraft/Install',
      'AppData/Local/Packages/Microsoft.4297127D64EC6_8wekyb3d8bbwe',
      'Documents/ATLauncher',
      'ATLauncher',
      'OneDrive/ATLauncher',
    ]);
    add(env['LOCALAPPDATA'], const ['Packages/GDLauncher']);
  } else if (Platform.isMacOS) {
    add(env['HOME'], const [
      'Library/Application Support/minecraft',
      'Library/Application Support/PrismLauncher',
      'Library/Application Support/com.modrinth.theseus/meta',
      'Library/Application Support/ATLauncher',
    ]);
  } else {
    add(env['HOME'], const [
      '.minecraft',
      '.local/share/PrismLauncher',
      '.local/share/multimc',
      '.var/app/com.mojang.Minecraft/data/minecraft',
      '.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher',
      'ATLauncher',
    ]);
  }
  return dirs;
}

/// Compares Minecraft version ids so 1.21.4 sorts above 1.9, and snapshots or
/// modded ids sort below releases.
int compareVersionIds(String a, String b) {
  final releaseA = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?$').firstMatch(a);
  final releaseB = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?$').firstMatch(b);
  if (releaseA == null && releaseB == null) return b.compareTo(a);
  if (releaseA == null) return 1;
  if (releaseB == null) return -1;
  for (var group = 1; group <= 3; group++) {
    final va = int.tryParse(releaseA.group(group) ?? '0') ?? 0;
    final vb = int.tryParse(releaseB.group(group) ?? '0') ?? 0;
    if (va != vb) return vb.compareTo(va);
  }
  return 0;
}

Future<List<TexturePackSource>> findTextureSources() async {
  final found = <TexturePackSource>[];

  final roots = <Directory>[];
  try {
    final support = await getApplicationSupportDirectory();
    roots.add(Directory(
      '${support.path}${Platform.pathSeparator}minecraft',
    ));
  } catch (_) {
    // No support directory (unusual); the standard game dirs may still work.
  }
  roots.addAll(_gameDirectories());

  for (final root in roots) {
    final versions = Directory(
      '${root.path}${Platform.pathSeparator}versions',
    );
    if (!await versions.exists()) continue;
    await for (final entry in versions.list()) {
      if (entry is! Directory) continue;
      final id = entry.path.split(Platform.pathSeparator).last;
      final jar = File(
        '${entry.path}${Platform.pathSeparator}$id.jar',
      );
      if (!await jar.exists()) continue;
      // A client jar has the assets in it; a tiny one is a loader stub.
      if (await jar.length() < 1024 * 512) continue;
      found.add(TexturePackSource(
        path: jar.path,
        label: 'Minecraft $id',
        version: id,
      ));
    }
  }

  found.sort((a, b) => compareVersionIds(a.version, b.version));

  // A resource pack has no block models, but its textures alone still give
  // almost every block the right face — so it beats flat colours when no
  // client jar turned up.
  if (found.isEmpty) {
    for (final root in roots) {
      final packs = Directory(
        '${root.path}${Platform.pathSeparator}resourcepacks',
      );
      if (!await packs.exists()) continue;
      await for (final entry in packs.list()) {
        if (entry is! File || !entry.path.toLowerCase().endsWith('.zip')) {
          continue;
        }
        final name = entry.path.split(Platform.pathSeparator).last;
        found.add(TexturePackSource(
          path: entry.path,
          label: name.substring(0, name.length - 4),
          version: '',
          isResourcePack: true,
        ));
      }
    }
  }

  return found;
}

/// Reads every block texture, blockstate and model out of [path].
///
/// Runs off the UI isolate — a client jar holds several thousand entries and
/// inflating them all takes long enough to drop frames.
RawTextureData readTexturePack(String path) {
  final file = File(path);
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());

  final textures = <String, Uint8List>{};
  final blockstates = <String, String>{};
  final models = <String, String>{};

  for (final entry in archive.files) {
    if (!entry.isFile) continue;
    final name = entry.name;
    if (!name.startsWith('assets/minecraft/')) continue;

    if (name.startsWith('assets/minecraft/textures/block/') &&
        name.endsWith('.png')) {
      final key = 'block/${name.substring(
        'assets/minecraft/textures/block/'.length,
        name.length - 4,
      )}';
      textures[key] = Uint8List.fromList(entry.content as List<int>);
    } else if (name.startsWith('assets/minecraft/blockstates/') &&
        name.endsWith('.json')) {
      final key = name.substring(
        'assets/minecraft/blockstates/'.length,
        name.length - 5,
      );
      blockstates[key] = utf8.decode(
        entry.content as List<int>,
        allowMalformed: true,
      );
    } else if (name.startsWith('assets/minecraft/models/block/') &&
        name.endsWith('.json')) {
      final key = 'block/${name.substring(
        'assets/minecraft/models/block/'.length,
        name.length - 5,
      )}';
      models[key] = utf8.decode(
        entry.content as List<int>,
        allowMalformed: true,
      );
    }
  }

  final label = file.uri.pathSegments.isEmpty
      ? path
      : file.uri.pathSegments.last.replaceAll('.jar', '');
  return RawTextureData(
    textures: textures,
    blockstates: blockstates,
    models: models,
    label: label,
  );
}

/// The size every texture is normalised to. Vanilla is 16×16; a high
/// resolution resource pack is scaled down to keep the atlas small, which
/// costs nothing at the scale the preview draws blocks.
const int _tileSize = 16;

/// Each tile is padded by a pixel of replicated edge so that neighbouring
/// tiles can never bleed into each other along a seam.
const int _tilePadding = 1;

/// Decodes every texture and packs them into one RGBA bitmap.
AtlasBitmap buildAtlas(RawTextureData data) {
  const stride = _tileSize + _tilePadding * 2;

  final names = data.textures.keys.toList()..sort();
  final decoded = <String, img.Image>{};
  final transparent = <String>{};
  for (final name in names) {
    final bytes = data.textures[name];
    if (bytes == null) continue;
    img.Image? frame;
    try {
      frame = img.decodePng(bytes);
    } catch (_) {
      frame = null;
    }
    if (frame == null) continue;

    // Animated textures are a vertical strip of frames; the first one is what
    // the block looks like at rest.
    if (frame.height > frame.width && frame.width > 0) {
      frame = img.copyCrop(
        frame,
        x: 0,
        y: 0,
        width: frame.width,
        height: frame.width,
      );
    }
    if (frame.width != _tileSize || frame.height != _tileSize) {
      frame = img.copyResize(
        frame,
        width: _tileSize,
        height: _tileSize,
        interpolation: img.Interpolation.nearest,
      );
    }
    // Leaves, glass and bars have holes in them, and a block wearing one must
    // not be treated as hiding whatever sits behind it.
    for (var y = 0; y < frame.height && !transparent.contains(name); y++) {
      for (var x = 0; x < frame.width; x++) {
        if (frame.getPixel(x, y).a < 250) {
          transparent.add(name);
          break;
        }
      }
    }

    decoded[name] = frame;
  }

  // A pack with no block textures in it is not a pack this can use, and must
  // not come back looking like a one-tile atlas that paints everything white.
  if (decoded.isEmpty) {
    return AtlasBitmap(
      pixels: Uint8List(0),
      width: 0,
      height: 0,
      tileStride: stride,
      tileSize: _tileSize,
      columns: 1,
      tiles: const <String, int>{},
      transparentTextures: const <String>{},
      blockstates: data.blockstates,
      models: data.models,
      label: data.label,
    );
  }

  // One extra all-white tile, so untextured blocks ride along in the same
  // draw call as textured ones.
  final solid = img.Image(width: _tileSize, height: _tileSize);
  img.fill(solid, color: img.ColorRgba8(255, 255, 255, 255));
  decoded[kSolidTileName] = solid;

  final count = decoded.length;
  if (count == 0) {
    return AtlasBitmap(
      pixels: Uint8List(0),
      width: 0,
      height: 0,
      tileStride: stride,
      tileSize: _tileSize,
      columns: 1,
      tiles: const <String, int>{},
      transparentTextures: const <String>{},
      blockstates: data.blockstates,
      models: data.models,
      label: data.label,
    );
  }

  var columns = 1;
  while (columns * columns < count) {
    columns++;
  }
  final rows = (count + columns - 1) ~/ columns;
  final width = columns * stride;
  final height = rows * stride;
  final pixels = Uint8List(width * height * 4);

  void put(int x, int y, int r, int g, int b, int a) {
    final offset = (y * width + x) * 4;
    pixels[offset] = r;
    pixels[offset + 1] = g;
    pixels[offset + 2] = b;
    pixels[offset + 3] = a;
  }

  final tiles = <String, int>{};
  var index = 0;
  for (final entry in decoded.entries) {
    final tileX = (index % columns) * stride;
    final tileY = (index ~/ columns) * stride;
    final image = entry.value;

    // Write the tile plus a one-pixel border of replicated edge pixels, so
    // sampling right at a tile edge can never pick up its neighbour.
    for (var y = -_tilePadding; y < _tileSize + _tilePadding; y++) {
      final sy = y.clamp(0, _tileSize - 1);
      for (var x = -_tilePadding; x < _tileSize + _tilePadding; x++) {
        final sx = x.clamp(0, _tileSize - 1);
        final pixel = image.getPixel(sx, sy);
        put(
          tileX + _tilePadding + x,
          tileY + _tilePadding + y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          pixel.a.toInt(),
        );
      }
    }

    tiles[entry.key] = index;
    index++;
  }

  return AtlasBitmap(
    pixels: pixels,
    width: width,
    height: height,
    tileStride: stride,
    tileSize: _tileSize,
    columns: columns,
    tiles: tiles,
    transparentTextures: transparent,
    blockstates: data.blockstates,
    models: data.models,
    label: data.label,
  );
}

/// Reads a pack and packs it in one go, so the whole job is a single hop onto
/// a background isolate.
AtlasBitmap readAndBuildAtlas(String path) => buildAtlas(readTexturePack(path));

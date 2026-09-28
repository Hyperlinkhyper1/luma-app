import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import '../../../../converter/schematic/textures/texture_pack_source.dart';

/// Files the Minecraft view borrowed from a copy of the game on this machine.
class VanillaAssets {
  const VanillaAssets({required this.label, required this.files});

  /// E.g. "Minecraft 1.21.4", for the scene to credit.
  final String label;

  /// Path under `assets/minecraft/` to the file's bytes, base64-encoded.
  final Map<String, String> files;
}

/// What the page may ask for: textures and font definitions only, as PNG,
/// JSON or animation metadata. Anything else in the jar stays in the jar.
final _allowedPath = RegExp(
  r'^(textures|font)/[a-z0-9_/.-]+\.(png|json|png\.mcmeta)$',
);

const _maxFiles = 400;

/// Reads [wanted] out of the newest Minecraft client jar on this machine —
/// the one the user picked for the schematic preview if there is one.
///
/// luma ships none of these files: they are Mojang's, and are only ever read
/// from the user's own install (or a jar they chose to download from Mojang)
/// at runtime. Returns null when there is no jar to read.
Future<VanillaAssets?> loadVanillaAssets(Iterable<String> wanted) async {
  final paths = wanted
      .where((p) => _allowedPath.hasMatch(p) && !p.contains('..'))
      .take(_maxFiles)
      .toSet()
      .toList();
  if (paths.isEmpty) return null;

  final saved = await loadSavedTextureSourcePath();
  final sources = await findTextureSources();
  final jars = [
    if (saved != null && saved.toLowerCase().endsWith('.jar'))
      TexturePackSource(path: saved, label: _label(saved), version: ''),
    ...sources.where((s) => !s.isResourcePack),
  ];
  for (final jar in jars) {
    try {
      final files = await Isolate.run(() => _read(jar.path, paths));
      // A jar missing the core textures (a modded stub, a very old version)
      // would leave the hall half vanilla, half not. Try the next one.
      if (files.containsKey('textures/block/oak_planks.png')) {
        return VanillaAssets(label: jar.label, files: files);
      }
    } catch (_) {
      continue;
    }
  }
  return null;
}

Map<String, String> _read(String jarPath, List<String> paths) {
  final input = InputFileStream(jarPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final files = <String, String>{};
    for (final path in paths) {
      final entry = archive.findFile('assets/minecraft/$path');
      if (entry == null || !entry.isFile) continue;
      files[path] = base64Encode(entry.content as List<int>);
    }
    return files;
  } finally {
    input.closeSync();
  }
}

String _label(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final stem = name.endsWith('.jar')
      ? name.substring(0, name.length - 4)
      : name;
  return 'Minecraft $stem';
}

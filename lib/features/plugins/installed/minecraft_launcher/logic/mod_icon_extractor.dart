import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import 'mc_paths.dart';
import 'mod_installer.dart';
import 'safe_path.dart';

/// Pulls the real icon out of an installed mod/resource-pack jar instead of
/// showing the generic puzzle-piece fallback — needed for anything that
/// wasn't installed through the in-app Modrinth browser (manually dropped
/// files, or a modpack import, which never has a `projectIconUrl` to load
/// from the network). Every major loader embeds an icon in the jar itself,
/// so this covers Fabric/Quilt/Forge/NeoForge without depending on the file
/// being on Modrinth at all:
///  - Fabric: `fabric.mod.json`'s `icon` field (a path, or a size->path map).
///  - Quilt: `quilt.mod.json`'s `quilt_loader.icon` field (same shapes).
///  - Forge/NeoForge: `META-INF/mods.toml`'s `logoFile` key.
///  - Generic fallback: a `pack.png`/`icon.png` sitting at the jar root.
///
/// Extracted bytes are cached to disk once per file (under a hidden
/// `.mod_icons/` folder inside the instance) since decoding a jar's full
/// central directory just to pull one entry isn't cheap to repeat on every
/// list rebuild.
class ModIconExtractor {
  const ModIconExtractor._();

  static Future<File?> iconFor({
    required String instanceId,
    required String kind,
    required String fileName,
  }) async {
    final contentDir = await McPaths.instanceSubDir(instanceId, contentFolderFor(kind));
    final jarPath = safeJoin(contentDir.path, fileName);
    if (jarPath == null) return null;

    var jarFile = File(jarPath);
    if (!await jarFile.exists()) {
      // Disabled mods are suffixed with `.disabled` on disk (see
      // ModInstaller.setEnabled) but the DB still holds the plain file name.
      final disabled = File('$jarPath.disabled');
      if (!await disabled.exists()) return null;
      jarFile = disabled;
    }

    final cacheDir = await McPaths.instanceSubDir(instanceId, '.mod_icons');
    final cachePath = safeJoin(cacheDir.path, '$fileName.png');
    if (cachePath == null) return null;
    final cacheFile = File(cachePath);
    if (await cacheFile.exists()) return cacheFile;

    try {
      final bytes = await _extractIconBytes(jarFile);
      if (bytes == null) return null;
      await cacheFile.writeAsBytes(bytes);
      return cacheFile;
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>?> _extractIconBytes(File jarFile) async {
    final archive = ZipDecoder().decodeBytes(await jarFile.readAsBytes());
    final byName = {for (final entry in archive.files) entry.name: entry};

    for (final metaName in const ['fabric.mod.json', 'quilt.mod.json']) {
      final metaEntry = byName[metaName];
      if (metaEntry == null) continue;
      try {
        final json = jsonDecode(utf8.decode(metaEntry.content as List<int>)) as Map<String, dynamic>;
        final iconValue = json['icon'] ?? (json['quilt_loader'] as Map<String, dynamic>?)?['icon'];
        final iconPath = _resolveIconPath(iconValue);
        if (iconPath != null) {
          final iconEntry = byName[iconPath] ?? byName[iconPath.replaceFirst(RegExp(r'^/'), '')];
          if (iconEntry != null) return iconEntry.content as List<int>;
        }
      } catch (_) {
        // Malformed or unexpected metadata shape — fall through to the next
        // strategy rather than failing icon lookup entirely.
      }
    }

    final modsToml = byName['META-INF/mods.toml'];
    if (modsToml != null) {
      try {
        final text = utf8.decode(modsToml.content as List<int>);
        final match = RegExp(r'logoFile\s*=\s*"([^"]+)"').firstMatch(text);
        final logoFile = match?.group(1);
        if (logoFile != null) {
          final iconEntry = byName[logoFile];
          if (iconEntry != null) return iconEntry.content as List<int>;
        }
      } catch (_) {}
    }

    for (final name in const ['pack.png', 'icon.png']) {
      final entry = byName[name];
      if (entry != null) return entry.content as List<int>;
    }

    return null;
  }

  /// `icon` is either a bare path string, or a map of `"<size>": "<path>"`
  /// (Fabric's multi-resolution form) — pick the largest available size.
  static String? _resolveIconPath(dynamic iconValue) {
    if (iconValue is String) return iconValue;
    if (iconValue is Map) {
      final sizes = iconValue.keys.whereType<String>().toList()
        ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
      if (sizes.isNotEmpty) return iconValue[sizes.first] as String?;
    }
    return null;
  }
}

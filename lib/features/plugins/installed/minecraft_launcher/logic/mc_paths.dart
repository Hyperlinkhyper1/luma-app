import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves the on-disk layout under `<app support dir>/minecraft/`, shared
/// by every piece of download/launch logic in this plugin. This whole tree is
/// excluded from [StorageGuardService]'s cap and from sync (see
/// `_excludedDirNames` in storage_guard.dart) since it holds large,
/// device-specific game files rather than user data.
class McPaths {
  const McPaths._();

  static Future<Directory> _ensure(String relative) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
        '${support.path}${Platform.pathSeparator}minecraft${Platform.pathSeparator}$relative');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> root() => _ensure('');
  static Future<Directory> versions() => _ensure('versions');
  static Future<Directory> libraries() => _ensure('libraries');
  static Future<Directory> assetsRoot() => _ensure('assets');
  static Future<Directory> assetsIndexes() => _ensure('assets${Platform.pathSeparator}indexes');
  static Future<Directory> assetsObjects() => _ensure('assets${Platform.pathSeparator}objects');
  static Future<Directory> runtimes() => _ensure('runtimes');
  static Future<Directory> instancesRoot() => _ensure('instances');

  /// Rejects any id that could act as a path segment escape (`..`, slashes,
  /// drive letters). Version ids come from a downloaded manifest and Forge/
  /// NeoForge installer output; instance ids are locally generated hex — but
  /// validating both keeps every McPaths caller traversal-safe by
  /// construction.
  static String _safeSegment(String segment) {
    if (segment.isEmpty ||
        segment == '.' ||
        segment == '..' ||
        segment.contains('/') ||
        segment.contains('\\') ||
        segment.contains(':')) {
      throw ArgumentError.value(segment, 'segment', 'Unsafe path segment');
    }
    return segment;
  }

  static Future<Directory> versionDir(String versionId) =>
      _ensure('versions${Platform.pathSeparator}${_safeSegment(versionId)}');

  static Future<Directory> instanceDir(String instanceId) =>
      _ensure('instances${Platform.pathSeparator}${_safeSegment(instanceId)}');

  static Future<Directory> instanceSubDir(String instanceId, String sub) => _ensure(
      'instances${Platform.pathSeparator}${_safeSegment(instanceId)}${Platform.pathSeparator}${_safeSegment(sub)}');
}

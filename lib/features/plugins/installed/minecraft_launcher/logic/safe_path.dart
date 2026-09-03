import 'dart:io';

/// Resolves an archive-entry- or manifest-style relative path (using '/' as
/// its separator, as in zip entry names and JSON manifest `path` fields)
/// against [baseDir], collapsing `.`/`..` segments and refusing anything
/// that would escape [baseDir] — an absolute path, a drive letter, a UNC
/// path, or a `..` that pops past the root. Returns null if the path is
/// unsafe; callers should skip that entry rather than write it.
///
/// This exists because several places in this plugin write files at a path
/// taken from untrusted input — a zip entry name (world backups, mod
/// loader/native jars, imported modpacks) or a JSON field inside a
/// user-supplied `.mrpack`/`modrinth.index.json` — and a crafted `../../`
/// sequence in any of those would otherwise let the archive write outside
/// the intended instance/natives folder ("Zip Slip").
String? safeJoin(String baseDir, String relativePath) {
  if (relativePath.isEmpty) return null;
  final normalized = relativePath.replaceAll('\\', '/');

  if (normalized.startsWith('/')) return null; // absolute (posix-style)
  if (normalized.startsWith('//')) return null; // UNC (//server/share)
  if (RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) return null; // C:\... drive letter

  final segments = <String>[];
  for (final part in normalized.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isEmpty) return null; // would climb above baseDir
      segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  if (segments.isEmpty) return null;

  return '$baseDir${Platform.pathSeparator}${segments.join(Platform.pathSeparator)}';
}

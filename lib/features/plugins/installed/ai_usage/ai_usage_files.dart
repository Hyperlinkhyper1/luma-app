import 'dart:io';

/// Every file under [root] whose path satisfies [include], found by walking
/// one directory at a time.
///
/// `Directory.list(recursive: true)` aborts the whole walk on the first
/// directory it cannot open, which once made a single scratch-session folder
/// in `~/.claude/projects` (deep enough to pass Windows' 260-character path
/// limit) silently hide every Claude Code log on the device. Here a folder
/// that cannot be listed is skipped and its siblings are still read.
///
/// On Windows a folder whose listing pattern would pass `MAX_PATH` is listed
/// through the `\\?\` long-path prefix instead. Only those folders get the
/// prefix: nothing under them could ever be listed before, so no path a
/// scanner already stored as a key changes spelling.
///
/// A [FileSystemException] still escapes when [root] itself cannot be
/// listed, so callers can tell "found but unreadable" from "found, empty".
Future<List<File>> listFilesTolerant(
  Directory root,
  bool Function(String path) include,
) async {
  final files = <File>[];
  final pending = <Directory>[root];
  var atRoot = true;
  while (pending.isNotEmpty) {
    final dir = pending.removeLast();
    final entities = await _listOne(dir, rethrowErrors: atRoot);
    atRoot = false;
    for (final entity in entities) {
      if (entity is Directory) {
        pending.add(entity);
      } else if (entity is File && include(entity.path)) {
        files.add(entity);
      }
    }
  }
  return files;
}

/// The last path segment of [path], whichever separator it uses.
String fileBaseName(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  return cut < 0 ? path : path.substring(cut + 1);
}

const _windowsMaxPath = 260;
const _longPathPrefix = r'\\?\';

Future<List<FileSystemEntity>> _listOne(
  Directory dir, {
  required bool rethrowErrors,
}) async {
  try {
    return await _windowsLongPath(dir).list(followLinks: false).toList();
  } on FileSystemException {
    if (rethrowErrors) rethrow;
    return const [];
  }
}

Directory _windowsLongPath(Directory dir) {
  if (!Platform.isWindows) return dir;
  final path = dir.path;
  if (path.startsWith(_longPathPrefix)) return dir;
  if (path.length + 2 < _windowsMaxPath) return dir;
  final absolute = dir.absolute.path.replaceAll('/', r'\');
  if (absolute.startsWith(r'\\')) return dir;
  return Directory('$_longPathPrefix$absolute');
}

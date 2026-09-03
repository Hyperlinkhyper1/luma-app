/// Helpers for the remote side of the browser. The server speaks POSIX no
/// matter what this device runs, so remote paths are always '/'-separated and
/// must never go through `dart:io`'s platform-dependent path handling.
class RemotePath {
  const RemotePath._();

  static const separator = '/';

  /// Appends [name] to [directory], collapsing any duplicate separators.
  static String join(String directory, String name) {
    if (name.startsWith(separator)) return normalize(name);
    final base = directory.isEmpty ? separator : directory;
    return normalize(
      base.endsWith(separator) ? '$base$name' : '$base$separator$name',
    );
  }

  /// The directory containing [path]. The root is its own parent, so walking
  /// up from '/' terminates instead of producing an empty path.
  static String parent(String path) {
    final normalized = normalize(path);
    if (normalized == separator) return separator;
    final cut = normalized.lastIndexOf(separator);
    if (cut <= 0) return separator;
    return normalized.substring(0, cut);
  }

  /// The last segment of [path] — the file or directory's own name.
  static String basename(String path) {
    final normalized = normalize(path);
    if (normalized == separator) return separator;
    return normalized.substring(normalized.lastIndexOf(separator) + 1);
  }

  /// Collapses repeated separators, resolves '.' and '..', and drops the
  /// trailing separator (except on the root itself).
  static String normalize(String path) {
    if (path.isEmpty) return separator;
    final absolute = path.startsWith(separator);
    final out = <String>[];
    for (final segment in path.split(separator)) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (out.isNotEmpty && out.last != '..') {
          out.removeLast();
        } else if (!absolute) {
          out.add('..');
        }
        continue;
      }
      out.add(segment);
    }
    final joined = out.join(separator);
    if (absolute) return '$separator$joined';
    return joined.isEmpty ? '.' : joined;
  }

  /// Every directory from the root down to [path], for the breadcrumb bar.
  static List<({String label, String path})> crumbs(String path) {
    final normalized = normalize(path);
    final crumbs = <({String label, String path})>[
      (label: separator, path: separator),
    ];
    var walked = '';
    for (final segment in normalized.split(separator)) {
      if (segment.isEmpty) continue;
      walked = '$walked$separator$segment';
      crumbs.add((label: segment, path: walked));
    }
    return crumbs;
  }
}

/// Renders a byte count the way a file manager does.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

/// Renders a transfer rate. Zero and non-finite rates render as a dash so a
/// stalled row never shows "NaN/s".
String formatTransferRate(double bytesPerSecond) {
  if (!bytesPerSecond.isFinite || bytesPerSecond <= 0) return '—';
  return '${formatFileSize(bytesPerSecond.round())}/s';
}

/// Turns a POSIX permission bitmask into the `rwxr-xr-x` string the remote
/// pane shows, so permissions read the same here as in a terminal.
String formatPermissions(int? mode) {
  if (mode == null) return '';
  const flags = ['r', 'w', 'x'];
  final out = StringBuffer();
  for (var group = 2; group >= 0; group--) {
    for (var bit = 2; bit >= 0; bit--) {
      final set = (mode & (1 << (group * 3 + bit))) != 0;
      out.write(set ? flags[2 - bit] : '-');
    }
  }
  return out.toString();
}

/// Parses `755` / `rwxr-xr-x` style input from the permissions dialog into a
/// bitmask. Returns null when the text is neither.
int? parsePermissions(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  if (RegExp(r'^[0-7]{3,4}$').hasMatch(text)) {
    return int.parse(text.substring(text.length - 3), radix: 8);
  }
  if (RegExp(r'^[rwx-]{9}$').hasMatch(text)) {
    var mode = 0;
    for (var i = 0; i < 9; i++) {
      if (text[i] != '-') mode |= 1 << (8 - i);
    }
    return mode;
  }
  return null;
}

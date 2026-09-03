import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One entry in the local pane. Deliberately the same shape as
/// [SftpEntry] so both panes can share a list widget.
class LocalEntry {
  const LocalEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
}

/// The local half of the browser. Everything here is plain `dart:io`; the
/// separator is the platform's, unlike the remote side which is always POSIX.
class LocalBrowser {
  const LocalBrowser._();

  static String get separator => Platform.pathSeparator;

  /// Lists [path], directories first then files, each alphabetical.
  /// Unreadable entries (permissions, vanished mid-scan) are skipped rather
  /// than failing the whole listing.
  static Future<List<LocalEntry>> list(String path) async {
    final dir = Directory(path);
    final entries = <LocalEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      try {
        final stat = await entity.stat();
        entries.add(
          LocalEntry(
            name: basename(entity.path),
            path: entity.path,
            isDirectory: stat.type == FileSystemEntityType.directory,
            size: stat.type == FileSystemEntityType.file ? stat.size : 0,
            modified: stat.modified,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  static String basename(String path) {
    final normalized = path.replaceAll('/', separator);
    final trimmed = normalized.endsWith(separator) && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final cut = trimmed.lastIndexOf(separator);
    if (cut < 0) return trimmed;
    final name = trimmed.substring(cut + 1);
    return name.isEmpty ? trimmed : name;
  }

  /// The containing directory, or null at a filesystem root — which is what
  /// disables the up button.
  static String? parent(String path) {
    final dir = Directory(path);
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    return parent.path;
  }

  static String join(String directory, String name) {
    if (directory.endsWith(separator)) return '$directory$name';
    return '$directory$separator$name';
  }

  /// Where the local pane opens when a site has no remembered directory.
  /// Downloads is the folder people actually transfer out of; documents is
  /// the fallback, and the working directory the last resort so a platform
  /// without either still lands the pane somewhere real.
  static Future<String> defaultDirectory() async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null && await downloads.exists()) return downloads.path;
      }
    } catch (_) {
      // Falls through to documents.
    }
    try {
      return (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  /// Top-level places for the pane's root menu: drive letters on Windows,
  /// the filesystem root plus home on Linux, and the app-visible storage
  /// directories on Android, where the whole filesystem isn't readable.
  static Future<List<LocalEntry>> roots() async {
    final roots = <LocalEntry>[];

    if (Platform.isWindows) {
      for (var letter = 'A'.codeUnitAt(0); letter <= 'Z'.codeUnitAt(0); letter++) {
        final path = '${String.fromCharCode(letter)}:\\';
        if (await Directory(path).exists()) {
          roots.add(LocalEntry(name: path, path: path, isDirectory: true));
        }
      }
      return roots;
    }

    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          roots.add(
            LocalEntry(
              name: 'App storage',
              path: external.path,
              isDirectory: true,
            ),
          );
        }
      } catch (_) {
        // Not fatal — the shared directories below are the useful ones.
      }
      for (final path in const [
        '/storage/emulated/0',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/sdcard',
      ]) {
        if (await Directory(path).exists()) {
          roots.add(
            LocalEntry(name: basename(path), path: path, isDirectory: true),
          );
        }
      }
      return roots;
    }

    roots.add(const LocalEntry(name: '/', path: '/', isDirectory: true));
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty && await Directory(home).exists()) {
      roots.add(LocalEntry(name: 'Home', path: home, isDirectory: true));
    }
    return roots;
  }

  /// Breadcrumb segments for [path], each with the path to jump to.
  static List<({String label, String path})> crumbs(String path) {
    final crumbs = <({String label, String path})>[];
    var current = path;
    while (true) {
      crumbs.insert(0, (label: basename(current), path: current));
      final up = parent(current);
      if (up == null || up == current) break;
      current = up;
    }
    return crumbs;
  }

  /// Every file under [path], flattened, each with its path relative to
  /// [path] — what a recursive upload expands a folder into.
  static Future<List<({File file, String relativePath})>> walk(
    String path,
  ) async {
    final results = <({File file, String relativePath})>[];
    final root = Directory(path);
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      var relative = entity.path.substring(path.length);
      relative = relative.replaceAll('\\', '/');
      while (relative.startsWith('/')) {
        relative = relative.substring(1);
      }
      results.add((file: entity, relativePath: relative));
    }
    return results;
  }
}

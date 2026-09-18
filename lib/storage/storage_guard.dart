import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A counted section of luma's local application data.
@immutable
class StorageCategory {
  const StorageCategory({required this.name, required this.bytes});

  final String name;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is StorageCategory && other.name == name && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(name, bytes);
}

/// A file path and size used when aggregating storage categories.
@immutable
class StorageFileEntry {
  const StorageFileEntry({required this.path, required this.bytes});

  final String path;
  final int bytes;
}

/// Reports how much local disk space luma's own data occupies on this
/// device — every local Drift database, JSON store, etc. under the app
/// support directory — broken down by feature. This is purely informational:
/// it does not enforce any cap. The plan's storage figure (see
/// `lib/account/plan.dart`) is a server-side sync quota, tracked and enforced
/// by the sync server, and is unrelated to this local usage number.
class StorageGuardService extends ChangeNotifier {
  /// Set once from `main.dart` so repositories without a `BuildContext` can
  /// read local usage without a `BuildContext`.
  static late StorageGuardService instance;

  /// Subdirectories (relative to the app support directory) excluded from the
  /// sum: one-time tool/binary downloads (yt-dlp, ffmpeg, …) and derived
  /// caches — not user data. `gallery_cache` holds thumbnails and read-back
  /// EXIF for photos that live in the user's own picture folders; every byte
  /// of it can be rebuilt by rescanning, so it would just inflate the
  /// reported usage for no reason.
  /// `luma_shared` is the SFTP plugin's device-to-device folder. It holds
  /// whatever the user chose to move between their own machines — videos,
  /// archives, disk images. It has its own size readout in the plugin
  /// instead.
  /// `ai_catalog_cache` is the AI Usage plugin's downloaded copy of the model
  /// leaderboard: a few hundred KB that is byte-identical for every user and
  /// re-fetchable from the server — data the user never created.
  /// `ai_benchmarks_cache` is the same plugin's downloaded benchmark scenes
  /// and previews: megabytes of HTML the app fetches on demand from the
  /// server, identical for every user.
  static const _excludedDirNames = {
    'tools',
    'ffmpeg',
    'minecraft',
    'gallery_cache',
    'luma_shared',
    'ai_catalog_cache',
    'ai_benchmarks_cache',
  };

  int _usedBytes = 0;
  List<StorageCategory> _breakdown = const [];
  bool _refreshing = false;
  Timer? _debounce;

  int get usedBytes => _usedBytes;
  List<StorageCategory> get breakdown => _breakdown;

  /// Recomputes [usedBytes] by summing every file under the app support
  /// directory (every local Drift database, JSON store, etc. already lives
  /// there, so this stays correct automatically as features are added). Only
  /// user-generated data counts — app binaries and log files are skipped.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final accumulator = _StorageAccumulator(dir.path);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          try {
            accumulator.add(entity.path, await entity.length());
          } catch (_) {
            // File may have been deleted mid-walk — ignore.
          }
        }
      }
      _usedBytes = accumulator.totalBytes;
      _breakdown = accumulator.categories;
      notifyListeners();
    } catch (_) {
      // Leave the last-known usage in place — a transient FS hiccup must not
      // block every write in the app.
    } finally {
      _refreshing = false;
    }
  }

  /// Aggregates file sizes using the same exclusions as [refresh].
  ///
  /// Keeping this small, synchronous seam makes the usage accounting rules
  /// straightforward to test without depending on a host platform's support
  /// directory.
  static List<StorageCategory> aggregateCategories({
    required String rootPath,
    required Iterable<StorageFileEntry> entries,
  }) {
    final accumulator = _StorageAccumulator(rootPath);
    for (final entry in entries) {
      accumulator.add(entry.path, entry.bytes);
    }
    return accumulator.categories;
  }

  static bool _isExcluded(String rootPath, String filePath) {
    // Rotating / append-only logs — not user data.
    if (filePath.toLowerCase().endsWith('.log')) return true;
    return _relativeSegments(rootPath, filePath)
        .any(_excludedDirNames.contains);
  }

  static List<String> _relativeSegments(String rootPath, String filePath) {
    final relative = filePath.startsWith(rootPath)
        ? filePath.substring(rootPath.length)
        : filePath;
    return relative
        .split(RegExp(r'[\\/]'))
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  static String _categoryName(String rootPath, String filePath) {
    final segments = _relativeSegments(rootPath, filePath);
    if (segments.length < 2) {
      return _rootFileCategory(segments.isEmpty ? '' : segments.first);
    }

    return _prettify(segments.first);
  }

  static String _rootFileCategory(String filename) {
    var base = filename;
    // Drift sidecars share the main db's category (foo.sqlite-wal → foo).
    base = base.split('.').first;
    for (var stripped = true; stripped;) {
      stripped = false;
      for (final suffix in ['-wal', '-shm', '-journal']) {
        if (base.toLowerCase().endsWith(suffix)) {
          base = base.substring(0, base.length - suffix.length);
          stripped = true;
        }
      }
    }
    final words = base
        .split(RegExp(r'[_-]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    // Drop the generic app prefix: luma_finance → Finance.
    if (words.length > 1 && words.first.toLowerCase() == 'luma') {
      words.removeAt(0);
    }
    if (words.isEmpty) return 'App data';
    return _prettify(words.join('_'));
  }

  static String _prettify(String raw) {
    final words = raw.split(RegExp(r'[_-]+'));
    final titled = words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    return titled.isEmpty ? 'App data' : titled;
  }

  /// Schedules a debounced [refresh] shortly after a guarded write succeeds —
  /// mirrors `SyncService`'s change-debounce so bursts of writes only trigger
  /// one re-scan.
  void scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), refresh);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _StorageAccumulator {
  _StorageAccumulator(this.rootPath);

  final String rootPath;
  final _bytesByCategory = <String, int>{};
  int totalBytes = 0;

  static const maxCategories = 8;

  void add(String path, int bytes) {
    if (StorageGuardService._isExcluded(rootPath, path)) return;
    final category = StorageGuardService._categoryName(rootPath, path);
    totalBytes += bytes;
    _bytesByCategory[category] = (_bytesByCategory[category] ?? 0) + bytes;
  }

  List<StorageCategory> get categories {
    final categories = _bytesByCategory.entries
        .map((entry) => StorageCategory(name: entry.key, bytes: entry.value))
        .toList()
      ..sort((a, b) {
        final sizeOrder = b.bytes.compareTo(a.bytes);
        return sizeOrder == 0 ? a.name.compareTo(b.name) : sizeOrder;
      });
    if (categories.length <= maxCategories) {
      return List.unmodifiable(categories);
    }
    final top = categories.sublist(0, maxCategories - 1);
    final rest = categories.sublist(maxCategories - 1);
    final otherBytes = rest.fold<int>(0, (sum, c) => sum + c.bytes);
    return List.unmodifiable([
      ...top,
      StorageCategory(name: 'Other', bytes: otherBytes),
    ]);
  }
}

/// Short alias used at call sites (`StorageGuard.instance.scheduleRefresh()`)
/// so repositories read naturally without importing the full service name.
typedef StorageGuard = StorageGuardService;

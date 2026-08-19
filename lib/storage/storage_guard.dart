import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Thrown when a write is rejected because the app is at (or over) its local
/// storage cap. Callers can show `toString()` directly — it's already a
/// friendly, user-facing message.
class StorageLimitExceededException implements Exception {
  const StorageLimitExceededException(this.usedBytes, this.limitBytes);

  final int usedBytes;
  final int limitBytes;

  @override
  String toString() =>
      "You've reached the local storage limit (${StorageGuardService.formatBytes(limitBytes)}). "
      'Free up space or delete old data to save new items.';
}

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

/// A single, app-wide cap on how much luma stores on this device — separate
/// from (and independent of) any per-account cloud quota, and enforced no
/// matter which plugins are installed. Once [isOverLimit], every feature's
/// "create new record" method refuses to write (see [ensureWithinLimit]), and
/// [SyncService] refuses to push to — or pull from — other devices.
class StorageGuardService extends ChangeNotifier {
  /// Set once from `main.dart` so repositories without a `BuildContext` can
  /// call `StorageGuard.instance.ensureWithinLimit()` directly.
  static late StorageGuardService instance;

  /// Subdirectories (relative to the app support directory) excluded from the
  /// sum: one-time tool/binary downloads (yt-dlp, ffmpeg, …) and derived
  /// caches — not user data. `gallery_cache` holds thumbnails and read-back
  /// EXIF for photos that live in the user's own picture folders; every byte
  /// of it can be rebuilt by rescanning, and counting it would put a 30 MB
  /// Nova device over its cap after a few hundred photos.
  /// `luma_shared` is the SFTP plugin's device-to-device folder. It holds
  /// whatever the user chose to move between their own machines — videos,
  /// archives, disk images — and counting it would put a 30 MB Nova device
  /// over its cap with one file. It has its own size readout in the plugin
  /// instead.
  static const _excludedDirNames = {
    'tools',
    'ffmpeg',
    'minecraft',
    'gallery_cache',
    'luma_shared',
  };

  int _limitBytes = _defaultLimitBytes;
  int _usedBytes = 0;
  List<StorageCategory> _breakdown = const [];
  bool _refreshing = false;
  Timer? _debounce;

  /// Fallback cap before `main.dart` has applied the selected plan's limit.
  static const int _defaultLimitBytes = 5 * 1024 * 1024; // 5 MB

  /// The current local storage cap, in bytes — set by [setLimitBytes] from
  /// the active plan (see `planById`).
  int get limitBytes => _limitBytes;
  int get usedBytes => _usedBytes;
  List<StorageCategory> get breakdown => _breakdown;
  bool get isOverLimit => _usedBytes >= _limitBytes;

  /// Updates the storage cap. Passing a different value notifies listeners so
  /// the UI (storage bar, over-limit banner) re-evaluates immediately.
  void setLimitBytes(int bytes) {
    if (bytes == _limitBytes) return;
    _limitBytes = bytes;
    notifyListeners();
  }

  /// Throws [StorageLimitExceededException] if already over the cap. Cheap —
  /// checks the cached usage, no disk I/O.
  void ensureWithinLimit() {
    if (isOverLimit) {
      throw StorageLimitExceededException(_usedBytes, _limitBytes);
    }
  }

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
  /// Keeping this small, synchronous seam makes the cap accounting rules
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
    if (segments.length < 2) return 'App data';

    final words = segments.first.split(RegExp(r'[_-]+'));
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
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
    return List.unmodifiable(categories);
  }
}

/// Short alias used at call sites (`StorageGuard.instance.ensureWithinLimit()`)
/// so repositories read naturally without importing the full service name.
typedef StorageGuard = StorageGuardService;

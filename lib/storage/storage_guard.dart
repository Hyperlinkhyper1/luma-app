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

/// A single, app-wide cap on how much luma stores on this device — separate
/// from (and independent of) any per-account cloud quota, and enforced no
/// matter which plugins are installed. Once [isOverLimit], every feature's
/// "create new record" method refuses to write (see [ensureWithinLimit]), and
/// [SyncService] refuses to push to — or pull from — other devices.
class StorageGuardService extends ChangeNotifier {
  /// Single tunable constant — there's only one tier today since paid plans
  /// don't change behavior yet.
  static const int limitBytes = 1 * 1024 * 1024 * 1024; // 1 GB

  /// Subdirectories (relative to the app support directory) excluded from the
  /// sum: one-time tool binaries, not user data.
  static const _excludedDirNames = {'tools'};

  /// Set once from `main.dart` so repositories without a `BuildContext` can
  /// call `StorageGuard.instance.ensureWithinLimit()` directly.
  static late StorageGuardService instance;

  int _usedBytes = 0;
  bool _refreshing = false;
  Timer? _debounce;

  int get usedBytes => _usedBytes;
  bool get isOverLimit => _usedBytes >= limitBytes;

  /// Throws [StorageLimitExceededException] if already over the cap. Cheap —
  /// checks the cached usage, no disk I/O.
  void ensureWithinLimit() {
    if (isOverLimit) {
      throw StorageLimitExceededException(_usedBytes, limitBytes);
    }
  }

  /// Recomputes [usedBytes] by summing every file under the app support
  /// directory (every local Drift database, JSON store, etc. already lives
  /// there, so this stays correct automatically as features are added).
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final dir = await getApplicationSupportDirectory();
      var total = 0;
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          if (_isExcluded(dir.path, entity.path)) continue;
          try {
            total += await entity.length();
          } catch (_) {
            // File may have been deleted mid-walk — ignore.
          }
        }
      }
      _usedBytes = total;
      notifyListeners();
    } catch (_) {
      // Leave the last-known usage in place — a transient FS hiccup must not
      // block every write in the app.
    } finally {
      _refreshing = false;
    }
  }

  bool _isExcluded(String rootPath, String filePath) {
    final relative = filePath.startsWith(rootPath)
        ? filePath.substring(rootPath.length)
        : filePath;
    final segments = relative
        .split(Platform.pathSeparator)
        .where((s) => s.isNotEmpty);
    return segments.any(_excludedDirNames.contains);
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

/// Short alias used at call sites (`StorageGuard.instance.ensureWithinLimit()`)
/// so repositories read naturally without importing the full service name.
typedef StorageGuard = StorageGuardService;

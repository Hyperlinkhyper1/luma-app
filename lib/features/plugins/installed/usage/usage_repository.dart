import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'data/usage_database.dart';
import 'usage_tracker.dart';

/// Sample interval bounds (seconds) exposed to the settings UI.
const int kUsageMinIntervalSeconds = 2;
const int kUsageMaxIntervalSeconds = 10;

/// Owns Usage's foreground-app poll timer and the session currently being
/// written to [UsageDatabase]. Lives for the app's lifetime (see main.dart)
/// rather than the plugin page's, so tracking keeps running while luma is
/// minimized or the user is elsewhere in the app.
///
/// Sessions are upserted rather than buffered in memory: the moment a new
/// process is seen in the foreground, a row is inserted with
/// `endedAt == startedAt`; every following poll of the same process updates
/// that row's `endedAt`/`durationSeconds` in place. This means a crash or
/// force-quit only loses at most one sample interval of the in-progress
/// session, and range queries can just read the table directly — there's no
/// separate "current session" the UI needs to merge in.
class UsageRepository extends ChangeNotifier {
  UsageRepository(this._db);

  final UsageDatabase _db;
  File? _settingsFile;
  bool _loaded = false;
  bool _disposed = false;

  bool _paused = false;
  int _intervalSeconds = 5;
  Timer? _timer;

  int? _currentSessionId;
  String? _currentProcessName;
  DateTime? _currentStartedAt;
  UsageAppInfo? _currentInfo;

  bool get loaded => _loaded;
  bool get supported => UsageTracker.supported;
  bool get paused => _paused;
  int get intervalSeconds => _intervalSeconds;

  /// The app currently being tracked, or null when paused / nothing focused.
  UsageAppInfo? get currentApp => _currentInfo;

  /// Loads persisted settings and starts polling (unless paused). Call once,
  /// from the app root, before this repository is used by the UI.
  Future<void> init() async {
    await _loadSettings();
    if (!_paused) _startTimer();
  }

  Future<void> _loadSettings() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _settingsFile = File('${dir.path}/luma_usage_settings.json');
      if (await _settingsFile!.exists()) {
        final data =
            jsonDecode(await _settingsFile!.readAsString()) as Map<String, dynamic>;
        _paused = data['paused'] as bool? ?? false;
        _intervalSeconds = ((data['intervalSeconds'] as num?)?.toInt() ??
                _intervalSeconds)
            .clamp(kUsageMinIntervalSeconds, kUsageMaxIntervalSeconds);
      }
    } catch (_) {
      // Best-effort load; defaults stand if the file is missing or corrupt.
    }
    _loaded = true;
    _notify();
  }

  Future<void> _saveSettings() async {
    final file = _settingsFile;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'paused': _paused,
        'intervalSeconds': _intervalSeconds,
      }));
    } catch (_) {
      // Best-effort save; a failure here shouldn't crash the app.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!supported) return;
    _timer = Timer.periodic(
        Duration(seconds: _intervalSeconds), (_) => unawaited(_tick()));
  }

  /// Changes the poll interval and restarts the timer (if running) so the
  /// new cadence takes effect immediately rather than after the next tick.
  void setIntervalSeconds(int seconds) {
    _intervalSeconds =
        seconds.clamp(kUsageMinIntervalSeconds, kUsageMaxIntervalSeconds);
    unawaited(_saveSettings());
    _notify();
    if (!_paused) _startTimer();
  }

  void setPaused(bool value) {
    if (_paused == value) return;
    _paused = value;
    unawaited(_saveSettings());
    if (_paused) {
      _timer?.cancel();
      _timer = null;
      unawaited(_finalizeCurrent());
    } else {
      _startTimer();
    }
    _notify();
  }

  void togglePaused() => setPaused(!_paused);

  Future<void> _tick() async {
    if (_disposed || !supported) return;
    UsageAppInfo? info;
    try {
      info = UsageTracker.current();
    } catch (_) {
      info = null;
    }
    if (_disposed) return;
    await handlePoll(info);
  }

  /// Applies one poll result to the current session: opens a new row when the
  /// foreground process changed, extends the open row otherwise, or finalizes
  /// it when nothing is focused. Split out from [_tick] (which sources [info]
  /// from the platform tracker) so tests can drive it with synthetic samples.
  @visibleForTesting
  Future<void> handlePoll(UsageAppInfo? info) async {
    if (info == null) {
      // Nothing usefully focused (lock screen, no window, ...) — close
      // whatever was open and wait for a real app to come back.
      await _finalizeCurrent();
      return;
    }

    // Only the process identity is a session boundary — switching tabs or
    // windows within the same app (different windowTitle) doesn't split it.
    if (_currentSessionId == null || _currentProcessName != info.processName) {
      await _finalizeCurrent();
      await _openSession(info);
    } else {
      _currentInfo = info;
      await _touchCurrent();
    }
  }

  Future<void> _openSession(UsageAppInfo info) async {
    final now = DateTime.now().toUtc();
    try {
      StorageGuard.instance.ensureWithinLimit();
    } on StorageLimitExceededException {
      // Over the storage cap: skip tracking rather than crash the timer.
      return;
    }
    final id = await _db.into(_db.usageSessions).insert(
          UsageSessionsCompanion.insert(
            appName: info.appName,
            processName: info.processName,
            windowTitle: Value(info.windowTitle),
            startedAt: now,
            endedAt: now,
            durationSeconds: 0,
          ),
        );
    if (_disposed) return;
    _currentSessionId = id;
    _currentProcessName = info.processName;
    _currentStartedAt = now;
    _currentInfo = info;
    _notify();
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> _touchCurrent() async {
    final id = _currentSessionId;
    final startedAt = _currentStartedAt;
    if (id == null || startedAt == null) return;
    final now = DateTime.now().toUtc();
    await (_db.update(_db.usageSessions)..where((t) => t.id.equals(id))).write(
      UsageSessionsCompanion(
        endedAt: Value(now),
        durationSeconds: Value(now.difference(startedAt).inSeconds),
      ),
    );
  }

  Future<void> _finalizeCurrent() async {
    if (_currentSessionId == null) return;
    await _touchCurrent();
    _currentSessionId = null;
    _currentProcessName = null;
    _currentStartedAt = null;
    _currentInfo = null;
    _notify();
  }

  /// Sessions overlapping `[start, end)` (given in local time — [UsageSessions]
  /// stores UTC, so bounds are converted before querying), soonest-starting
  /// first. Live-updates as new sessions are written, including the
  /// currently-open one.
  Stream<List<UsageSession>> watchRange(DateTime start, DateTime end) {
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    final query = _db.select(_db.usageSessions)
      ..where((t) =>
          t.endedAt.isBiggerOrEqualValue(startUtc) &
          t.startedAt.isSmallerThanValue(endUtc))
      ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]);
    return query.watch();
  }

  /// Deletes every stored session, including the one in progress.
  Future<void> clearHistory() async {
    await _finalizeCurrent();
    await _db.delete(_db.usageSessions).go();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_finalizeCurrent());
    _disposed = true;
    super.dispose();
  }
}

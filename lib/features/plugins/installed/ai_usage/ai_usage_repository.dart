import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../storage/storage_guard.dart';
import 'claude_code_scanner.dart';
import 'data/ai_usage_database.dart';

/// Owns the local Claude Code usage scan and the database it fills.
class AiUsageRepository extends ChangeNotifier {
  AiUsageRepository(this._db, {ClaudeCodeScanner? scanner})
      : _scanner = scanner ?? const ClaudeCodeScanner();

  final AiUsageDatabase _db;
  final ClaudeCodeScanner _scanner;

  bool _scanning = false;
  bool? _projectsDirFound; // null = not yet checked
  DateTime? _lastScanAt;
  ClaudeCodeScanResult? _lastScanResult;

  bool get scanning => _scanning;

  /// Whether `~/.claude/projects` was found on this device — null until the
  /// first [rescan] completes.
  bool? get projectsDirFound => _projectsDirFound;
  DateTime? get lastScanAt => _lastScanAt;
  ClaudeCodeScanResult? get lastScanResult => _lastScanResult;

  /// Scans `~/.claude/projects` for new/changed session logs and stores any
  /// new usage. Safe to call repeatedly — unchanged files are skipped
  /// cheaply by [ClaudeCodeScanner], and a scan already in flight is not
  /// duplicated.
  Future<void> rescan() async {
    if (_scanning) return;
    _scanning = true;
    notifyListeners();

    try {
      StorageGuard.instance.ensureWithinLimit();
      final result = await _scanner.scan(_db);
      _lastScanResult = result;
      _projectsDirFound = result.projectsDirFound;
      _lastScanAt = DateTime.now();
      if (result.turnsAdded > 0) {
        StorageGuard.instance.scheduleRefresh();
      }
    } on StorageLimitExceededException {
      // Over the storage cap: skip this scan rather than crash it.
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Turns in `[start, end)`, soonest first. A null [start] is unbounded
  /// ("All time"). Live-updates as [rescan] adds new rows.
  Stream<List<AiUsageTurn>> watchRange(DateTime? start, DateTime end) {
    final endUtc = end.toUtc();
    final query = _db.select(_db.aiUsageTurns)
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    if (start == null) {
      query.where((t) => t.timestamp.isSmallerThanValue(endUtc));
    } else {
      final startUtc = start.toUtc();
      query.where((t) =>
          t.timestamp.isBiggerOrEqualValue(startUtc) &
          t.timestamp.isSmallerThanValue(endUtc));
    }
    return query.watch();
  }
}

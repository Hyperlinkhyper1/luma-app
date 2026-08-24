import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../storage/storage_guard.dart';
import 'ai_usage_source.dart';
import 'antigravity_scanner.dart';
import 'claude_code_scanner.dart';
import 'codex_cli_scanner.dart';
import 'data/ai_usage_database.dart';
import 'opencode_scanner.dart';

/// Owns the local AI-usage scans (Claude Code, Codex CLI, Antigravity,
/// opencode) and the database they fill.
class AiUsageRepository extends ChangeNotifier {
  AiUsageRepository(
    this._db, {
    ClaudeCodeScanner? claudeScanner,
    CodexCliScanner? codexScanner,
    AntigravityScanner? antigravityScanner,
    OpencodeScanner? opencodeScanner,
  })  : _claudeScanner = claudeScanner ?? const ClaudeCodeScanner(),
        _codexScanner = codexScanner ?? const CodexCliScanner(),
        _antigravityScanner = antigravityScanner ?? const AntigravityScanner(),
        _opencodeScanner = opencodeScanner ?? const OpencodeScanner();

  final AiUsageDatabase _db;
  final ClaudeCodeScanner _claudeScanner;
  final CodexCliScanner _codexScanner;
  final AntigravityScanner _antigravityScanner;
  final OpencodeScanner _opencodeScanner;

  bool _scanning = false;
  bool? _claudeCodeDirFound; // null = not yet checked
  bool? _codexCliDirFound;
  bool? _antigravityDirFound;
  bool? _opencodeDbFound;
  DateTime? _lastScanAt;
  ClaudeCodeScanResult? _lastClaudeResult;
  CodexCliScanResult? _lastCodexResult;
  AntigravityScanResult? _lastAntigravityResult;
  OpencodeScanResult? _lastOpencodeResult;

  bool get scanning => _scanning;

  /// Whether `~/.claude/projects` was found on this device — null until the
  /// first [rescan] completes.
  bool? get claudeCodeDirFound => _claudeCodeDirFound;

  /// Whether `~/.codex/sessions` was found on this device — null until the
  /// first [rescan] completes.
  bool? get codexCliDirFound => _codexCliDirFound;

  /// Whether `~/.gemini/antigravity/brain` was found on this device — null
  /// until the first [rescan] completes.
  bool? get antigravityDirFound => _antigravityDirFound;

  /// Whether opencode's `opencode.db` was found on this device — null until
  /// the first [rescan] completes.
  bool? get opencodeDbFound => _opencodeDbFound;

  /// Whether one specific source's logs were found on this device — null
  /// until the first [rescan] completes. Backs the empty-state gate of a
  /// dashboard pinned to a single tool.
  bool? dirFoundFor(AiUsageSource source) => switch (source) {
        AiUsageSource.claudeCode => _claudeCodeDirFound,
        AiUsageSource.codexCli => _codexCliDirFound,
        AiUsageSource.antigravity => _antigravityDirFound,
        AiUsageSource.opencode => _opencodeDbFound,
      };

  /// Whether *any* source was found — drives the page's empty-state gate.
  /// Null until the first [rescan] completes.
  bool? get anyDirFound {
    if (_claudeCodeDirFound == null &&
        _codexCliDirFound == null &&
        _antigravityDirFound == null &&
        _opencodeDbFound == null) {
      return null;
    }
    return (_claudeCodeDirFound ?? false) ||
        (_codexCliDirFound ?? false) ||
        (_antigravityDirFound ?? false) ||
        (_opencodeDbFound ?? false);
  }

  DateTime? get lastScanAt => _lastScanAt;
  ClaudeCodeScanResult? get lastClaudeResult => _lastClaudeResult;
  CodexCliScanResult? get lastCodexResult => _lastCodexResult;
  AntigravityScanResult? get lastAntigravityResult => _lastAntigravityResult;
  OpencodeScanResult? get lastOpencodeResult => _lastOpencodeResult;

  /// Combined new-turn count from the most recent [rescan], across every
  /// source — for the single-line status UI.
  int get lastTurnsAdded =>
      (_lastClaudeResult?.turnsAdded ?? 0) +
      (_lastCodexResult?.turnsAdded ?? 0) +
      (_lastAntigravityResult?.turnsAdded ?? 0) +
      (_lastOpencodeResult?.turnsAdded ?? 0);

  /// Scans every known local source for new/changed session logs and stores
  /// any new usage. Safe to call repeatedly — unchanged files are skipped
  /// cheaply by the scanners, and a scan already in flight is not
  /// duplicated. The scanners touch disjoint file paths and only ever
  /// insert distinctly-sourced rows, so running them concurrently is safe.
  Future<void> rescan() async {
    if (_scanning) return;
    _scanning = true;
    notifyListeners();

    try {
      StorageGuard.instance.ensureWithinLimit();
      final (claudeResult, codexResult, antigravityResult, opencodeResult) = await (
        _claudeScanner.scan(_db),
        _codexScanner.scan(_db),
        _antigravityScanner.scan(_db),
        _opencodeScanner.scan(_db),
      ).wait;
      _lastClaudeResult = claudeResult;
      _lastCodexResult = codexResult;
      _lastAntigravityResult = antigravityResult;
      _lastOpencodeResult = opencodeResult;
      _claudeCodeDirFound = claudeResult.projectsDirFound;
      _codexCliDirFound = codexResult.sessionsDirFound;
      _antigravityDirFound = antigravityResult.brainDirFound;
      _opencodeDbFound = opencodeResult.dbFound;
      _lastScanAt = DateTime.now();
      if (lastTurnsAdded > 0) {
        StorageGuard.instance.scheduleRefresh();
      }
    } on StorageLimitExceededException {
      // Over the storage cap: skip this scan rather than crash it.
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Turns in `[start, end)`, soonest first, across every source. A null
  /// [start] is unbounded ("All time"). Live-updates as [rescan] adds new
  /// rows.
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

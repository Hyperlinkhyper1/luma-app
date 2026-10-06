import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../storage/storage_guard.dart';
import '../../../chat/providers/ai_client.dart';
import 'ai_usage_source.dart';
import 'antigravity_scanner.dart';
import 'claude_code_scanner.dart';
import 'codex_cli_scanner.dart';
import 'data/ai_usage_database.dart';
import 'freebuff_scanner.dart';
import 'opencode_scanner.dart';

/// Owns the local AI-usage scans (Claude Code, Codex CLI, Antigravity,
/// opencode, Freebuff) and the database they fill.
class AiUsageRepository extends ChangeNotifier {
  AiUsageRepository(
    this._db, {
    ClaudeCodeScanner? claudeScanner,
    CodexCliScanner? codexScanner,
    AntigravityScanner? antigravityScanner,
    OpencodeScanner? opencodeScanner,
    FreebuffScanner? freebuffScanner,
    Future<List<Map<String, dynamic>>?> Function()? fetchBackendCalls,
    String? Function()? backendAccount,
  }) : _claudeScanner = claudeScanner ?? const ClaudeCodeScanner(),
       _codexScanner = codexScanner ?? const CodexCliScanner(),
       _antigravityScanner = antigravityScanner ?? const AntigravityScanner(),
       _opencodeScanner = opencodeScanner ?? const OpencodeScanner(),
       _freebuffScanner = freebuffScanner ?? const FreebuffScanner(),
       // ignore: prefer_initializing_formals
       _fetchBackendCalls = fetchBackendCalls,
       // ignore: prefer_initializing_formals
       _backendAccount = backendAccount;

  final AiUsageDatabase _db;
  final Future<List<Map<String, dynamic>>?> Function()? _fetchBackendCalls;
  final String? Function()? _backendAccount;
  bool _refreshingBackend = false;
  bool _backendRefreshPending = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refreshBackendUsage() async {
    if (_disposed || _fetchBackendCalls == null) return;
    if (_refreshingBackend) {
      _backendRefreshPending = true;
      return;
    }
    _refreshingBackend = true;
    try {
      final account = _backendAccount?.call();
      final deviceId = account == null ? null : 'backend:$account';
      await (_db.delete(_db.aiUsageTurns)..where(
            (t) =>
                t.deviceId.like('backend:%') &
                (deviceId == null
                    ? const Constant(true)
                    : t.deviceId.equals(deviceId).not()),
          ))
          .go();
      if (account == null) return;
      final calls = await _fetchBackendCalls();
      if (_disposed || calls == null || _backendAccount?.call() != account) {
        return;
      }
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.aiUsageTurns,
        )..where((t) => t.deviceId.equals(deviceId!))).get();
        final seen = existing.map((t) => t.messageId).toSet();
        for (final call in calls) {
          final id = call['id'];
          final at = call['atMs'];
          if (id is! String || at is! num) continue;
          final messageId = 'backend:$account:$id';
          if (!seen.add(messageId)) continue;
          int count(String key) => call[key] is num
              ? (call[key] as num).toInt().clamp(0, 1 << 40)
              : 0;
          final prompt = count('inputTokens');
          final rawCached = count('cacheReadTokens');
          final cached = rawCached > prompt ? prompt : rawCached;
          final input = prompt - cached;
          final output = count('outputTokens');
          final remainder = count('totalTokens') - prompt;
          final provider = switch (call['upstream']) {
            'Google AI Studio' => 'google',
            'OpenRouter' => 'openrouter',
            'Mistral' => 'mistral',
            _ => 'backend',
          };
          await _db
              .into(_db.aiUsageTurns)
              .insert(
                AiUsageTurnsCompanion.insert(
                  sessionId: 'backend:$account:${call['feature']}',
                  timestamp: DateTime.fromMillisecondsSinceEpoch(
                    at.toInt(),
                    isUtc: true,
                  ),
                  model:
                      '$provider/${_bareModel(call['model'] as String? ?? '')}',
                  source: AiUsageSource.luma,
                  inputTokens: Value(input),
                  cacheReadTokens: Value(cached),
                  outputTokens: Value(
                    output > remainder ? output : remainder.clamp(0, 1 << 40),
                  ),
                  messageId: Value(messageId),
                  project: Value(call['feature'] as String?),
                  reportedCost: Value((call['costUsd'] as num?)?.toDouble()),
                  deviceId: Value(deviceId),
                ),
              );
        }
      });
      final lumaTurn =
          await (_db.select(_db.aiUsageTurns)
                ..where((t) => t.source.equalsValue(AiUsageSource.luma))
                ..limit(1))
              .getSingleOrNull();
      _lumaUsageFound = lumaTurn != null;
    } catch (error) {
      debugPrint('Backend AI usage refresh failed: $error');
    } finally {
      _refreshingBackend = false;
      if (!_disposed) {
        notifyListeners();
        if (_backendRefreshPending) {
          _backendRefreshPending = false;
          await refreshBackendUsage();
        }
      }
    }
  }

  final ClaudeCodeScanner _claudeScanner;
  final CodexCliScanner _codexScanner;
  final AntigravityScanner _antigravityScanner;
  final OpencodeScanner _opencodeScanner;
  final FreebuffScanner _freebuffScanner;

  bool _scanning = false;
  bool? _claudeCodeDirFound; // null = not yet checked
  bool? _codexCliDirFound;
  bool? _antigravityDirFound;
  bool? _opencodeDbFound;
  bool? _freebuffDirFound;
  bool _lumaUsageFound = false;
  DateTime? _lastScanAt;
  List<AiUsageRemoteDevice> _remoteDevices = const [];
  ClaudeCodeScanResult? _lastClaudeResult;
  CodexCliScanResult? _lastCodexResult;
  AntigravityScanResult? _lastAntigravityResult;
  OpencodeScanResult? _lastOpencodeResult;
  FreebuffScanResult? _lastFreebuffResult;

  bool get scanning => _scanning;

  /// Whether `~/.claude/projects` was found on this device â€” null until the
  /// first [rescan] completes.
  bool? get claudeCodeDirFound => _claudeCodeDirFound;

  /// Whether `~/.codex/sessions` was found on this device â€” null until the
  /// first [rescan] completes.
  bool? get codexCliDirFound => _codexCliDirFound;

  /// Whether `~/.gemini/antigravity/brain` was found on this device â€” null
  /// until the first [rescan] completes.
  bool? get antigravityDirFound => _antigravityDirFound;

  /// Whether opencode's `opencode.db` was found on this device â€” null until
  /// the first [rescan] completes.
  bool? get opencodeDbFound => _opencodeDbFound;

  /// Whether `~/.config/freebuff-desktop/projects` was found on this device
  /// â€” null until the first [rescan] completes.
  bool? get freebuffDirFound => _freebuffDirFound;

  /// Whether *any* source was found â€” drives the page's empty-state gate.
  /// Null until the first [rescan] completes.
  bool? get anyDirFound {
    // luma's own AI having logged a call is enough to show the page, even
    // before the first rescan and with no CLI tool on this device.
    if (_lumaUsageFound) return true;
    if (_claudeCodeDirFound == null &&
        _codexCliDirFound == null &&
        _antigravityDirFound == null &&
        _opencodeDbFound == null &&
        _freebuffDirFound == null) {
      return null;
    }
    return (_claudeCodeDirFound ?? false) ||
        (_codexCliDirFound ?? false) ||
        (_antigravityDirFound ?? false) ||
        (_opencodeDbFound ?? false) ||
        (_freebuffDirFound ?? false);
  }

  DateTime? get lastScanAt => _lastScanAt;

  /// The user's other devices whose usage is included in [watchRange], as
  /// of the last [loadRemoteDevices]. Empty when AI Usage sync is off.
  List<AiUsageRemoteDevice> get remoteDevices => _remoteDevices;

  /// Re-reads which other devices' usage is stored here. Called after a
  /// cloud sync pulls new numbers, and after every [rescan].
  Future<void> loadRemoteDevices() async {
    final devices = await (_db.select(
      _db.aiUsageRemoteDevices,
    )..orderBy([(d) => OrderingTerm.asc(d.name)])).get();
    _remoteDevices = devices;
    notifyListeners();
  }

  ClaudeCodeScanResult? get lastClaudeResult => _lastClaudeResult;
  CodexCliScanResult? get lastCodexResult => _lastCodexResult;
  AntigravityScanResult? get lastAntigravityResult => _lastAntigravityResult;
  OpencodeScanResult? get lastOpencodeResult => _lastOpencodeResult;
  FreebuffScanResult? get lastFreebuffResult => _lastFreebuffResult;

  /// Combined new-turn count from the most recent [rescan], across every
  /// source â€” for the single-line status UI.
  int get lastTurnsAdded =>
      (_lastClaudeResult?.turnsAdded ?? 0) +
      (_lastCodexResult?.turnsAdded ?? 0) +
      (_lastAntigravityResult?.turnsAdded ?? 0) +
      (_lastOpencodeResult?.turnsAdded ?? 0) +
      (_lastFreebuffResult?.turnsAdded ?? 0);

  /// Scans every known local source for new/changed session logs and stores
  /// any new usage. Safe to call repeatedly â€” unchanged files are skipped
  /// cheaply by the scanners, and a scan already in flight is not
  /// duplicated. The scanners touch disjoint file paths and only ever
  /// insert distinctly-sourced rows, so running them concurrently is safe.
  /// File decoding and external SQLite reads run in a worker isolate so large
  /// logs cannot block UI callbacks during startup, resume, or manual refresh.
  Future<void> rescan() async {
    if (_scanning) return;
    _scanning = true;
    notifyListeners();

    try {
      await refreshBackendUsage();
      final (
        claudeResult,
        codexResult,
        antigravityResult,
        opencodeResult,
        freebuffResult,
      ) = await _db.computeWithDatabase(
        connect: AiUsageDatabase.new,
        computation: _LocalScanJob(
          claude: _claudeScanner,
          codex: _codexScanner,
          antigravity: _antigravityScanner,
          opencode: _opencodeScanner,
          freebuff: _freebuffScanner,
        ).run,
      );
      _lastClaudeResult = claudeResult;
      _lastCodexResult = codexResult;
      _lastAntigravityResult = antigravityResult;
      _lastOpencodeResult = opencodeResult;
      _lastFreebuffResult = freebuffResult;
      _claudeCodeDirFound = claudeResult.projectsDirFound;
      _codexCliDirFound = codexResult.sessionsDirFound;
      _antigravityDirFound = antigravityResult.brainDirFound;
      _opencodeDbFound = opencodeResult.dbFound;
      _freebuffDirFound = freebuffResult.projectsDirFound;
      _lastScanAt = DateTime.now();
      if (lastTurnsAdded > 0) {
        StorageGuard.instance.scheduleRefresh();
      }
      _remoteDevices = await (_db.select(
        _db.aiUsageRemoteDevices,
      )..orderBy([(d) => OrderingTerm.asc(d.name)])).get();
      final lumaTurn =
          await (_db.select(_db.aiUsageTurns)
                ..where((t) => t.source.equalsValue(AiUsageSource.luma))
                ..limit(1))
              .getSingleOrNull();
      _lumaUsageFound = _lumaUsageFound || lumaTurn != null;
    } finally {
      _scanning = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Logs one call luma's own AI made — an Assistant reply, a Mind Map
  /// suggestion, a crash diagnosis — as an [AiUsageSource.luma] turn, so it
  /// is counted, priced and synced like any scanned CLI turn.
  ///
  /// [providerId] is the `AiProviderId` name the call went through and
  /// [feature] the part of luma that made it, stored as the turn's project.
  /// [sessionId] groups calls from one conversation; one-off calls default
  /// to the feature. Never throws: a failed write loses one row of usage,
  /// which must never turn a reply the user already has into an error.
  Future<void> recordLumaCall({
    required String providerId,
    required AiTokenUsage usage,
    required String feature,
    String? sessionId,
    DateTime? at,
  }) async {
    final timestamp = (at ?? DateTime.now()).toUtc();
    try {
      await _db
          .into(_db.aiUsageTurns)
          .insert(
            AiUsageTurnsCompanion.insert(
              sessionId: sessionId ?? 'luma:$feature',
              timestamp: timestamp,
              model: '$providerId/${_bareModel(usage.model)}',
              inputTokens: Value(usage.inputTokens),
              outputTokens: Value(usage.outputTokens),
              cacheReadTokens: Value(usage.cacheReadTokens),
              cacheCreationTokens: Value(usage.cacheWriteTokens),
              messageId: Value('luma:${timestamp.microsecondsSinceEpoch}'),
              project: Value(feature),
              source: AiUsageSource.luma,
              reportedCost: Value(usage.reportedCost),
            ),
          );
    } catch (error) {
      debugPrint('Could not log AI usage: $error');
      return;
    }
    if (!_lumaUsageFound) {
      _lumaUsageFound = true;
      notifyListeners();
    }
  }

  /// Gemini answers with `models/<id>`; the provider is already the prefix.
  static String _bareModel(String model) =>
      model.startsWith('models/') ? model.substring('models/'.length) : model;

  /// Turns in `[start, end)`, soonest first, across every source and every
  /// synced device. A null
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
      query.where(
        (t) =>
            t.timestamp.isBiggerOrEqualValue(startUtc) &
            t.timestamp.isSmallerThanValue(endUtc),
      );
    }
    return query.watch();
  }
}

typedef _LocalScanResult = (
  ClaudeCodeScanResult,
  CodexCliScanResult,
  AntigravityScanResult,
  OpencodeScanResult,
  FreebuffScanResult,
);

class _LocalScanJob {
  const _LocalScanJob({
    required this.claude,
    required this.codex,
    required this.antigravity,
    required this.opencode,
    required this.freebuff,
  });

  final ClaudeCodeScanner claude;
  final CodexCliScanner codex;
  final AntigravityScanner antigravity;
  final OpencodeScanner opencode;
  final FreebuffScanner freebuff;

  Future<_LocalScanResult> run(AiUsageDatabase db) => (
    claude.scan(db),
    codex.scan(db),
    antigravity.scan(db),
    opencode.scan(db),
    freebuff.scan(db),
  ).wait;
}

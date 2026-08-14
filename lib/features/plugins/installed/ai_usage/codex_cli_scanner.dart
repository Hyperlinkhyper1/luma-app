import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'ai_usage_source.dart';
import 'data/ai_usage_database.dart';

/// Summary of one [CodexCliScanner.scan] pass, for a status line in the UI.
class CodexCliScanResult {
  const CodexCliScanResult({
    required this.sessionsDirFound,
    this.filesScanned = 0,
    this.filesNew = 0,
    this.filesUpdated = 0,
    this.turnsAdded = 0,
  });

  static const unavailable = CodexCliScanResult(sessionsDirFound: false);

  /// Whether `~/.codex/sessions` was found on this device at all.
  final bool sessionsDirFound;
  final int filesScanned;
  final int filesNew;
  final int filesUpdated;
  final int turnsAdded;
}

/// Reads Codex CLI's local session logs (`~/.codex/sessions/**/*.jsonl`) and
/// stores per-turn token usage into [AiUsageDatabase]. Covers Codex used via
/// the standalone CLI, the ChatGPT desktop app, or its VS Code extension —
/// all three write the same rollout format to the same directory.
///
/// Only usage metadata is ever read out of a record: `type`, `session_id`,
/// `model`, `timestamp`, and the `last_token_usage` token counts.
/// `message`/content-bearing record types (`response_item`, `message`,
/// `user_message`, ...) are never inspected — the same "never touch prompt
/// or response text" rule as [ClaudeCodeScanner]. Mirrors the same
/// incremental-rescan strategy too: files are tracked by path + mtime + line
/// count in the shared [AiUsageDatabase.aiUsageScanFiles] table (safe to
/// share with Claude Code's scanner — paths from the two source trees never
/// collide).
///
/// Unlike Claude Code's JSONL, one Codex "turn" is spread across three
/// record types in file order: `session_meta` (session id, normally line 1),
/// `turn_context` (the model in effect, once per turn), and an
/// `event_msg`/`token_count` event (the actual usage delta). See
/// [_scanFile] for why state from the first two must survive an incremental
/// rescan's line-skip cutoff.
class CodexCliScanner {
  const CodexCliScanner();

  /// Locates the local Codex CLI sessions directory, or null if this device
  /// doesn't have one. Same `USERPROFILE`/`HOME` resolution as
  /// [ClaudeCodeScanner.projectsDirectory].
  Directory? sessionsDirectory() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return null;
    final dir = Directory(
      '$home${Platform.pathSeparator}.codex${Platform.pathSeparator}sessions',
    );
    return dir.existsSync() ? dir : null;
  }

  Future<CodexCliScanResult> scan(AiUsageDatabase db) =>
      scanDirectory(db, sessionsDirectory());

  /// Scans [dir] directly — split out from [scan] so tests can point it at a
  /// fixture directory instead of the real `~/.codex/sessions`.
  Future<CodexCliScanResult> scanDirectory(
    AiUsageDatabase db,
    Directory? dir,
  ) async {
    if (dir == null) return CodexCliScanResult.unavailable;

    final files = <File>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
          files.add(entity);
        }
      }
    } on FileSystemException {
      return const CodexCliScanResult(sessionsDirFound: true);
    }

    var filesScanned = 0;
    var filesNew = 0;
    var filesUpdated = 0;
    var turnsAdded = 0;

    for (final file in files) {
      _FileScanOutcome? outcome;
      try {
        outcome = await _scanFile(db, file);
      } catch (_) {
        // One unreadable/locked file must not abort the rest of the scan.
        continue;
      }
      if (outcome == null) continue; // unchanged, skipped
      filesScanned++;
      if (outcome.isNewFile) {
        filesNew++;
      } else {
        filesUpdated++;
      }
      turnsAdded += outcome.turnsAdded;
    }

    return CodexCliScanResult(
      sessionsDirFound: true,
      filesScanned: filesScanned,
      filesNew: filesNew,
      filesUpdated: filesUpdated,
      turnsAdded: turnsAdded,
    );
  }

  Future<_FileScanOutcome?> _scanFile(AiUsageDatabase db, File file) async {
    final stat = await file.stat();
    final mtimeMs = stat.modified.millisecondsSinceEpoch.toDouble();

    final existing = await (db.select(db.aiUsageScanFiles)
          ..where((t) => t.path.equals(file.path)))
        .getSingleOrNull();

    if (existing != null && (existing.mtimeMs - mtimeMs).abs() < 10) {
      return null;
    }

    final oldLineCount = existing?.lineCount ?? 0;
    final isNewFile = existing == null;

    final newTurns = <AiUsageTurnsCompanion>[];
    var lineNumber = 0;
    // Running state carried across the whole file. Deliberately NOT reset
    // or skipped by the oldLineCount cutoff below — session_meta and
    // turn_context lines that establish this state normally appear once,
    // early in the file, and would sit entirely within the "already
    // scanned" prefix on every rescan after the first. If state updates
    // were gated the same way turn emission is, every resumed scan would
    // see sessionId/model reset to empty before it ever reached a new
    // token_count line, silently mislabelling every turn found after the
    // first scan of a file.
    String? sessionId;
    var model = '';

    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lines) {
      lineNumber++;
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      Map<String, dynamic> record;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        record = decoded;
      } catch (_) {
        continue;
      }

      // Plain if/else rather than a switch: a bare `continue` (needed below
      // to skip already-scanned event_msg lines) isn't legal directly inside
      // a switch case in Dart without a case label, and this loop needs it
      // to target the enclosing `await for`.
      final type = record['type'];
      if (type == 'session_meta') {
        final payload = record['payload'];
        if (payload is Map<String, dynamic>) {
          final id = payload['session_id'];
          if (id is String && id.isNotEmpty) sessionId = id;
        }
      } else if (type == 'turn_context') {
        final payload = record['payload'];
        if (payload is Map<String, dynamic>) {
          final m = payload['model'];
          if (m is String && m.isNotEmpty) model = m;
        }
      } else if (type == 'event_msg') {
        if (lineNumber <= oldLineCount) continue;
        final companion = _parseTokenCountEvent(
          record,
          sessionId: sessionId ?? _sessionIdFromFilename(file),
          model: model,
        );
        if (companion != null) newTurns.add(companion);
      }
      // response_item, message, user_message, task_started, task_complete,
      // thread_rolled_back, ... — never inspected.
    }

    await db.batch((b) {
      if (newTurns.isNotEmpty) {
        b.insertAll(db.aiUsageTurns, newTurns);
      }
      b.insert(
        db.aiUsageScanFiles,
        AiUsageScanFilesCompanion.insert(
          path: file.path,
          mtimeMs: mtimeMs,
          lineCount: Value(lineNumber),
        ),
        mode: InsertMode.insertOrReplace,
      );
    });

    return _FileScanOutcome(isNewFile: isNewFile, turnsAdded: newTurns.length);
  }

  /// Parses one `event_msg` record into an insertable turn, or null if it
  /// isn't a `token_count` event, carries no usage info (a rate-limit-only
  /// ping), has no session id to attach to, has an unparseable timestamp, or
  /// carries no token usage at all (e.g. a context-compaction marker).
  AiUsageTurnsCompanion? _parseTokenCountEvent(
    Map<String, dynamic> record, {
    required String? sessionId,
    required String model,
  }) {
    if (sessionId == null || sessionId.isEmpty) return null;

    final payload = record['payload'];
    if (payload is! Map<String, dynamic>) return null;
    if (payload['type'] != 'token_count') return null;

    final info = payload['info'];
    if (info is! Map<String, dynamic>) return null; // e.g. a rate-limit ping
    final lastUsage = info['last_token_usage'];
    if (lastUsage is! Map<String, dynamic>) return null;

    int tokenField(String key) => (lastUsage[key] as num?)?.toInt() ?? 0;
    final inputTokens = tokenField('input_tokens');
    final cacheReadTokens = tokenField('cached_input_tokens');
    // OpenAI bills reasoning tokens at the output rate, so folding them
    // into outputTokens here keeps cost calculation accurate without a
    // dedicated schema column.
    final outputTokens =
        tokenField('output_tokens') + tokenField('reasoning_output_tokens');
    if (inputTokens + outputTokens + cacheReadTokens == 0) return null;

    final timestampRaw = record['timestamp'] as String?;
    final timestamp =
        timestampRaw == null ? null : DateTime.tryParse(timestampRaw);
    if (timestamp == null) return null;

    return AiUsageTurnsCompanion.insert(
      sessionId: sessionId,
      timestamp: timestamp.toUtc(),
      model: model,
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      cacheReadTokens: Value(cacheReadTokens),
      cacheCreationTokens: const Value(0),
      messageId: const Value(null),
      source: AiUsageSource.codexCli,
    );
  }

  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// Rollout filenames end in `-<uuid>.jsonl`, matching the file's own
  /// `session_meta.payload.session_id` — a fallback for the rare case a file
  /// is missing (or hasn't yet reached) its `session_meta` line.
  String? _sessionIdFromFilename(File file) =>
      _uuidPattern.firstMatch(file.uri.pathSegments.last)?.group(0);
}

class _FileScanOutcome {
  const _FileScanOutcome({required this.isNewFile, required this.turnsAdded});
  final bool isNewFile;
  final int turnsAdded;
}

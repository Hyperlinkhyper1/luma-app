import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'data/ai_usage_database.dart';

/// Summary of one [ClaudeCodeScanner.scan] pass, for a status line in the UI.
class ClaudeCodeScanResult {
  const ClaudeCodeScanResult({
    required this.projectsDirFound,
    this.filesScanned = 0,
    this.filesNew = 0,
    this.filesUpdated = 0,
    this.turnsAdded = 0,
  });

  static const unavailable = ClaudeCodeScanResult(projectsDirFound: false);

  /// Whether `~/.claude/projects` was found on this device at all.
  final bool projectsDirFound;
  final int filesScanned;
  final int filesNew;
  final int filesUpdated;
  final int turnsAdded;
}

/// Reads Claude Code's local session logs (`~/.claude/projects/*.jsonl`) and
/// stores per-turn token usage into [AiUsageDatabase].
///
/// Only usage metadata is ever read out of a record: `type`, `sessionId`,
/// `timestamp`, `message.id`, `message.model`, and `message.usage.*`.
/// `message.content` — the actual prompt/response text — is never read,
/// stored, or displayed. This mirrors the reference `claude-usage` CLI tool's
/// own scanner (`C:\Users\ayden\claude-usage\scanner.py`), including its
/// incremental-rescan strategy: files are tracked by path + mtime + line
/// count, so an unchanged file is skipped entirely and a changed file resumes
/// from its last scanned line instead of reparsing from the start.
class ClaudeCodeScanner {
  const ClaudeCodeScanner();

  /// Locates the local Claude Code projects directory, or null if this
  /// device doesn't have one (Claude Code has never run here, or the home
  /// directory couldn't be resolved). Mirrors the only existing precedent in
  /// this app for reaching outside its own sandbox into the user's home
  /// directory (the gallery plugin's `_defaultRoots()`).
  Directory? projectsDirectory() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return null;
    final dir = Directory(
      '$home${Platform.pathSeparator}.claude${Platform.pathSeparator}projects',
    );
    return dir.existsSync() ? dir : null;
  }

  Future<ClaudeCodeScanResult> scan(AiUsageDatabase db) =>
      scanDirectory(db, projectsDirectory());

  /// Scans [dir] directly — split out from [scan] so tests can point it at a
  /// fixture directory instead of the real `~/.claude/projects`.
  Future<ClaudeCodeScanResult> scanDirectory(
    AiUsageDatabase db,
    Directory? dir,
  ) async {
    if (dir == null) return ClaudeCodeScanResult.unavailable;

    final files = <File>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
          files.add(entity);
        }
      }
    } on FileSystemException {
      return const ClaudeCodeScanResult(projectsDirFound: true);
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

    return ClaudeCodeScanResult(
      projectsDirFound: true,
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

    // Sub-millisecond float round-tripping through the DB shouldn't look
    // like a change; 10ms of slack is well under any real filesystem's
    // mtime resolution.
    if (existing != null && (existing.mtimeMs - mtimeMs).abs() < 10) {
      return null;
    }

    final oldLineCount = existing?.lineCount ?? 0;
    final isNewFile = existing == null;

    // message_id -> latest companion seen this pass. Claude Code streams
    // multiple records per turn as the response is generated; only the
    // final one has the settled usage tallies, so the last write wins.
    final seenByMessageId = <String, AiUsageTurnsCompanion>{};
    final noIdTurns = <AiUsageTurnsCompanion>[];
    var lineNumber = 0;

    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lines) {
      lineNumber++;
      if (lineNumber <= oldLineCount) continue;

      final companion = _parseLine(rawLine);
      if (companion == null) continue;

      final messageId = companion.messageId.value;
      if (messageId != null && messageId.isNotEmpty) {
        seenByMessageId[messageId] = companion;
      } else {
        noIdTurns.add(companion);
      }
    }

    final newTurns = [...noIdTurns, ...seenByMessageId.values];

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

  /// Parses one JSONL line into an insertable turn, or null if the line is
  /// blank, malformed, not an `assistant` record, missing a session id, or
  /// carries no token usage at all (matches `scanner.py`'s own filtering). A
  /// single bad line is swallowed here rather than aborting the file.
  AiUsageTurnsCompanion? _parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return null;

    try {
      final record = jsonDecode(line);
      if (record is! Map<String, dynamic>) return null;
      if (record['type'] != 'assistant') return null;

      final sessionId = record['sessionId'];
      if (sessionId is! String || sessionId.isEmpty) return null;

      final message = record['message'];
      if (message is! Map<String, dynamic>) return null;

      final usage = message['usage'];
      final model = message['model'] as String? ?? '';
      final messageId = message['id'] as String?;

      int tokenField(String key) =>
          usage is Map<String, dynamic> ? ((usage[key] as num?)?.toInt() ?? 0) : 0;
      final inputTokens = tokenField('input_tokens');
      final outputTokens = tokenField('output_tokens');
      final cacheRead = tokenField('cache_read_input_tokens');
      final cacheCreation = tokenField('cache_creation_input_tokens');
      if (inputTokens + outputTokens + cacheRead + cacheCreation == 0) {
        return null;
      }

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
        cacheReadTokens: Value(cacheRead),
        cacheCreationTokens: Value(cacheCreation),
        messageId: Value(messageId),
      );
    } catch (_) {
      return null;
    }
  }
}

class _FileScanOutcome {
  const _FileScanOutcome({required this.isNewFile, required this.turnsAdded});
  final bool isNewFile;
  final int turnsAdded;
}

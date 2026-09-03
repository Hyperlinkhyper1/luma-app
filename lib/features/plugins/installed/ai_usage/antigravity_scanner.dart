import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'ai_usage_source.dart';
import 'data/ai_usage_database.dart';

/// Summary of one [AntigravityScanner.scan] pass, for a status line in the UI.
class AntigravityScanResult {
  const AntigravityScanResult({
    required this.brainDirFound,
    this.filesScanned = 0,
    this.filesNew = 0,
    this.filesUpdated = 0,
    this.turnsAdded = 0,
  });

  static const unavailable = AntigravityScanResult(brainDirFound: false);

  /// Whether `~/.gemini/antigravity/brain` was found on this device at all.
  final bool brainDirFound;
  final int filesScanned;
  final int filesNew;
  final int filesUpdated;
  final int turnsAdded;
}

/// Roughly how many characters make up one token, for English text — the
/// same rule of thumb AI providers themselves cite. Used only because
/// Antigravity's local logs don't record real token counts at all (unlike
/// Claude Code and Codex CLI, which do) — see the module doc below.
const int _kCharsPerToken = 4;

/// Reads Google Antigravity's local conversation logs
/// (`~/.gemini/antigravity/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`)
/// and stores an *estimated* per-turn token count into [AiUsageDatabase].
///
/// This source is fundamentally different from [ClaudeCodeScanner] and
/// [CodexCliScanner]: Antigravity's transcripts do not record token usage
/// anywhere (confirmed by inspecting real local conversation files — no
/// token/usage field exists in this app's logs at all). The only available
/// signal is the length of the actual message text, so this scanner reads
/// the character length of `content` (and, for model turns, `thinking` and
/// `tool_calls`) purely to compute `length ~/ 4` as a rough token estimate —
/// **the text itself is never stored, displayed, or used for anything else**,
/// consistent with every other scanner in this plugin never touching
/// message content. Because it's derived from message length rather than
/// metered by the provider, every turn from this source is priced (if at
/// all) more tentatively than Claude Code/Codex's exact figures — see
/// `ai_usage_pricing.dart`'s `_antigravityPricingFor` — and is shown in the
/// UI labelled as an estimate, not exact usage.
///
/// Only two record types are counted:
/// - `type: "USER_INPUT"` — the user's message; its length becomes the
///   *pending* input-token estimate for the next model turn.
/// - `type: "PLANNER_RESPONSE"` — the model's turn; its own content (+
///   thinking + tool call arguments) becomes the output-token estimate, and
///   consumes whatever input estimate is pending.
/// Every other record type (`CHECKPOINT`, `CONVERSATION_HISTORY`,
/// `EPHEMERAL_MESSAGE`, ...) is synthetic context injected by Antigravity
/// itself, not a real exchange, and is ignored entirely — including for the
/// purpose of resetting the pending input estimate.
///
/// The model in use is also not a stored field — Antigravity surfaces it
/// only as prose inside a `USER_INPUT`'s own content, e.g. "...changed
/// setting `Model Selection` from None to Claude Opus 4.6 (Thinking)...".
/// This is parsed out and tracked the same way [CodexCliScanner] tracks
/// `turn_context.model` — a running value applied to subsequent turns until
/// it changes again.
class AntigravityScanner {
  const AntigravityScanner();

  /// Locates the local Antigravity conversation directory, or null if this
  /// device doesn't have one. Same `USERPROFILE`/`HOME` resolution as the
  /// other scanners.
  Directory? conversationsDirectory() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return null;
    final dir = Directory(
      '$home${Platform.pathSeparator}.gemini${Platform.pathSeparator}antigravity'
      '${Platform.pathSeparator}brain',
    );
    return dir.existsSync() ? dir : null;
  }

  Future<AntigravityScanResult> scan(AiUsageDatabase db) =>
      scanDirectory(db, conversationsDirectory());

  /// Scans [dir] directly — split out from [scan] so tests can point it at a
  /// fixture directory instead of the real `~/.gemini/antigravity/brain`.
  Future<AntigravityScanResult> scanDirectory(
    AiUsageDatabase db,
    Directory? dir,
  ) async {
    if (dir == null) return AntigravityScanResult.unavailable;

    final files = <File>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        // Only the (smaller, user-facing) transcript — not
        // transcript_full.jsonl, which duplicates it with more internal
        // detail we have no use for here.
        if (entity is File && entity.uri.pathSegments.last == 'transcript.jsonl') {
          files.add(entity);
        }
      }
    } on FileSystemException {
      return const AntigravityScanResult(brainDirFound: true);
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

    return AntigravityScanResult(
      brainDirFound: true,
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
    final sessionId = _conversationId(file) ?? file.parent.parent.parent.path;

    final newTurns = <AiUsageTurnsCompanion>[];
    var lineNumber = 0;
    // Running state carried across the whole file, never reset by the
    // oldLineCount cutoff — see the state-continuity note in
    // codex_cli_scanner.dart for why (the same reasoning applies here:
    // the USER_INPUT that sets these normally sits in the already-scanned
    // prefix on every rescan after the first).
    String model = 'Unknown model';
    int pendingInputChars = 0;

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

      final type = record['type'];
      if (type == 'USER_INPUT') {
        final content = record['content'] as String?;
        pendingInputChars = content?.length ?? 0;
        final changedModel = _modelFromSettingsChange(content);
        if (changedModel != null) model = changedModel;
      } else if (type == 'PLANNER_RESPONSE') {
        if (lineNumber <= oldLineCount) {
          pendingInputChars = 0;
          continue;
        }
        final companion = _parsePlannerResponse(
          record,
          sessionId: sessionId,
          model: model,
          inputChars: pendingInputChars,
        );
        pendingInputChars = 0;
        if (companion != null) newTurns.add(companion);
      }
      // CHECKPOINT, CONVERSATION_HISTORY, EPHEMERAL_MESSAGE, and anything
      // else are synthetic/system records — never inspected, and never
      // allowed to consume or reset the pending input estimate.
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

  AiUsageTurnsCompanion? _parsePlannerResponse(
    Map<String, dynamic> record, {
    required String sessionId,
    required String model,
    required int inputChars,
  }) {
    final content = record['content'] as String?;
    final thinking = record['thinking'] as String?;
    var outputChars = (content?.length ?? 0) + (thinking?.length ?? 0);

    final toolCalls = record['tool_calls'];
    if (toolCalls != null) {
      try {
        outputChars += jsonEncode(toolCalls).length;
      } catch (_) {
        // Not encodable — skip it rather than fail the whole turn.
      }
    }

    final inputTokens = inputChars ~/ _kCharsPerToken;
    final outputTokens = outputChars ~/ _kCharsPerToken;
    if (inputTokens + outputTokens == 0) return null;

    final timestampRaw = record['created_at'] as String?;
    final timestamp =
        timestampRaw == null ? null : DateTime.tryParse(timestampRaw);
    if (timestamp == null) return null;

    return AiUsageTurnsCompanion.insert(
      sessionId: sessionId,
      timestamp: timestamp.toUtc(),
      model: model,
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      cacheReadTokens: const Value(0),
      cacheCreationTokens: const Value(0),
      messageId: const Value(null),
      // No reliable per-conversation project source — see the module doc.
      project: const Value(null),
      source: AiUsageSource.antigravity,
    );
  }

  static final _modelChangePattern =
      RegExp(r'Model Selection` from .+? to (.+?)\. No need to comment');

  /// Antigravity never stores the active model as its own field — it only
  /// ever appears as prose inside a USER_INPUT when the user (re)selects
  /// one, e.g. "...changed setting `Model Selection` from None to Claude
  /// Opus 4.6 (Thinking). No need to comment...". Returns null if [content]
  /// doesn't contain that phrase (i.e. most messages, which don't change
  /// the model).
  String? _modelFromSettingsChange(String? content) {
    if (content == null) return null;
    return _modelChangePattern.firstMatch(content)?.group(1)?.trim();
  }

  /// The conversation folder name from a path shaped like
  /// `.../brain/<conversation-id>/.system_generated/logs/transcript.jsonl`.
  String? _conversationId(File file) {
    final segments =
        file.parent.parent.parent.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.last;
  }
}

class _FileScanOutcome {
  const _FileScanOutcome({required this.isNewFile, required this.turnsAdded});
  final bool isNewFile;
  final int turnsAdded;
}

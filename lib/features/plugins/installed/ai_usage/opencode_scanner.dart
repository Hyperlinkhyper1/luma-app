import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'ai_usage_project.dart';
import 'ai_usage_source.dart';
import 'data/ai_usage_database.dart';

/// Summary of one [OpencodeScanner.scan] pass, for a status line in the UI.
class OpencodeScanResult {
  const OpencodeScanResult({required this.dbFound, this.turnsAdded = 0});

  static const unavailable = OpencodeScanResult(dbFound: false);

  /// Whether opencode's local `opencode.db` was found on this device at all.
  final bool dbFound;
  final int turnsAdded;
}

/// Reads opencode CLI's local SQLite database (`opencode.db`, under
/// `OPENCODE_DATA_DIR` or the default `~/.local/share/opencode`) and stores
/// per-turn token usage into [AiUsageDatabase].
///
/// OpenCode stores messages in SQLite rather than JSONL files. New versions
/// use `session_message` and `session_v2`; older versions use `message`.
/// Only usage metadata is imported, never the prompt or response content.
///
/// Incremental scans use the message update time, because OpenCode creates
/// assistant messages before their token counts are known. A separate key for
/// each schema causes a one-time backfill, and an inclusive watermark handles
/// messages that share an update timestamp.
class OpencodeScanner {
  const OpencodeScanner();

  /// Locates opencode's local database file, or null if this device doesn't
  /// have one. Honors `OPENCODE_DATA_DIR` the same way opencode itself does;
  /// falls back to `~/.local/share/opencode`.
  File? databaseFile() {
    final override = Platform.environment['OPENCODE_DATA_DIR'];
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final base = (override != null && override.isNotEmpty)
        ? override
        : (home.isEmpty
              ? ''
              : '$home${Platform.pathSeparator}.local${Platform.pathSeparator}share${Platform.pathSeparator}opencode');
    if (base.isEmpty) return null;
    final file = File('$base${Platform.pathSeparator}opencode.db');
    return file.existsSync() ? file : null;
  }

  Future<OpencodeScanResult> scan(AiUsageDatabase db) =>
      scanFile(db, databaseFile());

  /// Scans [file] directly — split out from [scan] so tests can point it at
  /// a fixture database instead of the real `opencode.db`.
  Future<OpencodeScanResult> scanFile(AiUsageDatabase db, File? file) async {
    if (file == null) return OpencodeScanResult.unavailable;

    sqlite.Database? sqliteDb;
    try {
      sqliteDb = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    } catch (_) {
      // Locked, mid-write, or not actually a SQLite file — try again next
      // scan rather than aborting the whole pass.
      return const OpencodeScanResult(dbFound: true);
    }

    try {
      final modern = sqliteDb
          .select(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'session_message'",
          )
          .isNotEmpty;
      // Use a different key when OpenCode migrates its schema so the new
      // table gets a complete, deduplicated scan on the next pass.
      final scanKey = '${file.path}::opencode-updated-${modern ? 'v3' : 'v2'}';
      final existing = await (db.select(
        db.aiUsageScanFiles,
      )..where((t) => t.path.equals(scanKey))).getSingleOrNull();
      final sinceMs = existing?.mtimeMs.toInt() ?? 0;
      final rows = sqliteDb.select(
        modern
            ? 'SELECT m.id, m.session_id, m.time_created, m.time_updated, '
                  'm.data, m.type, s.directory FROM session_message m '
                  'LEFT JOIN session_v2 s ON s.id = m.session_id '
                  'WHERE m.time_updated >= ? ORDER BY m.time_updated ASC'
            : 'SELECT id, session_id, time_created, time_updated, data FROM message '
                  'WHERE time_updated >= ? ORDER BY time_updated ASC',
        [sinceMs],
      );

      final turns = <AiUsageTurnsCompanion>[];
      var maxMs = sinceMs;
      for (final row in rows) {
        final timeUpdated = (row['time_updated'] as num).toInt();
        if (timeUpdated > maxMs) maxMs = timeUpdated;
        final turn = _parseRow(row, modern: modern);
        if (turn != null) turns.add(turn);
      }

      // The target is a view with no unique constraint on source message IDs.
      // Match only this device's OpenCode rows, and preserve unchanged rows so
      // rescans are idempotent and do not trigger unnecessary cloud uploads.
      final previous = <String, List<AiUsageTurn>>{};
      for (var i = 0; i < turns.length; i += 400) {
        final ids = turns
            .skip(i)
            .take(400)
            .map((t) => t.messageId.value!)
            .toList();
        final matches =
            await (db.select(db.aiUsageTurns)..where(
                  (t) =>
                      t.source.equalsValue(AiUsageSource.opencode) &
                      t.deviceId.isNull() &
                      t.messageId.isIn(ids),
                ))
                .get();
        for (final match in matches) {
          (previous[match.messageId!] ??= []).add(match);
        }
      }
      final newTurns = <AiUsageTurnsCompanion>[];
      final replacedIds = <int>[];
      var added = 0;
      for (final turn in turns) {
        final old = previous[turn.messageId.value] ?? [];
        if (old.length == 1 && _sameTurn(old.single, turn)) continue;
        if (old.isEmpty) added++;
        replacedIds.addAll(old.map((row) => row.id));
        newTurns.add(turn);
      }

      await db.transaction(() async {
        for (var i = 0; i < replacedIds.length; i += 400) {
          final ids = replacedIds.skip(i).take(400).toList();
          await (db.delete(db.aiUsageTurns)..where((t) => t.id.isIn(ids))).go();
        }
        await db.batch((b) {
          if (newTurns.isNotEmpty) b.insertAll(db.aiUsageTurns, newTurns);
          b.insert(
            db.aiUsageScanFiles,
            AiUsageScanFilesCompanion.insert(
              path: scanKey,
              mtimeMs: maxMs.toDouble(),
              lineCount: const Value(0),
            ),
            mode: InsertMode.insertOrReplace,
          );
        });
      });

      return OpencodeScanResult(dbFound: true, turnsAdded: added);
    } catch (_) {
      return const OpencodeScanResult(dbFound: true);
    } finally {
      sqliteDb.close();
    }
  }

  bool _sameTurn(AiUsageTurn row, AiUsageTurnsCompanion turn) =>
      row.sessionId == turn.sessionId.value &&
      row.timestamp.millisecondsSinceEpoch ~/ 1000 ==
          turn.timestamp.value.millisecondsSinceEpoch ~/ 1000 &&
      row.model == turn.model.value &&
      row.inputTokens == turn.inputTokens.value &&
      row.outputTokens == turn.outputTokens.value &&
      row.cacheReadTokens == turn.cacheReadTokens.value &&
      row.cacheCreationTokens == turn.cacheCreationTokens.value &&
      row.project == turn.project.value &&
      row.reportedCost == turn.reportedCost.value;

  /// Parses one `message` row into an insertable turn, or null if it isn't
  /// an assistant record, carries no token usage at all, or its `data`
  /// column isn't valid JSON.
  AiUsageTurnsCompanion? _parseRow(sqlite.Row row, {required bool modern}) {
    try {
      final id = row['id'] as String;
      final sessionId = row['session_id'] as String;
      final timeCreated = (row['time_created'] as num).toInt();

      final decoded = jsonDecode(row['data'] as String);
      if (decoded is! Map<String, dynamic>) return null;
      final role = modern ? row['type'] : decoded['role'];
      if (role != 'assistant' && role != 'compaction') return null;

      final tokens = decoded['tokens'];
      if (tokens is! Map<String, dynamic>) return null;
      int field(String key) => (tokens[key] as num?)?.toInt() ?? 0;

      final inputTokens = field('input');
      // opencode's underlying providers bill reasoning tokens at the output
      // rate (same as Codex's `reasoning_output_tokens` — see
      // codex_cli_scanner.dart), so folding them in here keeps cost
      // calculation accurate without a dedicated schema column.
      final outputTokens = field('output') + field('reasoning');
      final cache = tokens['cache'];
      final cacheRead = cache is Map<String, dynamic>
          ? ((cache['read'] as num?)?.toInt() ?? 0)
          : 0;
      final cacheWrite = cache is Map<String, dynamic>
          ? ((cache['write'] as num?)?.toInt() ?? 0)
          : 0;
      if (inputTokens + outputTokens + cacheRead + cacheWrite == 0) return null;

      final nestedModel = decoded['model'];
      final modelId = modern && nestedModel is Map<String, dynamic>
          ? nestedModel['id'] as String? ?? ''
          : decoded['modelID'] as String? ?? '';
      final providerId = modern && nestedModel is Map<String, dynamic>
          ? nestedModel['providerID'] as String? ?? ''
          : decoded['providerID'] as String? ?? '';
      final model = providerId.isEmpty ? modelId : '$providerId/$modelId';

      final path = decoded['path'];
      final cwd = modern
          ? row['directory'] as String?
          : path is Map<String, dynamic>
          ? path['cwd'] as String?
          : null;

      // opencode prices every turn itself, from models.dev — including the
      // providers this app has no table for (MiniMax, OpenRouter, its own
      // gateway). Stored so cost can fall back to it rather than showing
      // "n/a" for everything outside anthropic/openai. A recorded 0 is a
      // real answer (a free model), not a missing one.
      final reportedCost = (decoded['cost'] as num?)?.toDouble();

      return AiUsageTurnsCompanion.insert(
        sessionId: sessionId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          timeCreated,
          isUtc: true,
        ),
        model: model,
        inputTokens: Value(inputTokens),
        outputTokens: Value(outputTokens),
        cacheReadTokens: Value(cacheRead),
        cacheCreationTokens: Value(cacheWrite),
        messageId: Value(id),
        project: Value(projectNameFromCwd(cwd)),
        source: AiUsageSource.opencode,
        reportedCost: Value(reportedCost),
      );
    } catch (_) {
      return null;
    }
  }
}

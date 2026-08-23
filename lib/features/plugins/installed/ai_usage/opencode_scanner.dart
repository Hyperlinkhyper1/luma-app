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
/// Unlike the other scanners, opencode keeps one row per message in a
/// `message` table (`id`, `session_id`, `time_created`, `data` — a JSON blob)
/// rather than a JSONL log per session. Only `role`, `tokens`, `modelID`,
/// `providerID`, and `path.cwd` are ever read out of `data`; the actual
/// prompt/response content (in the separate `part` table) is never touched.
///
/// Incremental rescans work by watermark rather than file position: the
/// highest `time_created` seen so far is stored in the shared
/// [AiUsageDatabase.aiUsageScanFiles] table, keyed by the database's own
/// path (reusing that table's `mtimeMs` column as the watermark rather than
/// an actual mtime — a real file's line-count tracking doesn't apply to
/// rows queried out of a live SQLite database).
class OpencodeScanner {
  const OpencodeScanner();

  /// Locates opencode's local database file, or null if this device doesn't
  /// have one. Honors `OPENCODE_DATA_DIR` the same way opencode itself does;
  /// falls back to `~/.local/share/opencode`.
  File? databaseFile() {
    final override = Platform.environment['OPENCODE_DATA_DIR'];
    final home = Platform.environment['USERPROFILE'] ??
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

    final existing = await (db.select(db.aiUsageScanFiles)
          ..where((t) => t.path.equals(file.path)))
        .getSingleOrNull();
    final sinceMs = existing?.mtimeMs.toInt() ?? 0;

    sqlite.Database? sqliteDb;
    try {
      sqliteDb = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    } catch (_) {
      // Locked, mid-write, or not actually a SQLite file — try again next
      // scan rather than aborting the whole pass.
      return const OpencodeScanResult(dbFound: true);
    }

    try {
      final rows = sqliteDb.select(
        'SELECT id, session_id, time_created, data FROM message '
        'WHERE time_created > ? ORDER BY time_created ASC',
        [sinceMs],
      );

      final newTurns = <AiUsageTurnsCompanion>[];
      var maxMs = sinceMs;
      for (final row in rows) {
        final timeCreated = (row['time_created'] as num).toInt();
        if (timeCreated > maxMs) maxMs = timeCreated;
        final turn = _parseRow(row);
        if (turn != null) newTurns.add(turn);
      }

      await db.batch((b) {
        if (newTurns.isNotEmpty) {
          b.insertAll(db.aiUsageTurns, newTurns);
        }
        b.insert(
          db.aiUsageScanFiles,
          AiUsageScanFilesCompanion.insert(
            path: file.path,
            mtimeMs: maxMs.toDouble(),
            lineCount: const Value(0),
          ),
          mode: InsertMode.insertOrReplace,
        );
      });

      return OpencodeScanResult(dbFound: true, turnsAdded: newTurns.length);
    } catch (_) {
      return const OpencodeScanResult(dbFound: true);
    } finally {
      sqliteDb.dispose();
    }
  }

  /// Parses one `message` row into an insertable turn, or null if it isn't
  /// an assistant record, carries no token usage at all, or its `data`
  /// column isn't valid JSON.
  AiUsageTurnsCompanion? _parseRow(sqlite.Row row) {
    try {
      final id = row['id'] as String;
      final sessionId = row['session_id'] as String;
      final timeCreated = (row['time_created'] as num).toInt();

      final decoded = jsonDecode(row['data'] as String);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['role'] != 'assistant') return null;

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
      final cacheRead =
          cache is Map<String, dynamic> ? ((cache['read'] as num?)?.toInt() ?? 0) : 0;
      final cacheWrite =
          cache is Map<String, dynamic> ? ((cache['write'] as num?)?.toInt() ?? 0) : 0;
      if (inputTokens + outputTokens + cacheRead + cacheWrite == 0) return null;

      final modelId = decoded['modelID'] as String? ?? '';
      final providerId = decoded['providerID'] as String? ?? '';
      final model = providerId.isEmpty ? modelId : '$providerId/$modelId';

      final path = decoded['path'];
      final cwd = path is Map<String, dynamic> ? path['cwd'] as String? : null;

      return AiUsageTurnsCompanion.insert(
        sessionId: sessionId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timeCreated, isUtc: true),
        model: model,
        inputTokens: Value(inputTokens),
        outputTokens: Value(outputTokens),
        cacheReadTokens: Value(cacheRead),
        cacheCreationTokens: Value(cacheWrite),
        messageId: Value(id),
        project: Value(projectNameFromCwd(cwd)),
        source: AiUsageSource.opencode,
      );
    } catch (_) {
      return null;
    }
  }
}

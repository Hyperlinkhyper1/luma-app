import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'ai_usage_project.dart';
import 'ai_usage_source.dart';
import 'data/ai_usage_database.dart';

/// Summary of one [FreebuffScanner.scan] pass, for a status line in the UI.
class FreebuffScanResult {
  const FreebuffScanResult({
    required this.projectsDirFound,
    this.projectsScanned = 0,
    this.turnsAdded = 0,
  });

  static const unavailable = FreebuffScanResult(projectsDirFound: false);

  /// Whether `~/.config/freebuff-desktop/projects` was found on this device
  /// at all.
  final bool projectsDirFound;
  final int projectsScanned;
  final int turnsAdded;
}

/// Reads the Freebuff desktop app's local per-project SQLite databases
/// (`~/.config/freebuff-desktop/projects/<name>-<id>/desktop-v2.db`, one per
/// project it's been pointed at) and stores per-turn token usage into
/// [AiUsageDatabase].
///
/// Freebuff orchestrates one or more underlying coding harnesses per thread
/// (an embedded Claude Code, Codex CLI, or its own native multi-provider
/// catalog); each `threads` row records that thread's `model` and
/// `project_path`, and every assistant `messages` row carries a
/// `metrics_json` blob whose `usage` object
/// (`inputTokens`/`cachedInputTokens`/`outputTokens`/`reasoningOutputTokens`)
/// holds that turn's token counts once the harness has reported them. Only
/// those fields — plus `thread_id`, `seq`, and `ts` — are ever read;
/// `parts_json` (the actual prompt/response content) is never touched.
///
/// Like `OpencodeScanner`, this reads an external SQLite database directly
/// rather than through drift, and tracks a rescan watermark by the highest
/// `ts` seen so far (stored in [AiUsageDatabase.aiUsageScanFiles], keyed by
/// each project database's own path) rather than by file position, since
/// rows are queried out of a live database, not read line-by-line.
class FreebuffScanner {
  const FreebuffScanner();

  /// Locates Freebuff's local projects directory, or null if this device
  /// doesn't have one (Freebuff has never run here, or the home directory
  /// couldn't be resolved).
  Directory? projectsDirectory() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return null;
    final dir = Directory(
      '$home${Platform.pathSeparator}.config${Platform.pathSeparator}freebuff-desktop${Platform.pathSeparator}projects',
    );
    return dir.existsSync() ? dir : null;
  }

  Future<FreebuffScanResult> scan(AiUsageDatabase db) =>
      scanDirectory(db, projectsDirectory());

  /// Scans [dir] directly — split out from [scan] so tests can point it at a
  /// fixture directory instead of the real
  /// `~/.config/freebuff-desktop/projects`.
  Future<FreebuffScanResult> scanDirectory(
    AiUsageDatabase db,
    Directory? dir,
  ) async {
    if (dir == null) return FreebuffScanResult.unavailable;

    List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return const FreebuffScanResult(projectsDirFound: true);
    }

    var projectsScanned = 0;
    var turnsAdded = 0;
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final dbFile = File(
        '${entry.path}${Platform.pathSeparator}desktop-v2.db',
      );
      if (!dbFile.existsSync()) continue;
      try {
        turnsAdded += await _scanProjectDb(db, dbFile);
        projectsScanned++;
      } catch (_) {
        // A locked, mid-write, or corrupt project database must not abort
        // the rest of the scan.
        continue;
      }
    }

    return FreebuffScanResult(
      projectsDirFound: true,
      projectsScanned: projectsScanned,
      turnsAdded: turnsAdded,
    );
  }

  Future<int> _scanProjectDb(AiUsageDatabase db, File file) async {
    final existing = await (db.select(db.aiUsageScanFiles)
          ..where((t) => t.path.equals(file.path)))
        .getSingleOrNull();
    final sinceMs = existing?.mtimeMs.toInt() ?? 0;

    sqlite.Database? sqliteDb;
    try {
      sqliteDb = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    } catch (_) {
      return 0;
    }

    try {
      final modelByThread = <String, String>{};
      final projectPathByThread = <String, String?>{};
      for (final row in sqliteDb.select('SELECT id, model, project_path FROM threads')) {
        final id = row['id'] as String?;
        if (id == null) continue;
        modelByThread[id] = (row['model'] as String?) ?? '';
        projectPathByThread[id] = row['project_path'] as String?;
      }

      final rows = sqliteDb.select(
        "SELECT seq, thread_id, metrics_json, ts FROM messages "
        "WHERE role = 'assistant' AND ts > ? ORDER BY ts ASC",
        [sinceMs],
      );

      final newTurns = <AiUsageTurnsCompanion>[];
      var maxMs = sinceMs;
      for (final row in rows) {
        final ts = (row['ts'] as num).toInt();
        if (ts > maxMs) maxMs = ts;
        final turn = _parseRow(row, modelByThread, projectPathByThread);
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

      return newTurns.length;
    } finally {
      sqliteDb.close();
    }
  }

  /// Parses one `messages` row into an insertable turn, or null if it isn't
  /// an assistant record, carries no `usage` in its `metrics_json` at all
  /// (a message still in flight, or one that never got metered — e.g. a
  /// steering/injection message), or carries no token usage. A single
  /// malformed row is swallowed here rather than aborting the rest of the
  /// scan.
  AiUsageTurnsCompanion? _parseRow(
    sqlite.Row row,
    Map<String, String> modelByThread,
    Map<String, String?> projectPathByThread,
  ) {
    try {
      final threadId = row['thread_id'] as String;
      final seq = row['seq'] as int;
      final ts = (row['ts'] as num).toInt();

      final decoded = jsonDecode(row['metrics_json'] as String? ?? '{}');
      if (decoded is! Map<String, dynamic>) return null;
      final usage = decoded['usage'];
      if (usage is! Map<String, dynamic>) return null;

      int field(String key) => (usage[key] as num?)?.toInt() ?? 0;
      final inputTokens = field('inputTokens');
      // Freebuff bills reasoning tokens at the output rate (same convention
      // as Codex's `reasoning_output_tokens` and opencode's `reasoning`),
      // so folding them into output keeps cost calculation accurate without
      // a dedicated schema column.
      final outputTokens = field('outputTokens') + field('reasoningOutputTokens');
      // Freebuff's own usage shape only ever reports a single cumulative
      // "already cached" count, not a separate cache-write tally — see
      // `freebuff_scanner.dart`'s class doc.
      final cacheRead = field('cachedInputTokens');
      if (inputTokens + outputTokens + cacheRead == 0) return null;

      final model = modelByThread[threadId] ?? '';
      final projectPath = projectPathByThread[threadId];

      return AiUsageTurnsCompanion.insert(
        sessionId: threadId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
        model: model,
        inputTokens: Value(inputTokens),
        outputTokens: Value(outputTokens),
        cacheReadTokens: Value(cacheRead),
        // Globally unique: thread ids are unique across every project
        // database, unlike `seq`, which only autoincrements within one.
        messageId: Value('$threadId#$seq'),
        project: Value(projectNameFromCwd(projectPath)),
        source: AiUsageSource.freebuff,
      );
    } catch (_) {
      return null;
    }
  }
}

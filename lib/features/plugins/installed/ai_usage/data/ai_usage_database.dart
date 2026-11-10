import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../ai_usage_source.dart';

part 'ai_usage_database.g.dart';

/// One assistant turn's token counts, read from a local coding CLI's session
/// log (Claude Code or Codex CLI). Only usage metadata is ever stored here —
/// never the prompt/response text itself.
///
/// On disk this is a view over interned rows — see [AiUsageTurnStorage].
class AiUsageTurns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get model => text()();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  IntColumn get cacheReadTokens => integer().withDefault(const Constant(0))();
  IntColumn get cacheCreationTokens => integer().withDefault(const Constant(0))();
  // Dedup key from the source record only — never the message content.
  TextColumn get messageId => text().nullable()();
  // Friendly project name derived from cwd (last two path segments). Null
  // for sources with no reliable project source (Antigravity).
  TextColumn get project => text().nullable()();
  // Which CLI this turn came from — determines which pricing table applies.
  TextColumn get source => textEnum<AiUsageSource>()();
  // Reasoning-effort tier, Claude Code only — null for sources that don't
  // record it (Codex CLI, Antigravity) and for values it didn't recognise.
  TextColumn get effort => textEnum<AiEffort>().nullable()();
  // USD cost the source tool worked out for this turn itself, when it
  // records one — opencode only, which computes it from models.dev and so
  // covers providers this app has no pricing table for. Null means "the
  // tool didn't say"; 0 is a real answer (a free model). Used only as a
  // fallback — see `costForRow` in ai_usage_stats.dart.
  RealColumn get reportedCost => real().nullable()();
  // Which of the user's other devices this turn was synced from. Null means
  // it was scanned on this device — the only rows this device ever uploads.
  TextColumn get deviceId => text().nullable()();
}

/// The user's other devices whose usage has been pulled from the sync server,
/// with the server version of each one's upload so an unchanged device is
/// never downloaded twice.
class AiUsageRemoteDevices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get name => text()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  IntColumn get turnCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get uploadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// Tracks which JSONL files have already been scanned (path + mtime + how
/// many lines were parsed), so a rescan can skip unchanged files entirely and
/// resume changed ones from where it left off instead of reparsing from
/// scratch.
class AiUsageScanFiles extends Table {
  TextColumn get path => text()();
  RealColumn get mtimeMs => real()();
  IntColumn get lineCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {path};
}

/// How `ai_usage_turns` is laid out on disk.
///
/// Drift sees the [AiUsageTurns] table, but in SQLite that name is a view.
/// The rows live in `ai_usage_turn_rows`, and every repeated string (session,
/// model, project, source, effort, device) is stored once in
/// `ai_usage_strings`, with each row holding only its integer id. Tens of
/// thousands of turns share a couple of thousand distinct strings, so the
/// table shrinks to well under half its old size. INSTEAD OF triggers on the
/// view intern strings on insert and forward deletes, so every scanner, query
/// and stream keeps using the drift table as if it were real.
///
/// A view has no column defaults, which is why the insert trigger fills the
/// token counts in itself. It also reports zero changed rows for a delete,
/// so deletes go through [AiUsageDatabase.deleteTurns].
abstract final class AiUsageTurnStorage {
  static const _createStrings =
      'CREATE TABLE IF NOT EXISTS ai_usage_strings ('
      'id INTEGER PRIMARY KEY, value TEXT NOT NULL UNIQUE)';

  static const _createRows =
      'CREATE TABLE IF NOT EXISTS ai_usage_turn_rows ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'session INTEGER NOT NULL, '
      'timestamp INTEGER NOT NULL, '
      'model INTEGER NOT NULL, '
      'input_tokens INTEGER NOT NULL DEFAULT 0, '
      'output_tokens INTEGER NOT NULL DEFAULT 0, '
      'cache_read_tokens INTEGER NOT NULL DEFAULT 0, '
      'cache_creation_tokens INTEGER NOT NULL DEFAULT 0, '
      'message_id TEXT, '
      'project INTEGER, '
      'source INTEGER NOT NULL, '
      'effort INTEGER, '
      'reported_cost REAL, '
      'device INTEGER)';

  static const _createView =
      'CREATE VIEW IF NOT EXISTS ai_usage_turns AS SELECT '
      'r.id AS id, '
      'session.value AS session_id, '
      'r.timestamp AS timestamp, '
      'model.value AS model, '
      'r.input_tokens AS input_tokens, '
      'r.output_tokens AS output_tokens, '
      'r.cache_read_tokens AS cache_read_tokens, '
      'r.cache_creation_tokens AS cache_creation_tokens, '
      'r.message_id AS message_id, '
      'project.value AS project, '
      'source.value AS source, '
      'effort.value AS effort, '
      'r.reported_cost AS reported_cost, '
      'device.value AS device_id '
      'FROM ai_usage_turn_rows r '
      'JOIN ai_usage_strings session ON session.id = r.session '
      'JOIN ai_usage_strings model ON model.id = r.model '
      'JOIN ai_usage_strings source ON source.id = r.source '
      'LEFT JOIN ai_usage_strings project ON project.id = r.project '
      'LEFT JOIN ai_usage_strings effort ON effort.id = r.effort '
      'LEFT JOIN ai_usage_strings device ON device.id = r.device';

  static String _lookup(String column) =>
      '(SELECT id FROM ai_usage_strings WHERE value = NEW.$column)';

  // OR IGNORE skips both strings already interned and the NULLs of
  // optional columns, which the NOT NULL constraint would otherwise reject.
  static final _createInsertTrigger =
      'CREATE TRIGGER IF NOT EXISTS ai_usage_turns_insert '
      'INSTEAD OF INSERT ON ai_usage_turns BEGIN '
      'INSERT OR IGNORE INTO ai_usage_strings (value) VALUES '
      '(NEW.session_id), (NEW.model), (NEW.project), (NEW.source), '
      '(NEW.effort), (NEW.device_id); '
      'INSERT INTO ai_usage_turn_rows (id, session, timestamp, model, '
      'input_tokens, output_tokens, cache_read_tokens, '
      'cache_creation_tokens, message_id, project, source, effort, '
      'reported_cost, device) VALUES (NEW.id, '
      '${_lookup('session_id')}, NEW.timestamp, ${_lookup('model')}, '
      'COALESCE(NEW.input_tokens, 0), COALESCE(NEW.output_tokens, 0), '
      'COALESCE(NEW.cache_read_tokens, 0), '
      'COALESCE(NEW.cache_creation_tokens, 0), NEW.message_id, '
      '${_lookup('project')}, ${_lookup('source')}, ${_lookup('effort')}, '
      'NEW.reported_cost, ${_lookup('device_id')}); END';

  static const _createDeleteTrigger =
      'CREATE TRIGGER IF NOT EXISTS ai_usage_turns_delete '
      'INSTEAD OF DELETE ON ai_usage_turns BEGIN '
      'DELETE FROM ai_usage_turn_rows WHERE id = OLD.id; END';

  /// Moves a schema-6 `ai_usage_turns` table into the interned rows,
  /// keeping every row id and the AUTOINCREMENT high-water mark: the cloud
  /// sync fingerprints this device's upload by row count and max id.
  static const _copyFromTable = [
    'INSERT OR IGNORE INTO ai_usage_strings (value) '
        'SELECT session_id FROM ai_usage_turns UNION '
        'SELECT model FROM ai_usage_turns UNION '
        'SELECT project FROM ai_usage_turns UNION '
        'SELECT source FROM ai_usage_turns UNION '
        'SELECT effort FROM ai_usage_turns UNION '
        'SELECT device_id FROM ai_usage_turns',
    'INSERT INTO ai_usage_turn_rows (id, session, timestamp, model, '
        'input_tokens, output_tokens, cache_read_tokens, '
        'cache_creation_tokens, message_id, project, source, effort, '
        'reported_cost, device) '
        'SELECT t.id, session.id, t.timestamp, model.id, t.input_tokens, '
        't.output_tokens, t.cache_read_tokens, t.cache_creation_tokens, '
        't.message_id, project.id, source.id, effort.id, t.reported_cost, '
        'device.id FROM ai_usage_turns t '
        'JOIN ai_usage_strings session ON session.value = t.session_id '
        'JOIN ai_usage_strings model ON model.value = t.model '
        'JOIN ai_usage_strings source ON source.value = t.source '
        'LEFT JOIN ai_usage_strings project ON project.value = t.project '
        'LEFT JOIN ai_usage_strings effort ON effort.value = t.effort '
        'LEFT JOIN ai_usage_strings device ON device.value = t.device_id '
        'ORDER BY t.id',
    'INSERT INTO sqlite_sequence (name, seq) '
        "SELECT 'ai_usage_turn_rows', 0 WHERE NOT EXISTS (SELECT 1 FROM "
        "sqlite_sequence WHERE name = 'ai_usage_turn_rows')",
    'UPDATE sqlite_sequence SET seq = MAX(seq, COALESCE((SELECT MAX(seq) '
        "FROM sqlite_sequence WHERE name = 'ai_usage_turns'), 0)) "
        "WHERE name = 'ai_usage_turn_rows'",
    'DROP TABLE ai_usage_turns',
  ];

  /// The scan bookkeeping is keyed by a long file path. Without a rowid the
  /// table itself is the primary-key index, rather than every path being
  /// stored twice.
  static const _createScanFiles =
      'CREATE TABLE IF NOT EXISTS ai_usage_scan_files ('
      'path TEXT NOT NULL PRIMARY KEY, '
      'mtime_ms REAL NOT NULL, '
      'line_count INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID';

  static const _rebuildScanFiles = [
    'ALTER TABLE ai_usage_scan_files RENAME TO ai_usage_scan_files_old',
    _createScanFiles,
    'INSERT INTO ai_usage_scan_files (path, mtime_ms, line_count) '
        'SELECT path, mtime_ms, line_count FROM ai_usage_scan_files_old',
    'DROP TABLE ai_usage_scan_files_old',
  ];

  static List<String> get _viewAndTriggers => [
    _createView,
    _createInsertTrigger,
    _createDeleteTrigger,
  ];

  /// A fresh database: interned turns plus the rowid-less scan table.
  static List<String> get create => [
    _createStrings,
    _createRows,
    ..._viewAndTriggers,
    _createScanFiles,
  ];

  /// Schema 6 → 7: the same layout, filled from the old plain table.
  static List<String> get upgradeFromTable => [
    _createStrings,
    _createRows,
    ..._copyFromTable,
    ..._viewAndTriggers,
    ..._rebuildScanFiles,
  ];
}

@DriftDatabase(tables: [AiUsageTurns, AiUsageScanFiles, AiUsageRemoteDevices])
class AiUsageDatabase extends _$AiUsageDatabase {
  AiUsageDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_ai_usage',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 7;

  Future<void> _run(List<String> statements) async {
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  /// Deletes the turns [filter] matches and returns how many there were.
  ///
  /// `ai_usage_turns` is a view (see [AiUsageTurnStorage]), and SQLite
  /// reports zero changes for a delete through one, so a plain drift delete
  /// would return 0 and never wake the streams watching the turns.
  Future<int> deleteTurns(
    Expression<bool> Function($AiUsageTurnsTable t) filter,
  ) {
    return transaction(() async {
      final count = aiUsageTurns.id.count();
      final matching =
          await (selectOnly(aiUsageTurns)
                ..addColumns([count])
                ..where(filter(aiUsageTurns)))
              .map((row) => row.read(count) ?? 0)
              .getSingle();
      if (matching == 0) return 0;
      await (delete(aiUsageTurns)..where(filter)).go();
      notifyUpdates({
        TableUpdate.onTable(aiUsageTurns, kind: UpdateKind.delete),
      });
      return matching;
    });
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await _run(AiUsageTurnStorage.create);
          await m.createTable(aiUsageRemoteDevices);
        },
        onUpgrade: (m, from, to) async {
          if (from < 5) {
            // Both tables here are a derived, re-scannable cache of local
            // session logs — simplest correct migration for any schema
            // change (the required `source` column at v2, `project` at v3,
            // `effort` at v4, `reportedCost` at v5) is to drop and recreate
            // rather than synthesize values for old rows; the next rescan
            // repopulates everything from scratch.
            await customStatement('DROP TABLE IF EXISTS ai_usage_turns');
            await customStatement('DROP TABLE IF EXISTS ai_usage_scan_files');
            await _run(AiUsageTurnStorage.create);
            await m.createTable(aiUsageRemoteDevices);
            return;
          }
          await transaction(() async {
            if (from < 6) {
              await customStatement(
                'ALTER TABLE ai_usage_turns ADD COLUMN device_id TEXT',
              );
              await m.createTable(aiUsageRemoteDevices);
            }
            if (from < 7) await _run(AiUsageTurnStorage.upgradeFromTable);
          });
        },
        beforeOpen: (details) async {
          // Range queries filter and order by time. Per-device lookups only
          // ever ask about synced rows, so that index leaves out this
          // device's own (NULL) rows, which are nearly all of them.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS ai_usage_turn_rows_timestamp '
            'ON ai_usage_turn_rows (timestamp)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS ai_usage_turn_rows_device '
            'ON ai_usage_turn_rows (device) WHERE device IS NOT NULL',
          );
          final before = details.versionBefore;
          if (details.hadUpgrade && before != null && before < 7) {
            // The old table's pages are only free space inside the file
            // until a VACUUM gives them back to the disk.
            try {
              await customStatement('VACUUM');
            } catch (_) {}
          }
        },
      );
}

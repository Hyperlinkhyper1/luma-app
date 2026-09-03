import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../ai_usage_source.dart';

part 'ai_usage_database.g.dart';

/// One assistant turn's token counts, read from a local coding CLI's session
/// log (Claude Code or Codex CLI). Only usage metadata is ever stored here —
/// never the prompt/response text itself.
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

@DriftDatabase(tables: [AiUsageTurns, AiUsageScanFiles])
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
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
            await m.createTable(aiUsageTurns);
            await m.createTable(aiUsageScanFiles);
          }
        },
      );
}

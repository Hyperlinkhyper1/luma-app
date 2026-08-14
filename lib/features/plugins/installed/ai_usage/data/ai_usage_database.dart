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
  // Which CLI this turn came from — determines which pricing table applies.
  TextColumn get source => textEnum<AiUsageSource>()();
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
  int get schemaVersion => 1;
}

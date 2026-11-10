import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:sqlite3/sqlite3.dart';

AiUsageTurnsCompanion _turn({
  String session = 's1',
  String model = 'claude-opus-4-6',
  String? project = 'luma/app',
  AiEffort? effort,
  String? deviceId,
  int input = 0,
  DateTime? at,
}) => AiUsageTurnsCompanion.insert(
  sessionId: session,
  timestamp: at ?? DateTime.utc(2026, 11, 1, 12),
  model: model,
  source: AiUsageSource.claudeCode,
  inputTokens: input == 0 ? const Value.absent() : Value(input),
  project: Value(project),
  effort: Value(effort),
  deviceId: Value(deviceId),
  messageId: const Value('msg'),
);

void main() {
  group('interned turn storage', () {
    late AiUsageDatabase db;

    setUp(() => db = AiUsageDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('turns read back exactly as written, defaults included', () async {
      await db.into(db.aiUsageTurns).insert(_turn(effort: AiEffort.high));
      await db.into(db.aiUsageTurns).insert(_turn(project: null, input: 7));

      final rows = await (db.select(
        db.aiUsageTurns,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(rows, hasLength(2));
      expect(rows[0].sessionId, 's1');
      expect(rows[0].model, 'claude-opus-4-6');
      expect(rows[0].project, 'luma/app');
      expect(rows[0].effort, AiEffort.high);
      expect(rows[0].inputTokens, 0);
      expect(rows[0].outputTokens, 0);
      expect(rows[0].deviceId, isNull);
      expect(rows[0].timestamp.toUtc(), DateTime.utc(2026, 11, 1, 12));
      expect(rows[1].project, isNull);
      expect(rows[1].effort, isNull);
      expect(rows[1].inputTokens, 7);
      expect(rows[1].id, greaterThan(rows[0].id));
    });

    test('a repeated string is stored once', () async {
      await db.batch((b) {
        b.insertAll(db.aiUsageTurns, [
          for (var i = 0; i < 50; i++) _turn(deviceId: i.isEven ? 'dev' : null),
        ]);
      });
      final strings = await db
          .customSelect('SELECT value FROM ai_usage_strings')
          .map((row) => row.read<String>('value'))
          .get();
      expect(
        strings,
        unorderedEquals(['s1', 'claude-opus-4-6', 'luma/app', 'claudeCode', 'dev']),
      );
    });

    test('deleteTurns counts the rows and wakes watchers', () async {
      await db.batch((b) {
        b.insertAll(db.aiUsageTurns, [
          _turn(deviceId: 'laptop'),
          _turn(deviceId: 'laptop'),
          _turn(),
        ]);
      });
      final seen = <int>[];
      final sub = db
          .select(db.aiUsageTurns)
          .watch()
          .listen((rows) => seen.add(rows.length));
      await pumpEventQueue();

      expect(await db.deleteTurns((t) => t.deviceId.equals('laptop')), 2);
      expect(await db.deleteTurns((t) => t.deviceId.equals('laptop')), 0);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, [3, 1]);
      final left = await db.select(db.aiUsageTurns).get();
      expect(left.single.deviceId, isNull);
    });

    test('per-device and time-range filters still work on the view', () async {
      await db.batch((b) {
        b.insertAll(db.aiUsageTurns, [
          _turn(deviceId: 'backend:a', at: DateTime.utc(2026, 1, 1)),
          _turn(deviceId: 'backend:b', at: DateTime.utc(2026, 6, 1)),
          _turn(at: DateTime.utc(2026, 9, 1)),
        ]);
      });
      final backend = await (db.select(db.aiUsageTurns)..where(
            (t) =>
                t.deviceId.isBiggerOrEqualValue('backend:') &
                t.deviceId.isSmallerThanValue('backend;'),
          ))
          .get();
      expect(backend, hasLength(2));
      final recent = await (db.select(db.aiUsageTurns)..where(
            (t) => t.timestamp.isBiggerOrEqualValue(DateTime.utc(2026, 5, 1)),
          ))
          .get();
      expect(recent, hasLength(2));
    });
  });

  test('a schema-6 database moves into interned storage intact', () async {
    final dir = await Directory.systemTemp.createTemp('ai_usage_v6');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/luma_ai_usage.sqlite');

    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE ai_usage_turns (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL, timestamp INTEGER NOT NULL,
        model TEXT NOT NULL,
        input_tokens INTEGER NOT NULL DEFAULT 0,
        output_tokens INTEGER NOT NULL DEFAULT 0,
        cache_read_tokens INTEGER NOT NULL DEFAULT 0,
        cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
        message_id TEXT NULL, project TEXT NULL, source TEXT NOT NULL,
        effort TEXT NULL, reported_cost REAL NULL, device_id TEXT NULL);
      CREATE TABLE ai_usage_scan_files (
        path TEXT NOT NULL, mtime_ms REAL NOT NULL,
        line_count INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (path));
      CREATE TABLE ai_usage_remote_devices (
        device_id TEXT NOT NULL, name TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 0,
        turn_count INTEGER NOT NULL DEFAULT 0,
        uploaded_at INTEGER NOT NULL, PRIMARY KEY (device_id));
      CREATE INDEX ai_usage_turns_timestamp ON ai_usage_turns (timestamp);
      INSERT INTO ai_usage_turns (id, session_id, timestamp, model,
        input_tokens, output_tokens, message_id, project, source, effort,
        reported_cost, device_id) VALUES
        (3, 'sA', 1000, 'gpt-5', 10, 20, 'm1', NULL, 'codexCli', NULL, NULL, NULL),
        (8, 'sB', 2000, 'opus', 1, 2, 'm2', 'luma/app', 'claudeCode', 'high', 0.5, 'laptop');
      UPDATE sqlite_sequence SET seq = 12 WHERE name = 'ai_usage_turns';
      INSERT INTO ai_usage_scan_files VALUES ('C:/logs/a.jsonl', 123.5, 40);
      PRAGMA user_version = 6;
    ''');
    raw.close();

    final db = AiUsageDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await (db.select(
      db.aiUsageTurns,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(rows.map((r) => r.id), [3, 8]);
    expect(rows[0].sessionId, 'sA');
    expect(rows[0].source, AiUsageSource.codexCli);
    expect(rows[0].project, isNull);
    expect(rows[0].inputTokens, 10);
    expect(rows[0].timestamp.millisecondsSinceEpoch, 1000 * 1000);
    expect(rows[1].effort, AiEffort.high);
    expect(rows[1].reportedCost, 0.5);
    expect(rows[1].deviceId, 'laptop');
    expect(rows[1].messageId, 'm2');

    final scan = await db.select(db.aiUsageScanFiles).getSingle();
    expect(scan.path, 'C:/logs/a.jsonl');
    expect(scan.lineCount, 40);

    // The AUTOINCREMENT high-water mark survives, so ids never repeat.
    await db.into(db.aiUsageTurns).insert(_turn());
    final newest = await (db.select(
      db.aiUsageTurns,
    )..orderBy([(t) => OrderingTerm.desc(t.id)])).get();
    expect(newest.first.id, 13);

    final kind = await db
        .customSelect(
          "SELECT type FROM sqlite_master WHERE name = 'ai_usage_turns'",
        )
        .map((row) => row.read<String>('type'))
        .getSingle();
    expect(kind, 'view');
  });
}

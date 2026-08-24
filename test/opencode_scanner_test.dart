import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/opencode_scanner.dart';

/// Builds a fixture `opencode.db` with just the columns the scanner reads —
/// a minimal stand-in for the real `message`/`session` schema opencode's
/// Drizzle migrations create.
sqlite.Database _openFixtureDb(String path) {
  final db = sqlite.sqlite3.open(path);
  db.execute('''
    CREATE TABLE message (
      id text PRIMARY KEY,
      session_id text NOT NULL,
      time_created integer NOT NULL,
      time_updated integer NOT NULL,
      data text NOT NULL
    )
  ''');
  return db;
}

void _insertMessage(
  sqlite.Database db, {
  required String id,
  required String sessionId,
  required int timeCreated,
  required Map<String, dynamic> data,
}) {
  db.execute(
    'INSERT INTO message (id, session_id, time_created, time_updated, data) VALUES (?, ?, ?, ?, ?)',
    [id, sessionId, timeCreated, timeCreated, jsonEncode(data)],
  );
}

Map<String, dynamic> _assistantData({
  String providerId = 'anthropic',
  String modelId = 'claude-opus-4-6',
  int input = 1000,
  int output = 200,
  int reasoning = 0,
  int cacheRead = 0,
  int cacheWrite = 0,
  String? cwd = r'C:\Users\ayden\project',
  int timeCreated = 1787479979983,
  num? cost = 0,
}) =>
    {
      'role': 'assistant',
      'mode': 'build',
      'agent': 'build',
      'cost': ?cost,
      'tokens': {
        'input': input,
        'output': output,
        'reasoning': reasoning,
        'cache': {'read': cacheRead, 'write': cacheWrite},
      },
      'modelID': modelId,
      'providerID': providerId,
      if (cwd != null) 'path': {'cwd': cwd, 'root': '/'},
      'time': {'created': timeCreated},
    };

void main() {
  late Directory tempDir;
  late AiUsageDatabase db;
  const scanner = OpencodeScanner();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opencode_scanner_test_');
    db = AiUsageDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  File dbPath(String name) => File('${tempDir.path}${Platform.pathSeparator}$name');

  test('an assistant message with token usage parses into a turn', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1787479979983,
      data: _assistantData(input: 1000, output: 200, reasoning: 50, cacheRead: 300, cacheWrite: 20),
    );
    sqliteDb.close();

    final result = await scanner.scanFile(db, path);
    expect(result.dbFound, isTrue);
    expect(result.turnsAdded, 1);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.sessionId, 'ses-1');
    expect(row.messageId, 'msg-1');
    expect(row.model, 'anthropic/claude-opus-4-6');
    expect(row.source, AiUsageSource.opencode);
    expect(row.inputTokens, 1000);
    expect(row.outputTokens, 200 + 50, reason: 'reasoning tokens are folded into output');
    expect(row.cacheReadTokens, 300);
    expect(row.cacheCreationTokens, 20);
    expect(row.project, 'ayden/project');
  });

  test('a user message (no tokens field) is skipped', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1787479979983,
      data: {'role': 'user', 'time': {'created': 1787479979983}},
    );
    sqliteDb.close();

    final result = await scanner.scanFile(db, path);
    expect(result.turnsAdded, 0);
    expect(await db.select(db.aiUsageTurns).get(), isEmpty);
  });

  test('an all-zero-token assistant message is skipped', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1787479979983,
      data: _assistantData(input: 0, output: 0),
    );
    sqliteDb.close();

    final result = await scanner.scanFile(db, path);
    expect(result.turnsAdded, 0);
  });

  test('a null file (no local install found) is a clean unavailable result', () async {
    final result = await scanner.scanFile(db, null);
    expect(result.dbFound, isFalse);
    expect(result.turnsAdded, 0);
  });

  test('a path to a nonexistent db file fails open gracefully', () async {
    final result = await scanner.scanFile(db, dbPath('missing.db'));
    expect(result.dbFound, isTrue);
    expect(result.turnsAdded, 0);
  });

  test('a rescan only picks up messages created after the watermark', () async {
    final path = dbPath('opencode.db');
    var sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1000,
      data: _assistantData(timeCreated: 1000),
    );
    sqliteDb.close();

    final first = await scanner.scanFile(db, path);
    expect(first.turnsAdded, 1);

    sqliteDb = sqlite.sqlite3.open(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-2',
      sessionId: 'ses-1',
      timeCreated: 2000,
      data: _assistantData(timeCreated: 2000),
    );
    sqliteDb.close();

    final second = await scanner.scanFile(db, path);
    expect(second.turnsAdded, 1, reason: 'only msg-2 is newer than the stored watermark');

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(2));
  });

  test('rescanning with no new messages adds nothing', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1000,
      data: _assistantData(timeCreated: 1000),
    );
    sqliteDb.close();

    await scanner.scanFile(db, path);
    final second = await scanner.scanFile(db, path);
    expect(second.turnsAdded, 0);
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));
  });

  test('an opencode-provider (OpenCode Zen catalog) model still records the turn', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1000,
      data: _assistantData(providerId: 'opencode', modelId: 'x-preview-f-free', input: 500, output: 50),
    );
    sqliteDb.close();

    await scanner.scanFile(db, path);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.model, 'opencode/x-preview-f-free');
  });

  test("stores opencode's own per-turn cost", () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1000,
      data: _assistantData(
        providerId: 'minimax',
        modelId: 'MiniMax-M3',
        cost: 0.0042,
      ),
    );
    sqliteDb.close();

    await scanner.scanFile(db, path);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.reportedCost, closeTo(0.0042, 1e-9));
  });

  test('a recorded cost of zero is kept, not treated as absent', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1000,
      data: _assistantData(
        providerId: 'opencode',
        modelId: 'x-preview-f-free',
        cost: 0,
      ),
    );
    sqliteDb.close();

    await scanner.scanFile(db, path);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.reportedCost, 0);
  });

  test('a record with no cost field stores a null cost', () async {
    final path = dbPath('opencode.db');
    final sqliteDb = _openFixtureDb(path.path);
    _insertMessage(
      sqliteDb,
      id: 'msg-1',
      sessionId: 'ses-1',
      timeCreated: 1000,
      data: _assistantData(cost: null),
    );
    sqliteDb.close();

    await scanner.scanFile(db, path);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.reportedCost, null);
  });
}

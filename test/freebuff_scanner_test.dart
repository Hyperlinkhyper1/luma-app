import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/freebuff_scanner.dart';

/// Builds a fixture `desktop-v2.db` with just the columns the scanner reads
/// — a minimal stand-in for the real `threads`/`messages` schema Freebuff's
/// own migrations create.
sqlite.Database _openFixtureDb(String path) {
  final db = sqlite.sqlite3.open(path);
  db.execute('''
    CREATE TABLE threads (
      id text PRIMARY KEY,
      model text,
      project_path text NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE messages (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      thread_id text NOT NULL,
      role text NOT NULL,
      metrics_json text NOT NULL DEFAULT '{}',
      ts integer NOT NULL
    )
  ''');
  return db;
}

void _insertThread(
  sqlite.Database db, {
  required String id,
  String? model,
  String projectPath = r'C:\Users\ayden\project',
}) {
  db.execute(
    'INSERT INTO threads (id, model, project_path) VALUES (?, ?, ?)',
    [id, model, projectPath],
  );
}

void _insertMessage(
  sqlite.Database db, {
  required String threadId,
  String role = 'assistant',
  required int ts,
  Map<String, dynamic>? metrics,
}) {
  db.execute(
    'INSERT INTO messages (thread_id, role, metrics_json, ts) VALUES (?, ?, ?, ?)',
    [threadId, role, jsonEncode(metrics ?? {}), ts],
  );
}

Map<String, dynamic> _metrics({
  int inputTokens = 1000,
  int outputTokens = 200,
  int reasoningOutputTokens = 0,
  int cachedInputTokens = 0,
}) =>
    {
      'usage': {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'reasoningOutputTokens': reasoningOutputTokens,
        'cachedInputTokens': cachedInputTokens,
        'totalTokens': inputTokens + outputTokens + reasoningOutputTokens,
      },
      'context': {'usedTokens': inputTokens + outputTokens},
    };

void main() {
  late Directory tempDir;
  late AiUsageDatabase db;
  const scanner = FreebuffScanner();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freebuff_scanner_test_');
    db = AiUsageDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Directory projectDir(String name) {
    final dir = Directory('${tempDir.path}${Platform.pathSeparator}$name');
    dir.createSync();
    return dir;
  }

  File dbFileIn(Directory dir) =>
      File('${dir.path}${Platform.pathSeparator}desktop-v2.db');

  test('an assistant message with usage tokens parses into a turn', () async {
    final dir = projectDir('luma-app-abc123');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'claude-opus-4-8');
    _insertMessage(
      sqliteDb,
      threadId: 'thread-1',
      ts: 1787479979983,
      metrics: _metrics(inputTokens: 1000, outputTokens: 200, reasoningOutputTokens: 50, cachedInputTokens: 300),
    );
    sqliteDb.close();

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.projectsDirFound, isTrue);
    expect(result.projectsScanned, 1);
    expect(result.turnsAdded, 1);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.sessionId, 'thread-1');
    expect(row.messageId, 'thread-1#1');
    expect(row.model, 'claude-opus-4-8');
    expect(row.source, AiUsageSource.freebuff);
    expect(row.inputTokens, 1000);
    expect(row.outputTokens, 200 + 50, reason: 'reasoning tokens are folded into output');
    expect(row.cacheReadTokens, 300);
    expect(row.cacheCreationTokens, 0);
    expect(row.project, 'ayden/project');
  });

  test('a user message (no usage in metrics) is skipped', () async {
    final dir = projectDir('proj');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'claude-opus-4-8');
    _insertMessage(sqliteDb, threadId: 'thread-1', role: 'user', ts: 1000, metrics: {});
    sqliteDb.close();

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 0);
    expect(await db.select(db.aiUsageTurns).get(), isEmpty);
  });

  test('an assistant message with no usage object yet (in-flight turn) is skipped', () async {
    final dir = projectDir('proj');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'claude-opus-4-8');
    _insertMessage(sqliteDb, threadId: 'thread-1', ts: 1000, metrics: {'compactions': []});
    sqliteDb.close();

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 0);
  });

  test('an all-zero-token assistant message is skipped', () async {
    final dir = projectDir('proj');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'claude-opus-4-8');
    _insertMessage(
      sqliteDb,
      threadId: 'thread-1',
      ts: 1000,
      metrics: _metrics(inputTokens: 0, outputTokens: 0),
    );
    sqliteDb.close();

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 0);
  });

  test('a null directory (no local install found) is a clean unavailable result', () async {
    final result = await scanner.scanDirectory(db, null);
    expect(result.projectsDirFound, isFalse);
    expect(result.turnsAdded, 0);
  });

  test('a projects directory with no project subfolders scans cleanly', () async {
    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.projectsDirFound, isTrue);
    expect(result.projectsScanned, 0);
    expect(result.turnsAdded, 0);
  });

  test('a project folder missing desktop-v2.db is skipped, not fatal', () async {
    projectDir('empty-project');
    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.projectsDirFound, isTrue);
    expect(result.projectsScanned, 0);
    expect(result.turnsAdded, 0);
  });

  test('multiple projects are scanned together', () async {
    final dirA = projectDir('proj-a');
    final sqliteA = _openFixtureDb(dbFileIn(dirA).path);
    _insertThread(sqliteA, id: 'thread-a', model: 'claude-opus-4-8');
    _insertMessage(sqliteA, threadId: 'thread-a', ts: 1000, metrics: _metrics());
    sqliteA.close();

    final dirB = projectDir('proj-b');
    final sqliteB = _openFixtureDb(dbFileIn(dirB).path);
    _insertThread(sqliteB, id: 'thread-b', model: 'z-ai/glm-5.3-flash');
    _insertMessage(sqliteB, threadId: 'thread-b', ts: 1000, metrics: _metrics());
    sqliteB.close();

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.projectsScanned, 2);
    expect(result.turnsAdded, 2);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows.map((r) => r.messageId), containsAll(['thread-a#1', 'thread-b#1']));
  });

  test('a Freebuff-native provider-prefixed model records the turn', () async {
    final dir = projectDir('proj');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'z-ai/glm-5.3-flash');
    _insertMessage(sqliteDb, threadId: 'thread-1', ts: 1000, metrics: _metrics());
    sqliteDb.close();

    await scanner.scanDirectory(db, tempDir);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.model, 'z-ai/glm-5.3-flash');
  });

  test('a rescan only picks up messages created after the watermark', () async {
    final dir = projectDir('proj');
    var sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'claude-opus-4-8');
    _insertMessage(sqliteDb, threadId: 'thread-1', ts: 1000, metrics: _metrics());
    sqliteDb.close();

    final first = await scanner.scanDirectory(db, tempDir);
    expect(first.turnsAdded, 1);

    sqliteDb = sqlite.sqlite3.open(dbFileIn(dir).path);
    _insertMessage(sqliteDb, threadId: 'thread-1', ts: 2000, metrics: _metrics());
    sqliteDb.close();

    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.turnsAdded, 1, reason: 'only the newer message is past the stored watermark');

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(2));
  });

  test('rescanning with no new messages adds nothing', () async {
    final dir = projectDir('proj');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: 'claude-opus-4-8');
    _insertMessage(sqliteDb, threadId: 'thread-1', ts: 1000, metrics: _metrics());
    sqliteDb.close();

    await scanner.scanDirectory(db, tempDir);
    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.turnsAdded, 0);
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));
  });

  test('a thread with no model recorded still stores the turn with an empty model', () async {
    final dir = projectDir('proj');
    final sqliteDb = _openFixtureDb(dbFileIn(dir).path);
    _insertThread(sqliteDb, id: 'thread-1', model: null);
    _insertMessage(sqliteDb, threadId: 'thread-1', ts: 1000, metrics: _metrics());
    sqliteDb.close();

    await scanner.scanDirectory(db, tempDir);

    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.model, '');
  });
}

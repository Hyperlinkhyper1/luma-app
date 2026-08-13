import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/claude_code_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

String _record({
  String type = 'assistant',
  String sessionId = 'sess-1',
  String timestamp = '2026-01-01T10:00:00.000Z',
  String? model = 'claude-sonnet-4-6',
  String? messageId = 'msg-1',
  int inputTokens = 100,
  int outputTokens = 50,
  int cacheRead = 0,
  int cacheCreation = 0,
}) {
  final message = <String, dynamic>{
    'usage': {
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'cache_read_input_tokens': cacheRead,
      'cache_creation_input_tokens': cacheCreation,
    },
  };
  if (messageId != null) message['id'] = messageId;
  if (model != null) message['model'] = model;
  return jsonEncode({
    'type': type,
    'sessionId': sessionId,
    'timestamp': timestamp,
    'message': message,
  });
}

void main() {
  late Directory tempDir;
  late AiUsageDatabase db;
  const scanner = ClaudeCodeScanner();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_usage_scanner_test_');
    db = AiUsageDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> writeLog(String name, List<String> lines, {DateTime? mtime}) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsString('${lines.join('\n')}\n');
    if (mtime != null) await file.setLastModified(mtime);
    return file;
  }

  test('parses a valid assistant record into a turn with correct token counts', () async {
    await writeLog('a.jsonl', [_record()], mtime: DateTime(2026, 1, 1));

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.projectsDirFound, isTrue);
    expect(result.turnsAdded, 1);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(1));
    expect(rows.single.sessionId, 'sess-1');
    expect(rows.single.model, 'claude-sonnet-4-6');
    expect(rows.single.inputTokens, 100);
    expect(rows.single.outputTokens, 50);
  });

  test('streaming records sharing a message id dedupe to the last one', () async {
    await writeLog(
      'a.jsonl',
      [
        _record(messageId: 'm1', inputTokens: 10, outputTokens: 5),
        _record(messageId: 'm1', inputTokens: 10, outputTokens: 40),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(1));
    expect(rows.single.outputTokens, 40, reason: 'final tally should win');
  });

  test('a turn with no token usage at all is skipped', () async {
    await writeLog(
      'a.jsonl',
      [_record(inputTokens: 0, outputTokens: 0, cacheRead: 0, cacheCreation: 0)],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);

    expect(await db.select(db.aiUsageTurns).get(), isEmpty);
  });

  test('a malformed line and a non-assistant line are skipped without aborting the file',
      () async {
    await writeLog(
      'a.jsonl',
      ['not valid json {{{', _record(type: 'user'), _record(messageId: 'm2')],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);

    expect(result.turnsAdded, 1);
    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows.single.messageId, 'm2');
  });

  test('rescanning an unchanged file adds nothing', () async {
    final mtime = DateTime(2026, 1, 1);
    await writeLog('a.jsonl', [_record()], mtime: mtime);

    final first = await scanner.scanDirectory(db, tempDir);
    expect(first.filesScanned, 1);

    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.filesScanned, 0, reason: 'unchanged mtime should be skipped entirely');
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));
  });

  test('rescanning after new lines are appended only adds the new turns', () async {
    final file = await writeLog('a.jsonl', [_record(messageId: 'm1')], mtime: DateTime(2026, 1, 1));

    await scanner.scanDirectory(db, tempDir);
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));

    await file.writeAsString('${_record(messageId: 'm2')}\n', mode: FileMode.append);
    await file.setLastModified(DateTime(2026, 1, 1, 0, 0, 1));

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 1);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.messageId), containsAll(['m1', 'm2']));
  });
}

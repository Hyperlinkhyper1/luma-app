import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/antigravity_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

String _userInput({
  String content = '<USER_REQUEST>\nHello there\n</USER_REQUEST>',
  String timestamp = '2026-07-18T12:31:39Z',
}) =>
    jsonEncode({
      'step_index': 0,
      'source': 'USER_EXPLICIT',
      'type': 'USER_INPUT',
      'status': 'DONE',
      'created_at': timestamp,
      'content': content,
    });

/// Real Antigravity behavior: the active model is only ever revealed as
/// prose inside a USER_INPUT's own content when the user (re)selects one.
String _modelChangeUserInput(String modelName, {String timestamp = '2026-07-18T12:31:39Z'}) =>
    _userInput(
      timestamp: timestamp,
      content: '<USER_REQUEST>\ndo something\n</USER_REQUEST>\n<USER_SETTINGS_CHANGE>\n'
          'The user changed setting `Model Selection` from None to $modelName. No need to '
          "comment on this change if the user doesn't ask about it. If reporting what model "
          'you are, please use a human readable name instead of the exact string.\n'
          '</USER_SETTINGS_CHANGE>',
    );

String _plannerResponse({
  String content = 'I will help with that.',
  String? thinking,
  List<Map<String, dynamic>>? toolCalls,
  String timestamp = '2026-07-18T12:31:45Z',
}) {
  final record = <String, dynamic>{
    'step_index': 2,
    'source': 'MODEL',
    'type': 'PLANNER_RESPONSE',
    'status': 'DONE',
    'created_at': timestamp,
    'content': content,
  };
  if (thinking != null) record['thinking'] = thinking;
  if (toolCalls != null) record['tool_calls'] = toolCalls;
  return jsonEncode(record);
}

String _systemRecord(String type, {String? content, String timestamp = '2026-07-18T12:31:40Z'}) {
  final record = <String, dynamic>{
    'step_index': 1,
    'source': 'SYSTEM',
    'type': type,
    'status': 'DONE',
    'created_at': timestamp,
  };
  if (content != null) record['content'] = content;
  return jsonEncode(record);
}

void main() {
  late Directory tempDir;
  late AiUsageDatabase db;
  const scanner = AntigravityScanner();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('antigravity_scanner_test_');
    db = AiUsageDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Builds `<tempDir>/<conversationId>/.system_generated/logs/transcript.jsonl`
  /// (the real Antigravity layout) and writes [lines] to it.
  Future<File> writeTranscript(
    String conversationId,
    List<String> lines, {
    DateTime? mtime,
    bool alsoWriteFullVariant = false,
  }) async {
    final logsDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}$conversationId'
      '${Platform.pathSeparator}.system_generated${Platform.pathSeparator}logs',
    );
    await logsDir.create(recursive: true);
    final file = File('${logsDir.path}${Platform.pathSeparator}transcript.jsonl');
    await file.writeAsString('${lines.join('\n')}\n');
    if (mtime != null) await file.setLastModified(mtime);
    if (alsoWriteFullVariant) {
      final full = File('${logsDir.path}${Platform.pathSeparator}transcript_full.jsonl');
      // Deliberately different content, to prove this file is never read.
      await full.writeAsString('${_userInput(content: 'x' * 100000)}\n');
      if (mtime != null) await full.setLastModified(mtime);
    }
    return file;
  }

  test('a USER_INPUT -> PLANNER_RESPONSE pair produces one estimated turn', () async {
    await writeTranscript(
      'conv-1',
      [_userInput(content: 'a' * 40), _plannerResponse(content: 'b' * 80)],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.brainDirFound, isTrue);
    expect(result.turnsAdded, 1);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.sessionId, 'conv-1');
    expect(row.source, AiUsageSource.antigravity);
    expect(row.inputTokens, 40 ~/ 4);
    expect(row.outputTokens, 80 ~/ 4);
    expect(row.cacheReadTokens, 0);
    expect(row.cacheCreationTokens, 0);
  });

  test('thinking and tool_calls both contribute to the output estimate', () async {
    await writeTranscript(
      'conv-1',
      [
        _userInput(content: ''),
        _plannerResponse(
          content: 'ok',
          thinking: 'x' * 100,
          toolCalls: [
            {
              'name': 'list_dir',
              'args': {'DirectoryPath': 'y' * 50},
            },
          ],
        ),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);
    final row = (await db.select(db.aiUsageTurns).get()).single;
    final expectedChars = 'ok'.length + 100 + jsonEncode([
          {
            'name': 'list_dir',
            'args': {'DirectoryPath': 'y' * 50},
          }
        ]).length;
    expect(row.outputTokens, expectedChars ~/ 4);
  });

  test('the model is parsed from a USER_SETTINGS_CHANGE block and persists across turns',
      () async {
    await writeTranscript(
      'conv-1',
      [
        _modelChangeUserInput('Claude Opus 4.6 (Thinking)'),
        _plannerResponse(content: 'first', timestamp: '2026-07-18T12:31:41Z'),
        _userInput(content: 'a follow-up with no model change'),
        _plannerResponse(content: 'second', timestamp: '2026-07-18T12:31:50Z'),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);
    final rows = await (db.select(db.aiUsageTurns)
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    expect(rows, hasLength(2));
    expect(rows[0].model, 'Claude Opus 4.6 (Thinking)');
    expect(rows[1].model, 'Claude Opus 4.6 (Thinking)',
        reason: 'model carries forward until changed again');
  });

  test('a mid-conversation model switch is picked up for later turns', () async {
    await writeTranscript(
      'conv-1',
      [
        _modelChangeUserInput('Gemini 3.1 Pro (High)', timestamp: '2026-07-18T12:00:00Z'),
        _plannerResponse(content: 'first', timestamp: '2026-07-18T12:00:05Z'),
        _modelChangeUserInputSwitch(),
        _plannerResponse(content: 'second', timestamp: '2026-07-18T12:10:05Z'),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);
    final rows = await (db.select(db.aiUsageTurns)
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    expect(rows[0].model, 'Gemini 3.1 Pro (High)');
    expect(rows[1].model, 'Claude Opus 4.6 (Thinking)');
  });

  test('SYSTEM records (checkpoints, history, ephemeral messages) are ignored', () async {
    await writeTranscript(
      'conv-1',
      [
        _userInput(content: 'a' * 20),
        _systemRecord('CHECKPOINT', content: 'z' * 5000),
        _systemRecord('CONVERSATION_HISTORY', content: 'z' * 5000),
        _systemRecord('EPHEMERAL_MESSAGE', content: 'z' * 5000),
        _plannerResponse(content: 'b' * 20),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 1, reason: 'only the real USER_INPUT/PLANNER_RESPONSE count');
    final row = (await db.select(db.aiUsageTurns).get()).single;
    expect(row.inputTokens, 20 ~/ 4, reason: 'the SYSTEM records must not affect the estimate');
  });

  test('a PLANNER_RESPONSE with no preceding input and empty content is skipped', () async {
    await writeTranscript(
      'conv-1',
      [_systemRecord('CONVERSATION_HISTORY'), _plannerResponse(content: '')],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 0);
  });

  test('only transcript.jsonl is scanned, never transcript_full.jsonl', () async {
    await writeTranscript(
      'conv-1',
      [_userInput(content: 'a' * 20), _plannerResponse(content: 'b' * 20)],
      mtime: DateTime(2026, 1, 1),
      alsoWriteFullVariant: true,
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.filesScanned, 1);
    expect(result.turnsAdded, 1);
  });

  test('a malformed line does not abort the rest of the file', () async {
    await writeTranscript(
      'conv-1',
      [_userInput(content: 'a' * 20), 'not valid json {{{', _plannerResponse(content: 'b' * 20)],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 1);
  });

  test('state from USER_INPUT survives an incremental rescan that only appends new lines',
      () async {
    final file = await writeTranscript(
      'conv-1',
      [
        _modelChangeUserInput('Claude Opus 4.6 (Thinking)', timestamp: '2026-07-18T12:00:00Z'),
        _plannerResponse(content: 'first', timestamp: '2026-07-18T12:00:05Z'),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    final first = await scanner.scanDirectory(db, tempDir);
    expect(first.turnsAdded, 1);

    // Append only a new user input + response — no repeated model-change
    // block. A naive implementation that skips already-scanned lines
    // outright (rather than just skipping their *emission*) would lose the
    // model state for this new turn.
    await file.writeAsString(
      '${_userInput(content: 'a follow-up')}\n'
      '${_plannerResponse(content: 'second', timestamp: '2026-07-18T12:10:00Z')}\n',
      mode: FileMode.append,
    );
    await file.setLastModified(DateTime(2026, 1, 1, 0, 0, 1));

    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.turnsAdded, 1);

    final rows = await (db.select(db.aiUsageTurns)
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    expect(rows, hasLength(2));
    expect(rows[1].model, 'Claude Opus 4.6 (Thinking)');
  });

  test('rescanning an unchanged file adds nothing', () async {
    final mtime = DateTime(2026, 1, 1);
    await writeTranscript(
      'conv-1',
      [_userInput(content: 'a' * 20), _plannerResponse(content: 'b' * 20)],
      mtime: mtime,
    );

    final first = await scanner.scanDirectory(db, tempDir);
    expect(first.filesScanned, 1);

    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.filesScanned, 0);
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));
  });
}

/// A second, later model-switch message reused by the mid-conversation
/// switch test — kept as a top-level helper since it needs a `from X to Y`
/// (not `from None to Y`) phrasing, which is what a real second switch
/// looks like.
String _modelChangeUserInputSwitch() => jsonEncode({
      'step_index': 3,
      'source': 'USER_EXPLICIT',
      'type': 'USER_INPUT',
      'status': 'DONE',
      'created_at': '2026-07-18T12:10:00Z',
      'content': '<USER_REQUEST>\nswitch models\n</USER_REQUEST>\n<USER_SETTINGS_CHANGE>\n'
          'The user changed setting `Model Selection` from Gemini 3.1 Pro (High) to Claude '
          "Opus 4.6 (Thinking). No need to comment on this change if the user doesn't ask "
          'about it. If reporting what model you are, please use a human readable name '
          'instead of the exact string.\n</USER_SETTINGS_CHANGE>',
    });

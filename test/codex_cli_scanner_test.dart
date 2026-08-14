import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/codex_cli_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

String _sessionMeta({String sessionId = 'sess-1'}) => jsonEncode({
      'timestamp': '2026-07-07T21:08:31.261Z',
      'type': 'session_meta',
      'payload': {
        'session_id': sessionId,
        'id': sessionId,
        'cwd': 'C:\\Users\\ayden\\project',
        'originator': 'Codex Desktop',
        'cli_version': '0.142.5',
        'model_provider': 'openai',
      },
    });

String _turnContext({String model = 'gpt-5.5'}) => jsonEncode({
      'timestamp': '2026-07-07T21:08:43.628Z',
      'type': 'turn_context',
      'payload': {'turn_id': 'turn-1', 'cwd': 'C:\\Users\\ayden\\project', 'model': model},
    });

String _tokenCount({
  String timestamp = '2026-07-07T21:08:52.656Z',
  int lastInput = 16111,
  int lastCached = 10112,
  int lastOutput = 18,
  int lastReasoning = 0,
}) =>
    jsonEncode({
      'timestamp': timestamp,
      'type': 'event_msg',
      'payload': {
        'type': 'token_count',
        'info': {
          'total_token_usage': {
            'input_tokens': lastInput,
            'cached_input_tokens': lastCached,
            'output_tokens': lastOutput,
            'reasoning_output_tokens': lastReasoning,
            'total_tokens': lastInput + lastOutput,
          },
          'last_token_usage': {
            'input_tokens': lastInput,
            'cached_input_tokens': lastCached,
            'output_tokens': lastOutput,
            'reasoning_output_tokens': lastReasoning,
            'total_tokens': lastInput + lastOutput,
          },
          'model_context_window': 258400,
        },
        'rate_limits': {'limit_id': 'premium'},
      },
    });

String _tokenCountPing({String timestamp = '2026-07-07T21:08:44.536Z'}) => jsonEncode({
      'timestamp': timestamp,
      'type': 'event_msg',
      'payload': {
        'type': 'token_count',
        'info': null,
        'rate_limits': {'limit_id': 'premium'},
      },
    });

/// Real-observed edge case: a token_count event where all four component
/// fields are 0 but total_tokens is non-zero (looks like a context-
/// compaction marker) — should be treated as zero-usage and skipped.
String _tokenCountCompactionMarker({String timestamp = '2026-07-07T21:08:44.536Z'}) => jsonEncode({
      'timestamp': timestamp,
      'type': 'event_msg',
      'payload': {
        'type': 'token_count',
        'info': {
          'total_token_usage': {
            'input_tokens': 0,
            'cached_input_tokens': 0,
            'output_tokens': 0,
            'reasoning_output_tokens': 0,
            'total_tokens': 0,
          },
          'last_token_usage': {
            'input_tokens': 0,
            'cached_input_tokens': 0,
            'output_tokens': 0,
            'reasoning_output_tokens': 0,
            'total_tokens': 12672,
          },
          'model_context_window': 258400,
        },
        'rate_limits': {'limit_id': 'premium'},
      },
    });

String _irrelevant(String type) => jsonEncode({
      'timestamp': '2026-07-07T21:08:45.000Z',
      'type': type,
      'payload': {'some': 'content that must never be inspected'},
    });

void main() {
  late Directory tempDir;
  late AiUsageDatabase db;
  const scanner = CodexCliScanner();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('codex_cli_scanner_test_');
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

  test('a full session_meta -> turn_context -> token_count sequence parses correctly', () async {
    await writeLog(
      'a.jsonl',
      [
        _sessionMeta(sessionId: 'sess-1'),
        _turnContext(model: 'gpt-5.5'),
        _tokenCount(lastInput: 16111, lastCached: 10112, lastOutput: 18, lastReasoning: 5),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.sessionsDirFound, isTrue);
    expect(result.turnsAdded, 1);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.sessionId, 'sess-1');
    expect(row.model, 'gpt-5.5');
    expect(row.source, AiUsageSource.codexCli);
    expect(row.inputTokens, 16111);
    expect(row.cacheReadTokens, 10112);
    expect(row.outputTokens, 18 + 5, reason: 'output + reasoning tokens are folded together');
    expect(row.cacheCreationTokens, 0);
  });

  test('a token_count event with info: null (rate-limit ping) is skipped', () async {
    await writeLog(
      'a.jsonl',
      [_sessionMeta(), _turnContext(), _tokenCountPing(), _tokenCount()],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 1, reason: 'only the real token_count event should count');
  });

  test('an all-zero-fields compaction marker is skipped', () async {
    await writeLog(
      'a.jsonl',
      [_sessionMeta(), _turnContext(), _tokenCountCompactionMarker()],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 0);
    expect(await db.select(db.aiUsageTurns).get(), isEmpty);
  });

  test('model tracking updates across multiple turn_context records', () async {
    await writeLog(
      'a.jsonl',
      [
        _sessionMeta(),
        _turnContext(model: 'gpt-5.5'),
        _tokenCount(timestamp: '2026-07-07T21:08:52.000Z'),
        _turnContext(model: 'gpt-5.4-mini'),
        _tokenCount(timestamp: '2026-07-07T21:09:10.000Z'),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);

    final rows = await (db.select(db.aiUsageTurns)
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    expect(rows, hasLength(2));
    expect(rows[0].model, 'gpt-5.5');
    expect(rows[1].model, 'gpt-5.4-mini');
  });

  test('irrelevant record types are ignored and never abort the file', () async {
    await writeLog(
      'a.jsonl',
      [
        _sessionMeta(),
        _irrelevant('response_item'),
        _irrelevant('message'),
        _irrelevant('user_message'),
        _turnContext(),
        _irrelevant('task_started'),
        _tokenCount(),
        _irrelevant('task_complete'),
        _irrelevant('thread_rolled_back'),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 1);
  });

  test('a file with zero token_count events (pre-telemetry log) scans cleanly', () async {
    await writeLog(
      'a.jsonl',
      [_sessionMeta(), _irrelevant('user_message'), _irrelevant('task_complete')],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.sessionsDirFound, isTrue);
    expect(result.turnsAdded, 0);
  });

  test('falls back to a UUID parsed from the filename when session_meta is missing', () async {
    await writeLog(
      'rollout-2026-07-07T23-08-31-019f3e69-260f-72d2-bf90-91bf5ddf898c.jsonl',
      [_turnContext(), _tokenCount()],
      mtime: DateTime(2026, 1, 1),
    );

    await scanner.scanDirectory(db, tempDir);

    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows, hasLength(1));
    expect(rows.single.sessionId, '019f3e69-260f-72d2-bf90-91bf5ddf898c');
  });

  test('a malformed line does not abort the rest of the file', () async {
    await writeLog(
      'a.jsonl',
      [_sessionMeta(), 'not valid json {{{', _turnContext(), _tokenCount()],
      mtime: DateTime(2026, 1, 1),
    );

    final result = await scanner.scanDirectory(db, tempDir);
    expect(result.turnsAdded, 1);
  });

  test(
      'state from session_meta/turn_context survives an incremental rescan '
      "that only appends a new token_count line", () async {
    final file = await writeLog(
      'a.jsonl',
      [
        _sessionMeta(sessionId: 'sess-1'),
        _turnContext(model: 'gpt-5.5'),
        _tokenCount(timestamp: '2026-07-07T21:08:52.000Z'),
      ],
      mtime: DateTime(2026, 1, 1),
    );

    final first = await scanner.scanDirectory(db, tempDir);
    expect(first.turnsAdded, 1);

    // Append only a new token_count line — no repeated session_meta or
    // turn_context. A naive implementation that skips already-scanned lines
    // outright (rather than just skipping their *emission*) would lose the
    // sessionId/model state and mishandle this second turn.
    await file.writeAsString(
      '${_tokenCount(timestamp: '2026-07-07T21:09:10.000Z', lastInput: 500, lastOutput: 50)}\n',
      mode: FileMode.append,
    );
    await file.setLastModified(DateTime(2026, 1, 1, 0, 0, 1));

    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.turnsAdded, 1);

    final rows = await (db.select(db.aiUsageTurns)
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    expect(rows, hasLength(2));
    expect(rows[1].sessionId, 'sess-1');
    expect(rows[1].model, 'gpt-5.5');
    expect(rows[1].inputTokens, 500);
  });

  test('rescanning an unchanged file adds nothing', () async {
    final mtime = DateTime(2026, 1, 1);
    await writeLog('a.jsonl', [_sessionMeta(), _turnContext(), _tokenCount()], mtime: mtime);

    final first = await scanner.scanDirectory(db, tempDir);
    expect(first.filesScanned, 1);

    final second = await scanner.scanDirectory(db, tempDir);
    expect(second.filesScanned, 0);
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));
  });
}

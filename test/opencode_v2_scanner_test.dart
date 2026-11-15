import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/opencode_scanner.dart';

Map<String, Object> _usage({int input = 100}) => {
  'model': {
    'id': 'vendor/model-free',
    'providerID': 'openrouter',
    'variant': 'high',
  },
  'tokens': {
    'input': input,
    'output': 20,
    'reasoning': 5,
    'cache': {'read': 30, 'write': 10},
  },
  'cost': 0,
};

void main() {
  late Directory dir;
  late File source;
  late AiUsageDatabase usage;
  const scanner = OpencodeScanner();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('opencode_v2_test_');
    source = File('${dir.path}${Platform.pathSeparator}opencode.db');
    usage = AiUsageDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await usage.close();
    await dir.delete(recursive: true);
  });

  test(
    'imports current desktop messages and compactions with their project',
    () async {
      final external = sqlite.sqlite3.open(source.path);
      external.execute(
        'CREATE TABLE session_v2 (id TEXT PRIMARY KEY, directory TEXT)',
      );
      external.execute('''
      CREATE TABLE session_message (
        id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL,
        seq INTEGER NOT NULL, time_created INTEGER NOT NULL,
        time_updated INTEGER NOT NULL, data TEXT NOT NULL
      )
    ''');
      external.execute('INSERT INTO session_v2 VALUES (?, ?)', [
        'session',
        r'C:\projects\luma',
      ]);
      void add(String id, String type, int time, Map<String, Object> data) {
        external.execute(
          'INSERT INTO session_message VALUES (?, ?, ?, ?, ?, ?, ?)',
          [id, 'session', type, time, time, time, jsonEncode(data)],
        );
      }

      add('user', 'user', 1000, {'text': 'not usage'});
      add('assistant', 'assistant', 2000, _usage());
      add('compaction', 'compaction', 3000, _usage(input: 200));
      external.close();

      expect((await scanner.scanFile(usage, source)).turnsAdded, 2);
      final rows = await usage.select(usage.aiUsageTurns).get();
      expect(rows, hasLength(2));
      final assistant = rows.singleWhere((row) => row.messageId == 'assistant');
      expect(assistant.source, AiUsageSource.opencode);
      expect(assistant.model, 'openrouter/vendor/model-free');
      expect(assistant.project, 'projects/luma');
      expect(assistant.inputTokens, 100);
      expect(assistant.outputTokens, 25);
      expect(assistant.cacheReadTokens, 30);
      expect(assistant.cacheCreationTokens, 10);
      expect(assistant.reportedCost, 0);
      expect((await scanner.scanFile(usage, source)).turnsAdded, 0);
      expect(await usage.select(usage.aiUsageTurns).get(), hasLength(2));
    },
  );

  test(
    'migrates previously scanned legacy messages without double counting',
    () async {
      final external = sqlite.sqlite3.open(source.path);
      external.execute('''
      CREATE TABLE message (
        id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER,
        time_updated INTEGER, data TEXT
      )
    ''');
      external.execute('INSERT INTO message VALUES (?, ?, ?, ?, ?)', [
        'old',
        'session',
        1000,
        1000,
        jsonEncode({
          'role': 'assistant',
          'modelID': 'old',
          'providerID': 'opencode',
          'tokens': {'input': 10, 'output': 2},
        }),
      ]);
      expect((await scanner.scanFile(usage, source)).turnsAdded, 1);
      external.execute(
        'CREATE TABLE session_v2 (id TEXT PRIMARY KEY, directory TEXT)',
      );
      external.execute('INSERT INTO session_v2 VALUES (?, ?)', [
        'session',
        r'C:\projects\luma',
      ]);
      external.execute('''
      CREATE TABLE session_message (
        id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL,
        seq INTEGER NOT NULL, time_created INTEGER NOT NULL,
        time_updated INTEGER NOT NULL, data TEXT NOT NULL
      )
    ''');
      for (final item in [('old', 1000), ('new', 2000)]) {
        external.execute(
          'INSERT INTO session_message VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            item.$1,
            'session',
            'assistant',
            item.$2,
            item.$2,
            item.$2,
            jsonEncode(_usage()),
          ],
        );
      }
      external.close();

      await scanner.scanFile(usage, source);
      final rows = await usage.select(usage.aiUsageTurns).get();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.messageId).toSet(), {'old', 'new'});
      await scanner.scanFile(usage, source);
      expect(await usage.select(usage.aiUsageTurns).get(), hasLength(2));
    },
  );
}

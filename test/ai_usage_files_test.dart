import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_files.dart';
import 'package:luma/features/plugins/installed/ai_usage/claude_code_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

String _assistantRecord(String sessionId, String messageId) => jsonEncode({
  'type': 'assistant',
  'sessionId': sessionId,
  'timestamp': '2026-11-06T00:30:00.000Z',
  'message': {
    'id': messageId,
    'model': 'claude-opus-5-5',
    'usage': {'input_tokens': 10, 'output_tokens': 5},
  },
});

void main() {
  late Directory tempDir;
  final sep = Platform.pathSeparator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_usage_files_test_');
  });

  tearDown(() async {
    final root = Platform.isWindows
        ? Directory('\\\\?\\${tempDir.absolute.path}')
        : tempDir;
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// A project folder that sorts before every other one and whose
  /// `tool-results` subfolder lists past Windows' 260-character limit, the
  /// shape a Claude desktop scratch session leaves in `~/.claude/projects`.
  Future<String> makeOverlongProject() async {
    final name = 'A--${'scratch-workspace-' * 12}';
    final project = '${tempDir.absolute.path}$sep$name';
    final deep = '$project${sep}00d31170-edae-418c-bde5-8bfd3fcec3d6'
        '${sep}tool-results';
    expect('$deep$sep*'.length, greaterThan(260));
    final prefix = Platform.isWindows ? '\\\\?\\' : '';
    await Directory('$prefix$deep').create(recursive: true);
    await File('$prefix$deep${sep}blob.jpg').writeAsBytes([0]);
    await File(
      '$prefix$project${sep}long-session.jsonl',
    ).writeAsString('${_assistantRecord('long-session', 'msg-long')}\n');
    return project;
  }

  test('finds files nested several folders deep', () async {
    final nested = Directory('${tempDir.path}${sep}a${sep}b');
    await nested.create(recursive: true);
    await File('${nested.path}${sep}x.jsonl').writeAsString('');
    await File('${tempDir.path}${sep}y.txt').writeAsString('');

    final files = await listFilesTolerant(
      tempDir,
      (p) => p.endsWith('.jsonl'),
    );

    expect(files.map((f) => fileBaseName(f.path)), ['x.jsonl']);
  });

  test('a folder past the path limit does not hide its siblings', () async {
    await makeOverlongProject();
    final normal = Directory('${tempDir.path}${sep}B--normal-project');
    await normal.create();
    await File('${normal.path}${sep}s.jsonl').writeAsString('');

    final files = await listFilesTolerant(
      tempDir,
      (p) => p.endsWith('.jsonl') || p.endsWith('.jpg'),
    );

    expect(
      files.map((f) => fileBaseName(f.path)).toSet(),
      {'s.jsonl', 'long-session.jsonl', 'blob.jpg'},
    );
  });

  test('paths short enough to list plainly keep their plain spelling', () async {
    await File('${tempDir.path}${sep}s.jsonl').writeAsString('');

    final files = await listFilesTolerant(tempDir, (p) => true);

    expect(files.single.path, isNot(startsWith('\\\\?\\')));
  });

  test('an unreadable root still throws', () async {
    final missing = Directory('${tempDir.path}${sep}missing');

    expect(
      () => listFilesTolerant(missing, (p) => true),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('Claude Code scan reads every project past an overlong one', () async {
    await makeOverlongProject();
    final normal = Directory('${tempDir.path}${sep}B--luma-app');
    await normal.create();
    await File(
      '${normal.path}${sep}today.jsonl',
    ).writeAsString('${_assistantRecord('today', 'msg-today')}\n');

    final db = AiUsageDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final result = await const ClaudeCodeScanner().scanDirectory(db, tempDir);

    expect(result.turnsAdded, 2);
    final rows = await db.select(db.aiUsageTurns).get();
    expect(rows.map((r) => r.sessionId).toSet(), {'today', 'long-session'});
  });
}

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/antigravity_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/claude_code_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/codex_cli_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/freebuff_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/opencode_scanner.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  test('startup AI usage scan keeps the UI event loop responsive', () async {
    final fixture = await Directory.systemTemp.createTemp('usage_startup_');
    final db = AiUsageDatabase(NativeDatabase.memory());
    final guard = StorageGuardService();
    StorageGuardService.instance = guard;
    final repo = AiUsageRepository(
      db,
      codexScanner: _FixtureCodex(fixture.path),
      claudeScanner: const _NoClaude(),
      antigravityScanner: const _NoAntigravity(),
      opencodeScanner: const _NoOpencode(),
      freebuffScanner: const _NoFreebuff(),
    );
    addTearDown(() async {
      repo.dispose();
      guard.dispose();
      await db.close();
      await fixture.delete(recursive: true);
    });
    final ignoredContent = List.filled(
      1600000,
      r'\n\"C:\\workspace\\file.dart\"\t',
    ).join();
    await File('${fixture.path}/rollout.jsonl').writeAsString(
      '{"type":"session_meta","payload":{"session_id":"fixture"}}\n'
      '{"type":"turn_context","payload":{"model":"fixture-model"}}\n'
      '{"type":"response_item","payload":{"text":"$ignoredContent"}}\n'
      '{"timestamp":"2026-10-06T00:00:00Z","type":"event_msg",'
      '"payload":{"type":"token_count","info":{"last_token_usage":'
      '{"input_tokens":10,"output_tokens":2}}}}\n',
    );
    await db.customSelect('SELECT 1').get();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final clock = Stopwatch()..start();
    var previousTick = clock.elapsedMicroseconds;
    var worstPause = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final now = clock.elapsedMicroseconds;
      final pause = now - previousTick;
      if (pause > worstPause) worstPause = pause;
      previousTick = now;
    });
    try {
      await repo.rescan();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      heartbeat.cancel();
    }

    final turn = (await db.select(db.aiUsageTurns).get()).single;
    expect(turn.model, 'fixture-model');
    expect(turn.inputTokens, 10);
    expect(turn.outputTokens, 2);
    expect(
      worstPause,
      lessThan(100000),
      reason:
          'The startup scanner blocked UI callbacks for '
          '${(worstPause / 1000).round()} ms during a '
          '${clock.elapsedMilliseconds} ms scan.',
    );

    await repo.rescan();
    expect(repo.lastTurnsAdded, 0);
    expect(await db.select(db.aiUsageTurns).get(), hasLength(1));
    expect((await db.select(db.aiUsageScanFiles).get()).single.lineCount, 4);
  });
}

class _FixtureCodex extends CodexCliScanner {
  const _FixtureCodex(this.path);
  final String path;

  @override
  Directory? sessionsDirectory() => Directory(path);
}

class _NoClaude extends ClaudeCodeScanner {
  const _NoClaude();

  @override
  Future<ClaudeCodeScanResult> scan(AiUsageDatabase db) async =>
      ClaudeCodeScanResult.unavailable;
}

class _NoAntigravity extends AntigravityScanner {
  const _NoAntigravity();

  @override
  Future<AntigravityScanResult> scan(AiUsageDatabase db) async =>
      AntigravityScanResult.unavailable;
}

class _NoOpencode extends OpencodeScanner {
  const _NoOpencode();

  @override
  Future<OpencodeScanResult> scan(AiUsageDatabase db) async =>
      OpencodeScanResult.unavailable;
}

class _NoFreebuff extends FreebuffScanner {
  const _NoFreebuff();

  @override
  Future<FreebuffScanResult> scan(AiUsageDatabase db) async =>
      FreebuffScanResult.unavailable;
}

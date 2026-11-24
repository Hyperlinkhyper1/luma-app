import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

/// The Usage dashboard used to read every turn in range onto the UI isolate
/// and aggregate it inside `build`, so switching to "All" on a machine with
/// 100k+ turns froze the app. `loadDashboard` does both on a worker isolate.
void main() {
  late Directory dir;
  late AiUsageDatabase db;
  late AiUsageRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('usage_dashboard_');
    db = AiUsageDatabase(
      NativeDatabase.createInBackground(File('${dir.path}/usage.sqlite')),
    );
    repo = AiUsageRepository(db);
  });

  tearDown(() async {
    repo.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> seed(int count, DateTime newest) async {
    await db.batch((b) {
      b.insertAll(db.aiUsageTurns, [
        for (var i = 0; i < count; i++)
          AiUsageTurnsCompanion.insert(
            sessionId: 's${i ~/ 50}',
            timestamp: newest.subtract(Duration(minutes: i * 3)).toUtc(),
            model: i.isEven ? 'claude-opus-5-5' : 'gpt-6-astra',
            source: i.isEven ? AiUsageSource.claudeCode : AiUsageSource.codexCli,
            inputTokens: const Value(100),
            outputTokens: const Value(10),
            cacheReadTokens: const Value(1000),
            project: Value('p${i % 7}'),
          ),
      ]);
    });
  }

  test('an all-time load of 120k turns never blocks the UI isolate', () async {
    final now = DateTime.now();
    await seed(120000, now);

    final clock = Stopwatch()..start();
    var previousTick = clock.elapsedMicroseconds;
    var worstPause = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final tick = clock.elapsedMicroseconds;
      if (tick - previousTick > worstPause) worstPause = tick - previousTick;
      previousTick = tick;
    });
    final snapshot = await repo.loadDashboard(null);
    heartbeat.cancel();

    expect(snapshot.summary.turnCount, 120000);
    expect(snapshot.summary.totalTokens, 120000 * 110);
    expect(snapshot.summary.cacheReadTokens, 120000 * 1000);
    expect(snapshot.modelTotals.map((m) => m.model).toSet(), {
      'claude-opus-5-5',
      'gpt-6-astra',
    });
    expect(snapshot.projectTotals, hasLength(7));
    expect(snapshot.dayBuckets.length, greaterThan(200));
    expect(
      worstPause,
      lessThan(250000),
      reason: 'loading the dashboard paused UI callbacks for '
          '${(worstPause / 1000).round()} ms over '
          '${clock.elapsedMilliseconds} ms',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the range start and source filter are applied in the query', () async {
    final now = DateTime.now();
    await seed(1000, now);

    final lastDay = await repo.loadDashboard(
      now.subtract(const Duration(hours: 23, minutes: 59)),
    );
    expect(lastDay.summary.turnCount, 480);

    final claudeOnly = await repo.loadDashboard(
      null,
      source: AiUsageSource.claudeCode,
    );
    expect(claudeOnly.summary.turnCount, 500);
    expect(claudeOnly.modelTotals.single.model, 'claude-opus-5-5');
    expect(claudeOnly.providerTotals, isEmpty);
  });

  test('turnsChanged fires when turns are written', () async {
    final fired = repo.turnsChanged.first;
    await seed(1, DateTime.now());
    await expectLater(fired.timeout(const Duration(seconds: 5)), completes);
  });
}

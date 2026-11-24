import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_stats.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

const _out = r'C:\Users\ayden\AppData\Local\Temp\claude\f55c479e66811e21\e07c06d6-3ca8-4c41-a3ad-73de652fdb88\scratchpad';
void main() {
  test('timing', () async {
    final db = AiUsageDatabase(NativeDatabase.createInBackground(File('$_out/usage_copy.sqlite')));
    await db.customSelect('select 1').get();
    for (var round = 0; round < 2; round++) {
      final r = await db.computeWithDatabase(connect: AiUsageDatabase.new, computation: (d) async {
        final sw = Stopwatch()..start();
        final rows = await (d.select(d.aiUsageTurns)..orderBy([(t) => OrderingTerm.asc(t.timestamp)])).get();
        final q = sw.elapsedMilliseconds;
        final parts = <String, int>{};
        void time(String n, void Function() f) { final s = Stopwatch()..start(); f(); parts[n] = s.elapsedMilliseconds; }
        time('totals', () => totals(rows));
        time('model', () => aggregateByModel(rows));
        time('company', () => aggregateByCompany(rows));
        time('day', () => aggregateByDay(rows));
        time('effort', () => aggregateByModelAndEffort(rows));
        time('project', () => aggregateByProject(rows));
        time('provider', () => aggregateOpencodeByProvider(rows));
        time('hour', () => aggregateByHour(rows));
        time('session', () => aggregateBySession(rows));
        time('streak', () => longestActiveDayStreak(rows));
        return 'rows=${rows.length} query=${q}ms $parts';
      });
      // ignore: avoid_print
      print(r);
    }
    final sw = Stopwatch()..start();
    final rows = await db.select(db.aiUsageTurns).get();
    // ignore: avoid_print
    print('main-isolate select ${rows.length} rows: ${sw.elapsedMilliseconds}ms');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}

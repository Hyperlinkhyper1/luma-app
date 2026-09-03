import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_pricing.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_stats.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/effort_breakdown_section.dart';

AiUsageTurn _turn({
  int id = 0,
  String model = 'claude-sonnet-4-6',
  AiUsageSource source = AiUsageSource.claudeCode,
  AiEffort? effort,
  int inputTokens = 100,
  int outputTokens = 200,
  int cacheReadTokens = 0,
  int cacheCreationTokens = 0,
}) =>
    AiUsageTurn(
      id: id,
      sessionId: 's1',
      timestamp: DateTime.utc(2026, 8, 20, 12),
      model: model,
      source: source,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cacheReadTokens: cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens,
      messageId: null,
      project: null,
      effort: effort,
    );

void main() {
  group('effortFromLog', () {
    test('recognises every tier, case- and whitespace-insensitively', () {
      for (final effort in AiEffort.values) {
        expect(effortFromLog(effort.name), effort);
        expect(effortFromLog(effort.name.toUpperCase()), effort);
        expect(effortFromLog('  ${effort.name}  '), effort);
      }
    });

    // Normalising once, here, is what lets the display switch be exhaustive
    // over AiEffort with no fallback arm for blanks or odd spellings.
    test('absent, blank and unknown values all become null', () {
      expect(effortFromLog(null), isNull);
      expect(effortFromLog(''), isNull);
      expect(effortFromLog('   '), isNull);
      expect(effortFromLog('turbo'), isNull);
    });
  });

  group('effortLabel', () {
    test('every tier has a label and null reads as Unspecified', () {
      expect(effortLabel(null), 'Unspecified');
      for (final effort in AiEffort.values) {
        expect(effortLabel(effort), isNotEmpty);
        expect(effortLabel(effort), isNot('Unspecified'));
      }
      expect(effortLabel(AiEffort.xhigh), 'Extra high');
    });
  });

  group('aggregateByModelAndEffort', () {
    test('groups by (model, effort) and sums each bucket', () {
      final tiers = aggregateByModelAndEffort([
        _turn(id: 1, effort: AiEffort.high, inputTokens: 10, outputTokens: 20),
        _turn(id: 2, effort: AiEffort.high, inputTokens: 30, outputTokens: 40),
        _turn(id: 3, effort: AiEffort.low, inputTokens: 1, outputTokens: 2),
      ]);

      expect(tiers, hasLength(2));
      final high = tiers.firstWhere((t) => t.effort == AiEffort.high);
      expect(high.turnCount, 2);
      expect(high.inputTokens, 40);
      expect(high.outputTokens, 60);
      expect(high.totalTokens, 100);

      final low = tiers.firstWhere((t) => t.effort == AiEffort.low);
      expect(low.turnCount, 1);
      expect(low.totalTokens, 3);
    });

    test('sorts by descending token count', () {
      final tiers = aggregateByModelAndEffort([
        _turn(id: 1, effort: AiEffort.low, inputTokens: 1, outputTokens: 1),
        _turn(id: 2, effort: AiEffort.max, inputTokens: 500, outputTokens: 500),
        _turn(id: 3, effort: AiEffort.high, inputTokens: 50, outputTokens: 50),
      ]);

      expect(tiers.map((t) => t.effort),
          [AiEffort.max, AiEffort.high, AiEffort.low]);
    });

    // Only Claude Code records a tier, so folding other sources in would
    // invent an "Unspecified" row that says nothing about them.
    test('ignores sources that do not record an effort tier', () {
      final tiers = aggregateByModelAndEffort([
        _turn(id: 1, effort: AiEffort.high),
        _turn(id: 2, source: AiUsageSource.codexCli, model: 'gpt-5.4'),
        _turn(id: 3, source: AiUsageSource.antigravity, model: 'Gemini 3 Pro'),
      ]);

      expect(tiers, hasLength(1));
      expect(tiers.single.effort, AiEffort.high);
      expect(tiers.single.turnCount, 1);
    });

    test('turns with no recorded tier get their own bucket, not dropped', () {
      final tiers = aggregateByModelAndEffort([
        _turn(id: 1, effort: null),
        _turn(id: 2, effort: AiEffort.high),
      ]);

      expect(tiers, hasLength(2));
      expect(tiers.map((t) => t.effort), contains(null));
    });

    test('splits the same effort across different models', () {
      final tiers = aggregateByModelAndEffort([
        _turn(id: 1, model: 'claude-opus-4-8', effort: AiEffort.high),
        _turn(id: 2, model: 'claude-sonnet-4-6', effort: AiEffort.high),
      ]);

      expect(tiers, hasLength(2));
      expect(tiers.map((t) => t.model).toSet(),
          {'claude-opus-4-8', 'claude-sonnet-4-6'});
    });

    // The cost expression lives in one place shared with aggregateByModel;
    // this pins that the effort split reports the same money as the model
    // totals it sits underneath.
    test('costs sum to the same total as aggregateByModel', () {
      final turns = [
        _turn(
            id: 1,
            effort: AiEffort.high,
            inputTokens: 1000,
            outputTokens: 2000,
            cacheReadTokens: 500,
            cacheCreationTokens: 300),
        _turn(
            id: 2,
            effort: AiEffort.low,
            inputTokens: 400,
            outputTokens: 100,
            cacheCreationTokens: 50),
      ];

      final byEffort =
          aggregateByModelAndEffort(turns).fold<double>(0, (a, t) => a + t.cost);
      final byModel =
          aggregateByModel(turns).fold<double>(0, (a, t) => a + t.cost);

      expect(byEffort, closeTo(byModel, 1e-9));
      expect(byEffort, greaterThan(0));
    });

    test('is empty when nothing came from Claude Code', () {
      expect(
        aggregateByModelAndEffort(
            [_turn(id: 1, source: AiUsageSource.codexCli, model: 'gpt-5.4')]),
        isEmpty,
      );
    });
  });

  // aggregateByModel and aggregateByModelAndEffort share one bucketing
  // helper; this guards that the shared path still reports every token
  // category the model table displays.
  group('aggregateByModel', () {
    test('sums all four token categories per (source, model)', () {
      final totals = aggregateByModel([
        _turn(
            id: 1,
            inputTokens: 10,
            outputTokens: 20,
            cacheReadTokens: 30,
            cacheCreationTokens: 40),
        _turn(
            id: 2,
            inputTokens: 1,
            outputTokens: 2,
            cacheReadTokens: 3,
            cacheCreationTokens: 4),
      ]);

      expect(totals, hasLength(1));
      final only = totals.single;
      expect(only.turnCount, 2);
      expect(only.inputTokens, 11);
      expect(only.outputTokens, 22);
      expect(only.cacheReadTokens, 33);
      expect(only.cacheCreationTokens, 44);
      // Cache reads stay out of totalTokens by design.
      expect(only.totalTokens, 11 + 22 + 44);
      expect(only.billable,
          isBillableModel(AiUsageSource.claudeCode, 'claude-sonnet-4-6'));
    });

    test('keeps the same model id from different sources apart', () {
      final totals = aggregateByModel([
        _turn(id: 1, model: 'shared-name'),
        _turn(id: 2, model: 'shared-name', source: AiUsageSource.codexCli),
      ]);

      expect(totals, hasLength(2));
      expect(totals.map((t) => t.source).toSet(),
          {AiUsageSource.claudeCode, AiUsageSource.codexCli});
    });
  });
}

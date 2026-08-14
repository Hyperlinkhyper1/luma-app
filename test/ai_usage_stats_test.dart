import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_pricing.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_stats.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

AiUsageTurn _turn({
  int id = 0,
  String sessionId = 's1',
  required DateTime timestamp,
  String model = 'claude-sonnet-4-6',
  AiUsageSource source = AiUsageSource.claudeCode,
  int inputTokens = 100,
  int outputTokens = 200,
  int cacheReadTokens = 0,
  int cacheCreationTokens = 0,
}) =>
    AiUsageTurn(
      id: id,
      sessionId: sessionId,
      timestamp: timestamp.toUtc(),
      model: model,
      source: source,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cacheReadTokens: cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens,
      messageId: null,
    );

void main() {
  group('resolveAiUsageRange', () {
    final now = DateTime(2026, 3, 15, 14, 30);

    test('today starts at local midnight', () {
      final (start, end) = resolveAiUsageRange(AiUsageRangePreset.today, now);
      expect(start, DateTime(2026, 3, 15));
      expect(end, now);
    });

    test('last7Days starts 7 days before now', () {
      final (start, end) = resolveAiUsageRange(AiUsageRangePreset.last7Days, now);
      expect(start, now.subtract(const Duration(days: 7)));
      expect(end, now);
    });

    test('last30Days starts 30 days before now', () {
      final (start, end) = resolveAiUsageRange(AiUsageRangePreset.last30Days, now);
      expect(start, now.subtract(const Duration(days: 30)));
      expect(end, now);
    });

    test('all has no lower bound', () {
      final (start, end) = resolveAiUsageRange(AiUsageRangePreset.all, now);
      expect(start, isNull);
      expect(end, now);
    });
  });

  group('Anthropic pricing (via dispatcher)', () {
    test('recognizes every Anthropic model family', () {
      for (final family in ['fable', 'mythos', 'opus', 'sonnet', 'haiku']) {
        expect(isBillableModel(AiUsageSource.claudeCode, 'claude-$family-4-6'), isTrue,
            reason: family);
      }
    });

    test('rejects unrecognized model names', () {
      expect(isBillableModel(AiUsageSource.claudeCode, 'gpt-4o-mini'), isFalse);
      expect(isBillableModel(AiUsageSource.claudeCode, null), isFalse);
    });

    test('exact match wins over prefix/fallback', () {
      final rates = pricingFor(AiUsageSource.claudeCode, 'claude-haiku-4-5');
      expect(rates!.input, 1.00);
      expect(rates.output, 5.00);
    });

    test('dated suffix falls back to prefix match', () {
      final rates = pricingFor(AiUsageSource.claudeCode, 'claude-opus-4-8-20260315');
      expect(rates, isNotNull);
      expect(rates!.input, kAnthropicPricing['claude-opus-4-8']!.input);
    });

    test('unrecognized model has no pricing', () {
      expect(pricingFor(AiUsageSource.claudeCode, 'gpt-4o-mini'), isNull);
    });
  });

  group('OpenAI pricing (via dispatcher)', () {
    test('recognizes gpt- models, rejects everything else', () {
      expect(isBillableModel(AiUsageSource.codexCli, 'gpt-5.5'), isTrue);
      expect(isBillableModel(AiUsageSource.codexCli, 'claude-sonnet-4-6'), isFalse,
          reason: "a cross-source substring shouldn't leak");
      expect(isBillableModel(AiUsageSource.codexCli, null), isFalse);
    });

    test('exact match rates for confirmed real model strings', () {
      final gpt55 = pricingFor(AiUsageSource.codexCli, 'gpt-5.5');
      expect(gpt55!.input, 5.00);
      expect(gpt55.output, 30.00);

      final mini = pricingFor(AiUsageSource.codexCli, 'gpt-5.4-mini');
      expect(mini!.input, 0.75);
      expect(mini.output, 4.50);
    });

    test('a more specific suffix is never shadowed by a shorter prefix', () {
      // Regression test: 'gpt-5.4-mini-...'.startsWith('gpt-5.4') is also
      // true, so a naive first-match-wins prefix scan could resolve this to
      // the (wrong, more expensive) base gpt-5.4 rate instead of mini's.
      final rates = pricingFor(AiUsageSource.codexCli, 'gpt-5.4-mini-2026-08-01');
      expect(rates!.input, kOpenAiPricing['gpt-5.4-mini']!.input);
      expect(rates.input, isNot(kOpenAiPricing['gpt-5.4']!.input));
    });

    test('unlisted suffix of a known generation falls back to that generation\'s rate', () {
      final rates = pricingFor(AiUsageSource.codexCli, 'gpt-5.6-mini');
      expect(rates, isNotNull);
      expect(rates!.input, kOpenAiPricing['gpt-5.6']!.input);
    });

    test('unrecognized model has no pricing', () {
      expect(pricingFor(AiUsageSource.codexCli, 'gemini-2.0'), isNull);
    });
  });

  group('costForTurn', () {
    test('non-billable model costs nothing', () {
      expect(costForTurn(AiUsageSource.claudeCode, 'gpt-4o-mini', 1000000, 1000000, 0, 0), 0);
    });

    test('billable Anthropic model costs per the rate table', () {
      // 1M input + 1M output tokens on sonnet-4-6: $3.00 + $15.00.
      final cost =
          costForTurn(AiUsageSource.claudeCode, 'claude-sonnet-4-6', 1000000, 1000000, 0, 0);
      expect(cost, closeTo(18.00, 0.0001));
    });

    test('billable OpenAI model costs per the rate table', () {
      // 1M input + 1M output tokens on gpt-5.5: $5.00 + $30.00.
      final cost = costForTurn(AiUsageSource.codexCli, 'gpt-5.5', 1000000, 1000000, 0, 0);
      expect(cost, closeTo(35.00, 0.0001));
    });
  });

  group('aggregateByModel', () {
    test('sums per model and sorts by descending total tokens', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        _turn(timestamp: day, model: 'claude-haiku-4-5', inputTokens: 10, outputTokens: 10),
        _turn(
            timestamp: day,
            model: 'claude-opus-4-8',
            inputTokens: 1000,
            outputTokens: 1000),
        _turn(timestamp: day, model: 'claude-opus-4-8', inputTokens: 500, outputTokens: 500),
      ];

      final totals = aggregateByModel(turns);
      expect(totals, hasLength(2));
      expect(totals.first.model, 'claude-opus-4-8');
      expect(totals.first.turnCount, 2);
      expect(totals.first.totalTokens, 3000);
      expect(totals.first.billable, isTrue);
    });

    test('groups a non-Anthropic model as unbillable', () {
      final turns = [
        _turn(timestamp: DateTime(2026, 1, 1), model: 'gpt-4o-mini'),
      ];
      final totals = aggregateByModel(turns);
      expect(totals.single.billable, isFalse);
      expect(totals.single.cost, 0);
    });

    test('same model string from different sources never merges', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        _turn(timestamp: day, model: 'x', source: AiUsageSource.claudeCode, inputTokens: 10),
        _turn(timestamp: day, model: 'x', source: AiUsageSource.codexCli, inputTokens: 20),
      ];

      final totals = aggregateByModel(turns);
      expect(totals, hasLength(2), reason: 'identical model name, different source');
      final sources = totals.map((t) => t.source).toSet();
      expect(sources, {AiUsageSource.claudeCode, AiUsageSource.codexCli});
    });
  });

  group('aggregateByDay', () {
    test('buckets turns by local calendar day', () {
      final turns = [
        _turn(timestamp: DateTime(2026, 1, 1, 9), inputTokens: 100, outputTokens: 0),
        _turn(timestamp: DateTime(2026, 1, 1, 23), inputTokens: 50, outputTokens: 0),
        _turn(timestamp: DateTime(2026, 1, 2, 1), inputTokens: 10, outputTokens: 0),
      ];

      final buckets = aggregateByDay(turns);
      expect(buckets, hasLength(2));
      expect(buckets[0].day, DateTime(2026, 1, 1));
      expect(buckets[0].totalTokens, 150);
      expect(buckets[1].day, DateTime(2026, 1, 2));
      expect(buckets[1].totalTokens, 10);
    });
  });

  group('totals', () {
    test('sums tokens/cost and counts distinct sessions', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        _turn(sessionId: 'a', timestamp: day, model: 'claude-sonnet-4-6'),
        _turn(sessionId: 'a', timestamp: day, model: 'claude-sonnet-4-6'),
        _turn(sessionId: 'b', timestamp: day, model: 'gpt-4o-mini'),
      ];

      final result = totals(turns);
      expect(result.turnCount, 3);
      expect(result.sessionCount, 2);
      expect(result.hasUnbillable, isTrue);
    });

    test('costs a mixed Claude Code + Codex CLI list using each turn\'s own source', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        // $3.00/MTok input * 1M = $3.00
        _turn(
          sessionId: 'a',
          timestamp: day,
          model: 'claude-sonnet-4-6',
          source: AiUsageSource.claudeCode,
          inputTokens: 1000000,
          outputTokens: 0,
        ),
        // $5.00/MTok input * 1M = $5.00
        _turn(
          sessionId: 'b',
          timestamp: day,
          model: 'gpt-5.5',
          source: AiUsageSource.codexCli,
          inputTokens: 1000000,
          outputTokens: 0,
        ),
      ];

      final result = totals(turns);
      expect(result.cost, closeTo(8.00, 0.0001));
      expect(result.hasUnbillable, isFalse);
    });
  });
}

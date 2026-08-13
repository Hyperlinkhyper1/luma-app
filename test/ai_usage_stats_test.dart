import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_pricing.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_stats.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

AiUsageTurn _turn({
  int id = 0,
  String sessionId = 's1',
  required DateTime timestamp,
  String model = 'claude-sonnet-4-6',
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

  group('isBillableModel / pricingFor', () {
    test('recognizes every Anthropic model family', () {
      for (final family in ['fable', 'mythos', 'opus', 'sonnet', 'haiku']) {
        expect(isBillableModel('claude-$family-4-6'), isTrue, reason: family);
      }
    });

    test('rejects unrecognized model names', () {
      expect(isBillableModel('gpt-4o-mini'), isFalse);
      expect(isBillableModel(null), isFalse);
    });

    test('exact match wins over prefix/fallback', () {
      final rates = pricingFor('claude-haiku-4-5');
      expect(rates!.input, 1.00);
      expect(rates.output, 5.00);
    });

    test('dated suffix falls back to prefix match', () {
      final rates = pricingFor('claude-opus-4-8-20260315');
      expect(rates, isNotNull);
      expect(rates!.input, kAiPricing['claude-opus-4-8']!.input);
    });

    test('unrecognized model has no pricing', () {
      expect(pricingFor('gpt-4o-mini'), isNull);
    });
  });

  group('costForTurn', () {
    test('non-billable model costs nothing', () {
      expect(costForTurn('gpt-4o-mini', 1000000, 1000000, 0, 0), 0);
    });

    test('billable model costs per the rate table', () {
      // 1M input + 1M output tokens on sonnet-4-6: $3.00 + $15.00.
      final cost = costForTurn('claude-sonnet-4-6', 1000000, 1000000, 0, 0);
      expect(cost, closeTo(18.00, 0.0001));
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
  });
}

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
  String? project,
  AiEffort? effort,
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
      project: project,
      effort: effort,
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

  group('Antigravity pricing (via dispatcher)', () {
    test('a recognized Gemini model prices at its rate, suffix and all', () {
      final rates = pricingFor(AiUsageSource.antigravity, 'Gemini 3.1 Pro (High)');
      expect(rates, isNotNull);
      expect(rates!.input, kGeminiPricing['Gemini 3.1 Pro']!.input);
      expect(isBillableModel(AiUsageSource.antigravity, 'Gemini 3.1 Pro (High)'), isTrue);
    });

    test('the reasoning-effort suffix does not change which rate is picked', () {
      final withSuffix = pricingFor(AiUsageSource.antigravity, 'Gemini 3.5 Flash (Medium)');
      final withoutSuffix = pricingFor(AiUsageSource.antigravity, 'Gemini 3.5 Flash');
      expect(withSuffix!.input, withoutSuffix!.input);
    });

    test('Flash-Lite is never shadowed by the shorter Flash prefix', () {
      final rates = pricingFor(AiUsageSource.antigravity, 'Gemini 3.5 Flash-Lite (Low)');
      expect(rates!.input, kGeminiPricing['Gemini 3.5 Flash-Lite']!.input);
      expect(rates.input, isNot(kGeminiPricing['Gemini 3.5 Flash']!.input));
    });

    test('a recognized Claude model falls back to the Anthropic family rate', () {
      // Antigravity's Claude-named turns never hit the Anthropic table's
      // exact/dated-prefix tiers (those expect slugs like
      // "claude-opus-4-6", not this prose form) — only its family-word
      // fallback, so this always resolves to the newest known Opus rate
      // regardless of which specific version Antigravity's UI names.
      final rates = pricingFor(AiUsageSource.antigravity, 'Claude Opus 4.6 (Thinking)');
      expect(rates, isNotNull);
      expect(rates!.input, kAnthropicPricing['claude-opus-4-8']!.input);
    });

    test('an unrecognized model stays unbillable with no pricing', () {
      for (final model in ['Some Local Model', null]) {
        expect(isBillableModel(AiUsageSource.antigravity, model), isFalse, reason: '$model');
        expect(pricingFor(AiUsageSource.antigravity, model), isNull, reason: '$model');
      }
      expect(costForTurn(AiUsageSource.antigravity, 'Some Local Model', 100, 200, 0, 0), 0);
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

    test('totalTokens excludes cache reads even though cost still bills them', () {
      final turns = [
        _turn(
          timestamp: DateTime(2026, 1, 1),
          model: 'claude-sonnet-4-6',
          inputTokens: 100,
          outputTokens: 200,
          cacheReadTokens: 5000000,
        ),
      ];
      final result = aggregateByModel(turns).single;
      expect(result.totalTokens, 300);
      expect(result.cacheReadTokens, 5000000, reason: 'raw field is untouched');
      expect(result.cost, greaterThan(1.0), reason: 'cost calc still includes the cache read');
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

    test('excludes cache reads from the daily total', () {
      final turns = [
        _turn(
          timestamp: DateTime(2026, 1, 1),
          inputTokens: 100,
          outputTokens: 50,
          cacheReadTokens: 500000,
        ),
      ];
      final buckets = aggregateByDay(turns);
      expect(buckets.single.totalTokens, 150,
          reason: 'a huge repeated cache read must not dominate the daily total');
    });

    test('sums each of the four token categories independently per day', () {
      final turns = [
        _turn(
          timestamp: DateTime(2026, 1, 1, 9),
          inputTokens: 10,
          outputTokens: 20,
          cacheReadTokens: 30,
          cacheCreationTokens: 40,
        ),
        _turn(
          timestamp: DateTime(2026, 1, 1, 15),
          inputTokens: 1,
          outputTokens: 2,
          cacheReadTokens: 3,
          cacheCreationTokens: 4,
        ),
      ];
      final bucket = aggregateByDay(turns).single;
      expect(bucket.inputTokens, 11);
      expect(bucket.outputTokens, 22);
      expect(bucket.cacheReadTokens, 33);
      expect(bucket.cacheCreationTokens, 44);
    });
  });

  group('aggregateByProject', () {
    test('groups by project, sorted by descending tokens', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        _turn(timestamp: day, project: 'org/small', inputTokens: 10, outputTokens: 0),
        _turn(timestamp: day, project: 'org/big', inputTokens: 1000, outputTokens: 0),
        _turn(timestamp: day, project: 'org/big', inputTokens: 500, outputTokens: 0),
      ];

      final result = aggregateByProject(turns);
      expect(result, hasLength(2));
      expect(result.first.project, 'org/big');
      expect(result.first.turnCount, 2);
      expect(result.first.totalTokens, 1500);
    });

    test('a turn with no project folds into "Unknown project"', () {
      final turns = [_turn(timestamp: DateTime(2026, 1, 1), project: null)];
      final result = aggregateByProject(turns);
      expect(result.single.project, kUnknownProject);
    });

    test('sessionCount counts distinct sessions within the project', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        _turn(sessionId: 'a', timestamp: day, project: 'org/repo'),
        _turn(sessionId: 'a', timestamp: day, project: 'org/repo'),
        _turn(sessionId: 'b', timestamp: day, project: 'org/repo'),
      ];
      expect(aggregateByProject(turns).single.sessionCount, 2);
    });

    test('costs a mixed-source project using each turn\'s own source', () {
      final day = DateTime(2026, 1, 1);
      final turns = [
        _turn(
          timestamp: day,
          project: 'org/repo',
          model: 'claude-sonnet-4-6',
          source: AiUsageSource.claudeCode,
          inputTokens: 1000000,
          outputTokens: 0,
        ),
        _turn(
          timestamp: day,
          project: 'org/repo',
          model: 'gpt-5.5',
          source: AiUsageSource.codexCli,
          inputTokens: 1000000,
          outputTokens: 0,
        ),
      ];
      expect(aggregateByProject(turns).single.cost, closeTo(8.00, 0.0001));
    });
  });

  group('aggregateBySession', () {
    test('groups by (source, sessionId), sorted by descending cost', () {
      final turns = [
        _turn(sessionId: 'cheap', timestamp: DateTime(2026, 1, 1), inputTokens: 10),
        _turn(sessionId: 'pricey', timestamp: DateTime(2026, 1, 1), inputTokens: 1000000),
      ];
      final result = aggregateBySession(turns);
      expect(result, hasLength(2));
      expect(result.first.sessionId, 'pricey');
    });

    test('the same sessionId from different sources never merges', () {
      final turns = [
        _turn(sessionId: 'shared', source: AiUsageSource.claudeCode, timestamp: DateTime(2026, 1, 1)),
        _turn(sessionId: 'shared', source: AiUsageSource.codexCli, timestamp: DateTime(2026, 1, 1)),
      ];
      expect(aggregateBySession(turns), hasLength(2));
    });

    test('duration spans the first to the last turn in the session', () {
      final turns = [
        _turn(sessionId: 'a', timestamp: DateTime(2026, 1, 1, 10, 0)),
        _turn(sessionId: 'a', timestamp: DateTime(2026, 1, 1, 12, 30)),
      ];
      expect(aggregateBySession(turns).single.duration, const Duration(hours: 2, minutes: 30));
    });

    test('project is carried from the session\'s turns', () {
      final turns = [_turn(sessionId: 'a', timestamp: DateTime(2026, 1, 1), project: 'org/repo')];
      expect(aggregateBySession(turns).single.project, 'org/repo');
    });
  });

  group('longestActiveDayStreak', () {
    test('no turns means a zero-length streak', () {
      final streak = longestActiveDayStreak(const []);
      expect(streak.days, 0);
      expect(streak.start, isNull);
      expect(streak.end, isNull);
    });

    test('a single active day is a streak of 1', () {
      final streak = longestActiveDayStreak([_turn(timestamp: DateTime(2026, 1, 1))]);
      expect(streak.days, 1);
      expect(streak.start, DateTime(2026, 1, 1));
      expect(streak.end, DateTime(2026, 1, 1));
    });

    test('picks the longest of several runs, not the most recent', () {
      final turns = [
        // A 3-day run (Jan 1-3), a gap, then a 2-day run (Jan 10-11).
        _turn(timestamp: DateTime(2026, 1, 1)),
        _turn(timestamp: DateTime(2026, 1, 2)),
        _turn(timestamp: DateTime(2026, 1, 3)),
        _turn(timestamp: DateTime(2026, 1, 10)),
        _turn(timestamp: DateTime(2026, 1, 11)),
      ];
      final streak = longestActiveDayStreak(turns);
      expect(streak.days, 3);
      expect(streak.start, DateTime(2026, 1, 1));
      expect(streak.end, DateTime(2026, 1, 3));
    });

    test('multiple turns on the same day only count once', () {
      final turns = [
        _turn(timestamp: DateTime(2026, 1, 1, 9)),
        _turn(timestamp: DateTime(2026, 1, 1, 15)),
        _turn(timestamp: DateTime(2026, 1, 2, 9)),
      ];
      expect(longestActiveDayStreak(turns).days, 2);
    });
  });

  group('aggregateByHour', () {
    test('always returns 24 buckets, empty hours included as 0', () {
      final buckets = aggregateByHour(const []);
      expect(buckets, hasLength(24));
      expect(
        buckets.every((b) => b.totalTurns == 0 && b.avgTurns == 0 && b.avgTokens == 0),
        isTrue,
      );
    });

    test('averages by the number of distinct days present, not the full range', () {
      final turns = [
        _turn(timestamp: DateTime(2026, 1, 1, 9), sessionId: 'a'),
        _turn(timestamp: DateTime(2026, 1, 2, 9), sessionId: 'b'),
        _turn(timestamp: DateTime(2026, 1, 2, 9), sessionId: 'c'),
      ];
      final buckets = aggregateByHour(turns);
      final hour9 = buckets.firstWhere((b) => b.hour == 9);
      expect(hour9.totalTurns, 3);
      expect(hour9.avgTurns, closeTo(1.5, 0.0001), reason: '3 turns over 2 distinct days');
    });

    test('avgTokens uses the input+output+cache-write definition, averaged by distinct days', () {
      final turns = [
        _turn(
            timestamp: DateTime(2026, 1, 1, 9),
            sessionId: 'a',
            inputTokens: 100,
            outputTokens: 200),
        _turn(
            timestamp: DateTime(2026, 1, 2, 9),
            sessionId: 'b',
            inputTokens: 50,
            outputTokens: 50),
      ];
      final buckets = aggregateByHour(turns);
      final hour9 = buckets.firstWhere((b) => b.hour == 9);
      expect(hour9.avgTokens, closeTo(200, 0.0001), reason: '(300 + 100) new tokens over 2 days');
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

    test('totalTokens excludes cache reads, but cost and cacheReadTokens still reflect them',
        () {
      // Regression test for a real bug: a long agentic session re-reads the
      // same growing cached context on nearly every turn, so summing cache
      // reads into "total tokens" inflated real usage by ~100x in practice
      // (1.93B reported vs. a reference tool's ~15M for the same history).
      final turns = [
        _turn(
          timestamp: DateTime(2026, 1, 1),
          model: 'claude-sonnet-4-6',
          inputTokens: 100,
          outputTokens: 200,
          cacheReadTokens: 1000000, // $0.30/MTok on sonnet-4-6 -> $0.30
          cacheCreationTokens: 0,
        ),
      ];

      final result = totals(turns);
      expect(result.totalTokens, 300, reason: 'input + output only, cache read excluded');
      expect(result.cacheReadTokens, 1000000, reason: 'still reported, just separately');
      expect(result.cost, greaterThan(0.29),
          reason: 'cost must still bill the cache read, even though tokens excludes it');
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

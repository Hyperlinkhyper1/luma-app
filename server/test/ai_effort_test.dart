import 'dart:io';

import 'package:luma_sync_server/ai_effort.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:test/test.dart';

void main() {
  group('planAssistantEffort', () {
    test('each level maps to a server-chosen effort and budget', () {
      final low = planAssistantEffort({'luma_effort': 'low'}, 'smarter');
      expect(low.reasoningEffort, 'low');
      expect(low.weightTenths, 10);
      expect(low.maxTokens, 1024);

      final medium = planAssistantEffort({'luma_effort': 'medium'}, 'smarter');
      expect(medium.reasoningEffort, isNull);
      expect(medium.overridesRoute, isFalse);
      expect(planAssistantEffort({'luma_effort': 'medium'}, 'smartest')
          .reasoningEffort, 'high');

      final max = planAssistantEffort({'luma_effort': 'max'}, 'normal');
      expect(max.reasoningEffort, 'high');
      expect(max.weightTenths, 35);
      expect(max.maxTokens, 16384);
      expect(max.overridesRoute, isTrue);
    });

    test('the client cannot raise its own output budget past the level', () {
      final plan = planAssistantEffort(
          {'luma_effort': 'medium', 'max_tokens': 999999}, 'normal');
      expect(plan.maxTokens, 4096);
      expect(planAssistantEffort(
              {'luma_effort': 'extra', 'max_tokens': 999999}, 'normal')
          .maxTokens, 16384);
    });

    test('an unknown level falls back to the legacy reading', () {
      expect(planAssistantEffort({'luma_effort': 'ultra9000'}, 'normal').level,
          AssistantEffort.medium);
    });

    test('a raw reasoning_effort is charged, not passed through for free',
        () {
      final sneaky =
          planAssistantEffort({'reasoning_effort': 'high'}, 'normal');
      expect(sneaky.level, AssistantEffort.high);
      expect(sneaky.weightTenths, 15);
      final pulsar =
          planAssistantEffort({'reasoning_effort': 'high'}, 'smartest');
      expect(pulsar.level, AssistantEffort.medium);
      expect(pulsar.reasoningEffort, 'high');
      expect(planAssistantEffort({'reasoning_effort': 'xhigh'}, 'normal')
          .reasoningEffort, isNull);
    });

    test('weights are published for the app', () {
      expect(assistantEffortWeights['max'], 3.5);
      expect(assistantEffortWeights['medium'], 1.0);
    });
  });

  test('charge multiplies the units by the effort weight', () async {
    final dir = await Directory.systemTemp.createTemp('luma_effort_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    const budget = AiTokenBudget(1000000);
    await store.charge('u', 1000, 'normal', budget);
    expect(store.unitsUsed('u', const Duration(hours: 1)), 1000);
    await store.charge('u', 1000, 'smarter', budget, effortTenths: 35);
    expect(store.unitsUsed('u', const Duration(hours: 1)), 1000 + 5250);
  });
}

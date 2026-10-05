import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:test/test.dart';

void main() {
  test('one weekly allowance per plan; five hours is 15 percent', () {
    expect(aiTokenBudget('core').weekly, 1000000);
    expect(aiTokenBudget('orbit').weekly, 5000000);
    expect(aiTokenBudget('nova').weekly, 14000000);
    expect(aiTokenBudget(null).weekly, 1000000);
    for (final plan in ['core', 'orbit', 'nova']) {
      final budget = aiTokenBudget(plan);
      expect(budget.fiveHour, budget.weekly * 15 ~/ 100);
    }
  });

  test('better modes drain the shared allowance faster', () {
    expect(aiUsageUnits(1000, 'normal'), 1000);
    expect(aiUsageUnits(1000, 'smarter'), 1500);
    expect(aiUsageUnits(1000, 'smartest'), 2500);
    expect(aiUsageUnits(1000, 'unknown'), 1000);
  });

  test('every mode draws on one allowance, weighted by mode', () async {
    final dir = await Directory.systemTemp.createTemp('ai_shared_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    final budget = aiTokenBudget('orbit');
    await store.charge('u', 100000, 'normal', budget);
    await store.charge('u', 100000, 'smarter', budget);
    await store.charge('u', 100000, 'smartest', budget);
    expect(store.unitsUsed('u', const Duration(days: 7)), 500000);
    expect(store.tokensUsed('u', const Duration(days: 7)), 300000);
    expect(store.tokensUsed('u', const Duration(days: 7), mode: 'smarter'),
        100000);

    expect(store.canSpend('u', budget), isTrue);
    await store.charge('u', 200000, 'smartest', budget);
    expect(store.unitsUsed('u', const Duration(days: 7)), 1000000);
    expect(store.canSpend('u', budget), isFalse,
        reason: 'past the five-hour share of the shared allowance');
  });

  test('a flat cost is already in units and takes no mode weight', () async {
    final dir = await Directory.systemTemp.createTemp('ai_flat_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    final budget = aiTokenBudget('orbit');
    await store.chargeFlat('u', 350000, 'smartest', budget);
    expect(store.unitsUsed('u', const Duration(days: 7)), 350000);
  });

  test('credits are spent at the mode weight once the allowance is gone',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai_credit_weight_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    final budget = aiTokenBudget('core');
    await store.addCredits('u', 1000000);
    await store.recordTokens('u', budget.weekly, mode: 'normal');
    expect(store.canSpend('u', budget), isTrue);
    await store.charge('u', 100000, 'smartest', budget);
    expect(store.creditBalance('u'), 750000);
  });

  test('AI checks: plans include weekly reviews, extras cost a weekly share',
      () async {
    expect(aiCheckerWeeklyChecksForPlan('core'), 0);
    expect(aiCheckerWeeklyChecksForPlan('orbit'), 10);
    expect(aiCheckerWeeklyChecksForPlan('nova'), 30);
    expect(aiCheckerWeeklyChecksForPlan(null), 0);
    expect(aiCheckerExchangePercentForPlan('core'), 10);
    expect(aiCheckerExchangePercentForPlan('orbit'), 4);
    expect(aiCheckerExchangePercentForPlan('nova'), 2);
    for (final plan in ['core', 'orbit', 'nova']) {
      final budget = aiTokenBudget(plan);
      expect(budget.weekly * aiCheckerExchangePercentForPlan(plan) ~/ 100,
          lessThanOrEqualTo(budget.fiveHour));
    }

    final dir = await Directory.systemTemp.createTemp('ai_checks_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    expect(store.aiChecksUsed('u'), 0);
    await store.recordAiCheck('u');
    await store.recordAiCheck('u');
    expect(store.aiChecksUsed('u'), 2);
    expect(store.aiChecksUsed('someone-else'), 0);
    final reopened = await AiUsageStore.open(dir.path);
    expect(reopened.aiChecksUsed('u'), 2);
  });

  test('credit packs are priced as listed', () {
    expect([for (final p in kAiCreditPacks) (p.tokens, p.priceCents)], [
      (1000000, 200),
      (2500000, 400),
      (5000000, 750),
      (10000000, 1400),
    ]);
    expect(aiCreditPackById('credits_5m')?.priceCents, 750);
    expect(aiCreditPackById('nope'), isNull);
  });

  test('credits are only spent once the plan budget is used up', () async {
    final dir = await Directory.systemTemp.createTemp('ai_credits_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    final budget = aiTokenBudget('core');
    await store.addCredits('u', 1000000);
    expect(store.creditBalance('u'), 1000000);

    await store.charge('u', 500, 'normal', budget);
    expect(store.creditBalance('u'), 1000000);
    expect(store.tokensUsed('u', const Duration(days: 7), mode: 'normal'), 500);

    await store.recordTokens('u', budget.weekly, mode: 'normal');
    expect(store.canSpend('u', budget), isTrue);
    await store.charge('u', 4000, 'normal', budget);
    expect(store.creditBalance('u'), 996000);

    await store.charge('someone', 10, 'normal', budget);
    expect(store.canSpend('someone', budget), isTrue);
    await store.recordTokens('someone', budget.weekly, mode: 'normal');
    expect(store.canSpend('someone', budget), isFalse);
    expect(store.canAfford('someone', budget, 100), isFalse);
    await store.addCredits('someone', 100);
    expect(store.canAfford('someone', budget, 100), isTrue);
    await store.chargeFlat('someone', 100, 'normal', budget);
    expect(store.creditBalance('someone'), 0);

    final reopened = await AiUsageStore.open(dir.path);
    expect(reopened.creditBalance('u'), 996000);
  });

  test('usage events are isolated by mode and survive reopening', () async {
    final dir = await Directory.systemTemp.createTemp('ai_usage_limits_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    await store.recordTokens('user', 100, mode: 'normal');
    await store.recordTokens('user', 200, mode: 'smarter');
    final reopened = await AiUsageStore.open(dir.path);
    expect(reopened.tokensUsed('user', const Duration(days: 7), mode: 'normal'),
        100);
    expect(
        reopened.tokensUsed('user', const Duration(days: 7), mode: 'smarter'),
        200);
    expect(
        reopened.tokensUsed('user', const Duration(days: 7), mode: 'smartest'),
        0);
  });

  test('pre-mode usage remains charged to Aurora', () async {
    final dir = await Directory.systemTemp.createTemp('ai_usage_legacy_');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.now().millisecondsSinceEpoch;
    await File('${dir.path}${Platform.pathSeparator}ai_usage.json')
        .writeAsString(jsonEncode({'user': {'tokens': [[now, 75]]}}));
    final store = await AiUsageStore.open(dir.path);
    expect(store.tokensUsed('user', const Duration(days: 7), mode: 'normal'), 75);
    expect(store.tokensUsed('user', const Duration(days: 7), mode: 'smarter'), 0);
    expect(store.unitsUsed('user', const Duration(days: 7)), 75);
  });

  test('events stored without units are weighted by their mode', () async {
    final dir = await Directory.systemTemp.createTemp('ai_usage_nounits_');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.now().millisecondsSinceEpoch;
    await File('${dir.path}${Platform.pathSeparator}ai_usage.json')
        .writeAsString(jsonEncode({
      'user': {
        'tokens': [
          [now, 100, 'smarter'],
          [now, 100, 'smartest', 40],
        ],
      },
    }));
    final store = await AiUsageStore.open(dir.path);
    expect(store.unitsUsed('user', const Duration(days: 7)), 150 + 40);
  });

  test('AI calls are logged per feature and model for the dashboard', () async {
    final dir = await Directory.systemTemp.createTemp('ai_calls_');
    addTearDown(() => dir.delete(recursive: true));
    final store = await AiUsageStore.open(dir.path);
    final chat = AiCallUsage.parse(jsonEncode({
      'model': 'google/gemini-3-flash',
      'usage': {'prompt_tokens': 120, 'completion_tokens': 30, 'total_tokens': 150, 'cost': 0.002},
    }));
    expect(chat.model, 'google/gemini-3-flash');
    expect(chat.totalTokens, 150);
    await store.recordCall('user',
        feature: 'Assistant · Aurora', upstream: 'OpenRouter', model: 'fallback', usage: chat);
    await store.recordCall('user',
        feature: 'Assistant · Aurora', upstream: 'OpenRouter', model: 'fallback', usage: chat);
    await store.recordCall('user',
        feature: 'Picture', upstream: 'Google AI Studio', model: 'imagen',
        usage: AiCallUsage.parse(jsonEncode({
          'usageMetadata': {'promptTokenCount': 10, 'candidatesTokenCount': 1290},
        })));

    final reopened = await AiUsageStore.open(dir.path);
    final summary = reopened.callSummary('user');
    final models = summary['models'] as List;
    expect(models, hasLength(2));
    expect(models.first['model'], 'imagen');
    expect(models.first['totalTokens'], 1300);
    final aurora = models.last;
    expect(aurora['model'], 'google/gemini-3-flash');
    expect(aurora['calls'], 2);
    expect(aurora['inputTokens'], 240);
    expect(aurora['outputTokens'], 60);
    expect(aurora['costUsd'], closeTo(0.004, 1e-9));
    expect(summary['recent'], hasLength(3));
    final daily = summary['daily'] as List;
    expect(daily, hasLength(1));
    expect(daily.single['calls'], 3);
    expect(daily.single['tokens'], 1600);
    expect(daily.single['features'],
        {'Assistant · Aurora': 300, 'Picture': 1300});
    expect(reopened.callSummary('nobody')['models'], isEmpty);
    expect(reopened.callSummary('nobody')['daily'], isEmpty);

    await reopened.deleteUser('user');
    expect(reopened.callSummary('user')['models'], isEmpty);
  });
}

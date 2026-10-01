import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:test/test.dart';

void main() {
  test('weekly budgets depend on plan and model; five hours is 15 percent', () {
    expect(aiTokenBudget('core', 'normal').weekly, 750000);
    expect(aiTokenBudget('core', 'smarter').weekly, 500000);
    expect(aiTokenBudget('orbit', 'normal').weekly, 3750000);
    expect(aiTokenBudget('orbit', 'smarter').weekly, 2500000);
    expect(aiTokenBudget('nova', 'normal').weekly, 11250000);
    expect(aiTokenBudget('nova', 'smarter').weekly, 7500000);
    expect(aiTokenBudget('nova', 'smartest').weekly, 4000000);
    for (final plan in ['core', 'orbit', 'nova']) {
      for (final mode in ['normal', 'smarter', 'smartest']) {
        final budget = aiTokenBudget(plan, mode);
        expect(budget.fiveHour, budget.weekly * 15 ~/ 100);
      }
    }
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
      final budget = aiTokenBudget(plan, 'normal');
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
    final budget = aiTokenBudget('core', 'normal');
    await store.addCredits('u', 1000000);
    expect(store.creditBalance('u'), 1000000);

    await store.charge('u', 500, 'normal', budget);
    expect(store.creditBalance('u'), 1000000);
    expect(store.tokensUsed('u', const Duration(days: 7), mode: 'normal'), 500);

    await store.recordTokens('u', budget.weekly, mode: 'normal');
    expect(store.canSpend('u', 'normal', budget), isTrue);
    await store.charge('u', 4000, 'normal', budget);
    expect(store.creditBalance('u'), 996000);

    await store.charge('someone', 10, 'normal', budget);
    expect(store.canSpend('someone', 'normal', budget), isTrue);
    await store.recordTokens('someone', budget.weekly, mode: 'normal');
    expect(store.canSpend('someone', 'normal', budget), isFalse);
    expect(store.canAfford('someone', 'normal', budget, 100), isFalse);
    await store.addCredits('someone', 100);
    expect(store.canAfford('someone', 'normal', budget, 100), isTrue);
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

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
    expect(reopened.callSummary('nobody')['models'], isEmpty);

    await reopened.deleteUser('user');
    expect(reopened.callSummary('user')['models'], isEmpty);
  });
}

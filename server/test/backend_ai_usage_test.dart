import 'dart:io';

import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late AiUsageStore usage;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backend_usage');
    usage = await AiUsageStore.open(dir.path);
  });
  tearDown(() async => dir.delete(recursive: true));

  test('only opted-in calls enter the user feed, with stable IDs after restart',
      () async {
    const tokens = AiCallUsage(inputTokens: 20, outputTokens: 10, costUsd: 0);
    await usage.recordCall('a',
        feature: 'Classroom',
        upstream: 'OpenRouter',
        model: 'model',
        usage: tokens);
    expect(usage.usageCalls('a'), isEmpty);
    await usage.recordCall('a',
        feature: 'Classroom',
        upstream: 'OpenRouter',
        model: 'model',
        usage: tokens,
        includeInUsage: true);
    await usage.recordCall('a',
        feature: 'Picture',
        upstream: 'OpenRouter',
        model: 'model',
        usage: tokens,
        includeInUsage: true);
    final calls = usage.usageCalls('a');
    expect(calls, hasLength(2));
    expect(calls.map((c) => c['id']).toSet(), hasLength(2));
    expect(calls.first['costUsd'], 0);
    expect(usage.usageCalls('b'), isEmpty);
    final reopened = await AiUsageStore.open(dir.path);
    expect(reopened.usageCalls('a'), calls);
    expect(reopened.callSummary('a')['models'], hasLength(2));
  });

  test(
      'Add benchmark credits only the named account without consuming its allowance',
      () async {
    final acc = ChatStreamAccumulator()
      ..addLine(
          'data: {"model":"actual","usage":{"prompt_tokens":120,"completion_tokens":80,"total_tokens":200,"cost":0.5}}');
    await recordBenchmarkGenerationUsage(
        usage,
        {
          'aydenjue@outlook.com': 'owner',
          'someone@example.com': 'other',
        },
        const AiModeRoute(AiUpstream.openrouter, 'requested'),
        acc.usage);
    final call = usage.usageCalls('owner').single;
    expect(call['feature'], 'Add benchmark');
    expect(call['model'], 'actual');
    expect(call['inputTokens'], 120);
    expect(call['outputTokens'], 80);
    expect(call['totalTokens'], 200);
    expect(call['costUsd'], 0.5);
    expect(usage.usageCalls('other'), isEmpty);
    expect(usage.tokensUsed('owner', const Duration(days: 7)), 0);
    await usage.recordCall('owner',
        feature: 'Admin key test',
        upstream: 'OpenRouter',
        model: 'model',
        usage: acc.usage);
    expect(usage.usageCalls('owner'), hasLength(1));
  });

  test('missing target account does not attribute benchmark usage elsewhere',
      () async {
    await recordBenchmarkGenerationUsage(
        usage,
        {'other@example.com': 'other'},
        const AiModeRoute(AiUpstream.google, 'model'),
        const AiCallUsage(inputTokens: 10));
    expect(usage.usageCalls('other'), isEmpty);
  });
}

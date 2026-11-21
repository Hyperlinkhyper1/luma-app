import 'dart:convert';

import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:test/test.dart';

void main() {
  test('automatic compression keeps the benchmark brief on every attempt', () {
    const brief = 'Make a complete interactive scene with a red roof.';
    expect(benchmarkAutoCompactPrompt(brief, 0), brief);
    for (final attempt in [1, 2]) {
      final prompt = benchmarkAutoCompactPrompt(brief, attempt);
      expect(prompt, contains(brief));
      expect(
          prompt.toLowerCase(), matches(RegExp(r'compact|compress|concise')));
    }
    expect(benchmarkAutoCompactPrompt(brief, 1),
        isNot(benchmarkAutoCompactPrompt(brief, 2)));
  });

  test('a retry after overthinking asks for brief planning', () {
    const brief = 'Build a pagoda.';
    final plain = benchmarkAutoCompactPrompt(brief, 1);
    final thought = benchmarkAutoCompactPrompt(brief, 1, overthought: true);
    expect(plain, isNot(contains('thinking')));
    expect(thought, contains(brief));
    expect(thought, contains('thinking'));
    expect(benchmarkAutoCompactPrompt(brief, 0, overthought: true), brief);
  });

  test('reasoning that ate the budget is told apart from a long page', () {
    expect(
        benchmarkReasoningAteBudget(
            contentChars: 0, reasoningChars: 173000, outputTokens: 65000),
        isTrue);
    expect(
        benchmarkReasoningAteBudget(
            contentChars: 7600, reasoningChars: 0, outputTokens: 65000),
        isTrue,
        reason: 'hidden reasoning: 7.6k chars cannot fill 65k tokens');
    expect(
        benchmarkReasoningAteBudget(
            contentChars: 200000, reasoningChars: 30000, outputTokens: 65000),
        isFalse,
        reason: 'the page itself filled the budget');
    expect(
        benchmarkReasoningAteBudget(
            contentChars: 200000, reasoningChars: 0, outputTokens: 0),
        isFalse);
  });

  test('compact retries step reasoning down to medium, then low', () {
    expect(benchmarkCompactRetryEffort('xhigh', 1), 'medium');
    expect(benchmarkCompactRetryEffort('medium', 2), 'low');
    expect(benchmarkCompactRetryEffort('xhigh', 2), 'low');
    expect(benchmarkCompactRetryEffort('high', 1), 'medium');
    expect(benchmarkCompactRetryEffort('medium', 1), 'low');
    expect(benchmarkCompactRetryEffort('low', 2), 'minimal');
    expect(benchmarkCompactRetryEffort('minimal', 1), isNull);
    expect(benchmarkCompactRetryEffort('none', 1), isNull);
    expect(benchmarkCompactRetryEffort(null, 1), isNull);
    expect(benchmarkCompactRetryEffort('xhigh', 0), isNull);
  });

  test('output-limit detection reads normalized and native finish reasons', () {
    for (final reason in ['length', 'MAX_TOKENS', 'max_output_tokens']) {
      for (final native in [false, true]) {
        final acc = ChatStreamAccumulator()
          ..addLine('data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': '<html>'},
                    'finish_reason': native ? 'stop' : reason,
                    if (native) 'native_finish_reason': reason,
                  }
                ]
              })}');
        expect(benchmarkWasTruncated(acc), isTrue,
            reason: '$reason, native=$native');
      }
    }
  });

  test('normal, filtered and unfinished replies are not output limits', () {
    for (final reason in [null, 'stop', 'content_filter', 'SAFETY']) {
      final acc = ChatStreamAccumulator()
        ..addLine('data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': '<html>'},
                  if (reason != null) 'finish_reason': reason,
                }
              ]
            })}');
      expect(benchmarkWasTruncated(acc), isFalse, reason: '$reason');
    }
  });

  test('a truncated response is replaced by a compact complete response',
      () async {
    final acc = ChatStreamAccumulator();
    var attempt = 0;
    final prompts = <String>[];
    final recorded = <String>[];
    final result = await retryBenchmarkCompacted<int>(
        acc,
        () async {
          prompts.add(benchmarkAutoCompactPrompt('Build a scene.', attempt));
          acc.addCompletion({
            'choices': [
              {
                'message': {
                  'content': attempt == 0
                      ? '<html>unfinished'
                      : '<html>complete</html>'
                },
                'finish_reason': attempt == 0 ? 'length' : 'stop',
              }
            ]
          });
          return 200;
        },
        attempt: () => attempt,
        autoCompact: true,
        canRetry: () => true,
        isSuccess: (status) => status == 200,
        beforeRetry: () async {
          recorded.add(acc.content);
          attempt++;
          acc.reset();
        });
    expect(result, 200);
    expect(prompts, hasLength(2));
    expect(prompts.first, 'Build a scene.');
    expect(prompts.last, contains('Build a scene.'));
    expect(recorded, ['<html>unfinished']);
    expect(acc.content, '<html>complete</html>');
  });

  test('retries stop at the automatic attempt limit', () async {
    final acc = ChatStreamAccumulator();
    var attempt = 0;
    var requests = 0;
    await retryBenchmarkCompacted<int>(
        acc,
        () async {
          requests++;
          acc.addCompletion({
            'choices': [
              {
                'message': {'content': 'attempt $attempt'},
                'finish_reason': 'length',
              }
            ]
          });
          return 200;
        },
        attempt: () => attempt,
        autoCompact: true,
        canRetry: () => true,
        isSuccess: (status) => status == 200,
        beforeRetry: () async {
          attempt++;
          acc.reset();
        });
    expect(requests, 3);
    expect(acc.content, 'attempt 2');
  });

  test('explicit caps, errors and stops never launch a compact retry',
      () async {
    for (final condition in ['explicit', 'http', 'error', 'stop', 'normal']) {
      final acc = ChatStreamAccumulator();
      var requests = 0;
      await retryBenchmarkCompacted<int>(acc, () async {
        requests++;
        acc.addCompletion({
          if (condition == 'error') 'error': {'message': 'Provider failed'},
          'choices': [
            {
              'message': {'content': 'original output'},
              'finish_reason': condition == 'normal' ? 'stop' : 'length',
            }
          ]
        });
        return condition == 'http' ? 503 : 200;
      },
          attempt: () => 0,
          autoCompact: condition != 'explicit',
          canRetry: () => condition != 'stop',
          isSuccess: (status) => status == 200,
          beforeRetry: () async => fail('unexpected retry: $condition'));
      expect(requests, 1, reason: condition);
      expect(acc.content, 'original output', reason: condition);
    }
  });
}

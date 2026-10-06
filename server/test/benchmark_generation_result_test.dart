import 'dart:convert';

import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:test/test.dart';

void main() {
  const page = '<!doctype html><html><body></body></html>';
  const partial = '<!doctype html><html><body><script>let x =';

  test('failed batch keeps result diagnostics after a server restart', () {
    final job = BenchmarkGenJob(
      id: 'run1',
      kind: 'pagoda',
      sceneId: 'pagoda_demo',
      name: 'Demo',
      vendor: '',
      route: const AiModeRoute(AiUpstream.openrouter, 'demo/model:batch'),
      prompt: '',
      maxTokens: 7000,
      startedAtMs: 1,
      batchId: 'batch1',
    )
      ..status = 'failed'
      ..resultStatus = 'TRUNCATED'
      ..resultReason = 'Output limit reached'
      ..validation = 'Missing closing </html>'
      ..finishReason = 'length'
      ..nativeFinishReason = 'MAX_TOKENS'
      ..outputTokens = 6900
      ..tokens = 8000
      ..chars = 12200
      ..hasOutput = true;
    final restored =
        BenchmarkGenJob.fromState(jsonDecode(jsonEncode(job.toState())));
    expect(restored, isNotNull);
    for (final field in [
      'status',
      'resultStatus',
      'resultReason',
      'validation',
      'finishReason',
      'nativeFinishReason',
      'outputTokens',
      'tokens',
      'chars',
      'hasOutput'
    ]) {
      expect(restored!.toJson()[field], job.toJson()[field], reason: field);
    }
  });

  test('output ceilings take precedence even when HTML has a closing tag', () {
    for (final reason in ['length', 'MAX_TOKENS', 'max_output_tokens']) {
      for (final reply in ['', partial, page]) {
        final result =
            benchmarkGenerationResult(reply: reply, finishReason: reason);
        expect(result.status, 'TRUNCATED');
        expect(result.reason, 'Output limit reached');
      }
    }
    expect(
        benchmarkGenerationResult(
                reply: page,
                finishReason: 'stop',
                nativeFinishReason: 'MAX_TOKENS')
            .status,
        'TRUNCATED');
  });

  test('missing closing HTML is invalid, not evidence of a token limit', () {
    final result =
        benchmarkGenerationResult(reply: partial, finishReason: 'stop');
    expect(result.status, 'INVALID_OUTPUT');
    expect(result.validation, 'Missing closing </html>');
    expect(
        benchmarkGenerationResult(reply: partial).reason, contains('unknown'));
    expect(
        benchmarkGenerationResult(reply: 'Sorry.').validation, 'No HTML page');
    expect(benchmarkGenerationResult(reply: page, finishReason: 'stop').status,
        'PASS');
  });

  test('provider failures cannot pass with partial or complete output', () {
    for (final reply in ['', partial, page]) {
      for (final code in [429, 503, 502, 529, 401, 500]) {
        final status = benchmarkGenerationResult(
                reply: reply, httpStatus: code, error: 'Provider error')
            .status;
        expect(
            status,
            code == 429
                ? 'RATE_LIMITED'
                : [502, 503, 529].contains(code)
                    ? 'PROVIDER_BUSY'
                    : 'MODEL_ERROR');
      }
      expect(
          benchmarkGenerationResult(reply: reply, error: 'Stream error').status,
          'MODEL_ERROR');
    }
    expect(
        benchmarkGenerationResult(reply: page, finishReason: 'content_filter')
            .status,
        'MODEL_ERROR');
  });

  test('native Google streamed and batch replies retain MAX_TOKENS and usage',
      () {
    final body = {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'thinking', 'thought': true},
              {'text': partial}
            ]
          },
          'finishReason': 'MAX_TOKENS',
        }
      ],
      'usageMetadata': {
        'promptTokenCount': 10,
        'candidatesTokenCount': 90,
        'totalTokenCount': 100
      },
    };
    for (final streamed in [true, false]) {
      final acc = ChatStreamAccumulator();
      if (streamed) {
        acc.addLine('data: ${jsonEncode(body)}');
      } else {
        acc.addCompletion(body);
      }
      expect(acc.content, partial);
      expect(acc.reasoningChars, 8);
      expect(acc.finishReason, 'MAX_TOKENS');
      expect(acc.usage.outputTokens, 90);
      expect(acc.tokens, 100);
    }
  });

  test('OpenRouter retains normalized and native finish reasons separately',
      () {
    final acc = ChatStreamAccumulator()
      ..addLine(
          'data: {"choices":[{"delta":{"content":"$page"},"finish_reason":"stop","native_finish_reason":"end_turn"}]}')
      ..addLine('data: {"error":{"code":429,"message":"Rate limited"}}');
    expect(acc.finishReason, 'stop');
    expect(acc.nativeFinishReason, 'end_turn');
    expect(acc.errorCode, 429);
    expect(
        benchmarkGenerationResult(
                reply: acc.content,
                finishReason: acc.finishReason,
                httpStatus: acc.errorCode,
                error: acc.error)
            .status,
        'RATE_LIMITED');
  });

  test('batch response errors retain HTTP status for classification', () {
    final acc = ChatStreamAccumulator();
    final error = readBenchmarkBatch({
      'status': 'completed',
      'results': [
        {
          'response': {
            'status_code': 503,
            'body': {
              'error': {'message': 'Busy'}
            }
          }
        }
      ],
    }, acc);
    expect(acc.providerStatus, 503);
    expect(
        benchmarkGenerationResult(
                reply: acc.content,
                httpStatus: acc.providerStatus,
                error: error)
            .status,
        'PROVIDER_BUSY');
  });
}

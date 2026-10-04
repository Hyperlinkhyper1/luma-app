import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:luma_sync_server/benchmark_prompts.dart';
import 'package:test/test.dart';

/// Covers the pure half of the dashboard's "Add benchmark": pulling the
/// page out of a model's reply, reading the stream, and naming the entry.
void main() {
  group('extractBenchmarkHtml', () {
    const page = '<!DOCTYPE html><html><body><canvas></canvas></body></html>';

    test('takes a bare page as is', () {
      expect(extractBenchmarkHtml(page), page);
    });

    test('drops chatter around the page', () {
      expect(extractBenchmarkHtml('Here you go!\n\n$page\n\nEnjoy.'), page);
    });

    test('prefers the longest fenced page', () {
      final reply = 'Snippet:\n```js\nconst a = 1;\n```\n'
          'Full page:\n```html\n$page\n```\nDone.';
      expect(extractBenchmarkHtml(reply), page);
    });

    test('ignores a think block that quotes html', () {
      final reply = '<think>maybe <html> like this</think>$page';
      expect(extractBenchmarkHtml(reply), page);
    });

    test('keeps a page cut off before </html>, flagged incomplete', () {
      const cut = '<!doctype html><html><body><script>let x = 1';
      final got = extractBenchmarkHtml('Sure:\n$cut');
      expect(got, cut);
      expect(benchmarkHtmlComplete(got!), isFalse);
      expect(benchmarkHtmlComplete(page), isTrue);
    });

    test('null when there is no page at all', () {
      expect(extractBenchmarkHtml('I cannot help with that.'), isNull);
    });
  });

  group('ChatStreamAccumulator', () {
    test('collects content, reasoning, usage and finish reason', () {
      final acc = ChatStreamAccumulator();
      for (final line in [
        ': OPENROUTER PROCESSING',
        'data: {"choices":[{"delta":{"reasoning":"hmm"}}]}',
        'data: {"choices":[{"delta":{"content":"<html>"}}]}',
        '',
        'data: {"choices":[{"delta":{"content":"</html>"},"finish_reason":"stop"}]}',
        'data: {"choices":[],"usage":{"total_tokens":1234}}',
        'data: [DONE]',
      ]) {
        acc.addLine(line);
      }
      expect(acc.content, '<html></html>');
      expect(acc.reasoningChars, 3);
      expect(acc.finishReason, 'stop');
      expect(acc.tokens, 1234);
      expect(acc.done, isTrue);
    });

    test('reads Google-style reasoning_content and mid-stream errors', () {
      final acc = ChatStreamAccumulator()
        ..addLine('data: {"choices":[{"delta":{"reasoning_content":"ab"}}]}')
        ..addLine('data: {"error":{"message":"Rate limited"}}')
        ..addLine('data: not json');
      expect(acc.reasoningChars, 2);
      expect(acc.error, 'Rate limited');
      expect(acc.content, isEmpty);
    });
  });

  group('naming', () {
    test('display name drops the company prefix and adds the effort', () {
      expect(benchmarkDisplayName('Anthropic: Claude Sonnet 5.5', 'high'),
          'Claude Sonnet 5.5 (High)');
      expect(benchmarkDisplayName('gemini-3-pro', ''), 'gemini-3-pro');
      expect(benchmarkDisplayName('Grok 5', 'none'), 'Grok 5');
    });

    test('vendor comes from the key or the OpenRouter id', () {
      const known = {'anthropic', 'google', 'mistralai', 'x-ai'};
      expect(benchmarkVendorFor(AiUpstream.openrouter, 'x-ai/grok-5', known),
          'x-ai');
      expect(
          benchmarkVendorFor(AiUpstream.openrouter, 'acme/thing', known), '');
      expect(benchmarkVendorFor(AiUpstream.google, 'gemini-3-pro', known),
          'google');
      expect(benchmarkVendorFor(AiUpstream.mistral, 'mistral-large', known),
          'mistralai');
    });

    test('scene id matches the upload dialog and never reuses an id', () {
      expect(benchmarkSceneId('pagoda', 'Sonnet 5.5 (High)', 'high', {}),
          'pagoda_sonnet_55_high');
      expect(
          benchmarkSceneId('engine', 'Sonnet 5.5 (High)', 'high',
              {'engine_sonnet_55_high', 'engine_sonnet_55_high_2'}),
          'engine_sonnet_55_high_3');
      expect(benchmarkSceneId('pc', 'Grok 5', '', {}), 'pc_grok_5');
      expect(benchmarkSceneId('pc', 'Grok 5', 'none', {}), 'pc_grok_5');
    });

    test('generated ids and names pass the store\'s own validation', () {
      for (final kind in kBenchmarkPrompts.keys) {
        final name = benchmarkDisplayName('OpenAI: GPT-6.1 Sol', 'xhigh');
        final id = benchmarkSceneId(kind, name, 'xhigh', {});
        expect(
          () => AiBenchmarkStore.validateUpload(
            kind: kind,
            id: id,
            model: name,
            vendor: 'openai',
            description: 'x',
            bytes: null,
          ),
          returnsNormally,
          reason: id,
        );
      }
    });
  });

  group('prompts', () {
    test('every test has a prompt ending in the output contract', () {
      for (final kind in kBenchmarkPrompts.keys) {
        expect(AiBenchmarkStore.kinds, contains(kind));
        if (kBenchmarkManualKinds.contains(kind)) continue;
        final p = benchmarkPromptFor(kind);
        expect(p, contains('<!DOCTYPE html>'));
        expect(p.trimRight(), endsWith('breaks it.'));
      }
    });

    test('the cathedral prompt is for copying only: no HTML contract', () {
      expect(kBenchmarkManualKinds, {'cathedral'});
      expect(kBenchmarkPrompts, contains('cathedral'));
      final p = benchmarkPromptFor('cathedral');
      expect(p, contains('cathedral.glb'));
      expect(p, isNot(contains('<!DOCTYPE html>')));
      expect(AiBenchmarkStore.extForKind('cathedral'), 'glb');
    });
  });

  group('batch', () {
    const page = '<!doctype html><html><body></body></html>';

    test('only OpenRouter :batch ids run as a batch', () {
      expect(
          isBenchmarkBatchModel(
              AiUpstream.openrouter, 'anthropic/claude-sonnet-5.5:batch'),
          isTrue);
      expect(
          isBenchmarkBatchModel(
              AiUpstream.openrouter, 'anthropic/claude-sonnet-5.5'),
          isFalse);
      expect(isBenchmarkBatchModel(AiUpstream.google, 'gemini:batch'), isFalse);
      expect(isBenchmarkBatchModel(AiUpstream.openrouter, ':batch'), isFalse);
      expect(benchmarkBatchBaseModel('anthropic/claude-sonnet-5.5:batch'),
          'anthropic/claude-sonnet-5.5');
      expect(benchmarkBatchBaseModel('x-ai/grok-5'), 'x-ai/grok-5');
    });

    test('the entry name drops OpenRouter\'s (batch) tag', () {
      expect(
          benchmarkDisplayName('Anthropic: Claude Sonnet 5.5 (batch)', 'high'),
          'Claude Sonnet 5.5 (High)');
    });

    test('reads a completed batch like a finished stream', () {
      final acc = ChatStreamAccumulator();
      final why = readBenchmarkBatch({
        'status': 'completed',
        'usage': {'prompt_tokens': 10, 'completion_tokens': 90, 'cost': 0.5},
        'results': [
          {
            'custom_id': 'pagoda_x',
            'response': {
              'status_code': 200,
              'body': {
                'choices': [
                  {
                    'message': {
                      'content': page,
                      'reasoning': 'thinking it over',
                    },
                    'finish_reason': 'stop',
                  },
                ],
                'usage': {'prompt_tokens': 10, 'completion_tokens': 90},
              },
            },
            'error': null,
          },
        ],
      }, acc);
      expect(why, isNull);
      expect(acc.content, page);
      expect(acc.reasoningChars, 'thinking it over'.length);
      expect(acc.finishReason, 'stop');
      expect(acc.tokens, 100);
      expect(acc.usage.costUsd, 0.5);
    });

    test('says why a batch produced nothing', () {
      expect(
          readBenchmarkBatch({
            'status': 'failed',
            'error': {'message': 'model has no batch endpoint'},
          }, ChatStreamAccumulator()),
          'The batch ended failed: model has no batch endpoint.');
      expect(
          readBenchmarkBatch({
            'status': 'completed',
            'results': [
              {
                'response': null,
                'error': {'message': 'max_tokens too large'},
              },
            ],
          }, ChatStreamAccumulator()),
          'max_tokens too large');
      expect(readBenchmarkBatch({'status': 'expired'}, ChatStreamAccumulator()),
          'The batch ended expired.');
    });
  });
}

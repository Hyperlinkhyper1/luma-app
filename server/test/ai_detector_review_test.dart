import 'dart:io';

import 'package:luma_sync_server/ai_detector_review.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:test/test.dart';

void main() {
  const text = 'Went to the allotment after work. In today\'s fast-paced '
      'world, gardening offers a unique opportunity to reconnect with nature.';

  group('parseAiDetectorReply', () {
    test('reads a fenced reply and locates each quote', () {
      const reply = '```json\n{"score": 71, "verdict": "Mixed", '
          '"summary": "Half and half.", "passages": ['
          '{"quote": "In today\'s fast-paced world", "likelihood": 92, '
          '"reason": "Stock opener."},'
          '{"quote": "Went to the allotment after work.", "likelihood": 8, '
          '"reason": "Plain diary voice."}]}\n```';
      final verdict = parseAiDetectorReply(reply, text)!;
      expect(verdict.score, 71);
      expect(verdict.verdict, 'Mixed');
      expect(verdict.passages, hasLength(2));
      // Sorted into text order.
      final first = verdict.passages.first;
      expect(text.substring(first.start!, first.end!),
          'Went to the allotment after work.');
      expect(verdict.passages.last.likelihood, 92);
    });

    test('finds quotes the model normalised', () {
      final span = locateQuote(
          text, 'in TODAY’S   fast-paced world, gardening');
      expect(span, isNotNull);
      expect(text.substring(span!.$1, span.$2),
          "In today's fast-paced world, gardening");
    });

    test('keeps a paraphrased passage without offsets', () {
      final verdict = parseAiDetectorReply(
          '{"score": 0.4, "passages": [{"quote": "nothing like this", '
          '"likelihood": 50, "reason": "x"}]}',
          text)!;
      expect(verdict.score, 40);
      expect(verdict.verdict, 'Mixed signals');
      expect(verdict.passages.single.start, isNull);
    });

    test('rejects replies without a score', () {
      expect(parseAiDetectorReply('I think it is AI.', text), isNull);
      expect(parseAiDetectorReply('{"verdict": "AI"}', text), isNull);
    });
  });

  test('the output contract always follows the instructions', () {
    final messages = aiDetectorMessages('Judge harshly.', 'hello');
    expect(messages.first['content'], startsWith('Judge harshly.'));
    expect(messages.first['content'], contains('"passages"'));
    expect(messages.last['content'], '<text>\nhello\n</text>');
  });

  test('config persists and blank instructions mean the built-in ones',
      () async {
    final dir = Directory.systemTemp.createTempSync('luma_ai_detector');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(AiDetectorConfigStore(dir.path).config.effectiveInstructions,
        kDefaultAiDetectorInstructions);
    await AiDetectorConfigStore(dir.path).save(const AiDetectorConfig(
      route: AiModeRoute(AiUpstream.openrouter, 'anthropic/claude-sonnet-5'),
      instructions: 'Be strict.',
    ));
    final reloaded = AiDetectorConfigStore(dir.path).config;
    expect(reloaded.route!.model, 'anthropic/claude-sonnet-5');
    expect(reloaded.effectiveInstructions, 'Be strict.');
  });
}

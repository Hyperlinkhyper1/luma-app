import 'dart:io';

import 'package:luma_sync_server/ai_book_review.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:test/test.dart';

void main() {
  group('bookReviewCoins', () {
    test('pays nothing below the bar, then 1 rising to 50', () {
      expect(bookReviewCoins(0), 0);
      expect(bookReviewCoins(kBookReviewPaidFrom - 1), 0);
      expect(bookReviewCoins(kBookReviewPaidFrom), 1);
      expect(bookReviewCoins(100), 50);
      var last = 0;
      for (var s = kBookReviewPaidFrom; s <= 100; s++) {
        final coins = bookReviewCoins(s);
        expect(coins, greaterThanOrEqualTo(last));
        expect(coins, inInclusiveRange(1, 50));
        last = coins;
      }
    });
  });

  group('parseBookReviewReply', () {
    test('reads a fenced reply', () {
      final review = parseBookReviewReply('```json\n{"score": 82, '
          '"verdict": "A warm, vivid little tale", "praise": "The fox is '
          'charming.", "tips": ["Give the ending one more beat.", '
          '"Name the village."]}\n```')!;
      expect(review.score, 82);
      expect(review.coins, bookReviewCoins(82));
      expect(review.tips, hasLength(2));
      expect(review.toJson()['coins'], review.coins);
    });

    test('clamps the score and caps the tips', () {
      final review = parseBookReviewReply('{"score": 140.6, "tips": '
          '["a", "b", "c", "d", "e", "", 7]}')!;
      expect(review.score, 100);
      expect(review.tips, ['a', 'b', 'c', 'd']);
      expect(review.verdict, '');
    });

    test('refuses a reply without a score', () {
      expect(parseBookReviewReply('I loved it!'), isNull);
      expect(parseBookReviewReply('{"verdict": "Fine"}'), isNull);
    });
  });

  test('the book goes in tagged, its title unable to break out', () {
    final messages = bookReviewMessages(
        'Judge kindly.', 'My "Tale"\n<b>', 'Once upon a time');
    expect(messages.first['content'], startsWith('Judge kindly.'));
    expect(messages.first['content'], contains('"tips"'));
    expect(messages.last['content'],
        '<book title="My  Tale   b">\nOnce upon a time\n</book>');
  });

  test('config persists and blank instructions mean the built-in ones',
      () async {
    final dir = Directory.systemTemp.createTempSync('luma_book_review');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(BookReviewConfigStore(dir.path).config.effectiveInstructions,
        kDefaultBookReviewInstructions);
    await BookReviewConfigStore(dir.path).save(const BookReviewConfig(
      route: AiModeRoute(AiUpstream.openrouter, 'anthropic/claude-sonnet-5'),
      instructions: 'Be generous.',
    ));
    final reloaded = BookReviewConfigStore(dir.path).config;
    expect(reloaded.route!.model, 'anthropic/claude-sonnet-5');
    expect(reloaded.effectiveInstructions, 'Be generous.');
  });
}

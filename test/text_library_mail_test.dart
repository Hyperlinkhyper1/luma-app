import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/mail_store.dart';

void main() {
  test('mail state round-trips', () {
    const state = MailState(open: 600, letters: [12, 30], hand: 17, vault: 240);
    final back = MailState.fromJson(state.toJson());
    expect(back.toJson(), state.toJson());
  });

  test('mail state from the page is cleaned up', () {
    final state = MailState.fromJson({
      'open': -5,
      'letters': [20.7, 0, -3, 'x', 15, 11, 12, 13, 14, 16, 17, 18, 19],
      'hand': 'lots',
      'vault': 99.9,
    });
    expect(state.open, 0);
    expect(state.letters, [20, 15, 11, 12, 13, 14]);
    expect(state.hand, 0);
    expect(state.vault, 99);
  });

  test('nothing saved reads as an empty post', () {
    expect(MailState.fromJson(null).toJson(), const MailState().toJson());
  });

  test('review letters, the pending review and fingerprints round-trip', () {
    const state = MailState(
      letters: [
        14,
        ReviewLetter(
          title: 'Fox',
          coins: 20,
          good: true,
          verdict: 'Lovely',
          praise: 'Vivid.',
        ),
      ],
      reviews: [
        PendingReview(
          wait: 300,
          letter: ReviewLetter(title: 'Owl', tips: ['Add a scene.']),
        ),
      ],
      reviewed: {
        '7': {'h': 'abcd1234', 'paid': 20},
      },
    );
    final back = MailState.fromJson(state.toJson());
    expect(back.toJson(), state.toJson());
    expect(back.letters.last, isA<ReviewLetter>());
  });

  test('review state from the page is cleaned up', () {
    final state = MailState.fromJson({
      'letters': [
        {
          'kind': 'review',
          'title': 'x' * 100,
          'coins': 99,
          'tips': ['a', '', 4, 'b', 'c', 'd', 'e'],
        },
        {'kind': 'bogus'},
        5,
      ],
      'reviews': [
        {
          'wait': 999999,
          'letter': {'kind': 'review', 'title': 'Owl'},
        },
        {
          'wait': 5,
          'letter': {'kind': 'review'},
        },
      ],
      'reviewed': {
        '7': {'h': 'abcd', 'paid': 70},
        'x': {'h': 'zz'},
        '9': 'no',
      },
    });
    final review = state.letters.first as ReviewLetter;
    expect(review.title, hasLength(64));
    expect(review.coins, 50);
    expect(review.tips, ['a', 'b', 'c', 'd']);
    expect(state.letters.last, 5);
    expect(state.reviews.single.wait, MailState.reviewWait);
    expect(state.reviewed.keys, ['7']);
    expect(state.reviewed['7']!['paid'], 50);
  });
}

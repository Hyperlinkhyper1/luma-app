import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A letter from the book review desk: what the reviewer thought of one of
/// the reader's books, the coins it earned and — when it earned none — the
/// tips to make it better.
class ReviewLetter {
  const ReviewLetter({
    this.title = '',
    this.coins = 0,
    this.good = false,
    this.verdict = '',
    this.praise = '',
    this.tips = const [],
  });

  final String title;
  final int coins;
  final bool good;
  final String verdict;
  final String praise;
  final List<String> tips;

  static String _text(Object? v, int max) =>
      v is String ? (v.length > max ? v.substring(0, max) : v) : '';

  static ReviewLetter? fromJson(Object? json) {
    if (json is! Map || json['kind'] != 'review') return null;
    final tips = json['tips'];
    return ReviewLetter(
      title: _text(json['title'], 64),
      coins: MailState._count(json['coins']).clamp(0, 50),
      good: json['good'] == true,
      verdict: _text(json['verdict'], 120),
      praise: _text(json['praise'], 400),
      tips: [
        if (tips is List)
          for (final t in tips)
            if (_text(t, 300).isNotEmpty) _text(t, 300),
      ].take(4).toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'kind': 'review',
    'title': title,
    'coins': coins,
    'good': good,
    'verdict': verdict,
    'praise': praise,
    'tips': tips,
  };
}

/// A book waiting on the reviewer: its letter is already written and comes
/// to the mailbox after [wait] more seconds of the hall being open.
class PendingReview {
  const PendingReview({required this.wait, required this.letter});

  final int wait;
  final ReviewLetter letter;

  Map<String, Object?> toJson() => {'wait': wait, 'letter': letter.toJson()};
}

/// The Minecraft hall's post and vault: how long the hall has been open
/// toward the next letter, the letters waiting in the mailbox (coin amounts,
/// or book reviews), the coins in the reader's hand and those in the vault,
/// the book review on its way, and a fingerprint of every book reviewed so
/// far with the coins it has been paid.
///
/// The page does the timing and hands the whole state over whenever it
/// changes; it is kept on this device only, like the skin.
class MailState {
  const MailState({
    this.open = 0,
    this.letters = const [],
    this.hand = 0,
    this.vault = 0,
    this.reviews = const [],
    this.reviewed = const {},
  });

  /// Seconds a review takes: one in-game day.
  static const reviewWait = 1200;
  static const maxReviewed = 500;

  /// Seconds counted toward the next letter.
  final int open;

  /// Each letter is an [int] of coins or a [ReviewLetter].
  final List<Object> letters;
  final int hand;
  final int vault;
  final List<PendingReview> reviews;

  /// Book id → `{h: text fingerprint, paid: coins paid}`.
  final Map<String, Map<String, Object>> reviewed;

  static int _count(Object? value) => switch (value) {
    final num n when n.isFinite && n > 0 => n.floor(),
    _ => 0,
  };

  /// Whatever the page sent, cleaned up: counts are whole and never negative,
  /// and empty or malformed letters are dropped.
  factory MailState.fromJson(Object? json) {
    if (json is! Map) return const MailState();
    final letters = json['letters'];
    final reviews = json['reviews'];
    final reviewed = json['reviewed'];
    return MailState(
      open: _count(json['open']),
      letters: [
        if (letters is List)
          for (final l in letters.take(9))
            if (l is Map)
              ?ReviewLetter.fromJson(l)
            else if (_count(l) > 0)
              _count(l),
      ],
      hand: _count(json['hand']),
      vault: _count(json['vault']),
      reviews: [
        if (reviews is List)
          for (final r in reviews.take(1))
            if (r is Map && ReviewLetter.fromJson(r['letter']) != null)
              PendingReview(
                wait: _count(r['wait']).clamp(0, reviewWait),
                letter: ReviewLetter.fromJson(r['letter'])!,
              ),
      ],
      reviewed: {
        if (reviewed is Map)
          for (final MapEntry(:key, :value) in reviewed.entries.take(
            maxReviewed,
          ))
            if (key is String &&
                RegExp(r'^\d+$').hasMatch(key) &&
                value is Map &&
                value['h'] is String)
              key: {
                'h': (value['h'] as String).length > 16
                    ? (value['h'] as String).substring(0, 16)
                    : value['h'] as String,
                'paid': _count(value['paid']).clamp(0, 50),
              },
      },
    );
  }

  Map<String, Object?> toJson() => {
    'open': open,
    'letters': [for (final l in letters) l is ReviewLetter ? l.toJson() : l],
    'hand': hand,
    'vault': vault,
    'reviews': [for (final r in reviews) r.toJson()],
    'reviewed': reviewed,
  };
}

Future<File> _file() async {
  final support = await getApplicationSupportDirectory();
  return File('${support.path}${Platform.pathSeparator}text_library_mail.json');
}

Future<MailState?> loadMail() async {
  try {
    final file = await _file();
    if (!await file.exists()) return null;
    return MailState.fromJson(jsonDecode(await file.readAsString()));
  } catch (_) {
    return null;
  }
}

Future<void> _saving = Future.value();

/// Saves one after another, so a quick run of changes lands in order.
Future<void> saveMail(MailState state) {
  final next = _saving.catchError((Object _) {}).then((_) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temp.rename(file.path);
  });
  _saving = next;
  return next;
}

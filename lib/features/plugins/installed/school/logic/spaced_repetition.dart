/// SM-2 spaced-repetition scheduling, driven by the classic 4-button
/// Anki-style review ratings rather than SM-2's original 0-5 quality scale.
enum ReviewRating { again, hard, good, easy }

/// The updated scheduling state to persist after a flashcard review.
class SM2Result {
  const SM2Result({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReviewDate,
  });

  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReviewDate;
}

const double _minEaseFactor = 1.3;

/// Computes the next ease factor, interval, repetition count, and due date
/// for a flashcard given how the user rated their recall of it.
SM2Result computeNextReview({
  required double easeFactor,
  required int intervalDays,
  required int repetitions,
  required ReviewRating rating,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();

  if (rating == ReviewRating.again) {
    // Lapses reset the streak and shrink the ease factor, but the card is
    // due again tomorrow rather than immediately.
    final newEase = (easeFactor - 0.2).clamp(_minEaseFactor, 3.0);
    return SM2Result(
      easeFactor: newEase,
      intervalDays: 1,
      repetitions: 0,
      nextReviewDate: today.add(const Duration(days: 1)),
    );
  }

  // Map the 4-button rating onto SM-2's 0-5 "quality" scale for the ease
  // factor formula (Again is handled above and never reaches here).
  final quality = switch (rating) {
    ReviewRating.hard => 3,
    ReviewRating.good => 4,
    ReviewRating.easy => 5,
    ReviewRating.again => 0,
  };

  var newEase = easeFactor +
      (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  newEase = newEase.clamp(_minEaseFactor, 3.5);

  final newRepetitions = repetitions + 1;
  int newInterval;
  if (newRepetitions == 1) {
    newInterval = 1;
  } else if (newRepetitions == 2) {
    newInterval = 6;
  } else {
    newInterval = (intervalDays * newEase).round();
  }

  if (rating == ReviewRating.hard) {
    newInterval = (newInterval * 0.8).round().clamp(1, newInterval);
  } else if (rating == ReviewRating.easy) {
    newInterval = (newInterval * 1.3).round();
  }
  newInterval = newInterval < 1 ? 1 : newInterval;

  return SM2Result(
    easeFactor: newEase,
    intervalDays: newInterval,
    repetitions: newRepetitions,
    nextReviewDate: today.add(Duration(days: newInterval)),
  );
}

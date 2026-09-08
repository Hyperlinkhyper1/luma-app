import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/logic/quiz_bank.dart';

void main() {
  group('quiz bank integrity', () {
    // Most of the pool comes out of the generators in `logic/quiz/*_extra.dart`,
    // which silently drop a question they cannot give four distinct options.
    // This guards the floor: if a template starts dropping most of its output,
    // the count falls through 500 and this fails.
    test('every subject has at least 500 questions', () {
      for (final s in QuizBank.subjects) {
        expect(s.questions.length, greaterThanOrEqualTo(500),
            reason: '${s.name} has too few questions to draw varied tests');
      }
    });

    test('every topic can fill its share of the longest test', () {
      final longest = QuizBank.lengths.reduce((a, b) => a > b ? a : b);
      for (final s in QuizBank.subjects) {
        final perTopic = <String, int>{};
        for (final q in s.questions) {
          perTopic[q.topic] = (perTopic[q.topic] ?? 0) + 1;
        }
        final share = (longest / perTopic.length).ceil();
        for (final entry in perTopic.entries) {
          expect(entry.value, greaterThanOrEqualTo(share),
              reason: '${s.name} / ${entry.key} cannot fill a $longest-vragen '
                  'toets without repeating');
        }
      }
    });

    test('question ids are unique across the whole bank', () {
      final seen = <String>{};
      for (final s in QuizBank.subjects) {
        for (final q in s.questions) {
          expect(seen.add(q.id), isTrue, reason: 'duplicate id ${q.id}');
        }
      }
    });

    test('every question has four options and a valid answer index', () {
      for (final s in QuizBank.subjects) {
        for (final q in s.questions) {
          expect(q.options, hasLength(4), reason: q.id);
          expect(q.answerIndex, inInclusiveRange(0, 3), reason: q.id);
          expect(q.prompt.trim(), isNotEmpty, reason: q.id);
        }
      }
    });

    test('options within a question are distinct and non-empty', () {
      for (final s in QuizBank.subjects) {
        for (final q in s.questions) {
          expect(q.options.toSet(), hasLength(4),
              reason: '${q.id} repeats an option');
          for (final o in q.options) {
            expect(o.trim(), isNotEmpty, reason: q.id);
          }
        }
      }
    });

    test('the correct answer is not always the same letter', () {
      // A bank where every answer sits at index 0 is guessable without
      // reading the question.
      for (final s in QuizBank.subjects) {
        final indices = s.questions.map((q) => q.answerIndex).toSet();
        expect(indices.length, greaterThan(1), reason: s.name);
      }
    });

    test('every subject splits into at least three topics', () {
      for (final s in QuizBank.subjects) {
        expect(s.topics.length, greaterThanOrEqualTo(3), reason: s.name);
      }
    });

    test('subject ids are unique and resolvable', () {
      final ids = QuizBank.subjects.map((s) => s.id).toSet();
      expect(ids, hasLength(QuizBank.subjects.length));
      for (final id in ids) {
        expect(QuizBank.byId(id), isNotNull);
      }
      expect(QuizBank.byId('does-not-exist'), isNull);
    });
  });

  group('buildTest', () {
    test('draws the requested number of questions without repeats', () {
      for (final s in QuizBank.subjects) {
        final test = buildTest(s, count: 20, seed: 1);
        expect(test, hasLength(20), reason: s.name);
        expect(test.map((q) => q.id).toSet(), hasLength(20), reason: s.name);
      }
    });

    test('never asks for more than the subject holds', () {
      final s = QuizBank.subjects.first;
      final test = buildTest(s, count: s.questions.length + 50, seed: 2);
      expect(test, hasLength(s.questions.length));
    });

    test('spreads questions evenly across topics', () {
      // The point of the even spread: a 20-question test of any subject
      // covers every topic, so two tests of the same length are comparable.
      for (final s in QuizBank.subjects) {
        final test = buildTest(s, count: 20, seed: 3);
        final counts = <String, int>{};
        for (final q in test) {
          counts[q.topic] = (counts[q.topic] ?? 0) + 1;
        }
        expect(counts.keys.toSet(), s.topics.toSet(), reason: s.name);
        final spread = counts.values.reduce((a, b) => a > b ? a : b) -
            counts.values.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThanOrEqualTo(1),
            reason: '${s.name} is lopsided: $counts');
      }
    });

    test('the same seed gives the same test, a different one does not', () {
      final s = QuizBank.subjects.first;
      final a = buildTest(s, count: 15, seed: 7).map((q) => q.id).toList();
      final b = buildTest(s, count: 15, seed: 7).map((q) => q.id).toList();
      final c = buildTest(s, count: 15, seed: 8).map((q) => q.id).toList();
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('QuizResult', () {
    QuizResult resultWith(List<int?> answers) {
      final subject = QuizBank.subjects.first;
      final questions = buildTest(subject, count: answers.length, seed: 4);
      return QuizResult(
        subject: subject,
        questions: questions,
        answers: answers,
        duration: const Duration(minutes: 3),
      );
    }

    test('scores only exact matches', () {
      final subject = QuizBank.subjects.first;
      final questions = buildTest(subject, count: 4, seed: 5);
      final answers = <int?>[
        questions[0].answerIndex,
        (questions[1].answerIndex + 1) % 4,
        questions[2].answerIndex,
        null,
      ];
      final r = QuizResult(
        subject: subject,
        questions: questions,
        answers: answers,
        duration: Duration.zero,
      );
      expect(r.correct, 2);
      expect(r.skipped, 1);
      expect(r.isCorrect(0), isTrue);
      expect(r.isCorrect(1), isFalse);
      expect(r.isCorrect(3), isFalse);
    });

    test('all wrong is a 1,0 and all right is a 10,0', () {
      final subject = QuizBank.subjects.first;
      final questions = buildTest(subject, count: 10, seed: 6);
      final allRight = QuizResult(
        subject: subject,
        questions: questions,
        answers: [for (final q in questions) q.answerIndex],
        duration: Duration.zero,
      );
      final allWrong = QuizResult(
        subject: subject,
        questions: questions,
        answers: [for (final q in questions) (q.answerIndex + 1) % 4],
        duration: Duration.zero,
      );
      expect(allRight.mark, 10.0);
      expect(allRight.passed, isTrue);
      expect(allWrong.mark, 1.0);
      expect(allWrong.passed, isFalse);
    });

    test('byTopic totals add up to the number of questions', () {
      final r = resultWith(List<int?>.filled(20, 0));
      final total = r.byTopic.values.fold(0, (sum, e) => sum + e.total);
      expect(total, 20);
    });
  });
}

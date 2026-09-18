import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/school/logic/quiz_bank.dart';

void main() {
  test('all IEP items have explanations and valid open answers', () {
    for (final s in QuizBank.doorstroomSubjects) {
      for (final q in s.questions) {
        expect(q.id, startsWith('iep-'));
        expect(q.explanation, isNotEmpty, reason: q.id);
        if (q.isOpen) expect(q.accepts(q.answer), isTrue, reason: q.id);
        if (s.id == 'lezen') expect(q.passage, isNotEmpty);
        if (q.table != null) {
          for (final row in q.table!.rows) {
            expect(row.length, q.table!.headers.length);
          }
        }
      }
    }
  });
  test(
    'Dutch numeric answers accept equivalent notation, not units or malformed numbers',
    () {
      expect(parseQuizNumber('1.250,50'), 1250.5);
      expect(parseQuizNumber('1 250,50'), 1250.5);
      expect(parseQuizNumber(' 12,50 '), 12.5);
      expect(parseQuizNumber('12.5'), 12.5);
      for (final invalid in ['12 euro', '1,2,3', '1 2', '1.25,0', '2+3', '']) {
        expect(parseQuizNumber(invalid), isNull, reason: invalid);
      }
    },
  );
  test(
    'spelling accepts case and apostrophe style but never fixes misspellings',
    () {
      final q = QuizBank.byId(
        'taalverzorging',
      )!.questions.firstWhere((q) => q.expected == "foto's");
      expect(q.accepts(' FOTO’S '), isTrue);
      expect(q.accepts('fotos'), isFalse);
      final gap = QuizBank.byId(
        'taalverzorging',
      )!.questions.firstWhere((q) => q.id == 'iep-t-letters-0');
      expect(gap.accepts('p'), isTrue);
      expect(gap.accepts('paraplu'), isFalse);
    },
  );
  test('all scale and graph answers agree with the data in the question', () {
    final math = QuizBank.byId('rekenen')!.questions;
    final scale = math.where((q) => q.id.startsWith('iep-r-schaal-'));
    expect(scale, hasLength(12));
    for (final q in scale) {
      final distance = int.parse(
        RegExp(r'kaart (\d+) cm').firstMatch(q.prompt)![1]!,
      );
      expect(parseQuizNumber(q.answer), distance * 25000 / 100000);
      expect(q.options.map(parseQuizNumber).toSet().length, q.options.length);
    }
    for (final q in math.where((q) => q.bars != null)) {
      expect(parseQuizNumber(q.answer), q.bars!.values[2] - q.bars!.values[0]);
    }
    for (final q in math.where((q) => q.id.startsWith('iep-r-tabel-'))) {
      final total = q.table!.rows.fold(
        0,
        (sum, row) => sum + int.parse(row[1]),
      );
      expect(parseQuizNumber(q.answer), total);
    }
  });
  test('reading questions stay together by text for all offered lengths', () {
    for (final length in QuizBank.lengths) {
      final questions = buildTest(
        QuizBank.byId('lezen')!,
        count: length,
        seed: 42,
      );
      final seen = <String>{};
      String? previous;
      for (final q in questions) {
        if (q.passage != previous) expect(seen.add(q.passage!), isTrue);
        previous = q.passage;
      }
    }
  });
  test('open, multiple and skipped answers are scored independently', () {
    final subject = QuizBank.byId('lezen')!;
    final multi = subject.questions.last;
    final numeric = QuizBank.byId(
      'rekenen',
    )!.questions.firstWhere((q) => q.isOpen);
    QuizResult result(Set<int> selected, String input) => QuizResult(
      subject: subject,
      questions: [multi, numeric, numeric],
      answers: [null, null, null],
      duration: Duration.zero,
      typedAnswers: {1: input},
      multipleAnswers: {0: selected},
    );
    final correct = result(multi.correctIndices.toSet(), numeric.answer);
    expect(correct.correct, 2);
    expect(correct.skipped, 1);
    expect(correct.givenAnswer(1), numeric.answer);
    expect(result({0}, '0').correct, 0);
    expect(result({0, 1, 2}, numeric.answer).isCorrect(0), isFalse);
  });
}

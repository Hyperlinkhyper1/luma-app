import 'dart:math';
import 'quiz_bank.dart';

const maxQuizExportQuestions = 500;

Map<String, int> distributeQuizQuestions(
  List<QuizSubject> subjects,
  int total,
) {
  if (subjects.isEmpty) throw ArgumentError('Kies minstens één vak.');
  if (total < subjects.length || total > maxQuizExportQuestions) {
    throw ArgumentError(
      'Kies tussen ${subjects.length} en $maxQuizExportQuestions vragen.',
    );
  }
  if (subjects.fold(0, (sum, s) => sum + s.questions.length) < total) {
    throw ArgumentError(
      'Er zijn niet genoeg vragen beschikbaar voor deze vakken.',
    );
  }
  final counts = {for (final s in subjects) s.id: 0};
  var remaining = total;
  while (remaining > 0) {
    for (final s in subjects) {
      if (remaining == 0) break;
      if (counts[s.id]! < s.questions.length) {
        counts[s.id] = counts[s.id]! + 1;
        remaining--;
      }
    }
  }
  return counts;
}

class QuizExportBlock {
  const QuizExportBlock(this.subject, this.questions);
  final QuizSubject subject;
  final List<QuizQuestion> questions;
}

class QuizExport {
  const QuizExport({
    required this.title,
    required this.blocks,
    required this.mixed,
    required this.answers,
    required this.explanations,
    required this.writingSpace,
  });
  final String title;
  final List<QuizExportBlock> blocks;
  final bool mixed;
  final bool answers;
  final bool explanations;
  final bool writingSpace;
  int get count => blocks.fold(0, (sum, b) => sum + b.questions.length);
}

QuizExport prepareQuizExport({
  required Map<String, int> counts,
  String title = 'Oefentoets groep 8',
  bool mixed = false,
  bool answers = false,
  bool explanations = true,
  bool writingSpace = true,
  int? seed,
}) {
  if (counts.isEmpty) throw ArgumentError('Kies minstens één vak.');
  final total = counts.values.fold(0, (sum, n) => sum + n);
  if (total > maxQuizExportQuestions) {
    throw ArgumentError(
      'Kies maximaal $maxQuizExportQuestions vragen per PDF.',
    );
  }
  final random = Random(seed);
  final blocks = <QuizExportBlock>[];
  for (final entry in counts.entries) {
    final subject = QuizBank.byId(entry.key);
    if (subject == null ||
        entry.value < 1 ||
        entry.value > subject.questions.length) {
      throw ArgumentError(
        'Ongeldig aantal vragen voor ${subject?.name ?? entry.key}.',
      );
    }
    final questions = buildTest(
      subject,
      count: entry.value,
      seed: random.nextInt(1 << 30),
    );
    var group = <QuizQuestion>[];
    for (final q in questions) {
      if (group.isNotEmpty &&
          (q.passage == null || q.passage != group.last.passage)) {
        blocks.add(QuizExportBlock(subject, List.unmodifiable(group)));
        group = [];
      }
      group.add(q);
    }
    if (group.isNotEmpty) {
      blocks.add(QuizExportBlock(subject, List.unmodifiable(group)));
    }
  }
  if (mixed) blocks.shuffle(random);
  return QuizExport(
    title: title.trim().isEmpty ? 'Oefentoets groep 8' : title.trim(),
    blocks: List.unmodifiable(blocks),
    mixed: mixed,
    answers: answers,
    explanations: explanations,
    writingSpace: writingSpace,
  );
}

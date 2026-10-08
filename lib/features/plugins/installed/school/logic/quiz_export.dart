import 'dart:math';
import 'dart:ui' show Locale;

import '../../../../../l10n/app_localizations.dart';
import '../../../../../l10n/current_l.dart';
import 'quiz_bank.dart';

const maxQuizExportQuestions = 500;

/// The language the PDF is written in. The PDF uses a Latin standard font, so
/// Chinese falls back to English rather than printing boxes.
L _pdfL() => currentLocale.languageCode == 'zh'
    ? lookupL(const Locale('en'))
    : currentL;

Map<String, int> distributeQuizQuestions(
  List<QuizSubject> subjects,
  int total,
) {
  if (subjects.isEmpty) throw ArgumentError(currentL.schoolQuizPickSubject);
  if (total < subjects.length || total > maxQuizExportQuestions) {
    throw ArgumentError(
      currentL.schoolQuizChooseBetween(subjects.length, maxQuizExportQuestions),
    );
  }
  if (subjects.fold(0, (sum, s) => sum + s.questions.length) < total) {
    throw ArgumentError(currentL.schoolQuizNotEnoughQuestions);
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

/// Fixed text for the PDF, resolved on the main isolate because the renderer
/// runs in its own isolate. Templates keep `{tokens}` that the renderer fills.
class QuizPdfLabels {
  const QuizPdfLabels({
    required this.runningHeader,
    required this.questions,
    required this.answerSheet,
    required this.mixed,
    required this.perSubject,
    required this.questionTitle,
    required this.questionTitlePassage,
    required this.passageHeading,
    required this.pageOf,
    required this.nameDate,
    required this.instructions,
    required this.disclaimer,
    required this.answerBlank,
    required this.answers,
    required this.answersNote,
  });

  factory QuizPdfLabels.current() {
    final t = _pdfL();
    return QuizPdfLabels(
      runningHeader: t.schoolQuizPdfRunningHeader('{section}'),
      questions: t.schoolQuizPdfSectionQuestions,
      answerSheet: t.schoolQuizPdfSectionAnswerSheet,
      mixed: t.schoolQuizPdfMixed,
      perSubject: t.schoolQuizPdfPerSubject,
      questionTitle: t.schoolQuizPdfQuestionTitle('{number}', '{subject}'),
      questionTitlePassage: t.schoolQuizPdfQuestionTitlePassage(
        '{number}',
        '{subject}',
        '{passage}',
      ),
      passageHeading: t.schoolQuizPdfPassageHeading('{number}'),
      pageOf: t.schoolQuizPdfPageOf('{page}', '{total}'),
      nameDate: t.schoolQuizPdfNameDateLine,
      instructions: t.schoolQuizPdfInstructions,
      disclaimer: t.schoolQuizPdfDisclaimer,
      answerBlank: t.schoolQuizPdfAnswerBlank,
      answers: t.schoolQuizPdfAnswersHeading,
      answersNote: t.schoolQuizPdfAnswersNote,
    );
  }

  final String runningHeader;
  final String questions;
  final String answerSheet;
  final String mixed;
  final String perSubject;
  final String questionTitle;
  final String questionTitlePassage;
  final String passageHeading;
  final String pageOf;
  final String nameDate;
  final String instructions;
  final String disclaimer;
  final String answerBlank;
  final String answers;
  final String answersNote;
}

class QuizExport {
  const QuizExport({
    required this.title,
    required this.subtitle,
    required this.blocks,
    required this.mixed,
    required this.answers,
    required this.explanations,
    required this.writingSpace,
    required this.labels,
  });
  final String title;
  final String subtitle;
  final List<QuizExportBlock> blocks;
  final bool mixed;
  final bool answers;
  final bool explanations;
  final bool writingSpace;
  final QuizPdfLabels labels;
  int get count => blocks.fold(0, (sum, b) => sum + b.questions.length);
}

QuizExport prepareQuizExport({
  required Map<String, int> counts,
  String? title,
  bool mixed = false,
  bool answers = false,
  bool explanations = true,
  bool writingSpace = true,
  int? seed,
}) {
  if (counts.isEmpty) throw ArgumentError(currentL.schoolQuizPickSubject);
  final total = counts.values.fold(0, (sum, n) => sum + n);
  if (total > maxQuizExportQuestions) {
    throw ArgumentError(
      currentL.schoolQuizMaxQuestionsPerPdf(maxQuizExportQuestions),
    );
  }
  final labels = QuizPdfLabels.current();
  final random = Random(seed);
  final blocks = <QuizExportBlock>[];
  for (final entry in counts.entries) {
    final subject = QuizBank.byId(entry.key);
    if (subject == null ||
        entry.value < 1 ||
        entry.value > subject.questions.length) {
      throw ArgumentError(
        currentL.schoolQuizInvalidCount(subject?.name ?? entry.key),
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
  final trimmed = title?.trim() ?? '';
  return QuizExport(
    title: trimmed.isEmpty ? _pdfL().schoolQuizDefaultTitle : trimmed,
    subtitle: _pdfL().schoolQuizPdfCountLine(
      total,
      mixed ? labels.mixed : labels.perSubject,
    ),
    blocks: List.unmodifiable(blocks),
    mixed: mixed,
    answers: answers,
    explanations: explanations,
    writingSpace: writingSpace,
    labels: labels,
  );
}

import 'dart:math';
import 'quiz/iep_rekenen.dart';
import 'quiz/iep_taal.dart';
import 'quiz/iep_lezen.dart';

import 'package:flutter/material.dart';

import 'quiz/aardrijkskunde_extra.dart';
import 'quiz/aardrijkskunde_questions.dart';
import 'quiz/biologie_extra.dart';
import 'quiz/biologie_questions.dart';
import 'quiz/engels_extra.dart';
import 'quiz/engels_questions.dart';
import 'quiz/geschiedenis_extra.dart';
import 'quiz/geschiedenis_questions.dart';

enum QuizInput { choice, number, word, multiple }

@immutable
class QuizTable {
  const QuizTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

@immutable
class QuizBars {
  const QuizBars({
    required this.title,
    required this.labels,
    required this.values,
    required this.unit,
  });
  final String title;
  final List<String> labels;
  final List<int> values;
  final String unit;
}

/// One practice question in the practice-test bank.
///
/// Practice questions vary in difficulty; scores are not standardised.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.topic,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    this.explanation,
    this.passage,
    this.input = QuizInput.choice,
    this.expected,
    this.unit,
    this.correctIndices = const [],
    this.table,
    this.bars,
  });

  /// Stable identifier, unique across the whole bank.
  final String id;

  /// The subdomain inside the subject, e.g. 'Verhoudingen'. Tests are drawn
  /// evenly across topics so every generated test has the same make-up.
  final String topic;

  final String prompt;

  /// Answer options for closed questions; empty for open questions.
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int answerIndex;

  /// Short reason the answer is right, shown in the review afterwards.
  final String? explanation;

  /// A reading fragment the question belongs to, shown above the prompt.
  final String? passage;

  final QuizInput input;
  final String? expected;
  final String? unit;
  final List<int> correctIndices;
  final QuizTable? table;
  final QuizBars? bars;

  bool get isOpen => input == QuizInput.number || input == QuizInput.word;

  bool accepts(String raw) {
    if (!isOpen || raw.trim().isEmpty) return false;
    if (input == QuizInput.word) {
      String normalise(String text) =>
          text.trim().toLowerCase().replaceAll('’', "'").replaceAll('‘', "'");
      return normalise(raw) == normalise(expected!);
    }
    return parseQuizNumber(raw) != null &&
        parseQuizNumber(raw) == parseQuizNumber(expected!);
  }

  String get answer => isOpen
      ? expected!
      : input == QuizInput.multiple
      ? correctIndices.map((i) => options[i]).join(' · ')
      : options[answerIndex];
}

/// Dutch numeric input: comma decimals, optional grouped thousands or a
/// decimal point. Units and expressions are deliberately not accepted.
double? parseQuizNumber(String raw) {
  var text = raw.trim().replaceAll('−', '-');
  if (!RegExp(r'^-?[0-9][0-9., ]*$').hasMatch(text)) return null;
  if (text.contains(' ')) {
    if (!RegExp(r'^-?\d{1,3}( \d{3})+([,.]\d+)?$').hasMatch(text)) return null;
    text = text.replaceAll(' ', '');
  }
  if (text.contains(',')) {
    if (!RegExp(r'^-?(\d+|\d{1,3}(\.\d{3})+),\d+$').hasMatch(text)) return null;
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    text = text.replaceAll('.', '');
  }
  return double.tryParse(text);
}

/// A subject the student can be tested on.
class QuizSubject {
  QuizSubject({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.blurb,
    required this.build,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// One line describing what the subject covers, shown on the subject card.
  final String blurb;

  /// Assembles the pool. Called once, lazily, by [questions].
  final List<QuizQuestion> Function() build;

  bool get isDoorstroom =>
      const {'rekenen', 'lezen', 'taalverzorging'}.contains(id);

  /// The subject's whole question pool.
  ///
  /// Built on first use and then kept: most of the pool is assembled from data
  /// tables and templates (see `logic/quiz/gen.dart`), which costs a few
  /// milliseconds once instead of tens of thousands of hand-typed lines in the
  /// binary. Generation is seeded, so the pool is the same on every launch.
  late final List<QuizQuestion> questions = build();

  /// The subdomains present in this subject, in the order they first appear.
  List<String> get topics {
    final seen = <String>[];
    for (final q in questions) {
      if (!seen.contains(q.topic)) seen.add(q.topic);
    }
    return seen;
  }
}

/// The built-in practice-test bank.
///
/// The bank ships with the app: no database table, no download, no network.
/// Each subject is a hand-written file (`logic/quiz/<vak>_questions.dart`) plus
/// a generated one (`logic/quiz/<vak>_extra.dart`) that expands compact data
/// tables into the bulk of the pool. Adding questions means adding rows to a
/// table or a hand-written entry — nothing else has to change.
abstract final class QuizBank {
  /// Intended audience, not a calibrated reference-level assessment.
  static const level = 'Groep 8 · oefenen voor IEP';

  static final List<QuizSubject> subjects = [
    QuizSubject(
      id: 'rekenen',
      name: 'Rekenen',
      icon: Icons.calculate_rounded,
      color: const Color(0xFF7C5AD9),
      blurb: 'Getallen, verhoudingen, meten & meetkunde, verbanden',
      build: buildIepRekenen,
    ),
    QuizSubject(
      id: 'taalverzorging',
      name: 'Taalverzorging',
      icon: Icons.spellcheck_rounded,
      color: const Color(0xFF2E9E7B),
      blurb: 'Spelling, werkwoordspelling en leestekens',
      build: buildIepTaal,
    ),
    QuizSubject(
      id: 'lezen',
      name: 'Begrijpend lezen',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFFD9843B),
      blurb: 'Teksten begrijpen, samenvatten, woordbetekenis en opzoeken',
      build: buildIepLezen,
    ),
    QuizSubject(
      id: 'engels',
      name: 'Engels',
      icon: Icons.translate_rounded,
      color: const Color(0xFF3B7FD9),
      blurb: 'Extra oefening · Engels voor bovenbouw en brugklas',
      build: () => [...engelsQuestions, ...buildEngelsExtra()],
    ),
    QuizSubject(
      id: 'aardrijkskunde',
      name: 'Aardrijkskunde',
      icon: Icons.public_rounded,
      color: const Color(0xFF1FA5A5),
      blurb: 'Extra oefening · Nederland, Europa, de wereld en het weer',
      build: () => [...aardrijkskundeQuestions, ...buildAardrijkskundeExtra()],
    ),
    QuizSubject(
      id: 'geschiedenis',
      name: 'Geschiedenis',
      icon: Icons.history_edu_rounded,
      color: const Color(0xFFB4574B),
      blurb: 'Extra oefening · De tien tijdvakken, van jagers tot nu',
      build: () => [...geschiedenisQuestions, ...buildGeschiedenisExtra()],
    ),
    QuizSubject(
      id: 'biologie',
      name: 'Natuur & techniek',
      icon: Icons.science_rounded,
      color: const Color(0xFF5FA83C),
      blurb: 'Extra oefening · Lichaam, natuur, energie en techniek',
      build: () => [...biologieQuestions, ...buildBiologieExtra()],
    ),
  ];

  static QuizSubject? byId(String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  static int get totalQuestions =>
      subjects.fold(0, (sum, s) => sum + s.questions.length);

  static List<QuizSubject> get doorstroomSubjects =>
      subjects.where((s) => s.isDoorstroom).toList();
  static List<QuizSubject> get extraSubjects =>
      subjects.where((s) => !s.isDoorstroom).toList();

  /// The test lengths offered in the UI.
  static const lengths = [10, 20, 30, 50];
}

/// Draws a test of [count] questions from [subject].
///
/// Questions are taken round-robin across the subject's topics, so a
/// twenty-question rekentoets always covers all four rekendomeinen in roughly
/// equal measure rather than landing on twenty breukensommen by chance. That
/// spread covers the topics; it does not guarantee equal difficulty.
///
/// Pass a [seed] to get a reproducible draw (used by the tests).
List<QuizQuestion> buildTest(
  QuizSubject subject, {
  required int count,
  int? seed,
}) {
  final random = Random(seed);
  final pools = <String, List<QuizQuestion>>{};
  var source = subject.questions;
  if (subject.id == 'lezen') {
    final passages = source.map((q) => q.passage).toSet().toList()
      ..shuffle(random);
    final selected = passages.take((count / 8).ceil()).toSet();
    source = source.where((q) => selected.contains(q.passage)).toList();
  }
  for (final q in source) {
    pools.putIfAbsent(q.topic, () => []).add(q);
  }
  for (final pool in pools.values) {
    pool.shuffle(random);
  }

  final topics = pools.keys.toList()..shuffle(random);
  final drawn = <QuizQuestion>[];
  final wanted = min(count, subject.questions.length);
  var round = 0;
  while (drawn.length < wanted) {
    var addedThisRound = false;
    for (final topic in topics) {
      if (drawn.length >= wanted) break;
      final pool = pools[topic]!;
      if (round < pool.length) {
        drawn.add(pool[round]);
        addedThisRound = true;
      }
    }
    if (!addedThisRound) break;
    round++;
  }

  drawn.shuffle(random);
  if (subject.id == 'lezen') {
    final grouped = <String, List<QuizQuestion>>{};
    for (final q in drawn) {
      grouped.putIfAbsent(q.passage ?? q.id, () => []).add(q);
    }
    final order = {
      for (var i = 0; i < subject.questions.length; i++)
        subject.questions[i].id: i,
    };
    return [
      for (final group in grouped.values)
        ...group..sort((a, b) => order[a.id]!.compareTo(order[b.id]!)),
    ];
  }
  return drawn;
}

/// A finished attempt: the questions that were asked and what was answered.
@immutable
class QuizResult {
  const QuizResult({
    required this.subject,
    required this.questions,
    required this.answers,
    required this.duration,
    this.typedAnswers = const {},
    this.multipleAnswers = const {},
  });

  final QuizSubject subject;
  final List<QuizQuestion> questions;

  /// Chosen option index per question, `null` where the question was skipped.
  final List<int?> answers;

  final Duration duration;

  final Map<int, String> typedAnswers;
  final Map<int, Set<int>> multipleAnswers;

  bool isAnswered(int i) => questions[i].isOpen
      ? (typedAnswers[i]?.trim().isNotEmpty ?? false)
      : questions[i].input == QuizInput.multiple
      ? (multipleAnswers[i]?.isNotEmpty ?? false)
      : answers[i] != null;

  bool isCorrect(int i) {
    final q = questions[i];
    if (q.isOpen) return q.accepts(typedAnswers[i] ?? '');
    if (q.input == QuizInput.multiple) {
      final selected = multipleAnswers[i] ?? const <int>{};
      return selected.length == q.correctIndices.length &&
          selected.containsAll(q.correctIndices);
    }
    return answers[i] == q.answerIndex;
  }

  String givenAnswer(int i) {
    final q = questions[i];
    if (!isAnswered(i)) return '';
    if (q.isOpen) return typedAnswers[i]!;
    if (q.input == QuizInput.multiple) {
      return (multipleAnswers[i]!.toList()..sort())
          .map((n) => q.options[n])
          .join(' · ');
    }
    return q.options[answers[i]!];
  }

  int get correct {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      if (isCorrect(i)) n++;
    }
    return n;
  }

  int get skipped => [
    for (var i = 0; i < questions.length; i++)
      if (!isAnswered(i)) i,
  ].length;

  double get fraction => questions.isEmpty ? 0 : correct / questions.length;

  /// The Dutch 1–10 mark for this attempt, rounded to one decimal.
  double get mark {
    final raw = 1 + fraction * 9;
    return (raw * 10).round() / 10;
  }

  bool get passed => mark >= 5.5;

  /// Correct-count per topic, for the breakdown on the result screen.
  Map<String, ({int correct, int total})> get byTopic {
    final out = <String, ({int correct, int total})>{};
    for (var i = 0; i < questions.length; i++) {
      final topic = questions[i].topic;
      final prev = out[topic] ?? (correct: 0, total: 0);
      out[topic] = (
        correct: prev.correct + (isCorrect(i) ? 1 : 0),
        total: prev.total + 1,
      );
    }
    return out;
  }
}

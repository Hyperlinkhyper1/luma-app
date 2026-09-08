import 'dart:math';

import 'package:flutter/material.dart';

import 'quiz/aardrijkskunde_extra.dart';
import 'quiz/aardrijkskunde_questions.dart';
import 'quiz/biologie_extra.dart';
import 'quiz/biologie_questions.dart';
import 'quiz/engels_extra.dart';
import 'quiz/engels_questions.dart';
import 'quiz/geschiedenis_extra.dart';
import 'quiz/geschiedenis_questions.dart';
import 'quiz/lezen_extra.dart';
import 'quiz/lezen_questions.dart';
import 'quiz/rekenen_extra.dart';
import 'quiz/rekenen_questions.dart';
import 'quiz/taalverzorging_extra.dart';
import 'quiz/taalverzorging_questions.dart';

/// One multiple-choice question in the practice-test bank.
///
/// Every question in the bank is authored at the same level — see
/// [QuizBank.level] — so a test drawn from one subject is comparable to a test
/// drawn from any other.
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
  });

  /// Stable identifier, unique across the whole bank.
  final String id;

  /// The subdomain inside the subject, e.g. 'Verhoudingen'. Tests are drawn
  /// evenly across topics so every generated test has the same make-up.
  final String topic;

  final String prompt;

  /// Always four answer options.
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int answerIndex;

  /// Short reason the answer is right, shown in the review afterwards.
  final String? explanation;

  /// A reading fragment the question belongs to, shown above the prompt.
  final String? passage;

  String get answer => options[answerIndex];
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
  /// The single difficulty every question is written to.
  ///
  /// This is the invariant that makes "the same test for every subject" mean
  /// something: a question only belongs in the bank if it sits at the end of
  /// groep 8 / start of the brugklas — the doorstroomtoets level. Anything
  /// easier or harder does not go in.
  static const level = 'Groep 8 · doorstroomtoets-niveau';

  static final List<QuizSubject> subjects = [
    QuizSubject(
      id: 'rekenen',
      name: 'Rekenen',
      icon: Icons.calculate_rounded,
      color: const Color(0xFF7C5AD9),
      blurb: 'Getallen, verhoudingen, meten & meetkunde, verbanden',
      build: () => [...rekenenQuestions, ...buildRekenenExtra()],
    ),
    QuizSubject(
      id: 'taalverzorging',
      name: 'Taalverzorging',
      icon: Icons.spellcheck_rounded,
      color: const Color(0xFF2E9E7B),
      blurb: 'Spelling, werkwoordspelling en leestekens',
      build: () => [...taalverzorgingQuestions, ...buildTaalverzorgingExtra()],
    ),
    QuizSubject(
      id: 'lezen',
      name: 'Begrijpend lezen',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFFD9843B),
      blurb: 'Teksten begrijpen, samenvatten, woordbetekenis en opzoeken',
      build: () => [...lezenQuestions, ...buildLezenExtra()],
    ),
    QuizSubject(
      id: 'engels',
      name: 'Engels',
      icon: Icons.translate_rounded,
      color: const Color(0xFF3B7FD9),
      blurb: 'Woordenschat, grammatica en werkwoordstijden',
      build: () => [...engelsQuestions, ...buildEngelsExtra()],
    ),
    QuizSubject(
      id: 'aardrijkskunde',
      name: 'Aardrijkskunde',
      icon: Icons.public_rounded,
      color: const Color(0xFF1FA5A5),
      blurb: 'Nederland, Europa, de wereld en het weer',
      build: () => [...aardrijkskundeQuestions, ...buildAardrijkskundeExtra()],
    ),
    QuizSubject(
      id: 'geschiedenis',
      name: 'Geschiedenis',
      icon: Icons.history_edu_rounded,
      color: const Color(0xFFB4574B),
      blurb: 'De tien tijdvakken, van jagers tot nu',
      build: () => [...geschiedenisQuestions, ...buildGeschiedenisExtra()],
    ),
    QuizSubject(
      id: 'biologie',
      name: 'Natuur & techniek',
      icon: Icons.science_rounded,
      color: const Color(0xFF5FA83C),
      blurb: 'Het lichaam, planten, dieren, energie en techniek',
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

  /// The test lengths offered in the UI.
  static const lengths = [10, 20, 30, 50];
}

/// Draws a test of [count] questions from [subject].
///
/// Questions are taken round-robin across the subject's topics, so a
/// twenty-question rekentoets always covers all four rekendomeinen in roughly
/// equal measure rather than landing on twenty breukensommen by chance. That
/// even spread — plus the single authoring level — is what keeps two tests of
/// the same length comparable, whichever subject they come from.
///
/// Pass a [seed] to get a reproducible draw (used by the tests).
List<QuizQuestion> buildTest(
  QuizSubject subject, {
  required int count,
  int? seed,
}) {
  final random = Random(seed);
  final pools = <String, List<QuizQuestion>>{};
  for (final q in subject.questions) {
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
  });

  final QuizSubject subject;
  final List<QuizQuestion> questions;

  /// Chosen option index per question, `null` where the question was skipped.
  final List<int?> answers;

  final Duration duration;

  bool isCorrect(int i) => answers[i] == questions[i].answerIndex;

  int get correct {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      if (isCorrect(i)) n++;
    }
    return n;
  }

  int get skipped => answers.where((a) => a == null).length;

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

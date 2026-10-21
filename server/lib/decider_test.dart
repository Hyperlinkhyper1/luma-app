import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'util.dart';

part 'decider_test_suite.dart';

/// The decider test: a moderation suite for decision models (Perplexity's
/// Decider and the other models OpenRouter lists with "decisions" output),
/// scored against the operator's expected answers and plotted cost against
/// accuracy on the admin dashboard.
///
/// Decision models don't write text. A request carries `state` (here the
/// policy, the context and the post) and named `questions`; the reply holds
/// a probability per answer. So nothing is parsed out of prose and the model
/// never grades itself:
///
///  * `choice` — right when the top option is the expected one.
///  * `noul` (yes/no) — right when the probability of yes lands on the
///    expected side of 0.5.
///  * `score` (ordered levels) — right when the expected score is within
///    half a level of the expected one.
///
/// A case with several questions only counts when every one is right, so a
/// four-question checklist has a one-in-sixteen chance of a lucky guess.

const kDeciderTestMaxCases = 400;

const kDeciderTestMaxSuiteChars = 600000;

/// Runs kept on disk; the oldest go first.
const kDeciderTestMaxRuns = 120;

/// The question types the decisions API answers.
const kDeciderQuestionTypes = ['choice', 'noul', 'score'];

/// The instructions a case gets when it only names the expected action.
const kDeciderDefaultInstructions =
    'Apply the POLICY exactly as written to the CONTENT, using the facts in '
    'CONTEXT. Which single action does the policy require?';

/// Models that answer yes/no questions only: Respan's span-01 family
/// refuses `choice` and `score` questions, and wants plain-string
/// instructions and criteria on the yes/no ones.
bool deciderNoulOnly(String model) => model.startsWith('respan/span-01');

/// How many failed cases, before any was answered, stop a run: the model is
/// refusing the request itself, so the rest would fail the same way.
const kDeciderEarlyFailures = 5;

/// Where a run sends its requests. OpenRouter serves every decisions model
/// on its alpha endpoint; Perplexity serves its own Decider models.
enum DeciderProvider {
  openrouter('OpenRouter', 'https://openrouter.ai/api/alpha/decisions'),
  perplexity('Perplexity', 'https://api.perplexity.ai/v1/decisions');

  const DeciderProvider(this.label, this.endpoint);

  final String label;
  final String endpoint;

  static DeciderProvider? parse(Object? raw) {
    for (final p in values) {
      if (p.name == raw) return p;
    }
    return null;
  }

  /// Perplexity takes its own model names; OpenRouter's `perplexity/` prefix
  /// is accepted there too, but the bare name is the documented one.
  String modelFor(String model) =>
      this == perplexity && model.startsWith('perplexity/')
          ? model.substring('perplexity/'.length)
          : model;
}

final _pastedKeyPattern = RegExp(r'^[A-Za-z0-9_\-.]{16,300}$');

/// Why [key] can't be right for [provider], or null.
String? deciderKeyProblem(DeciderProvider provider, String key) {
  if (!_pastedKeyPattern.hasMatch(key)) {
    return 'That API key does not look right — paste it without spaces.';
  }
  if (provider == DeciderProvider.openrouter && !key.startsWith('sk-or-')) {
    return 'That is not an OpenRouter key — they start with "sk-or-". '
        'Did the browser fill in a saved password?';
  }
  if (provider == DeciderProvider.perplexity && !key.startsWith('pplx-')) {
    return 'That is not a Perplexity key — they start with "pplx-".';
  }
  return null;
}

/// Enough of [key] to recognise it, never enough to use it.
String deciderKeyHint(String key) {
  final dash = key.lastIndexOf('-', math.min(key.length - 1, 12));
  final head = dash > 0 ? key.substring(0, dash + 1) : key.substring(0, 3);
  return '$head…${key.substring(key.length - 4)}';
}

String _str(Object? raw) => raw is String ? raw.trim() : '';

/// A short fingerprint of a suite's text (FNV-1a, 32 bit), so runs made on
/// an older or edited suite can be told apart from current ones.
String deciderSuiteHash(String text) {
  var h = 0x811c9dc5;
  for (final unit in utf8.encode(text)) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// One rulebook the cases point at.
class DeciderPolicy {
  const DeciderPolicy(
      {required this.id,
      required this.title,
      required this.rules,
      required this.actions});

  final String id;
  final String title;
  final String rules;

  /// Action name → what it means; the default question's options.
  final Map<String, String> actions;
}

/// One named question of a case, with the answer that counts as right.
class DeciderQuestion {
  const DeciderQuestion({
    required this.name,
    required this.type,
    required this.instructions,
    required this.criteria,
    required this.expect,
  });

  final String name;

  /// `choice`, `noul` or `score`.
  final String type;
  final String instructions;

  /// Option name → description for `choice`; the ordered levels for
  /// `score`; null for `noul`.
  final Object? criteria;

  /// The option name, `true`/`false`, or the level index.
  final Object expect;

  int get optionCount => switch (type) {
        'choice' => (criteria as Map).length,
        'score' => (criteria as List).length,
        _ => 2,
      };

  Map<String, dynamic> toRequest() => {
        'type': type,
        'instructions': instructions,
        if (criteria != null) 'criteria': criteria,
      };

  /// The yes/no questions standing in for this one on a model that takes
  /// nothing else: one per option or level, each asking whether that
  /// option is the answer, with plain-string instructions and criteria.
  Map<String, Map<String, dynamic>> toNoulRequests() => switch (type) {
        'choice' => {
            for (final e in (criteria as Map).entries)
              '${name}__${e.key}': _noul(
                  '$instructions\n\nIs "${e.key}" the action that applies? '
                      'Answer yes only for this one action.',
                  '${e.key}: ${e.value}'),
          },
        'score' => {
            for (var i = 0; i < (criteria as List).length; i++)
              '${name}__$i': _noul(
                  '$instructions\n\nIs level $i the one that applies? '
                      'Answer yes only for this one level.',
                  'Level $i: ${(criteria as List)[i]}'),
          },
        _ => {
            name: _noul(
                instructions,
                'Answer yes when the question above is true for the content, '
                'no when it is false.'),
          },
      };

  static Map<String, dynamic> _noul(String instructions, String criteria) =>
      {'type': 'noul', 'instructions': instructions, 'criteria': criteria};

  /// This question's answer rebuilt from the yes/no [answers] of
  /// [toNoulRequests]; null when the model left any of them out.
  Map<String, dynamic>? foldNoulAnswer(Map answers) {
    double? p(String key) {
      final a = answers[key];
      final v = a is Map ? _num(a['noul']) : double.nan;
      return v.isNaN ? null : v;
    }

    if (type == 'noul') {
      final v = p(name);
      return v == null ? null : {'noul': v};
    }
    final keys = type == 'choice'
        ? [for (final k in (criteria as Map).keys) '$k']
        : [for (var i = 0; i < (criteria as List).length; i++) '$i'];
    final ps = <double>[];
    for (final k in keys) {
      final v = p('${name}__$k');
      if (v == null) return null;
      ps.add(v);
    }
    final total = ps.fold(0.0, (s, v) => s + v);
    var best = 0;
    for (var i = 1; i < ps.length; i++) {
      if (ps[i] > ps[best]) best = i;
    }
    final probs = {
      for (var i = 0; i < ps.length; i++)
        keys[i]: total <= 0 ? 1 / ps.length : ps[i] / total,
    };
    return type == 'choice'
        ? {'choice': keys[best], 'probabilities': probs}
        : {'score': best, 'probabilities': probs};
  }

  String get expectedLabel => switch (type) {
        'noul' => expect == true ? 'yes' : 'no',
        'score' => 'level $expect',
        _ => '$expect',
      };
}

/// One case: a post under one policy and the questions asked about it.
class DeciderCase {
  const DeciderCase({
    required this.id,
    required this.policy,
    required this.skill,
    required this.context,
    required this.content,
    required this.questions,
    this.why = '',
  });

  final String id;
  final DeciderPolicy policy;

  /// What the case tests (dates, arithmetic, precedence…), for the
  /// per-skill breakdown.
  final String skill;
  final Object? context;
  final String content;
  final List<DeciderQuestion> questions;

  /// The worked answer, shown next to a wrong one in a run's details.
  final String why;

  /// The odds of getting the whole case right by guessing.
  double get chance =>
      questions.fold(1.0, (p, q) => p / math.max(1, q.optionCount));

  String get expectedLabel => questions.length == 1
      ? questions.single.expectedLabel
      : questions.map((q) => '${q.name}: ${q.expectedLabel}').join(', ');

  /// The decisions API body for [model]. The state is one plain text, the
  /// one shape every decisions model takes: Respan's accept only a string
  /// or their own chat transcript, not an arbitrary object. A yes/no-only
  /// model gets every question split into yes/no ones.
  Map<String, dynamic> request(String model) => {
        'model': model,
        'state': stateText,
        'questions': deciderNoulOnly(model)
            ? {for (final q in questions) ...q.toNoulRequests()}
            : {for (final q in questions) q.name: q.toRequest()},
      };

  /// Folds the reply of a yes/no-only model back into one answer per
  /// question, the shape [scoreDeciderAnswer] reads.
  Map foldNoulAnswers(Map answers) => {
        for (final q in questions)
          if (q.foldNoulAnswer(answers) case final a?) q.name: a,
      };

  String get stateText {
    final facts =
        const JsonEncoder.withIndent('  ').convert(context ?? const {});
    return 'POLICY\n${policy.title}\n${policy.rules}\n\n'
        'CONTEXT\n$facts\n\nCONTENT\n$content';
  }
}

/// The operator's suite: the policies and the cases.
class DeciderSuite {
  const DeciderSuite(this.policies, this.cases);

  final Map<String, DeciderPolicy> policies;
  final List<DeciderCase> cases;

  /// What a model guessing at random would score, 0 to 100.
  double get chancePercent => cases.isEmpty
      ? 0
      : cases.fold(0.0, (s, c) => s + c.chance) / cases.length * 100;

  /// Reads a suite from its JSON text. Throws a [FormatException] naming
  /// the first thing that is wrong, so the dashboard can show it.
  static DeciderSuite parse(String text) {
    if (text.length > kDeciderTestMaxSuiteChars) {
      throw const FormatException('The suite is too long.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('Not valid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException(
          'The suite must be an object with "policies" and "cases".');
    }
    final rawPolicies = decoded['policies'];
    if (rawPolicies is! Map || rawPolicies.isEmpty) {
      throw const FormatException('Add at least one policy.');
    }
    final policies = <String, DeciderPolicy>{};
    rawPolicies.forEach((key, raw) {
      final id = '$key';
      if (raw is! Map) throw FormatException('Policy "$id" must be an object.');
      final rules = _str(raw['rules']);
      if (rules.isEmpty) throw FormatException('Policy "$id" has no rules.');
      final actions = <String, String>{};
      if (raw['actions'] case final Map a) {
        a.forEach((k, v) => actions['$k'] = v is String ? v : '');
      }
      policies[id] = DeciderPolicy(
          id: id,
          title: _str(raw['title']).isEmpty ? id : _str(raw['title']),
          rules: rules,
          actions: actions);
    });

    final rawCases = decoded['cases'];
    if (rawCases is! List || rawCases.isEmpty) {
      throw const FormatException('Add at least one case.');
    }
    if (rawCases.length > kDeciderTestMaxCases) {
      throw const FormatException(
          'Too many cases — at most $kDeciderTestMaxCases.');
    }
    final ids = <String>{};
    final cases = <DeciderCase>[];
    for (var i = 0; i < rawCases.length; i++) {
      final raw = rawCases[i];
      final label = raw is Map && _str(raw['id']).isNotEmpty
          ? 'Case "${_str(raw['id'])}"'
          : 'Case ${i + 1}';
      if (raw is! Map) throw FormatException('$label must be an object.');
      final id = _str(raw['id']);
      if (id.isEmpty) throw FormatException('$label has no id.');
      if (!ids.add(id)) throw FormatException('$label: the id is used twice.');
      final policy = policies[_str(raw['policy'])];
      if (policy == null) {
        throw FormatException('$label names a policy that does not exist.');
      }
      final content = _str(raw['content']);
      if (content.isEmpty) throw FormatException('$label has no content.');
      cases.add(DeciderCase(
        id: id,
        policy: policy,
        skill: _str(raw['skill']).isEmpty ? 'other' : _str(raw['skill']),
        context: raw['context'],
        content: content,
        questions: _questionsOf(raw, policy, label),
        why: _str(raw['why']),
      ));
    }
    return DeciderSuite(policies, cases);
  }

  static List<DeciderQuestion> _questionsOf(
      Map raw, DeciderPolicy policy, String label) {
    final rawQuestions = raw['questions'];
    if (rawQuestions == null) {
      final expect = _str(raw['expect']);
      if (policy.actions.isEmpty) {
        throw FormatException(
            '$label: its policy has no actions, so it needs "questions".');
      }
      if (!policy.actions.containsKey(expect)) {
        throw FormatException(
            '$label: "expect" must be one of the policy\'s actions.');
      }
      return [
        DeciderQuestion(
          name: 'action',
          type: 'choice',
          instructions: _str(raw['instructions']).isEmpty
              ? kDeciderDefaultInstructions
              : _str(raw['instructions']),
          criteria: policy.actions,
          expect: expect,
        )
      ];
    }
    if (rawQuestions is! Map || rawQuestions.isEmpty) {
      throw FormatException('$label: "questions" must be a non-empty object.');
    }
    final expects = raw['expect'];
    if (expects is! Map) {
      throw FormatException(
          '$label: "expect" must give an answer per question.');
    }
    final out = <DeciderQuestion>[];
    rawQuestions.forEach((key, q) {
      final name = '$key';
      final where = '$label, question "$name"';
      if (q is! Map) throw FormatException('$where must be an object.');
      final type = _str(q['type']);
      if (!kDeciderQuestionTypes.contains(type)) {
        throw FormatException('$where: type must be choice, noul or score.');
      }
      final instructions = _str(q['instructions']);
      if (instructions.isEmpty) {
        throw FormatException('$where has no instructions.');
      }
      final expect = expects[name];
      Object? criteria = q['criteria'];
      switch (type) {
        case 'choice':
          if (criteria == null && policy.actions.isNotEmpty) {
            criteria = policy.actions;
          }
          if (criteria is! Map || criteria.isEmpty || criteria.length > 255) {
            throw FormatException('$where needs 1 to 255 criteria.');
          }
          if (expect is! String || !criteria.containsKey(expect)) {
            throw FormatException('$where: expect one of its criteria.');
          }
        case 'score':
          if (criteria is! List ||
              criteria.length < 2 ||
              criteria.length > 10) {
            throw FormatException('$where needs 2 to 10 levels.');
          }
          if (expect is! int || expect < 0 || expect >= criteria.length) {
            throw FormatException('$where: expect a level index.');
          }
        default:
          criteria = null;
          if (expect is! bool) {
            throw FormatException('$where: expect true or false.');
          }
      }
      out.add(DeciderQuestion(
          name: name,
          type: type,
          instructions: instructions,
          criteria: criteria,
          expect: expect));
    });
    return out;
  }
}

/// How one question went.
class DeciderAnswer {
  const DeciderAnswer(this.right, this.pTrue, this.got);

  final bool right;

  /// The probability the model put on the right answer.
  final double pTrue;

  /// What the model answered, for the run's detail table.
  final String got;
}

double _num(Object? v) => v is num ? v.toDouble() : double.nan;

/// Scores [answer] (one entry of the reply's `answers`) against [q]. A
/// missing or malformed answer counts as wrong.
DeciderAnswer scoreDeciderAnswer(DeciderQuestion q, Object? answer) {
  if (answer is! Map) return const DeciderAnswer(false, 0, 'no answer');
  final probs = answer['probabilities'];
  switch (q.type) {
    case 'noul':
      final p = _num(answer['noul']);
      if (p.isNaN) return const DeciderAnswer(false, 0, 'no answer');
      final yes = p >= 0.5;
      return DeciderAnswer(yes == q.expect, q.expect == true ? p : 1 - p,
          '${yes ? 'yes' : 'no'} (${(p * 100).round()}%)');
    case 'score':
      final s = _num(answer['score']);
      if (s.isNaN) return const DeciderAnswer(false, 0, 'no answer');
      final p = probs is Map ? _num(probs['${q.expect}']) : double.nan;
      return DeciderAnswer((s - (q.expect as int)).abs() < 0.5, p.isNaN ? 0 : p,
          'level ${s.toStringAsFixed(2)}');
    default:
      final choice = answer['choice'];
      if (choice is! String) return const DeciderAnswer(false, 0, 'no answer');
      var p = probs is Map ? _num(probs[q.expect]) : double.nan;
      if (p.isNaN) p = choice == q.expect ? _num(answer['confidence']) : 0;
      final top = probs is Map ? _num(probs[choice]) : double.nan;
      return DeciderAnswer(choice == q.expect, p.isNaN ? 0 : p,
          top.isNaN ? choice : '$choice (${(top * 100).round()}%)');
  }
}

/// One case's result in a run.
class DeciderCaseResult {
  const DeciderCaseResult({
    required this.id,
    required this.skill,
    required this.policy,
    required this.right,
    required this.pTrue,
    required this.expected,
    required this.got,
    required this.ms,
    this.inputTokens = 0,
    this.costUsd = 0,
    this.error,
    this.why = '',
  });

  final String id;
  final String skill;
  final String policy;
  final bool right;
  final double pTrue;
  final String expected;
  final String got;
  final int ms;
  final int inputTokens;
  final double costUsd;
  final String? error;
  final String why;

  Map<String, dynamic> toJson() => {
        'id': id,
        'skill': skill,
        'policy': policy,
        'right': right,
        'pTrue': double.parse(pTrue.toStringAsFixed(4)),
        'expected': expected,
        'got': got,
        'ms': ms,
        'inputTokens': inputTokens,
        'costUsd': costUsd,
        if (error != null) 'error': error,
        if (why.isNotEmpty) 'why': why,
      };

  static DeciderCaseResult? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    return DeciderCaseResult(
      id: raw['id'] as String,
      skill: _str(raw['skill']),
      policy: _str(raw['policy']),
      right: raw['right'] == true,
      pTrue: (raw['pTrue'] as num?)?.toDouble() ?? 0,
      expected: _str(raw['expected']),
      got: _str(raw['got']),
      ms: (raw['ms'] as num?)?.toInt() ?? 0,
      inputTokens: (raw['inputTokens'] as num?)?.toInt() ?? 0,
      costUsd: (raw['costUsd'] as num?)?.toDouble() ?? 0,
      error: raw['error'] is String ? raw['error'] as String : null,
      why: _str(raw['why']),
    );
  }
}

/// What one decisions call came back with.
class DeciderReply {
  const DeciderReply({
    this.answers,
    this.inputTokens = 0,
    this.costUsd,
    this.error,
    this.fatal = false,
  });

  /// The reply's `answers` object.
  final Map? answers;
  final int inputTokens;

  /// The provider's own figure, when it sends one (OpenRouter does).
  final double? costUsd;
  final String? error;

  /// The provider refused the key or the account is out of credit; the
  /// run stops.
  final bool fatal;
}

typedef DeciderCall = Future<DeciderReply> Function(Map<String, dynamic> body);

/// Runs [c] through [call] and scores it. [pricePerMInput] prices the call
/// when the provider sends no cost of its own.
Future<DeciderCaseResult> attemptDeciderCase(
    DeciderCase c, String model, DeciderCall call,
    {double? pricePerMInput}) async {
  final watch = Stopwatch()..start();
  final reply = await call(c.request(model));
  final ms = watch.elapsedMilliseconds;
  final cost = reply.costUsd ??
      (pricePerMInput == null ? 0.0 : reply.inputTokens * pricePerMInput / 1e6);
  final answers = reply.answers == null || !deciderNoulOnly(model)
      ? reply.answers
      : c.foldNoulAnswers(reply.answers!);
  if (answers == null) {
    return DeciderCaseResult(
        id: c.id,
        skill: c.skill,
        policy: c.policy.id,
        right: false,
        pTrue: 0,
        expected: c.expectedLabel,
        got: '',
        ms: ms,
        inputTokens: reply.inputTokens,
        costUsd: cost,
        error: reply.error ?? 'No answers in the reply.',
        why: c.why);
  }
  var right = true;
  var pTrue = 1.0;
  final got = <String>[];
  for (final q in c.questions) {
    final a = scoreDeciderAnswer(q, answers[q.name]);
    right = right && a.right;
    pTrue *= a.pTrue;
    got.add(c.questions.length == 1 ? a.got : '${q.name}: ${a.got}');
  }
  return DeciderCaseResult(
      id: c.id,
      skill: c.skill,
      policy: c.policy.id,
      right: right,
      pTrue: pTrue,
      expected: c.expectedLabel,
      got: got.join(', '),
      ms: ms,
      inputTokens: reply.inputTokens,
      costUsd: cost,
      why: c.why);
}

/// One run of the suite against one model.
class DeciderRun {
  DeciderRun({
    required this.id,
    required this.provider,
    required this.model,
    required this.ownKey,
    required this.startedAtMs,
    required this.total,
    required this.chance,
    this.suite = '',
    this.keyHint,
    this.status = 'queued',
    this.finishedAtMs,
    this.note,
    List<DeciderCaseResult>? results,
  }) : results = results ?? [];

  final String id;
  final DeciderProvider provider;
  final String model;
  final bool ownKey;
  final String? keyHint;
  int startedAtMs;
  final int total;

  /// What guessing would have scored on the suite this run used, 0 to 100.
  final double chance;

  /// [deciderSuiteHash] of the suite this run used. Runs on another suite
  /// are not comparable with runs on the current one.
  final String suite;

  /// `queued`, `running`, `done`, `stopped`, `failed` or `interrupted`.
  String status;
  int? finishedAtMs;
  String? note;
  final List<DeciderCaseResult> results;

  /// Set from the dashboard's Stop button; never stored.
  bool stopRequested = false;

  bool get active => status == 'queued' || status == 'running';

  Iterable<DeciderCaseResult> get _answered =>
      results.where((r) => r.error == null);

  /// Share of answered cases that were right, 0 to 100.
  double get accuracy =>
      _pct(_answered.where((r) => r.right).length, _answered.length);

  /// The average probability put on the right answer, 0 to 100.
  double get meanPTrue => _answered.isEmpty
      ? 0
      : _answered.fold(0.0, (s, r) => s + r.pTrue) / _answered.length * 100;

  double get costUsd => results.fold(0.0, (s, r) => s + r.costUsd);
  int get inputTokens => results.fold(0, (s, r) => s + r.inputTokens);
  int get errors => results.where((r) => r.error != null).length;

  /// What a thousand answered cases would cost at this run's rate.
  double get costPer1k =>
      _answered.isEmpty ? 0 : costUsd / _answered.length * 1000;

  static double _pct(int n, int of) => of == 0 ? 0 : n / of * 100;

  Map<String, dynamic> _breakdown(String Function(DeciderCaseResult) key) {
    final groups = <String, List<DeciderCaseResult>>{};
    for (final r in _answered) {
      groups.putIfAbsent(key(r), () => []).add(r);
    }
    return {
      for (final e in groups.entries)
        e.key: {
          'n': e.value.length,
          'score': double.parse(
              _pct(e.value.where((r) => r.right).length, e.value.length)
                  .toStringAsFixed(1)),
        },
    };
  }

  Map<String, dynamic> summaryJson() => {
        'id': id,
        'provider': provider.name,
        'providerLabel': provider.label,
        'model': model,
        'ownKey': ownKey,
        if (keyHint != null) 'keyHint': keyHint,
        'startedAtMs': startedAtMs,
        if (finishedAtMs != null) 'finishedAtMs': finishedAtMs,
        'status': status,
        if (note != null) 'note': note,
        'total': total,
        'done': results.length,
        'chance': double.parse(chance.toStringAsFixed(1)),
        if (suite.isNotEmpty) 'suite': suite,
        'accuracy': double.parse(accuracy.toStringAsFixed(1)),
        'meanPTrue': double.parse(meanPTrue.toStringAsFixed(1)),
        'costUsd': costUsd,
        'costPer1k': costPer1k,
        'inputTokens': inputTokens,
        'errors': errors,
        'bySkill': _breakdown((r) => r.skill),
        'byPolicy': _breakdown((r) => r.policy),
        'avgMs': results.isEmpty
            ? 0
            : results.fold<int>(0, (s, r) => s + r.ms) ~/ results.length,
      };

  Map<String, dynamic> toJson() => {
        ...summaryJson(),
        'results': [for (final r in results) r.toJson()],
      };

  static DeciderRun? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final provider = DeciderProvider.parse(raw['provider']);
    final model = _str(raw['model']);
    if (id is! String || provider == null || model.isEmpty) return null;
    final status = _str(raw['status']);
    return DeciderRun(
      id: id,
      provider: provider,
      model: model,
      ownKey: raw['ownKey'] == true,
      keyHint: raw['keyHint'] is String ? raw['keyHint'] as String : null,
      startedAtMs: (raw['startedAtMs'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      chance: (raw['chance'] as num?)?.toDouble() ?? 0,
      suite: _str(raw['suite']),
      status:
          status == 'running' || status == 'queued' ? 'interrupted' : status,
      finishedAtMs: (raw['finishedAtMs'] as num?)?.toInt(),
      note: raw['note'] is String ? raw['note'] as String : null,
      results: [
        if (raw['results'] case final List list)
          for (final r in list)
            if (DeciderCaseResult.fromJson(r) case final result?) result,
      ],
    );
  }
}

/// Runs every case of [suite] through [call], [parallel] at a time, adding
/// each result to [run] as it lands. A fatal reply (key refused, no credit)
/// stops the run with that reply's error as its note.
Future<void> runDeciderSuite(
  DeciderRun run,
  DeciderSuite suite,
  DeciderCall call, {
  double? pricePerMInput,
  int parallel = 4,
  Future<void> Function()? onProgress,
}) async {
  final model = run.provider.modelFor(run.model);
  var next = 0;
  Future<void> worker() async {
    while (next < suite.cases.length && !run.stopRequested) {
      final c = suite.cases[next++];
      var fatal = false;
      final result = await attemptDeciderCase(c, model, (body) async {
        final reply = await call(body);
        fatal = reply.fatal;
        return reply;
      }, pricePerMInput: pricePerMInput);
      if (fatal) {
        if (!run.stopRequested) {
          run.stopRequested = true;
          run.note = result.error;
        }
        break;
      }
      run.results.add(result);
      if (run.results.length == kDeciderEarlyFailures &&
          run.results.every((r) => r.error != null) &&
          !run.stopRequested) {
        run.stopRequested = true;
        run.note = 'The first $kDeciderEarlyFailures cases all failed: '
            '${run.results.first.error}';
      }
      await onProgress?.call();
    }
  }

  await Future.wait([
    for (var i = 0; i < math.max(1, parallel); i++) worker(),
  ]);
}

/// The suite the operator saved and every run, in `decider_tests.json`.
class DeciderTestStore {
  DeciderTestStore(String dataDir)
      : _file = File('$dataDir/decider_tests.json') {
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      if (decoded['suite'] case final String suite) _suiteText = suite;
      if (decoded['runs'] case final List runs) {
        for (final raw in runs) {
          if (DeciderRun.fromJson(raw) case final run?) _runs.add(run);
        }
      }
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  final File _file;
  final AsyncLock _lock = AsyncLock();
  String? _suiteText;
  final List<DeciderRun> _runs = [];

  /// The operator's suite, or the built-in one until they save their own.
  String get suiteText => _suiteText ?? kStarterDeciderSuite;
  bool get customSuite => _suiteText != null;

  /// Newest first.
  List<DeciderRun> get runs => List.unmodifiable(_runs.reversed);

  DeciderRun? run(String id) {
    for (final r in _runs) {
      if (r.id == id) return r;
    }
    return null;
  }

  bool get busy => _runs.any((r) => r.active);

  /// Runs still waiting or going, oldest first.
  List<DeciderRun> get active => _runs.where((r) => r.active).toList();

  /// Saves [text] after checking it parses; null resets to the built-in set.
  Future<void> saveSuite(String? text) async {
    if (text != null) DeciderSuite.parse(text);
    _suiteText = text;
    await persist();
  }

  Future<void> addAll(List<DeciderRun> runs) async {
    _runs.addAll(runs);
    while (_runs.length > kDeciderTestMaxRuns) {
      final oldest = _runs.indexWhere((r) => !r.active);
      if (oldest < 0) break;
      _runs.removeAt(oldest);
    }
    await persist();
  }

  Future<bool> delete(String id) async {
    final before = _runs.length;
    _runs.removeWhere((r) => r.id == id && !r.active);
    if (_runs.length == before) return false;
    await persist();
    return true;
  }

  Future<void> persist() => _lock.synchronized(() => atomicWriteString(
      _file.path,
      jsonEncode({
        if (_suiteText != null) 'suite': _suiteText,
        'runs': [for (final r in _runs) r.toJson()],
      })));
}

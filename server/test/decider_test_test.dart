import 'dart:io';

import 'package:luma_sync_server/decider_test.dart';
import 'package:test/test.dart';

void main() {
  group('built-in suite', () {
    final suite = DeciderSuite.parse(kStarterDeciderSuite);

    test('parses with every policy used', () {
      expect(suite.cases.length, greaterThanOrEqualTo(50));
      expect(suite.cases.map((c) => c.policy.id).toSet(),
          suite.policies.keys.toSet());
    });

    test('every case explains its answer', () {
      for (final c in suite.cases) {
        expect(c.why, isNotEmpty, reason: c.id);
      }
    });

    test('guessing scores well under the 50% ceiling', () {
      expect(suite.chancePercent, lessThan(25));
    });

    test('no single answer wins a policy by itself', () {
      // A model that always picks the same action must not pass a policy.
      for (final policy in suite.policies.values) {
        final picks = <String, int>{};
        final cases = suite.cases.where((c) =>
            c.policy == policy &&
            c.questions.length == 1 &&
            c.questions.single.type == 'choice');
        for (final c in cases) {
          final e = c.questions.single.expect as String;
          picks[e] = (picks[e] ?? 0) + 1;
        }
        if (cases.isEmpty) continue;
        final top = picks.values.reduce((a, b) => a > b ? a : b);
        expect(top / suite.cases.length, lessThan(0.12),
            reason: '${policy.id}: $picks');
      }
    });

    test('a case request carries the policy, context and post', () {
      final c = suite.cases.first;
      final body = c.request('perplexity/pplx-decider-flash-v1.2');
      expect(body['model'], 'perplexity/pplx-decider-flash-v1.2');
      // Plain text: Respan's models refuse an object state.
      final state = body['state'] as String;
      expect(state, startsWith('POLICY\n'));
      expect(state, contains('HARBOR COMMUNITY RULES'));
      expect(state, contains('"today": "2026-10-16"'));
      expect(state, endsWith('CONTENT\n${c.content}'));
      final q = (body['questions'] as Map)['action'] as Map;
      expect(q['type'], 'choice');
      expect((q['criteria'] as Map).keys, contains('ALLOW'));
    });

    test('a yes/no-only model gets every question split into yes/no ones', () {
      for (final c in suite.cases) {
        final body = c.request('respan/span-01-lite:free');
        final questions = body['questions'] as Map;
        for (final q in questions.values) {
          expect(q['type'], 'noul');
          expect(q['instructions'], isA<String>());
          expect(q['criteria'], isA<String>());
        }
        final answers = {
          for (final e in questions.entries) e.key: {'noul': 0.1},
        };
        for (final q in c.questions) {
          final key = switch (q.type) {
            'choice' => '${q.name}__${q.expect}',
            'score' => '${q.name}__${q.expect}',
            _ => q.name,
          };
          answers[key] = {
            'noul': q.type == 'noul' && q.expect == false ? 0.1 : 0.9
          };
        }
        final folded = c.foldNoulAnswers(answers);
        for (final q in c.questions) {
          expect(scoreDeciderAnswer(q, folded[q.name]).right, isTrue,
              reason: '${c.id} ${q.name}');
        }
      }
    });
  });

  group('parse', () {
    test('rejects an expect that is not an action', () {
      expect(
          () => DeciderSuite.parse('{"policies":{"p":{"rules":"r","actions":'
              '{"A":"","B":""}}},"cases":[{"id":"x","policy":"p",'
              '"content":"c","expect":"C"}]}'),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('"x"'))));
    });

    test('rejects a score expect outside the levels', () {
      expect(
          () => DeciderSuite.parse('{"policies":{"p":{"rules":"r"}},'
              '"cases":[{"id":"x","policy":"p","content":"c","questions":'
              '{"s":{"type":"score","instructions":"i","criteria":["a","b"]}},'
              '"expect":{"s":2}}]}'),
          throwsFormatException);
    });
  });

  group('scoring', () {
    const choice = DeciderQuestion(
        name: 'action',
        type: 'choice',
        instructions: 'i',
        criteria: {'ALLOW': '', 'REMOVE': ''},
        expect: 'REMOVE');
    const noul = DeciderQuestion(
        name: 'n',
        type: 'noul',
        instructions: 'i',
        criteria: null,
        expect: false);
    const score = DeciderQuestion(
        name: 's',
        type: 'score',
        instructions: 'i',
        criteria: ['0', '1', '2', '3'],
        expect: 2);

    test('choice is right on the top option', () {
      final a = scoreDeciderAnswer(choice, {
        'type': 'choice',
        'choice': 'REMOVE',
        'probabilities': {'ALLOW': 0.3, 'REMOVE': 0.7}
      });
      expect(a.right, isTrue);
      expect(a.pTrue, 0.7);
      final b = scoreDeciderAnswer(choice, {
        'type': 'choice',
        'choice': 'ALLOW',
        'probabilities': {'ALLOW': 0.6, 'REMOVE': 0.4}
      });
      expect(b.right, isFalse);
      expect(b.pTrue, 0.4);
    });

    test('noul splits at one half', () {
      expect(scoreDeciderAnswer(noul, {'noul': 0.49}).right, isTrue);
      expect(scoreDeciderAnswer(noul, {'noul': 0.5}).right, isFalse);
      expect(scoreDeciderAnswer(noul, {'noul': 0.2}).pTrue, closeTo(0.8, 1e-9));
    });

    test('score is right within half a level', () {
      expect(scoreDeciderAnswer(score, {'score': 2.4}).right, isTrue);
      expect(scoreDeciderAnswer(score, {'score': 1.5}).right, isFalse);
    });

    test('a missing answer is wrong', () {
      expect(scoreDeciderAnswer(choice, null).right, isFalse);
      expect(scoreDeciderAnswer(noul, {'type': 'noul'}).right, isFalse);
    });
  });

  group('run', () {
    final suite = DeciderSuite.parse(kStarterDeciderSuite);

    DeciderRun newRun() => DeciderRun(
        id: 'r',
        provider: DeciderProvider.openrouter,
        model: 'perplexity/pplx-decider-flash-v1.2',
        ownKey: false,
        startedAtMs: 0,
        total: suite.cases.length,
        chance: suite.chancePercent);

    test('a model that always answers right scores 100%, priced by tokens',
        () async {
      final byId = {for (final c in suite.cases) c.id: c};
      final run = newRun();
      await runDeciderSuite(run, suite, (body) async {
        final c = byId.values.firstWhere((c) =>
            body['state'] == c.stateText &&
            (body['questions'] as Map).keys.join() ==
                c.questions.map((q) => q.name).join());
        return DeciderReply(inputTokens: 1000, answers: {
          for (final q in c.questions)
            q.name: switch (q.type) {
              'noul' => {'noul': q.expect == true ? 0.9 : 0.1},
              'score' => {'score': (q.expect as int).toDouble()},
              _ => {
                  'choice': q.expect,
                  'probabilities': {q.expect: 1.0}
                },
            },
        });
      }, pricePerMInput: 0.01);
      expect(run.results.length, suite.cases.length);
      expect(run.accuracy, 100);
      expect(run.costPer1k, closeTo(0.01, 1e-12));
    });

    test('a refused key stops the run with its error', () async {
      final run = newRun();
      await runDeciderSuite(run, suite,
          (body) async => const DeciderReply(error: 'HTTP 401', fatal: true));
      expect(run.results, isEmpty);
      expect(run.note, 'HTTP 401');
    });

    test('a model that rejects every request stops after five cases', () async {
      final run = newRun();
      await runDeciderSuite(
          run,
          suite,
          (body) async =>
              const DeciderReply(error: 'HTTP 400: state must be a string'),
          parallel: 1);
      expect(run.results.length, kDeciderEarlyFailures);
      expect(run.note, contains('HTTP 400: state must be a string'));
    });

    test('a later error does not stop a run that was answering', () async {
      final run = newRun();
      var n = 0;
      await runDeciderSuite(run, suite, (body) async {
        n++;
        return n == 1
            ? const DeciderReply(answers: {})
            : const DeciderReply(error: 'HTTP 500');
      }, parallel: 1);
      expect(run.results.length, suite.cases.length);
      expect(run.note, isNull);
    });

    test('the suite fingerprint changes with any edit', () {
      final a = deciderSuiteHash(kStarterDeciderSuite);
      expect(a, hasLength(8));
      expect(deciderSuiteHash(kStarterDeciderSuite), a);
      expect(deciderSuiteHash('$kStarterDeciderSuite '), isNot(a));
    });

    test('runs survive a restart as interrupted', () async {
      final dir = await Directory.systemTemp.createTemp('decider');
      addTearDown(() => dir.delete(recursive: true));
      final store = DeciderTestStore(dir.path);
      final run = newRun()..status = 'running';
      await store.addAll([run]);
      final again = DeciderTestStore(dir.path);
      expect(again.runs.single.status, 'interrupted');
      expect(again.busy, isFalse);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/school_test.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _lesson = {
  'country': 'Nederland',
  'school': 'Middelbare school',
  'year': 'leerjaar 3',
  'level': 'havo',
  'subject': 'Wiskunde',
  'publisher': 'Getal & Ruimte',
  'chapter': '4',
  'paragraph': '4.2',
  'topic': 'De stelling van Pythagoras',
};

SchoolTestCase _case(Map<String, dynamic> raw) =>
    SchoolTestSuite.parse(jsonEncode({
      'cases': [
        {'lesson': _lesson, ...raw}
      ]
    })).cases.single;

String _answer(String a) => jsonEncode({'answer': a});

String _review(String result) =>
    jsonEncode({'result': result, 'feedback': 'ok', 'answer': '4'});

void main() {
  group('suite', () {
    test('the starter set parses', () {
      final suite = SchoolTestSuite.parse(kStarterSchoolTestSuite);
      expect(suite.language, 'nl');
      expect(suite.cases.map((c) => c.kind).toSet(),
          {'answer', 'grade', 'question'});
      expect(suite.cases.length, greaterThanOrEqualTo(80));
      for (var d = 1; d <= kSchoolTestMaxDifficulty; d++) {
        expect(suite.cases.where((c) => c.difficulty == d).length,
            greaterThanOrEqualTo(10),
            reason: 'level $d');
      }
      // Format-only question cases are free points; they must not weigh
      // more than the easiest level.
      expect(
          suite.cases
              .where((c) => c.kind == 'question')
              .every((c) => c.difficulty == 1),
          isTrue);
    });

    test('names the case that is wrong', () {
      Matcher fails(String part) => throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', contains(part)));
      String one(Map<String, dynamic> c) => jsonEncode({
            'cases': [
              {'lesson': _lesson, ...c}
            ]
          });
      expect(() => SchoolTestSuite.parse('{'), fails('Not valid JSON'));
      expect(() => SchoolTestSuite.parse('{"cases":[]}'), fails('at least'));
      expect(
          () => SchoolTestSuite.parse(one({'kind': 'quiz'})), fails('"kind"'));
      expect(
          () => SchoolTestSuite.parse(one({
                'kind': 'answer',
                'question': 'q',
                'expect': {
                  'number': 1,
                  'accept': ['a']
                },
              })),
          fails('exactly one'));
      expect(
          () => SchoolTestSuite.parse(one({
                'kind': 'answer',
                'question': 'q',
                'choices': ['a', 'b'],
                'expect': {'choice': 'C'},
              })),
          fails('letter'));
      expect(
          () => SchoolTestSuite.parse(one({
                'kind': 'grade',
                'question': 'q',
                'studentAnswer': 'a',
                'expect': {'result': 'maybe'},
              })),
          fails('correct, partly or wrong'));
      expect(
          () => SchoolTestSuite.parse(jsonEncode({
                'cases': [
                  {
                    'kind': 'question',
                    'lesson': {'school': 'x'}
                  }
                ]
              })),
          fails('lesson'));
      expect(
          () => SchoolTestSuite.parse(jsonEncode({
                'cases': [
                  {'id': 'a', 'kind': 'question', 'lesson': _lesson},
                  {'id': 'a', 'kind': 'question', 'lesson': _lesson},
                ]
              })),
          fails('twice'));
      for (final bad in [0, 6, 2.5, 'hard']) {
        expect(
            () => SchoolTestSuite.parse(
                one({'kind': 'question', 'difficulty': bad})),
            fails('"difficulty"'),
            reason: '$bad');
      }
      expect(
          SchoolTestSuite.parse(one({'kind': 'question'}))
              .cases
              .single
              .difficulty,
          1);
    });
  });

  group('scoring', () {
    test('numbers are checked here, with a decimal comma and a tolerance', () {
      final c = _case({
        'kind': 'answer',
        'question': 'Snelheid in m/s?',
        'expect': {'number': 5, 'tolerance': 0.05},
      });
      expect(scoreSchoolTestCase(c, _answer('5,0 m/s')).score, 1);
      expect(scoreSchoolTestCase(c, _answer('v = 18 / 3,6 = 5')).score, 1);
      expect(scoreSchoolTestCase(c, _answer('5.2')).score, 0);
      expect(scoreSchoolTestCase(c, _answer('vijf')).score, 0);
      expect(lastNumber('1 648'), 1648);
    });

    test('numbers in powers of ten and with thousands separators count', () {
      final force = _case({
        'kind': 'answer',
        'question': 'Remkracht in N?',
        'expect': {'number': 6000, 'tolerance': 1},
      });
      for (final said in [
        '6,0 · 10³ N',
        '6.000 N',
        '6,0 × 10^3 N',
        '6.0e3 N',
        'F = 6000 N'
      ]) {
        expect(scoreSchoolTestCase(force, _answer(said)).score, 1,
            reason: said);
      }
      expect(scoreSchoolTestCase(force, _answer('6,0 N')).score, 0);
      expect(numberReadings('€ 2.318,55'), [2318.55]);
      expect(numberReadings('Kz = 1,8 · 10⁻⁵').single, closeTo(1.8e-5, 1e-12));
      expect(numberReadings('−1'), [-1]);
    });

    test('an option counts by its letter or its exact text', () {
      final c = _case({
        'kind': 'answer',
        'question': 'Welke stof?',
        'choices': ['Zuurstof', 'Koolstofdioxide', 'Stikstof'],
        'expect': {'choice': 'B'},
      });
      expect(scoreSchoolTestCase(c, _answer('B')).score, 1);
      expect(scoreSchoolTestCase(c, _answer('(b) Koolstofdioxide')).score, 1);
      expect(scoreSchoolTestCase(c, _answer('koolstofdioxide')).score, 1);
      expect(scoreSchoolTestCase(c, _answer('A')).score, 0);
    });

    test('a phrase must contain an accepted one as whole words', () {
      final c = _case({
        'kind': 'answer',
        'question': 'Hoe heet dat?',
        'expect': {
          'accept': ['vergrijzing']
        },
      });
      expect(scoreSchoolTestCase(c, _answer('Vergrijzing.')).score, 1);
      expect(scoreSchoolTestCase(c, _answer('ontgroening')).score, 0);
    });

    test('a verdict one step off is half right; right marked wrong is harsh',
        () {
      final c = _case({
        'kind': 'grade',
        'question': 'Hoe hoog?',
        'studentAnswer': '4 meter',
        'expect': {'result': 'correct'},
      });
      expect(scoreSchoolTestCase(c, _review('correct')).score, 1);
      expect(scoreSchoolTestCase(c, _review('partly')).score, 0.5);
      final wrong = scoreSchoolTestCase(c, _review('wrong'));
      expect(wrong.score, 0);
      expect(wrong.harsh, isTrue);
    });

    test('a question case checks only the shape', () {
      final c = _case({'kind': 'question'});
      expect(
          scoreSchoolTestCase(
              c, jsonEncode({'question': 'Bereken c.', 'choices': []})).score,
          1);
      final bad = scoreSchoolTestCase(c, 'Here is a question: what is c?');
      expect(bad.score, 0);
      expect(bad.error, isNotNull);
    });

    test('a failed call scores zero and keeps the reason', () {
      final c = _case({'kind': 'question'});
      final r = scoreSchoolTestCase(c, null, error: 'HTTP 401');
      expect(r.score, 0);
      expect(r.error, 'HTTP 401');
    });
  });

  test('a run sends each case its own messages and adds up the score',
      () async {
    final suite = SchoolTestSuite.parse(jsonEncode({
      'cases': [
        {
          'id': 'n',
          'kind': 'answer',
          'lesson': _lesson,
          'question': '6 en 8, schuine zijde?',
          'expect': {'number': 10},
        },
        {
          'id': 'g',
          'kind': 'grade',
          'lesson': _lesson,
          'question': 'Hoe hoog?',
          'studentAnswer': '4 meter',
          'expect': {'result': 'correct'},
        },
        {'id': 'q', 'kind': 'question', 'lesson': _lesson},
      ]
    }));
    final seen = <String>[];
    Future<SchoolTestReply> call(List<Map<String, String>> messages,
        {required double temperature}) async {
      final system = messages.first['content']!;
      expect(system, startsWith('Be kind.'));
      if (system.contains('answering an exam question')) {
        seen.add('answer');
        expect(messages.last['content'], contains('<question>'));
        return SchoolTestReply(content: _answer('10 cm'), tokens: 10);
      }
      if (system.contains('"result"')) {
        seen.add('grade');
        expect(messages.last['content'], contains('<answer>\n4 meter'));
        return SchoolTestReply(content: _review('wrong'), tokens: 20);
      }
      seen.add('question');
      expect(temperature, 0.8);
      return const SchoolTestReply(error: 'HTTP 500');
    }

    final run = SchoolTestRun(
      id: 'r',
      route: const AiModeRoute(AiUpstream.openrouter, 'x/y'),
      ownKey: true,
      startedAtMs: 0,
      total: 3,
    );
    await runSchoolTestSuite(run, suite, 'Be kind.', call, parallel: 2);
    expect(seen.toSet(), {'answer', 'grade', 'question'});
    expect(run.results, hasLength(3));
    expect(run.score, closeTo(100 / 3, 0.01));
    expect(run.harsh, 1);
    expect(run.errors, 1);
    expect(run.tokens, 30);
    expect(run.byKind()['answer'], {'n': 1, 'score': 100.0});
  });

  test('a hard case weighs as much as its difficulty', () {
    SchoolTestCaseResult r(int difficulty, double score) =>
        SchoolTestCaseResult(
            id: '$difficulty-$score',
            kind: 'answer',
            expected: '',
            score: score,
            got: '',
            difficulty: difficulty);
    final run = SchoolTestRun(
      id: 'w',
      route: const AiModeRoute(AiUpstream.openrouter, 'x/y'),
      ownKey: false,
      startedAtMs: 0,
      total: 4,
      results: [r(1, 1), r(1, 1), r(1, 1), r(5, 0)],
    );
    // Three easy right, one hard wrong: 3 of 8 points, not 3 of 4.
    expect(run.score, closeTo(37.5, 0.001));
    expect(run.byDifficulty(), {
      '1': {'n': 3, 'score': 100.0},
      '5': {'n': 1, 'score': 0.0},
    });
  });

  test('a key the provider refuses ends the run with the reason', () async {
    final suite = SchoolTestSuite.parse(jsonEncode({
      'cases': [
        for (var i = 0; i < 5; i++)
          {'id': 'q$i', 'kind': 'question', 'lesson': _lesson},
      ]
    }));
    final run = SchoolTestRun(
      id: 'r',
      route: const AiModeRoute(AiUpstream.openrouter, 'x/y'),
      ownKey: true,
      startedAtMs: 0,
      total: 5,
    );
    await runSchoolTestSuite(
        run,
        suite,
        'Teach.',
        (messages, {required temperature}) async =>
            const SchoolTestReply(error: 'HTTP 401: nope', fatal: true),
        parallel: 1);
    expect(run.results, hasLength(1));
    expect(run.note, 'HTTP 401: nope');
  });

  test(
      'a pasted key is checked against its provider and shown only by its ends',
      () {
    expect(schoolTestKeyProblem(AiUpstream.openrouter, 'hunter2hunter2'),
        contains('sk-or-'));
    expect(schoolTestKeyProblem(AiUpstream.openrouter, 'sk-or-v1-abcdef123'),
        isNull);
    expect(schoolTestKeyProblem(AiUpstream.mistral, 'abc def ghi'),
        contains('spaces'));
    expect(schoolTestKeyProblem(AiUpstream.mistral, 'AbCdEfGh1234'), isNull);
    expect(schoolTestKeyHint('sk-or-v1-0123456789abcdef'), 'sk-or-v1-…cdef');
    expect(schoolTestKeyHint('AbCdEfGh1234'), 'AbC…1234');
  });

  test('a stop request ends the run before the next case', () async {
    final suite = SchoolTestSuite.parse(jsonEncode({
      'cases': [
        for (var i = 0; i < 5; i++)
          {'id': 'q$i', 'kind': 'question', 'lesson': _lesson},
      ]
    }));
    final run = SchoolTestRun(
      id: 'r',
      route: const AiModeRoute(AiUpstream.openrouter, 'x/y'),
      ownKey: false,
      startedAtMs: 0,
      total: 5,
    );
    await runSchoolTestSuite(run, suite, 'Teach.', (messages,
        {required temperature}) async {
      run.stopRequested = true;
      return const SchoolTestReply(content: '{"question":"q","choices":[]}');
    }, parallel: 1);
    expect(run.results, hasLength(1));
  });

  group('store', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('st_store'));
    tearDown(() => dir.delete(recursive: true));

    test('keeps the suite and runs; a run cut off by a restart is marked so',
        () async {
      final store = SchoolTestStore(dir.path);
      expect(store.customSuite, isFalse);
      await expectLater(store.saveSuite('{"cases":[]}'), throwsFormatException);
      final mine = jsonEncode({
        'cases': [
          {'kind': 'question', 'lesson': _lesson}
        ]
      });
      await store.saveSuite(mine);
      await store.add(SchoolTestRun(
        id: 'a',
        route: const AiModeRoute(AiUpstream.mistral, 'm'),
        ownKey: true,
        startedAtMs: 1,
        total: 1,
      ));
      final reloaded = SchoolTestStore(dir.path);
      expect(reloaded.suiteText, mine);
      expect(reloaded.run('a')!.status, 'interrupted');
      expect(reloaded.run('a')!.ownKey, isTrue);
      expect(reloaded.running, isNull);
      await reloaded.saveSuite(null);
      expect(SchoolTestStore(dir.path).customSuite, isFalse);
    });
  });

  group('admin dashboard', () {
    late Directory dir;
    late Handler handler;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('st_admin');
      final config = ServerConfig(
        port: 0,
        dataDir: dir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(hours: 24),
        maxVerificationEmailsPerHour: 50,
        approvalMode: ApprovalMode.open,
        adminKey: 'test-admin-key',
        mistralApiKey: null,
        googleApiKey: null,
        itadApiKey: null,
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: null,
        wikiDir: null,
        publicUrl: 'https://sync.example.com',
        oauthProviders: const {},
      );
      handler = Api(
        await Store.open(dir.path),
        config,
        Mailer(MailConfig.fromEnvironment(const {})),
        await FamilyStore.open(dir.path),
        await ChatStore.open(dir.path),
        await AiUsageStore.open(dir.path),
        await SubwayStore.open(dir.path),
        await RecipeStore.open(dir.path),
        await AiModelCatalogStore.open(dir.path),
        await AiBenchmarkStore.open(dir.path),
      ).handler;
    });
    tearDown(() => dir.delete(recursive: true));

    Future<(int, String)> send(String method, String path,
        {Object? json}) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          'x-admin-key': 'test-admin-key',
          if (json != null) 'Content-Type': 'application/json',
        },
        body: json == null ? null : jsonEncode(json),
      ));
      return (response.statusCode, await response.readAsString());
    }

    test('the benchmark cards live on the Tests tab, not Maintenance',
        () async {
      final (status, html) = await send('GET', '/admin');
      expect(status, 200);
      expect(html, contains('data-tab="tests">Tests</button>'));
      final tests = html.indexOf('id="panel-tests"');
      final control = html.indexOf('id="panel-control"');
      expect(tests, greaterThan(control));
      final controlPanel = html.substring(control, tests);
      final testsPanel = html.substring(tests);
      for (final id in ['bmUploadBtn', 'bannersMissingBtn']) {
        expect(controlPanel, isNot(contains('id="$id"')), reason: id);
        expect(testsPanel, contains('id="$id"'), reason: id);
      }
      expect(testsPanel, contains('id="stRunBtn"'));
      expect(controlPanel, contains('id="deployBtn"'));
    });

    test('a run needs a key from the server or the form', () async {
      var (status, body) = await send('POST', '/admin/school-tests/run',
          json: {'upstream': 'openrouter', 'model': 'x/y'});
      expect(status, 409);
      expect(body, contains('no_key'));
      (status, body) = await send('POST', '/admin/school-tests/run', json: {
        'upstream': 'openrouter',
        'model': 'x/y',
        'apiKey': 'has spaces in it',
      });
      expect(status, 400);
      (status, body) = await send('POST', '/admin/school-tests/run',
          json: {'upstream': 'nope', 'model': 'x/y', 'apiKey': 'sk-12345678'});
      expect(status, 400);
      (status, body) = await send('POST', '/admin/school-tests/run', json: {
        'upstream': 'openrouter',
        'model': 'x/y',
        'apiKey': 'MyAdminPassword!',
      });
      expect(status, 400);
      expect(jsonDecode(body)['message'], contains('sk-or-'));
    });

    test('prompts are validated on save and can be reset', () async {
      var (status, body) = await send('POST', '/admin/school-tests/suite',
          json: {'suite': '{"cases":[{"kind":"answer"}]}'});
      expect(status, 400);
      expect(jsonDecode(body)['message'], contains('Case 1'));
      final mine = jsonEncode({
        'cases': [
          {'kind': 'question', 'lesson': _lesson}
        ]
      });
      (status, body) = await send('POST', '/admin/school-tests/suite',
          json: {'suite': mine});
      expect(status, 200);
      (status, body) = await send('GET', '/admin/school-tests');
      final state = jsonDecode(body) as Map<String, dynamic>;
      expect(state['customSuite'], isTrue);
      expect(state['cases'], 1);
      expect(state['runs'], isEmpty);
      (status, body) = await send('POST', '/admin/school-tests/suite',
          json: {'reset': true});
      expect(jsonDecode(body)['customSuite'], isFalse);
    });
  });
}

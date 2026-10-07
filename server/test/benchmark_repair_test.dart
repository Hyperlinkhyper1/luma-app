import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_price_guard.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:luma_sync_server/benchmark_repair.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/preview_render.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'preview_render_test.dart' show FakeRenderProcess;

class RepairRenderer extends PreviewRenderService {
  RepairRenderer({required super.dataDir}) : super(environment: const {});
  String? validationError;
  int validations = 0;
  SourceProblem? Function(List<int> bytes)? syntax;
  @override
  Future<SourceProblem?> findSyntaxError(List<int> bytes) async =>
      syntax?.call(bytes);

  List<int>? candidate;
  final rendered = <String>[];
  @override
  Future<String?> validateRepair(String id, List<int> bytes) async {
    validations++;
    candidate = bytes;
    return validationError;
  }

  @override
  Future<String?> enqueue(List<String> ids) async {
    rendered.addAll(ids);
    return null;
  }
}

/// Only the owner lookup is used by these admin routes. Account database ACLs
/// are covered elsewhere; scene persistence and usage recording stay real.
class RepairAccounts implements Store {
  @override
  final Map<String, String> userIdByEmail = {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const original =
      '<html><head></head><body><script>const value = broken();</script><canvas></canvas></body></html>';
  final reply = jsonEncode({
    'edits': [
      {'before': 'broken()', 'after': 'fixed()'}
    ]
  });
  test(
      'exact patches keep the scene and reject broad, ambiguous or overlapping edits',
      () {
    expect(applyBenchmarkRepair(original, reply),
        original.replaceFirst('broken()', 'fixed()'));
    expect(
        () => applyBenchmarkRepair(
            original,
            jsonEncode({
              'edits': [
                {'before': original, 'after': '<html>new</html>'}
              ]
            })),
        throwsFormatException);
    expect(() => applyBenchmarkRepair('$original broken()', reply),
        throwsFormatException);
    expect(
        () => applyBenchmarkRepair(
            original,
            jsonEncode({
              'edits': [
                {'before': 'broken()', 'after': 'fixed()'},
                {'before': 'value = broken()', 'after': 'value = other()'},
              ]
            })),
        throwsFormatException);
  });
  test('a reply wrapped in prose or a fence still applies', () {
    final fixed = original.replaceFirst('broken()', 'fixed()');
    expect(applyBenchmarkRepair(original, 'Here is the fix:\n$reply\nDone.'),
        fixed);
    expect(
        applyBenchmarkRepair(
            original, 'The bug is X.\n```json\n$reply\n```\nThat fixes it.'),
        fixed);
  });
  test('bracket problems point at where the imbalance starts', () {
    final cut = bracketProblem('<html>\n<script>\nfunction a() {\n'
        '  if (x) {\n    y();\n</script>\n</html>')!;
    expect(cut.line, 4);
    expect(cut.message, contains('2 brackets are never closed'));
    expect(cut.message, contains("'{' at line 4: if (x) {"));
    final extra = bracketProblem(
        '<script>\nfunction a() {\n  b();\n}\n}\nc();\n</script>')!;
    expect(extra.line, 5);
    expect(extra.message, contains("Line 5 has a '}' that closes nothing"));
    expect(
        bracketProblem('<script type="importmap">{"imports":{</script>'
            '<script>const s = "{"; const r = /[}(]/g; '
            'const t = `a\${b + `{`}{`; // }\n/* { */ f(s, [r, t]);</script>'),
        isNull);
    expect(
        repairFocusLine('<script>\nfunction a() {\n  b();\n\n\n</script>',
            'Syntax error at line 6:1: Unexpected end of input.'),
        2);
  });
  test('code pasted into JSON strings unescaped is mended', () {
    const page = '<script>\nconst re = /broken()/;\n</script>';
    expect(
        applyBenchmarkRepair(page,
            '{"edits":[{"before":"const re = /broken()/;","after":"const re = /\\d+/;\n\tlet x = 1;"}]}'),
        '<script>\nconst re = /\\d+/;\n\tlet x = 1;\n</script>');
  });
  test('line numbers may come as strings, and bad ones say why', () {
    const page = 'a\nb\nc';
    expect(
        applyBenchmarkRepair(
            page,
            jsonEncode({
              'edits': [
                {'startLine': '2', 'endLine': 2.0, 'after': 'B'}
              ]
            })),
        'a\nB\nc');
    expect(
        () => applyBenchmarkRepair(
            page,
            jsonEncode({
              'edits': [
                {'startLine': 9, 'endLine': 9, 'after': 'x'}
              ]
            })),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('the source has 3 lines'))));
  });
  test('a reply that is not JSON says so, not that before was wrong', () {
    expect(
        () => applyBenchmarkRepair(
            original, r'{"edits":[{"before":"a" "after":"b"}]}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            startsWith('Your reply was not valid JSON'))));
  });
  test('errors about a declaration are told where the name is declared', () {
    const page = 'const A = 1;\n'
        'function run() {\n'
        '  return G + A;\n'
        '}\n'
        'const G = 2;\n'
        'const { X, Y } = obj;\n'
        'let Y = 3;\n';
    expect(
        explainRenderError(
            page, "Cannot access 'G' before initialization (at line 3:10)"),
        allOf(
            startsWith("Cannot access 'G' before initialization"),
            contains("Hint: 'G' is declared at line 5;"),
            contains('move the declaration earlier')));
    expect(explainRenderError(page, "Identifier 'Y' has already been declared"),
        contains("'Y' is declared at lines 6, 7;"));
    expect(explainRenderError(page, 'ReferenceError: nope'),
        'ReferenceError: nope');
    expect(explainRenderError(page, "Cannot access 'Z' before initialization"),
        "Cannot access 'Z' before initialization");
  });

  test('a reply whose text does not match is pointed at the nearest line', () {
    const page =
        'one\n  const material = new THREE.MeshStandardMaterial();\ntwo\n';
    String reply(String before) => jsonEncode({
          'edits': [
            {'before': before, 'after': 'x'}
          ]
        });
    expect(
        nearestLineOf(
            page,
            reply(
                'const  material = new THREE.MeshStandardMaterial({ color: 1 });')),
        isNull);
    expect(
        nearestLineOf(
            page,
            reply(
                '// setup\nconst material = new THREE.MeshStandardMaterial();')),
        2);
    expect(nearestLineOf(page, 'not json at all'), isNull);
    expect(nearestLineOf(page, reply('tiny')), isNull);
  });

  test('a missing import map for three is a known fix, and only that', () {
    const error =
        'Failed to resolve module specifier "three". Relative references must start with either "/", "./", or "../".';
    const page =
        '<html><head><title>x</title></head><body><script type="module">\n'
        "import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.152.0/build/three.module.js';\n"
        "import { OrbitControls } from 'https://cdn.jsdelivr.net/npm/three@0.152.0/examples/jsm/controls/OrbitControls.js';\n"
        '</script></body></html>';
    final fix = knownRepair(page, error)!;
    expect(fix.what, contains('import map'));
    expect(
        fix.source,
        contains('<script type="importmap">{"imports":{"three":'
            '"https://cdn.jsdelivr.net/npm/three@0.152.0/build/three.module.js",'
            '"three/addons/":"https://cdn.jsdelivr.net/npm/three@0.152.0/examples/jsm/"}}</script>'));
    expect(fix.source.indexOf('importmap'),
        lessThan(fix.source.indexOf('type="module"')));
    expect(
        fix.source.replaceFirst(
            RegExp(r'<script type="importmap">.*?</script>\n'), ''),
        page);
    expect(knownRepair(fix.source, error), isNull);
    expect(knownRepair(page, 'ReferenceError: x is not defined'), isNull);
    expect(
        knownRepair('<script type="module">import "three"</script>', error)!
            .source,
        contains('unpkg.com/three@0.160.0'));
    expect(knownRepair('plain text, no head or module script', error), isNull);
  });

  test('a block of lines can be rewritten, and the page cannot be replaced',
      () {
    final lines = [for (var n = 1; n <= 10; n++) 'line $n of the page'];
    String edit(Object edits, {String eol = '\n'}) =>
        applyBenchmarkRepair(lines.join(eol), jsonEncode({'edits': edits}));
    expect(
        edit([
          {'startLine': 3, 'endLine': 4, 'after': 'new three\nnew four\nextra'}
        ]),
        [...lines.take(2), 'new three', 'new four', 'extra', ...lines.skip(4)]
            .join('\n'));
    expect(
        edit([
          {'startLine': 2, 'endLine': 2, 'after': 'two!'}
        ], eol: '\r\n'),
        [lines[0], 'two!', ...lines.skip(2)].join('\r\n'));
    expect(
        edit([
          {'startLine': 10, 'endLine': 10, 'after': 'last'},
          {'before': 'line 1 of', 'after': 'first of'},
        ]),
        ['first of the page', ...lines.sublist(1, 9), 'last'].join('\n'));
    for (final bad in [
      [
        {'startLine': 9, 'endLine': 11, 'after': 'x'}
      ],
      [
        {'startLine': 0, 'endLine': 1, 'after': 'x'}
      ],
      [
        {'startLine': 5, 'endLine': 4, 'after': 'x'}
      ],
      [
        {'startLine': 1, 'endLine': 10, 'after': 'all new'}
      ],
      [
        {'startLine': 3, 'endLine': 5, 'after': 'x'},
        {'before': 'line 4 of the page', 'after': 'y'},
      ],
    ]) {
      expect(() => edit(bad), throwsFormatException, reason: '$bad');
    }
  });

  test('an edit that differs only in whitespace still lands, once', () {
    final pad = '<!-- ${'x' * 400} -->\r\n';
    final source =
        '$pad<script>\r\n  function go() {\r\n    broken();\r\n  }\r\n</script>';
    String fixed(String before) => applyBenchmarkRepair(
        source,
        jsonEncode({
          'edits': [
            {'before': before, 'after': 'fixed();'}
          ]
        }));
    expect(fixed('broken();'), contains('fixed();'));
    expect(fixed('function go() {\n    broken();\n  }'),
        '$pad<script>\r\n  fixed();\r\n</script>');
    expect(() => fixed('function stop() {\n broken();'), throwsFormatException);
    expect(
        () => applyBenchmarkRepair(
            '<p>a  b</p><p>a b</p>',
            jsonEncode({
              'edits': [
                {'before': 'a\nb', 'after': 'c'}
              ]
            })),
        throwsFormatException);
  });

  test('candidate renders take turns instead of sharing the GPU', () async {
    final dir = await Directory.systemTemp.createTemp('repair_render_turns');
    try {
      final store = await AiBenchmarkStore.open(dir.path);
      for (final id in ['pagoda_one', 'pagoda_two', 'pagoda_three']) {
        await store.saveUpload(
            kind: 'pagoda',
            id: id,
            model: id,
            vendor: '',
            description: '',
            bytes: utf8.encode(original));
      }
      var active = 0;
      var most = 0;
      final service = PreviewRenderService(
          dataDir: dir.path,
          fileExists: (_) async => true,
          runProcess: (_, __) async => ProcessResult(1, 0, 'v20', ''),
          startProcess: (_, args) async {
            final id = args[args.indexOf('--ids') + 1];
            active++;
            most = active > most ? active : most;
            final process = FakeRenderProcess();
            unawaited(Future<void>.delayed(const Duration(milliseconds: 60),
                () async {
              process.line('START $id');
              process.line('OK   $id');
              active--;
              await process.exit(0);
            }));
            return process;
          });
      final bytes = utf8.encode(original.replaceFirst('broken()', 'fixed()'));
      final results = await Future.wait([
        for (final id in ['pagoda_one', 'pagoda_two', 'pagoda_three'])
          service.validateRepair(id, bytes),
      ]);
      expect(results, everyElement(isNull));
      expect(most, 1);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test(
      'a model that reasons without answering is cut off, one that answers is not',
      () {
    String line(Map<String, dynamic> delta) => 'data: ${jsonEncode({
              'choices': [
                {'delta': delta}
              ]
            })}';
    final thinking = ChatStreamAccumulator()
      ..addLine(line({'reasoning': 'x' * (kRepairReasoningCharBudget - 10)}));
    expect(repairStreamProblem(thinking), isNull);
    thinking.addLine(line({'reasoning': 'x' * 20}));
    expect(repairStreamProblem(thinking), contains('stopped early'));
    expect(repairStreamProblem(thinking), contains('reasoning effort'));
    final answering = ChatStreamAccumulator()
      ..addLine(line({'reasoning': 'x' * (kRepairReasoningCharBudget * 2)}))
      ..addLine(line({'content': '{"edits":'}));
    expect(repairStreamProblem(answering), isNull);
    final huge = ChatStreamAccumulator()
      ..addLine(line({'content': 'y' * 100001}));
    expect(repairStreamProblem(huge), contains('too large'));
  });

  test('a render error that names a line is turned into the code around it',
      () {
    expect(errorLineOf('Unexpected token (at line 801:22)'), 801);
    expect(errorLineOf('Syntax error at line 12:3: nope'), 12);
    expect(errorLineOf('TimeoutError: no canvas'), isNull);
    final source = [for (var n = 1; n <= 40; n++) 'line $n  '].join('\n');
    final lines = errorLinesOf(source, 20);
    expect(lines.first, {'line': 12, 'text': 'line 12'});
    expect(lines.last, {'line': 28, 'text': 'line 28'});
    expect(errorLinesOf(source, 2).first['line'], 1);
    expect(errorLinesOf(source, 40).last['line'], 40);
    expect(errorLinesOf(source, 41), isEmpty);
    expect(errorLinesOf(source, 0), isEmpty);
  });

  test('price guard handles unknown, free and expensive prices', () {
    expect(() => repairOutputLimit('source', const AiPrice(null, 1), .25),
        throwsArgumentError);
    expect(() => repairOutputLimit('source', const AiPrice(100, 100), .001),
        throwsArgumentError);
    expect(repairOutputLimit('source', const AiPrice(0, 0), .001),
        kRepairMaxOutputTokens);
    expect(repairOutputLimit('source', const AiPrice(1, 2), .25),
        kRepairMaxOutputTokens);
    final tokens = repairOutputLimit('source', const AiPrice(1, 100), .1);
    expect(tokens, lessThan(1000));
    expect((4102 + tokens * 100) / 1000000, lessThanOrEqualTo(.1));
    expect(BenchmarkRepairSettings.validLimit(double.nan), isFalse);
  });

  test(
      'candidate renders use isolated source and preserve live files on success and failure',
      () async {
    final dir = await Directory.systemTemp.createTemp('repair_render_check');
    try {
      final store = await AiBenchmarkStore.open(dir.path);
      await store.saveUpload(
          kind: 'pagoda',
          id: 'pagoda_demo',
          model: 'Original',
          vendor: '',
          description: '',
          bytes: utf8.encode(original));
      var fail = false;
      final service = PreviewRenderService(
          dataDir: dir.path,
          fileExists: (_) async => true,
          runProcess: (_, __) async => ProcessResult(1, 0, 'v20', ''),
          startProcess: (_, args) async {
            final override = args[args.indexOf('--override') + 1];
            expect(override, contains('candidate_'));
            expect(
                await File('$override/uploads/pagoda_demo.html').readAsString(),
                contains('fixed()'));
            final process = FakeRenderProcess();
            scheduleMicrotask(() {
              process.line('START pagoda_demo');
              process.line(
                  fail ? 'FAIL pagoda_demo: Cannot render' : 'OK pagoda_demo');
              unawaited(process.exit(fail ? 1 : 0));
            });
            return process;
          });
      final repaired =
          utf8.encode(original.replaceFirst('broken()', 'fixed()'));
      expect(await service.validateRepair('pagoda_demo', repaired), isNull);
      expect(
          utf8.decode((await store.readScene('pagoda_demo'))!.bytes), original);
      fail = true;
      expect(await service.validateRepair('pagoda_demo', repaired), isNotNull);
      expect(
          utf8.decode((await store.readScene('pagoda_demo'))!.bytes), original);
      expect(
          await Directory('${dir.path}/benchmark_repair_checks')
              .list()
              .toList(),
          isEmpty);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('saves from parallel repairs all land in the roster', () async {
    final dir = await Directory.systemTemp.createTemp('repair_roster_race');
    try {
      final ids = [for (var n = 0; n < 8; n++) 'pagoda_race_$n'];
      await Future.wait([
        for (final id in ids)
          (await AiBenchmarkStore.open(dir.path)).saveUpload(
              kind: 'pagoda',
              id: id,
              model: 'Model $id',
              vendor: '',
              description: '',
              bytes: utf8.encode(original)),
      ]);
      final roster =
          await (await AiBenchmarkStore.open(dir.path)).editableEntries();
      expect(roster.map((e) => e['id']).toSet(), ids.toSet());
    } finally {
      await dir.delete(recursive: true);
    }
  });

  group('on-demand repair endpoints', () {
    late Directory dir;
    late Api api;
    late Store accounts;
    late AiUsageStore usage;
    late AiBenchmarkStore scenes;
    late RepairRenderer renderer;
    late AiPrice? price;
    late int calls;
    late bool failCall;
    late List<Object> busy;
    late String finish;
    late List<String> replies;
    late double callCost;
    late Map<String, dynamic> sent;
    Completer<void>? hold;

    Future<Map<String, dynamic>> request(String method, String path,
        {Object? body, bool admin = true, String? origin}) async {
      final response =
          await api.handler(Request(method, Uri.parse('http://localhost$path'),
              headers: {
                'host': 'localhost',
                if (admin) 'x-admin-key': 'test-admin-key',
                if (body != null) 'content-type': 'application/json',
                'origin': origin ?? 'http://localhost',
              },
              body: body == null ? null : jsonEncode(body)));
      final raw = await response.readAsString();
      return {
        ...(raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>),
        'httpStatus': response.statusCode
      };
    }

    Future<void> save({double limit = .25, String? effort}) async {
      final response = await request(
          'PUT', '/admin/benchmark-banners/repair/settings',
          body: {
            'route': {
              'upstream': 'openrouter',
              'model': 'test/model',
              if (effort != null) 'reasoningEffort': effort,
            },
            'maxCostUsd': limit,
          });
      expect(response['httpStatus'], 200, reason: '$response');
    }

    Future<void> finished() async {
      for (var n = 0;
          n < 100 &&
              api.benchmarkRepairJobs.values.any((j) => j.state == 'running');
          n++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(api.benchmarkRepairJobs.values.any((j) => j.state == 'running'),
          isFalse);
    }

    Future<void> saveModulePage() async {
      await scenes.saveUpload(
          kind: 'pagoda',
          id: 'pagoda_demo',
          model: 'Original model',
          vendor: 'openai',
          description: 'Original description',
          bytes: utf8.encode(
              '<html><head></head><body><canvas></canvas><script type="module">'
              "import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.152.0/build/three.module.js';"
              '</script></body></html>'));
      renderer.recordFailure('pagoda_demo',
          'Failed to resolve module specifier "three". Relative references must start with either "/", "./", or "../".');
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_repair_test');
      accounts = RepairAccounts();
      accounts.userIdByEmail[benchmarkRepairOwner] = 'owner';
      usage = await AiUsageStore.open(dir.path);
      scenes = await AiBenchmarkStore.open(dir.path);
      await scenes.saveUpload(
          kind: 'pagoda',
          id: 'pagoda_demo',
          model: 'Original model',
          vendor: 'openai',
          description: 'Original description',
          bytes: utf8.encode(original));
      renderer = RepairRenderer(dataDir: dir.path);
      renderer.recordFailure(
          'pagoda_demo', 'ReferenceError: broken is not defined');
      price = const AiPrice(1, 2);
      calls = 0;
      failCall = false;
      busy = [];
      finish = 'stop';
      replies = [];
      callCost = .001;
      hold = null;
      api = Api(
          accounts,
          ServerConfig(
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
            openRouterApiKey: 'fake-test-key',
            itadApiKey: null,
            groceriesUrl: '',
            groceriesAdminKey: null,
            artificialAnalysisKey: null,
            repoPath: null,
            wikiDir: null,
            publicUrl: 'http://localhost',
            oauthProviders: const {},
          ),
          Mailer(MailConfig.fromEnvironment(const {})),
          await FamilyStore.open(dir.path),
          await ChatStore.open(dir.path),
          usage,
          await SubwayStore.open(dir.path),
          await RecipeStore.open(dir.path),
          await AiModelCatalogStore.open(dir.path),
          scenes,
          previewRenders: renderer,
          benchmarkRepairPrice: (_) async => price,
          benchmarkRepairCall: (route, body, acc) async {
            calls++;
            sent = body;
            if (hold != null) await hold!.future;
            if (busy.isNotEmpty) {
              final next = busy.removeAt(0);
              if (next is String) {
                acc.addLine('data: ${jsonEncode({
                      'error': {'message': next, 'code': 502}
                    })}');
                return;
              }
              throw next;
            }
            acc.addLine('data: ${jsonEncode({
                  'model': 'actual/model',
                  'usage': {
                    'prompt_tokens': 120,
                    'completion_tokens': 80,
                    'cost': callCost
                  },
                  'choices': [
                    {
                      'delta': {
                        'content':
                            replies.isNotEmpty ? replies.removeAt(0) : reply
                      },
                      'finish_reason': finish
                    }
                  ]
                })}');
            if (failCall) throw const HttpException('Connection failed');
            acc.addLine('data: [DONE]');
          });
      api.benchmarkRepairBusyBackoff = (_) => Duration.zero;
    });
    tearDown(() async {
      await finished();
      await dir.delete(recursive: true);
    });

    test(
        'settings persist without calls and price increases stop before spending',
        () async {
      await save();
      expect(calls, 0);
      final settings = BenchmarkRepairSettings(dir.path);
      expect(settings.route!.model, 'test/model');
      expect(settings.acceptedPrice!.output, 2);
      price = const AiPrice(1, 3);
      expect(
          (await request('POST',
              '/admin/benchmark-banners/repair/pagoda_demo'))['httpStatus'],
          202);
      await finished();
      expect(calls, 0);
      expect(api.benchmarkRepairJobs['pagoda_demo']!.detail,
          contains('price increased'));
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          original);
    });
    test(
        'successful explicit repair credits only owner, backs up and preserves metadata',
        () async {
      await save();
      expect(
          (await request('POST',
              '/admin/benchmark-banners/repair/pagoda_demo'))['httpStatus'],
          202);
      await finished();
      expect(calls, 1);
      expect(sent, isNot(contains('tools')));
      expect(sent['messages'], hasLength(2));
      expect((sent['provider'] as Map)['max_price'],
          {'prompt': 1.0, 'completion': 2.0});
      expect(api.benchmarkRepairJobs['pagoda_demo']!.state, 'done');
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          contains('fixed()'));
      expect(
          (await scenes.editableEntries()).single['model'], 'Original model');
      final backups =
          await Directory('${dir.path}/benchmark_repairs/pagoda_demo')
              .list()
              .toList();
      expect(await File(backups.single.path).readAsString(), original);
      expect(renderer.rendered, ['pagoda_demo']);
      final call = usage.usageCalls('owner').single;
      expect(call['feature'], 'Benchmark render repair');
      expect(call['model'], 'actual/model');
      expect(call['costUsd'], .001);
      expect(usage.usageCalls('other'), isEmpty);
      expect(usage.tokensUsed('owner', const Duration(days: 7)), 0);
    });
    test('a recorded error outlives the render job that hit it', () async {
      await save();
      renderer.status.items = [
        PreviewRenderItem('pagoda_other')..state = 'ok',
      ];
      final started =
          await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      expect(started['httpStatus'], 202, reason: '$started');
      await finished();
      expect(calls, 1);
      expect(api.benchmarkRepairJobs['pagoda_demo']!.state, 'done');
    });
    test('the model is shown the line a syntax error is on', () async {
      await save();
      renderer.syntax = (bytes) => utf8.decode(bytes).contains('broken()')
          ? (line: 1, column: 40, message: "Unexpected token '.'")
          : null;
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final user =
          jsonDecode((sent['messages'] as List).last['content'] as String)
              as Map;
      expect(user['renderError'], startsWith('Syntax error at line 1:40'));
      expect(user['renderError'], contains('ReferenceError: broken'));
      expect(user['errorLine'], 1);
      final shown = (user['errorLines'] as List).cast<Map>();
      expect(shown.map((l) => l['line']).contains(1), isTrue);
      expect(shown.firstWhere((l) => l['line'] == 1)['text'],
          utf8.decode(utf8.encode(original)).split('\n')[0].trimRight());
      expect(api.benchmarkRepairJobs['pagoda_demo']!.state, 'done');
    });
    test('an oversized source says how big it is', () async {
      await save();
      await scenes.saveUpload(
          kind: 'pagoda',
          id: 'pagoda_demo',
          model: 'Original model',
          vendor: 'openai',
          description: 'Original description',
          bytes: utf8.encode(
              '<html><body><canvas></canvas><script>${'a' * 250000}</script></body></html>'));
      final result =
          await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      expect(result['httpStatus'], 409);
      expect(result['error'], 'source_size');
      expect(result['message'], contains('250 kB'));
      expect(result['message'], contains('200 kB'));
      expect(calls, 0);
    });
    test('a missing import map is added without asking the model', () async {
      await save();
      await saveModulePage();
      final started =
          await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      expect(started['httpStatus'], 202, reason: '$started');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'done', reason: job.detail);
      expect(job.detail, contains('automatically'));
      expect(calls, 0);
      expect(usage.usageCalls('owner'), isEmpty);
      final live = utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes);
      expect(
          live,
          contains(
              '"three":"https://cdn.jsdelivr.net/npm/three@0.152.0/build/three.module.js"'));
      expect(renderer.rendered, ['pagoda_demo']);
    });
    test('when the known fix is not enough the model carries on from there',
        () async {
      await save();
      await saveModulePage();
      renderer.validationError = 'initThree.js is not a function';
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(calls, kRepairMaxAttempts);
      final user =
          jsonDecode((sent['messages'] as List).last['content'] as String)
              as Map;
      expect(
          (user['previousAttempts'] as List).first, contains('Automatic fix'));
      expect(user['html'], contains('importmap'));
    });
    test('a fix that trades one error for another gets another attempt',
        () async {
      await save();
      String edit(String before, String after) => jsonEncode({
            'edits': [
              {'before': before, 'after': after}
            ]
          });
      replies = [edit('broken()', 'oops()'), edit('oops()', 'fixed()')];
      renderer.syntax = (bytes) => utf8.decode(bytes).contains('oops()')
          ? (
              line: 1,
              column: 30,
              message: "Identifier 'x' has already been declared"
            )
          : null;
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'done', reason: job.detail);
      expect(job.detail, contains('attempt 2'));
      expect(calls, 2);
      final user =
          jsonDecode((sent['messages'] as List).last['content'] as String)
              as Map;
      expect(user['renderError'], startsWith('Syntax error at line 1:30'));
      expect(user['originalError'], 'ReferenceError: broken is not defined');
      expect(user['previousAttempts'], hasLength(1));
      expect(user['html'], contains('oops()'));
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          contains('fixed()'));
      final backups =
          await Directory('${dir.path}/benchmark_repairs/pagoda_demo')
              .list()
              .toList();
      expect(await File(backups.single.path).readAsString(), original);
      expect(usage.usageCalls('owner'), hasLength(2));
    });
    test('an edit that unbalances the brackets is dropped, not built on',
        () async {
      await save();
      String edit(String before, String after) => jsonEncode({
            'edits': [
              {'before': before, 'after': after}
            ]
          });
      replies = [
        edit('broken();', 'fixed(); function f() {'),
        edit('broken()', 'fixed()'),
      ];
      renderer.syntax = (bytes) => utf8.decode(bytes).contains('function f')
          ? (line: 1, column: 99, message: 'Unexpected end of input')
          : null;
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'done', reason: job.detail);
      expect(calls, 2);
      final user =
          jsonDecode((sent['messages'] as List).last['content'] as String)
              as Map;
      expect(user['html'], original);
      expect(user['renderError'], 'ReferenceError: broken is not defined');
      expect((user['previousAttempts'] as List).single,
          contains('unbalanced the brackets'));
    });
    test('a reply that cannot be applied is retried with the real error shown',
        () async {
      await save();
      replies = [
        jsonEncode({
          'edits': [
            {'before': 'not in the page', 'after': 'x'}
          ]
        }),
      ];
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(api.benchmarkRepairJobs['pagoda_demo']!.state, 'done');
      expect(calls, 2);
      final user =
          jsonDecode((sent['messages'] as List).last['content'] as String)
              as Map;
      expect(user['renderError'], 'ReferenceError: broken is not defined');
      expect((user['previousAttempts'] as List).single,
          contains('could not be applied'));
    });
    test('the cost limit covers all attempts together', () async {
      await save();
      callCost = .2;
      renderer.validationError = 'Still cannot render';
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'failed');
      expect(calls, 2);
      expect(job.detail, contains('repair limit'));
      expect(job.costUsd, closeTo(.4, 1e-9));
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          original);
    });
    test('a repair that still does not parse fails without opening a browser',
        () async {
      await save();
      renderer.syntax = (bytes) => utf8.decode(bytes).contains('fixed()')
          ? (line: 4, column: 9, message: "Unexpected token '>'")
          : null;
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'failed');
      expect(
          job.detail, contains('Gave up after $kRepairMaxAttempts attempts'));
      expect(renderer.validations, 0);
      expect(calls, kRepairMaxAttempts);
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          original);
      expect(renderer.rendered, isEmpty);
    });
    test('repairs ask for low reasoning unless the settings say otherwise',
        () async {
      await save();
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(sent['reasoning'], {'effort': 'low'});
      expect(sent['provider'], isNot(contains('require_parameters')));
      expect((sent['provider'] as Map)['max_price'],
          {'prompt': 1.0, 'completion': 2.0});
      for (final (effort, expected) in [
        ('none', {'enabled': false}),
        ('high', {'effort': 'high'}),
      ]) {
        await save(effort: effort);
        final saved =
            await request('GET', '/admin/benchmark-banners/repair/settings');
        expect(saved['route']['reasoningEffort'], effort);
        renderer.recordFailure(
            'pagoda_demo', 'ReferenceError: broken is not defined');
        await scenes.saveUpload(
            kind: 'pagoda',
            id: 'pagoda_demo',
            model: 'Original model',
            vendor: 'openai',
            description: 'Original description',
            bytes: utf8.encode(original));
        await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
        await finished();
        expect(sent['reasoning'], expected, reason: effort);
      }
    });
    test('a model that runs out of tokens is told so, with the room it had',
        () async {
      await save();
      finish = 'length';
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(sent['max_tokens'], kRepairMaxOutputTokens);
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'failed');
      expect(job.detail, contains('ran out of its $kRepairMaxOutputTokens'));
      expect(job.detail, isNot(contains('Bad state')));
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          original);
    });
    test('a failed candidate keeps the live file and still records paid usage',
        () async {
      await save();
      renderer.validationError = 'Still cannot render';
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(api.benchmarkRepairJobs['pagoda_demo']!.state, 'failed');
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          original);
      expect(renderer.rendered, isEmpty);
      expect(calls, kRepairMaxAttempts);
      expect(usage.usageCalls('owner'), hasLength(kRepairMaxAttempts));
    });
    test('provider failure is not retried and reported usage is retained',
        () async {
      await save();
      failCall = true;
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(calls, 1);
      expect(renderer.validations, 0);
      expect(usage.usageCalls('owner'), hasLength(1));
    });
    test('a busy provider is asked again without using up an attempt',
        () async {
      await save();
      busy = [
        'Upstream error from Nvidia: Service temporarily overloaded',
        RepairHttpStatus(429, 'Rate limited'),
        const HttpException('Connection closed while receiving data'),
      ];
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'done', reason: job.detail);
      expect(job.detail, contains('attempt 1'));
      expect(calls, 4);
    });
    test('a provider that stays busy fails with what it last said', () async {
      await save();
      busy = List<Object>.filled(
          kRepairBusyRetries + 1, 'Service temporarily overloaded',
          growable: true);
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'failed');
      expect(job.detail,
          contains('stayed busy through ${kRepairBusyRetries + 1} tries'));
      expect(job.detail, contains('temporarily overloaded'));
      expect(calls, kRepairBusyRetries + 1);
      expect(utf8.decode((await scenes.readScene('pagoda_demo'))!.bytes),
          original);
    });
    test('a request the provider rejects is not sent again', () async {
      await save();
      busy = [RepairHttpStatus(400, 'Bad request')];
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      final job = api.benchmarkRepairJobs['pagoda_demo']!;
      expect(job.state, 'failed');
      expect(job.detail, contains('HTTP 400: Bad request'));
      expect(calls, 1);
    });
    test(
        'unknown prices and insufficient budget block the model before any call',
        () async {
      await save(limit: .001);
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(calls, 0);
      expect(api.benchmarkRepairJobs['pagoda_demo']!.detail,
          contains('price guard'));
      await save();
      price = null;
      await request('POST', '/admin/benchmark-banners/repair/pagoda_demo');
      await finished();
      expect(calls, 0);
      expect(api.benchmarkRepairJobs['pagoda_demo']!.detail,
          contains('pricing is unavailable'));
    });
    test(
        'authorization, origin, diagnostic and owner are enforced before calls',
        () async {
      await save();
      expect(
          (await request('POST', '/admin/benchmark-banners/repair/pagoda_demo',
              admin: false))['httpStatus'],
          302);
      expect(
          (await request('POST', '/admin/benchmark-banners/repair/pagoda_demo',
              origin: 'https://evil.example'))['httpStatus'],
          403);
      renderer.recordFailure('pagoda_demo', null);
      expect(
          (await request('POST',
              '/admin/benchmark-banners/repair/pagoda_demo'))['httpStatus'],
          409);
      accounts.userIdByEmail.clear();
      expect(
          (await request('POST',
              '/admin/benchmark-banners/repair/pagoda_demo'))['httpStatus'],
          409);
      expect(calls, 0);
    });
    test('parallel repair, settings and render requests are blocked', () async {
      await save();
      hold = Completer<void>();
      final results = await Future.wait([
        request('POST', '/admin/benchmark-banners/repair/pagoda_demo'),
        request('POST', '/admin/benchmark-banners/repair/pagoda_demo'),
      ]);
      expect(results.map((r) => r['httpStatus']).toSet(), {202, 409});
      expect(
          (await request(
              'POST', '/admin/benchmark-banners/render'))['httpStatus'],
          409);
      expect(
          (await request('PUT', '/admin/benchmark-banners/repair/settings',
              body: {}))['httpStatus'],
          409);
      hold!.complete();
      await finished();
      expect(calls, 1);
    });

    group('repair all', () {
      Future<List<String>> failScenes(int extra) async {
        final ids = ['pagoda_demo'];
        for (var n = 1; n <= extra; n++) {
          final id = 'pagoda_extra_$n';
          await scenes.saveUpload(
              kind: 'pagoda',
              id: id,
              model: 'Extra model $n',
              vendor: 'openai',
              description: '',
              bytes: utf8.encode(original));
          ids.add(id);
        }
        for (final id in ids) {
          renderer.recordFailure(id, 'ReferenceError: broken is not defined');
        }
        renderer.recordFailure('cathedral_glb', 'invalid GLB');
        return ids;
      }

      Future<void> allDone() async {
        for (var n = 0; n < 300 && api.benchmarkRepairAll.running; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(api.benchmarkRepairAll.running, isFalse);
      }

      Future<void> until(bool Function() ready) async {
        for (var n = 0; n < 300 && !ready(); n++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(ready(), isTrue);
      }

      test('repairs three at a time and starts the next as each one finishes',
          () async {
        await save();
        final ids = await failScenes(4);
        hold = Completer<void>();
        final started =
            await request('POST', '/admin/benchmark-banners/repair-all');
        expect(started['httpStatus'], 202);
        expect(started['count'], 5);
        expect(started['workers'], 3);
        await until(() => calls == 3);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(calls, 3);
        expect(api.benchmarkRepairAll.queue, hasLength(2));
        final status = await request('GET', '/admin/benchmark-banners/status');
        expect(status['repairAll']['running'], isTrue);
        expect(status['repairAll']['queued'], hasLength(2));
        expect(status['repairModel']['model'], 'test/model');
        expect(
            (status['repairs'] as List).where((j) => j['state'] == 'running'),
            hasLength(3));
        hold!.complete();
        await allDone();
        expect(calls, 5);
        expect([
          for (final j in api.benchmarkRepairJobs.values)
            if (j.state != 'done') '${j.id}: ${j.state} ${j.detail}'
        ], isEmpty);
        expect(api.benchmarkRepairJobs.keys.toSet(), ids.toSet());
        expect(
            api.benchmarkRepairJobs['pagoda_extra_2']!.name, 'Extra model 2');
        expect(api.benchmarkRepairJobs['pagoda_demo']!.finishedAtMs, isNotNull);
        expect(renderer.rendered.toSet(), ids.toSet());
        expect(usage.usageCalls('owner'), hasLength(5));
      });

      test(
          'a scene that never renders gets all its attempts, then the run moves on',
          () async {
        await save();
        await failScenes(3);
        renderer.validationError = 'Still cannot render';
        await request('POST', '/admin/benchmark-banners/repair-all');
        await allDone();
        expect(calls, 4 * kRepairMaxAttempts);
        expect(api.benchmarkRepairJobs.values.map((j) => j.state).toSet(),
            {'failed'});
        expect(renderer.rendered, isEmpty);
        expect(api.benchmarkRepairAll.finishedAtMs, isNotNull);
      });

      test('stop lets the repairs under way finish and drops the rest',
          () async {
        await save();
        await failScenes(4);
        hold = Completer<void>();
        await request('POST', '/admin/benchmark-banners/repair-all');
        await until(() => calls == 3);
        final stopped =
            await request('POST', '/admin/benchmark-banners/repair-all/stop');
        expect(stopped['stopped'], isTrue);
        hold!.complete();
        await allDone();
        expect(calls, 3);
        expect(api.benchmarkRepairAll.stopped, isTrue);
        expect(api.benchmarkRepairJobs, hasLength(3));
        final dismissed = await request(
            'POST', '/admin/benchmark-banners/repair-all/dismiss');
        expect(dismissed['httpStatus'], 200);
        expect(api.benchmarkRepairJobs, isEmpty);
        expect(api.benchmarkRepairAll.startedAtMs, isNull);
      });

      test(
          'needs a chosen model, failed scenes, an idle service and the origin',
          () async {
        expect(
            (await request(
                'POST', '/admin/benchmark-banners/repair-all'))['error'],
            'no_model');
        await save();
        renderer.recordFailure('pagoda_demo', null);
        expect(
            (await request(
                'POST', '/admin/benchmark-banners/repair-all'))['error'],
            'no_failures');
        await failScenes(1);
        expect(
            (await request('POST', '/admin/benchmark-banners/repair-all',
                origin: 'http://evil.example'))['httpStatus'],
            403);
        expect(
            (await request('POST', '/admin/benchmark-banners/repair-all',
                admin: false))['httpStatus'],
            302);
        hold = Completer<void>();
        expect(
            (await request(
                'POST', '/admin/benchmark-banners/repair-all'))['httpStatus'],
            202);
        await until(() => calls >= 1);
        for (final path in [
          '/admin/benchmark-banners/repair-all',
          '/admin/benchmark-banners/repair/pagoda_demo',
          '/admin/benchmark-banners/render',
        ]) {
          expect((await request('POST', path))['httpStatus'], 409,
              reason: path);
        }
        expect(
            (await request('PUT', '/admin/benchmark-banners/repair/settings',
                body: {}))['httpStatus'],
            409);
        hold!.complete();
        await allDone();
        expect(calls, 2);
      });
    });
  });
}

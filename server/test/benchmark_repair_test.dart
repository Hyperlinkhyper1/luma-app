import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_price_guard.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
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
  test('price guard handles unknown, free and expensive prices', () {
    expect(() => repairOutputLimit('source', const AiPrice(null, 1), .25),
        throwsArgumentError);
    expect(() => repairOutputLimit('source', const AiPrice(100, 100), .001),
        throwsArgumentError);
    expect(repairOutputLimit('source', const AiPrice(0, 0), .001), 8192);
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

    Future<void> save({double limit = .25}) async {
      final response = await request(
          'PUT', '/admin/benchmark-banners/repair/settings',
          body: {
            'route': {'upstream': 'openrouter', 'model': 'test/model'},
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
            acc.addLine('data: ${jsonEncode({
                  'model': 'actual/model',
                  'usage': {
                    'prompt_tokens': 120,
                    'completion_tokens': 80,
                    'cost': .001
                  },
                  'choices': [
                    {
                      'delta': {'content': reply},
                      'finish_reason': 'stop'
                    }
                  ]
                })}');
            if (failCall) throw const HttpException('Connection failed');
            acc.addLine('data: [DONE]');
          });
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
      expect(usage.usageCalls('owner'), hasLength(1));
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

      test('a scene that still fails is not retried, and the run ends',
          () async {
        await save();
        await failScenes(3);
        renderer.validationError = 'Still cannot render';
        await request('POST', '/admin/benchmark-banners/repair-all');
        await allDone();
        expect(calls, 4);
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

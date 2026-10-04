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
      renderer.status.items = [
        PreviewRenderItem('pagoda_demo')
          ..state = 'failed'
          ..detail = 'ReferenceError: broken is not defined'
      ];
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
      renderer.status.items.clear();
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
  });
}

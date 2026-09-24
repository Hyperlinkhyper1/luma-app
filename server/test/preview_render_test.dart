import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/preview_render.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Stands in for the node render tool: the test writes its stdout lines and
/// decides when it exits.
class FakeRenderProcess implements Process {
  final _out = StreamController<List<int>>();
  final _err = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  void line(String text) => _out.add(utf8.encode('$text\n'));
  void errLine(String text) => _err.add(utf8.encode('$text\n'));

  Future<void> exit(int code) async {
    await _out.close();
    await _err.close();
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => _err.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    unawaited(exit(-15));
    return true;
  }

  @override
  int get pid => 1;
  @override
  IOSink get stdin => throw UnimplementedError();
}

/// Covers the admin dashboard's banner buttons: which scenes a job picks,
/// how the renderer's progress lines become per-scene status, and the
/// endpoints the Control panel drives.
void main() {
  late Directory dir;
  late Directory seed;
  late List<List<String>> launches;
  late FakeRenderProcess process;
  late bool toolPresent;

  PreviewRenderService service() => PreviewRenderService(
        dataDir: dir.path,
        seedDir: seed.path,
        toolScript: '/tool/render_previews.mjs',
        environment: const {},
        fileExists: (_) async => toolPresent,
        runProcess: (exe, args) async => ProcessResult(1, 0, 'v20.0.0', ''),
        startProcess: (exe, args) async {
          launches.add(args);
          return process = FakeRenderProcess();
        },
      );

  /// Lets the stream listeners in the service catch up.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  List<String> idsOf(List<String> args) =>
      args[args.indexOf('--ids') + 1].split(',');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_banner_test');
    seed = await Directory.systemTemp.createTemp('luma_banner_seed');
    await Directory('${seed.path}/scenes').create(recursive: true);
    await Directory('${seed.path}/previews').create(recursive: true);
    await File('${seed.path}/manifest.json').writeAsString(jsonEncode({
      'benchmarks': [
        {'id': 'pagoda_has', 'kind': 'pagoda', 'model': 'Has'},
        {'id': 'pagoda_lacks', 'kind': 'pagoda', 'model': 'Lacks'},
        {'id': 'engine_lacks', 'kind': 'engine', 'model': 'Engine'},
      ],
    }));
    for (final id in ['pagoda_has', 'pagoda_lacks', 'engine_lacks']) {
      await File('${seed.path}/scenes/$id.html').writeAsString('<html></html>');
    }
    await File('${seed.path}/previews/pagoda_has.png').writeAsBytes([1, 2, 3]);
    launches = [];
    toolPresent = true;
  });

  tearDown(() async {
    await dir.delete(recursive: true);
    await seed.delete(recursive: true);
  });

  group('PreviewRenderService', () {
    test('missing renders only scenes without a banner, into the data dir',
        () async {
      final s = service();
      expect(await s.start(PreviewRenderMode.missing), isNull);
      expect(launches, hasLength(1));
      expect(idsOf(launches.single), ['pagoda_lacks', 'engine_lacks']);
      final args = launches.single;
      expect(args[args.indexOf('--root') + 1], seed.path);
      expect(args[args.indexOf('--out') + 1],
          endsWith('${AiBenchmarkStore.dirName}${Platform.pathSeparator}previews'));
      expect(s.status.running, isTrue);
      expect(s.status.items.map((i) => i.state), ['queued', 'queued']);
    });

    test('all re-renders every scene, including ones with a banner',
        () async {
      final s = service();
      expect(await s.start(PreviewRenderMode.all), isNull);
      expect(idsOf(launches.single),
          ['pagoda_has', 'pagoda_lacks', 'engine_lacks']);
    });

    test('follows the renderer scene by scene', () async {
      final s = service();
      await s.start(PreviewRenderMode.missing);
      process.line('capturing 2 scenes with chromium, one at a time');
      process.line('START pagoda_lacks');
      process.line('  framing: perspective, fov 24, distance 120');
      await settle();
      expect(s.status.items.first.state, 'rendering');
      process.line('  daylight at luma 0.80');
      process.line('OK   pagoda_lacks');
      process.line('START engine_lacks');
      process.line('FAIL engine_lacks: TimeoutError: no canvas');
      await process.exit(0);
      await settle();

      expect(s.status.running, isFalse);
      expect(s.status.error, isNull);
      expect(s.status.finishedAtMs, isNotNull);
      final first = s.status.items.first;
      expect(first.state, 'ok');
      expect(first.detail, contains('fov 24'));
      expect(first.detail, contains('daylight'));
      expect(s.status.items.last.state, 'failed');
      expect(s.status.items.last.detail, 'TimeoutError: no canvas');
    });

    test('only one job at a time', () async {
      final s = service();
      final both = await Future.wait([
        s.start(PreviewRenderMode.missing),
        s.start(PreviewRenderMode.all),
      ]);
      expect(both.where((m) => m == null), hasLength(1));
      expect(launches, hasLength(1));
    });

    test('says so when there is nothing missing', () async {
      await File('${seed.path}/previews/pagoda_lacks.png').writeAsBytes([1]);
      await File('${seed.path}/previews/engine_lacks.png').writeAsBytes([1]);
      final s = service();
      expect(await s.start(PreviewRenderMode.missing), contains('already'));
      expect(launches, isEmpty);
      expect(s.status.running, isFalse);
      expect(s.status.error, isNull);
    });

    test('refuses to start without the render tool', () async {
      toolPresent = false;
      final s = service();
      final problem = await s.start(PreviewRenderMode.missing);
      expect(problem, contains('not found'));
      expect(s.status.error, problem);
      expect(s.status.running, isFalse);
      expect(launches, isEmpty);
    });

    test('stop kills the renderer and skips what is left', () async {
      final s = service();
      await s.start(PreviewRenderMode.all);
      process.line('START pagoda_has');
      process.line('OK   pagoda_has');
      process.line('START pagoda_lacks');
      await settle();
      expect(s.stop(), isTrue);
      await settle();
      expect(process.killed, isTrue);
      expect(s.status.running, isFalse);
      expect(s.status.stopped, isTrue);
      expect(s.status.error, isNull);
      expect(s.status.items.map((i) => i.state),
          ['ok', 'skipped', 'skipped']);
    });

    test('a renderer crash is reported', () async {
      final s = service();
      await s.start(PreviewRenderMode.missing);
      process.errLine('\x1B[31mError: Protocol error: Connection closed.\x1B[39m');
      process.errLine('    at async main \x1B[90m(render_previews.mjs:392:20)\x1B[39m');
      await process.exit(1);
      await settle();
      expect(s.status.error, 'Error: Protocol error: Connection closed.');
      expect(s.status.items.every((i) => i.state == 'failed'), isTrue);
    });
  });

  group('admin banner endpoints', () {
    late Handler handler;

    Future<Map<String, dynamic>> call(String method, String path,
        {String key = 'test-admin-key'}) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'x-admin-key': key},
      ));
      final raw = await response.readAsString();
      return {
        ...(raw.isEmpty ? const {} : jsonDecode(raw) as Map<String, dynamic>),
        'httpStatus': response.statusCode,
      };
    }

    setUp(() async {
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
        mistralAgentId: null,
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
        await AiBenchmarkStore.open(dir.path, seedDir: seed.path),
        previewRenders: service(),
      ).handler;
    });

    test('status reports coverage before any job', () async {
      final status = await call('GET', '/admin/benchmark-banners/status');
      expect(status['httpStatus'], 200);
      expect(status['sceneCount'], 3);
      expect(status['missingCount'], 2);
      expect(status['running'], isFalse);
      expect(status['items'], isEmpty);
    });

    test('render all starts a job the status then follows', () async {
      final started =
          await call('POST', '/admin/benchmark-banners/render?mode=all');
      expect(started['httpStatus'], 202);
      expect(started['count'], 3);
      final again =
          await call('POST', '/admin/benchmark-banners/render?mode=missing');
      expect(again['httpStatus'], 409);

      process.line('START pagoda_has');
      await settle();
      final status = await call('GET', '/admin/benchmark-banners/status');
      expect(status['running'], isTrue);
      expect(status['mode'], 'all');
      expect((status['items'] as List).first,
          {'id': 'pagoda_has', 'state': 'rendering', 'detail': ''});

      final stop = await call('POST', '/admin/benchmark-banners/stop');
      expect(stop['stopped'], isTrue);
    });

    test('render missing is the default mode', () async {
      final started = await call('POST', '/admin/benchmark-banners/render');
      expect(started['httpStatus'], 202);
      expect(idsOf(launches.single), ['pagoda_lacks', 'engine_lacks']);
      await process.exit(0);
    });

    test('a missing render tool is a 503 with the reason', () async {
      toolPresent = false;
      final result = await call('POST', '/admin/benchmark-banners/render');
      expect(result['httpStatus'], 503);
      expect(result['message'], contains('not found'));
    });

    test('serves a scene banner to the dashboard', () async {
      final response = await handler(Request(
        'GET',
        Uri.parse('http://localhost/admin/benchmark-banners/image/pagoda_has'),
        headers: {'x-admin-key': 'test-admin-key'},
      ));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      expect(await response.read().expand((b) => b).toList(), [1, 2, 3]);
      final missing =
          await call('GET', '/admin/benchmark-banners/image/pagoda_lacks');
      expect(missing['httpStatus'], 404);
    });

    test('needs the admin key', () async {
      final result = await call('POST', '/admin/benchmark-banners/render',
          key: 'wrong');
      expect(result['httpStatus'], 401);
      expect(launches, isEmpty);
    });
  });
}

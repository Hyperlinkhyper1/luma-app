import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Covers the one thing that must never regress here: the admin dashboard's
/// deploy button refuses outright — rather than running a broken shell
/// command — when LUMA_REPO_PATH isn't set. The actual `docker compose`
/// deploy itself needs a live Docker daemon and isn't something a unit test
/// can exercise; see Api._adminDeploy's doc comment for what it runs and why.
void main() {
  group('admin deploy gate', () {
    late Directory dir;
    late Handler handler;
    late Store store;

    Future<Handler> buildHandler({String? repoPath}) async {
      final config = ServerConfig(
        port: 0,
        dataDir: dir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(hours: 24),
        approvalMode: ApprovalMode.open,
        adminKey: 'test-admin-key',
        mistralApiKey: null,
        mistralAgentId: null,
        googleApiKey: null,
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: repoPath,
        wikiDir: null,
        publicUrl: 'https://sync.example.com',
        oauthProviders: const {},
      );
      return Api(
        store,
        config,
        Mailer(MailConfig.fromEnvironment(const {})),
        await FamilyStore.open(dir.path),
        await ChatStore.open(dir.path),
        await AiUsageStore.open(dir.path),
        await SubwayStore.open(dir.path),
        await RecipeStore.open(dir.path),
        await AiModelCatalogStore.open(dir.path),
      ).handler;
    }


    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_deploy_test');
      store = await Store.open(dir.path);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> post(String path) async {
      final response = await handler(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        headers: {'x-admin-key': 'test-admin-key'},
      ));
      final raw = await response.readAsString();
      return {
        ...(raw.isEmpty ? const {} : jsonDecode(raw) as Map<String, dynamic>),
        'httpStatus': response.statusCode,
      };
    }

    Future<Map<String, dynamic>> get(String path) async {
      final response = await handler(Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: {'x-admin-key': 'test-admin-key'},
      ));
      final raw = await response.readAsString();
      return {
        ...(raw.isEmpty ? const {} : jsonDecode(raw) as Map<String, dynamic>),
        'httpStatus': response.statusCode,
      };
    }

    test('refuses to deploy when LUMA_REPO_PATH is unset', () async {
      handler = await buildHandler(repoPath: null);
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 404);
      expect(result['error'], 'not_configured');
    });

    test('refuses to deploy when LUMA_REPO_PATH is blank', () async {
      handler = await buildHandler(repoPath: '');
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 404);
      expect(result['error'], 'not_configured');
    });

    test('the status endpoint reports whether the button is configured',
        () async {
      handler = await buildHandler(repoPath: null);
      final unset = await get('/admin/deploy/status');
      expect(unset['repoPathConfigured'], isFalse);

      handler = await buildHandler(repoPath: '/home/example/luma-app');
      final set = await get('/admin/deploy/status');
      expect(set['repoPathConfigured'], isTrue);
    });

    // deploy-watcher.sh (running on the host, outside any container) is
    // what actually does the git pull + rebuild — this process only ever
    // drops a request file for it to pick up. See Api._adminDeploy's doc
    // comment for why: running `docker compose up -d --build` on this very
    // container from inside itself kills the process driving the recreate
    // before it starts the new container.
    test('a deploy request drops a request file rather than running '
        'anything itself', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 200);
      expect(result['started'], isTrue);
      expect(await File('${dir.path}/deploy.request').exists(), isTrue);
    });

    test('refuses a second deploy while the watcher\'s PID file is present',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await File('${dir.path}/deploy.pid').writeAsString('12345');
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 409);
      expect(result['error'], 'deploy_running');
    });

    test('status reflects the watcher\'s PID file and log, not this '
        'process\'s own state', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');

      final idle = await get('/admin/deploy/status');
      expect(idle['running'], isFalse);
      expect(idle['log'], '');

      await File('${dir.path}/deploy.pid').writeAsString('12345');
      await File('${dir.path}/deploy.log').writeAsString('git pull...\n');
      final active = await get('/admin/deploy/status');
      expect(active['running'], isTrue);
      expect(active['log'], 'git pull...\n');
    });

    // Whether a deploy worked is the exit code the watcher records, never
    // something guessed from the log text — a `git pull` that aborted on
    // local changes reads as perfectly calm prose.
    test('status reports success and failure from the recorded exit code',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');

      final unknown = await get('/admin/deploy/status');
      expect(unknown['ok'], isNull);
      expect(unknown['exitCode'], isNull);

      await File('${dir.path}/deploy.status').writeAsString('0\n');
      final good = await get('/admin/deploy/status');
      expect(good['ok'], isTrue);
      expect(good['exitCode'], 0);

      await File('${dir.path}/deploy.status').writeAsString('1\n');
      await File('${dir.path}/deploy.log')
          .writeAsString('error: Your local changes would be overwritten\n');
      final bad = await get('/admin/deploy/status');
      expect(bad['ok'], isFalse);
      expect(bad['exitCode'], 1);
    });

    test('a finished run\'s exit code is hidden while the next one runs',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await File('${dir.path}/deploy.status').writeAsString('0\n');
      await File('${dir.path}/deploy.pid').writeAsString('12345');

      final running = await get('/admin/deploy/status');
      expect(running['running'], isTrue);
      expect(running['ok'], isNull);
    });

    // The dashboard reads the log to decide how the deploy went, so the
    // previous run's output must not be left lying around — otherwise a
    // request nothing picks up looks like a deploy that finished instantly.
    test('requesting a deploy clears the previous run\'s log and status',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await File('${dir.path}/deploy.log').writeAsString('old output\n');
      await File('${dir.path}/deploy.status').writeAsString('1\n');

      expect((await post('/admin/deploy'))['httpStatus'], 200);
      expect(await File('${dir.path}/deploy.log').exists(), isFalse);
      expect(await File('${dir.path}/deploy.status').exists(), isFalse);

      final status = await get('/admin/deploy/status');
      expect(status['log'], '');
      expect(status['ok'], isNull);
      expect(status['pending'], isTrue);
    });

    // A watcher killed mid-deploy (host reboot, systemctl stop) leaves its
    // PID file behind. Without an age check that debris refuses every later
    // deploy forever.
    test('a stale PID file does not block deploys for good', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      final pidFile = File('${dir.path}/deploy.pid');
      await pidFile.writeAsString('12345');
      pidFile.setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 6)));

      expect((await get('/admin/deploy/status'))['running'], isFalse);
      expect((await post('/admin/deploy'))['httpStatus'], 200);
      expect(await pidFile.exists(), isFalse);
    });

    test('the watcher counts as alive only while its heartbeat is fresh',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      expect((await get('/admin/deploy/status'))['watcherAlive'], isFalse);

      final beat = File('${dir.path}/deploy.watcher');
      await beat.writeAsString('');
      expect((await get('/admin/deploy/status'))['watcherAlive'], isTrue);

      beat.setLastModifiedSync(
          DateTime.now().subtract(const Duration(minutes: 5)));
      expect((await get('/admin/deploy/status'))['watcherAlive'], isFalse);
    });
  });
}

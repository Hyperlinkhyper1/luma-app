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
/// can exercise; see DeployConsole's doc comment for what it runs and why.
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
        itadApiKey: null,
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


    /// Writes [name] on the shared volume, optionally backdated so the
    /// freshness checks can be exercised.
    Future<File> volumeFile(String name, String content,
        {Duration? age}) async {
      final file = File('${dir.path}/$name');
      await file.writeAsString(content);
      if (age != null) {
        file.setLastModifiedSync(DateTime.now().subtract(age));
      }
      return file;
    }

    Future<String> phase() async =>
        (await get('/admin/deploy/status'))['phase'] as String;

    test('refuses to deploy when LUMA_REPO_PATH is unset', () async {
      handler = await buildHandler(repoPath: null);
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 404);
      expect(result['error'], 'not_configured');
      expect(await phase(), 'notConfigured');
    });

    test('refuses to deploy when LUMA_REPO_PATH is blank', () async {
      handler = await buildHandler(repoPath: '');
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 404);
      expect(result['error'], 'not_configured');
      expect(await phase(), 'notConfigured');
    });

    // deploy-watcher.sh (running on the host, outside any container) is what
    // actually does the git pull + rebuild — this process only ever drops a
    // request file for it to pick up. See DeployConsole's doc comment for
    // why: running `docker compose up -d --build` on this very container
    // from inside itself kills the process driving the recreate before it
    // ever starts the new container.
    test(
        'a deploy request drops a request file rather than running anything '
        'itself', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await volumeFile('deploy.watcher', '');

      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 200);
      expect(result['phase'], 'queued');
      expect(await File('${dir.path}/deploy.request').exists(), isTrue);
      expect(await phase(), 'queued');
    });

    // A request nobody can claim is its own phase, not a timeout. The
    // browser used to discover this by giving up after 30 polls.
    test('a request with no watcher alive is stalled, not queued', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');

      final result = await post('/admin/deploy');
      expect(result['phase'], 'stalled');
      expect(result['watcherAlive'], isFalse);
      expect(await phase(), 'stalled');
    });

    test('refuses a second deploy while the lock is fresh', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await volumeFile('deploy.lock', '');
      final result = await post('/admin/deploy');
      expect(result['httpStatus'], 409);
      expect(result['error'], 'deploy_running');
    });

    test(
        "status reflects the watcher's lock and log, not this process's own "
        'state', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');

      expect(await phase(), 'idle');
      expect((await get('/admin/deploy/status'))['log'], '');

      await volumeFile('deploy.lock', '');
      await volumeFile('deploy.log', 'git pull...\n');
      final active = await get('/admin/deploy/status');
      expect(active['phase'], 'running');
      expect(active['log'], 'git pull...\n');
    });

    // Whether a deploy worked is the exit code the watcher records, never
    // something guessed from the log text — a `git pull` that aborted on
    // local changes reads as perfectly calm prose.
    test('status reports success and failure from the recorded exit code',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');

      final unknown = await get('/admin/deploy/status');
      expect(unknown['phase'], 'idle');
      expect(unknown['exitCode'], isNull);

      await volumeFile('deploy.status', '0\n');
      final good = await get('/admin/deploy/status');
      expect(good['phase'], 'succeeded');
      expect(good['exitCode'], 0);

      await volumeFile('deploy.status', '1\n');
      await volumeFile(
          'deploy.log', 'error: Your local changes would be overwritten\n');
      final bad = await get('/admin/deploy/status');
      expect(bad['phase'], 'failed');
      expect(bad['exitCode'], 1);
    });

    test("a finished run's exit code is hidden while the next one runs",
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await volumeFile('deploy.status', '0\n');
      await volumeFile('deploy.lock', '');

      final running = await get('/admin/deploy/status');
      expect(running['phase'], 'running');
      expect(running['exitCode'], isNull);
    });

    // deploy-watcher.sh owns every artifact of a run and clears them when it
    // claims the request. This process clearing them too left a window where
    // the request was pending and everything else had been wiped — a state
    // indistinguishable from a deploy that finished instantly, which the
    // browser could only paper over with a timeout.
    test(
        "requesting a deploy leaves the previous run's artifacts to the "
        'watcher', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await volumeFile('deploy.watcher', '');
      await volumeFile('deploy.log', 'old output\n');
      await volumeFile('deploy.status', '1\n');

      expect((await post('/admin/deploy'))['httpStatus'], 200);
      expect(await File('${dir.path}/deploy.log').exists(), isTrue);
      expect(await File('${dir.path}/deploy.status').exists(), isTrue);

      // ...but the queued phase reports neither, so the operator never sees
      // the last run's output attributed to the one they just started.
      final status = await get('/admin/deploy/status');
      expect(status['phase'], 'queued');
      expect(status['log'], '');
      expect(status['exitCode'], isNull);
    });

    // A watcher killed mid-deploy (host reboot, systemctl stop) leaves its
    // lock behind. Without an age check that debris refuses every later
    // deploy forever.
    test('a stale lock does not block deploys for good', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await volumeFile('deploy.lock', '', age: const Duration(hours: 6));

      expect(await phase(), 'idle');
      expect((await post('/admin/deploy'))['httpStatus'], 200);
    });

    // The lock is refreshed by the watcher for the whole run (see
    // refresher_start in deploy-watcher.sh), so a deploy taking longer than
    // the staleness window keeps reporting itself as running instead of
    // silently freeing the button mid-rebuild.
    test('a lock refreshed during a long run keeps reporting running',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      await volumeFile('deploy.lock', '', age: const Duration(hours: 2));
      expect(await phase(), 'idle');

      await volumeFile('deploy.lock', '');
      expect(await phase(), 'running');
    });

    // The button's whole job is to restart this process, so a dashboard
    // session that dies with it makes the deploy fail from the second click
    // onwards: the poll silently 302s to the login form and the POST comes
    // back as HTML, which the panel could only report as "Could not start
    // the deploy".
    test('a dashboard session survives the restart the deploy button causes',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');

      final login = await handler(Request(
        'POST',
        Uri.parse('http://localhost/admin/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'key=test-admin-key',
      ));
      final cookie = login.headers['set-cookie'];
      expect(cookie, isNotNull);
      final token = cookie!.split(';').first.split('=').last;

      // A fresh Api over the same data dir is what a restarted container is.
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      final response = await handler(Request(
        'POST',
        Uri.parse('http://localhost/admin/deploy'),
        headers: {'cookie': 'luma_admin=$token'},
      ));

      expect(response.statusCode, 200,
          reason: 'the session cookie should still be honoured, not sent to '
              '/admin/login');
      expect(jsonDecode(await response.readAsString())['phase'],
          anyOf('queued', 'stalled'));
    });

    test('logging out drops the stored session for good', () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      final login = await handler(Request(
        'POST',
        Uri.parse('http://localhost/admin/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'key=test-admin-key',
      ));
      final token =
          login.headers['set-cookie']!.split(';').first.split('=').last;

      await handler(Request(
        'POST',
        Uri.parse('http://localhost/admin/logout'),
        headers: {'cookie': 'luma_admin=$token'},
      ));

      handler = await buildHandler(repoPath: '/home/example/luma-app');
      final response = await handler(Request(
        'POST',
        Uri.parse('http://localhost/admin/deploy'),
        headers: {'cookie': 'luma_admin=$token'},
      ));
      expect(response.statusCode, 302);
      expect(response.headers['location'], '/admin/login');
    });

    test('the watcher counts as alive only while its heartbeat is fresh',
        () async {
      handler = await buildHandler(repoPath: '/home/example/luma-app');
      expect((await get('/admin/deploy/status'))['watcherAlive'], isFalse);

      await volumeFile('deploy.watcher', '');
      expect((await get('/admin/deploy/status'))['watcherAlive'], isTrue);

      await volumeFile('deploy.watcher', '', age: const Duration(minutes: 5));
      expect((await get('/admin/deploy/status'))['watcherAlive'], isFalse);
    });
  });
}

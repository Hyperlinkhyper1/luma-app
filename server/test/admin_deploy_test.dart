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
  });
}

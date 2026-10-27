import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as c;
import 'package:luma_sync_server/ai_benchmark_store.dart';
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

/// Someone who only knows an email address must not be able to lock its
/// owner out: failed logins count against the guesser's own address.
void main() {
  late Directory dir;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_login_lockout');
    final store = await Store.open(dir.path);
    final config = ServerConfig(
      port: 0,
      dataDir: dir.path,
      allowRegistration: true,
      maxBlobBytes: 1024 * 1024,
      tokenTtl: const Duration(days: 30),
      corsOrigin: '*',
      trustProxy: true,
      verificationTtl: const Duration(hours: 24),
      maxVerificationEmailsPerHour: 50,
      approvalMode: ApprovalMode.open,
      adminKey: null,
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
      clientIpHeader: 'x-luma-client-ip',
    );
    handler = Api(
      store,
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

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  String key(String seed) =>
      base64Encode(c.sha256.convert(utf8.encode(seed)).bytes);

  Future<int> post(String path, Map<String, Object> body, String ip) async {
    final response = await handler(Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json', 'x-luma-client-ip': ip},
      body: jsonEncode(body),
    ));
    return response.statusCode;
  }

  Future<int> login(String ip, {bool right = true}) => post(
      '/api/v1/auth/login',
      {'email': 'victim@example.com', 'authKey': key(right ? 'right' : 'wrong')},
      ip);

  setUp(() async {
    expect(
        await post(
            '/api/v1/auth/register',
            {
              'email': 'victim@example.com',
              'authKey': key('right'),
              'kdfSalt': base64Encode(List.filled(16, 1)),
              'kdfIterations': 210000,
            },
            '198.51.100.1'),
        201);
  });

  test('the guesser locks itself out, not the owner', () async {
    for (var i = 0; i < 10; i++) {
      expect(await login('203.0.113.66', right: false), 401);
    }
    expect(await login('203.0.113.66'), 429);
    expect(await login('198.51.100.20'), 200);
  });

  test('guessing from many addresses still hits a per-account ceiling, '
      'except from where the owner signed in before', () async {
    expect(await login('198.51.100.1'), 200);
    for (var i = 0; i < 50; i++) {
      expect(await login('203.0.113.${i + 1}', right: false), 401);
    }
    expect(await login('192.0.2.200'), 429);
    expect(await login('198.51.100.1'), 200);
  });
}

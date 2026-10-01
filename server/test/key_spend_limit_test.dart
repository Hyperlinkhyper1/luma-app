import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

/// The routes that spend an operator-held upstream key are budgeted per
/// account and server-wide, not just per IP — so a bot rotating addresses
/// can't drain the key. No upstream is configured here: the handlers answer
/// not_configured/plan_required, but the middleware has counted them by then.
void main() {
  late Directory dir;
  late Store store;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_key_spend_test');
    store = await Store.open(dir.path);
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

  String seedUser(String id) {
    final token = 'test-bearer-token-$id-0123456789';
    final user = StoredUser(
      id: id,
      email: '$id@example.com',
      authHash: '',
      authSalt: '',
      kdfSalt: '',
      kdfIterations: 200000,
      quotaBytes: 1024,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    store.usersById[id] = user;
    store.userIdByEmail[user.email] = id;
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    store.sessionsByTokenHash[tokenHash] = StoredSession(
      tokenHash: tokenHash,
      userId: id,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      expiresAtMs:
          DateTime.now().add(const Duration(days: 29)).millisecondsSinceEpoch,
    );
    return token;
  }

  var ipCounter = 0;
  Future<Response> call(String method, String path, {String? token}) async =>
      await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          // A fresh address every call, like a bot rotating proxies.
          'X-Forwarded-For': '10.${ipCounter ~/ 65536 % 256}'
              '.${ipCounter ~/ 256 % 256}.${ipCounter++ % 256}',
        },
        body: method == 'POST' ? jsonEncode({'prompt': 'x'}) : null,
      ));

  test('an account is capped across rotating IPs', () async {
    final token = seedUser('u1');
    for (var i = 0; i < 300; i++) {
      final r = await call('GET', '/api/v1/steam/itad/lookup?appid=570',
          token: token);
      expect(r.statusCode, isNot(429), reason: 'request $i');
    }
    final over =
        await call('GET', '/api/v1/steam/itad/lookup?appid=570', token: token);
    expect(over.statusCode, 429);
    expect(int.parse(over.headers['retry-after']!), greaterThan(0));

    // Another account is unaffected.
    final other = await call('GET', '/api/v1/steam/itad/lookup?appid=570',
        token: seedUser('u2'));
    expect(other.statusCode, isNot(429));
  });

  test('a swarm of accounts hits the server-wide cap', () async {
    for (final id in ['a', 'b']) {
      final token = seedUser(id);
      for (var i = 0; i < 30; i++) {
        final r = await call('POST', '/api/v1/ai/image', token: token);
        expect(r.statusCode, isNot(429), reason: '$id request $i');
      }
    }
    final third = await call('POST', '/api/v1/ai/image', token: seedUser('c'));
    expect(third.statusCode, 429);
  });

  test('tokenless requests never eat into the shared budget', () async {
    for (var i = 0; i < 200; i++) {
      final r = await call('POST', '/api/v1/ai/image');
      expect(r.statusCode, 401);
    }
    final real = await call('POST', '/api/v1/ai/image', token: seedUser('u'));
    expect(real.statusCode, isNot(429));
  });
}

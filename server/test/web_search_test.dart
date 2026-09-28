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

void main() {
  late Directory dir;
  late Store store;
  late HttpServer upstream;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_web_search_test');
    store = await Store.open(dir.path);
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await upstream.close(force: true);
    await dir.delete(recursive: true);
  });

  String seedUser() {
    const token = 'test-web-search-bearer-token';
    final user = StoredUser(
      id: 'u1',
      email: 'alice@example.com',
      authHash: '',
      authSalt: '',
      kdfSalt: '',
      kdfIterations: 200000,
      quotaBytes: 1024,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    store.usersById[user.id] = user;
    store.userIdByEmail[user.email] = user.id;
    final hash = sha256.convert(utf8.encode(token)).toString();
    store.sessionsByTokenHash[hash] = StoredSession(
      tokenHash: hash,
      userId: user.id,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      expiresAtMs:
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
    );
    return token;
  }

  Future<Handler> handler({String? searxngUrl}) async => Api(
        store,
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
          searxngUrl: searxngUrl,
        ),
        Mailer(MailConfig.fromEnvironment(const {})),
        await FamilyStore.open(dir.path),
        await ChatStore.open(dir.path),
        await AiUsageStore.open(dir.path),
        await SubwayStore.open(dir.path),
        await RecipeStore.open(dir.path),
        await AiModelCatalogStore.open(dir.path),
        await AiBenchmarkStore.open(dir.path),
      ).handler;

  Future<Response> search(Handler handler, String? token, Object body) async =>
      await handler(Request(
        'POST',
        Uri.parse('http://localhost/api/v1/ai/web-search'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ));

  test('requires an approved session and configured search backend', () async {
    final token = seedUser();
    final endpoint = await handler();
    expect((await search(endpoint, null, {'query': 'test'})).statusCode, 401);
    expect((await search(endpoint, token, {'query': 'test'})).statusCode, 503);
  });

  test('validates query and returns five bounded source results', () async {
    final token = seedUser();
    final endpoint =
        await handler(searxngUrl: 'http://127.0.0.1:${upstream.port}');
    expect((await search(endpoint, token, {'query': '   '})).statusCode, 400);
    expect(
        (await search(endpoint, token, {'query': List.filled(201, 'x').join()}))
            .statusCode,
        400);

    final upstreamRequest = upstream.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/search');
      expect(
          await utf8.decoder.bind(request).join(), contains('q=Dart+search'));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'results': [
          {'title': 'bad', 'url': 'javascript:alert(1)', 'content': 'ignored'},
          for (var i = 0; i < 7; i++)
            {
              'title': '<b>Result $i</b>',
              'url': 'https://example.com/$i',
              'content': 'a' * 500
            },
        ],
      }));
      await request.response.close();
    });
    final response = await search(endpoint, token, {'query': 'Dart search'});
    await upstreamRequest;
    expect(response.statusCode, 200);
    final results =
        (jsonDecode(await response.readAsString()) as Map)['results'] as List;
    expect(results, hasLength(5));
    expect(results.first['title'], 'Result 0');
    expect((results.first['snippet'] as String).length, lessThanOrEqualTo(321));
  });
}

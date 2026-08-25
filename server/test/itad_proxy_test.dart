import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

/// Covers the part of the ITAD proxy (`/api/v1/steam/itad/*`) that doesn't
/// need a live network call: the operator-key gate, input validation, and
/// that an approved account is required at all. The actual "reach
/// IsThereAnyDeal and return its body" path is the same shared forwarder the
/// Mistral/Google AI proxies already use in production and isn't something a
/// unit test can exercise without a live upstream.
void main() {
  group('ITAD price-history proxy', () {
    late Directory dir;
    late Store store;
    late Handler handler;

    Future<Handler> buildHandler({String? itadApiKey}) async {
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
        adminKey: null,
        mistralApiKey: null,
        mistralAgentId: null,
        googleApiKey: null,
        itadApiKey: itadApiKey,
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: null,
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

    /// Inserts an already-approved account and a live session directly,
    /// bypassing the password/KDF registration handshake — irrelevant to
    /// what this file is testing, which is what happens after auth passes.
    String seedApprovedUser() {
      const token = 'test-bearer-token-0123456789';
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
      final tokenHash = sha256.convert(utf8.encode(token)).toString();
      store.sessionsByTokenHash[tokenHash] = StoredSession(
        tokenHash: tokenHash,
        userId: user.id,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        expiresAtMs:
            DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      return token;
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_itad_test');
      store = await Store.open(dir.path);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> call(
      String method,
      String path, {
      String? token,
      Object? body,
    }) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        body: body == null ? null : jsonEncode(body),
      ));
      final raw = await response.readAsString();
      return {
        ...(raw.isEmpty ? const {} : jsonDecode(raw) as Map<String, dynamic>),
        'httpStatus': response.statusCode,
      };
    }

    test('refuses every route without a bearer token', () async {
      handler = await buildHandler(itadApiKey: 'server-key');
      for (final result in [
        await call('GET', '/api/v1/steam/itad/status'),
        await call('GET', '/api/v1/steam/itad/lookup?appid=570'),
        await call('GET', '/api/v1/steam/itad/history?id=abc12345'),
        await call('POST', '/api/v1/steam/itad/overview',
            body: ['abc12345']),
      ]) {
        expect(result['httpStatus'], 401, reason: '$result');
      }
    });

    test('status reports whether the operator configured a key', () async {
      final token = seedApprovedUser();

      handler = await buildHandler(itadApiKey: null);
      expect((await call('GET', '/api/v1/steam/itad/status', token: token))
          ['configured'], isFalse);

      handler = await buildHandler(itadApiKey: 'server-key');
      expect((await call('GET', '/api/v1/steam/itad/status', token: token))
          ['configured'], isTrue);
    });

    test('every proxy route answers not_configured with no key set',
        () async {
      final token = seedApprovedUser();
      handler = await buildHandler(itadApiKey: null);

      for (final result in [
        await call('GET', '/api/v1/steam/itad/lookup?appid=570',
            token: token),
        await call('GET', '/api/v1/steam/itad/history?id=abc12345',
            token: token),
        await call('POST', '/api/v1/steam/itad/overview',
            token: token, body: ['abc12345']),
      ]) {
        expect(result['httpStatus'], 404, reason: '$result');
        expect(result['error'], 'not_configured');
      }
    });

    test('lookup rejects a non-numeric appid before touching the network',
        () async {
      final token = seedApprovedUser();
      handler = await buildHandler(itadApiKey: 'server-key');

      final result = await call(
          'GET', '/api/v1/steam/itad/lookup?appid=not-a-number',
          token: token);

      expect(result['httpStatus'], 400);
      expect(result['error'], 'bad_request');
    });

    test('history rejects an id that is not ITAD-id-shaped', () async {
      final token = seedApprovedUser();
      handler = await buildHandler(itadApiKey: 'server-key');

      final result = await call(
          'GET', '/api/v1/steam/itad/history?id=<script>alert(1)</script>',
          token: token);

      expect(result['httpStatus'], 400);
      expect(result['error'], 'bad_request');
    });

    test('overview rejects a body that is not 1-5 id strings', () async {
      final token = seedApprovedUser();
      handler = await buildHandler(itadApiKey: 'server-key');

      final tooMany =
          await call('POST', '/api/v1/steam/itad/overview', token: token,
              body: List.generate(6, (i) => 'abc12345$i'));
      expect(tooMany['httpStatus'], 400);

      final wrongType = await call(
          'POST', '/api/v1/steam/itad/overview', token: token,
          body: [123]);
      expect(wrongType['httpStatus'], 400);

      final empty = await call('POST', '/api/v1/steam/itad/overview',
          token: token, body: <String>[]);
      expect(empty['httpStatus'], 400);
    });
  });
}

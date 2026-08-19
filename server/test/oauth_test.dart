import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/oauth.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Signing in with Google or GitHub.
///
/// The behaviour worth pinning down is what happens when the address the
/// provider vouches for already has an account: it must resolve to *that*
/// account rather than a second one, and the passphrase must still be
/// checked — the provider settles who you are, never what decrypts your
/// data.
///
/// The provider round trip itself is replaced by [_FakeOAuthClient]; nothing
/// here touches the network.
class _FakeOAuthClient extends OAuthClient {
  _FakeOAuthClient(this.identity);

  /// What the next code exchange resolves to.
  OAuthIdentity identity;

  /// When set, the exchange throws this instead.
  String? failure;

  int exchanges = 0;

  @override
  Future<OAuthIdentity> fetchIdentity({
    required OAuthProviderSpec spec,
    required OAuthProviderConfig config,
    required String code,
    required String redirectUri,
  }) async {
    exchanges++;
    if (failure != null) throw OAuthException(failure!);
    return identity;
  }
}

void main() {
  group('OAuthClient.pickGithubEmail', () {
    test('prefers the verified primary address', () {
      final picked = OAuthClient.pickGithubEmail([
        {'email': 'Other@Example.com', 'primary': false, 'verified': true},
        {'email': 'Primary@Example.com', 'primary': true, 'verified': true},
      ]);
      expect(picked, 'primary@example.com');
    });

    test('falls back to any other verified address', () {
      final picked = OAuthClient.pickGithubEmail([
        {'email': 'unverified@example.com', 'primary': true, 'verified': false},
        {'email': 'backup@example.com', 'primary': false, 'verified': true},
      ]);
      expect(picked, 'backup@example.com');
    });

    test('never returns an unverified address, even the primary one', () {
      // Anyone can add an address they do not control to a GitHub account.
      // Honouring one would hand them whichever luma account owns it.
      final picked = OAuthClient.pickGithubEmail([
        {'email': 'victim@example.com', 'primary': true, 'verified': false},
      ]);
      expect(picked, isNull);
    });
  });

  group('OAuthFlowStore', () {
    test('polling needs the ticket — the state alone is not enough', () {
      final store = OAuthFlowStore();
      final (flow, ticket) = store.create('google');

      // The state travels through the browser, so treat it as public.
      expect(store.byState(flow.state), same(flow));
      expect(store.byTicket(flow.state), isNull);
      expect(store.byTicket(ticket), same(flow));
    });

    test('a removed flow is gone from both indexes', () {
      final store = OAuthFlowStore();
      final (flow, ticket) = store.create('github');
      store.remove(flow);
      expect(store.byTicket(ticket), isNull);
      expect(store.byState(flow.state), isNull);
    });
  });

  group('OAuth sign-in endpoints', () {
    late Directory dir;
    late Store store;
    late Handler handler;
    late _FakeOAuthClient oauth;

    /// Any 32 bytes work as an auth key here; the server only ever compares
    /// what it was given at registration with what it is given at sign-in.
    String authKey(int fill) => base64Encode(List<int>.filled(32, fill));
    String kdfSalt() => base64Encode(List<int>.filled(16, 7));

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_oauth_test');
      store = await Store.open(dir.path);
      oauth = _FakeOAuthClient(const OAuthIdentity(
        provider: 'google',
        subject: 'google-subject-1',
        email: 'alice@example.com',
        displayName: 'Alice',
      ));
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
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: null,
        wikiDir: null,
        publicUrl: 'https://sync.example.com',
        oauthProviders: const {
          'google': OAuthProviderConfig(
              id: 'google', clientId: 'gid', clientSecret: 'gsecret'),
          // Deliberately left unconfigured, to prove the providers endpoint
          // only advertises what the operator actually set up.
          'github':
              OAuthProviderConfig(id: 'github', clientId: '', clientSecret: ''),
        },
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
        oauthClient: oauth,
      ).handler;
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> call(
      String method,
      String path, {
      Object? body,
      Map<String, String> headers = const {},
    }) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {
          if (body != null) 'Content-Type': 'application/json',
          ...headers,
        },
      ));
      final raw = await response.readAsString();
      final decoded = raw.isEmpty ? const {} : _tryDecode(raw);
      return {
        if (decoded is Map<String, dynamic>) ...decoded,
        'httpStatus': response.statusCode,
      };
    }

    /// Runs start -> callback -> poll, returning the ticket and the poll
    /// result. That is everything up to the passphrase step.
    Future<(String, Map<String, dynamic>)> browserHalf() async {
      final started = await call('POST', '/api/v1/auth/oauth/start',
          body: {'provider': 'google'});
      expect(started['httpStatus'], 200);
      final ticket = started['ticket'] as String;
      final state =
          Uri.parse(started['authUrl'] as String).queryParameters['state'];

      final callback = await handler(Request(
          'GET',
          Uri.parse('http://localhost/api/v1/auth/oauth/callback/google'
              '?code=abc&state=$state')));
      expect(callback.statusCode, 200);

      final polled =
          await call('POST', '/api/v1/auth/oauth/poll', body: {'ticket': ticket});
      return (ticket, polled);
    }

    test('only configured providers are advertised', () async {
      final result = await call('GET', '/api/v1/auth/oauth/providers');
      final providers = result['providers'] as List<dynamic>;
      expect(providers, hasLength(1));
      expect((providers.single as Map)['id'], 'google');
    });

    test('start builds an authorize URL with this server as the redirect',
        () async {
      final started = await call('POST', '/api/v1/auth/oauth/start',
          body: {'provider': 'google'});
      final url = Uri.parse(started['authUrl'] as String);
      expect(url.host, 'accounts.google.com');
      expect(url.queryParameters['client_id'], 'gid');
      expect(url.queryParameters['redirect_uri'],
          'https://sync.example.com/api/v1/auth/oauth/callback/google');
      expect(url.queryParameters['state'], isNotEmpty);
      // The ticket must never travel to the provider.
      expect(url.toString(), isNot(contains(started['ticket'] as String)));
    });

    test('an unconfigured provider is refused', () async {
      final result = await call('POST', '/api/v1/auth/oauth/start',
          body: {'provider': 'github'});
      expect(result['httpStatus'], 400);
      expect(result['error'], 'unknown_provider');
    });

    test('polling is pending until the browser half lands', () async {
      final started = await call('POST', '/api/v1/auth/oauth/start',
          body: {'provider': 'google'});
      final polled = await call('POST', '/api/v1/auth/oauth/poll',
          body: {'ticket': started['ticket']});
      expect(polled['status'], 'pending');
      expect(polled['email'], isNull);
    });

    test('a first-time address creates the account once the passphrase is set',
        () async {
      final (ticket, polled) = await browserHalf();
      expect(polled['status'], 'ready');
      expect(polled['email'], 'alice@example.com');
      expect(polled['existingAccount'], isFalse);
      // Nothing to derive against yet — the client picks the parameters.
      expect(polled['kdfSalt'], isNull);

      final completed = await call('POST', '/api/v1/auth/oauth/complete', body: {
        'ticket': ticket,
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      expect(completed['httpStatus'], 201);
      expect(completed['token'], isNotEmpty);
      expect(store.userIdByEmail['alice@example.com'], isNotNull);
    });

    test('an address that already has a password account signs into it, and '
        'the link makes the button work from then on', () async {
      // An ordinary email + password account, made the old way.
      final registered = await call('POST', '/api/v1/auth/register', body: {
        'email': 'alice@example.com',
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      expect(registered['httpStatus'], 201);
      final userId = store.userIdByEmail['alice@example.com'];
      expect(userId, isNotNull);

      final (ticket, polled) = await browserHalf();
      expect(polled['existingAccount'], isTrue);
      // The client needs the account's own KDF parameters, or the passphrase
      // would derive a key that decrypts nothing.
      expect(polled['kdfSalt'], kdfSalt());
      expect(polled['kdfIterations'], 200000);

      final completed = await call('POST', '/api/v1/auth/oauth/complete', body: {
        'ticket': ticket,
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      expect(completed['httpStatus'], 200);
      expect(completed['token'], isNotEmpty);

      // Same account, not a second one, and now linked to the provider.
      expect(store.usersById, hasLength(1));
      expect(store.usersById[userId]!.oauthSubjects['google'],
          'google-subject-1');
      expect(store.userIdByOAuth[Store.oauthKey('google', 'google-subject-1')],
          userId);
    });

    test('the passphrase is still checked — the provider does not skip it',
        () async {
      await call('POST', '/api/v1/auth/register', body: {
        'email': 'alice@example.com',
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });

      final (ticket, _) = await browserHalf();
      final completed = await call('POST', '/api/v1/auth/oauth/complete', body: {
        'ticket': ticket,
        'authKey': authKey(2), // wrong passphrase
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      expect(completed['httpStatus'], 401);
      expect(completed['error'], 'invalid_credentials');
    });

    test('a linked account is found again after the address changes at the '
        'provider', () async {
      final (firstTicket, _) = await browserHalf();
      await call('POST', '/api/v1/auth/oauth/complete', body: {
        'ticket': firstTicket,
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      final userId = store.userIdByEmail['alice@example.com'];

      // Same Google account, new address on it.
      oauth.identity = const OAuthIdentity(
        provider: 'google',
        subject: 'google-subject-1',
        email: 'alice@newdomain.example',
      );
      final (_, polled) = await browserHalf();
      expect(polled['existingAccount'], isTrue,
          reason: 'the subject, not the address, identifies the account');
      expect(polled['kdfSalt'], kdfSalt());
      expect(store.usersById, hasLength(1));
      expect(store.userIdByEmail['alice@newdomain.example'], isNull);
      expect(store.userIdByEmail['alice@example.com'], userId);
    });

    test('a failed provider exchange is reported, not left hanging', () async {
      oauth.failure = 'The provider rejected the sign-in.';
      final started = await call('POST', '/api/v1/auth/oauth/start',
          body: {'provider': 'google'});
      final state =
          Uri.parse(started['authUrl'] as String).queryParameters['state'];
      final callback = await handler(Request(
          'GET',
          Uri.parse('http://localhost/api/v1/auth/oauth/callback/google'
              '?code=abc&state=$state')));
      expect(callback.statusCode, 502);

      final polled = await call('POST', '/api/v1/auth/oauth/poll',
          body: {'ticket': started['ticket']});
      expect(polled['status'], 'error');
      expect(polled['message'], contains('rejected'));
    });

    test('a stale or unknown ticket cannot complete a sign-in', () async {
      final completed = await call('POST', '/api/v1/auth/oauth/complete', body: {
        'ticket': 'not-a-real-ticket',
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      expect(completed['httpStatus'], 400);
      expect(completed['error'], 'oauth_expired');
      expect(store.usersById, isEmpty);
    });

    test('the account endpoint reports which providers are linked', () async {
      final (ticket, _) = await browserHalf();
      final completed = await call('POST', '/api/v1/auth/oauth/complete', body: {
        'ticket': ticket,
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(),
        'kdfIterations': 200000,
      });
      final account = await call('GET', '/api/v1/account',
          headers: {'Authorization': 'Bearer ${completed['token']}'});
      expect(account['linkedProviders'], ['google']);
    });
  });
}

Object? _tryDecode(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

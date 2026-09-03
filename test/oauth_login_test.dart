import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_api.dart';
import 'package:luma/sync/sync_crypto.dart';
import 'package:luma/sync/sync_service.dart';

/// The client half of signing in with Google or GitHub, driven against an
/// in-process fake of the server's four OAuth endpoints — nothing here
/// reaches a real provider or a real luma server.
///
/// What these lock down is the property the whole design turns on: the
/// provider decides *which account*, and the passphrase — never the
/// provider — is what produces the encryption key. So the same passphrase
/// must yield the same key whether you arrived by password or by button.
class _FakeOAuthServer {
  _FakeOAuthServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeOAuthServer> start() async =>
      _FakeOAuthServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}';

  /// Providers to advertise.
  List<Map<String, String>> providers = [
    {'id': 'google', 'name': 'Google'},
    {'id': 'github', 'name': 'GitHub'},
  ];

  /// How many polls to answer with "pending" before handing back the
  /// identity, so the waiting loop is actually exercised.
  int pendingPolls = 1;

  /// The poll payload served once [pendingPolls] is exhausted.
  Map<String, dynamic> readyResult = {
    'status': 'ready',
    'provider': 'google',
    'email': 'alice@example.com',
    'existingAccount': false,
  };

  /// Set to reject /complete with this auth key mismatch, standing in for a
  /// wrong passphrase on an existing account.
  String? expectedAuthKeyB64;

  /// Every /complete body the client sent.
  final List<Map<String, dynamic>> completions = [];

  /// Paths that were requested, in order.
  final List<String> paths = [];

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    paths.add(request.uri.path);
    final raw = await utf8.decodeStream(request);
    final body = raw.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;

    Future<void> reply(int status, Object payload) async {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));
      await request.response.close();
    }

    switch (request.uri.path) {
      case '/api/v1/auth/oauth/providers':
        await reply(200, {'providers': providers});
      case '/api/v1/auth/oauth/start':
        await reply(200, {
          'ticket': 'ticket-abc',
          'authUrl': 'https://accounts.example.com/authorize?state=xyz',
        });
      case '/api/v1/auth/oauth/poll':
        if (pendingPolls > 0) {
          pendingPolls--;
          await reply(200, {'status': 'pending'});
        } else {
          await reply(200, readyResult);
        }
      case '/api/v1/auth/oauth/complete':
        completions.add(body);
        final expected = expectedAuthKeyB64;
        if (expected != null && body['authKey'] != expected) {
          await reply(401, {
            'error': 'invalid_credentials',
            'message': 'That passphrase does not match this account.',
          });
        } else {
          await reply(200, {
            'token': 'session-token',
            'expiresAtMs': 1 << 40,
            'quotaBytes': 1024,
            'email': readyResult['email'],
          });
        }
      default:
        // Whatever the post-sign-in sync tries next is not under test.
        await reply(404, {'error': 'not_found', 'message': 'no'});
    }
  }
}

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(false));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  group('the server-access gate', () {
    test('lets the OAuth handshake through while still closed', () async {
      final sent = <Uri>[];
      final client = GatedServerClient(
        inner: _RecordingClient(sent),
        allowBeforeApproval: ServerAccessGate.accountSetupPaths,
      );

      for (final path in const [
        '/api/v1/auth/oauth/providers',
        '/api/v1/auth/oauth/start',
        '/api/v1/auth/oauth/poll',
        '/api/v1/auth/oauth/complete',
      ]) {
        await client.post(Uri.parse('https://sync.luma-app.cc$path'));
      }
      expect(sent, hasLength(4));

      // ...and nothing beyond it, exactly as for the password handshake.
      await expectLater(
        client.get(Uri.parse('https://sync.luma-app.cc/api/v1/sync/notes')),
        throwsA(isA<ServerAccessDeniedException>()),
      );
      expect(sent, hasLength(4));
    });
  });

  group('sign in with a provider', () {
    late _FakeOAuthServer server;
    late SyncService sync;

    setUp(() async {
      server = await _FakeOAuthServer.start();
      sync = SyncService(collections: const []);
      await sync.init();
    });

    tearDown(() async {
      sync.dispose();
      await server.close();
    });

    test('a server with none configured simply offers no buttons', () async {
      server.providers = [];
      expect(await sync.availableOAuthProviders(server.url), isEmpty);
    });

    test('an unreachable server is not an error, just no buttons', () async {
      // Nothing is listening on this port.
      final providers =
          await sync.availableOAuthProviders('http://127.0.0.1:1');
      expect(providers, isEmpty);
    });

    test('the configured providers are offered', () async {
      final providers = await sync.availableOAuthProviders(server.url);
      expect(providers.map((p) => p.id), ['google', 'github']);
      expect(providers.first.name, 'Google');
    });

    test('the ticket is kept out of the URL handed to the browser', () async {
      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');
      addTearDown(handle.close);
      expect(handle.authUrl, isNot(contains(handle.ticket)));
      expect(handle.providerId, 'google');
    });

    test('waiting keeps polling until the browser half lands', () async {
      server.pendingPolls = 3;
      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');
      addTearDown(handle.close);

      final result = await sync.waitForOAuthIdentity(handle,
          interval: const Duration(milliseconds: 5));
      expect(result.isReady, isTrue);
      expect(result.email, 'alice@example.com');
      expect(server.pendingPolls, 0);
    });

    test('cancelling stops the wait without signing anything in', () async {
      server.pendingPolls = 1 << 20; // never becomes ready
      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');

      handle.cancel();
      final result = await sync.waitForOAuthIdentity(handle,
          interval: const Duration(milliseconds: 5));
      expect(result.isError, isTrue);
      expect(sync.signedIn, isFalse);
      handle.close();
    });

    test('a new account is created with the passphrase, and the passphrase '
        'is what produces the key', () async {
      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');
      final identity = await sync.waitForOAuthIdentity(handle,
          interval: const Duration(milliseconds: 5));

      final pending = await sync.completeOAuthSignIn(
        handle: handle,
        identity: identity,
        passphrase: 'a-long-enough-passphrase',
      );

      expect(pending, isNull);
      expect(sync.signedIn, isTrue);
      expect(sync.serverReady, isTrue);
      expect(sync.email, 'alice@example.com');
      expect(ServerAccessGate.instance.approved, isTrue);

      // The server was sent the derived auth key and never the passphrase.
      final sentBody = server.completions.single;
      expect(sentBody['authKey'], isNotNull);
      expect(jsonEncode(sentBody), isNot(contains('a-long-enough-passphrase')));
    });

    test('an existing account reuses its own KDF parameters, so the same '
        'passphrase unlocks the same data as a password sign-in', () async {
      // What the account already has on the server, as /oauth/poll reports
      // it for an address that matched.
      final salt = SyncCrypto.randomBytes(16);
      const iterations = 1000;
      final expected = await SyncCrypto.deriveKeys(
        password: 'the-existing-password',
        kdfSalt: salt,
        iterations: iterations,
      );
      server.readyResult = {
        'status': 'ready',
        'provider': 'google',
        'email': 'alice@example.com',
        'existingAccount': true,
        'kdfSalt': base64Encode(salt),
        'kdfIterations': iterations,
      };
      server.expectedAuthKeyB64 = base64Encode(expected.authKey);

      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');
      final identity = await sync.waitForOAuthIdentity(handle,
          interval: const Duration(milliseconds: 5));
      expect(identity.existingAccount, isTrue);

      final pending = await sync.completeOAuthSignIn(
        handle: handle,
        identity: identity,
        passphrase: 'the-existing-password',
      );

      expect(pending, isNull);
      expect(sync.signedIn, isTrue);
      // The account's parameters were used verbatim — deriving under fresh
      // ones would produce a key that opens none of the existing snapshots.
      expect(server.completions.single['kdfIterations'], iterations);
      expect(server.completions.single['kdfSalt'], base64Encode(salt));
      expect(sync.peerHandshakeToken(), isNotNull);
    });

    test('a wrong passphrase on an existing account signs nothing in',
        () async {
      final salt = SyncCrypto.randomBytes(16);
      final right = await SyncCrypto.deriveKeys(
          password: 'the-right-one', kdfSalt: salt, iterations: 1000);
      server.readyResult = {
        'status': 'ready',
        'provider': 'google',
        'email': 'alice@example.com',
        'existingAccount': true,
        'kdfSalt': base64Encode(salt),
        'kdfIterations': 1000,
      };
      server.expectedAuthKeyB64 = base64Encode(right.authKey);

      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');
      final identity = await sync.waitForOAuthIdentity(handle,
          interval: const Duration(milliseconds: 5));

      await expectLater(
        sync.completeOAuthSignIn(
          handle: handle,
          identity: identity,
          passphrase: 'the-wrong-one',
        ),
        throwsA(isA<SyncApiException>()),
      );
      expect(sync.signedIn, isFalse);
      expect(sync.serverReady, isFalse);
      expect(ServerAccessGate.instance.approved, isFalse);
      handle.close();
    });

    test('an identity that never became ready cannot be completed', () async {
      final handle = await sync.startOAuthSignIn(
          serverUrl: server.url, providerId: 'google');
      addTearDown(handle.close);

      await expectLater(
        sync.completeOAuthSignIn(
          handle: handle,
          identity: const OAuthPollResult(status: 'pending'),
          passphrase: 'a-long-enough-passphrase',
        ),
        throwsA(isA<SyncApiException>()),
      );
      expect(server.completions, isEmpty);
    });
  });
}

/// Records request URLs without sending them anywhere.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.sent);
  final List<Uri> sent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request.url);
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

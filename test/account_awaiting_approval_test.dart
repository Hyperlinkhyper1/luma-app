import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_api.dart';
import 'package:luma/sync/sync_service.dart';

/// An in-process stand-in for a server running `LUMA_APPROVAL_MODE=email`:
/// registering holds the account, the emailed code proves the address, and
/// sign-in stays refused until [approved] is flipped by "the operator".
class _FakeEmailApprovalServer {
  _FakeEmailApprovalServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeEmailApprovalServer> start() async =>
      _FakeEmailApprovalServer._(
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  String get url => 'http://127.0.0.1:${_server.port}';

  bool verified = false;
  bool approved = false;
  final List<String> paths = [];

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    paths.add(request.uri.path);
    await utf8.decodeStream(request);

    Future<void> reply(int status, Object payload) async {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));
      await request.response.close();
    }

    switch (request.uri.path) {
      case '/api/v1/auth/register':
        await reply(201, {
          'status': 'pending_approval',
          'approval': 'email',
          'message': 'We sent a 6-digit code.',
        });
      case '/api/v1/auth/verify-code':
        verified = true;
        await reply(200, {
          'status': 'awaiting_approval',
          'message': 'Your email is verified and your account is created.',
        });
      case '/api/v1/auth/params':
        await reply(200, {
          'kdfSalt': base64Encode(List<int>.filled(16, 3)),
          'kdfIterations': 1000,
        });
      case '/api/v1/auth/login':
        if (!approved) {
          await reply(403, {
            'error': verified
                ? 'account_awaiting_approval'
                : 'account_pending_approval',
            'message': 'Waiting for the server operator.',
          });
        } else {
          await reply(200, {
            'token': 'session-token',
            'expiresAtMs': 1 << 40,
            'quotaBytes': 1024,
          });
        }
      default:
        await reply(404, {'error': 'not_found', 'message': 'no'});
    }
  }
}

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(false));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  group('an email-verified account awaiting approval', () {
    late _FakeEmailApprovalServer server;
    late SyncService sync;

    setUp(() async {
      server = await _FakeEmailApprovalServer.start();
      sync = SyncService(collections: const []);
      await sync.init();
    });

    tearDown(() async {
      await sync.cancelPendingApproval();
      sync.dispose();
      await server.close();
    });

    test('the code makes it official but leaves the gate shut', () async {
      final message = await sync.register(
        serverUrl: server.url,
        email: 'Bob@Example.com',
        password: 'a-long-enough-password',
      );
      expect(message, isNotNull);
      expect(sync.awaitingEmailCode, isTrue);
      expect(sync.pendingEmailVerified, isFalse);

      final awaiting = await sync.verifyEmailCode('123456');
      expect(awaiting, isNotNull);
      expect(sync.pendingApprovalEmail, 'bob@example.com');
      expect(sync.pendingEmailVerified, isTrue);
      expect(sync.awaitingEmailCode, isFalse);
      expect(sync.awaitingApproval, isTrue);
      expect(sync.signedIn, isFalse);
      expect(sync.serverReady, isFalse);
      expect(ServerAccessGate.instance.approved, isFalse);

      // A second code would make no sense any more.
      await expectLater(sync.verifyEmailCode('123456'), throwsStateError);

      // Nothing past the handshake was attempted, and verifying did not
      // sign in on its own.
      expect(server.paths, [
        '/api/v1/auth/register',
        '/api/v1/auth/verify-code',
      ]);
    });

    test('signing in before approval is refused and keeps the state',
        () async {
      server.verified = true;
      await expectLater(
        sync.signIn(
          serverUrl: server.url,
          email: 'bob@example.com',
          password: 'a-long-enough-password',
        ),
        throwsA(isA<SyncApiException>().having(
            (e) => e.code, 'code', 'account_awaiting_approval')),
      );
      expect(sync.pendingApprovalEmail, 'bob@example.com');
      expect(sync.pendingEmailVerified, isTrue);
      expect(sync.awaitingEmailCode, isFalse);
      expect(sync.serverReady, isFalse);
      expect(ServerAccessGate.instance.approved, isFalse);
    });

    test('once the operator approves, signing in opens the gate', () async {
      server
        ..verified = true
        ..approved = true;
      await sync.signIn(
        serverUrl: server.url,
        email: 'bob@example.com',
        password: 'a-long-enough-password',
      );
      expect(sync.serverReady, isTrue);
      expect(sync.pendingApprovalEmail, isNull);
      expect(sync.pendingEmailVerified, isFalse);
      expect(ServerAccessGate.instance.approved, isTrue);
      await sync.signOut();
    });
  });
}

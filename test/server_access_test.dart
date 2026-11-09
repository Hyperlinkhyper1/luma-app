import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_api.dart';
import 'package:luma/sync/sync_service.dart';

/// Records every request it is asked to send, so a test can assert that
/// nothing at all reached the network.
class _RecordingClient extends http.BaseClient {
  final List<Uri> sent = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request.url);
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(false));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  group('ServerAccessGate', () {
    test('starts closed — a fresh install talks to no server', () {
      expect(ServerAccessGate.instance.approved, isFalse);
      expect(
        () => ServerAccessGate.instance.ensureApproved(),
        throwsA(isA<ServerAccessDeniedException>()),
      );
    });

    test('GatedServerClient refuses to send while closed', () async {
      final inner = _RecordingClient();
      final client = GatedServerClient(inner: inner);

      await expectLater(
        client.get(Uri.parse('https://sync.luma-app.cc/api/v1/account')),
        throwsA(isA<ServerAccessDeniedException>()),
      );
      expect(inner.sent, isEmpty);
    });

    test('the account handshake stays reachable while closed', () async {
      final inner = _RecordingClient();
      final client = GatedServerClient(
        inner: inner,
        allowBeforeApproval: ServerAccessGate.accountSetupPaths,
      );

      await client.post(
        Uri.parse('https://sync.luma-app.cc/api/v1/auth/register'),
      );
      expect(inner.sent, hasLength(1));

      // ...but nothing beyond it.
      await expectLater(
        client.get(Uri.parse('https://sync.luma-app.cc/api/v1/sync/notes')),
        throwsA(isA<ServerAccessDeniedException>()),
      );
      expect(inner.sent, hasLength(1));
    });

    test('a forgotten password can be reset while signed out', () async {
      final inner = _RecordingClient();
      final api = SyncApi('https://sync.luma-app.cc', client: inner);

      await api.requestPasswordResetCode('a@b.c').catchError((_) => '');
      await api
          .resetPasswordWithCode(
            email: 'a@b.c',
            code: '123456',
            newAuthKey: Uint8List(32),
            newKdfSalt: Uint8List(16),
            newKdfIterations: 200000,
          )
          .catchError((_) {});

      expect(inner.sent.map((u) => u.path), [
        '/api/v1/auth/forgot-password',
        '/api/v1/auth/reset-with-code',
      ]);
    });

    test('opening the gate lets everything through again', () async {
      final inner = _RecordingClient();
      final client = GatedServerClient(inner: inner);

      ServerAccessGate.instance.setApproved(true);
      await client.get(Uri.parse('https://sync.luma-app.cc/api/v1/account'));
      expect(inner.sent, hasLength(1));
    });

  });

  group('SyncApi without an approved account', () {
    test(
      'every non-handshake call is refused before it opens a socket',
      () async {
        final inner = _RecordingClient();
        final api = SyncApi('https://sync.luma-app.cc', client: inner);

        await expectLater(
          api.account(),
          throwsA(isA<ServerAccessDeniedException>()),
        );
        await expectLater(
          api.getBlob('notes'),
          throwsA(isA<ServerAccessDeniedException>()),
        );
        await expectLater(
          api.listSessions(),
          throwsA(isA<ServerAccessDeniedException>()),
        );
        await expectLater(
          api.deleteBlob('notes'),
          throwsA(isA<ServerAccessDeniedException>()),
        );
        await expectLater(
          api.aiStatus(),
          throwsA(isA<ServerAccessDeniedException>()),
        );

        expect(inner.sent, isEmpty);
      },
    );

    test('the approval check reaches only the account endpoint', () async {
      final inner = _RecordingClient();
      final api = SyncApi(
        'https://sync.luma-app.cc',
        token: 't',
        client: inner,
      );

      await api.approvalCheck();
      expect(inner.sent.map((u) => u.path), ['/api/v1/account']);

      // The regular client is still shut for the same path.
      await expectLater(
        api.account(),
        throwsA(isA<ServerAccessDeniedException>()),
      );
      expect(inner.sent, hasLength(1));
    });
  });

  group('A device the server once put back to "waiting for approval"', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory dir;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('luma-approval-recheck-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      await File('${dir.path}${Platform.pathSeparator}luma_sync.json')
          .writeAsString(
            jsonEncode({
              'serverUrl': 'https://sync.luma-app.cc',
              'email': 'stuck@example.invalid',
              'token': 'still-valid-token',
              'encryptionKey': base64Encode(Uint8List(32)),
              'accountApproved': false,
              'localAccountMigrated': true,
            }),
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await dir.delete(recursive: true);
    });

    Future<(SyncService, List<String>, String?)> start(
      http.Response Function() account,
    ) {
      final paths = <String>[];
      String? plan;
      return http.runWithClient(() async {
        final sync = SyncService(
          collections: const [],
          onServerPlan: (id) => plan = id,
        );
        await sync.init();
        for (var i = 0; i < 20; i++) {
          await pumpEventQueue();
        }
        sync.dispose();
        // dispose() starts a last save; let it land before tearDown deletes
        // the directory under it.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return (sync, paths, plan);
      }, () => MockClient((request) async {
        paths.add(request.url.path);
        return request.url.path == '/api/v1/account'
            ? account()
            : http.Response('{}', 200);
      }));
    }

    test('reopens its gate on its own once the server approves it', () async {
      final (sync, paths, plan) = await start(
        () => http.Response(
          jsonEncode({'email': 'stuck@example.invalid', 'status': 'active',
              'planId': 'nova', 'quotaBytes': 1, 'usedBytes': 0}),
          200,
        ),
      );

      expect(paths.first, '/api/v1/account');
      expect(sync.accountApproved, isTrue);
      expect(sync.serverReady, isTrue);
      expect(sync.waitingForReapproval, isFalse);
      expect(plan, 'nova');
    });

    test('stays shut, asking nothing else, while still pending', () async {
      final (sync, paths, _) = await start(
        () => http.Response(
          jsonEncode({'error': 'account_not_approved',
              'message': 'This account is waiting to be approved.'}),
          403,
        ),
      );

      expect(paths, ['/api/v1/account']);
      expect(sync.serverReady, isFalse);
      expect(sync.waitingForReapproval, isTrue);
      expect(ServerAccessGate.instance.approved, isFalse);
    });
  });

  group('SyncService approval state', () {
    test(
      'a fresh service is not server-ready and keeps the gate shut',
      () async {
        final sync = SyncService(collections: const []);
        await sync.init();

        expect(sync.signedIn, isFalse);
        expect(sync.accountApproved, isFalse);
        expect(sync.serverReady, isFalse);
        expect(ServerAccessGate.instance.approved, isFalse);
      },
    );

    test('a local-only (P2P) identity does not open the gate', () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      await sync.setLocalAccount(
        email: 'peer@example.com',
        password: 'a-long-local-password',
      );

      expect(sync.p2pReady, isTrue);
      expect(sync.serverReady, isFalse);
      expect(ServerAccessGate.instance.approved, isFalse);
    });

    test(
      'cloud storage primitives refuse without an approved account',
      () async {
        final sync = SyncService(collections: const []);
        await sync.init();

        await expectLater(sync.getObject('files'), throwsStateError);
        await expectLater(sync.deleteObject('files'), throwsStateError);
        await expectLater(
          sync.putJsonObject('files', const {}),
          throwsStateError,
        );
        expect(await sync.mistralKeyConfiguredOnServer(), isFalse);
        expect(await sync.aiStatus(), isNull);
      },
    );

    test('resending the approval mail needs a pending account', () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      expect(sync.pendingApprovalEmail, isNull);
      await expectLater(sync.resendApprovalEmail(), throwsStateError);
    });

    test('submitting a verification code needs a pending account', () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      expect(sync.pendingApprovalEmail, isNull);
      await expectLater(sync.verifyEmailCode('123456'), throwsStateError);
    });

    test(
      'approval defaults to manual, so no UI offers to resend anything',
      () async {
        final sync = SyncService(collections: const []);
        await sync.init();
        expect(sync.pendingApprovalMode, ServerApprovalMode.manual);
      },
    );
  });

  group('ServerApprovalMode', () {
    test('parses what the server reports', () {
      expect(ServerApprovalMode.parse('manual'), ServerApprovalMode.manual);
      expect(ServerApprovalMode.parse('email'), ServerApprovalMode.email);
      expect(ServerApprovalMode.parse('open'), ServerApprovalMode.open);
    });

    test(
      'anything unknown — including a server too old to say — is manual',
      () {
        // Safe default: manual never promises the user an email that is not
        // coming, and never implies the account is already usable.
        expect(ServerApprovalMode.parse(null), ServerApprovalMode.manual);
        expect(ServerApprovalMode.parse('whatever'), ServerApprovalMode.manual);
      },
    );
  });

  group('RemoteAccount.status', () {
    test('an account still waiting for approval reads as not approved', () {
      final pending = RemoteAccount.fromJson(const {
        'email': 'a@b.c',
        'usedBytes': 0,
        'quotaBytes': 1,
        'status': 'pending',
      });
      expect(pending.approved, isFalse);
    });

    test('a server that predates the field counts as approved', () {
      final legacy = RemoteAccount.fromJson(const {
        'email': 'a@b.c',
        'usedBytes': 0,
        'quotaBytes': 1,
      });
      expect(legacy.approved, isTrue);
    });
  });
}

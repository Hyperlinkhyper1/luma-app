import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
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

/// The two operator-driven account actions on the admin dashboard, end to end
/// through the real handler:
///
///  * **Reset password** — the old password stops signing in, but the
///    account's existing sessions survive. That is load-bearing, not an
///    oversight: sync is zero-knowledge, so only a device that still holds the
///    encryption key can re-seal the stored snapshots under the new password.
///    Revoking sessions here would make an admin reset silently destroy the
///    user's synced data.
///  * **Data-deletion requests** — filing one deletes nothing; only the
///    operator accepting it does.
void main() {
  late Directory dir;
  late Store store;
  late Handler handler;

  Future<Handler> buildHandler() async {
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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_admin_actions_test');
    store = await Store.open(dir.path);
    handler = await buildHandler();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// The client derives an auth key from the password; the server only ever
  /// sees this. Any distinct 32 bytes per password will do for these tests.
  Uint8List authKeyFor(String password) => Uint8List.fromList(
      c.sha256.convert(utf8.encode('key:$password')).bytes);

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Object? json,
    String? form,
    String? token,
    bool admin = false,
  }) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {
        if (json != null) 'Content-Type': 'application/json',
        if (form != null) 'Content-Type': 'application/x-www-form-urlencoded',
        if (token != null) 'Authorization': 'Bearer $token',
        if (admin) 'x-admin-key': 'test-admin-key',
      },
      body: json != null ? jsonEncode(json) : form,
    ));
    final raw = await response.readAsString();
    return {
      ...(raw.isEmpty || !raw.trimLeft().startsWith('{')
          ? const <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>),
      'httpStatus': response.statusCode,
    };
  }

  /// Registers an account (approval mode is `open`, so this signs straight in)
  /// and returns its session token.
  Future<String> register(String email, String password) async {
    final result = await call('POST', '/api/v1/auth/register', json: {
      'email': email,
      'authKey': base64Encode(authKeyFor(password)),
      'kdfSalt': base64Encode(List.filled(16, 7)),
      'kdfIterations': 210000,
    });
    expect(result['httpStatus'], 201, reason: 'register: $result');
    return result['token'] as String;
  }

  Future<Map<String, dynamic>> login(String email, String password) =>
      call('POST', '/api/v1/auth/login', json: {
        'email': email,
        'authKey': base64Encode(authKeyFor(password)),
      });

  group('admin password reset', () {
    test('kills the old password but keeps the session that can re-encrypt',
        () async {
      final token = await register('reset@example.com', 'old-password-1');
      expect((await login('reset@example.com', 'old-password-1'))['httpStatus'],
          200);

      final reset = await call('POST', '/admin/password-reset',
          form: 'email=reset%40example.com', admin: true);
      expect(reset['httpStatus'], 200);

      // The old password is dead everywhere...
      final blocked = await login('reset@example.com', 'old-password-1');
      expect(blocked['httpStatus'], 403);
      expect(blocked['error'], 'password_reset_required');

      // ...but the already-signed-in device still works, and is told why.
      final account =
          await call('GET', '/api/v1/account', token: token);
      expect(account['httpStatus'], 200);
      expect(account['passwordResetRequired'], isTrue);
    });

    test('a wrong password on a flagged account still says reset, not wrong',
        () async {
      await register('reset2@example.com', 'old-password-1');
      await call('POST', '/admin/password-reset',
          form: 'email=reset2%40example.com', admin: true);
      final wrong = await login('reset2@example.com', 'not-even-close');
      expect(wrong['error'], 'password_reset_required');
    });

    test('the signed-in device can set a new password, and only then', () async {
      final token = await register('reset3@example.com', 'old-password-1');

      // Nothing outstanding yet: /auth/reset must not be a way around
      // /auth/change's current-password check.
      final premature = await call('POST', '/api/v1/auth/reset',
          token: token,
          json: {
            'newAuthKey': base64Encode(authKeyFor('new-password-1')),
            'newKdfSalt': base64Encode(List.filled(16, 9)),
            'newKdfIterations': 210000,
          });
      expect(premature['httpStatus'], 409);
      expect(premature['error'], 'no_reset_pending');

      await call('POST', '/admin/password-reset',
          form: 'email=reset3%40example.com', admin: true);

      final done = await call('POST', '/api/v1/auth/reset',
          token: token,
          json: {
            'newAuthKey': base64Encode(authKeyFor('new-password-1')),
            'newKdfSalt': base64Encode(List.filled(16, 9)),
            'newKdfIterations': 210000,
          });
      expect(done['httpStatus'], 200);

      expect((await login('reset3@example.com', 'new-password-1'))['httpStatus'],
          200);
      expect((await login('reset3@example.com', 'old-password-1'))['httpStatus'],
          401);
    });

    test('cancelling a reset gives the old password back', () async {
      await register('reset4@example.com', 'old-password-1');
      await call('POST', '/admin/password-reset',
          form: 'email=reset4%40example.com', admin: true);
      await call('POST', '/admin/password-reset/cancel',
          form: 'email=reset4%40example.com', admin: true);
      expect((await login('reset4@example.com', 'old-password-1'))['httpStatus'],
          200);
    });

    test('an ordinary password change satisfies a pending reset', () async {
      final token = await register('reset5@example.com', 'old-password-1');
      await call('POST', '/admin/password-reset',
          form: 'email=reset5%40example.com', admin: true);

      final changed = await call('POST', '/api/v1/auth/change',
          token: token,
          json: {
            'currentAuthKey': base64Encode(authKeyFor('old-password-1')),
            'newAuthKey': base64Encode(authKeyFor('new-password-1')),
            'newKdfSalt': base64Encode(List.filled(16, 3)),
            'newKdfIterations': 210000,
          });
      expect(changed['httpStatus'], 200);

      final account = await call('GET', '/api/v1/account', token: token);
      expect(account['passwordResetRequired'], isFalse);
    });
  });

  group('data-deletion requests', () {
    test('filing one deletes nothing and shows up for the admin', () async {
      final token = await register('bye@example.com', 'old-password-1');

      final filed = await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'Moving off luma.'});
      expect(filed['httpStatus'], 200);
      expect((filed['request'] as Map)['status'], 'pending');

      // Still a working account — nothing was deleted.
      final account = await call('GET', '/api/v1/account', token: token);
      expect(account['httpStatus'], 200);
      expect((account['deletionRequest'] as Map)['reason'], 'Moving off luma.');

      final inbox =
          await call('GET', '/admin/deletion-requests', admin: true);
      final requests = inbox['requests'] as List;
      expect(requests, hasLength(1));
      expect((requests.first as Map)['email'], 'bye@example.com');
      expect((requests.first as Map)['pending'], isTrue);
    });

    test('a reason is required and only one request may be open', () async {
      final token = await register('bye2@example.com', 'old-password-1');
      final blank = await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': '   '});
      expect(blank['httpStatus'], 400);

      await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'First.'});
      final second = await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'Second.'});
      expect(second['httpStatus'], 409);
      expect(second['error'], 'already_pending');
    });

    test('declining keeps the account and hands back the note', () async {
      final token = await register('stay@example.com', 'old-password-1');
      final filed = await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'Changed my mind, maybe.'});
      final id = (filed['request'] as Map)['id'] as String;

      final decided = await call('POST', '/admin/deletion-requests/decide',
          form: 'id=${Uri.encodeQueryComponent(id)}&decision=decline'
              '&note=${Uri.encodeQueryComponent('Talk to me first.')}',
          admin: true);
      expect(decided['httpStatus'], 200);

      final account = await call('GET', '/api/v1/account', token: token);
      expect(account['httpStatus'], 200);
      final request = account['deletionRequest'] as Map;
      expect(request['status'], 'declined');
      expect(request['adminNote'], 'Talk to me first.');
    });

    test('accepting wipes the account, its blobs and its sessions', () async {
      final token = await register('gone@example.com', 'old-password-1');
      final userId = store.userIdByEmail['gone@example.com']!;

      // Give the account something to lose.
      final put = await handler(Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/sync/notes'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Base-Version': '0',
          'Content-Type': 'application/octet-stream',
        },
        body: List.filled(64, 1),
      ));
      expect(put.statusCode, 200);
      expect(File(store.blobPath(userId, 'notes')).existsSync(), isTrue);

      final filed = await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'Delete everything please.'});
      final id = (filed['request'] as Map)['id'] as String;

      final decided = await call('POST', '/admin/deletion-requests/decide',
          form: 'id=${Uri.encodeQueryComponent(id)}&decision=accept',
          admin: true);
      expect(decided['httpStatus'], 200);

      expect(store.usersById.containsKey(userId), isFalse);
      expect(store.userIdByEmail.containsKey('gone@example.com'), isFalse);
      expect(Directory('${dir.path}/blobs/$userId').existsSync(), isFalse);
      expect((await call('GET', '/api/v1/account', token: token))['httpStatus'],
          401);

      // The decision itself survives as history for the Inbox.
      final inbox = await call('GET', '/admin/deletion-requests', admin: true);
      final requests = inbox['requests'] as List;
      expect((requests.single as Map)['status'], 'accepted');
    });

    test('a decided request cannot be decided again', () async {
      final token = await register('once@example.com', 'old-password-1');
      final filed = await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'Once.'});
      final id = (filed['request'] as Map)['id'] as String;
      final form = 'id=${Uri.encodeQueryComponent(id)}&decision=decline';
      expect((await call('POST', '/admin/deletion-requests/decide',
              form: form, admin: true))['httpStatus'],
          200);
      final again = await call('POST', '/admin/deletion-requests/decide',
          form: form, admin: true);
      expect(again['httpStatus'], 409);
      expect(again['error'], 'already_decided');
    });

    test('a user can withdraw their own undecided request', () async {
      final token = await register('undo@example.com', 'old-password-1');
      await call('POST', '/api/v1/account/deletion-request',
          token: token, json: {'reason': 'Actually never mind.'});
      final cancelled = await call(
          'POST', '/api/v1/account/deletion-request/cancel',
          token: token);
      expect(cancelled['httpStatus'], 200);
      expect(store.deletionRequestsById, isEmpty);

      final account = await call('GET', '/api/v1/account', token: token);
      expect(account['deletionRequest'], isNull);
    });
  });
}

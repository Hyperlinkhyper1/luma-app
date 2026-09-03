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

  Future<Handler> buildHandler({bool trustProxy = false}) async {
    final config = ServerConfig(
      port: 0,
      dataDir: dir.path,
      allowRegistration: true,
      maxBlobBytes: 1024 * 1024,
      tokenTtl: const Duration(days: 30),
      corsOrigin: '*',
      trustProxy: trustProxy,
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

  group('revoked access', () {
    test('locks the account out of sign-in and of its existing sessions',
        () async {
      final token = await register('banned@example.com', 'old-password-1');
      expect((await call('GET', '/api/v1/account', token: token))['httpStatus'],
          200);

      final revoked = await call('POST', '/admin/access/revoke',
          form: 'email=banned%40example.com'
              '&reason=${Uri.encodeQueryComponent('Repeated abuse reports.')}',
          admin: true);
      expect(revoked['httpStatus'], 200);

      // Sessions are dropped, so the account's devices lose the server at
      // once rather than on their next sign-in.
      final stale = await call('GET', '/api/v1/account', token: token);
      expect(stale['httpStatus'], 401);

      final blocked = await login('banned@example.com', 'old-password-1');
      expect(blocked['httpStatus'], 403);
      expect(blocked['error'], 'access_revoked');
      expect(blocked['message'], contains('Repeated abuse reports.'));
    });

    test('the right password is still needed before it says so', () async {
      await register('quiet@example.com', 'old-password-1');
      await call('POST', '/admin/access/revoke',
          form: 'email=quiet%40example.com', admin: true);
      // Otherwise sign-in would confirm which addresses have accounts.
      final wrong = await login('quiet@example.com', 'not-even-close');
      expect(wrong['httpStatus'], 401);
      expect(wrong['error'], 'invalid_credentials');
    });

    test('approving does not lift it — only restoring does', () async {
      await register('locked@example.com', 'old-password-1');
      await call('POST', '/admin/access/revoke',
          form: 'email=locked%40example.com', admin: true);

      // The approval flow is a separate axis and must not be a way around it.
      await call('POST', '/admin/verify',
          form: 'email=locked%40example.com', admin: true);
      expect((await login('locked@example.com', 'old-password-1'))['error'],
          'access_revoked');

      final restored = await call('POST', '/admin/access/restore',
          form: 'email=locked%40example.com', admin: true);
      expect(restored['httpStatus'], 200);

      final ok = await login('locked@example.com', 'old-password-1');
      expect(ok['httpStatus'], 200);
      expect(ok['token'], isNotNull);
    });

    test('leaves the account and its data alone', () async {
      final token = await register('data@example.com', 'old-password-1');
      final userId = store.userIdByEmail['data@example.com']!;
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

      await call('POST', '/admin/access/revoke',
          form: 'email=data%40example.com', admin: true);

      // A lockout, not a deletion: everything is still there for when access
      // is restored.
      expect(store.usersById.containsKey(userId), isTrue);
      expect(File(store.blobPath(userId, 'notes')).existsSync(), isTrue);
    });

    test('an unknown email is a 404, not a silent success', () async {
      final result = await call('POST', '/admin/access/revoke',
          form: 'email=nobody%40example.com', admin: true);
      expect(result['httpStatus'], 404);
    });
  });

  group('ip bans', () {
    test('banning an account blocks the API but never the dashboard', () async {
      await register('spam@example.com', 'old-password-1');
      // Shelf gives no connection info in a synthetic Request, so the address
      // has to come from a trusted forwarding header for this to be testable
      // at all. Either way it is the same _clientKey the middleware reads.
      final user = store.usersById[store.userIdByEmail['spam@example.com']!]!;
      user.noteIp('203.0.113.9');
      await store.saveUsers();

      final banned = await call('POST', '/admin/ip-ban',
          form: 'email=spam%40example.com', admin: true);
      expect(banned['httpStatus'], 200);
      expect(store.bansByIp.containsKey('203.0.113.9'), isTrue);

      // The dashboard stays reachable from a banned address on purpose —
      // otherwise banning your own address locks you out of undoing it.
      final dashboard = await call('GET', '/admin/ip-bans', admin: true);
      expect(dashboard['httpStatus'], 200);
      expect((dashboard['bans'] as List).single['email'], 'spam@example.com');
    });

    test('a banned address is refused before it reaches any route', () async {
      // Behind a trusted proxy the address comes from X-Forwarded-For, which
      // is the only way to hand a synthetic Request an address at all.
      handler = await buildHandler(trustProxy: true);

      Future<int> statusFrom(String ip, String path) async {
        final response = await handler(Request(
          'GET',
          Uri.parse('http://localhost$path'),
          headers: {'x-forwarded-for': ip, 'x-admin-key': 'test-admin-key'},
        ));
        return response.statusCode;
      }

      // Unauthenticated, but reaching the route: 401, not 403.
      expect(await statusFrom('203.0.113.20', '/api/v1/account'), 401);

      await call('POST', '/admin/ip-ban',
          form: 'ip=203.0.113.20&reason=abuse', admin: true);

      expect(await statusFrom('203.0.113.20', '/api/v1/account'), 403);
      // A different address is unaffected...
      expect(await statusFrom('203.0.113.21', '/api/v1/account'), 401);
      // ...and the banned one can still reach the dashboard to be unbanned.
      expect(await statusFrom('203.0.113.20', '/admin/ip-bans'), 200);
    });

    test('an account nobody has seen connect has nothing to ban', () async {
      await register('ghost@example.com', 'old-password-1');
      final user = store.usersById[store.userIdByEmail['ghost@example.com']!]!;
      user.recentIps.clear();
      await store.saveUsers();

      final result = await call('POST', '/admin/ip-ban',
          form: 'email=ghost%40example.com', admin: true);
      expect(result['httpStatus'], 409);
      expect(result['error'], 'no_known_ips');
    });

    test('a ban leaves the account itself alone', () async {
      final token = await register('kept@example.com', 'old-password-1');
      final user = store.usersById[store.userIdByEmail['kept@example.com']!]!;
      user.noteIp('203.0.113.10');
      await store.saveUsers();

      await call('POST', '/admin/ip-ban',
          form: 'email=kept%40example.com', admin: true);

      // Same session, same approval, same data — only the address is blocked.
      final account = await call('GET', '/api/v1/account', token: token);
      expect(account['httpStatus'], 200);
      expect(account['status'], 'active');
    });

    test('unbanning by email lifts every address banned for it', () async {
      await register('multi@example.com', 'old-password-1');
      final user = store.usersById[store.userIdByEmail['multi@example.com']!]!;
      user
        ..noteIp('203.0.113.11')
        ..noteIp('203.0.113.12');
      await store.saveUsers();

      await call('POST', '/admin/ip-ban',
          form: 'email=multi%40example.com', admin: true);
      expect(store.bansByIp, hasLength(2));

      final lifted = await call('POST', '/admin/ip-unban',
          form: 'email=multi%40example.com', admin: true);
      expect(lifted['httpStatus'], 200);
      expect(store.bansByIp, isEmpty);
    });

    test('a single address can be banned and lifted on its own', () async {
      final banned = await call('POST', '/admin/ip-ban',
          form: 'ip=198.51.100.4&reason=scraper', admin: true);
      expect(banned['httpStatus'], 200);
      expect(store.bansByIp['198.51.100.4']!.reason, 'scraper');

      final lifted = await call('POST', '/admin/ip-unban',
          form: 'ip=198.51.100.4', admin: true);
      expect(lifted['httpStatus'], 200);
      expect(store.bansByIp, isEmpty);

      // Lifting a ban that isn't there is an error, not a silent no-op.
      expect(
          (await call('POST', '/admin/ip-unban',
              form: 'ip=198.51.100.4', admin: true))['httpStatus'],
          404);
    });

    test('recentIps keeps the newest addresses, without duplicates', () {
      final user = StoredUser(
        id: 'u',
        email: 'ring@example.com',
        authHash: '',
        authSalt: '',
        kdfSalt: '',
        kdfIterations: 210000,
        quotaBytes: 0,
        createdAtMs: 0,
      );
      for (var i = 0; i < StoredUser.maxRecentIps + 3; i++) {
        user.noteIp('10.0.0.$i');
      }
      expect(user.recentIps, hasLength(StoredUser.maxRecentIps));
      expect(user.recentIps.last, '10.0.0.${StoredUser.maxRecentIps + 2}');

      // Re-seeing an address moves it to the front of the queue rather than
      // adding a second copy.
      final oldest = user.recentIps.first;
      expect(user.noteIp(oldest), isTrue);
      expect(user.recentIps.where((ip) => ip == oldest), hasLength(1));
      expect(user.recentIps.last, oldest);
      expect(user.noteIp(oldest), isFalse);
      expect(user.noteIp('unknown'), isFalse);
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

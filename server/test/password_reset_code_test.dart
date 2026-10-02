import 'dart:convert';
import 'dart:io';

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
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Stands in for Resend: records the reset codes handed to it.
class _CapturingMailer extends Mailer {
  _CapturingMailer() : super(MailConfig.fromEnvironment(const {}));

  String? lastToEmail;
  String? lastCode;
  Duration? lastValidFor;
  int sendCount = 0;

  @override
  Future<void> sendPasswordResetCode({
    required String toEmail,
    required String code,
    required Duration validFor,
  }) async {
    sendCount++;
    lastToEmail = toEmail;
    lastCode = code;
    lastValidFor = validFor;
  }
}

void main() {
  group('forgot password by emailed code', () {
    late Directory dir;
    late Store store;
    late _CapturingMailer mailer;
    late Handler handler;

    String authKey(int fill) => base64Encode(List<int>.filled(32, fill));
    String kdfSalt(int fill) => base64Encode(List<int>.filled(16, fill));

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_reset_test');
      store = await Store.open(dir.path);
      mailer = _CapturingMailer();
      final config = ServerConfig(
        port: 0,
        dataDir: dir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(minutes: 10),
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
        mailer,
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

    Future<Map<String, dynamic>> call(String path, Object body) async {
      final response = await handler(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));
      final raw = await response.readAsString();
      final decoded = raw.isEmpty ? const {} : jsonDecode(raw);
      return {
        if (decoded is Map<String, dynamic>) ...decoded,
        'httpStatus': response.statusCode,
      };
    }

    Future<void> register(String email) async {
      final result = await call('/api/v1/auth/register', {
        'email': email,
        'authKey': authKey(1),
        'kdfSalt': kdfSalt(7),
        'kdfIterations': 200000,
      });
      expect(result['httpStatus'], 201);
    }

    Future<Map<String, dynamic>> reset(String email, String code,
            {int newKey = 2}) =>
        call('/api/v1/auth/reset-with-code', {
          'email': email,
          'code': code,
          'newAuthKey': authKey(newKey),
          'newKdfSalt': kdfSalt(9),
          'newKdfIterations': 200000,
        });

    Future<Map<String, dynamic>> login(String email, int key) =>
        call('/api/v1/auth/login', {'email': email, 'authKey': authKey(key)});

    test('mails a 6-digit code that is valid for 15 minutes', () async {
      await register('alice@example.com');
      final result = await call(
          '/api/v1/auth/forgot-password', {'email': 'alice@example.com'});

      expect(result['httpStatus'], 200);
      expect(mailer.sendCount, 1);
      expect(mailer.lastToEmail, 'alice@example.com');
      expect(RegExp(r'^\d{6}$').hasMatch(mailer.lastCode!), isTrue);
      expect(mailer.lastValidFor, const Duration(minutes: 15));

      final user = store.usersById.values.single;
      final ttl = user.passwordResetCodeExpiresAtMs! -
          DateTime.now().millisecondsSinceEpoch;
      expect(ttl, greaterThan(const Duration(minutes: 14).inMilliseconds));
      expect(
          ttl, lessThanOrEqualTo(const Duration(minutes: 15).inMilliseconds));
    });

    test('an unknown address gets the same answer and no mail', () async {
      await register('alice@example.com');
      final known = await call(
          '/api/v1/auth/forgot-password', {'email': 'alice@example.com'});
      final unknown = await call(
          '/api/v1/auth/forgot-password', {'email': 'nobody@example.com'});

      expect(unknown['httpStatus'], known['httpStatus']);
      expect(unknown['message'], known['message']);
      expect(mailer.sendCount, 1);
    });

    test('the right code sets the new password, wipes sync data and sessions',
        () async {
      await register('bob@example.com');
      final user = store.usersById.values.single;
      await store.writeBlob(user.id, 'notes', [1, 2, 3]);
      expect(store.sessionsByTokenHash.values.where((s) => s.userId == user.id),
          isNotEmpty);

      await call('/api/v1/auth/forgot-password', {'email': 'bob@example.com'});
      final result = await reset('bob@example.com', mailer.lastCode!);
      expect(result['httpStatus'], 200);

      expect(await store.readBlob(user.id, 'notes'), isNull);
      expect(store.sessionsByTokenHash.values.where((s) => s.userId == user.id),
          isEmpty);
      expect(user.kdfSalt, kdfSalt(9));
      expect(user.passwordResetCodeHash, isNull);

      expect((await login('bob@example.com', 1))['httpStatus'], 401);
      final fresh = await login('bob@example.com', 2);
      expect(fresh['httpStatus'], 200);
      expect(fresh['token'], isNotNull);
    });

    test('a code works only once', () async {
      await register('carol@example.com');
      await call(
          '/api/v1/auth/forgot-password', {'email': 'carol@example.com'});
      final code = mailer.lastCode!;

      expect((await reset('carol@example.com', code))['httpStatus'], 200);
      final again = await reset('carol@example.com', code, newKey: 3);
      expect(again['httpStatus'], 400);
      expect(again['error'], 'bad_code');
      expect((await login('carol@example.com', 2))['httpStatus'], 200);
    });

    test('a wrong code changes nothing', () async {
      await register('dave@example.com');
      await call('/api/v1/auth/forgot-password', {'email': 'dave@example.com'});
      final wrong = mailer.lastCode == '000000' ? '111111' : '000000';

      final result = await reset('dave@example.com', wrong);
      expect(result['httpStatus'], 400);
      expect(result['error'], 'bad_code');
      expect((await login('dave@example.com', 1))['httpStatus'], 200);
    });

    test('an expired code is refused and burned', () async {
      await register('erin@example.com');
      await call('/api/v1/auth/forgot-password', {'email': 'erin@example.com'});
      final user = store.usersById.values.single;
      user.passwordResetCodeExpiresAtMs =
          DateTime.now().millisecondsSinceEpoch - 1;

      final result = await reset('erin@example.com', mailer.lastCode!);
      expect(result['httpStatus'], 400);
      expect(result['error'], 'code_expired');
      expect(user.passwordResetCodeHash, isNull);
      expect((await login('erin@example.com', 1))['httpStatus'], 200);
    });

    test('5 wrong attempts burn the code, even the right one after', () async {
      await register('frank@example.com');
      await call(
          '/api/v1/auth/forgot-password', {'email': 'frank@example.com'});
      final correct = mailer.lastCode!;
      final wrong = correct == '000000' ? '111111' : '000000';

      for (var i = 0; i < 5; i++) {
        expect((await reset('frank@example.com', wrong))['httpStatus'], 400,
            reason: 'attempt $i');
      }
      final locked = await reset('frank@example.com', correct);
      expect(locked['httpStatus'], 429);
      expect(locked['error'], 'too_many_attempts');
      expect(store.usersById.values.single.passwordResetCodeHash, isNull);
    });

    test('a reset code is stored apart from the verification code', () async {
      await register('gina@example.com');
      await call('/api/v1/auth/forgot-password', {'email': 'gina@example.com'});
      final user = store.usersById.values.single;
      expect(user.verificationTokenHash, isNull);
      expect(user.passwordResetCodeHash, isNotNull);
    });

    group('with a recovery key', () {
      final envelope = base64Encode(List<int>.filled(60, 5));
      final keyBox = base64Encode(List<int>.filled(52, 6));

      Future<String> signedIn(String email) async {
        await register(email);
        final result = await login(email, 1);
        return result['token'] as String;
      }

      Future<Map<String, dynamic>> authed(
          String path, String token, Object body) async {
        final response = await handler(Request(
          'POST',
          Uri.parse('http://localhost$path'),
          body: jsonEncode(body),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ));
        final raw = await response.readAsString();
        final decoded = raw.isEmpty ? const {} : jsonDecode(raw);
        return {
          if (decoded is Map<String, dynamic>) ...decoded,
          'httpStatus': response.statusCode,
        };
      }

      Future<void> setUpRecovery(String token) async {
        final result = await authed('/api/v1/account/recovery', token,
            {'recoveryEnvelope': envelope, 'recoveryKeyBox': keyBox});
        expect(result['httpStatus'], 200);
      }

      test('is stored on disk and reaches signed-in devices', () async {
        final token = await signedIn('hana@example.com');
        await setUpRecovery(token);

        final db = sqlite3.open('${dir.path}/accounts/accounts.sqlite');
        try {
          final row = db
              .select('SELECT recoveryEnvelope, recoveryKeyBox FROM users')
              .single;
          expect(row['recoveryEnvelope'], envelope);
          expect(row['recoveryKeyBox'], keyBox);
          expect(db.select('PRAGMA user_version').single.values.single, 2);
        } finally {
          db.close();
        }

        final account = await handler(Request(
          'GET',
          Uri.parse('http://localhost/api/v1/account'),
          headers: {'Authorization': 'Bearer $token'},
        ));
        final body = jsonDecode(await account.readAsString()) as Map;
        expect(body['recoveryKeyBox'], keyBox);
        expect(body.containsKey('recoveryEnvelope'), isFalse);
      });

      test('the envelope needs the emailed code and does not spend it',
          () async {
        await setUpRecovery(await signedIn('ivan@example.com'));
        await call(
            '/api/v1/auth/forgot-password', {'email': 'ivan@example.com'});
        final code = mailer.lastCode!;
        final wrong = code == '000000' ? '111111' : '000000';

        final refused = await call('/api/v1/auth/recovery-envelope',
            {'email': 'ivan@example.com', 'code': wrong});
        expect(refused['httpStatus'], 400);
        expect(refused.containsKey('recoveryEnvelope'), isFalse);

        final granted = await call('/api/v1/auth/recovery-envelope',
            {'email': 'ivan@example.com', 'code': code});
        expect(granted['httpStatus'], 200);
        expect(granted['recoveryEnvelope'], envelope);
        expect(
            store.usersById.values.single.passwordResetCodeHash, isNotNull);
      });

      test('keepData resets the password but keeps the synced data',
          () async {
        await setUpRecovery(await signedIn('jules@example.com'));
        final user = store.usersById.values.single;
        await store.writeBlob(user.id, 'notes', [1, 2, 3]);

        await call(
            '/api/v1/auth/forgot-password', {'email': 'jules@example.com'});
        final result = await call('/api/v1/auth/reset-with-code', {
          'email': 'jules@example.com',
          'code': mailer.lastCode!,
          'newAuthKey': authKey(2),
          'newKdfSalt': kdfSalt(9),
          'newKdfIterations': 200000,
          'keepData': true,
        });
        expect(result['httpStatus'], 200);
        expect(result['keptData'], isTrue);

        expect(await store.readBlob(user.id, 'notes'), [1, 2, 3]);
        expect(user.recoveryEnvelope, envelope,
            reason: 'it still opens to the key the data is sealed with');
        expect(
            store.sessionsByTokenHash.values.where((s) => s.userId == user.id),
            isEmpty);
        expect((await login('jules@example.com', 2))['httpStatus'], 200);
      });

      test('keepData without a recovery key changes nothing', () async {
        await register('kim@example.com');
        final user = store.usersById.values.single;
        await store.writeBlob(user.id, 'notes', [1, 2, 3]);
        await call(
            '/api/v1/auth/forgot-password', {'email': 'kim@example.com'});
        final code = mailer.lastCode!;

        final envelopeResult = await call('/api/v1/auth/recovery-envelope',
            {'email': 'kim@example.com', 'code': code});
        expect(envelopeResult['httpStatus'], 404);
        expect(envelopeResult['error'], 'no_recovery_key');

        final result = await call('/api/v1/auth/reset-with-code', {
          'email': 'kim@example.com',
          'code': code,
          'newAuthKey': authKey(2),
          'newKdfSalt': kdfSalt(9),
          'newKdfIterations': 200000,
          'keepData': true,
        });
        expect(result['httpStatus'], 409);
        expect(result['error'], 'no_recovery_key');
        expect(await store.readBlob(user.id, 'notes'), [1, 2, 3]);
        expect((await login('kim@example.com', 1))['httpStatus'], 200);
        expect(user.passwordResetCodeHash, isNotNull);
      });

      test('a reset without it erases the data and the envelope', () async {
        await setUpRecovery(await signedIn('lena@example.com'));
        final user = store.usersById.values.single;
        await store.writeBlob(user.id, 'notes', [1, 2, 3]);

        await call(
            '/api/v1/auth/forgot-password', {'email': 'lena@example.com'});
        final result = await reset('lena@example.com', mailer.lastCode!);
        expect(result['httpStatus'], 200);
        expect(await store.readBlob(user.id, 'notes'), isNull);
        expect(user.recoveryEnvelope, isNull);
        expect(user.recoveryKeyBox, isNull);
      });

      test('a password change replaces the pair, or drops a stale one',
          () async {
        final token = await signedIn('max@example.com');
        await setUpRecovery(token);
        final user = store.usersById.values.single;
        final newEnvelope = base64Encode(List<int>.filled(60, 8));
        final newBox = base64Encode(List<int>.filled(52, 9));

        final changed = await authed('/api/v1/auth/change', token, {
          'currentAuthKey': authKey(1),
          'newAuthKey': authKey(2),
          'newKdfSalt': kdfSalt(9),
          'newKdfIterations': 200000,
          'recoveryEnvelope': newEnvelope,
          'recoveryKeyBox': newBox,
        });
        expect(changed['httpStatus'], 200);
        expect(user.recoveryEnvelope, newEnvelope);
        expect(user.recoveryKeyBox, newBox);

        final again = await authed('/api/v1/auth/change', token, {
          'currentAuthKey': authKey(2),
          'newAuthKey': authKey(3),
          'newKdfSalt': kdfSalt(9),
          'newKdfIterations': 200000,
        });
        expect(again['httpStatus'], 200);
        expect(user.recoveryEnvelope, isNull);
        expect(user.recoveryKeyBox, isNull);
      });

      test('half a pair is refused', () async {
        final token = await signedIn('nora@example.com');
        final result = await authed('/api/v1/account/recovery', token,
            {'recoveryEnvelope': envelope});
        expect(result['httpStatus'], 400);
        expect(store.usersById.values.single.recoveryEnvelope, isNull);
      });
    });
  });
}

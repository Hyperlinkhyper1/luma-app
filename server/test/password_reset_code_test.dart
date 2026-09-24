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
  });
}

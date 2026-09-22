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

/// Stands in for Resend: records the last code handed to it instead of
/// making a real HTTP call, so tests can read back what "arrived by email"
/// without any network access.
class _CapturingMailer extends Mailer {
  _CapturingMailer() : super(MailConfig.fromEnvironment(const {}));

  String? lastToEmail;
  String? lastCode;
  int sendCount = 0;

  @override
  Future<void> sendVerificationCode({
    required String toEmail,
    required String code,
  }) async {
    sendCount++;
    lastToEmail = toEmail;
    lastCode = code;
  }
}

void main() {
  group('email verification codes', () {
    late Directory dir;
    late Store store;
    late _CapturingMailer mailer;
    late Handler handler;

    String authKey(int fill) => base64Encode(List<int>.filled(32, fill));
    String kdfSalt() => base64Encode(List<int>.filled(16, 7));

    /// [maxVerificationEmailsPerHour] is parameterised so the rate-limit
    /// test can build its own server with a tiny budget without disturbing
    /// the others.
    Future<void> setUpApi({int maxVerificationEmailsPerHour = 50}) async {
      dir = await Directory.systemTemp.createTemp('luma_verify_test');
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
        maxVerificationEmailsPerHour: maxVerificationEmailsPerHour,
        approvalMode: ApprovalMode.email,
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
    }

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> call(
      String method,
      String path, {
      Object? body,
    }) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {if (body != null) 'Content-Type': 'application/json'},
      ));
      final raw = await response.readAsString();
      final decoded = raw.isEmpty ? const {} : jsonDecode(raw);
      return {
        if (decoded is Map<String, dynamic>) ...decoded,
        'httpStatus': response.statusCode,
      };
    }

    Future<Map<String, dynamic>> register(String email) => call(
          'POST',
          '/api/v1/auth/register',
          body: {
            'email': email,
            'authKey': authKey(1),
            'kdfSalt': kdfSalt(),
            'kdfIterations': 200000,
          },
        );

    test('registering issues a pending account and a 6-digit code', () async {
      await setUpApi();
      final result = await register('alice@example.com');
      expect(result['httpStatus'], 201);
      expect(result['token'], isNull);
      expect(result['approval'], 'email');
      expect(mailer.sendCount, 1);
      expect(mailer.lastToEmail, 'alice@example.com');
      expect(RegExp(r'^\d{6}$').hasMatch(mailer.lastCode!), isTrue);
      expect(store.usersById.values.single.status, 'pending');
    });

    test('the correct code activates the account and unlocks sign-in',
        () async {
      await setUpApi();
      await register('bob@example.com');
      final code = mailer.lastCode!;

      final verified = await call('POST', '/api/v1/auth/verify-code',
          body: {'email': 'bob@example.com', 'code': code});
      expect(verified['httpStatus'], 200);
      expect(store.usersById.values.single.status, 'active');

      final login = await call('POST', '/api/v1/auth/login', body: {
        'email': 'bob@example.com',
        'authKey': authKey(1),
      });
      expect(login['httpStatus'], 200);
      expect(login['token'], isNotNull);
    });

    test('a wrong code is rejected and the account stays pending', () async {
      await setUpApi();
      await register('carol@example.com');
      final wrong = mailer.lastCode == '000000' ? '111111' : '000000';

      final result = await call('POST', '/api/v1/auth/verify-code',
          body: {'email': 'carol@example.com', 'code': wrong});
      expect(result['httpStatus'], 400);
      expect(result['error'], 'bad_code');
      expect(store.usersById.values.single.status, 'pending');
    });

    test('5 wrong attempts locks out and burns the code, even the right one',
        () async {
      await setUpApi();
      await register('dave@example.com');
      final correctCode = mailer.lastCode!;
      final wrong = correctCode == '000000' ? '111111' : '000000';

      for (var i = 0; i < 5; i++) {
        final result = await call('POST', '/api/v1/auth/verify-code',
            body: {'email': 'dave@example.com', 'code': wrong});
        expect(result['httpStatus'], 400, reason: 'attempt $i');
      }

      // The 6th attempt is locked out even with the code that was actually
      // correct — the attempt budget, not the guess, is what's exhausted.
      final locked = await call('POST', '/api/v1/auth/verify-code',
          body: {'email': 'dave@example.com', 'code': correctCode});
      expect(locked['httpStatus'], 429);
      expect(locked['error'], 'too_many_attempts');
      expect(store.usersById.values.single.status, 'pending');
      expect(store.usersById.values.single.verificationTokenHash, isNull);
    });

    test('resending issues a fresh code that supersedes the old one',
        () async {
      await setUpApi();
      await register('erin@example.com');
      final oldCode = mailer.lastCode!;

      final resent = await call('POST', '/api/v1/auth/resend-verification',
          body: {'email': 'erin@example.com'});
      expect(resent['httpStatus'], 200);
      final newCode = mailer.lastCode!;
      expect(newCode, isNot(oldCode));

      final oldAttempt = await call('POST', '/api/v1/auth/verify-code',
          body: {'email': 'erin@example.com', 'code': oldCode});
      expect(oldAttempt['httpStatus'], 400);

      final newAttempt = await call('POST', '/api/v1/auth/verify-code',
          body: {'email': 'erin@example.com', 'code': newCode});
      expect(newAttempt['httpStatus'], 200);
    });

    test(
        'exceeding the hourly verification-email budget refuses further '
        'sends and leaves no pending account behind', () async {
      // A budget of 2 is below the hardcoded per-IP limiter's own budget of
      // 3, so the global limiter is deterministically what trips here.
      await setUpApi(maxVerificationEmailsPerHour: 2);

      final first = await register('first@example.com');
      expect(first['httpStatus'], 201);
      final second = await register('second@example.com');
      expect(second['httpStatus'], 201);

      final third = await register('third@example.com');
      expect(third['httpStatus'], 429);
      expect(third['error'], 'rate_limited');
      // Refused before any account was ever written for it.
      expect(store.userIdByEmail.containsKey('third@example.com'), isFalse);
      expect(mailer.sendCount, 2);
    });

    test('/auth/verify-code is inert outside email-approval mode', () async {
      await setUpApi();
      // Flip the running server's mode indirectly is not possible here, so
      // this exercises the same guard a manual/open deployment relies on by
      // asking with an email that was never registered under this (email)
      // mode config: the endpoint itself must still 400/404 rather than 200
      // for a nonexistent pending account, which the earlier "wrong code"
      // test already covers. The mode gate itself is covered by inspecting
      // the response shape directly against a manual-mode server:
      final manualDir = await Directory.systemTemp.createTemp('luma_manual');
      addTearDown(() async {
        if (await manualDir.exists()) await manualDir.delete(recursive: true);
      });
      final manualStore = await Store.open(manualDir.path);
      final manualConfig = ServerConfig(
        port: 0,
        dataDir: manualDir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(minutes: 10),
        maxVerificationEmailsPerHour: 50,
        approvalMode: ApprovalMode.manual,
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
      final manualHandler = Api(
        manualStore,
        manualConfig,
        _CapturingMailer(),
        await FamilyStore.open(manualDir.path),
        await ChatStore.open(manualDir.path),
        await AiUsageStore.open(manualDir.path),
        await SubwayStore.open(manualDir.path),
        await RecipeStore.open(manualDir.path),
        await AiModelCatalogStore.open(manualDir.path),
        await AiBenchmarkStore.open(manualDir.path),
      ).handler;

      final response = await manualHandler(Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/verify-code'),
        body: jsonEncode({'email': 'anyone@example.com', 'code': '123456'}),
        headers: {'Content-Type': 'application/json'},
      ));
      expect(response.statusCode, 403);
    });
  });
}

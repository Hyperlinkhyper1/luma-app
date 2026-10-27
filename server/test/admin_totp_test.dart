import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/admin_totp.dart';
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

/// The admin dashboard's second factor: every sign-in takes the admin key
/// and the authenticator app's current 30-second code.
void main() {
  group('TOTP primitives', () {
    // RFC 6238 appendix B, SHA-1, truncated to the 6 digits apps show.
    final rfcSecret = utf8.encode('12345678901234567890');

    test('matches the RFC 6238 test vectors', () {
      expect(totpCode(rfcSecret, totpStep(59 * 1000)), '287082');
      expect(totpCode(rfcSecret, totpStep(1111111109 * 1000)), '081804');
      expect(totpCode(rfcSecret, totpStep(1234567890 * 1000)), '005924');
      expect(totpCode(rfcSecret, totpStep(2000000000 * 1000)), '279037');
    });

    test('base32 round-trips and ignores spacing and case', () {
      final bytes = [0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, 0xde, 0xad, 0xbe, 0xef];
      expect(base32Encode(bytes), 'JBSWY3DPEHPK3PXP');
      expect(base32Decode('jbsw y3dp-ehpk 3pxp'), bytes);
      expect(base32Decode('not base32!'), isNull);
    });
  });

  group('admin sign-in with an authenticator', () {
    late Directory dir;
    late Store store;
    late Handler handler;
    const adminKey = 'test-admin-key-that-is-long-enough-123';

    Future<Handler> build({String? totpSecret}) async {
      final config = ServerConfig(
        port: 0,
        dataDir: dir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(hours: 24),
        maxVerificationEmailsPerHour: 50,
        approvalMode: ApprovalMode.open,
        adminKey: adminKey,
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
        adminTotpRequired: true,
        adminTotpSecret: totpSecret,
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
        await AiBenchmarkStore.open(dir.path),
      ).handler;
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('luma_admin_totp');
      store = await Store.open(dir.path);
      handler = await build();
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Response> form(String path, Map<String, String> fields) =>
        Future.value(handler(Request(
          'POST',
          Uri.parse('http://localhost$path'),
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            'origin': 'http://localhost',
          },
          body: Uri(queryParameters: fields).query,
        )));

    Future<Response> withCookie(String cookie) => Future.value(handler(Request(
          'GET',
          Uri.parse('http://localhost/admin/deploy/status'),
          headers: {'cookie': cookie},
        )));

    String cookieOf(Response response) =>
        response.headers['set-cookie']!.split(';').first;

    int nowStep() => totpStep(DateTime.now().millisecondsSinceEpoch);

    /// Signs in with the key, reads the setup key off the enrollment page
    /// and confirms it with a code — what the operator does once.
    Future<(List<int>, Response)> enroll() async {
      final page = await form('/admin/login', {'key': adminKey});
      expect(page.statusCode, 200);
      final html = await page.readAsString();
      final token =
          RegExp(r'name="enrollment" value="([^"]+)"').firstMatch(html)![1]!;
      final uri = RegExp(r'secret=([A-Z2-7]+)').firstMatch(html)![1]!;
      final secret = base32Decode(uri)!;
      final done = await form('/admin/login/enroll',
          {'enrollment': token, 'code': totpCode(secret, nowStep())});
      return (secret, done);
    }

    test('the first sign-in enrolls the app and signs in', () async {
      final (_, done) = await enroll();
      expect(done.statusCode, 302);
      expect(done.headers['location'], '/admin');
      final ok = await withCookie(cookieOf(done));
      expect(ok.statusCode, 200);
      expect(File('${dir.path}/admin_totp.json').existsSync(), isTrue);
    });

    test('a wrong code does not enroll', () async {
      final page = await form('/admin/login', {'key': adminKey});
      final html = await page.readAsString();
      final token =
          RegExp(r'name="enrollment" value="([^"]+)"').firstMatch(html)![1]!;
      final wrong = await form(
          '/admin/login/enroll', {'enrollment': token, 'code': '000000'});
      expect(wrong.statusCode, 200);
      expect(await wrong.readAsString(), contains('did not match'));
      expect(File('${dir.path}/admin_totp.json').existsSync(), isFalse);
    });

    test('a wrong admin key never reaches enrollment', () async {
      final response = await form('/admin/login', {'key': 'nope'});
      expect(response.statusCode, 302);
      expect(response.headers['location'], '/admin/login?failed=1');
    });

    test('once enrolled, the key alone is refused', () async {
      await enroll();
      final response = await form('/admin/login', {'key': adminKey});
      expect(response.statusCode, 302);
      expect(response.headers['location'], '/admin/login?failed=1');
    });

    test('key plus a fresh code signs in, but a code works only once',
        () async {
      final (secret, _) = await enroll();
      // The enrollment burned the current step, so its code is spent.
      final replay = await form('/admin/login',
          {'key': adminKey, 'code': totpCode(secret, nowStep())});
      expect(replay.headers['location'], '/admin/login?failed=1');

      // The next step's code is inside the one-step drift window.
      handler = await build();
      final next = await form('/admin/login',
          {'key': adminKey, 'code': totpCode(secret, nowStep() + 1)});
      expect(next.headers['location'], '/admin');
      expect((await withCookie(cookieOf(next))).statusCode, 200);
    });

    test('the code is checked across a restart from the saved secret',
        () async {
      final (secret, _) = await enroll();
      handler = await build();
      final page = await handler(
          Request('GET', Uri.parse('http://localhost/admin/login')));
      expect(await page.readAsString(), contains('name="code"'));
      final stale = await form('/admin/login',
          {'key': adminKey, 'code': totpCode(secret, nowStep() - 5)});
      expect(stale.headers['location'], '/admin/login?failed=1');
    });

    test('the X-Admin-Key header also needs X-Admin-Totp', () async {
      final (secret, _) = await enroll();
      Future<Response> call(Map<String, String> headers) =>
          Future.value(handler(Request(
            'GET',
            Uri.parse('http://localhost/admin/deploy/status'),
            headers: headers,
          )));
      final keyOnly = await call({'x-admin-key': adminKey});
      expect(keyOnly.statusCode, 401);
      expect(await keyOnly.readAsString(), contains('totp_required'));

      handler = await build();
      final both = await call({
        'x-admin-key': adminKey,
        'x-admin-totp': totpCode(secret, nowStep()),
      });
      expect(both.statusCode, 200);
    });

    test('the header is refused before anything is enrolled', () async {
      final response = await handler(Request(
        'GET',
        Uri.parse('http://localhost/admin/deploy/status'),
        headers: {'x-admin-key': adminKey},
      ));
      expect(response.statusCode, 403);
      expect(await response.readAsString(), contains('totp_not_enrolled'));
    });

    test('LUMA_ADMIN_TOTP_SECRET skips enrollment', () async {
      final secret = AdminTotp.newSecret();
      handler = await build(totpSecret: base32Encode(secret));
      final keyOnly = await form('/admin/login', {'key': adminKey});
      expect(keyOnly.headers['location'], '/admin/login?failed=1');

      handler = await build(totpSecret: base32Encode(secret));
      final ok = await form('/admin/login',
          {'key': adminKey, 'code': totpCode(secret, nowStep())});
      expect(ok.headers['location'], '/admin');
    });

    test('a malformed LUMA_ADMIN_TOTP_SECRET locks the dashboard', () async {
      handler = await build(totpSecret: 'not!base32');
      final response = await form('/admin/login', {'key': adminKey});
      expect(response.headers['location'], '/admin/login');
      expect(File('${dir.path}/admin_totp.json').existsSync(), isFalse);
    });
  });

  test('a short LUMA_ADMIN_KEY disables the dashboard', () {
    expect(
        ServerConfig.fromEnvironment(const {'LUMA_ADMIN_KEY': 'hunter2'})
            .adminEnabled,
        isFalse);
    final strong = 'a' * ServerConfig.minAdminKeyLength;
    final config =
        ServerConfig.fromEnvironment({'LUMA_ADMIN_KEY': strong});
    expect(config.adminEnabled, isTrue);
    expect(config.adminTotpRequired, isTrue);
  });
}

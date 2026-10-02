import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
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

/// Account emails are attacker-chosen — the server only checks their rough
/// shape, so `'`, `"`, `<` and `(` all pass — and the dashboard shows them to
/// the operator. These tests register such an account and check that it
/// cannot break out of any attribute or inline-handler string on /admin.
///
/// Also covers the bodies that used to be buffered whole before their size
/// was checked, one of them on a route anyone can reach.
void main() {
  late Directory dir;
  late Store store;
  late Handler handler;

  const hostileEmail = "a'+alert(1)+'\"x<b>@x.co";

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_admin_escaping_test');
    store = await Store.open(dir.path);
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
      adminKey: 'test-admin-key',
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
      Mailer(MailConfig.fromEnvironment(const {})),
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

  Future<Response> send(
    String method,
    String path, {
    Object? json,
    String? form,
    Object? body,
    String? token,
    bool admin = false,
  }) =>
      Future.value(handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          if (json != null) 'Content-Type': 'application/json',
          if (form != null) 'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
          if (admin) 'x-admin-key': 'test-admin-key',
        },
        body: json != null ? jsonEncode(json) : form ?? body,
      )));

  Future<String> register(String email) async {
    final response = await send('POST', '/api/v1/auth/register', json: {
      'email': email,
      'authKey': base64Encode(
          c.sha256.convert(utf8.encode('key:$email')).bytes),
      'kdfSalt': base64Encode(List.filled(16, 7)),
      'kdfIterations': 210000,
    });
    final raw = await response.readAsString();
    expect(response.statusCode, 201, reason: 'register: $raw');
    return (jsonDecode(raw) as Map<String, dynamic>)['token'] as String;
  }

  String decodeEntities(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  test('a hostile email cannot escape the dashboard markup', () async {
    final token = await register(hostileEmail);
    // Put the account on every dashboard surface that renders an email inside
    // an inline handler: the users table, the paid-plan list and the inbox.
    final plan = await send('POST', '/admin/plan',
        admin: true,
        form: 'email=${Uri.encodeQueryComponent(hostileEmail)}&planId=orbit');
    expect(plan.statusCode, lessThan(400), reason: await plan.readAsString());
    final deletion = await send('POST', '/api/v1/account/deletion-request',
        token: token, json: {'reason': 'please'});
    expect(deletion.statusCode, lessThan(400),
        reason: await deletion.readAsString());

    final response = await send('GET', '/admin', admin: true);
    expect(response.statusCode, 200);
    final html = await response.readAsString();

    // Attribute values: the email's own `"` must not end the attribute.
    expect(html, isNot(contains('"x<b>')));
    expect(html, contains('value="a&#39;+alert(1)+&#39;&quot;x&lt;b&gt;@x.co"'));

    // Inline handlers: what the JS engine sees after the HTML parser has
    // decoded the attribute must not contain a bare quote from the email.
    final handlers = RegExp(r'on(?:submit|click)="([^"]*)"')
        .allMatches(html)
        .map((m) => decodeEntities(m.group(1)!))
        .where((js) => js.contains('alert(1)'))
        .toList();
    expect(handlers.length, greaterThanOrEqualTo(3),
        reason: 'expected the users table, plan list and inbox to all '
            'mention the account in a confirm()');
    for (final js in handlers) {
      expect(js, isNot(contains("'+alert(1)+'")), reason: js);
      final quote = '${String.fromCharCode(92)}u0027';
      expect(js, contains('a$quote+alert(1)+$quote'), reason: js);
    }
  });

  test('the admin login form refuses an oversized body', () async {
    final response = await send('POST', '/admin/login',
        body: Stream<List<int>>.fromIterable(
            List.generate(64, (_) => Uint8List(1024))));
    expect(response.statusCode, 302);
    expect(response.headers['location'], '/admin/login?failed=1');
  });

  test('co-op room state is capped while it streams in', () async {
    final token = await register('player@example.com');
    final created = await send('POST', '/api/v1/subway/rooms', token: token);
    final code = (jsonDecode(await created.readAsString())
        as Map<String, dynamic>)['code'] as String;

    // No Content-Length: only the streaming cap can stop this one.
    final tooBig = await send('PUT', '/api/v1/subway/rooms/$code/state',
        token: token,
        body: Stream<List<int>>.fromIterable(
            List.generate(5, (_) => Uint8List(1024 * 1024))));
    expect(tooBig.statusCode, 413);

    final fine = await send('PUT', '/api/v1/subway/rooms/$code/state',
        token: token, body: '{"lines":[]}');
    expect(fine.statusCode, 200);
  });
}

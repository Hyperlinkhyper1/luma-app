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

/// The dashboard's Messages tab, end to end: a message sent to everyone or to
/// chosen accounts shows up in exactly those accounts' inboxes, and each
/// account's read state is its own.
void main() {
  late Directory dir;
  late Store store;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_admin_messages_test');
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

  Future<String> register(String email) async {
    final result = await call('POST', '/api/v1/auth/register', json: {
      'email': email,
      'authKey': base64Encode(authKeyFor('password-1')),
      'kdfSalt': base64Encode(List.filled(16, 7)),
      'kdfIterations': 210000,
    });
    expect(result['httpStatus'], 201, reason: 'register: $result');
    return result['token'] as String;
  }

  Future<List> inbox(String token) async {
    final r = await call('GET', '/api/v1/messages', token: token);
    expect(r['httpStatus'], 200);
    return r['messages'] as List;
  }

  String form(Map<String, List<String>> fields) => [
        for (final e in fields.entries)
          for (final v in e.value)
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(v)}',
      ].join('&');

  test('a broadcast reaches everyone, a targeted message only its picks',
      () async {
    final a = await register('a@example.com');
    final b = await register('b@example.com');

    final all = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['Maintenance'],
          'body': ['Back at noon.'],
          'audience': ['all'],
        }));
    expect(all['httpStatus'], 200);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final one = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['Just you'],
          'body': ['Hi A.'],
          'audience': ['selected'],
          'email': ['A@example.com'],
        }));
    expect(one['httpStatus'], 200);

    expect((await inbox(a)).map((m) => (m as Map)['title']),
        unorderedEquals(['Maintenance', 'Just you']));
    expect((await inbox(b)).map((m) => (m as Map)['title']), ['Maintenance']);

    // An account made after the broadcast does not get it.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final late = await register('late@example.com');
    expect(await inbox(late), isEmpty);
  });

  test('read state is per account', () async {
    final a = await register('a@example.com');
    final b = await register('b@example.com');
    final sent = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['Hello'],
          'body': ['Everyone.'],
          'audience': ['all'],
        }));
    final id = sent['id'] as String;

    expect(((await inbox(a)).single as Map)['read'], false);
    final marked = await call('POST', '/api/v1/messages/$id/read', token: a);
    expect(marked['httpStatus'], 200);
    expect(((await inbox(a)).single as Map)['read'], true);
    expect(((await inbox(b)).single as Map)['read'], false);
  });

  test('bad sends are refused and a message cannot be read by a stranger',
      () async {
    final a = await register('a@example.com');
    final b = await register('b@example.com');

    final unknown = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['x'],
          'body': ['y'],
          'audience': ['selected'],
          'email': ['nobody@example.com'],
        }));
    expect(unknown['httpStatus'], 404);

    final none = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['x'],
          'body': ['y'],
          'audience': ['selected'],
        }));
    expect(none['httpStatus'], 400);

    final blank = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': [' '],
          'body': ['y'],
          'audience': ['all'],
        }));
    expect(blank['httpStatus'], 400);

    final notAdmin = await call('POST', '/admin/messages/send',
        form: form({
          'title': ['x'],
          'body': ['y'],
          'audience': ['all'],
        }));
    expect(notAdmin['httpStatus'], isNot(200));
    expect(store.adminMessagesById, isEmpty);

    final sent = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['Private'],
          'body': ['For A.'],
          'audience': ['selected'],
          'email': ['a@example.com'],
        }));
    final stranger = await call(
        'POST', '/api/v1/messages/${sent['id']}/read',
        token: b);
    expect(stranger['httpStatus'], 404);
    expect(await inbox(a), hasLength(1));
  });

  test('deleting a message removes it from inboxes', () async {
    final a = await register('a@example.com');
    final sent = await call('POST', '/admin/messages/send',
        admin: true,
        form: form({
          'title': ['Oops'],
          'body': ['Wrong text.'],
          'audience': ['all'],
        }));
    expect(await inbox(a), hasLength(1));
    final gone = await call('POST', '/admin/messages/delete',
        admin: true, form: 'id=${Uri.encodeQueryComponent(sent['id'] as String)}');
    expect(gone['httpStatus'], 200);
    expect(await inbox(a), isEmpty);
  });
}

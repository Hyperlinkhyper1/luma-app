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

/// The server's equivalent of row-level security. Every account's data is
/// keyed by the session's user id, never by an id the caller supplies, and
/// shared data (families, chats, rooms) checks membership on every call.
/// These tests sign in as a second account and try to reach the first one's
/// data through every user-facing route.
///
/// The second half stores the literal text "null" everywhere a user can type
/// and checks it comes back as text — not as a missing value — including
/// after the server restarts and reloads everything from disk.
void main() {
  late Directory dir;
  late Handler handler;

  late Store store;

  /// Reloads feature stores to cover persisted shared data. The account
  /// store is reused because only feature text fields are under test.
  Future<Handler> openServer({bool reuseAccounts = false}) async {
    if (!reuseAccounts) store = await Store.open(dir.path);
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
    dir = await Directory.systemTemp.createTemp('luma_data_isolation_test');
    handler = await openServer();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<Response> send(String method, String path,
      {Object? json, String? raw, List<int>? bytes, String? token,
      Map<String, String> headers = const {}}) {
    return Future.value(handler(Request(
      method,
      Uri.parse('http://localhost/api/v1$path'),
      headers: {
        if (json != null || raw != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        ...headers,
      },
      body: json != null ? jsonEncode(json) : (raw ?? bytes),
    )));
  }

  Future<Map<String, dynamic>> call(String method, String path,
      {Object? json, String? raw, String? token}) async {
    final response =
        await send(method, path, json: json, raw: raw, token: token);
    final body = await response.readAsString();
    return {
      ...(body.trimLeft().startsWith('{')
          ? jsonDecode(body) as Map<String, dynamic>
          : const <String, dynamic>{}),
      'httpStatus': response.statusCode,
    };
  }

  Future<String> register(String email, {bool verified = true}) async {
    final authKey = c.sha256.convert(utf8.encode('key:$email')).bytes;
    final result = await call('POST', '/auth/register', json: {
      'email': email,
      'authKey': base64Encode(authKey),
      'kdfSalt': base64Encode(List.filled(16, 7)),
      'kdfIterations': 210000,
    });
    expect(result['httpStatus'], 201, reason: 'register: $result');
    // As if each person had confirmed the code emailed to them: accepting a
    // family or chat invite needs a verified address.
    if (verified) {
      store.usersById[store.userIdByEmail[email]]!.emailVerifiedAtMs =
          DateTime.now().millisecondsSinceEpoch;
    }
    return result['token'] as String;
  }

  Future<int> putBlob(String token, String name, List<int> bytes,
      {int base = 0}) async {
    final r = await send('PUT', '/sync/$name',
        bytes: bytes, token: token, headers: {'X-Base-Version': '$base'});
    return r.statusCode;
  }

  Future<Uint8List?> getBlob(String token, String name) async {
    final r = await send('GET', '/sync/$name', token: token);
    if (r.statusCode != 200) return null;
    final out = BytesBuilder();
    await for (final chunk in r.read()) {
      out.add(chunk);
    }
    return out.takeBytes();
  }

  group('an unverified email is not an identity', () {
    test('invites need a verified address, which a code then proves',
        () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com', verified: false);
      final familyId = (await call('POST', '/family',
          json: {'name': 'Home'}, token: a))['id'] as String;
      final invite = await call('POST', '/family/$familyId/invite',
          json: {'email': 'b@example.com'}, token: a);

      final refused = await call(
          'POST', '/family/invites/${invite['id']}/accept',
          token: b);
      expect(refused['httpStatus'], 403);
      expect(refused['error'], 'email_unverified');

      // No mailer on this server, so it says so instead of pretending.
      final send = await call('POST', '/account/email/send-code', token: b);
      expect(send['httpStatus'], 503);

      // Plant the code a configured mailer would have sent.
      final user = store.usersById[store.userIdByEmail['b@example.com']]!;
      user
        ..verificationTokenHash =
            c.sha256.convert(utf8.encode('424242')).toString()
        ..verificationExpiresAtMs =
            DateTime.now().millisecondsSinceEpoch + 60000;
      final wrong = await call('POST', '/account/email/verify',
          json: {'code': '000000'}, token: b);
      expect(wrong['error'], 'bad_code');
      final ok = await call('POST', '/account/email/verify',
          json: {'code': '424242'}, token: b);
      expect(ok['verified'], isTrue);
      expect(user.emailVerifiedAtMs, isNotNull);

      final accepted = await call(
          'POST', '/family/invites/${invite['id']}/accept',
          token: b);
      expect(accepted['httpStatus'], 200);
    });
  });

  group('chat keys', () {
    test('a stolen token cannot swap in a new chat key', () async {
      final a = await register('a@example.com');
      final first = base64Encode(List.filled(32, 1));
      final second = base64Encode(List.filled(32, 2));
      expect((await call('PUT', '/chat/key',
          json: {'publicKey': first}, token: a))['httpStatus'], 200);
      // Re-sending the same key is always fine.
      expect((await call('PUT', '/chat/key',
          json: {'publicKey': first}, token: a))['httpStatus'], 200);

      // A fresh sign-in may replace it — that is what a new device does.
      expect((await call('PUT', '/chat/key',
          json: {'publicKey': second}, token: a))['httpStatus'], 200);

      // An old session may not.
      final session = store.sessionsByTokenHash.values
          .firstWhere((s) => s.userId == store.userIdByEmail['a@example.com']);
      store.sessionsByTokenHash[session.tokenHash] = StoredSession(
        tokenHash: session.tokenHash,
        userId: session.userId,
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        expiresAtMs: session.expiresAtMs,
      );
      final refused = await call('PUT', '/chat/key',
          json: {'publicKey': first}, token: a);
      expect(refused['httpStatus'], 403);
      expect(refused['error'], 'reauth_required');
    });
  });

  group('one account cannot reach another account\'s data', () {
    test('sync snapshots are per account, even under the same name',
        () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      expect(await putBlob(a, 'notes', [1, 2, 3]), 200);

      expect(await getBlob(b, 'notes'), isNull);
      // B writing "notes" makes B's own copy and leaves A's alone.
      expect(await putBlob(b, 'notes', [9]), 200);
      expect((await call('DELETE', '/sync/notes', token: b))['httpStatus'],
          200);
      expect(await getBlob(a, 'notes'), [1, 2, 3]);

      final info = await call('GET', '/account', token: b);
      expect(info['usedBytes'], 0);
    });

    test('sessions can only be listed and revoked by their owner', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final aSessions = await call('GET', '/auth/sessions', token: a);
      final aSessionId =
          ((aSessions['sessions'] as List).single as Map)['id'] as String;

      final bSessions = await call('GET', '/auth/sessions', token: b);
      expect((bSessions['sessions'] as List).map((s) => (s as Map)['id']),
          isNot(contains(aSessionId)));
      final revoke =
          await call('POST', '/auth/sessions/$aSessionId/revoke', token: b);
      expect(revoke['httpStatus'], 404);
      expect((await call('GET', '/account', token: a))['httpStatus'], 200);
    });

    test('a family and its events are closed to outsiders', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final family =
          await call('POST', '/family', json: {'name': 'Home'}, token: a);
      final familyId = family['id'] as String;
      final event = await call('POST', '/family/$familyId/events',
          json: {'title': 'Dentist', 'startMs': 1, 'endMs': 2}, token: a);
      final eventId = event['id'] as String;

      expect((await call('GET', '/family', token: b))['httpStatus'], 404);
      // An outsider can't tell a real family from a made-up id.
      for (final id in [familyId, 'no-such-family']) {
        for (final (method, path, body) in [
          ('GET', '/family/$id/events', null),
          ('POST', '/family/$id/events',
              {'title': 'x', 'startMs': 1, 'endMs': 2}),
          ('PUT', '/family/$id/events/$eventId',
              {'title': 'x', 'startMs': 1, 'endMs': 2}),
          ('DELETE', '/family/$id/events/$eventId', null),
          ('POST', '/family/$id/invite', {'email': 'b@example.com'}),
          ('POST', '/family/$id/members/someone/remove', null),
          ('POST', '/family/$id/delete', null),
        ]) {
          final r = await call(method, path, json: body, token: b);
          expect(r['httpStatus'], 404, reason: '$method $path: $r');
        }
      }

      final events = await call('GET', '/family/$familyId/events', token: a);
      expect(((events['events'] as List).single as Map)['title'], 'Dentist');
    });

    test('leaving a family ends write access to events you wrote', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final familyId = (await call('POST', '/family',
          json: {'name': 'Home'}, token: a))['id'] as String;
      final invite = await call('POST', '/family/$familyId/invite',
          json: {'email': 'b@example.com'}, token: a);
      await call('POST', '/family/invites/${invite['id']}/accept', token: b);
      final eventId = (await call('POST', '/family/$familyId/events',
          json: {'title': 'Mine', 'startMs': 1, 'endMs': 2},
          token: b))['id'] as String;

      final family = await call('GET', '/family', token: a);
      final bId = ((family['members'] as List)
              .firstWhere((m) => (m as Map)['role'] == 'member') as Map)[
          'userId'] as String;
      await call('POST', '/family/$familyId/members/$bId/remove', token: a);

      final edit = await call('PUT', '/family/$familyId/events/$eventId',
          json: {'title': 'Changed', 'startMs': 1, 'endMs': 2}, token: b);
      expect(edit['httpStatus'], 404);
      final delete = await call(
          'DELETE', '/family/$familyId/events/$eventId',
          token: b);
      expect(delete['httpStatus'], 404);
    });

    test('a chat is visible only to its two members', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final outsider = await register('c@example.com');
      final key = base64Encode(List.filled(32, 1));
      for (final t in [a, b, outsider]) {
        await call('PUT', '/chat/key', json: {'publicKey': key}, token: t);
      }
      final invite = await call('POST', '/chat/invite',
          json: {'email': 'b@example.com'}, token: a);
      final conversation = await call(
          'POST', '/chat/invites/${invite['id']}/accept',
          token: b);
      final conversationId = conversation['id'] as String;
      final aId = conversation['peerUserId'] as String;
      await call('POST', '/chat/conversations/$conversationId/messages',
          json: {'blobForRecipient': 'x', 'blobForSender': 'y'}, token: a);

      final read = await call(
          'GET', '/chat/conversations/$conversationId/messages',
          token: outsider);
      expect(read['httpStatus'], 404);
      final write = await call(
          'POST', '/chat/conversations/$conversationId/messages',
          json: {'blobForRecipient': 'x', 'blobForSender': 'y'},
          token: outsider);
      expect(write['httpStatus'], 404);
      expect(
          (await call('GET', '/chat/conversations', token: outsider))[
              'conversations'],
          isEmpty);
      // A stranger can't even confirm the account exists.
      expect((await call('GET', '/chat/key/$aId', token: outsider))[
          'httpStatus'], 404);
      expect(
          (await call('GET', '/chat/key/$aId', token: b))['httpStatus'], 200);
      // Nor accept an invite addressed to someone else.
      final second = await call('POST', '/chat/invite',
          json: {'email': 'c@example.com'}, token: b);
      expect(
          (await call('POST', '/chat/invites/${second['id']}/accept',
              token: a))['httpStatus'],
          404);
    });

    test('only a recipe\'s author can change it', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final recipe = await call('POST', '/recipes',
          json: {
            'title': 'Soup',
            'ingredients': [
              {'name': 'water'}
            ],
            'steps': ['boil'],
          },
          token: a);
      final id = recipe['id'] as String;

      final edit = await call('PUT', '/recipes/$id',
          json: {
            'title': 'Mine now',
            'ingredients': <Object>[],
            'steps': <Object>[],
          },
          token: b);
      expect(edit['httpStatus'], 403);
      expect((await call('DELETE', '/recipes/$id', token: b))['httpStatus'],
          403);
      final photo = await send('POST', '/recipes/$id/photo',
          bytes: [1, 2, 3], token: b);
      expect(photo.statusCode, 403);
      expect((await call('GET', '/recipes/$id', token: a))['title'], 'Soup');
    });

    test('a subway room is closed to non-members and codes cannot be guessed',
        () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final code = (await call('POST', '/subway/rooms', token: a))['code']
          as String;
      await call('PUT', '/subway/rooms/$code/state',
          json: {'stations': []}, token: a);

      // A live room looks exactly like a missing one to a non-member.
      for (final (method, path) in [
        ('GET', '/subway/rooms/$code/state'),
        ('PUT', '/subway/rooms/$code/state'),
        ('POST', '/subway/rooms/$code/ticket'),
        ('POST', '/subway/rooms/$code/clock/claim'),
        ('POST', '/subway/rooms/$code/clock/release'),
        ('POST', '/subway/rooms/$code/invite'),
      ]) {
        final body = switch (path) {
          _ when method == 'PUT' => {'x': 1},
          _ when path.endsWith('/invite') => {'contactUserId': 'x'},
          _ => null,
        };
        final r = await call(method, path, json: body, token: b);
        expect(r['httpStatus'], 404, reason: '$method $path');
      }
      expect((await call('GET', '/subway/rooms', token: b))['rooms'], isEmpty);
    });

    test('room routes cannot be used to probe codes past the join limit',
        () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final code = (await call('POST', '/subway/rooms', token: a))['code']
          as String;

      var last = 0;
      for (var i = 0; i < 11; i++) {
        last = (await call('GET', '/subway/rooms/ZZZZZ$i/state', token: b))[
            'httpStatus'] as int;
      }
      expect(last, 429);
      expect((await call('GET', '/subway/rooms/$code/state', token: b))[
          'httpStatus'], 429);
      expect((await call('POST', '/subway/rooms/$code/join', token: b))[
          'httpStatus'], 429);
      // The owner's own room is unaffected by someone else's guessing.
      expect((await call('POST', '/subway/rooms/$code/ticket', token: a))[
          'httpStatus'], 200);
    });

    test('wrong room codes lock out joining', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');
      final code = (await call('POST', '/subway/rooms', token: a))['code']
          as String;

      var last = 0;
      for (var i = 0; i < 11; i++) {
        last = (await call('POST', '/subway/rooms/ZZZZZ$i/join', token: b))[
            'httpStatus'] as int;
      }
      expect(last, 429);
      // Once locked out, even the right code waits.
      expect((await call('POST', '/subway/rooms/$code/join', token: b))[
          'httpStatus'], 429);
    });
  });

  group('the text "null" is stored as text', () {
    test('in every free-text field, before and after a restart', () async {
      final a = await register('a@example.com');
      final b = await register('b@example.com');

      expect(await putBlob(a, 'null', utf8.encode('null')), 200);

      final recipeId = (await call('POST', '/recipes',
          json: {
            'title': 'null',
            'description': 'null',
            'category': 'null',
            'ingredients': [
              {'name': 'null', 'amount': 'null', 'unit': 'null'}
            ],
            'steps': ['null'],
          },
          token: a))['id'] as String;
      await call('POST', '/recipes/$recipeId/reviews',
          json: {'rating': 4, 'text': 'null'}, token: b);

      final familyId = (await call('POST', '/family',
          json: {'name': 'null'}, token: a))['id'] as String;
      await call('POST', '/family/$familyId/events',
          json: {
            'title': 'null',
            'description': 'null',
            'location': 'null',
            'recurrence': 'null',
            'startMs': 1,
            'endMs': 2,
          },
          token: a);

      final code = (await call('POST', '/subway/rooms', token: a))['code']
          as String;
      expect(
          (await call('PUT', '/subway/rooms/$code/state',
              json: {'place': 'null', 'lines': null}, token: a))['httpStatus'],
          200);

      Future<void> expectAllNull() async {
        expect(await getBlob(a, 'null'), utf8.encode('null'));

        final recipe = await call('GET', '/recipes/$recipeId', token: a);
        expect(recipe['title'], 'null');
        expect(recipe['description'], 'null');
        expect(recipe['category'], 'null');
        expect(recipe['ingredients'], [
          {'name': 'null', 'amount': 'null', 'unit': 'null'}
        ]);
        expect(recipe['steps'], ['null']);
        final reviews = await call('GET', '/recipes/$recipeId/reviews',
            token: a);
        expect(((reviews['reviews'] as List).single as Map)['text'], 'null');

        expect((await call('GET', '/family', token: a))['name'], 'null');
        final event = ((await call('GET', '/family/$familyId/events',
                token: a))['events'] as List)
            .single as Map;
        expect(event['title'], 'null');
        expect(event['description'], 'null');
        expect(event['location'], 'null');
        expect(event['recurrence'], 'null');

        final state = await call('GET', '/subway/rooms/$code/state', token: a);
        expect(state['place'], 'null');
        expect(state.containsKey('lines'), isTrue);
        expect(state['lines'], isNull);
      }

      await expectAllNull();
      handler = await openServer(reuseAccounts: true);
      await expectAllNull();
    });

    test('a JSON null or wrong-typed field is a 400, never a crash', () async {
      final a = await register('a@example.com');
      final familyId = (await call('POST', '/family',
          json: {'name': 'Home'}, token: a))['id'] as String;
      final code = (await call('POST', '/subway/rooms', token: a))['code']
          as String;

      for (final (method, path, raw) in [
        ('POST', '/family', 'null'),
        ('POST', '/recipes', 'null'),
        ('POST', '/chat/invite', '"null"'),
        ('PUT', '/subway/rooms/$code/state', 'null'),
        ('PUT', '/subway/rooms/$code/state', '"null"'),
        ('POST', '/family/$familyId/events',
            '{"title":"x","startMs":1,"endMs":2,"color":"null"}'),
        ('POST', '/family/$familyId/events',
            '{"title":"x","startMs":1,"endMs":2,"visibility":"subset",'
                '"memberUserIds":[null]}'),
        ('POST', '/family/$familyId/events',
            '{"title":"x","startMs":"null","endMs":2}'),
        ('POST', '/recipes',
            '{"title":"x","ingredients":[{"name":null}],"steps":[null]}'),
        ('POST', '/recipes', '{"title":null,"ingredients":null}'),
        ('POST', '/family', '{"name":null}'),
      ]) {
        final r = await call(method, path, raw: raw, token: a);
        expect(r['httpStatus'], lessThan(500),
            reason: '$method $path $raw -> $r');
      }
      // A null room state is refused rather than wiping the room.
      expect(
          (await call('PUT', '/subway/rooms/$code/state',
              raw: 'null', token: a))['httpStatus'],
          400);

      // And none of that broke the account.
      expect((await call('GET', '/family/$familyId/events', token: a))[
          'httpStatus'], 200);
    });
  });
}

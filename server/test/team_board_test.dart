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
import 'package:luma_sync_server/team_board.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A real PNG of [width] × [height] transparent pixels: correct CRCs and
/// deflated pixel data, built the way an image editor would write it.
Uint8List _pngOf(int width, int height, {List<int> trailing = const []}) {
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(body)
      ..add((ByteData(4)..setUint32(0, _crc(body))).buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  chunk('IHDR', header.buffer.asUint8List());
  final rows = <int>[];
  for (var y = 0; y < height; y++) {
    rows
      ..add(0)
      ..addAll(List.filled(width * 4, 0));
  }
  chunk('IDAT', zlib.encode(rows));
  chunk('IEND', const []);
  out.add(trailing);
  return out.takeBytes();
}

int _crc(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

final _png = _pngOf(16, 16);

void main() {
  group('files', () {
    test('names keep the last segment and need png, json or mcmeta', () {
      expect(cleanTeamBoardFileName(r'C:\mods\ruby_ore.PNG'), 'ruby_ore.PNG');
      expect(cleanTeamBoardFileName('../../etc/ruby.json'), 'ruby.json');
      expect(cleanTeamBoardFileName('fire.png.mcmeta'), 'fire.png.mcmeta');
      expect(cleanTeamBoardFileName('...hidden.json'), 'hidden.json');
      expect(cleanTeamBoardFileName('model.zip'), isNull);
      expect(cleanTeamBoardFileName('.png'), isNull);
      expect(cleanTeamBoardFileName('run.exe'), isNull);
      expect(cleanTeamBoardFileName(null), isNull);
    });

    test('a PNG has to be a whole, honest PNG', () {
      expect(teamBoardFileProblem('a.png', _png), isNull);
      expect(teamBoardFileProblem('fire.png', _pngOf(16, 512)), isNull);
      expect(teamBoardFileProblem('a.png', utf8.encode('{"a": 1}')),
          contains('not a valid PNG'));
      expect(teamBoardFileProblem('a.png', _png.sublist(0, 12)),
          contains('not a valid PNG'));

      final hidden =
          _pngOf(16, 16, trailing: utf8.encode('#!/bin/sh\nrm -rf /'));
      expect(
          teamBoardFileProblem('a.png', hidden), contains('not a valid PNG'));

      final corrupted = Uint8List.fromList(_png)..[30] ^= 0xFF;
      expect(teamBoardFileProblem('a.png', corrupted),
          contains('not a valid PNG'));

      final noEnd = _png.sublist(0, _png.length - 12);
      expect(teamBoardFileProblem('a.png', noEnd), contains('not a valid PNG'));

      expect(teamBoardFileProblem('huge.png', _pngOf(8192, 1)),
          contains('too big an image'));
    });

    test('a model or mcmeta has to be a JSON object', () {
      expect(
          teamBoardFileProblem(
              'ruby.json', utf8.encode('{"parent": "block/cube_all"}')),
          isNull);
      expect(
          teamBoardFileProblem(
              'fire.png.mcmeta',
              Uint8List.fromList(
                  [0xEF, 0xBB, 0xBF, ...utf8.encode('{"animation": {}}')])),
          isNull);
      expect(
          teamBoardFileProblem(
              'ruby.json', utf8.encode('{\n  "parent": "block/cube_all",\n}')),
          'ruby.json is not valid JSON (line 3, column 1).');
      expect(teamBoardFileProblem('list.json', utf8.encode('[1, 2]')),
          contains('JSON object'));
      expect(teamBoardFileProblem('a.mcmeta', Uint8List.fromList([0xFF])),
          contains('not UTF-8'));
      expect(teamBoardFileProblem('a.json', Uint8List(0)), contains('empty'));
      expect(
          teamBoardFileProblem(
              'deep.json', utf8.encode('${'[' * 100}${']' * 100}')),
          contains('nests deeper'));
      expect(
          teamBoardFileProblem(
              'tricky.json', utf8.encode('{"a": "[[[[\\"]]]]"}')),
          isNull);
    });
  });

  test('the board puts work to do first and closed threads last', () {
    TeamBoardEntry make(String id, String stage, int at,
            {bool closed = false}) =>
        TeamBoardEntry(
            id: id,
            kind: 'model',
            title: id,
            brief: '',
            authorId: 'u',
            authorEmail: 'u@x.com',
            createdAtMs: at,
            updatedAtMs: at,
            stage: stage,
            closed: closed);
    final dir = Directory.systemTemp.createTempSync('team_board_order');
    addTearDown(() => dir.deleteSync(recursive: true));
    final board = TeamBoardStore(dir.path);
    for (final e in [
      make('added', 'added', 9),
      make('closed', 'idea', 10, closed: true),
      make('done', 'done', 8),
      make('old-idea', 'idea', 1),
      make('claimed', 'claimed', 5),
    ]) {
      board.addEntry(e);
    }
    expect(board.board().map((e) => e.id),
        ['claimed', 'old-idea', 'done', 'added', 'closed']);
  });

  group('endpoints', () {
    late Directory dir;
    late Handler handler;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('team_board_api');
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
        await Store.open(dir.path),
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

    Future<Map<String, dynamic>> call(String method, String path,
        {Object? json,
        String? form,
        List<int>? bytes,
        String? token,
        bool admin = false}) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          if (json != null) 'Content-Type': 'application/json',
          if (form != null) 'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
          if (admin) 'x-admin-key': 'test-admin-key',
        },
        body: json != null ? jsonEncode(json) : form ?? bytes,
      ));
      final raw = await response.readAsString();
      return {
        ...(raw.trimLeft().startsWith('{')
            ? jsonDecode(raw) as Map<String, dynamic>
            : const <String, dynamic>{}),
        'httpStatus': response.statusCode,
      };
    }

    Future<String> register(String email) async {
      final result = await call('POST', '/api/v1/auth/register', json: {
        'email': email,
        'authKey': base64Encode(Uint8List.fromList(
            c.sha256.convert(utf8.encode('key:$email')).bytes)),
        'kdfSalt': base64Encode(List.filled(16, 7)),
        'kdfIterations': 210000,
      });
      expect(result['httpStatus'], 201, reason: 'register: $result');
      return result['token'] as String;
    }

    Future<void> setRole(String email, String role) async {
      final result = await call('POST', '/admin/team-board/access?role=$role',
          admin: true, form: 'email=${Uri.encodeQueryComponent(email)}');
      expect(result['httpStatus'], anyOf(200, 302), reason: '$result');
    }

    Future<Map<String, dynamic>> create(String token,
            {String kind = 'model', String title = 'Ruby ore'}) =>
        call('POST', '/api/v1/team-board/entries',
            token: token,
            json: {'kind': kind, 'title': title, 'brief': 'Glows a bit.'});

    test('the account lists the plugin only while the admin grants it',
        () async {
      final token = await register('pixel@example.com');
      Future<List<dynamic>?> granted() async =>
          (await call('GET', '/api/v1/account', token: token))['grantedPlugins']
              as List<dynamic>?;
      expect(await granted(), isEmpty);
      await setRole('pixel@example.com', 'member');
      expect(await granted(), ['team-clipboard']);
      await setRole('pixel@example.com', 'lead');
      expect(await granted(), ['team-clipboard']);
      await setRole('pixel@example.com', 'none');
      expect(await granted(), isEmpty);
    });

    test('nobody gets in until the admin adds them', () async {
      final token = await register('stranger@example.com');
      final board = await call('GET', '/api/v1/team-board', token: token);
      expect(board['member'], isFalse);
      expect(board['entries'], isNull);
      final created = await create(token);
      expect(created['httpStatus'], 403);
      expect(created['error'] ?? created['code'], 'team_access_required');

      await setRole('stranger@example.com', 'member');
      expect((await create(token))['httpStatus'], 201);

      await setRole('stranger@example.com', 'none');
      expect((await call('GET', '/api/v1/team-board', token: token))['member'],
          isFalse);
    });

    test('the dashboard offers the toggle and shows who is on the team',
        () async {
      await register('member@example.com');
      Future<String> dashboard() async =>
          (await handler(Request('GET', Uri.parse('http://localhost/admin'),
                  headers: {'x-admin-key': 'test-admin-key'})))
              .readAsString();
      expect(await dashboard(), contains('Add to Team Clipboard'));
      await setRole('member@example.com', 'member');
      final html = await dashboard();
      expect(html, contains('Make Team Clipboard lead'));
      expect(html, contains('Remove from Team Clipboard'));
      expect(html, contains('<span class="badge ok">team</span>'));
    });

    test('members claim and finish; only a lead marks added', () async {
      final author = await register('author@example.com');
      final helper = await register('helper@example.com');
      final lead = await register('lead@example.com');
      await setRole('author@example.com', 'member');
      await setRole('helper@example.com', 'member');
      await setRole('lead@example.com', 'lead');

      final id = (await create(author))['id'] as String;
      final claimed = await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: helper, json: {'stage': 'claimed'});
      expect(claimed['stage'], 'claimed');
      expect(claimed['claimedBy'], 'helper');
      expect(claimed['claimedByMe'], isTrue);

      final done = await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: helper, json: {'stage': 'done'});
      expect(done['stage'], 'done');

      final refused = await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: author, json: {'stage': 'added'});
      expect(refused['httpStatus'], 403);

      final added = await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: lead, json: {'stage': 'added'});
      expect(added['stage'], 'added');
      expect(added['claimedBy'], 'helper');

      final undo = await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: helper, json: {'stage': 'done'});
      expect(undo['httpStatus'], 403);
    });

    test('a closed thread takes no more messages, files or stages', () async {
      final author = await register('author@example.com');
      final other = await register('other@example.com');
      await setRole('author@example.com', 'member');
      await setRole('other@example.com', 'member');
      final id = (await create(author, kind: 'bug'))['id'] as String;

      final posted = await call(
          'POST', '/api/v1/team-board/entries/$id/messages',
          token: other, json: {'text': '  Crashes on load  '});
      expect(posted['httpStatus'], 201);
      final messages = posted['messages'] as List;
      expect(messages.single['text'], 'Crashes on load');
      expect(messages.single['author'], 'other');

      final notYours = await call(
          'POST', '/api/v1/team-board/entries/$id/close',
          token: other, json: {'closed': true});
      expect(notYours['httpStatus'], 403);

      final closed = await call('POST', '/api/v1/team-board/entries/$id/close',
          token: author, json: {'closed': true});
      expect(closed['closed'], isTrue);

      expect(
          (await call('POST', '/api/v1/team-board/entries/$id/messages',
              token: other, json: {'text': 'one more'}))['httpStatus'],
          409);
      expect(
          (await call('POST', '/api/v1/team-board/entries/$id/files?name=a.png',
              token: other, bytes: _png))['httpStatus'],
          409);
      expect(
          (await call('POST', '/api/v1/team-board/entries/$id/stage',
              token: author, json: {'stage': 'done'}))['httpStatus'],
          403);

      final board = await call('GET', '/api/v1/team-board', token: author);
      expect((board['entries'] as List).single['closed'], isTrue);
    });

    test('files go up, come down, and only their uploader removes them',
        () async {
      final author = await register('author@example.com');
      final other = await register('other@example.com');
      await setRole('author@example.com', 'member');
      await setRole('other@example.com', 'member');
      final id = (await create(author))['id'] as String;

      final wrongType = await call(
          'POST', '/api/v1/team-board/entries/$id/files?name=pack.zip',
          token: author, bytes: _png);
      expect(wrongType['httpStatus'], 400);
      final fake = await call(
          'POST', '/api/v1/team-board/entries/$id/files?name=ruby.png',
          token: author, bytes: utf8.encode('not a png'));
      expect(fake['httpStatus'], 400);

      final up = await call(
          'POST', '/api/v1/team-board/entries/$id/files?name=ruby_ore.png',
          token: author, bytes: _png);
      expect(up['httpStatus'], 201);
      final file = (up['files'] as List).single as Map<String, dynamic>;
      expect(file['name'], 'ruby_ore.png');
      expect(file['sizeBytes'], _png.length);

      final download = await handler(Request('GET',
          Uri.parse('http://localhost/api/v1/team-board/files/${file['id']}'),
          headers: {'Authorization': 'Bearer $other'}));
      expect(download.statusCode, 200);
      expect(download.headers['content-type'], 'image/png');
      expect(await download.read().expand((b) => b).toList(), _png);

      final stranger = await register('stranger@example.com');
      final blocked = await handler(Request('GET',
          Uri.parse('http://localhost/api/v1/team-board/files/${file['id']}'),
          headers: {'Authorization': 'Bearer $stranger'}));
      expect(blocked.statusCode, 403);

      expect(
          (await call(
              'DELETE', '/api/v1/team-board/entries/$id/files/${file['id']}',
              token: other))['httpStatus'],
          403);
      final removed = await call(
          'DELETE', '/api/v1/team-board/entries/$id/files/${file['id']}',
          token: author);
      expect(removed['files'], isEmpty);
    });

    test('every member and lead can download every file, closed or not',
        () async {
      final author = await register('author@example.com');
      final member = await register('member@example.com');
      final lead = await register('lead@example.com');
      await setRole('author@example.com', 'member');
      await setRole('member@example.com', 'member');
      await setRole('lead@example.com', 'lead');
      final id = (await create(author))['id'] as String;
      final model = utf8.encode('{"parent": "block/cube_all"}');
      final up = await call(
          'POST', '/api/v1/team-board/entries/$id/files?name=ruby_ore.json',
          token: author, bytes: model);
      final fileId = ((up['files'] as List).single as Map)['id'] as String;

      Future<Response> fetch(String token) async => await handler(Request(
          'GET', Uri.parse('http://localhost/api/v1/team-board/files/$fileId'),
          headers: {'Authorization': 'Bearer $token'}));

      for (final token in [author, member, lead]) {
        final response = await fetch(token);
        expect(response.statusCode, 200);
        expect(await response.read().expand((b) => b).toList(), model);
      }

      await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: lead, json: {'stage': 'added'});
      await call('POST', '/api/v1/team-board/entries/$id/close',
          token: lead, json: {'closed': true});
      for (final token in [author, member, lead]) {
        expect((await fetch(token)).statusCode, 200);
      }
      final listed =
          await call('GET', '/api/v1/team-board/entries/$id', token: member);
      expect(listed['closed'], isTrue);
      expect(listed['files'], hasLength(1));
    });

    test('files are stored and served as inert bytes', () async {
      final author = await register('author@example.com');
      await setRole('author@example.com', 'member');
      final id = (await create(author))['id'] as String;

      final broken = await call(
          'POST', '/api/v1/team-board/entries/$id/files?name=ruby.json',
          token: author, bytes: utf8.encode('{"parent": '));
      expect(broken['httpStatus'], 400);
      expect(broken['message'], contains('not valid JSON (line 1'));
      final smuggled = await call(
          'POST', '/api/v1/team-board/entries/$id/files?name=evil.png',
          token: author,
          bytes: _pngOf(16, 16, trailing: utf8.encode('<?php system(1);')));
      expect(smuggled['httpStatus'], 400);
      final filesDir = Directory('${dir.path}/team_board/files');
      expect(filesDir.existsSync() ? filesDir.listSync() : const [], isEmpty,
          reason: 'a refused file never touches the disk');

      final up = await call('POST',
          '/api/v1/team-board/entries/$id/files?name=..%2F..%2Frun.sh.png',
          token: author, bytes: _png);
      final file = (up['files'] as List).single as Map<String, dynamic>;
      expect(file['name'], 'run.sh.png');
      final stored = filesDir.listSync().single as File;
      expect(stored.uri.pathSegments.last, file['id']);
      expect(stored.uri.pathSegments.last, matches(RegExp(r'^[a-f0-9]{24}$')));
      if (!Platform.isWindows) {
        expect(stored.statSync().mode & 0x49, 0, reason: 'no execute bits');
      }

      final download = await handler(Request('GET',
          Uri.parse('http://localhost/api/v1/team-board/files/${file['id']}'),
          headers: {'Authorization': 'Bearer $author'}));
      expect(download.headers['content-disposition'], 'attachment');
      expect(download.headers['x-content-type-options'], 'nosniff');
      expect(download.headers['content-security-policy'], contains('sandbox'));
    });

    test('an author can only delete an entry nobody else added to', () async {
      final author = await register('author@example.com');
      final other = await register('other@example.com');
      final lead = await register('lead@example.com');
      await setRole('author@example.com', 'member');
      await setRole('other@example.com', 'member');
      await setRole('lead@example.com', 'lead');
      final id = (await create(author))['id'] as String;
      await call('POST', '/api/v1/team-board/entries/$id/messages',
          token: other, json: {'text': 'I can do the texture'});

      expect(
          (await call('DELETE', '/api/v1/team-board/entries/$id',
              token: author))['httpStatus'],
          403);
      expect(
          (await call('DELETE', '/api/v1/team-board/entries/$id',
              token: lead))['httpStatus'],
          200);
      expect(
          (await call('GET', '/api/v1/team-board/entries/$id',
              token: author))['httpStatus'],
          404);
    });

    test('since= answers unchanged until something moves', () async {
      final token = await register('member@example.com');
      await setRole('member@example.com', 'member');
      final first = await call('GET', '/api/v1/team-board', token: token);
      final revision = first['revision'] as int;
      final again =
          await call('GET', '/api/v1/team-board?since=$revision', token: token);
      expect(again['unchanged'], isTrue);
      expect(again['entries'], isNull);
      await create(token);
      final moved =
          await call('GET', '/api/v1/team-board?since=$revision', token: token);
      expect(moved['unchanged'], isNull);
      expect(moved['entries'], hasLength(1));
    });

    test('a member picks the name the board shows for everything they wrote',
        () async {
      final author = await register('ruby.dev@example.com');
      final other = await register('other@example.com');
      await setRole('ruby.dev@example.com', 'member');
      await setRole('other@example.com', 'member');
      final id = (await create(author))['id'] as String;
      await call('POST', '/api/v1/team-board/entries/$id/messages',
          token: author, json: {'text': 'Texture is up'});

      final renamed = await call('PUT', '/api/v1/team-board/me',
          token: author, json: {'name': '  Ruby   Smith '});
      expect(renamed['httpStatus'], 200);
      expect(renamed['me'], 'Ruby Smith');

      final entry =
          await call('GET', '/api/v1/team-board/entries/$id', token: other);
      expect(entry['author'], 'Ruby Smith');
      expect((entry['messages'] as List).single['author'], 'Ruby Smith');
      final board = await call('GET', '/api/v1/team-board', token: author);
      expect(board['me'], 'Ruby Smith');

      expect(
          (await call('PUT', '/api/v1/team-board/me',
              token: other, json: {'name': 'ruby smith'}))['httpStatus'],
          409);
      expect(
          (await call('PUT', '/api/v1/team-board/me',
              token: other, json: {'name': 'x' * 33}))['httpStatus'],
          400);

      final reset = await call('PUT', '/api/v1/team-board/me',
          token: author, json: {'name': ''});
      expect(reset['me'], 'ruby.dev');

      final outsider = await register('outsider@example.com');
      expect(
          (await call('PUT', '/api/v1/team-board/me',
              token: outsider, json: {'name': 'Boss'}))['httpStatus'],
          403);
    });

    test('a main thread holds sub-entries one level deep', () async {
      final token = await register('member@example.com');
      await setRole('member@example.com', 'member');
      final main =
          (await create(token, title: 'Nether update'))['id'] as String;
      final sub = await call('POST', '/api/v1/team-board/entries',
          token: token,
          json: {'kind': 'model', 'title': 'Ash block', 'parentId': main});
      expect(sub['httpStatus'], 201);
      expect(sub['parentId'], main);
      final subId = sub['id'] as String;

      expect(
          (await call('POST', '/api/v1/team-board/entries',
              token: token,
              json: {
                'kind': 'model',
                'title': 'Too deep',
                'parentId': subId
              }))['httpStatus'],
          409);
      expect(
          (await call('PUT', '/api/v1/team-board/entries/$main',
              token: token, json: {'parentId': subId}))['httpStatus'],
          409);

      final loose = (await create(token, title: 'Ember'))['id'] as String;
      final moved = await call('PUT', '/api/v1/team-board/entries/$loose',
          token: token, json: {'parentId': main});
      expect(moved['parentId'], main);
      final freed = await call('PUT', '/api/v1/team-board/entries/$loose',
          token: token, json: {'parentId': null});
      expect(freed['parentId'], isNull);
      final kept = await call('PUT', '/api/v1/team-board/entries/$subId',
          token: token, json: {'title': 'Ash block v2'});
      expect(kept['parentId'], main);

      await call('DELETE', '/api/v1/team-board/entries/$main', token: token);
      final orphan =
          await call('GET', '/api/v1/team-board/entries/$subId', token: token);
      expect(orphan['httpStatus'], 200);
      expect(orphan['parentId'], isNull);
    });
  });
}

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
import 'package:luma_sync_server/team_library.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Uint8List _png() {
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
    ..setUint32(0, 2)
    ..setUint32(4, 2)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', zlib.encode(List.filled(2 * (1 + 8), 0)));
  chunk('IEND', const []);
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

/// A zip of [files], deflated unless the name is in [stored]. A
/// [declare] entry lists a size other than the real one, the way a zip bomb
/// lies.
Uint8List _zip(Map<String, List<int>> files,
    {Set<String> stored = const {}, Map<String, int> declare = const {}}) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  ByteData u16(int v) => ByteData(2)..setUint16(0, v, Endian.little);
  ByteData u32(int v) => ByteData(4)..setUint32(0, v, Endian.little);
  void add(BytesBuilder b, ByteData d) => b.add(d.buffer.asUint8List());
  for (final f in files.entries) {
    final name = utf8.encode(f.key);
    final deflate = !stored.contains(f.key);
    final data = deflate
        ? ZLibEncoder(raw: true).convert(f.value)
        : f.value;
    final offset = out.length;
    final size = declare[f.key] ?? f.value.length;
    final crc = _crc(f.value);
    add(out, u32(0x04034b50));
    add(out, u16(20));
    add(out, u16(0));
    add(out, u16(deflate ? 8 : 0));
    add(out, u32(0));
    add(out, u32(crc));
    add(out, u32(data.length));
    add(out, u32(size));
    add(out, u16(name.length));
    add(out, u16(0));
    out
      ..add(name)
      ..add(data);
    add(central, u32(0x02014b50));
    add(central, u16(20));
    add(central, u16(20));
    add(central, u16(0));
    add(central, u16(deflate ? 8 : 0));
    add(central, u32(0));
    add(central, u32(crc));
    add(central, u32(data.length));
    add(central, u32(size));
    add(central, u16(name.length));
    add(central, u16(0));
    add(central, u16(0));
    add(central, u16(0));
    add(central, u16(0));
    add(central, u32(0));
    add(central, u32(offset));
    central.add(name);
  }
  final cdOffset = out.length;
  final cd = central.takeBytes();
  out.add(cd);
  add(out, u32(0x06054b50));
  add(out, u16(0));
  add(out, u16(0));
  add(out, u16(files.length));
  add(out, u16(files.length));
  add(out, u32(cd.length));
  add(out, u32(cdOffset));
  add(out, u16(0));
  return out.takeBytes();
}

/// Modrinth as the library sees it: one project whose versions the test
/// can add to.
class _FakeModrinth implements TeamLibrarySource {
  final versions = <Map<String, dynamic>>[];
  final jars = <String, Uint8List>{};
  final downloads = <Uri>[];

  void publish(String id, String number, Uint8List jar,
      {String date = '2026-10-01T00:00:00Z', String? url}) {
    final link = url ?? 'https://cdn.modrinth.com/data/AABBCCDD/$id.jar';
    jars[link] = jar;
    versions.add({
      'id': id,
      'version_number': number,
      'name': 'Ruby $number',
      'date_published': date,
      'loaders': ['fabric'],
      'game_versions': ['1.21.1'],
      'files': [
        {
          'url': link,
          'filename': 'ruby-$number.jar',
          'primary': true,
          'size': jar.length,
          'hashes': {'sha1': c.sha1.convert(jar).toString()},
        }
      ],
    });
  }

  @override
  Future<Object?> getJson(String path, [Map<String, String>? query]) async {
    if (path == '/project/AABBCCDD') {
      return {
        'id': 'AABBCCDD',
        'slug': 'ruby',
        'title': 'Ruby Mod',
        'project_type': 'mod',
        'icon_url': 'https://cdn.modrinth.com/data/AABBCCDD/icon.png',
        'loaders': ['fabric', 'quilt'],
        'game_versions': ['1.20.1', '1.21.1'],
      };
    }
    if (path == '/project/SHADERSS') {
      return {'id': 'SHADERSS', 'project_type': 'shader'};
    }
    if (path == '/project/AABBCCDD/version') return versions;
    if (path == '/search') {
      return {
        'hits': [
          {
            'project_id': 'AABBCCDD',
            'slug': 'ruby',
            'title': 'Ruby Mod',
            'project_type': 'mod',
            'categories': ['fabric', 'decoration'],
            'versions': ['1.20.1', '1.21.1'],
          },
          {'project_id': 'SHADERSS', 'project_type': 'shader'},
        ],
      };
    }
    return null;
  }

  @override
  Future<Uint8List?> download(Uri url, int maxBytes) async {
    downloads.add(url);
    return jars[url.toString()];
  }
}

final _model = utf8.encode(
    '{"parent": "block/cube_all", "textures": {"all": "ruby:block/ruby"}}');

void main() {
  group('jar scan', () {
    test('keeps assets and data, leaves code and junk out', () {
      final jar = _zip({
        'assets/ruby/textures/block/ruby.png': _png(),
        'assets/ruby/models/block/ruby.json': _model,
        'assets/ruby/textures/block/fire.png.mcmeta':
            utf8.encode('{"animation": {"frametime": 2}}'),
        'data/ruby/recipes/ruby.json': utf8.encode('{"type": "x"}'),
        'net/ruby/RubyMod.class': [0xCA, 0xFE, 0xBA, 0xBE],
        'fabric.mod.json': utf8.encode('{"id": "ruby"}'),
        'assets/ruby/sounds/ding.ogg': [1, 2, 3],
        'assets/ruby/textures/bad.png': utf8.encode('not a png'),
        'assets/ruby/lang/en_us.json': utf8.encode('[1]'),
        'assets/../../etc/passwd.png': _png(),
        'assets/ruby/textures/stored.png': _png(),
      }, stored: {
        'assets/ruby/textures/stored.png'
      });
      final kept = <String, Uint8List>{};
      final scan = scanTeamLibraryJar(jar, (p, b) => kept[p] = b);
      expect(kept.keys, unorderedEquals([
        'assets/ruby/textures/block/ruby.png',
        'assets/ruby/models/block/ruby.json',
        'assets/ruby/textures/block/fire.png.mcmeta',
        'data/ruby/recipes/ruby.json',
        'assets/ruby/textures/stored.png',
      ]));
      expect(kept['assets/ruby/textures/block/ruby.png'], _png());
      expect(kept['assets/ruby/models/block/ruby.json'], _model);
      expect(scan.skipped, 2);
      expect(scan.kept, 5);
    });

    test('a zip that lies about a size stops at the cap', () {
      final jar = _zip({
        'assets/ruby/models/huge.json': [
          ...utf8.encode('{"a": "'),
          ...List.filled(11 * 1024 * 1024, 0x61),
          ...utf8.encode('"}'),
        ],
      }, declare: {
        'assets/ruby/models/huge.json': 10
      });
      final scan = scanTeamLibraryJar(jar, (_, __) => fail('kept a bomb'));
      expect(scan.skipped, 1);
    });

    test('too many assets or not a zip at all is refused', () {
      expect(
          () => scanTeamLibraryJar(
              _zip({for (var i = 0; i < 4; i++) 'assets/a/m/$i.json': _model}),
              (_, __) {},
              maxFiles: 3),
          throwsA(isA<TeamLibraryException>()));
      expect(() => scanTeamLibraryJar(Uint8List(100), (_, __) {}),
          throwsA(isA<TeamLibraryException>()));
    });

    test('paths have to look like resource locations', () {
      expect(isTeamLibraryAssetPath('assets/ruby/textures/a.png'), isTrue);
      expect(isTeamLibraryAssetPath('data/ruby/tags/a.json'), isTrue);
      expect(isTeamLibraryAssetPath('assets/ruby/../x.png'), isFalse);
      expect(isTeamLibraryAssetPath('assets/ruby//x.png'), isFalse);
      expect(isTeamLibraryAssetPath('assets/Ruby/x.png'), isFalse);
      expect(isTeamLibraryAssetPath('assets/ruby/x.class'), isFalse);
      expect(isTeamLibraryAssetPath('META-INF/x.json'), isFalse);
    });

    test('the newest version with a jar wins', () {
      final picked = pickTeamLibraryVersion([
        {
          'id': 'old',
          'date_published': '2026-01-01T00:00:00Z',
          'files': [
            {'url': 'https://cdn.modrinth.com/a.jar', 'filename': 'a.jar'}
          ],
        },
        {
          'id': 'new',
          'date_published': '2026-05-01T00:00:00Z',
          'files': [
            {'url': 'https://cdn.modrinth.com/b.jar', 'filename': 'b.jar'}
          ],
        },
        {
          'id': 'newest-without-jar',
          'date_published': '2026-09-01T00:00:00Z',
          'files': [
            {'url': 'https://cdn.modrinth.com/c.txt', 'filename': 'c.txt'}
          ],
        },
      ]);
      expect(picked?['id'], 'new');
    });
  });

  group('endpoints', () {
    late Directory dir;
    late Api api;
    late Handler handler;
    late _FakeModrinth modrinth;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('team_library_api');
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
      api = Api(
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
      );
      modrinth = _FakeModrinth();
      api.teamLibrary.source = modrinth;
      handler = api.handler;
    });

    tearDown(() async {
      await api.teamLibrary.settle();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> call(String method, String path,
        {Object? json, String? form, String? token, bool admin = false}) async {
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
        ...(raw.trimLeft().startsWith('{')
            ? jsonDecode(raw) as Map<String, dynamic>
            : const <String, dynamic>{}),
        'httpStatus': response.statusCode,
        'rawBody': raw,
      };
    }

    Future<String> member(String email, String role) async {
      final result = await call('POST', '/api/v1/auth/register', json: {
        'email': email,
        'authKey': base64Encode(Uint8List.fromList(
            c.sha256.convert(utf8.encode('key:$email')).bytes)),
        'kdfSalt': base64Encode(List.filled(16, 7)),
        'kdfIterations': 210000,
      });
      expect(result['httpStatus'], 201, reason: 'register: $result');
      if (role != 'none') {
        final set = await call('POST', '/admin/team-board/access?role=$role',
            admin: true, form: 'email=${Uri.encodeQueryComponent(email)}');
        expect(set['httpStatus'], anyOf(200, 302));
      }
      return result['token'] as String;
    }

    List<dynamic> filesOf(Map<String, dynamic> index) =>
        index['files'] as List<dynamic>;

    test('a lead adds a mod, the team browses it, an update reloads it',
        () async {
      final lead = await member('lead@example.com', 'lead');
      final crew = await member('crew@example.com', 'member');
      final stranger = await member('stranger@example.com', 'none');

      modrinth.publish(
          'v1',
          '1.0.0',
          _zip({
            'assets/ruby/textures/block/ruby.png': _png(),
            'assets/ruby/models/block/ruby.json': _model,
          }));

      final search =
          await call('GET', '/api/v1/team-board/library/search?q=ruby',
              token: lead);
      expect([for (final h in search['hits'] as List) h['id']], ['AABBCCDD']);
      expect((search['hits'] as List).first['loaders'], ['fabric']);
      expect((search['hits'] as List).first['gameVersions'],
          ['1.21.1', '1.20.1']);

      expect(
          (await call('POST', '/api/v1/team-board/library/mods',
                  token: crew, json: {'projectId': 'AABBCCDD'}))['httpStatus'],
          403);
      expect(
          (await call('GET', '/api/v1/team-board/library',
              token: stranger))['httpStatus'],
          403);
      expect(
          (await call('POST', '/api/v1/team-board/library/mods',
                  token: lead, json: {'projectId': 'SHADERSS'}))['httpStatus'],
          409);

      final added = await call('POST', '/api/v1/team-board/library/mods',
          token: lead,
          json: {
            'projectId': 'AABBCCDD',
            'loader': 'fabric',
            'gameVersion': '1.21.1'
          });
      expect(added['httpStatus'], 201, reason: '$added');
      await api.teamLibrary.settle();

      var library = await call('GET', '/api/v1/team-board/library', token: crew);
      expect(library['canManage'], isFalse);
      var mod = (library['mods'] as List).single as Map<String, dynamic>;
      expect(mod['state'], 'ready', reason: '$mod');
      expect(mod['title'], 'Ruby Mod');
      expect(mod['addedBy'], 'lead');
      expect(mod['version']['number'], '1.0.0');
      expect(mod['fileCount'], 2);
      expect(mod['namespaces'], ['ruby']);
      expect(mod['loaders'], ['fabric', 'quilt']);
      expect(mod['gameVersions'], ['1.21.1', '1.20.1']);

      final unchanged = await call('GET',
          '/api/v1/team-board/library?since=${library['revision']}',
          token: crew);
      expect(unchanged['unchanged'], isTrue);

      final index = await call(
          'GET', '/api/v1/team-board/library/mods/AABBCCDD/files',
          token: crew);
      expect(index['versionId'], 'v1');
      final png = filesOf(index)
          .firstWhere((f) => (f[0] as String).endsWith('.png')) as List;
      final blob = await handler(Request('GET',
          Uri.parse('http://localhost/api/v1/team-board/library/blobs/${png[1]}'),
          headers: {'Authorization': 'Bearer $crew'}));
      expect(blob.statusCode, 200);
      expect(blob.headers['x-content-type-options'], 'nosniff');
      expect(await blob.read().expand((b) => b).toList(), _png());
      expect(
          (await call('GET', '/api/v1/team-board/library/blobs/${png[1]}',
              token: stranger))['httpStatus'],
          403);

      // Nothing new: a check doesn't download again.
      await call('POST', '/api/v1/team-board/library/check',
          token: crew, json: {});
      await api.teamLibrary.settle();
      expect(modrinth.downloads, hasLength(1));

      // An update drops: the next check unpacks it and the old texture goes.
      modrinth.publish(
          'v2',
          '1.1.0',
          _zip({
            'assets/ruby/models/block/ruby.json': _model,
            'assets/ruby/textures/block/sapphire.png': _png(),
            'assets/ruby/lang/en_us.json': utf8.encode('{"a": "b"}'),
          }),
          date: '2026-10-10T00:00:00Z');
      await call('POST', '/api/v1/team-board/library/check',
          token: crew, json: {'projectId': 'AABBCCDD'});
      await api.teamLibrary.settle();
      library = await call('GET', '/api/v1/team-board/library', token: crew);
      mod = (library['mods'] as List).single as Map<String, dynamic>;
      expect(mod['version']['number'], '1.1.0');
      expect(mod['fileCount'], 3);
      expect((mod['history'] as List).single['number'], '1.0.0');
      final next = await call(
          'GET', '/api/v1/team-board/library/mods/AABBCCDD/files',
          token: crew);
      expect(next['versionId'], 'v2');
      expect([for (final f in filesOf(next)) f[0]], [
        'assets/ruby/lang/en_us.json',
        'assets/ruby/models/block/ruby.json',
        'assets/ruby/textures/block/sapphire.png',
      ]);

      // Removing the mod leaves no files behind.
      expect(
          (await call('DELETE', '/api/v1/team-board/library/mods/AABBCCDD',
              token: lead))['httpStatus'],
          200);
      await api.teamLibrary.settle();
      final blobs = Directory('${dir.path}/team_board/library/blobs');
      expect(blobs.listSync(), isEmpty);
    });

    test('a download from anywhere but the Modrinth CDN is refused',
        () async {
      final lead = await member('lead@example.com', 'lead');
      modrinth.publish('v1', '1.0.0', _zip({'assets/a/m/x.json': _model}),
          url: 'https://evil.example.com/ruby.jar');
      await call('POST', '/api/v1/team-board/library/mods',
          token: lead, json: {'projectId': 'AABBCCDD'});
      await api.teamLibrary.settle();
      final library =
          await call('GET', '/api/v1/team-board/library', token: lead);
      final mod = (library['mods'] as List).single;
      expect(mod['state'], 'failed');
      expect(modrinth.downloads, isEmpty);
    });

    test('a damaged download keeps the last good assets', () async {
      final lead = await member('lead@example.com', 'lead');
      modrinth.publish('v1', '1.0.0', _zip({'assets/a/m/x.json': _model}));
      await call('POST', '/api/v1/team-board/library/mods',
          token: lead, json: {'projectId': 'AABBCCDD'});
      await api.teamLibrary.settle();
      modrinth.publish('v2', '2.0.0', _zip({'assets/a/m/y.json': _model}),
          date: '2026-10-11T00:00:00Z');
      final link = modrinth.jars.keys.last;
      modrinth.jars[link] = Uint8List.fromList([...modrinth.jars[link]!, 0]);
      api.teamLibrary.check('AABBCCDD');
      await api.teamLibrary.settle();
      final mod = ((await call('GET', '/api/v1/team-board/library',
              token: lead))['mods'] as List)
          .single;
      expect(mod['state'], 'ready');
      expect(mod['version']['number'], '1.0.0');
      expect(mod['error'], contains('damaged'));
    });
  });
}

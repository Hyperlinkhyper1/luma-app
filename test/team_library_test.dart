import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/team_clipboard/data/team_clipboard_api.dart';
import 'package:luma/features/plugins/installed/team_clipboard/data/team_local_library.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_controller.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_page.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_scope.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_library_models.dart';
import 'package:luma/features/plugins/installed/team_clipboard/ui/team_model_view.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';

class _SignedIn extends SyncService {
  _SignedIn() : super(collections: const []);

  @override
  bool get serverReady => true;

  @override
  String? get serverUrl => 'https://sync.example.com/';

  @override
  String? get authToken => 'token';

  @override
  String? get email => 'pixel@example.com';
}

Map<String, dynamic> _mod({
  String state = 'ready',
  String? version = 'v1',
  String number = '1.0.0',
  int fileCount = 3,
  String? error,
}) => {
  'id': 'AABBCCDD',
  'slug': 'ruby',
  'title': 'Ruby Mod',
  'projectType': 'mod',
  'url': 'https://modrinth.com/mod/ruby',
  'iconUrl': null,
  'addedBy': 'pixel',
  'loaders': ['fabric', 'quilt'],
  'gameVersions': ['1.21.1', '1.20.1'],
  'loader': 'fabric',
  'gameVersion': '1.21.1',
  'state': state,
  'error': error,
  'version': version == null
      ? null
      : {'id': version, 'number': number, 'publishedAtMs': 1000},
  'loadedAtMs': version == null ? 0 : 2000,
  'checkedAtMs': 2000,
  'fileCount': version == null ? 0 : fileCount,
  'bytes': 4096,
  'skipped': 0,
  'namespaces': ['ruby'],
  'history': <Object>[],
};

/// The board and library endpoints, enough for the library tab.
class _FakeServer {
  _FakeServer({this.lead = true});

  final bool lead;
  int revision = 1;
  final mods = <Map<String, dynamic>>[];
  final indexes = <String, Map<String, dynamic>>{};
  final blobs = <String, List<int>>{};
  final requests = <http.Request>[];
  Future<void>? libraryLoad;

  /// How many batch requests to answer with "slow down" first.
  int busyFor = 0;
  int maxPerBatch = 1000;

  int get batchRequests => requests
      .where((r) => r.url.path == '/api/v1/team-board/library/blobs')
      .length;

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
    Map<String, dynamic> library() => {
      'revision': revision,
      'canManage': lead,
      'busy': false,
      'mods': mods,
    };
    if (path == '/api/v1/team-board') {
      return json({
        'member': true,
        'lead': lead,
        'me': 'pixel',
        'revision': 1,
        'entries': <Object>[],
      });
    }
    if (path == '/api/v1/team-board/library') {
      await libraryLoad;
      if (request.url.queryParameters['since'] == '$revision') {
        return json({'revision': revision, 'unchanged': true});
      }
      return json(library());
    }
    if (path == '/api/v1/team-board/library/search') {
      return json({
        'hits': [
          {
            'id': 'AABBCCDD',
            'title': 'Ruby Mod',
            'description': 'Shiny red things.',
            'author': 'gemcutter',
            'downloads': 12500,
            'projectType': 'mod',
            'loaders': ['fabric', 'quilt'],
            'gameVersions': ['1.21.1', '1.20.1'],
          },
        ],
      });
    }
    if (path == '/api/v1/team-board/library/mods' && request.method == 'POST') {
      mods.add(_mod(state: 'queued', version: null));
      revision++;
      return json(library(), 201);
    }
    if (path == '/api/v1/team-board/library/check') return json(library());
    final files = RegExp(
      r'^/api/v1/team-board/library/mods/(\w+)/files$',
    ).firstMatch(path);
    if (files != null) {
      final index = indexes[files.group(1)];
      return index == null ? json({'error': 'not_found'}, 404) : json(index);
    }
    if (path == '/api/v1/team-board/library/blobs' &&
        request.method == 'POST') {
      if (busyFor > 0) {
        busyFor--;
        return http.Response(
          '{"error": "rate_limited"}',
          429,
          headers: {'retry-after': '1'},
        );
      }
      final ids = ((jsonDecode(request.body) as Map)['ids'] as List)
          .cast<String>();
      // Like the server, a batch holds only so much; the rest is asked
      // for again.
      final served = ids.take(maxPerBatch).toList();
      return json({
        'files': {
          for (final id in served)
            if (blobs[id] case final bytes?) id: base64Encode(bytes),
        },
        'missing': [
          for (final id in served)
            if (!blobs.containsKey(id)) id,
        ],
      });
    }
    return json({'error': 'not_found', 'message': 'nope'}, 404);
  });

  /// The server finished unpacking [number] with [files] (path → bytes).
  void unpacked(String version, String number, Map<String, List<int>> files) {
    final list = <List<Object>>[];
    var i = 0;
    for (final f in files.entries) {
      final n = (i++).toString().padLeft(5, '0');
      final sha = '${version}_$n'.padRight(40, '0');
      blobs[sha] = f.value;
      list.add([f.key, sha, f.value.length]);
    }
    indexes['AABBCCDD'] = {'versionId': version, 'files': list};
    mods
      ..clear()
      ..add(_mod(version: version, number: number, fileCount: files.length));
    revision++;
  }
}

List<int> _png() {
  final pixels = img.Image(width: 16, height: 16, numChannels: 4);
  for (var y = 4; y < 12; y++) {
    for (var x = 4; x < 12; x++) {
      pixels.setPixelRgba(x, y, 200, 30, 60, 255);
    }
  }
  return img.encodePng(pixels);
}

final _cubeModel = utf8.encode(
  jsonEncode({
    'parent': 'minecraft:block/cube_all',
    'textures': {'all': 'ruby:block/ruby_block'},
  }),
);

/// This device's half of the library, in memory, so the widget tests never
/// touch the disk. Adding a mod "unpacks" it straight away.
class _FakeLocal extends TeamLocalLibrary {
  _FakeLocal() : super(directory: () async => null);

  int revision = 0;
  final mods = <Map<String, dynamic>>[];
  final added = <String>[];
  final blobs = <String, List<int>>{};
  Map<String, dynamic>? index;
  Future<void>? libraryLoad;

  TeamLibraryState _now({int? since}) => TeamLibraryState.fromJson({
    'revision': revision,
    'canManage': true,
    'busy': false,
    if (since == revision) 'unchanged': true else 'mods': mods,
  });

  @override
  Future<TeamLibraryState> state({int? since}) async {
    await libraryLoad;
    return _now(since: since);
  }

  @override
  Future<void> checkStale() async {}

  @override
  Future<List<TeamLibraryHit>> search(String query) async => [
    TeamLibraryHit.fromJson({
      'id': 'AABBCCDD',
      'title': 'Ruby Mod',
      'description': 'Shiny red things.',
      'author': 'gemcutter',
      'downloads': 12500,
      'projectType': 'mod',
      'loaders': ['fabric'],
      'gameVersions': ['1.21.1'],
    }),
  ];

  @override
  Future<TeamLibraryState> add(
    String projectId, {
    String? loader,
    String? gameVersion,
  }) async {
    added.add(projectId);
    final sha = 'c' * 40;
    blobs[sha] = _png();
    index = {
      'versionId': 'v9',
      'files': [
        ['assets/ruby/textures/block/mine.png', sha, blobs[sha]!.length],
      ],
    };
    mods.add(
      _mod(version: 'v9', number: '2.0.0', fileCount: 1)..['addedBy'] = '',
    );
    revision++;
    return _now();
  }

  @override
  Future<TeamLibraryIndex> files(
    String projectId, {
    DateTime? loadedAt,
  }) async =>
      TeamLibraryIndex.fromJson(index!, loadedAt: loadedAt, local: true);

  @override
  Future<Uint8List?> blob(String sha1) async =>
      blobs[sha1] == null ? null : Uint8List.fromList(blobs[sha1]!);
}

/// Modrinth for the real on-device library: one project whose versions
/// [release] adds.
class _FakeModrinth implements TeamLocalLibrarySource {
  final versions = <Map<String, dynamic>>[];
  final jars = <String, Uint8List>{};

  @override
  Future<Object?> getJson(String path, [Map<String, String>? query]) async {
    if (path == '/project/AABBCCDD') {
      return {
        'id': 'AABBCCDD',
        'slug': 'ruby',
        'title': 'Ruby Mod',
        'project_type': 'mod',
        'icon_url': 'http://cdn.example.com/icon.png',
        'loaders': ['fabric'],
        'game_versions': ['1.20.1', '1.21.1'],
      };
    }
    if (path == '/project/AABBCCDD/version') return versions;
    if (path == '/search') {
      return {
        'hits': [
          {
            'project_id': 'AABBCCDD',
            'project_type': 'mod',
            'title': 'Ruby Mod',
            'categories': ['fabric', 'decoration'],
            'versions': ['1.20.1', '1.21.1'],
          },
          {'project_id': 'EEFFGGHH', 'project_type': 'modpack'},
        ],
      };
    }
    return null;
  }

  @override
  Future<bool> download(Uri url, File to, int maxBytes) async {
    final bytes = jars['$url'];
    if (bytes == null) return false;
    await to.writeAsBytes(bytes);
    return true;
  }

  void release(
    String id,
    String number,
    String date,
    Uint8List jar, {
    String? sha1,
  }) {
    final url = 'https://cdn.modrinth.com/data/AABBCCDD/versions/$id/ruby.jar';
    jars[url] = jar;
    versions.add({
      'id': id,
      'version_number': number,
      'name': number,
      'date_published': date,
      'loaders': ['fabric'],
      'game_versions': ['1.21.1'],
      'files': [
        {
          'url': url,
          'filename': 'ruby-$number.jar',
          'primary': true,
          'size': jar.length,
          'hashes': {'sha1': sha1 ?? crypto.sha1.convert(jar).toString()},
        },
      ],
    });
  }
}

Uint8List _jar(Map<String, List<int>> files) {
  final archive = Archive();
  for (final f in files.entries) {
    archive.addFile(ArchiveFile.bytes(f.key, f.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

Future<void> _pump(
  WidgetTester tester,
  _FakeServer server, {
  TeamLocalLibrary? local,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = TeamClipboardController(
    _SignedIn(),
    stateFile: () async => null,
    pollInterval: const Duration(hours: 1),
    apiFactory: (url, token) =>
        TeamClipboardApi(url, token: token, client: server.client),
    localLibrary: local ?? _FakeLocal(),
  )..init();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    TeamClipboardScope(
      controller: controller,
      child: MaterialApp(
        theme: LumaTheme.dark,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: const Scaffold(body: TeamClipboardPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('team-clipboard-library-tab')));
  await tester.pump();
  await tester.pump();
}

/// Lets real work (PNG decodes) finish, and the library's batch timer
/// fire, a frame at a time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(true));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  group('models', () {
    final index = TeamLibraryIndex('v1', [
      TeamLibraryAsset('assets/ruby/textures/block/ruby_block.png', 'a', 1),
      TeamLibraryAsset('assets/ruby/textures/block/fire.png.mcmeta', 'b', 1),
      TeamLibraryAsset('assets/ruby/models/block/ruby_block.json', 'c', 1),
      TeamLibraryAsset('assets/ruby/blockstates/ruby_block.json', 'd', 1),
      TeamLibraryAsset('assets/ruby/lang/en_us.json', 'e', 1),
      TeamLibraryAsset('data/ruby/recipes/ruby.json', 'f', 1),
      TeamLibraryAsset('assets/ruby/items/ruby.json', 'g', 1),
    ]);

    test('files sort into categories by where they sit', () {
      expect(
        [for (final a in index.assets) a.category],
        [
          TeamAssetCategory.textures,
          TeamAssetCategory.other,
          TeamAssetCategory.models,
          TeamAssetCategory.blockstates,
          TeamAssetCategory.lang,
          TeamAssetCategory.data,
          TeamAssetCategory.other,
        ],
      );
      final texture = index.assets.first;
      expect(texture.name, 'ruby_block.png');
      expect(texture.namespace, 'ruby');
      expect(texture.folder, 'textures/block');
      expect(texture.fileId, 'lib:a');
    });

    test('references resolve to paths in the mod, vanilla ones do not', () {
      expect(index.texture('ruby:block/ruby_block')?.sha1, 'a');
      expect(index.model('ruby:block/ruby_block')?.sha1, 'c');
      expect(index.model('block/cube_all'), isNull);
      expect(index.model('minecraft:block/cube_all'), isNull);
    });

    test('a blockstate or item definition leads to its first model', () {
      expect(
        teamFirstModelRef({
          'variants': {
            'facing=north': [
              {'model': 'ruby:block/a'},
              {'model': 'ruby:block/b'},
            ],
          },
        }),
        'ruby:block/a',
      );
      expect(
        teamFirstModelRef({
          'multipart': [
            {'when': {}},
            {
              'apply': {'model': 'ruby:block/post'},
            },
          ],
        }),
        'ruby:block/post',
      );
      expect(
        teamFirstModelRef({
          'model': {'type': 'minecraft:model', 'model': 'ruby:item/ruby'},
        }),
        'ruby:item/ruby',
      );
      expect(teamFirstModelRef({'en': 'hi'}), isNull);
    });

    test('an unchanged answer carries no mods', () {
      final state = TeamLibraryState.fromJson({
        'revision': 4,
        'unchanged': true,
      });
      expect(state.mods, isNull);
      final full = TeamLibraryState.fromJson({
        'revision': 5,
        'canManage': true,
        'mods': [_mod()],
      });
      final mod = full.mods!.single;
      expect(mod.hasAssets, isTrue);
      expect(mod.version!.number, '1.0.0');
      expect(mod.state, TeamLibraryModState.ready);
    });
  });

  for (final slowShelf in ['team', 'local']) {
    testWidgets('does not flash an empty library while $slowShelf mods load', (
      tester,
    ) async {
      final pending = Completer<void>();
      final server = _FakeServer();
      final local = _FakeLocal();
      if (slowShelf == 'team') {
        server.libraryLoad = pending.future;
        server.mods.add(_mod());
      } else {
        local.libraryLoad = pending.future;
        local.mods.add(_mod());
      }

      await _pump(tester, server, local: local);
      expect(find.text('No mods in the library yet'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Ruby Mod'), findsOneWidget);
      expect(find.text('No mods in the library yet'), findsNothing);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets(
      'shows loaded mods while the $slowShelf shelf is still loading',
      (tester) async {
        final pending = Completer<void>();
        final server = _FakeServer();
        final local = _FakeLocal();
        if (slowShelf == 'team') {
          server.libraryLoad = pending.future;
          local.mods.add(_mod());
        } else {
          local.libraryLoad = pending.future;
          server.mods.add(_mod());
        }

        await _pump(tester, server, local: local);
        expect(find.text('Ruby Mod'), findsOneWidget);
        expect(find.text('No mods in the library yet'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        pending.complete();
        await tester.pump();
        await tester.pump();
        expect(find.text('Ruby Mod'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );

    testWidgets(
      'a failed $slowShelf load shows a retry instead of an empty library',
      (tester) async {
        final pending = Completer<void>();
        final server = _FakeServer();
        final local = _FakeLocal();
        if (slowShelf == 'team') {
          server.libraryLoad = pending.future;
        } else {
          local.libraryLoad = pending.future;
        }

        await _pump(tester, server, local: local);
        pending.completeError(StateError('Library load failed'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('Library load failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('No mods in the library yet'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        server.libraryLoad = null;
        local.libraryLoad = null;
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('Library load failed'), findsNothing);
        expect(find.text('No mods in the library yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );
  }

  testWidgets('shows an empty library only after both shelves finish loading', (
    tester,
  ) async {
    final pending = Completer<void>();
    final server = _FakeServer()..libraryLoad = pending.future;
    await _pump(tester, server);
    expect(find.text('No mods in the library yet'), findsNothing);

    pending.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('No mods in the library yet'), findsOneWidget);
    expect(find.text('Add mod'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a lead adds a mod; it fills in, previews and reloads', (
    tester,
  ) async {
    final server = _FakeServer();
    await _pump(tester, server);
    expect(find.text('No mods in the library yet'), findsOneWidget);

    await tester.tap(find.text('Add mod'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Ruby Mod'));
    await tester.pump();
    await tester.tap(find.text('Any loader'));
    await tester.pump();
    await tester.tap(find.text('fabric').last);
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump();

    final add = server.requests.lastWhere(
      (r) => r.url.path.endsWith('/library/mods'),
    );
    expect(jsonDecode(add.body), {
      'projectId': 'AABBCCDD',
      'loader': 'fabric',
      'gameVersion': null,
    });
    expect(find.text('Unpacking Ruby Mod'), findsOneWidget);

    // The server unpacks it; the next poll fills the page.
    server.unpacked('v1', '1.0.0', {
      'assets/ruby/textures/block/ruby_block.png': _png(),
      'assets/ruby/models/block/ruby_block.json': _cubeModel,
      'assets/ruby/lang/en_us.json': utf8.encode('{"block.ruby": "Ruby"}'),
    });
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    await _settle(tester);
    expect(find.text('Unpacking Ruby Mod'), findsNothing);
    expect(find.text('ruby_block'), findsOneWidget);

    // A model opens in 3D wearing the mod's own texture.
    await tester.tap(find.text('Models'));
    await tester.pump();
    await tester.tap(find.text('ruby_block.json'));
    await _settle(tester);
    expect(find.byType(TeamFileViewer), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(find.textContaining('Missing textures'), findsNothing);
    expect(
      server.requests.map((r) => r.url.path),
      contains('/api/v1/team-board/library/blobs'),
    );

    // An update drops: the library reloads and says so.
    server.unpacked('v2', '1.1.0', {
      'assets/ruby/textures/block/ruby_block.png': _png(),
      'assets/ruby/textures/block/sapphire.png': _png(),
      'assets/ruby/models/block/ruby_block.json': _cubeModel,
    });
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    await _settle(tester);
    expect(
      find.text('Ruby Mod updated to 1.1.0. The library reloaded.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Textures'));
    await tester.pump();
    await _settle(tester);
    expect(find.text('sapphire'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a big texture grid loads in batches and rides out a 429', (
    tester,
  ) async {
    final server = _FakeServer(lead: false)
      ..unpacked('v1', '1.0.0', {
        for (var i = 0; i < 400; i++)
          'assets/ruby/textures/block/tile_${i.toString().padLeft(3, '0')}.png':
              _png(),
      })
      ..busyFor = 1
      ..maxPerBatch = 30;
    await _pump(tester, server);
    await tester.tap(find.text('Ruby Mod'));
    await tester.pump();
    await tester.pump();
    // The first batch is told to slow down, then everything on screen
    // arrives anyway.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 600));
      await _settle(tester);
    }
    expect(find.byIcon(Icons.broken_image_rounded), findsNothing);
    final shown = tester.widgetList(find.textContaining('tile_')).length;
    expect(shown, greaterThan(20));
    // A screenful costs a few requests, not one per texture.
    expect(server.batchRequests, lessThan(shown ~/ 4));
    expect(
      server.requests.map((r) => r.url.path),
      isNot(contains(startsWith('/api/v1/team-board/library/blobs/'))),
    );
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a member browses but gets none of the lead controls', (
    tester,
  ) async {
    final server = _FakeServer(lead: false)
      ..unpacked('v1', '1.0.0', {
        'assets/ruby/lang/en_us.json': utf8.encode('{"a": "b"}'),
      });
    await _pump(tester, server);
    expect(find.byKey(const ValueKey('team-library-add')), findsNothing);
    expect(
      find.byKey(const ValueKey('team-library-add-local')),
      findsOneWidget,
    );
    await tester.tap(find.text('Ruby Mod'));
    await tester.pump();
    await tester.pump();
    expect(find.text('en_us.json'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open on Modrinth'), findsOneWidget);
    expect(find.text('Remove from library'), findsNothing);
    expect(find.text('Change versions'), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a member adds a mod to this device, apart from the team', (
    tester,
  ) async {
    final server = _FakeServer(lead: false)
      ..unpacked('v1', '1.0.0', {
        'assets/ruby/lang/en_us.json': utf8.encode('{"a": "b"}'),
      });
    final local = _FakeLocal();
    await _pump(tester, server, local: local);
    expect(find.text('TEAM'), findsOneWidget);
    expect(find.text('ON THIS DEVICE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-library-add-local')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Add to this device'), findsOneWidget);
    await tester.tap(find.text('Ruby Mod').last);
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump();
    await _settle(tester);

    expect(local.added, ['AABBCCDD']);
    // The team's copy and this device's own sit side by side.
    expect(find.text('Ruby Mod'), findsNWidgets(3));
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('mine'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_rounded), findsNothing);
    // Nothing about it went to the luma server.
    expect(
      server.requests.where(
        (r) => r.method != 'GET' || r.url.path.contains('/library/mods/'),
      ),
      isEmpty,
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Remove from this device'), findsOneWidget);
    expect(find.text('Change versions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  group('on this device', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('luma_tl'));
    tearDown(() => dir.delete(recursive: true));

    test('unpacks a mod, follows its updates and cleans up after it', () async {
      final modrinth = _FakeModrinth()
        ..release(
          'v1',
          '1.0.0',
          '2026-01-01T00:00:00Z',
          _jar({
            'assets/ruby/textures/block/ruby_block.png': _png(),
            'assets/ruby/models/block/ruby_block.json': _cubeModel,
            'assets/ruby/textures/block/broken.png': [1, 2, 3],
            'assets/ruby/sounds/ding.ogg': [1, 2],
            'com/example/Ruby.class': [0xCA, 0xFE],
          }),
        );
      final library = TeamLocalLibrary(
        directory: () async => dir,
        source: modrinth,
      );

      final hits = await library.search('');
      expect(hits.map((h) => h.id), ['AABBCCDD']);
      expect(hits.single.loaders, ['fabric']);
      expect(hits.single.gameVersions, ['1.21.1', '1.20.1']);

      await library.add('AABBCCDD', loader: 'fabric');
      await library.settle();
      var mod = (await library.state()).mods!.single;
      expect(mod.state, TeamLibraryModState.ready);
      expect(mod.version!.number, '1.0.0');
      expect(mod.fileCount, 2);
      expect(mod.skipped, 1);
      expect(mod.loader, 'fabric');
      expect(mod.iconUrl, isNull);
      expect(mod.url, 'https://modrinth.com/mod/ruby');
      expect(mod.namespaces, ['ruby']);

      final index = await library.files('AABBCCDD');
      final texture = index['assets/ruby/textures/block/ruby_block.png']!;
      expect(texture.fileId, '$kTeamLocalFilePrefix${texture.sha1}');
      expect(await library.blob(texture.sha1), _png());
      expect(await library.blob('../library'), isNull);
      expect(Directory('${dir.path}/tmp').listSync(), isEmpty);
      await expectLater(
        library.add('AABBCCDD'),
        throwsA(isA<TeamLocalLibraryException>()),
      );

      modrinth.release(
        'v2',
        '1.1.0',
        '2026-02-01T00:00:00Z',
        _jar({'assets/ruby/models/block/sapphire.json': _cubeModel}),
      );
      await library.check('AABBCCDD');
      await library.settle();
      mod = (await library.state()).mods!.single;
      expect(mod.version!.number, '1.1.0');
      expect(mod.history.single.number, '1.0.0');
      expect(await library.blob(texture.sha1), isNull);

      // A fresh start reads the same folder back.
      final again = TeamLocalLibrary(
        directory: () async => dir,
        source: modrinth,
      );
      expect((await again.state()).mods!.single.version!.number, '1.1.0');

      await library.remove('AABBCCDD');
      await library.settle();
      expect((await library.state()).mods, isEmpty);
      expect(Directory('${dir.path}/blobs').listSync(), isEmpty);
    });

    test('a damaged download fails and keeps nothing', () async {
      final modrinth = _FakeModrinth()
        ..release(
          'v1',
          '1.0.0',
          '2026-01-01T00:00:00Z',
          _jar({'assets/ruby/textures/block/ruby_block.png': _png()}),
          sha1: 'f' * 40,
        );
      final library = TeamLocalLibrary(
        directory: () async => dir,
        source: modrinth,
      );
      await library.add('AABBCCDD');
      await library.settle();
      final mod = (await library.state()).mods!.single;
      expect(mod.state, TeamLibraryModState.failed);
      expect(mod.error, 'The download was damaged.');
      final blobs = Directory('${dir.path}/blobs');
      expect(blobs.existsSync() ? blobs.listSync() : const [], isEmpty);
    });

    test('a jar entry outside assets/ or data/ is never kept', () {
      expect(isTeamLocalAssetPath('assets/ruby/textures/a.png'), isTrue);
      expect(isTeamLocalAssetPath('data/ruby/recipe/a.json'), isTrue);
      expect(isTeamLocalAssetPath('assets/ruby/../../evil.png'), isFalse);
      expect(isTeamLocalAssetPath('assets/ruby/sounds/a.ogg'), isFalse);
      expect(isTeamLocalAssetPath('META-INF/a.json'), isFalse);
    });
  });
}

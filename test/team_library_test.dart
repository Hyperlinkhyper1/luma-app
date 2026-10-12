import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/team_clipboard/data/team_clipboard_api.dart';
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

Future<void> _pump(WidgetTester tester, _FakeServer server) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = TeamClipboardController(
    _SignedIn(),
    stateFile: () async => null,
    pollInterval: const Duration(hours: 1),
    apiFactory: (url, token) =>
        TeamClipboardApi(url, token: token, client: server.client),
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
    expect(find.text('Add mod'), findsNothing);
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
}

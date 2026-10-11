import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/team_clipboard/data/team_clipboard_api.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_controller.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_models.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_page.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_clipboard_scope.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_file_check.dart';
import 'package:luma/features/plugins/installed/team_clipboard/team_model_mesh.dart';
import 'package:luma/features/plugins/installed/team_clipboard/ui/team_model_view.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';

/// A signed-in, approved account without going through a real sign-in.
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

Map<String, dynamic> _entry(
  String id,
  String title, {
  String kind = 'model',
  String stage = 'idea',
  bool closed = false,
  int updatedAtMs = 1000,
  List<Map<String, dynamic>> files = const [],
  List<Map<String, dynamic>>? messages,
  String? parentId,
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'brief': 'Brief for $title',
  'stage': stage,
  'closed': closed,
  'author': 'pixel',
  'mine': true,
  'claimedBy': stage == 'idea' ? null : 'blocky',
  'claimedByMe': false,
  'createdAtMs': 1000,
  'updatedAtMs': updatedAtMs,
  'messageCount': messages?.length ?? 0,
  'files': files,
  'canEdit': true,
  'canClose': true,
  'canDelete': true,
  'messages': ?messages,
  'parentId': parentId,
};

/// A small fake of the board endpoints, enough for the page.
class _FakeBoard {
  _FakeBoard({this.member = true});

  bool member;
  int revision = 1;
  String me = 'pixel';
  final requests = <http.Request>[];
  final blobs = <String, List<int>>{};
  final List<Map<String, dynamic>> entries = [
    _entry('a0', 'Copper lantern', stage: 'added', updatedAtMs: 9000),
    _entry(
      'b0',
      'Ruby ore',
      updatedAtMs: 2000,
      files: [
        {
          'id': 'f0',
          'name': 'ruby_ore.json',
          'sizeBytes': 120,
          'uploader': 'pixel',
          'mine': true,
          'canRemove': true,
          'createdAtMs': 1000,
        },
      ],
    ),
    _entry(
      'c0',
      'Chest lid clips',
      kind: 'bug',
      stage: 'claimed',
      updatedAtMs: 3000,
    ),
    _entry(
      'd0',
      'Old torch',
      stage: 'done',
      closed: true,
      updatedAtMs: 9500,
      files: [
        {
          'id': 'f9',
          'name': 'torch.png.mcmeta',
          'sizeBytes': 40,
          'uploader': 'blocky',
          'mine': false,
          'canRemove': false,
          'createdAtMs': 1000,
        },
      ],
    ),
  ];
  final Map<String, List<Map<String, dynamic>>> threads = {
    'b0': [
      {
        'id': 'm0',
        'author': 'blocky',
        'mine': false,
        'text': 'I can do the texture',
        'createdAtMs': 1500,
      },
    ],
  };

  Map<String, dynamic> _full(String id) {
    final e = entries.firstWhere((e) => e['id'] == id);
    final thread = threads[id] ?? [];
    return {...e, 'messages': thread, 'messageCount': thread.length};
  }

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
    if (path == '/api/v1/team-board') {
      if (!member) return json({'member': false, 'email': 'pixel@example.com'});
      if (request.url.queryParameters['since'] == '$revision') {
        return json({'member': true, 'revision': revision, 'unchanged': true});
      }
      return json({
        'member': true,
        'lead': false,
        'me': me,
        'revision': revision,
        'entries': entries,
      });
    }
    if (path == '/api/v1/team-board/me' && request.method == 'PUT') {
      final name = (jsonDecode(request.body) as Map)['name'] as String;
      me = name.isEmpty ? 'pixel' : name;
      revision++;
      return json({'me': me, 'revision': revision});
    }
    final blob = RegExp(r'^/api/v1/team-board/files/(\w+)$').firstMatch(path);
    if (blob != null && blobs.containsKey(blob.group(1))) {
      return http.Response.bytes(blobs[blob.group(1)]!, 200);
    }
    final match = RegExp(
      r'^/api/v1/team-board/entries/(\w+)(/messages)?$',
    ).firstMatch(path);
    if (match != null && request.method == 'GET') {
      return json(_full(match.group(1)!));
    }
    if (match != null && match.group(2) != null) {
      final text = (jsonDecode(request.body) as Map)['text'] as String;
      threads.putIfAbsent(match.group(1)!, () => []).add({
        'id': 'm${revision + 1}',
        'author': 'pixel',
        'mine': true,
        'text': text,
        'createdAtMs': 5000,
      });
      revision++;
      return json(_full(match.group(1)!), 201);
    }
    return json({'error': 'not_found', 'message': 'nope'}, 404);
  });
}

Future<TeamClipboardController> _pump(
  WidgetTester tester,
  _FakeBoard board, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = TeamClipboardController(
    _SignedIn(),
    stateFile: () async => null,
    pollInterval: const Duration(hours: 1),
    apiFactory: (url, token) =>
        TeamClipboardApi(url, token: token, client: board.client),
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
  return controller;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(true));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  group('api', () {
    test('reads the board, an unchanged answer and the way out', () async {
      final board = _FakeBoard();
      final api = TeamClipboardApi(
        'https://sync.example.com/',
        token: 't',
        client: board.client,
      );
      final first = await api.board();
      expect(first.access, TeamAccess.member);
      expect(first.entries!.map((e) => e.title), contains('Ruby ore'));
      expect(board.requests.last.headers['Authorization'], 'Bearer t');
      final again = await api.board(since: first.revision);
      expect(again.entries, isNull);
      expect(board.requests.last.url.query, 'since=1');

      board.member = false;
      final out = await api.board();
      expect(out.access, TeamAccess.outside);
      expect(out.email, 'pixel@example.com');
    });

    test('a refusal carries the server code', () async {
      final api = TeamClipboardApi(
        'https://sync.example.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'team_access_required',
              'message': 'Ask the admin.',
            }),
            403,
          ),
        ),
      );
      await expectLater(
        api.entry('abc'),
        throwsA(
          isA<TeamClipboardApiException>()
              .having((e) => e.accessRemoved, 'accessRemoved', isTrue)
              .having((e) => e.message, 'message', 'Ask the admin.'),
        ),
      );
    });

    test('nothing leaves the device while the gate is shut', () async {
      ServerAccessGate.instance.setApproved(false);
      final board = _FakeBoard();
      final api = TeamClipboardApi(
        'https://sync.example.com',
        client: board.client,
      );
      await expectLater(api.board(), throwsA(anything));
      expect(board.requests, isEmpty);
    });
  });

  test('animated strips count their frames', () {
    expect(teamTextureFrames(16, 16), 1);
    expect(teamTextureFrames(16, 64), 4);
    expect(teamTextureFrames(16, 40), 1);
    expect(teamTextureFrames(0, 0), 1);
  });

  testWidgets('an account the admin has not added sees who to ask', (
    tester,
  ) async {
    await _pump(tester, _FakeBoard(member: false));
    expect(find.text('Waiting for team access'), findsOneWidget);
    expect(find.textContaining('pixel@example.com'), findsOneWidget);
    expect(find.text('New entry'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('with nothing open the board fills the page as tiles', (
    tester,
  ) async {
    final controller = await _pump(tester, _FakeBoard());
    double y(String title) => tester.getTopLeft(find.text(title).first).dy;
    double x(String title) => tester.getTopLeft(find.text(title).first).dx;
    expect(y('Chest lid clips'), y('Ruby ore'));
    expect(x('Chest lid clips'), isNot(x('Ruby ore')));
    expect(y('Ruby ore'), lessThan(y('Copper lantern')));
    expect(find.text('Brief for Ruby ore'), findsOneWidget);

    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();
    expect(find.text('Claim it'), findsOneWidget);
    expect(x('Chest lid clips'), x('Ruby ore'));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, isNull);
    expect(find.text('Claim it'), findsNothing);
    expect(y('Chest lid clips'), y('Ruby ore'));
    await _unmount(tester);
  });

  testWidgets('work to do sits above finished entries', (tester) async {
    await _pump(tester, _FakeBoard(), size: const Size(700, 1200));
    double y(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(y('Chest lid clips'), lessThan(y('Copper lantern')));
    expect(y('Ruby ore'), lessThan(y('Copper lantern')));
    expect(y('Copper lantern'), lessThan(y('Old torch')));
    expect(find.text('TO DO'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);
    expect(find.text('Fixed'), findsNothing);
    expect(find.text('Claimed by blocky'), findsOneWidget);

    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();
    expect(find.text('Ruby ore'), findsNothing);
    expect(find.text('Chest lid clips'), findsOneWidget);
    await _unmount(tester);
  });

  group('local file check', () {
    final png = img.encodePng(img.Image(width: 16, height: 16));

    test('a whole PNG passes; a damaged or padded one does not', () async {
      expect(teamFileStructureProblem('ruby.png', png), isNull);
      expect(await checkTeamFile('ruby.png', png), isNull);

      final padded = Uint8List.fromList([...png, ...utf8.encode('#!/bin/sh')]);
      expect(
        teamFileStructureProblem('ruby.png', padded)?.kind,
        TeamFileProblemKind.badPng,
      );
      final corrupted = Uint8List.fromList(png)..[20] ^= 0xFF;
      expect(
        teamFileStructureProblem('ruby.png', corrupted)?.kind,
        TeamFileProblemKind.badPng,
      );
      expect(
        teamFileStructureProblem('ruby.png', utf8.encode('{"a": 1}'))?.kind,
        TeamFileProblemKind.badPng,
      );
      expect(
        teamFileStructureProblem(
          'huge.png',
          img.encodePng(img.Image(width: 8192, height: 1)),
        )?.kind,
        TeamFileProblemKind.imageTooBig,
      );
    });

    test('models and mcmeta must be JSON objects, with the error located', () {
      expect(
        teamFileStructureProblem(
          'ruby.json',
          utf8.encode('{"parent": "block/cube_all"}'),
        ),
        isNull,
      );
      final broken = teamFileStructureProblem(
        'ruby.json',
        utf8.encode('{\n  "parent": "block/cube_all",\n}'),
      )!;
      expect(broken.kind, TeamFileProblemKind.badJson);
      expect((broken.line, broken.column), (3, 1));
      expect(
        teamFileStructureProblem('a.mcmeta', utf8.encode('[1]'))?.kind,
        TeamFileProblemKind.notObject,
      );
      expect(
        teamFileStructureProblem('a.mcmeta', Uint8List.fromList([0xFF]))?.kind,
        TeamFileProblemKind.notText,
      );
      expect(
        teamFileStructureProblem('deep.json', utf8.encode('[' * 100))?.kind,
        TeamFileProblemKind.tooDeep,
      );
      expect(
        teamFileStructureProblem('run.exe', utf8.encode('{}'))?.kind,
        TeamFileProblemKind.wrongType,
      );
    });

    test('a file that fails the check never reaches the network', () async {
      final board = _FakeBoard();
      final controller = TeamClipboardController(
        _SignedIn(),
        stateFile: () async => null,
        apiFactory: (url, token) =>
            TeamClipboardApi(url, token: token, client: board.client),
      )..init();
      addTearDown(controller.dispose);
      await expectLater(
        controller.upload(
          'b0',
          TeamPickedFile('ruby.json', utf8.encode('{"parent": ')),
        ),
        throwsA(
          isA<TeamClipboardApiException>()
              .having((e) => e.code, 'code', 'rejected_locally')
              .having((e) => e.message, 'message', contains('line 1')),
        ),
      );
      expect(board.requests, isEmpty);
    });
  });

  testWidgets('a closed thread still offers its files for download', (
    tester,
  ) async {
    await _pump(tester, _FakeBoard());
    await tester.tap(find.text('Old torch'));
    await tester.pumpAndSettle();
    expect(find.text('This thread is closed.'), findsWidgets);
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('torch.png.mcmeta'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
    expect(find.byTooltip('Remove file'), findsNothing);
    expect(find.text('Add files'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('an entry opens on its overview, with files and chat as tabs', (
    tester,
  ) async {
    final board = _FakeBoard();
    await _pump(tester, board);
    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();

    expect(find.text('Brief for Ruby ore'), findsOneWidget);
    expect(find.text('Claim it'), findsOneWidget);
    expect(find.text('I can do the texture'), findsNothing);
    expect(find.text('Write a message…'), findsNothing);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('ruby_ore.json'), findsWidgets);
    expect(find.text('Brief for Ruby ore'), findsNothing);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('I can do the texture'), findsOneWidget);

    await tester.tap(find.text('Chest lid clips'));
    await tester.pumpAndSettle();
    expect(find.text('Write a message…'), findsOneWidget);
    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Write a message…'),
      'Pushed the model',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Pushed the model'), findsOneWidget);
    final sent = board.requests.where((r) => r.method == 'POST').single;
    expect(sent.url.path, '/api/v1/team-board/entries/b0/messages');
    await _unmount(tester);
  });

  testWidgets('a main thread holds its sub-entries and shows their progress', (
    tester,
  ) async {
    final board = _FakeBoard()
      ..entries.addAll([
        _entry('e0', 'Ruby ore texture', stage: 'done', parentId: 'b0'),
        _entry('e1', 'Ruby ore drop table', parentId: 'b0'),
      ]);
    final controller = await _pump(tester, board);
    expect(find.text('Ruby ore texture'), findsNothing);
    expect(find.text('1/2 finished'), findsOneWidget);

    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();
    expect(find.text('Sub-entries'), findsOneWidget);
    expect(find.text('Add sub-entry'), findsOneWidget);
    expect(find.text('Ruby ore texture'), findsWidgets);

    await tester.tap(find.text('Ruby ore drop table').last);
    await tester.pumpAndSettle();
    expect(controller.selectedId, 'e1');
    expect(find.text('Part of Ruby ore'), findsOneWidget);
    expect(find.text('Sub-entries'), findsNothing);

    await tester.tap(find.text('Part of Ruby ore'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 'b0');
    await _unmount(tester);
  });

  group('model mesh', () {
    TeamSprite sprite(String key, {int size = 16, List<int>? alpha}) =>
        TeamSprite(
          key: key,
          width: size,
          height: size,
          rgba: Uint8List.fromList([
            for (var i = 0; i < size * size; i++) ...[
              200,
              40,
              60,
              alpha?[i] ?? 255,
            ],
          ]),
        );

    test('references match attached textures by their last segment', () {
      expect(teamRefName('rubymod:item/ruby_sword'), 'ruby_sword');
      expect(teamRefName('block/Ruby_Ore.png'), 'ruby_ore');
      expect(teamRefName('ruby'), 'ruby');
    });

    test('a vanilla cube parent is rebuilt around the attached texture', () {
      final mesh = buildTeamModelMesh(
        {
          'parent': 'minecraft:block/cube_all',
          'textures': {'all': 'rubymod:block/ruby_block'},
        },
        sprites: {'ruby_block': sprite('k'), 'other': sprite('o')},
      );
      expect(mesh.quads, hasLength(6));
      expect(mesh.quads.map((q) => q.texture).toSet(), {'k'});
      expect(mesh.quads.map((q) => q.shade).toSet(), {0.8, 0.6, 1.0, 0.5});
      expect(mesh.missing, isEmpty);
    });

    test('a parent the team uploaded is followed for its elements', () {
      final mesh = buildTeamModelMesh(
        {'parent': 'rubymod:block/ruby_ore'},
        models: {
          'ruby_ore': {
            'parent': 'block/cube_all',
            'textures': {'all': 'rubymod:block/ruby_ore'},
          },
        },
        sprites: {'ruby_ore': sprite('ore')},
      );
      expect(mesh.quads, hasLength(6));
      expect(mesh.quads.first.texture, 'ore');
    });

    test('face uv and rotation land on the right corners', () {
      final mesh = buildTeamModelMesh(
        {
          'textures': {'0': 'rubymod:block/lamp'},
          'elements': [
            {
              'from': [0, 0, 0],
              'to': [16, 16, 16],
              'faces': {
                'north': {
                  'uv': [0, 0, 8, 8],
                  'rotation': 90,
                  'texture': '#0',
                },
              },
            },
          ],
        },
        sprites: {'lamp': sprite('lamp')},
      );
      final q = mesh.quads.single;
      // Turned a quarter clockwise, the top-left corner shows what was the
      // region's bottom-left.
      expect(q.uvs.sublist(0, 2), [0, 0.5]);
      expect(q.uvs.sublist(2, 4), [0, 0]);
      expect(q.uvs.sublist(4, 6), [0.5, 0]);
      // North faces -Z, its top-left seen from outside is the +X corner.
      expect(q.points.sublist(0, 3), [16, 16, 0]);
    });

    test('an element rotation turns about its origin', () {
      final mesh = buildTeamModelMesh(
        {
          'textures': {'all': 'x'},
          'elements': [
            {
              'from': [8, 0, 8],
              'to': [16, 16, 8],
              'rotation': {
                'origin': [8, 8, 8],
                'axis': 'y',
                'angle': 90,
              },
              'faces': {
                'south': {'texture': '#all'},
              },
            },
          ],
        },
        sprites: {'x': sprite('x')},
      );
      final p = mesh.quads.single.points;
      // (16, 16, 8) turns a quarter about +Y to (8, 16, 0).
      expect(p[3], closeTo(8, 1e-9));
      expect(p[5], closeTo(0, 1e-9));
    });

    test('names that match nothing are reported, unless one texture is all '
        'there is', () {
      final model = {
        'parent': 'block/cube_all',
        'textures': {'all': 'rubymod:block/missing_one'},
      };
      final many = buildTeamModelMesh(
        model,
        sprites: {'a': sprite('a'), 'b': sprite('b')},
      );
      expect(many.missing, ['missing_one']);
      expect(many.quads.every((q) => q.texture == null), isTrue);
      final one = buildTeamModelMesh(model, sprites: {'a': sprite('a')});
      expect(one.missing, isEmpty);
      expect(one.quads.first.texture, 'a');
    });

    test('a flat item gets a front, a back and an edge round each pixel', () {
      // 2×2 with the bottom-right pixel clear.
      final item = teamItemMesh(
        sprite('i', size: 2, alpha: [255, 255, 255, 0]),
      );
      expect(item.quads, hasLength(2 + 8));
      final generated = buildTeamModelMesh(
        {
          'parent': 'minecraft:item/handheld',
          'textures': {'layer0': 'rubymod:item/ruby_sword'},
        },
        sprites: {
          'ruby_sword': sprite('s', size: 2, alpha: [255, 255, 255, 0]),
        },
      );
      expect(generated.quads, hasLength(10));
      final (_, _, cz, _) = generated.bounds;
      expect(cz, 8);
    });

    test('only models count as models', () {
      expect(teamLooksLikeModel({'parent': 'block/cube_all'}), isTrue);
      expect(teamLooksLikeModel({'elements': []}), isTrue);
      expect(teamLooksLikeModel({'variants': {}, 'textures': {}}), isFalse);
      expect(teamLooksLikeModel({'pools': []}), isFalse);
    });
  });

  testWidgets('a model and its texture open in the 3D viewer', (tester) async {
    final pixels = img.Image(width: 16, height: 16, numChannels: 4);
    for (var y = 4; y < 12; y++) {
      for (var x = 4; x < 12; x++) {
        pixels.setPixelRgba(x, y, 200, 30, 60, 255);
      }
    }
    final board = _FakeBoard()
      ..entries.add(
        _entry(
          'g0',
          'Ruby sword',
          files: [
            for (final (id, name) in [
              ('m1', 'ruby_sword.json'),
              ('p1', 'ruby_sword.png'),
            ])
              {
                'id': id,
                'name': name,
                'sizeBytes': 100,
                'uploader': 'pixel',
                'mine': true,
                'canRemove': true,
                'createdAtMs': 1000,
              },
          ],
        ),
      )
      ..blobs['m1'] = utf8.encode(
        jsonEncode({
          'parent': 'minecraft:item/handheld',
          'textures': {'layer0': 'rubymod:item/ruby_sword'},
        }),
      )
      ..blobs['p1'] = img.encodePng(pixels);
    await _pump(tester, board);
    await tester.tap(find.text('Ruby sword'));
    await tester.pumpAndSettle();
    // Decoding a PNG is real work, so it needs real time to finish in.
    Future<void> decode() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    await tester.tap(find.text('Files'));
    await decode();

    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(find.textContaining('Drag to turn'), findsOneWidget);
    expect(find.textContaining('Missing textures'), findsNothing);
    expect(find.text('2D'), findsNothing);

    await tester.tap(find.text('ruby_sword.png'));
    await decode();
    expect(find.text('2D'), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsNothing);
    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.byTooltip('Reset view'), findsOneWidget);

    await tester.dragFrom(
      tester.getCenter(find.byType(TeamFileViewer)),
      const Offset(80, 30),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a member changes the name the team sees', (tester) async {
    final board = _FakeBoard();
    final controller = await _pump(tester, board);
    await tester.tap(find.byTooltip('Your name on the board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pixel Pete');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.me, 'Pixel Pete');
    expect(find.text('Pixel Pete'), findsOneWidget);
    final sent = board.requests.where((r) => r.method == 'PUT').single;
    expect(sent.url.path, '/api/v1/team-board/me');
    expect(jsonDecode(sent.body), {'name': 'Pixel Pete'});
    await _unmount(tester);
  });
}

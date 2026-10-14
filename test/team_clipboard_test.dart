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
import 'package:luma/features/plugins/installed/team_clipboard/team_settings_models.dart';
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
  _FakeBoard({this.member = true, this.lead = false});

  bool member;
  bool lead;

  /// What the Discord endpoints answer; a PUT merges into it.
  final Map<String, dynamic> discord = {
    'linked': false,
    'enabled': true,
    'status': 'off',
    'guilds': <Object>[],
    'automod': <Object>[],
    'replies': <Object>[],
    'log': <Object>[],
  };
  int revision = 1;
  String me = 'pixel';

  /// This account's permissions as a member; a lead has them all.
  List<String> permissions = [];

  /// What the Settings endpoints hold.
  final List<Map<String, dynamic>> tags = [];
  final List<Map<String, dynamic>> members = [
    {
      'id': 'u-pixel',
      'name': 'pixel',
      'email': 'pixel@example.com',
      'role': 'lead',
      'permissions': <String>[],
      'tags': <String>[],
    },
    {
      'id': 'u-blocky',
      'name': 'blocky',
      'email': 'blocky@example.com',
      'role': 'member',
      'permissions': <String>[],
      'tags': <String>[],
    },
  ];

  Map<String, dynamic> get _settings => {
    'permissions': [for (final p in TeamPermission.values) p.name],
    'tags': tags,
    'members': [
      for (final m in members)
        {
          ...m,
          'effective': m['role'] == 'lead'
              ? [for (final p in TeamPermission.values) p.name]
              : {
                  ...m['permissions'] as List,
                  for (final t in tags)
                    if ((m['tags'] as List).contains(t['id']))
                      ...t['permissions'] as List,
                }.toList(),
        },
    ],
  };

  void _saveSettings(Map<String, dynamic> body) {
    if (body['tags'] case final List<dynamic> next) {
      var n = tags.length;
      final kept = [
        for (final t in next.cast<Map<String, dynamic>>())
          {...t, 'id': t['id'] ?? 't${n++}'},
      ];
      tags
        ..clear()
        ..addAll(kept);
      final ids = {for (final t in kept) t['id']};
      for (final m in members) {
        m['tags'] = [
          for (final id in m['tags'] as List)
            if (ids.contains(id)) id,
        ];
      }
    }
    if (body['members'] case final List<dynamic> changes) {
      for (final c in changes.cast<Map<String, dynamic>>()) {
        final m = members.firstWhere((m) => m['id'] == c['id']);
        if (c.containsKey('permissions')) m['permissions'] = c['permissions'];
        if (c.containsKey('tags')) m['tags'] = c['tags'];
      }
    }
  }

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
      final base = {
        'member': true,
        'lead': lead,
        'me': me,
        'permissions': lead
            ? [for (final p in TeamPermission.values) p.name]
            : permissions,
        'revision': revision,
      };
      if (request.url.queryParameters['since'] == '$revision') {
        return json({...base, 'unchanged': true});
      }
      return json({...base, 'entries': entries});
    }
    if (path == '/api/v1/team-board/settings') {
      if (!lead) {
        return json({'error': 'forbidden', 'message': 'Leads only.'}, 403);
      }
      if (request.method == 'PUT') {
        _saveSettings(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return json(_settings);
    }
    if (path == '/api/v1/team-board/discord') {
      if (request.method == 'PUT') {
        discord.addAll(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return json({...discord, 'canManage': lead});
    }
    if (path == '/api/v1/team-board/discord/token') {
      if (request.method == 'PUT') {
        discord
          ..['linked'] = true
          ..['bot'] = {'id': '1', 'name': 'ModBot'}
          ..['inviteUrl'] = 'https://discord.com/oauth2/authorize?client_id=1';
      } else {
        discord
          ..['linked'] = false
          ..remove('bot');
      }
      return json({...discord, 'canManage': lead});
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
  ThemeData? theme,
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
        theme: theme ?? LumaTheme.dark,
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

  testWidgets('the task table opens details and returns to aligned rows', (
    tester,
  ) async {
    final controller = await _pump(tester, _FakeBoard());
    double y(String title) => tester.getTopLeft(find.text(title).first).dy;
    double x(String title) => tester.getTopLeft(find.text(title).first).dx;
    expect(y('Chest lid clips'), isNot(y('Ruby ore')));
    expect(x('Chest lid clips'), x('Ruby ore'));
    expect(y('Ruby ore'), lessThan(y('Copper lantern')));
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Discord bot'), findsOneWidget);

    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();
    expect(find.text('Claim it'), findsOneWidget);
    expect(x('Chest lid clips'), x('Ruby ore'));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, isNull);
    expect(find.text('Claim it'), findsNothing);
    expect(y('Chest lid clips'), isNot(y('Ruby ore')));
    expect(x('Chest lid clips'), x('Ruby ore'));
    await _unmount(tester);
  });

  testWidgets('Discord bot keeps task selection and filters on return', (
    tester,
  ) async {
    final board = _FakeBoard();
    final controller = await _pump(tester, board);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search titles, briefs and files'),
      'Ruby',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 'b0');
    final requestCount = board.requests.length;

    await tester.tap(find.byKey(const ValueKey('team-clipboard-discord-tab')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('team-discord-card-automod')),
      findsOneWidget,
    );
    expect(find.text('Claim it'), findsNothing);
    expect(
      board.requests.skip(requestCount).map((r) => r.url.path),
      everyElement('/api/v1/team-board/discord'),
    );

    await tester.tap(find.byKey(const ValueKey('team-clipboard-tasks-tab')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('team-discord-card-automod')),
      findsNothing,
    );
    expect(controller.selectedId, 'b0');
    expect(find.text('Claim it'), findsOneWidget);
    expect(find.text('Chest lid clips'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Search titles, briefs and files'),
          )
          .controller!
          .text,
      'Ruby',
    );
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('task navigation and phone details fit a narrow light view', (
    tester,
  ) async {
    final board = _FakeBoard()
      ..entries.add(_entry('e0', 'Ruby ore texture', parentId: 'b0'));
    final controller = await _pump(
      tester,
      board,
      size: const Size(320, 844),
      theme: LumaTheme.light,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-discord-tab')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('team-discord-card-automod')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-tasks-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 'b0');
    expect(find.text('Brief for Ruby ore'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(controller.selectedId, isNull);
    expect(find.text('Tasks'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('the bot’s resource usage shows only what the bot uses', (
    tester,
  ) async {
    final board = _FakeBoard();
    board.discord['metrics'] = {
      'cores': 8,
      'sinceMs': DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      'everyMs': 10000,
      'cpuMs': 12400,
      'cpuPercent': 0.0312,
      'memoryBytes': 84 * 1024,
      'settingsBytes': 1024,
      'attachmentBytes': 3 * 1024 * 1024,
      'diskWrittenBytes': 5 * 1024 * 1024,
      'diskWritePerSecond': 0,
      'netInBytes': 2 * 1024 * 1024,
      'netOutBytes': 300 * 1024,
      'netInPerSecond': 1536,
      'netOutPerSecond': 512,
      'history': {
        'cpu': [0.01, 0.05, 0.0312],
        'memory': [80000, 82000, 86016],
        'diskWrite': [0, 2048, 0],
        'netIn': [1024, 4096, 1536],
        'netOut': [256, 1024, 512],
      },
    };
    await _pump(tester, board);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-discord-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-discord-nav-usage')));
    await tester.pumpAndSettle();

    expect(find.text('Resource usage'), findsWidgets);
    for (final key in ['cpu', 'memory', 'disk', 'network']) {
      expect(find.byKey(ValueKey('team-discord-usage-$key')), findsOneWidget);
    }
    expect(find.text('0.03%'), findsOneWidget);
    expect(find.textContaining('12.4 s of CPU time'), findsOneWidget);
    expect(find.text('≈ 84.0 KB'), findsOneWidget);
    expect(find.text('3.0 MB'), findsOneWidget);
    expect(find.text('1.5 KB/s'), findsOneWidget);
    expect(find.text('512 B/s'), findsOneWidget);
    expect(find.textContaining('2.0 MB down'), findsOneWidget);
    expect(find.textContaining('Totals since the server started'), findsOne);
    expect(tester.takeException(), isNull);

    board.discord.remove('metrics');
    await tester.tap(find.byKey(const ValueKey('team-discord-nav-plugins')));
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-discord-nav-usage')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("doesn't measure the bot's usage yet"),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('a lead links the Discord bot and adds an automod rule', (
    tester,
  ) async {
    final board = _FakeBoard(lead: true);
    await _pump(tester, board);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-discord-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Plugins'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('team-discord-nav-bot')));
    await tester.pumpAndSettle();
    expect(find.text('Link your Discord bot'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('team-discord-token')),
      'secret-token',
    );
    await tester.tap(find.text('Link bot'));
    await tester.pumpAndSettle();
    final link = board.requests.lastWhere(
      (r) => r.url.path == '/api/v1/team-board/discord/token',
    );
    expect(jsonDecode(link.body), {'token': 'secret-token'});
    expect(find.text('ModBot'), findsWidgets);
    expect(find.text('Add to server'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-discord-nav-plugins')));
    await tester.pumpAndSettle();
    expect(find.text('Enable'), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('team-discord-card-automod')));
    await tester.pumpAndSettle();
    final enable = board.requests.lastWhere(
      (r) => r.url.path == '/api/v1/team-board/discord' && r.method == 'PUT',
    );
    expect(jsonDecode(enable.body), {'automodOn': true});
    expect(find.text('Rules'), findsOneWidget);

    await tester.tap(find.text('Add rule'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-discord-words')),
      'Creeper, griefing\ncreeper',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final save = board.requests.lastWhere(
      (r) => r.url.path == '/api/v1/team-board/discord' && r.method == 'PUT',
    );
    final automod = (jsonDecode(save.body) as Map)['automod'] as List;
    expect((automod.single as Map)['words'], ['creeper', 'griefing']);
    expect(find.text('griefing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a lead tracks a forum, limited to a tag', (tester) async {
    final board = _FakeBoard(lead: true)
      ..discord.addAll({
        'linked': true,
        'status': 'online',
        'bot': {'id': '1', 'name': 'ModBot'},
        'forums': [
          {
            'id': '100',
            'name': 'bug-reports',
            'guild': 'Mod Team',
            'tags': [
              {'id': '5', 'name': 'Crash'},
              {'id': '6', 'name': 'Visual'},
            ],
          },
        ],
      });
    await _pump(tester, board);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-discord-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-discord-nav-forums')));
    await tester.pumpAndSettle();
    expect(find.text('Forum tracking'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('team-discord-plugin-forums')));
    await tester.pumpAndSettle();
    final enable = board.requests.lastWhere(
      (r) => r.url.path == '/api/v1/team-board/discord' && r.method == 'PUT',
    );
    expect(jsonDecode(enable.body), {'forumsOn': true});

    await tester.tap(find.text('Add rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a forum.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-discord-forum')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#bug-reports · Mod Team').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Crash'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-discord-missing')),
      'Add your latest.log please',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final save = board.requests.lastWhere(
      (r) => r.url.path == '/api/v1/team-board/discord' && r.method == 'PUT',
    );
    final tracker =
        ((jsonDecode(save.body) as Map)['trackers'] as List).single as Map;
    expect(tracker['forumId'], '100');
    expect(tracker['forumName'], 'bug-reports');
    expect(tracker['tags'], [
      {'id': '5', 'name': 'Crash'},
    ]);
    expect(tracker['kind'], 'bug');
    expect(tracker['require'], 'both');
    expect(tracker['missingMessage'], 'Add your latest.log please');
    expect(tracker['doneMessage'], contains('{status}'));
    expect(find.text('#bug-reports'), findsOneWidget);
    expect(find.text('Crash'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('an entry from Discord links back and says what it misses', (
    tester,
  ) async {
    final board = _FakeBoard();
    board.entries.add({
      ..._entry('e0', 'Ruby chest crash', kind: 'bug', updatedAtMs: 9900),
      'author': 'steve',
      'discord': {
        'url': 'https://discord.com/channels/1/900',
        'author': 'steve',
        'missing': 'log',
        'attachments': [
          {
            'name': 'crash.jpg',
            'messageUrl': 'https://discord.com/channels/1/900/900',
          },
        ],
      },
    });
    await _pump(tester, board);
    expect(
      find.byTooltip('Still missing a log file'),
      findsOneWidget,
      reason: 'the task row flags it',
    );
    await tester.tap(find.text('Ruby chest crash'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-entry-discord')), findsOneWidget);
    expect(find.text('From Discord · posted by steve'), findsOneWidget);
    expect(find.text('Open in Discord'), findsOneWidget);
    expect(find.text('Still missing a log file'), findsOneWidget);
    expect(find.text('crash.jpg'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a member sees the bot but none of its controls', (tester) async {
    final board = _FakeBoard()
      ..discord.addAll({
        'linked': true,
        'status': 'online',
        'bot': {'id': '1', 'name': 'ModBot'},
        'replies': [
          {
            'id': 'r1',
            'triggers': ['modpack'],
            'reply': 'Grab it in #downloads',
            'match': 'word',
          },
        ],
      });
    await _pump(tester, board, size: const Size(360, 800));
    await tester.tap(find.byKey(const ValueKey('team-clipboard-discord-tab')));
    await tester.pumpAndSettle();
    expect(find.text('ModBot'), findsOneWidget);
    expect(find.text('Enable'), findsNothing);
    expect(find.text('View'), findsNWidgets(3));
    await tester.ensureVisible(
      find.byKey(const ValueKey('team-discord-card-replies')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-discord-card-replies')));
    await tester.pumpAndSettle();
    expect(find.text('modpack'), findsOneWidget);
    expect(find.text('Add rule'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.byKey(const ValueKey('team-discord-identity')));
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Only team leads can change the bot.'), findsOneWidget);
    expect(find.byKey(const ValueKey('team-discord-enabled')), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('search keeps a matching subtask visible without its parent', (
    tester,
  ) async {
    final board = _FakeBoard()
      ..entries.add(_entry('e0', 'Distinct texture', parentId: 'b0'));
    final controller = await _pump(tester, board);
    expect(find.text('Distinct texture'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search titles, briefs and files'),
      'Distinct',
    );
    await tester.pumpAndSettle();
    expect(find.text('Ruby ore'), findsNothing);
    expect(find.text('Distinct texture'), findsOneWidget);
    await tester.tap(find.text('Distinct texture'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 'e0');
    expect(find.text('Part of Ruby ore'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Ruby ore texture'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byTooltip('1/2 finished'), findsOneWidget);

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

  testWidgets('only a lead gets the Settings tab', (tester) async {
    final settingsTab = find.byKey(
      const ValueKey('team-clipboard-settings-tab'),
    );
    await _pump(tester, _FakeBoard());
    expect(settingsTab, findsNothing);
    await _unmount(tester);

    await _pump(tester, _FakeBoard(lead: true));
    expect(settingsTab, findsOneWidget);
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();
    expect(find.text('Team settings'), findsOneWidget);
    expect(find.text('Lead · can do everything'), findsOneWidget);
    expect(find.text('0 of 7 permissions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a lead makes a tag and puts a member in it', (tester) async {
    final board = _FakeBoard(lead: true);
    await _pump(tester, board);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-settings-tab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('team-settings-new-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-settings-tag-name')),
      'Tester',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('team-settings-perm-markAdded')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('team-settings-wearer-u-blocky')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('team-settings-wearer-u-blocky')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('team-settings-save')));
    await tester.pumpAndSettle();

    final puts = [
      for (final r in board.requests)
        if (r.method == 'PUT') jsonDecode(r.body) as Map<String, dynamic>,
    ];
    expect(puts, hasLength(2));
    expect(puts.first['tags'], [
      {
        'name': 'Tester',
        'color': 0,
        'permissions': ['markAdded'],
      },
    ]);
    expect(puts.last['members'], [
      {
        'id': 'u-blocky',
        'tags': ['t0'],
      },
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tester'), findsNWidgets(2));
    expect(find.text('1 of 7 permissions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('a tag’s permission shows as given by it, and is not saved as '
      'the member’s own', (tester) async {
    final board = _FakeBoard(lead: true)
      ..tags.add({
        'id': 't0',
        'name': 'Tester',
        'color': 2,
        'permissions': ['markAdded'],
      });
    await _pump(tester, board);
    await tester.tap(find.byKey(const ValueKey('team-clipboard-settings-tab')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('team-settings-member-u-blocky')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Permissions for blocky'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-settings-wear-t0')));
    await tester.pump();
    expect(find.textContaining('Given by Tester'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('team-settings-perm-markAdded')),
    );
    await tester.tap(find.byKey(const ValueKey('team-settings-perm-editAny')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('team-settings-save')));
    await tester.pumpAndSettle();

    final put = board.requests.lastWhere((r) => r.method == 'PUT');
    expect(jsonDecode(put.body), {
      'members': [
        {
          'id': 'u-blocky',
          'permissions': ['editAny'],
          'tags': ['t0'],
        },
      ],
    });
    expect(find.text('2 of 7 permissions'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a member given markAdded may mark entries added', (
    tester,
  ) async {
    final board = _FakeBoard();
    final controller = await _pump(tester, board);
    expect(controller.can(TeamPermission.markAdded), isFalse);
    board
      ..permissions = ['markAdded']
      ..revision += 1;
    await controller.refresh();
    expect(controller.can(TeamPermission.markAdded), isTrue);
    expect(controller.can(TeamPermission.botToken), isFalse);
    expect(controller.isLead, isFalse);
    await _unmount(tester);
  });

  testWidgets('the kind filters fit beside an open entry', (tester) async {
    await _pump(tester, _FakeBoard());
    await tester.tap(find.text('Ruby ore'));
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byType(VerticalDivider));
    for (final label in ['Bugs', 'Suggestions', 'Models']) {
      final chip = find.byTooltip(label);
      expect(chip, findsOneWidget, reason: label);
      expect(tester.getRect(chip).right, lessThanOrEqualTo(list.left));
    }
    await _unmount(tester);
  });
}

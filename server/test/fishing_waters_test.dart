import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/fishing_waters.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The Fishing Waters bridge: the Roblox game's heartbeat, the dashboard's
/// weather override and gamepass grants, and the project switcher markup.
void main() {
  late Directory dir;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_fishing_waters_test');
    final store = await Store.open(dir.path);
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
      fishingWatersKey: 'game-secret',
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

  Future<(int, Map<String, dynamic>)> send(String method, String path,
      {Object? json, bool admin = false, String? gameKey}) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {
        'Content-Type': 'application/json',
        if (admin) 'x-admin-key': 'test-admin-key',
        if (path.startsWith('/admin/')) 'Origin': 'http://localhost',
        if (gameKey != null) 'x-fishing-waters-key': gameKey,
      },
      body: json == null ? null : jsonEncode(json),
    ));
    final raw = await response.readAsString();
    return (
      response.statusCode,
      raw.startsWith('{')
          ? jsonDecode(raw) as Map<String, dynamic>
          : <String, dynamic>{'raw': raw}
    );
  }

  Map<String, dynamic> heartbeatBody({List<Map<String, dynamic>>? players}) => {
        'jobId': 'job-1',
        'startedAt': 1000,
        'players': players ??
            [
              {
                'userId': 42,
                'name': 'angler',
                'displayName': 'Angler <b>',
                'joinedAt': 1000,
                'x': 10,
                'z': -20,
              }
            ],
        'weather': {'kind': 'Rain', 'rain': 0.6, 'windSpeed': 30},
        'kinds': ['Clear', 'LightRain', 'Rain', 'Storm'],
        'schedule': [
          {'kind': 'Clear', 'duration': 150},
          {'kind': 'Rain', 'duration': 180},
        ],
        'passes': [
          {'key': 'AutoStore', 'name': 'Auto Store', 'id': 3722004182},
        ],
      };

  test('the heartbeat requires the game key', () async {
    final (missing, _) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody());
    expect(missing, 401);
    final (wrong, _) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'nope');
    expect(wrong, 401);
    final (ok, body) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'game-secret');
    expect(ok, 200);
    expect(body['intervalSeconds'], FishingWaters.heartbeatSeconds);
    expect(body['weatherOverride'], isNull);
  });

  test('regional weather samples round-trip and malformed grids are discarded',
      () async {
    final body = heartbeatBody();
    final weather = body['weather'] as Map;
    weather['maxWaveAmplitude'] = 4.5;
    weather['radar'] = {
      'version': 1,
      'resolution': 2,
      'halfSize': 5200,
      'cells': [
        [0, 0, 6, 0.3],
        [0.5, 0.2, 25, 1.5],
        [1, 1, 52, 4.5],
        [0.1, 0, 10, 0.5]
      ],
      'peakRain': 999,
    };
    final (ok, _) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: body, gameKey: 'game-secret');
    expect(ok, 200);
    final (_, state) =
        await send('GET', '/admin/fishing-waters/state', admin: true);
    final reported =
        ((state['servers'] as List).single as Map)['weather'] as Map;
    expect(reported['maxWaveAmplitude'], 4.5);
    final radar = reported['radar'] as Map;
    expect(radar['cells'], (weather['radar'] as Map)['cells']);
    expect(radar['peakRain'], 1);
    expect(radar['peakWave'], 4.5);
    for (final bad in [
      {'version': 1, 'resolution': 34, 'halfSize': 5200, 'cells': []},
      {
        'version': 1,
        'resolution': 2,
        'halfSize': 5200,
        'cells': [
          [1, 2]
        ]
      },
      {
        'version': 1,
        'resolution': 2,
        'halfSize': 5200,
        'cells': List.filled(4, [0, 'bad', 1, 2])
      },
    ]) {
      weather['radar'] = bad;
      await send('POST', '/api/v1/fishing-waters/heartbeat',
          json: body, gameKey: 'game-secret');
      final (_, invalid) =
          await send('GET', '/admin/fishing-waters/state', admin: true);
      expect(
          (((invalid['servers'] as List).single as Map)['weather']
              as Map)['radar'],
          isNull);
    }
  });

  test('live players, weather override and grants round-trip', () async {
    await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'game-secret');

    final (status, state) =
        await send('GET', '/admin/fishing-waters/state', admin: true);
    expect(status, 200);
    final servers = state['servers'] as List;
    expect(servers, hasLength(1));
    expect((servers.first as Map)['players'], hasLength(1));

    final (badKind, _) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'Hail'});
    expect(badKind, 400);
    final (setKind, afterSet) = await send(
        'POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'Storm'});
    expect(setKind, 200);
    expect((afterSet['weather'] as Map)['override'], 'Storm');

    // An online player resolves without asking Roblox.
    final (granted, afterGrant) = await send(
        'POST', '/admin/fishing-waters/grants',
        admin: true, json: {'user': 'Angler', 'pass': 'AutoStore'});
    expect(granted, 200, reason: '$afterGrant');
    expect(afterGrant['grants'], hasLength(1));
    final (duplicate, _) = await send('POST', '/admin/fishing-waters/grants',
        admin: true, json: {'user': '42', 'pass': 'AutoStore'});
    expect(duplicate, 409);

    final (_, reply) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'game-secret');
    expect(reply['weatherOverride'], 'Storm');
    expect(reply['grants'], {
      'AutoStore': [42]
    });

    // Grants only go to the server the player is in.
    final (_, empty) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(players: []), gameKey: 'game-secret');
    expect(empty['grants'], isEmpty);

    final (revoked, afterRevoke) = await send(
        'POST', '/admin/fishing-waters/grants/revoke',
        admin: true, json: {'userId': 42, 'pass': 'AutoStore'});
    expect(revoked, 200);
    expect(afterRevoke['grants'], isEmpty);
  });

  test('black holes require an admin and a bounded point, then reach game servers', () async {
    final (unauthorized, _) = await send('POST', '/admin/fishing-waters/weather',
        json: {'kind': 'BlackHole', 'blackHole': {'x': 30, 'z': -60}});
    expect(unauthorized, isNot(200));
    for (final point in [null, {}, {'x': 0}, {'x': '10', 'z': 0}, {'x': 5201, 'z': 0}, {'x': 0, 'z': -5201}]) {
      final (status, _) = await send('POST', '/admin/fishing-waters/weather',
          admin: true, json: {'kind': 'BlackHole', 'blackHole': point});
      expect(status, 400);
    }
    final (status, state) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'BlackHole', 'blackHole': {'x': 100.5, 'z': -200}});
    expect(status, 200);
    expect((state['weather'] as Map)['blackHole'], {'x': 100.5, 'z': -200});
    final (_, reply) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'game-secret');
    expect(reply['weatherOverride'], 'BlackHole');
    expect(reply['blackHole'], {'x': 100.5, 'z': -200});
    final (_, refreshed) = await send('GET', '/admin/fishing-waters/state', admin: true);
    expect((refreshed['weather'] as Map)['kinds'], contains('BlackHole'));
    final (moved, afterMove) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'BlackHole', 'blackHole': {'x': -5200, 'z': 5200}});
    expect(moved, 200);
    expect((afterMove['weather'] as Map)['blackHole'], {'x': -5200, 'z': 5200});
    final (clear, afterClear) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'Auto'});
    expect(clear, 200);
    expect((afterClear['weather'] as Map)['blackHole'], isNull);
    final (_, cleared) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'game-secret');
    expect(cleared['blackHole'], isNull);
    expect(cleared['weatherOverride'], isNull);
  });

  test('black hole locations persist and same-clock moves change the version', () async {
    final clock = DateTime.fromMillisecondsSinceEpoch(12345);
    final first = FishingWaters(dir.path, gameKey: 'k', clock: () => clock);
    Future<Response> setPoint(FishingWaters bridge, num x, num z) => bridge.setWeather(Request(
        'POST', Uri.parse('http://localhost/'),
        body: jsonEncode({'kind': 'BlackHole', 'blackHole': {'x': x, 'z': z}})));
    expect((await setPoint(first, 100, 200)).statusCode, 200);
    final v1 = (first.stateJson()['weather'] as Map)['setAt'] as int;
    expect((await setPoint(first, 300, 400)).statusCode, 200);
    final v2 = (first.stateJson()['weather'] as Map)['setAt'] as int;
    expect(v2, greaterThan(v1));
    final second = FishingWaters(dir.path, gameKey: 'k', clock: () => clock);
    final weather = second.stateJson()['weather'] as Map;
    expect(weather['override'], 'BlackHole');
    expect(weather['blackHole'], {'x': 300, 'z': 400});
    expect(weather['setAt'], v2);
  });

  test('supercells take an optional bounded location that reaches game servers', () async {
    final (unauthorized, _) = await send('POST', '/admin/fishing-waters/weather',
        json: {'kind': 'Supercell', 'supercell': {'x': 30, 'z': -60}});
    expect(unauthorized, isNot(200));
    await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody()..['kinds'] = ['Clear', 'Supercell', 'Storm'],
        gameKey: 'game-secret');
    for (final point in [{}, {'x': 0}, {'x': '10', 'z': 0}, {'x': 5201, 'z': 0}, {'x': 0, 'z': -5201}]) {
      final (status, _) = await send('POST', '/admin/fishing-waters/weather',
          admin: true, json: {'kind': 'Supercell', 'supercell': point});
      expect(status, 400);
    }
    final (placed, state) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'Supercell', 'supercell': {'x': 400, 'z': 600}});
    expect(placed, 200);
    expect((state['weather'] as Map)['supercell'], {'x': 400, 'z': 600});
    final (_, reply) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody()..['kinds'] = ['Clear', 'Supercell', 'Storm'],
        gameKey: 'game-secret');
    expect(reply['weatherOverride'], 'Supercell');
    expect(reply['supercell'], {'x': 400, 'z': 600});
    expect(reply['blackHole'], isNull);

    // Leaving the location out circles a random player: the game picks the spot.
    final (random, afterRandom) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'Supercell'});
    expect(random, 200);
    expect((afterRandom['weather'] as Map)['supercell'], isNull);
    final (_, randomReply) = await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody()..['kinds'] = ['Clear', 'Supercell', 'Storm'],
        gameKey: 'game-secret');
    expect(randomReply['weatherOverride'], 'Supercell');
    expect(randomReply['supercell'], isNull);

    final (blackHole, _) = await send('POST', '/admin/fishing-waters/weather',
        admin: true, json: {'kind': 'BlackHole', 'blackHole': {'x': 10, 'z': 20}});
    expect(blackHole, 200);
    final (_, afterBlackHole) = await send('GET', '/admin/fishing-waters/state', admin: true);
    expect((afterBlackHole['weather'] as Map)['supercell'], isNull);
  });

  test('supercell locations persist and clear with the override', () async {
    final clock = DateTime.fromMillisecondsSinceEpoch(12345);
    final first = FishingWaters(dir.path, gameKey: 'k', clock: () => clock);
    await first.heartbeat(Request('POST', Uri.parse('http://localhost/'),
        headers: {'x-fishing-waters-key': 'k'},
        body: jsonEncode({'jobId': 'job-1', 'kinds': ['Clear', 'Supercell']})));
    final placed = await first.setWeather(Request('POST', Uri.parse('http://localhost/'),
        body: jsonEncode({'kind': 'Supercell', 'supercell': {'x': 300, 'z': 400}})));
    expect(placed.statusCode, 200);
    final second = FishingWaters(dir.path, gameKey: 'k', clock: () => clock);
    final weather = second.stateJson()['weather'] as Map;
    expect(weather['override'], 'Supercell');
    expect(weather['supercell'], {'x': 300, 'z': 400});
    await second.setWeather(Request('POST', Uri.parse('http://localhost/'),
        body: jsonEncode({'kind': 'Clear'})));
    expect((second.stateJson()['weather'] as Map)['supercell'], isNull);
  });

  test('a closing server drops off the dashboard', () async {
    await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: heartbeatBody(), gameKey: 'game-secret');
    await send('POST', '/api/v1/fishing-waters/heartbeat',
        json: {'jobId': 'job-1', 'closing': true}, gameKey: 'game-secret');
    final (_, state) =
        await send('GET', '/admin/fishing-waters/state', admin: true);
    expect(state['servers'], isEmpty);
  });

  test('grants and the override survive a restart', () async {
    var fetches = 0;
    Future<(int, List<int>)> fetch(String method, Uri url,
        {Object? json}) async {
      fetches++;
      expect(url.host, 'users.roblox.com');
      expect((json as Map)['usernames'], ['Builderman']);
      return (
        200,
        utf8.encode(jsonEncode({
          'data': [
            {'id': 156, 'name': 'builderman', 'displayName': 'Builderman'}
          ]
        }))
      );
    }

    final first = FishingWaters(dir.path, gameKey: 'k', fetch: fetch);
    final response = await first.grant(Request(
        'POST', Uri.parse('http://localhost/'),
        body: jsonEncode({'user': '@Builderman', 'pass': 'AutoStore'})));
    expect(response.statusCode, 200, reason: await response.readAsString());
    expect(fetches, 1);
    await first.setWeather(Request('POST', Uri.parse('http://localhost/'),
        body: jsonEncode({'kind': 'Clear'})));

    final second = FishingWaters(dir.path, gameKey: 'k');
    final state = second.stateJson();
    expect((state['grants'] as List).single['userId'], 156);
    expect((state['weather'] as Map)['override'], 'Clear');
  });

  test('the dashboard carries both projects behind the logo menu', () async {
    final response = await handler(Request(
        'GET', Uri.parse('http://localhost/admin'),
        headers: {'x-admin-key': 'test-admin-key'}));
    final html = await response.readAsString();
    expect(response.statusCode, 200);
    expect(html, contains('id="projBtn"'));
    expect(html, contains('data-project="fw"'));
    expect(html, contains('id="project-luma"'));
    expect(html, contains('id="project-fw"'));
    expect(html, contains('id="fwBlackHoleX"'));
    expect(html, contains('id="fwBlackHoleZ"'));
    expect(html, contains('id="fwBlackHoleSpawn"'));
    expect(html, contains('id="fwSupercellX"'));
    expect(html, contains('id="fwSupercellSpawn"'));
    expect(html, contains('id="fwSupercellRandom"'));

    // Both projects sit side by side inside the page wrapper: the luma one
    // must be closed before Fishing Waters opens, and the wrapper after it.
    final body = html
        .substring(html.indexOf('<body'))
        .replaceAll(RegExp(r'<script\b.*?</script>', dotAll: true), '');
    var depth = 0;
    int? lumaDepth, fwDepth;
    for (final m in RegExp(r'<(/?)div\b[^>]*>').allMatches(body)) {
      if (m.group(1) == '/') {
        depth--;
      } else {
        if (m.group(0)!.contains('id="project-luma"')) lumaDepth = depth;
        if (m.group(0)!.contains('id="project-fw"')) {
          fwDepth = depth;
          expect(depth, lumaDepth, reason: 'project-fw must be a sibling');
        }
        depth++;
      }
    }
    expect(lumaDepth, 1, reason: 'projects live inside .wrap');
    expect(fwDepth, 1);
  });
}

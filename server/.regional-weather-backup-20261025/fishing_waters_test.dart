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

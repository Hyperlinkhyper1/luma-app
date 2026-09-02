import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_api.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_credentials.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_history.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_models.dart';
import 'package:luma/features/plugins/installed/account_overview/pmc_extract.dart';
import 'package:luma/features/plugins/installed/account_overview/ui/mc_charts.dart';

/// A real extractor payload, captured by running [pmcExtractorScript] against
/// a live Planet Minecraft member page.
///
/// This is the regression guard that matters for a scraper: PMC will change
/// its markup one day, and when it does the parser must keep behaving — the
/// failure belongs in a caught "unavailable", not in a crash.
const _capturedPmcPayload = '''
{
  "items": [
    {
      "id": "4975184",
      "kind": "skins",
      "title": "Official Cyprezz",
      "url": "/skin/official-cyprezz/",
      "views": "1.1k",
      "downloads": "55",
      "comments": "25",
      "diamonds": "166",
      "favorites": "113",
      "updated": "1735747406000"
    },
    {
      "id": "4136138",
      "kind": "blogs",
      "title": "Creating the Nether Build Contest Prize",
      "url": "/blog/creating-the-nether-build-contest-prize/",
      "views": "3.8k",
      "downloads": null,
      "comments": "59",
      "diamonds": "217",
      "favorites": "136",
      "updated": "1698932327000"
    }
  ],
  "menu": {
    "submissions": "33",
    "subscribers": "7,330",
    "favorites": "316",
    "upvoted": "8,141"
  },
  "blocked": false,
  "hasMore": true
}
''';

McDailyPoint _point(DateTime day, int downloads, {int views = 0}) =>
    McDailyPoint(day: day, downloads: downloads, views: views);

void main() {
  group('compact counts', () {
    test('reads exact, thousand and million forms', () {
      expect(parseCompactCount('55'), 55);
      expect(parseCompactCount('2,363'), 2363);
      expect(parseCompactCount('1.1k'), 1100);
      expect(parseCompactCount('24k'), 24000);
      expect(parseCompactCount('3.8M'), 3800000);
    });

    test('tells "no number" apart from zero', () {
      expect(parseCompactCount(null), isNull);
      expect(parseCompactCount(''), isNull);
      expect(parseCompactCount('n/a'), isNull);
      expect(parseCompactCount('0'), 0);
    });

    test('flags the forms the site rounded', () {
      expect(isCompactCount('1.1k'), isTrue);
      expect(isCompactCount('3.8M'), isTrue);
      expect(isCompactCount('2,363'), isFalse);
      expect(isCompactCount(null), isFalse);
    });
  });

  group('PMC extraction', () {
    test('parses a captured live payload', () {
      final page = parsePmcPayload(_capturedPmcPayload, memberName: 'cyprezz');

      expect(page.blocked, isFalse);
      expect(page.hasMore, isTrue);
      expect(page.projects.length, 2);

      final skin = page.projects.first;
      expect(skin.name, 'Official Cyprezz');
      expect(skin.platform, McPlatform.planetMinecraft);
      expect(skin.kind, 'skin');
      expect(skin.url, 'https://www.planetminecraft.com/skin/official-cyprezz/');
      expect(skin.views, 1100);
      expect(skin.downloads, 55);
      // Diamonds are PMC's nearest equivalent of a follower count.
      expect(skin.followers, 166);
      expect(skin.favourites, 113);
      // Views came back as "1.1k", so this project's figures are rounded.
      expect(skin.approximate, isTrue);
      expect(skin.updatedAt, DateTime.fromMillisecondsSinceEpoch(1735747406000));

      final blog = page.projects[1];
      expect(blog.kind, 'blog');
      expect(blog.downloads, 0);

      expect(page.menuCounts['subscribers'], 7330);
      expect(page.menuCounts['submissions'], 33);
    });

    test('survives markup that no longer matches', () {
      expect(parsePmcPayload(null).projects, isEmpty);
      expect(parsePmcPayload('').projects, isEmpty);
      expect(parsePmcPayload('<html>not json</html>').projects, isEmpty);
      expect(parsePmcPayload('{"items": "unexpected"}').projects, isEmpty);
      // Items missing an id or a title are skipped, not half-built.
      expect(
        parsePmcPayload('{"items":[{"id":null,"title":"x"},{"id":"1"}]}')
            .projects,
        isEmpty,
      );
    });

    test('unwraps a doubly-encoded payload from the WebView bridge', () {
      final page = parsePmcPayload(jsonEncode(_capturedPmcPayload));
      expect(page.projects.length, 2);
    });

    test('reports a Cloudflare interstitial as blocked', () {
      final page = parsePmcPayload('{"items":[],"menu":{},"blocked":true}');
      expect(page.blocked, isTrue);
      expect(page.projects, isEmpty);
    });

    test('caps how many pages it will walk', () {
      final pages = pmcPagesFor('octo');
      expect(pages.length, 4);
      expect(pages.first, endsWith('/member/octo/submissions/'));
      expect(pages.last, endsWith('?p=4'));
    });
  });

  group('history store', () {
    test('keeps one point per day, last write winning', () {
      final store = McHistoryStore.inMemory();
      final day = DateTime(2026, 9, 1, 9);

      store.record('modrinth', downloads: 100, at: day);
      store.record('modrinth', downloads: 140, at: day.add(const Duration(hours: 6)));

      expect(store.seriesFor('modrinth').length, 1);
      expect(store.seriesFor('modrinth').single.downloads, 140);
    });

    test('derives per-day gains and never charts a negative one', () {
      final store = McHistoryStore.inMemory();
      for (final (index, total) in [100, 120, 115, 200].indexed) {
        store.record(
          'cf',
          downloads: total,
          at: DateTime(2026, 9, 1).add(Duration(days: index)),
        );
      }

      final deltas = store.deltasFor('cf');
      expect(deltas.map((d) => d.gained).toList(), [20, 0, 85]);
    });

    test('integrates Modrinth gains backwards from the current total', () {
      final store = McHistoryStore.inMemory();
      // 10 gained yesterday, 5 the day before, ending on a total of 100.
      final gains = {
        DateTime(2026, 8, 30): 5,
        DateTime(2026, 8, 31): 10,
      };
      store.backfillFromGains('modrinth', gains, currentTotal: 100);

      final points = store.seriesFor('modrinth');
      expect(points.length, 2);
      expect(points.last.downloads, 100);
      expect(points.first.downloads, 90);
    });

    test('backfill never overwrites a day luma observed itself', () {
      final store = McHistoryStore.inMemory();
      store.record('modrinth', downloads: 999, at: DateTime(2026, 8, 31));
      store.backfillFromGains(
        'modrinth',
        {DateTime(2026, 8, 31): 10},
        currentTotal: 100,
      );

      expect(store.seriesFor('modrinth').single.downloads, 999);
    });

    test('combines series by carrying each one forward', () {
      final store = McHistoryStore.inMemory({
        'cf': [
          _point(DateTime(2026, 9, 1), 100),
          _point(DateTime(2026, 9, 3), 130),
        ],
        // Modrinth only starts on the 2nd; the combined line must not dip on
        // the day it joined.
        'mr': [_point(DateTime(2026, 9, 2), 50)],
      });

      final combined = store.combined(['cf', 'mr']);
      expect(combined.map((p) => p.downloads).toList(), [100, 150, 180]);
    });

    test('reports how long it has been collecting', () {
      final store = McHistoryStore.inMemory({
        'cf': [
          _point(DateTime(2026, 9, 1), 10),
          _point(DateTime(2026, 9, 5), 20),
        ],
      });

      expect(store.daySpan('cf'), 5);
      expect(store.firstDay('cf'), DateTime(2026, 9, 1));
      expect(store.daySpan('missing'), 0);
    });

    test('forgetting a platform drops its projects too', () {
      final store = McHistoryStore.inMemory();
      store.record('cf', downloads: 1);
      store.record('project:curseforge:99', downloads: 1);
      store.record('modrinth', downloads: 1);

      store.forget('cf');
      store.forgetWithPrefix('project:curseforge:');

      expect(store.seriesKeys, ['modrinth']);
    });

    test(
        'combined deltas do not spike when a platform starts tracking with '
        'an existing total', () {
      final store = McHistoryStore.inMemory({
        'mr': [
          _point(DateTime(2026, 9, 1), 1000),
          _point(DateTime(2026, 9, 2), 1010),
          _point(DateTime(2026, 9, 3), 1025),
        ],
        // CurseForge already has 120,000 downloads by the time luma starts
        // tracking it, on day 2. Summing totals first and diffing would
        // show that whole figure as a "gain" on day 2.
        'cf': [
          _point(DateTime(2026, 9, 2), 120000),
          _point(DateTime(2026, 9, 3), 120050),
        ],
      });

      final deltas = store.combinedDeltas(['mr', 'cf']);

      // Day 2 only carries Modrinth's own gain — CurseForge needs a second
      // point of its own before it can report any change at all.
      expect(deltas[0].day, DateTime(2026, 9, 2));
      expect(deltas[0].gained, 10);
      // Day 3 finally adds CurseForge's own day-over-day gain (50).
      expect(deltas[1].day, DateTime(2026, 9, 3));
      expect(deltas[1].gained, 15 + 50);
    });
  });

  group('project gains by day', () {
    McProject project(McPlatform platform, String id, String name) =>
        McProject(
          platform: platform,
          id: id,
          slug: id,
          name: name,
          url: 'https://example.invalid/$id',
        );

    test('buckets each project\'s own gains by day, highest first', () {
      final store = McHistoryStore.inMemory();
      for (final (i, total) in [10, 20, 45].indexed) {
        store.record(
          'project:curseforge:a',
          downloads: total,
          at: DateTime(2026, 9, 1).add(Duration(days: i)),
        );
      }
      // Starts a day later than 'a', so it has no delta at all on day 2.
      for (final (i, total) in [1000, 1005].indexed) {
        store.record(
          'project:curseforge:b',
          downloads: total,
          at: DateTime(2026, 9, 2).add(Duration(days: i)),
        );
      }
      // Never moves, so it must never show up in a breakdown.
      store.record('project:curseforge:c', downloads: 5, at: DateTime(2026, 9, 2));
      store.record('project:curseforge:c', downloads: 5, at: DateTime(2026, 9, 3));

      final projects = [
        project(McPlatform.curseforge, 'a', 'Alloy'),
        project(McPlatform.curseforge, 'b', 'Bits'),
        project(McPlatform.curseforge, 'c', 'Calm'),
      ];

      final byDay = projectGainsByDay(store, projects);

      expect(
        byDay[DateTime(2026, 9, 2)]!.map((g) => g.name),
        ['Alloy'],
      );
      expect(
        byDay[DateTime(2026, 9, 3)]!
            .map((g) => (g.name, g.gained))
            .toList(),
        [('Alloy', 25), ('Bits', 5)],
      );
    });
  });

  group('snapshot', () {
    McProject project(
      McPlatform platform, {
      int downloads = 0,
      int followers = 0,
      int views = 0,
    }) =>
        McProject(
          platform: platform,
          id: '$platform-$downloads',
          slug: 's',
          name: 'n',
          url: 'u',
          downloads: downloads,
          followers: followers,
          views: views,
        );

    test('combines only the two mod platforms', () {
      final snapshot = McSnapshot.empty
          .withResult(McPlatformResult(
            platform: McPlatform.curseforge,
            state: McPlatformState.ok,
            projects: [project(McPlatform.curseforge, downloads: 100)],
          ))
          .withResult(McPlatformResult(
            platform: McPlatform.modrinth,
            state: McPlatformState.ok,
            projects: [project(McPlatform.modrinth, downloads: 40)],
          ))
          .withResult(McPlatformResult(
            platform: McPlatform.planetMinecraft,
            state: McPlatformState.ok,
            projects: [project(McPlatform.planetMinecraft, views: 900)],
          ));

      // PMC is deliberately excluded: its rounded, view-based counts would
      // corrupt a downloads total.
      expect(snapshot.combinedDownloads, 140);
      expect(snapshot.combinedProjects.length, 2);
      expect(snapshot.pmcProjects.length, 1);
    });

    test('an unconfigured platform is not a failed one', () {
      final snapshot = McSnapshot.empty;
      expect(
        snapshot.resultFor(McPlatform.modrinth).state,
        McPlatformState.notConfigured,
      );
    });

    test('round-trips through JSON', () {
      final original = McSnapshot.empty
          .withResult(McPlatformResult(
            platform: McPlatform.modrinth,
            state: McPlatformState.ok,
            creator: const McCreator(
              platform: McPlatform.modrinth,
              handle: 'octo',
            ),
            projects: [project(McPlatform.modrinth, downloads: 7)],
          ))
          .withFetchedAt(DateTime(2026, 9, 1));

      final restored =
          McSnapshot.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.combinedDownloads, 7);
      expect(restored.resultFor(McPlatform.modrinth).creator!.handle, 'octo');
      expect(restored.fetchedAt, DateTime(2026, 9, 1));
    });
  });

  group('ModrinthApi', () {
    test('reads a creator and their projects', () async {
      final api = ModrinthApi(
        client: MockClient((request) async {
          if (request.url.path == '/v2/user/octo') {
            return http.Response(
              jsonEncode({
                'id': 'abc123',
                'username': 'octo',
                'name': 'Octo',
                'avatar_url': 'https://example.invalid/a.png',
              }),
              200,
            );
          }
          if (request.url.path == '/v2/user/abc123/projects') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'p1',
                  'slug': 'sodium',
                  'title': 'Sodium',
                  'description': 'Fast',
                  'project_type': 'mod',
                  'downloads': 900,
                  'followers': 30,
                  'updated': '2026-08-01T00:00:00Z',
                },
                {
                  'id': 'p2',
                  'slug': 'iris',
                  'title': 'Iris',
                  'project_type': 'mod',
                  'downloads': 2000,
                  'followers': 10,
                },
              ]),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final result = await api.fetchCreator('octo');
      expect(result.creator.handle, 'octo');
      expect(result.creator.url, 'https://modrinth.com/user/octo');
      // Sorted by downloads, so the headline project is first.
      expect(result.projects.first.name, 'Iris');
      expect(result.projects.first.url, 'https://modrinth.com/mod/iris');
      expect(result.projects.last.followers, 30);
    });

    test('says which user is missing rather than failing generically',
        () async {
      final api = ModrinthApi(
        client: MockClient((_) async => http.Response('{}', 404)),
      );
      await expectLater(
        api.fetchCreator('nobody'),
        throwsA(isA<McApiException>()
            .having((e) => e.message, 'message', contains('no user'))),
      );
    });

    test('analytics failure is soft — totals must survive it', () async {
      final api = ModrinthApi(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      final history =
          await api.fetchDownloadHistory(['p1'], token: 'mrp_x');
      expect(history, isEmpty);
    });

    test('buckets analytics timestamps into days', () async {
      final noon = DateTime(2026, 8, 30, 12).millisecondsSinceEpoch ~/ 1000;
      final evening = DateTime(2026, 8, 30, 20).millisecondsSinceEpoch ~/ 1000;
      final api = ModrinthApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'p1': {'$noon': 5, '$evening': 7},
              }),
              200,
            )),
      );

      final history = await api.fetchDownloadHistory(['p1'], token: 'mrp_x');
      expect(history['p1']!.length, 1);
      expect(history['p1']![DateTime(2026, 8, 30)], 12);
    });

    test('asks for nothing without a token', () async {
      var called = false;
      final api = ModrinthApi(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await api.fetchDownloadHistory(['p1'], token: ''), isEmpty);
      expect(called, isFalse);
    });
  });

  group('CurseForgeApi', () {
    test('sends the key as x-api-key and pages through an author', () async {
      final pages = <int>[];
      final api = CurseForgeApi(
        client: MockClient((request) async {
          expect(request.headers['x-api-key'], 'key123');
          expect(request.url.queryParameters['primaryAuthorId'], '77');
          pages.add(int.parse(request.url.queryParameters['index']!));
          // One full page, then a short one, which ends the walk.
          final full = request.url.queryParameters['index'] == '0';
          return http.Response(
            jsonEncode({
              'data': [
                for (var i = 0; i < (full ? 50 : 2); i++)
                  {
                    'id': full ? i : 1000 + i,
                    'name': 'Mod $i',
                    'slug': 'mod-$i',
                    'downloadCount': full ? 10 : 5,
                    'thumbsUpCount': 1,
                    'classId': 6,
                    'links': {'websiteUrl': 'https://cf/mod-$i'},
                  },
              ],
            }),
            200,
          );
        }),
      );

      final projects = await api.fetchAuthorProjects('key123', '77');
      expect(pages, [0, 50]);
      expect(projects.length, 52);
      expect(projects.first.kind, 'mod');
      expect(projects.first.platform, McPlatform.curseforge);
    });

    test('explains a rejected key', () async {
      final api = CurseForgeApi(
        client: MockClient((_) async => http.Response('{}', 403)),
      );
      await expectLater(
        api.fetchAuthorProjects('bad', '1'),
        throwsA(isA<McApiException>()
            .having((e) => e.message, 'message', contains('API key'))),
      );
    });

    test('one dead project id does not lose the others', () async {
      final api = CurseForgeApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/mods/404')) {
            return http.Response('{}', 500);
          }
          return http.Response(
            jsonEncode({
              'data': {
                'id': 7,
                'name': 'Good',
                'slug': 'good',
                'downloadCount': 3,
              },
            }),
            200,
          );
        }),
      );

      final projects = await api.fetchProjectsByIds('key', ['404', '7']);
      expect(projects.length, 1);
      expect(projects.single.name, 'Good');
    });

    test('pulls a slug out of a project URL', () {
      expect(
        CurseForgeApi.slugFromInput(
            'https://www.curseforge.com/minecraft/mc-mods/jei'),
        'jei',
      );
      expect(CurseForgeApi.slugFromInput('jei'), 'jei');
      expect(CurseForgeApi.slugFromInput('  some-mod '), 'some-mod');
      expect(CurseForgeApi.slugFromInput('not a slug!'), isNull);
      expect(CurseForgeApi.slugFromInput(''), isNull);
    });
  });

  group('credentials', () {
    test('CurseForge needs a key and something to look up', () {
      const keyOnly = McCredentials(curseforgeApiKey: 'k');
      expect(keyOnly.hasCurseforge, isFalse);
      expect(keyOnly.curseforgeNeedsTarget, isTrue);

      const withAuthor =
          McCredentials(curseforgeApiKey: 'k', curseforgeAuthorId: '9');
      expect(withAuthor.hasCurseforge, isTrue);

      const withProjects =
          McCredentials(curseforgeApiKey: 'k', curseforgeProjectIds: ['1']);
      expect(withProjects.hasCurseforge, isTrue);
    });

    test('Modrinth and PMC need only a username', () {
      expect(const McCredentials(modrinthUsername: 'octo').hasModrinth, isTrue);
      expect(const McCredentials(pmcUsername: 'octo').hasPmc, isTrue);
      expect(const McCredentials().hasAny, isFalse);
    });

    test('round-trips through JSON without inventing empty fields', () {
      const original = McCredentials(
        modrinthUsername: 'octo',
        curseforgeApiKey: 'k',
        curseforgeProjectIds: ['1', '2'],
      );
      final restored = McCredentials.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      expect(restored.modrinthUsername, 'octo');
      expect(restored.curseforgeProjectIds, ['1', '2']);
      expect(restored.pmcUsername, isNull);
    });
  });
}

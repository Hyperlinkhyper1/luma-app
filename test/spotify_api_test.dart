import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_api.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_models.dart';

void main() {
  test(
    'reads Spotify rankings and recent tracks with the requested scopes',
    () async {
      final requests = <Uri>[];
      final api = SpotifyApi(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer access-token');
          requests.add(request.url);
          switch (request.url.path) {
            case '/v1/me/top/artists':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'name': 'Artist A',
                      'genres': ['indie', 'rock'],
                      'images': [
                        {'url': 'https://example.com/artist.png'},
                      ],
                      'external_urls': {
                        'spotify': 'https://open.spotify.com/artist/1',
                      },
                    },
                  ],
                }),
                200,
              );
            case '/v1/me/top/tracks':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'name': 'Song A',
                      'artists': [
                        {'name': 'Artist A'},
                      ],
                      'album': {
                        'images': [
                          {'url': 'https://example.com/album.png'},
                        ],
                      },
                    },
                  ],
                }),
                200,
              );
            case '/v1/me/player/recently-played':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'played_at': '2026-09-28T12:00:00Z',
                      'track': {
                        'name': 'Song B',
                        'duration_ms': 180000,
                        'artists': [
                          {'name': 'Artist B'},
                        ],
                      },
                    },
                  ],
                }),
                200,
              );
            case '/v1/me/tracks':
              return http.Response('{"total":42,"items":[]}', 200);
            default:
              return http.Response('{}', 404);
          }
        }),
      );
      addTearDown(api.dispose);

      expect(
        (await api.top('access-token', 'artists', 'short_term')).single.name,
        'Artist A',
      );
      expect(
        (await api.top('access-token', 'tracks', 'short_term')).single.subtitle,
        'Artist A',
      );
      expect((await api.recent('access-token')).single.name, 'Song B');
      final older = await api.recentPage(
        'access-token',
        before: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
      expect(older.plays.single.durationMs, 180000);
      expect(requests[3].queryParameters['before'], '1000');
      expect(await api.total('access-token', '/me/tracks'), 42);
      expect(requests[0].queryParameters['time_range'], 'short_term');
      expect(requests[0].queryParameters['limit'], '10');
      expect(requests[2].queryParameters['limit'], '50');
    },
  );

  test('listening total sums minutes once and survives serialization', () {
    SpotifyPlay play(int minute, int durationMs) => SpotifyPlay(
      item: const SpotifyItem(name: 'Song', subtitle: 'Artist'),
      playedAt: DateTime.utc(2026, 9, 28, 12, minute),
      durationMs: durationMs,
    );
    final first = SpotifyListeningTotal.empty.add([
      play(0, 180000),
      play(5, 120000),
    ]);
    expect(first.minutes, 5);
    final restored = SpotifyListeningTotal.fromJson(
      jsonDecode(jsonEncode(first.toJson())) as Map<String, dynamic>,
    );
    expect(restored.add([play(0, 180000), play(5, 120000)]).minutes, 5);
    expect(restored.add([play(10, 60000)]).minutes, 6);
  });
}

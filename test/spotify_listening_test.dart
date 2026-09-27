import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_api.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_models.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_repository.dart';
import 'package:luma/security/secure_secret_store.dart';

void main() {
  test(
    'listening minutes persist and repeated refreshes do not count twice',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'luma-spotify-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final secrets = SecureSecretStore(storageDir: directory);
      final plays = <Map<String, dynamic>>[
        _play('2026-09-28T12:05:00Z', 120000),
        _play('2026-09-28T12:00:00Z', 180000),
      ];
      var paged = false;
      var olderPageRequests = 0;

      SpotifyRepository repository() =>
          SpotifyRepository(
            secrets: secrets,
            api: SpotifyApi(
              client: MockClient((request) async {
                switch (request.url.path) {
                  case '/v1/me':
                    return http.Response(
                      '{"id":"test-user","display_name":"Listener"}',
                      200,
                    );
                  case '/v1/me/player/recently-played':
                    if (paged) {
                      if (request.url.queryParameters['before'] == null) {
                        return http.Response(
                          jsonEncode({
                            'items': [
                              _play('2026-09-28T12:20:00Z', 120000),
                              _play('2026-09-28T12:15:00Z', 60000),
                            ],
                            'next':
                                'https://api.spotify.com/v1/me/player/recently-played?before=1',
                          }),
                          200,
                        );
                      }
                      olderPageRequests++;
                      return http.Response(
                        jsonEncode({
                          'items': [_play('2026-09-28T12:10:00Z', 60000)],
                          'next': null,
                        }),
                        200,
                      );
                    }
                    return http.Response(
                      jsonEncode({'items': plays, 'next': null}),
                      200,
                    );
                  case '/v1/me/top/artists':
                  case '/v1/me/top/tracks':
                    return http.Response('{"items":[]}', 200);
                  case '/v1/me/tracks':
                  case '/v1/me/playlists':
                    return http.Response('{"total":0}', 200);
                  default:
                    return http.Response('{}', 404);
                }
              }),
            ),
          )..seedForTest(
            SpotifySnapshot(
              displayName: 'Listener',
              profileUrl: null,
              followers: 0,
              topArtists: const [],
              topTracks: const [],
              recentTracks: const [],
              savedTracks: 0,
              playlists: 0,
              fetchedAt: DateTime.now(),
              timeRange: 'medium_term',
            ),
          );

      final first = repository();
      await first.refresh();
      expect(first.listeningTotal.minutes, 5);
      await first.refresh();
      expect(first.listeningTotal.minutes, 5);
      first.dispose();

      final second = repository();
      await second.refresh();
      expect(second.listeningTotal.minutes, 5);
      plays.insert(0, _play('2026-09-28T12:10:00Z', 60000));
      await second.refresh();
      expect(second.listeningTotal.minutes, 6);
      paged = true;
      await second.refresh();
      expect(second.listeningTotal.minutes, 9);
      expect(olderPageRequests, 1);
      second.dispose();
    },
  );
}

Map<String, dynamic> _play(String playedAt, int durationMs) => {
  'played_at': playedAt,
  'track': {
    'name': 'Song',
    'artists': [
      {'name': 'Artist'},
    ],
    'duration_ms': durationMs,
  },
};

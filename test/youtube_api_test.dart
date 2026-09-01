import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_api.dart';

void main() {
  group('YoutubeApi.fetchChannel', () {
    test('parses identity, counts and the uploads playlist id', () async {
      final api = YoutubeApi(
        client: MockClient((request) async {
          expect(request.url.path, '/youtube/v3/channels');
          expect(request.url.queryParameters['mine'], 'true');
          expect(request.headers['Authorization'], 'Bearer token-1');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'UC123',
                  'snippet': {
                    'title': 'Test Channel',
                    'publishedAt': '2020-01-01T00:00:00Z',
                    'thumbnails': {
                      'high': {'url': 'https://example.invalid/a.png'},
                    },
                  },
                  'statistics': {
                    'subscriberCount': '1234',
                    'viewCount': '56789',
                    'videoCount': '42',
                    'hiddenSubscriberCount': false,
                  },
                  'contentDetails': {
                    'relatedPlaylists': {'uploads': 'UUxyz'},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final channel = await api.fetchChannel('token-1');
      expect(channel.id, 'UC123');
      expect(channel.title, 'Test Channel');
      expect(channel.subscriberCount, 1234);
      expect(channel.viewCount, 56789);
      expect(channel.videoCount, 42);
      expect(channel.uploadsPlaylistId, 'UUxyz');
      expect(channel.hiddenSubscriberCount, isFalse);
    });

    test('a channel-less Google account is a clear error, not a crash',
        () async {
      final api = YoutubeApi(
        client: MockClient(
            (_) async => http.Response(jsonEncode({'items': []}), 200)),
      );

      await expectLater(
        api.fetchChannel('token-1'),
        throwsA(isA<YoutubeApiException>()),
      );
    });

    test('a 401 is flagged as needing reauth, not just any failure',
        () async {
      final api = YoutubeApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'message': 'Invalid Credentials'},
              }),
              401,
            )),
      );

      try {
        await api.fetchChannel('expired-token');
        fail('expected a YoutubeApiException');
      } on YoutubeApiException catch (e) {
        expect(e.needsReauth, isTrue);
        expect(e.statusCode, 401);
        expect(e.message, contains('Invalid Credentials'));
      }
    });

    test('a 403 is not flagged as needing reauth', () async {
      final api = YoutubeApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'message': 'API not enabled'},
              }),
              403,
            )),
      );

      try {
        await api.fetchChannel('token-1');
        fail('expected a YoutubeApiException');
      } on YoutubeApiException catch (e) {
        expect(e.needsReauth, isFalse);
        expect(e.statusCode, 403);
      }
    });
  });

  group('YoutubeApi.fetchRecentVideos', () {
    test('resolves playlist items to full video stats, newest first',
        () async {
      final api = YoutubeApi(
        client: MockClient((request) async {
          if (request.url.path == '/youtube/v3/playlistItems') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'contentDetails': {'videoId': 'vid-old'}
                  },
                  {
                    'contentDetails': {'videoId': 'vid-new'}
                  },
                ],
              }),
              200,
            );
          }
          expect(request.url.path, '/youtube/v3/videos');
          expect(request.url.queryParameters['id'], 'vid-old,vid-new');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'vid-old',
                  'snippet': {
                    'title': 'Older video',
                    'publishedAt': '2026-01-01T00:00:00Z',
                    'thumbnails': {
                      'medium': {'url': 'https://example.invalid/old.png'}
                    },
                  },
                  'statistics': {
                    'viewCount': '10',
                    'likeCount': '1',
                    'commentCount': '0',
                  },
                },
                {
                  'id': 'vid-new',
                  'snippet': {
                    'title': 'Newer video',
                    'publishedAt': '2026-06-01T00:00:00Z',
                    'thumbnails': {
                      'medium': {'url': 'https://example.invalid/new.png'}
                    },
                  },
                  'statistics': {
                    'viewCount': '99',
                    'likeCount': '9',
                    'commentCount': '2',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final videos = await api.fetchRecentVideos('token-1', 'UUxyz');
      expect(videos.map((v) => v.id), ['vid-new', 'vid-old']);
      expect(videos.first.viewCount, 99);
      expect(videos.first.likeCount, 9);
    });

    test('an empty playlist never reaches the videos endpoint', () async {
      final api = YoutubeApi(
        client: MockClient((request) async {
          expect(request.url.path, '/youtube/v3/playlistItems');
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );

      final videos = await api.fetchRecentVideos('token-1', 'UUxyz');
      expect(videos, isEmpty);
    });
  });

  group('YoutubeApi analytics', () {
    test('fetchAnalyticsTimeSeries turns Analytics API rows into points',
        () async {
      final api = YoutubeApi(
        client: MockClient((request) async {
          expect(request.url.host, 'youtubeanalytics.googleapis.com');
          expect(request.url.queryParameters['ids'], 'channel==MINE');
          expect(request.url.queryParameters['dimensions'], 'day');
          return http.Response(
            jsonEncode({
              'rows': [
                ['2026-08-01', 100, 500, 120, 5, 1],
                ['2026-08-02', 150, 700, 130, 8, 2],
              ],
            }),
            200,
          );
        }),
      );

      final points = await api.fetchAnalyticsTimeSeries('token-1', days: 7);
      expect(points, hasLength(2));
      expect(points.first.day, DateTime.parse('2026-08-01'));
      expect(points.first.views, 100);
      expect(points.first.estimatedMinutesWatched, 500);
      expect(points.first.averageViewDuration, 120);
      expect(points.first.subscribersGained, 5);
      expect(points.first.subscribersLost, 1);
      expect(points.last.views, 150);
    });

    test('fetchTrafficSources turns Analytics API rows into sources',
        () async {
      final api = YoutubeApi(
        client: MockClient((request) async {
          expect(
            request.url.queryParameters['dimensions'],
            'insightTrafficSourceType',
          );
          return http.Response(
            jsonEncode({
              'rows': [
                ['YT_SEARCH', 300],
                ['EXT_URL', 100],
              ],
            }),
            200,
          );
        }),
      );

      final sources = await api.fetchTrafficSources('token-1', days: 7);
      expect(sources, hasLength(2));
      expect(sources.first.type, 'YT_SEARCH');
      expect(sources.first.label, 'YouTube search');
      expect(sources.first.views, 300);
      expect(sources.last.label, 'External sites');
    });
  });
}

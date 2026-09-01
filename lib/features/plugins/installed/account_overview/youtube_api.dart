import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'youtube_models.dart';

/// Raised when Google answers with something the UI needs to explain rather
/// than swallow — a rejected token, a disabled API, an exhausted quota.
class YoutubeApiException implements Exception {
  YoutubeApiException(this.message, {this.statusCode, this.needsReauth = false});

  final String message;
  final int? statusCode;

  /// True on a 401 — the access token was rejected and a refresh (or a full
  /// reconnect if the refresh token itself is dead) is the fix, not a retry.
  final bool needsReauth;

  @override
  String toString() => message;
}

/// A thin, read-only client for the Data API and Analytics API surfaces this
/// plugin shows.
///
/// Every request goes straight from this device to Google with the user's
/// own OAuth token. Nothing here touches a luma server, so `GatedServerClient`
/// and `SyncService.serverReady` are not in play — the gate exists to keep
/// luma-server traffic behind an approved account, and there is no
/// luma-server traffic here.
class YoutubeApi {
  YoutubeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _dataApi = 'https://www.googleapis.com/youtube/v3';
  static const _analyticsApi =
      'https://youtubeanalytics.googleapis.com/v2/reports';

  void dispose() => _client.close();

  Future<dynamic> _get(String accessToken, Uri uri) async {
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw _describe(response);
  }

  YoutubeApiException _describe(http.Response response) {
    String? message;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['message'] is String) {
          message = error['message'] as String;
        }
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      return YoutubeApiException(
        message ?? 'Google rejected the access token.',
        statusCode: 401,
        needsReauth: true,
      );
    }
    if (response.statusCode == 403) {
      return YoutubeApiException(
        message ??
            'Google refused the request. The channel may not have analytics '
                'available yet, or the API may need enabling in your Google '
                'Cloud project.',
        statusCode: 403,
      );
    }
    return YoutubeApiException(
      message ?? 'Google returned HTTP ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  /// Verifies the token and resolves the channel behind it.
  Future<YoutubeChannelSnapshot> fetchChannel(String accessToken) async {
    final uri = Uri.parse('$_dataApi/channels').replace(queryParameters: {
      'part': 'snippet,statistics,contentDetails',
      'mine': 'true',
    });
    final body = await _get(accessToken, uri) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];
    if (items.isEmpty) {
      throw YoutubeApiException('This Google account has no YouTube channel.');
    }
    return YoutubeChannelSnapshot.fromApi(items.first as Map<String, dynamic>);
  }

  /// The channel's most recent uploads, newest first.
  Future<List<YoutubeVideoStat>> fetchRecentVideos(
    String accessToken,
    String uploadsPlaylistId, {
    int maxVideos = 25,
  }) async {
    final playlistUri =
        Uri.parse('$_dataApi/playlistItems').replace(queryParameters: {
      'part': 'contentDetails',
      'playlistId': uploadsPlaylistId,
      'maxResults': '$maxVideos',
    });
    final playlistBody = await _get(accessToken, playlistUri) as Map<String, dynamic>;
    final items = playlistBody['items'] as List<dynamic>? ?? const [];
    final videoIds = items
        .map((e) =>
            (e as Map<String, dynamic>)['contentDetails']?['videoId'] as String?)
        .whereType<String>()
        .toList();
    if (videoIds.isEmpty) return const [];

    final videosUri = Uri.parse('$_dataApi/videos').replace(queryParameters: {
      'part': 'snippet,statistics',
      'id': videoIds.join(','),
    });
    final videosBody = await _get(accessToken, videosUri) as Map<String, dynamic>;
    final videoItems = videosBody['items'] as List<dynamic>? ?? const [];
    final videos =
        videoItems.cast<Map<String, dynamic>>().map(YoutubeVideoStat.fromApi).toList();

    // The Data API does not promise to echo the requested `id` order back,
    // so this re-sorts by publish date rather than trust response order.
    videos.sort((a, b) {
      final at = a.publishedAt, bt = b.publishedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return videos;
  }

  /// The channel-wide time series behind the Analytics tab: views, watch
  /// time, average view duration and subscriber churn, one point per day.
  Future<List<YoutubeAnalyticsPoint>> fetchAnalyticsTimeSeries(
    String accessToken, {
    int days = 90,
  }) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    final uri = Uri.parse(_analyticsApi).replace(queryParameters: {
      'ids': 'channel==MINE',
      'startDate': _isoDate(start),
      'endDate': _isoDate(end),
      'metrics': 'views,estimatedMinutesWatched,averageViewDuration,'
          'subscribersGained,subscribersLost',
      'dimensions': 'day',
      'sort': 'day',
    });
    final body = await _get(accessToken, uri) as Map<String, dynamic>;
    final rows = body['rows'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows.cast<List<dynamic>>())
        YoutubeAnalyticsPoint(
          day: DateTime.parse(row[0] as String),
          views: (row[1] as num).toInt(),
          estimatedMinutesWatched: (row[2] as num).toInt(),
          averageViewDuration: (row[3] as num).toInt(),
          subscribersGained: (row[4] as num).toInt(),
          subscribersLost: (row[5] as num).toInt(),
        ),
    ];
  }

  /// Where views came from over the same window, for the traffic-source
  /// breakdown.
  Future<List<YoutubeTrafficSource>> fetchTrafficSources(
    String accessToken, {
    int days = 90,
  }) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    final uri = Uri.parse(_analyticsApi).replace(queryParameters: {
      'ids': 'channel==MINE',
      'startDate': _isoDate(start),
      'endDate': _isoDate(end),
      'metrics': 'views',
      'dimensions': 'insightTrafficSourceType',
      'sort': '-views',
    });
    final body = await _get(accessToken, uri) as Map<String, dynamic>;
    final rows = body['rows'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows.cast<List<dynamic>>())
        YoutubeTrafficSource(
            type: row[0] as String, views: (row[1] as num).toInt()),
    ];
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

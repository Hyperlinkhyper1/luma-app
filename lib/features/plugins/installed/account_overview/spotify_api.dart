import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../l10n/current_l.dart';
import 'spotify_models.dart';

class SpotifyApiException implements Exception {
  const SpotifyApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class SpotifyApi {
  SpotifyApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  void dispose() => _client.close();

  Future<Map<String, dynamic>> get(
    String token,
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.https('api.spotify.com', '/v1$path', query);
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    String? detail;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      detail = (body['error'] as Map?)?['message'] as String?;
    } catch (_) {}
    throw SpotifyApiException(
      detail ?? currentL.accountOverviewSpotifyHttpError('${response.statusCode}'),
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> profile(String token) => get(token, '/me');

  Future<List<SpotifyItem>> top(String token, String type, String range) async {
    final body = await get(token, '/me/top/$type', {
      'time_range': range,
      'limit': '10',
    });
    final items = (body['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    return type == 'artists'
        ? items.map(SpotifyItem.artist).toList()
        : items.map(SpotifyItem.track).toList();
  }

  Future<SpotifyRecentPage> recentPage(String token, {DateTime? before}) async {
    final body = await get(token, '/me/player/recently-played', {
      'limit': '50',
      if (before != null) 'before': '${before.millisecondsSinceEpoch}',
    });
    final plays = (body['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(
          (item) =>
              item['track'] is Map<String, dynamic> &&
              item['played_at'] is String,
        )
        .map(SpotifyPlay.fromJson)
        .toList();
    return SpotifyRecentPage(plays: plays, hasMore: body['next'] != null);
  }

  Future<List<SpotifyItem>> recent(String token) async => (await recentPage(
    token,
  )).plays.take(10).map((play) => play.item).toList();

  Future<int?> total(String token, String path) async {
    final body = await get(token, path, {'limit': '1'});
    return (body['total'] as num?)?.toInt();
  }
}

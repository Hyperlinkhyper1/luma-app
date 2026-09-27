import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../sync/server_access.dart';
import '../../sync/sync_service.dart';

/// Searches through the signed-in Luma server; no search request is sent while
/// the server access gate is closed.
class WebSearchClient {
  factory WebSearchClient({
    required SyncService syncService,
    http.Client? httpClient,
  }) => WebSearchClient._(syncService, httpClient);

  WebSearchClient._(this._syncService, this._httpClient);

  final SyncService _syncService;
  final http.Client? _httpClient;

  bool get available =>
      _syncService.serverReady &&
      _syncService.serverUrl != null &&
      _syncService.authToken != null;

  Future<Map<String, dynamic>> search(String query) async {
    if (!available) {
      return {
        'status': 'unavailable',
        'message': 'Web search needs an approved Luma account.',
      };
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return {
        'status': 'needs_info',
        'message': 'Missing query; ask the user and retry.',
      };
    }
    if (trimmed.length > 200) {
      return {'status': 'error', 'message': 'Search query is too long.'};
    }
    final base = Uri.parse(_syncService.serverUrl!);
    final url = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/api/v1/ai/web-search',
    );
    final client = GatedServerClient(inner: _httpClient);
    try {
      final response = await client
          .post(
            url,
            headers: {
              'Authorization': 'Bearer ${_syncService.authToken!}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'query': trimmed}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return {
          'status': 'unavailable',
          'message': 'Web search is unavailable (${response.statusCode}).',
        };
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['results'] is! List) {
        return {
          'status': 'unavailable',
          'message': 'Web search returned an invalid response.',
        };
      }
      return {
        'status': 'ok',
        'results': [
          for (final item in (data['results'] as List).whereType<Map>().take(5))
            {
              'title': (item['title'] as String? ?? '').substring(
                0,
                (item['title'] as String? ?? '').length.clamp(0, 120),
              ),
              'url': item['url'] as String? ?? '',
              'snippet': (item['snippet'] as String? ?? '').substring(
                0,
                (item['snippet'] as String? ?? '').length.clamp(0, 320),
              ),
            },
        ],
      };
    } catch (_) {
      return {
        'status': 'unavailable',
        'message': 'Could not reach web search.',
      };
    } finally {
      client.close();
    }
  }
}

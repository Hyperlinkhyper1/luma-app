import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../sync/server_access.dart';
import 'ai_model.dart';

/// Raised for every non-successful response from the catalogue endpoint.
class AiCatalogApiException implements Exception {
  const AiCatalogApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// What a fetch produced: either a fresh catalogue, or nothing because the
/// server confirmed the copy we already hold is current.
class AiCatalogFetchResult {
  const AiCatalogFetchResult({this.catalog, this.etag, this.unchanged = false});

  final AiCatalog? catalog;
  final String? etag;

  /// True when the server answered 304 — the cached catalogue is still good
  /// and no payload came down the wire.
  final bool unchanged;
}

/// Reads the AI model leaderboard from the luma server.
///
/// The catalogue is public, identical for every account and carries nothing a
/// user typed, so unlike the sync collections it isn't encrypted — but it
/// still goes through [GatedServerClient], because nothing in this app may
/// reach a luma server before the account is approved.
///
/// The payload is a few hundred kilobytes and only changes when the operator
/// refreshes it, so every request carries the cached ETag as `If-None-Match`;
/// the usual answer is a 304 costing a round trip and no body.
class AiCatalogApi {
  AiCatalogApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = GatedServerClient(inner: client);

  final String baseUrl;
  String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 45);

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<AiCatalogFetchResult> fetch({String? knownEtag}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/ai-models'),
      headers: {
        if (token case final value?) 'Authorization': 'Bearer $value',
        'If-None-Match': ?knownEtag,
      },
    ).timeout(_timeout);

    if (response.statusCode == 304) {
      return AiCatalogFetchResult(etag: knownEtag, unchanged: true);
    }
    if (response.statusCode != 200) {
      throw AiCatalogApiException(
        response.statusCode,
        'The server could not return the model leaderboard '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const AiCatalogApiException(200, 'Malformed leaderboard response.');
    }
    return AiCatalogFetchResult(
      catalog: AiCatalog.fromJson(decoded),
      etag: response.headers['etag'],
    );
  }

  void close() => _client.close();
}

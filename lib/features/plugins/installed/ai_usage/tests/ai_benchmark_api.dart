import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../../sync/server_access.dart';
import 'ai_benchmark.dart';

/// Raised for every non-successful response from the benchmark endpoints.
class AiBenchmarkApiException implements Exception {
  const AiBenchmarkApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// What a manifest fetch produced: either a fresh roster, or nothing because
/// the server confirmed the copy we already hold is current.
class AiBenchmarkFetchResult {
  const AiBenchmarkFetchResult(
      {this.manifest, this.etag, this.unchanged = false});

  final AiBenchmarkManifest? manifest;
  final String? etag;

  /// True when the server answered 304 — the cached roster is still good and
  /// no payload came down the wire.
  final bool unchanged;
}

/// Reads the AI benchmark scenes from the luma server.
///
/// Everything here goes through [GatedServerClient], because nothing in this
/// app may reach a luma server before the account is approved. Scenes only
/// ever download on demand — opening a model — never up front, so the Tests
/// tab stays cheap to visit.
class AiBenchmarkApi {
  AiBenchmarkApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = GatedServerClient(inner: client);

  final String baseUrl;
  String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 60);

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<AiBenchmarkFetchResult> fetchManifest({String? knownEtag}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/ai-benchmarks'),
      headers: {
        if (token case final value?) 'Authorization': 'Bearer $value',
        'If-None-Match': ?knownEtag,
      },
    ).timeout(_timeout);

    if (response.statusCode == 304) {
      return AiBenchmarkFetchResult(etag: knownEtag, unchanged: true);
    }
    if (response.statusCode != 200) {
      throw AiBenchmarkApiException(
        response.statusCode,
        'The server could not return the benchmark list '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const AiBenchmarkApiException(200, 'Malformed benchmark response.');
    }
    return AiBenchmarkFetchResult(
      manifest: AiBenchmarkManifest.fromJson(decoded),
      etag: response.headers['etag'],
    );
  }

  /// Downloads one scene's HTML. The caller verifies the bytes against the
  /// manifest's hash before trusting them.
  Future<Uint8List> fetchScene(String id) =>
      _fetchBytes('scene', id, 'benchmark scene');

  /// Downloads one scene's PNG preview, or null when it has none (404).
  Future<Uint8List?> fetchPreview(String id) async {
    try {
      return await _fetchBytes('preview', id, 'benchmark preview');
    } on AiBenchmarkApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Downloads generic tile artwork, e.g. `pagoda-preview.png`.
  Future<Uint8List?> fetchFallback(String file) async {
    try {
      return await _fetchBytes('fallback', file, 'benchmark artwork');
    } on AiBenchmarkApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Uint8List> _fetchBytes(
      String route, String id, String what) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/ai-benchmarks/$route/$id'),
      headers: {if (token case final value?) 'Authorization': 'Bearer $value'},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw AiBenchmarkApiException(
        response.statusCode,
        'The server could not return the $what (HTTP ${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  void close() => _client.close();
}

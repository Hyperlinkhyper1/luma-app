import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A small, bounded adapter for the JSON search API of a private SearXNG
/// instance. The URL is operator configured and never supplied by the caller.
class WebSearch {
  WebSearch(this.baseUrl, {HttpClient? client})
      : _client = client ?? HttpClient();

  final Uri baseUrl;
  final HttpClient _client;

  Future<List<Map<String, String>>> search(String query) async {
    final path = '${baseUrl.path.replaceAll(RegExp(r'/+$'), '')}/search';
    final uri = baseUrl.replace(path: path);
    final request =
        await _client.postUrl(uri).timeout(const Duration(seconds: 5));
    request.followRedirects = false;
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write(
        'q=${Uri.encodeQueryComponent(query)}&format=json&categories=general');
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw HttpException('SearXNG returned ${response.statusCode}');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      if (bytes.length + chunk.length > 256 * 1024) {
        throw const FormatException('Search response is too large');
      }
      bytes.add(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map || decoded['results'] is! List) {
      throw const FormatException('Invalid search response');
    }
    final results = <Map<String, String>>[];
    for (final raw in decoded['results'] as List) {
      if (raw is! Map) continue;
      final title = _short(raw['title'], 120);
      final url = raw['url'];
      final snippet = _short(raw['content'], 320);
      if (title.isEmpty ||
          url is! String ||
          url.length > 500 ||
          !_isWebUrl(url)) {
        continue;
      }
      results.add({'title': title, 'url': url, 'snippet': snippet});
      if (results.length == 5) break;
    }
    return results;
  }

  static bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _short(Object? value, int limit) {
    final text = value is String
        ? value
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
        : '';
    return text.length <= limit ? text : '${text.substring(0, limit)}…';
  }

  void close() => _client.close(force: true);
}

import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/web_search.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer upstream;

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await upstream.close(force: true);
  });

  test('sends a POST query and bounds SearXNG results', () async {
    final search = WebSearch(Uri.parse('http://127.0.0.1:${upstream.port}'));
    final requestFuture = upstream.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/search');
      final body = await utf8.decoder.bind(request).join();
      expect(body, contains('q=Dart+search'));
      expect(body, contains('format=json'));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'results': [
          {'title': 'bad', 'url': 'javascript:alert(1)', 'content': 'ignored'},
          for (var i = 0; i < 7; i++)
            {
              'title': '<b>Result $i</b>',
              'url': 'https://example.com/$i',
              'content': List.filled(500, 'a').join(),
            },
        ],
      }));
      await request.response.close();
    });
    final results = await search.search('Dart search');
    await requestFuture;
    search.close();
    expect(results, hasLength(5));
    expect(results.first['title'], 'Result 0');
    expect(results.first['snippet']!.length, lessThanOrEqualTo(321));
  });
}

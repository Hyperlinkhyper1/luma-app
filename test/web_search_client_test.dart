import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/chat/web_search_client.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_service.dart';

class _Sync extends SyncService {
  _Sync({required this.approvedReady}) : super(collections: const []);

  final bool approvedReady;

  @override
  bool get serverReady => approvedReady;

  @override
  String? get serverUrl => 'https://sync.example.com';

  @override
  String? get authToken => 'account-token';
}

void main() {
  setUp(() => ServerAccessGate.instance.setApproved(false));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  test('does not send a search without an approved account', () async {
    var requests = 0;
    final search = WebSearchClient(
      syncService: _Sync(approvedReady: false),
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    expect(search.available, isFalse);
    expect((await search.search('weather'))['status'], 'unavailable');
    expect(requests, 0);
  });

  test('posts a bounded query through the gated server client', () async {
    ServerAccessGate.instance.setApproved(true);
    final search = WebSearchClient(
      syncService: _Sync(approvedReady: true),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/ai/web-search');
        expect(request.url.query, isEmpty);
        expect(request.headers['authorization'], 'Bearer account-token');
        expect(jsonDecode(request.body)['query'], 'weather Amsterdam');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'title': 'Forecast',
                'url': 'https://example.com',
                'snippet': 'Sunny',
              },
            ],
          }),
          200,
        );
      }),
    );
    final result = await search.search('  weather Amsterdam  ');
    expect(result['status'], 'ok');
    expect((result['results'] as List).single['url'], 'https://example.com');
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/groceries/groceries_api.dart';
import 'package:luma/sync/server_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => ServerAccessGate.instance.setApproved(true));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  test(
    'all-store searches and categories request only supported markets',
    () async {
      final requests = <Uri>[];
      final api = GroceriesApi(
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response('{"products":[],"categories":[]}', 200);
        }),
      );
      addTearDown(api.dispose);

      await api.search();
      await api.search(marketSlugs: []);
      await api.fetchCategories();
      await api.fetchCategories(marketSlugs: []);
      for (final request in requests) {
        expect(request.queryParameters['market'], 'jumbo,ah,lidl,hoogvliet');
      }
      await api.search(marketSlugs: ['ah']);
      expect(requests.last.queryParameters['market'], 'ah');
    },
  );

  test('legacy servers cannot return Picnic markets or products', () async {
    final markets = [
      {'id': 1, 'slug': 'ah', 'name': 'Albert Heijn'},
      {'id': 2, 'slug': 'picnic', 'name': 'Picnic'},
    ];
    final api = GroceriesApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'markets': markets,
            'products': [
              for (final market in markets)
                {'id': market['id'], 'name': 'Milk', 'market': market},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);

    expect((await api.fetchMarkets()).map((m) => m.slug), ['ah']);
    expect((await api.search()).map((p) => p.market.slug), ['ah']);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_api.dart';

const steamId = '76561198012345678';
Map<String, Object> description(String id, String type, String name, {int? marketable}) => {
  'classid': id,
  'instanceid': '0',
  'market_hash_name': name,
  'icon_url': 'icon-$id',
  'marketable': ?marketable,
  'tags': [
    {'category': 'Type', 'internal_name': type},
  ],
};
Map<String, String> asset(String id, String classId) => {
  'assetid': id, 'classid': classId, 'instanceid': '0',
};

void main() {
  test('resolves IDs and profile URLs locally, and vanity via Steam XML', () async {
    final api = Cs2InventoryApi(client: MockClient((request) async {
      expect(request.url.host, 'steamcommunity.com');
      expect(request.url.path, '/id/player-name/');
      expect(request.url.queryParameters['xml'], '1');
      return http.Response('<profile><steamID64>$steamId</steamID64></profile>', 200);
    }));
    expect(await api.resolveSteamId(steamId), steamId);
    expect(await api.resolveSteamId('https://steamcommunity.com/profiles/$steamId/'), steamId);
    expect(await api.resolveSteamId('https://steamcommunity.com/id/player-name'), steamId);
    expect(await api.resolveSteamId('player-name'), steamId);
    await expectLater(api.resolveSteamId('https://steamcommunity.com.evil.test/id/player-name'), throwsA(isA<Cs2InventoryException>()));
    await expectLater(api.resolveSteamId('https://evil.test@steamcommunity.com/id/player-name'), throwsA(isA<Cs2InventoryException>()));
    api.close();
  });

  test('paginates, links class and instance, and skips unmarketable items', () async {
    var calls = 0;
    final api = Cs2InventoryApi(client: MockClient((request) async {
      calls++;
      expect(request.url.path, '/inventory/$steamId/730/2');
      if (calls == 1) {
        return http.Response(jsonEncode({
          'success': 1,
          'assets': [asset('1', 'a'), asset('2', 'b'), asset('4', 'd')],
          'descriptions': [
            description('a', 'CSGO_Type_Rifle', 'AK-47 | Redline (Field-Tested)'),
            description('b', 'CSGO_Type_Collectible', 'Service Medal', marketable: 0),
            description('d', 'CSGO_Type_WeaponCase', 'Kilowatt Case', marketable: 1),
          ],
          'more_items': 1,
          'last_assetid': '2',
        }), 200);
      }
      expect(request.url.queryParameters['start_assetid'], '2');
      return http.Response(jsonEncode({
        'success': 1,
        'assets': [asset('3', 'c')],
        'descriptions': [description('c', 'Type_Hands', '★ Sport Gloves | Hedge Maze (Field-Tested)')],
      }), 200, headers: {'content-type': 'application/json'});
    }));
    final items = await api.fetchInventory(steamId);
    expect(items.map((i) => i.assetId), ['1', '4', '3']);
    expect(items[1].marketHashName, 'Kilowatt Case');
    expect(items.first.marketHashName, 'AK-47 | Redline (Field-Tested)');
    expect(items.first.iconUrl, 'https://community.cloudflare.steamstatic.com/economy/image/icon-a');
    expect(calls, 2);
    api.close();
  });

  test('accepts genuinely empty inventories', () async {
    final api = Cs2InventoryApi(client: MockClient((_) async => http.Response('{"success":1,"total_inventory_count":0}', 200)));
    expect(await api.fetchInventory(steamId), isEmpty);
    api.close();
  });

  test('does not return a partial snapshot after a later page fails', () async {
    var calls = 0;
    final api = Cs2InventoryApi(client: MockClient((_) async {
      calls++;
      if (calls > 1) return http.Response('limited', 429);
      return http.Response(jsonEncode({
        'success': 1,
        'assets': [asset('1', 'a')],
        'descriptions': [description('a', 'CSGO_Type_Rifle', 'AK-47 | Redline')],
        'more_items': 1,
        'last_assetid': '1',
      }), 200);
    }));
    await expectLater(api.fetchInventory(steamId), throwsA(isA<Cs2InventoryException>().having((e) => e.status, 'status', 429)));
    api.close();
  });

  test('rejects malformed descriptions and looping pagination', () async {
    final broken = Cs2InventoryApi(client: MockClient((_) async => http.Response(jsonEncode({
      'success': 1, 'assets': [asset('1', 'a')], 'descriptions': [],
    }), 200)));
    await expectLater(broken.fetchInventory(steamId), throwsA(isA<Cs2InventoryException>()));
    broken.close();
    final looping = Cs2InventoryApi(client: MockClient((_) async => http.Response(jsonEncode({
      'success': 1, 'assets': [], 'descriptions': [], 'more_items': 1, 'last_assetid': '1',
    }), 200)));
    await expectLater(looping.fetchInventory(steamId), throwsA(isA<Cs2InventoryException>()));
    looping.close();
  });

  test('counts the trade-protected items Steam leaves out of the listing', () async {
    final api = Cs2InventoryApi(client: MockClient((_) async => http.Response(jsonEncode({
      'success': 1,
      'total_inventory_count': 4,
      'assets': [asset('1', 'a'), asset('2', 'b')],
      'descriptions': [
        description('a', 'CSGO_Type_Rifle', 'AK-47 | Redline (Field-Tested)', marketable: 1),
        description('b', 'CSGO_Type_Collectible', 'Service Medal'),
      ],
    }), 200)));
    final snapshot = await api.fetchSnapshot(steamId);
    expect(snapshot.items.map((item) => item.assetId), ['1']);
    expect(snapshot.hiddenCount, 2);
    api.close();
  });

  test('reads through a loader and keeps owner-only protected items', () async {
    final api = Cs2InventoryApi(client: MockClient((_) async => fail('used the plain client')));
    final snapshot = await api.fetchSnapshot(steamId, loader: (uri) async {
      expect(uri.path, '/inventory/$steamId/730/2');
      return Cs2InventoryPage(200, jsonEncode({
        'success': 1,
        'total_inventory_count': 2,
        'assets': [asset('1', 'a'), asset('2', 'p')],
        'descriptions': [
          {...description('a', 'CSGO_Type_Rifle', 'AK-47 | Redline (Field-Tested)'), 'tradable': 1},
          {
            ...description('p', 'CSGO_Tool_Sticker', 'Sticker | Protected', marketable: 0),
            'tradable': 0,
            'owner_descriptions': [
              {'type': 'html', 'value': 'Trade Protected'},
            ],
          },
        ],
      }));
    });
    expect(snapshot.items.map((item) => item.assetId), ['1', '2']);
    expect(snapshot.items.map((item) => item.tradeLocked), [false, true]);
    expect(snapshot.hiddenCount, 0);
    api.close();
  });
}

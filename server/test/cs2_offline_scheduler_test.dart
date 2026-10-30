import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/cs2_offline_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:test/test.dart';

void main() {
  test('later listings get checked across rate-limited scheduled sweeps',
      () async {
    final dir = await Directory.systemTemp.createTemp('cs2_offline_schedule');
    final accounts = await Store.open(dir.path);
    final store = await Cs2OfflineStore.open(dir.path);
    final filler = base64Encode(List.filled(32, 1));
    accounts.usersById['u1'] = StoredUser(
      id: 'u1',
      email: 'user@example.com',
      authHash: filler,
      authSalt: filler,
      kdfSalt: filler,
      kdfIterations: 200000,
      quotaBytes: 1024,
      createdAtMs: 0,
      planId: 'nova',
    );
    final config = <String, dynamic>{
      'enabled': true,
      'intervalHours': 1,
      'items': [
        {'marketHashName': 'A'},
        {'marketHashName': 'B'},
        {'marketHashName': 'C'},
      ],
      'points': <Map<String, dynamic>>[],
    };
    await store.put('u1', config);
    final requests = <String>[];
    final scheduler = Cs2OfflineScheduler(
      accounts: accounts,
      store: store,
      requestSpacing: Duration.zero,
      fetchPrice: (uri) async {
        requests.add(uri.queryParameters['market_hash_name']!);
        return requests.length.isEven
            ? (statusCode: 429, body: '')
            : (
                statusCode: 200,
                body: '{"success":true,"lowest_price":"\$1.00"}'
              );
      },
    );
    try {
      for (var i = 0; i < 3; i++) {
        final now = DateTime.utc(2026, 1, 1, i + 1);
        config['nextCheckAtMs'] = now.millisecondsSinceEpoch;
        await scheduler.runDue(now: now);
      }
      expect(requests, ['A', 'B', 'B', 'C', 'C', 'A']);
      expect((config['items'] as List).map((item) => item['marketHashName']),
          ['A', 'B', 'C']);
      expect((config['points'] as List).map((point) => point['marketHashName']),
          ['A', 'B', 'C']);
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('the bulk price file prices every listing it covers without Steam, '
      'and an unchanged price records nothing', () async {
    final dir = await Directory.systemTemp.createTemp('cs2_offline_bulk');
    final accounts = await Store.open(dir.path);
    final store = await Cs2OfflineStore.open(dir.path);
    final filler = base64Encode(List.filled(32, 1));
    accounts.usersById['u1'] = StoredUser(
      id: 'u1',
      email: 'user@example.com',
      authHash: filler,
      authSalt: filler,
      kdfSalt: filler,
      kdfIterations: 200000,
      quotaBytes: 1024,
      createdAtMs: 0,
      planId: 'nova',
    );
    final config = <String, dynamic>{
      'enabled': true,
      'intervalHours': 1,
      'items': [
        for (var i = 0; i < 1500; i++) {'marketHashName': 'Sticker $i'},
        {'marketHashName': 'Not In File'},
      ],
      'points': <Map<String, dynamic>>[],
    };
    await store.put('u1', config);
    final steamRequests = <String>[];
    var bulkRequests = 0;
    final scheduler = Cs2OfflineScheduler(
      accounts: accounts,
      store: store,
      requestSpacing: Duration.zero,
      fetchBulkPrices: (uri) async {
        bulkRequests++;
        expect(uri.host, 'prices.csgotrader.app');
        return (
          statusCode: 200,
          body: jsonEncode({
            for (var i = 0; i < 1500; i++)
              'Sticker $i': {'last_24h': null, 'last_7d': 0.25},
          }),
        );
      },
      fetchPrice: (uri) async {
        steamRequests.add(uri.queryParameters['market_hash_name']!);
        return (
          statusCode: 200,
          body: '{"success":true,"lowest_price":"\$2.00"}'
        );
      },
    );
    try {
      for (var i = 0; i < 2; i++) {
        final now = DateTime.utc(2026, 1, 1, i + 1);
        config['nextCheckAtMs'] = now.millisecondsSinceEpoch;
        await scheduler.runDue(now: now);
      }
      expect(bulkRequests, 1);
      expect(steamRequests, ['Not In File', 'Not In File']);
      final points = config['points'] as List;
      expect(points.where((p) => p['medianCents'] == 25), hasLength(1500));
      expect(points.where((p) => p['marketHashName'] == 'Not In File'),
          hasLength(2));
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });
}

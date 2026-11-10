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
        if (i < 2) {
          expect(config['nextCheckAtMs'],
              now.add(const Duration(minutes: 15)).millisecondsSinceEpoch);
        }
      }
      expect(requests, ['A', 'B', 'B', 'C', 'C']);
      expect((config['items'] as List).map((item) => item['marketHashName']),
          ['A', 'B', 'C']);
      expect((config['points'] as List).map((point) => point['marketHashName']),
          ['A', 'B', 'C']);
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('Orbit catches up an overdue hourly check', () async {
    final dir = await Directory.systemTemp.createTemp('cs2_offline_catchup');
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
      planId: 'orbit',
    );
    final now = DateTime.utc(2026, 1, 1, 12);
    final config = <String, dynamic>{
      'enabled': true,
      'intervalHours': 1,
      'nextCheckAtMs':
          now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      'items': [
        {'marketHashName': 'A'}
      ],
      'points': <Map<String, dynamic>>[],
    };
    await store.put('u1', config);
    final scheduler = Cs2OfflineScheduler(
      accounts: accounts,
      store: store,
      requestSpacing: Duration.zero,
      fetchPrice: (_) async => (
        statusCode: 200,
        body: '{"success":true,"lowest_price":"\$1.00"}',
      ),
    );
    try {
      await scheduler.runDue(now: now);
      expect(config['points'], hasLength(1));
      expect(config['nextCheckAtMs'],
          now.add(const Duration(hours: 1)).millisecondsSinceEpoch);
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('each scheduled sweep fetches a live price for every listing', () async {
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
        {'marketHashName': 'Sticker 0'},
        {'marketHashName': 'Sticker 1'},
      ],
      'points': <Map<String, dynamic>>[],
    };
    await store.put('u1', config);
    final steamRequests = <String>[];
    final scheduler = Cs2OfflineScheduler(
      accounts: accounts,
      store: store,
      requestSpacing: Duration.zero,
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
      expect(
          steamRequests, ['Sticker 0', 'Sticker 1', 'Sticker 0', 'Sticker 1']);
      final points = config['points'] as List;
      expect(points, hasLength(4));
      expect(points.every((p) => p['lowestCents'] == 200), isTrue);
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('shared rate limit pauses all users and resumes with the next user',
      () async {
    final dir = await Directory.systemTemp.createTemp('cs2_offline_fair');
    final accounts = await Store.open(dir.path);
    final store = await Cs2OfflineStore.open(dir.path);
    final filler = base64Encode(List.filled(32, 1));
    final now = DateTime.utc(2026, 1, 1, 12);
    for (final id in ['A', 'B']) {
      accounts.usersById[id] = StoredUser(
        id: id,
        email: '$id@example.com',
        authHash: filler,
        authSalt: filler,
        kdfSalt: filler,
        kdfIterations: 200000,
        quotaBytes: 1024,
        createdAtMs: 0,
        planId: 'nova',
      );
      await store.put(id, {
        'enabled': true,
        'intervalHours': 1,
        'nextCheckAtMs': now.millisecondsSinceEpoch,
        'items': [
          {'marketHashName': id}
        ],
        'points': <Map<String, dynamic>>[],
      });
    }
    final requests = <String>[];
    final scheduler = Cs2OfflineScheduler(
      accounts: accounts,
      store: store,
      requestSpacing: Duration.zero,
      fetchPrice: (uri) async {
        requests.add(uri.queryParameters['market_hash_name']!);
        if (requests.length == 1) return (statusCode: 429, body: '');
        return (
          statusCode: 200,
          body: '{"success":true,"lowest_price":"\$1.00"}'
        );
      },
    );
    try {
      await scheduler.runDue(now: now);
      await scheduler.runDue(now: now.add(const Duration(minutes: 14)));
      expect(requests, ['A']);
      await scheduler.runDue(now: now.add(const Duration(minutes: 15)));
      expect(requests, ['A', 'B', 'A']);
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('long inventories yield to other users and timestamp each response',
      () async {
    final dir = await Directory.systemTemp.createTemp('cs2_offline_batches');
    final accounts = await Store.open(dir.path);
    final store = await Cs2OfflineStore.open(dir.path);
    final filler = base64Encode(List.filled(32, 1));
    final now = DateTime.utc(2026, 1, 1, 12);
    for (final id in ['A', 'B']) {
      accounts.usersById[id] = StoredUser(
        id: id,
        email: '$id@example.com',
        authHash: filler,
        authSalt: filler,
        kdfSalt: filler,
        kdfIterations: 200000,
        quotaBytes: 1024,
        createdAtMs: 0,
        planId: 'nova',
      );
      await store.put(id, {
        'enabled': true,
        'intervalHours': 1,
        'nextCheckAtMs': now.millisecondsSinceEpoch,
        'items': [
          for (var i = 0; i < (id == 'A' ? 11 : 1); i++)
            {'marketHashName': '$id$i'}
        ],
        'points': <Map<String, dynamic>>[],
      });
    }
    final requests = <String>[];
    final scheduler = Cs2OfflineScheduler(
      accounts: accounts,
      store: store,
      requestSpacing: Duration.zero,
      fetchPrice: (uri) async {
        requests.add(uri.queryParameters['market_hash_name']!);
        await Future<void>.delayed(const Duration(milliseconds: 3));
        return (
          statusCode: 200,
          body: '{"success":true,"lowest_price":"\$1.00"}'
        );
      },
    );
    try {
      await scheduler.runDue(now: now);
      expect(requests, [...List.generate(10, (i) => 'A$i'), 'B0']);
      final firstPoints = store.forUser('A')!['points'] as List;
      expect(firstPoints.last['observedAtMs'],
          greaterThan(firstPoints.first['observedAtMs']));
      await scheduler.runDue(now: now.add(const Duration(seconds: 15)));
      expect(requests.last, 'A10');
      expect(store.forUser('A')!['points'], hasLength(11));
    } finally {
      scheduler.dispose();
      await dir.delete(recursive: true);
    }
  });
}

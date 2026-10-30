import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_bulk_price_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_price_history_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/storage/storage_guard.dart';

class _NoScheduleStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

Future<void> _track(SteamDatabase db, String name, {DateTime? trackedAt}) async {
  await db.addTrackedCs2Item(
    Cs2MarketItemsCompanion.insert(
      marketHashName: name,
      skinId: name,
      displayName: name,
      weaponName: name,
      rarityName: '',
      rarityColor: '#ffffff',
      imageUrl: '',
      trackedAt: trackedAt == null ? const Value.absent() : Value(trackedAt),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => StorageGuardService.instance = _NoScheduleStorageGuard());

  group('bulk price file', () {
    test('takes the freshest window that has a price, in cents', () {
      final prices = parseCs2BulkPrices(
        jsonEncode({
          'Kilowatt Case': {'last_24h': 0.24, 'last_7d': 0.25},
          'Sticker | Crown (Foil)': {'last_24h': null, 'last_7d': 460.43},
          'Dead Listing': {'last_24h': null, 'last_7d': null},
        }),
        updatedAt: DateTime(2026, 10, 30),
      )!;
      expect(prices.cents, {
        'Kilowatt Case': 24,
        'Sticker | Crown (Foil)': 46043,
      });
    });

    test('rejects a body that is not a price map', () {
      expect(parseCs2BulkPrices('[]', updatedAt: DateTime(2026)), isNull);
      expect(parseCs2BulkPrices('nope', updatedAt: DateTime(2026)), isNull);
    });

    test('one download serves repeated lookups within the cache window',
        () async {
      var calls = 0;
      final api = Cs2BulkPriceApi(
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'prices.csgotrader.app');
          return http.Response(
            jsonEncode({'A': {'last_24h': 1.5}}),
            200,
            headers: {'last-modified': 'Fri, 30 Oct 2026 13:25:18 GMT'},
          );
        }),
      );
      final first = await api.fetch();
      await api.fetch();
      expect(calls, 1);
      expect(first!.cents['A'], 150);
      expect(first.updatedAt.toUtc(), DateTime.utc(2026, 10, 30, 13, 25, 18));
      api.close();
    });
  });

  group('Steam price history', () {
    test('reads the action response and the page-embedded shape alike', () {
      final inner = {
        'ecurrency': 3,
        'prices': [
          {'time': 1793361600, 'price_median': 28.23, 'purchases': 4},
          {'time': 1392940800, 'price_median': 37.24, 'purchases': 198},
        ],
      };
      for (final body in [jsonEncode({'data': inner}), jsonEncode(inner)]) {
        final parsed = parseCs2PriceHistory(body)!;
        expect(parsed.ecurrency, 3);
        expect(parsed.prices.map((p) => p.$2), [37.24, 28.23]);
      }
    });

    test('converts to USD cents and refuses unknown currencies', () async {
      Future<List<Cs2HistoryPoint>?> fetchWith(int ecurrency) =>
          Cs2PriceHistoryApi(
            client: MockClient((request) async {
              expect(request.url.path, '/market/actions');
              expect(request.url.queryParameters['q'], 'QueryPriceHistory');
              expect(jsonDecode(request.url.queryParameters['qp']!),
                  [730, 'Kilowatt Case']);
              expect(request.headers['x-valve-request-type'], 'queryAction');
              return http.Response(
                jsonEncode({
                  'data': {
                    'ecurrency': ecurrency,
                    'prices': [
                      {'time': 1793361600, 'price_median': 10.0},
                    ],
                  },
                }),
                200,
              );
            }),
            usdPerUnit: (currency) async => currency == 'EUR' ? 1.1 : null,
          ).fetch('Kilowatt Case');
      expect((await fetchWith(3))!.single.cents, 1100);
      expect((await fetchWith(1))!.single.cents, 1000);
      expect(await fetchWith(99), isNull);
    });

    test('a 429 is raised so the caller backs off instead of skipping',
        () async {
      final api = Cs2PriceHistoryApi(
        client: MockClient((_) async => http.Response('', 429)),
        usdPerUnit: (_) async => 1,
      );
      await expectLater(
        api.fetch('A'),
        throwsA(isA<Cs2MarketApiException>()
            .having((e) => e.status, 'status', 429)),
      );
    });

    test('downsampling keeps recent detail and thins the past', () {
      final now = DateTime(2026, 10, 30, 12);
      final hourly = [
        for (var h = 0; h < 24 * 400; h++)
          Cs2HistoryPoint(at: now.subtract(Duration(hours: h)), cents: 1000),
      ];
      final thin = downsampleCs2History(hourly, now);
      expect(thin.length, lessThan(260));
      expect(thin.first.at.isAfter(now.subtract(const Duration(days: 366))),
          isTrue);
      final lastDay =
          thin.where((p) => now.difference(p.at) <= const Duration(days: 1));
      expect(lastDay.length, greaterThanOrEqualTo(23));
      expect(thin.every((p) => p.cents == 1000), isTrue);
    });
  });

  group('repository', () {
    late SteamDatabase db;
    setUp(() => db = SteamDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a sweep prices covered listings from the bulk file and asks Steam '
        'only for the rest', () async {
      for (final name in ['Covered', 'Missing']) {
        await _track(db, name);
      }
      final steamAsked = <String>[];
      final repository = Cs2MarketRepository(
        db,
        api: Cs2MarketApi(
          client: MockClient((request) async {
            steamAsked.add(request.url.queryParameters['market_hash_name']!);
            return http.Response(
                '{"success":true,"lowest_price":"\$2.00"}', 200);
          }),
        ),
        bulkPrices: Cs2BulkPriceApi(
          client: MockClient((_) async => http.Response(
                jsonEncode({'Covered': {'last_24h': 0.5}}),
                200,
              )),
        ),
        fetchOfflineSnapshot: () async => null,
        priceCheckSpacing: Duration.zero,
      );
      addTearDown(repository.dispose);
      await repository.refreshAllPrices();
      expect(steamAsked, ['Missing']);
      final items = {
        for (final item in await db.allCs2Items()) item.marketHashName: item,
      };
      expect(items['Covered']!.lastMedianCents, 50);
      expect(items['Missing']!.lastLowestCents, 200);

      // The same bulk file again adds no duplicate reading.
      await repository.refreshAllPrices();
      final points = await db.allCs2PricePoints();
      expect(points.where((p) => p.marketHashName == 'Covered'), hasLength(1));
    });

    test('backfill adds Steam history from before tracking, once', () async {
      final trackedAt = DateTime.now().subtract(const Duration(hours: 1));
      await _track(db, 'A', trackedAt: trackedAt);
      await db.recordCs2Prices({'A': 900}, observedAt: trackedAt);
      var calls = 0;
      final repository = Cs2MarketRepository(
        db,
        historyApi: Cs2PriceHistoryApi(
          client: MockClient((_) async {
            calls++;
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            return http.Response(
              jsonEncode({
                'data': {
                  'ecurrency': 1,
                  'prices': [
                    for (var d = 0; d < 20; d++)
                      {'time': now - d * 86400, 'price_median': 8.0},
                  ],
                },
              }),
              200,
            );
          }),
          usdPerUnit: (_) async => 1,
        ),
        fetchOfflineSnapshot: () async => null,
        historyBackfillSpacing: Duration.zero,
      );
      addTearDown(repository.dispose);
      await repository.backfillHistory();
      final points = (await db.allCs2PricePoints())
        ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
      expect(points.length, greaterThan(10));
      expect(points.last.medianCents, 900);
      // Nothing at or after the first local reading is touched.
      expect(
        points
            .where((p) => p.medianCents == 800)
            .every((p) => p.observedAt.isBefore(trackedAt)),
        isTrue,
      );
      await repository.backfillHistory();
      expect(calls, 1);
    });
  });
}

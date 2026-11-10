import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_bulk_price_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup catches up a listing last checked two hours ago', () async {
    final storageGuard = StorageGuardService();
    StorageGuardService.instance = storageGuard;
    final db = SteamDatabase(NativeDatabase.memory());
    await db.addTrackedCs2Item(
      Cs2MarketItemsCompanion.insert(
        marketHashName: 'A',
        skinId: 'A',
        displayName: 'A',
        weaponName: 'A',
        rarityName: '',
        rarityColor: '#ffffff',
        imageUrl: '',
      ),
    );
    await db.recordCs2Prices({
      'A': 100,
    }, observedAt: DateTime.now().subtract(const Duration(hours: 2)));
    final checked = Completer<void>();
    final repository = Cs2MarketRepository(
      db,
      api: Cs2MarketApi(
        client: MockClient((_) async {
          checked.complete();
          return http.Response('{"success":true,"lowest_price":"\$2.00"}', 200);
        }),
      ),
      priceCheckSpacing: Duration.zero,
    );
    addTearDown(() async {
      repository.dispose();
      storageGuard.dispose();
      await db.close();
    });
    await checked.future.timeout(const Duration(seconds: 2));
    await db
        .watchTrackedCs2Items()
        .firstWhere((items) => items.single.lastLowestCents == 200)
        .timeout(const Duration(seconds: 2));
  });

  test(
    'scheduled sweep checks live prices even when bulk covers every skin',
    () async {
      final storageGuard = StorageGuardService();
      StorageGuardService.instance = storageGuard;
      addTearDown(storageGuard.dispose);
      final db = SteamDatabase(NativeDatabase.memory());
      for (final name in ['A', 'B']) {
        await db.addTrackedCs2Item(
          Cs2MarketItemsCompanion.insert(
            marketHashName: name,
            skinId: name,
            displayName: name,
            weaponName: name,
            rarityName: '',
            rarityColor: '#ffffff',
            imageUrl: '',
          ),
        );
      }
      final requested = <String>[];
      final repository = Cs2MarketRepository(
        db,
        api: Cs2MarketApi(
          client: MockClient((request) async {
            requested.add(request.url.queryParameters['market_hash_name']!);
            return http.Response(
              '{"success":true,"lowest_price":"\$2.00"}',
              200,
            );
          }),
        ),
        bulkPrices: Cs2BulkPriceApi(
          client: MockClient(
            (_) async =>
                http.Response('{"A":{"last_24h":1},"B":{"last_24h":1}}', 200),
          ),
        ),
        fetchOfflineSnapshot: () async => null,
        priceCheckSpacing: Duration.zero,
      );
      addTearDown(() async {
        repository.dispose();
        await db.close();
      });

      await repository.refreshAllPrices(scheduled: true);
      expect(requested, unorderedEquals(['A', 'B']));
      expect(
        (await db.allCs2Items()).map((item) => item.lastLowestCents),
        everyElement(200),
      );
    },
  );

  test(
    'an unavailable Steam price does not replace the last reading',
    () async {
      final db = SteamDatabase(NativeDatabase.memory());
      await db.addTrackedCs2Item(
        Cs2MarketItemsCompanion.insert(
          marketHashName: 'A',
          skinId: 'A',
          displayName: 'A',
          weaponName: 'A',
          rarityName: '',
          rarityColor: '#ffffff',
          imageUrl: '',
        ),
      );
      final old = DateTime.now().subtract(const Duration(hours: 2));
      await db.recordCs2Prices({'A': 100}, observedAt: old);
      final repository = Cs2MarketRepository(
        db,
        api: Cs2MarketApi(
          client: MockClient(
            (_) async => http.Response('{"success":false}', 200),
          ),
        ),
        fetchOfflineSnapshot: () async => null,
        priceCheckSpacing: Duration.zero,
      );
      addTearDown(() async {
        repository.dispose();
        await db.close();
      });
      await repository.refreshAllPrices(scheduled: true);
      final item = (await db.allCs2Items()).single;
      expect(item.lastMedianCents, 100);
      expect(
        item.priceFetchedAt!.difference(old).abs(),
        lessThan(const Duration(seconds: 1)),
      );
      expect(await db.allCs2PricePoints(), hasLength(1));
    },
  );

  test('a rate-limited sweep resumes and checks every listing', () async {
    final db = SteamDatabase(NativeDatabase.memory());
    for (final name in ['A', 'B']) {
      await db.addTrackedCs2Item(
        Cs2MarketItemsCompanion.insert(
          marketHashName: name,
          skinId: name,
          displayName: name,
          weaponName: name,
          rarityName: '',
          rarityColor: '#ffffff',
          imageUrl: '',
        ),
      );
    }
    var requests = 0;
    final api = Cs2MarketApi(
      client: MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response('', 429);
        return http.Response('{"success":true,"lowest_price":"\$1.00"}', 200);
      }),
    );
    final repository = Cs2MarketRepository(
      db,
      api: api,
      fetchOfflineSnapshot: () async => null,
      priceCheckSpacing: Duration.zero,
      priceRateLimitRetryDelay: Duration.zero,
    );
    addTearDown(() async {
      repository.dispose();
      await db.close();
    });
    await repository.refreshAllPrices();
    expect(requests, 3);
    expect(
      (await db.allCs2Items()).every((item) => item.priceFetchedAt != null),
      isTrue,
    );
  });

  test(
    'cancel interrupts a rate-limit wait without sending another request',
    () async {
      final db = SteamDatabase(NativeDatabase.memory());
      await db.addTrackedCs2Item(
        Cs2MarketItemsCompanion.insert(
          marketHashName: 'A',
          skinId: 'a',
          displayName: 'A',
          weaponName: 'A',
          rarityName: '',
          rarityColor: '#ffffff',
          imageUrl: '',
        ),
      );
      var requests = 0;
      final api = Cs2MarketApi(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 429);
        }),
      );
      final repository = Cs2MarketRepository(
        db,
        api: api,
        fetchOfflineSnapshot: () async => null,
        priceRateLimitRetryDelay: const Duration(hours: 1),
      );
      addTearDown(() async {
        repository.dispose();
        await db.close();
      });
      repository.addListener(() {
        if (repository.priceRateLimitWaiting) repository.cancelPriceRefresh();
      });
      await repository.refreshAllPrices().timeout(const Duration(seconds: 2));
      expect(requests, 1);
      expect(repository.refreshingPrices, isFalse);
      expect(repository.priceRateLimitWaiting, isFalse);
    },
  );

  test(
    'later sweeps prioritize listings left unpriced after a rate limit',
    () async {
      final db = SteamDatabase(NativeDatabase.memory());
      for (final name in ['A', 'B']) {
        await db.addTrackedCs2Item(
          Cs2MarketItemsCompanion.insert(
            marketHashName: name,
            skinId: name,
            displayName: name,
            weaponName: name,
            rarityName: '',
            rarityColor: '#ffffff',
            imageUrl: '',
          ),
        );
      }
      final requested = <String>[];
      var rateLimited = true;
      final api = Cs2MarketApi(
        client: MockClient((request) async {
          final name = request.url.queryParameters['market_hash_name']!;
          requested.add(name);
          if (name == 'B' && rateLimited) return http.Response('', 429);
          return http.Response('{"success":true,"lowest_price":"\$1.00"}', 200);
        }),
      );
      final repository = Cs2MarketRepository(
        db,
        api: api,
        fetchOfflineSnapshot: () async => null,
        priceCheckSpacing: Duration.zero,
        priceRateLimitRetryDelay: Duration.zero,
      );
      addTearDown(() async {
        repository.dispose();
        await db.close();
      });
      await repository.refreshAllPrices();
      expect(requested, ['A', 'B', 'B', 'B', 'B']);
      // Steam kept refusing: the sweep rests and resumes by itself rather
      // than leaving an error for the user to deal with.
      expect(repository.error, isNull);
      expect(repository.priceSweepPausedUntil, isNotNull);
      rateLimited = false;
      requested.clear();
      await repository.refreshAllPrices();
      expect(requested, ['B', 'A']);
      expect(
        (await db.allCs2Items()).every((item) => item.priceFetchedAt != null),
        isTrue,
      );
    },
  );

  test('dispose interrupts a pending rate-limit wait', () async {
    final db = SteamDatabase(NativeDatabase.memory());
    await db.addTrackedCs2Item(
      Cs2MarketItemsCompanion.insert(
        marketHashName: 'A',
        skinId: 'a',
        displayName: 'A',
        weaponName: 'A',
        rarityName: '',
        rarityColor: '#ffffff',
        imageUrl: '',
      ),
    );
    var requests = 0;
    final api = Cs2MarketApi(
      client: MockClient((_) async {
        requests++;
        return http.Response('', 429);
      }),
    );
    final repository = Cs2MarketRepository(
      db,
      api: api,
      fetchOfflineSnapshot: () async => null,
      priceRateLimitRetryDelay: const Duration(hours: 1),
    );
    addTearDown(db.close);
    repository.addListener(() {
      if (repository.priceRateLimitWaiting) {
        scheduleMicrotask(repository.dispose);
      }
    });
    await repository.refreshAllPrices().timeout(const Duration(seconds: 2));
    expect(requests, 1);
  });
}

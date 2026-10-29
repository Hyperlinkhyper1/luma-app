import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(repository.error, isNotNull);
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

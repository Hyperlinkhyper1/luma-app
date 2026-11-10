import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_controller.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_purchase_history_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_steam_session.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/storage/storage_guard.dart';

const _id = '76561198012345678';
const _otherId = '76561198000000000';
const _hash = 'AK-47 | Redline (Field-Tested)';
const _time = 1794000000;

class _Session implements Cs2SteamSession {
  _Session(this.loader);

  final Future<Cs2InventoryPage> Function(Uri) loader;
  final requests = <Uri>[];
  String? who = _id;

  @override
  Future<String?> signedInSteamId() async => who;

  @override
  Future<Cs2InventoryPage> load(Uri uri) {
    requests.add(uri);
    return loader(uri);
  }

  @override
  Future<void> signOut() async => who = null;
}

class _NoScheduleStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

Map<String, Object?> _purchase(
  String assetId, {
  int amount = 100,
  int fee = 15,
  int currency = 2001,
  String purchaser = _id,
  Map<String, Object?> assetOverrides = const {},
  Map<String, Object?> overrides = const {},
}) => {
  'steamid_purchaser': purchaser,
  'paid_amount': amount,
  'paid_fee': fee,
  'currencyid': '$currency',
  'asset': {
    'appid': 730,
    'contextid': '2',
    'id': 'old-$assetId',
    'new_id': assetId,
    'new_contextid': '2',
    'amount': '1',
    ...assetOverrides,
  },
  ...overrides,
};

Cs2InventoryPage _page(
  Map<String, Map<String, Object?>> purchases, {
  int start = 0,
  int? total,
  int? pageSize,
  Map<String, int> eventTypes = const {},
}) => Cs2InventoryPage(
  200,
  jsonEncode({
    'success': true,
    'start': start,
    'pagesize': pageSize ?? purchases.length,
    'total_count': total ?? start + purchases.length,
    'events': [
      for (final key in purchases.keys)
        {
          'listingid': 'listing-$key',
          'purchaseid': key,
          'event_type': eventTypes[key] ?? 4,
          'time_event': _time,
        },
    ],
    'purchases': {
      for (final entry in purchases.entries)
        'listing-${entry.key}_${entry.key}': entry.value,
    },
    'listings': {
      for (final key in purchases.keys)
        'listing-$key': {'currencyid': 2008, 'original_price': 9999},
    },
  }),
);

Cs2PurchaseHistoryApi _api({Future<double?> Function(String)? rate}) =>
    Cs2PurchaseHistoryApi(
      usdPerUnit: rate ?? (_) async => null,
      pageSpacing: Duration.zero,
    );

Future<void> _add(SteamDatabase db, String assetId, {String steamId = _id}) =>
    db.addImportedCs2Item(
      Cs2MarketItemsCompanion.insert(
        marketHashName: _hash,
        skinId: 'redline',
        displayName: 'AK-47 | Redline',
        weaponName: 'AK-47',
        rarityName: 'Classified',
        rarityColor: '#d32ce6',
        imageUrl: '',
      ),
      '$steamId:$assetId',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => StorageGuardService.instance = _NoScheduleStorageGuard());

  test(
    'reads all needed pages, buyer fees, purchase dates and buyer currency',
    () async {
      final currencies = <String>[];
      final session = _Session((uri) async {
        expect(uri.host, 'steamcommunity.com');
        expect(uri.path, '/market/myhistory/render/');
        expect(uri.queryParameters['norender'], '1');
        return uri.queryParameters['start'] == '0'
            ? _page(
                {
                  'sold': _purchase('sold'),
                  'a': _purchase('a', currency: 2003),
                },
                total: 20,
                eventTypes: {'sold': 3},
              )
            : _page(
                {'b': _purchase('b', amount: 200, fee: 30, currency: 2003)},
                start: 2,
                total: 20,
              );
      });
      final pages =
          await _api(
                rate: (code) async {
                  currencies.add(code);
                  return code == 'EUR' ? 1.2 : null;
                },
              )
              .fetch(
                steamId: _id,
                session: session,
                assets: {'a': _hash, 'b': _hash},
              )
              .toList();
      expect(session.requests.map((uri) => uri.queryParameters['start']), [
        '0',
        '2',
      ]);
      expect(currencies, ['EUR']);
      expect(pages.expand((p) => p).map((p) => p.assetId), ['a', 'b']);
      expect(pages.expand((p) => p).map((p) => p.cents), [138, 276]);
      expect(
        pages.first.single.at,
        DateTime.fromMillisecondsSinceEpoch(_time * 1000, isUtc: true),
      );
    },
  );

  test(
    'does not guess from names, old IDs, sales, other accounts or reversed purchases',
    () async {
      final session = _Session(
        (_) async => _page(
          {
            'valid': _purchase('valid'),
            'wrong-owner': _purchase('wrong-owner', purchaser: _otherId),
            'failed': _purchase('failed', overrides: {'failed': 1}),
            'reversed': _purchase('reversed', overrides: {'needs_rollback': 1}),
            'returned': _purchase('returned', overrides: {'funds_returned': 1}),
            'no-new-id': _purchase(
              'no-new-id',
              assetOverrides: {'new_id': null},
            ),
            'another-game': _purchase(
              'another-game',
              assetOverrides: {'appid': 570},
            ),
            'bundle': _purchase('bundle', assetOverrides: {'amount': '2'}),
            'negative': _purchase('negative', amount: -1),
            'missing-fees': _purchase(
              'missing-fees',
              overrides: {'paid_fee': null},
            ),
            'sold': _purchase('sold'),
          },
          eventTypes: {'sold': 3},
        ),
      );
      final purchases =
          (await _api()
                  .fetch(
                    steamId: _id,
                    session: session,
                    assets: {
                      for (final id in [
                        'valid',
                        'wrong-owner',
                        'failed',
                        'reversed',
                        'returned',
                        'old-no-new-id',
                        'another-game',
                        'bundle',
                        'negative',
                        'missing-fees',
                        'sold',
                      ])
                        id: _hash,
                    },
                  )
                  .toList())
              .expand((p) => p);
      expect(purchases.map((p) => p.assetId), ['valid']);
      expect(purchases.single.cents, 115);
    },
  );

  test(
    'never reads a different account or an inventory with no missing costs',
    () async {
      final session = _Session((_) async => _page({}))..who = _otherId;
      await expectLater(
        _api()
            .fetch(steamId: _id, session: session, assets: {'a': _hash})
            .toList(),
        throwsA(isA<Cs2InventoryException>()),
      );
      expect(session.requests, isEmpty);
      expect(
        await _api().fetch(steamId: _id, session: session, assets: {}).toList(),
        isEmpty,
      );
    },
  );

  for (final response in [
    const Cs2InventoryPage(200, '<html>Sign in</html>'),
    const Cs2InventoryPage(200, '{"success":false}'),
    const Cs2InventoryPage(429, ''),
    const Cs2InventoryPage(
      200,
      '{"success":true,"events":[],"total_count":5,"pagesize":0}',
    ),
  ]) {
    test(
      'reports unavailable or incomplete history ${response.body} ${response.statusCode}',
      () async {
        final session = _Session((_) async => response);
        await expectLater(
          _api()
              .fetch(steamId: _id, session: session, assets: {'a': _hash})
              .toList(),
          throwsA(isA<Cs2InventoryException>()),
        );
      },
    );
  }

  test(
    'keeps successful prices and reports currencies it cannot convert',
    () async {
      final session = _Session(
        (_) async => _page({
          'usd': _purchase('usd'),
          'eur': _purchase('eur', currency: 2003),
          'unknown': _purchase('unknown', currency: 2999),
        }),
      );
      final found = <Cs2Purchase>[];
      await expectLater(() async {
        await for (final page in _api().fetch(
          steamId: _id,
          session: session,
          assets: {'usd': _hash, 'eur': _hash, 'unknown': _hash},
        )) {
          found.addAll(page);
        }
      }(), throwsA(isA<Cs2InventoryException>()));
      expect(found.single.assetId, 'usd');
      expect(found.single.cents, 115);
    },
  );

  group('saved costs', () {
    late SteamDatabase db;
    late Cs2MarketRepository repository;

    setUp(() async {
      db = SteamDatabase(NativeDatabase.memory());
      repository = Cs2MarketRepository(
        db,
        purchaseHistoryApi: _api(),
        fetchOfflineSnapshot: () async => null,
      );
    });

    tearDown(() async {
      repository.dispose();
      await db.close();
    });

    Future<Map<String, Cs2MarketEntry>> entriesByAsset() async {
      final keys = await db.allCs2InventoryAssetKeys();
      return {
        for (final entry in await db.allCs2Entries()) keys[entry.id]!: entry,
      };
    }

    test(
      'separate costs for identical copies feed gain/loss and preserve manual costs',
      () async {
        for (final id in ['a', 'b', 'manual', 'gift']) {
          await _add(db, id);
        }
        await _add(db, 'a', steamId: _otherId);
        final before = await entriesByAsset();
        await db.setCs2EntryStartingPrice(before['$_id:manual']!.id, 999);
        final session = _Session(
          (_) async => _page({
            'a': _purchase('a'),
            'b': _purchase('b', amount: 200, fee: 30),
            'manual': _purchase('manual'),
          }),
        );
        await repository.importPurchaseHistory(_id, session);
        final after = await entriesByAsset();
        expect(after['$_id:a']!.startingPriceCents, 115);
        expect(after['$_id:b']!.startingPriceCents, 230);
        expect(after['$_id:manual']!.startingPriceCents, 999);
        expect(after['$_id:gift']!.startingPriceCents, isNull);
        expect(after['$_otherId:a']!.startingPriceCents, isNull);
        expect(
          after['$_id:a']!.startingPriceAt!.millisecondsSinceEpoch,
          _time * 1000,
        );
        await db.recordCs2Prices({_hash: 300}, observedAt: DateTime.now());
        final item = (await db.allCs2Items()).single;
        expect(
          item.lastMedianCents! - after['$_id:a']!.startingPriceCents!,
          185,
        );
        final totalCost = after.values
            .map((e) => e.startingPriceCents)
            .whereType<int>()
            .fold(0, (a, b) => a + b);
        expect(totalCost, 115 + 230 + 999);
        await repository.importPurchaseHistory(_id, session);
        expect((await entriesByAsset())['$_id:a'], after['$_id:a']);
        expect(await db.allCs2Entries(), hasLength(5));
      },
    );

    test(
      'a manual edit during a request wins over the imported purchase',
      () async {
        await _add(db, 'a');
        final entry = (await db.allCs2Entries()).single;
        final session = _Session((_) async {
          await db.setCs2EntryStartingPrice(entry.id, 500);
          return _page({'a': _purchase('a')});
        });
        await repository.importPurchaseHistory(_id, session);
        expect((await db.allCs2Entries()).single.startingPriceCents, 500);
      },
    );

    test('a later rate limit keeps prices from earlier pages', () async {
      await _add(db, 'a');
      await _add(db, 'b');
      final session = _Session(
        (uri) async => uri.queryParameters['start'] == '0'
            ? _page({'a': _purchase('a')}, total: 2)
            : const Cs2InventoryPage(429, ''),
      );
      await expectLater(
        repository.importPurchaseHistory(_id, session),
        throwsA(isA<Cs2InventoryException>()),
      );
      final entries = await entriesByAsset();
      expect(entries['$_id:a']!.startingPriceCents, 115);
      expect(entries['$_id:b']!.startingPriceCents, isNull);
    });

    test(
      'cancelling a history read prevents applying an in-flight response',
      () async {
        await _add(db, 'a');
        var cancelled = false;
        final session = _Session((_) async {
          cancelled = true;
          return _page({'a': _purchase('a')});
        });
        await repository.importPurchaseHistory(
          _id,
          session,
          isCancelled: () => cancelled,
        );
        expect((await db.allCs2Entries()).single.startingPriceCents, isNull);
      },
    );
  });

  test(
    'sign-in, refresh and startup import history; public reads never do',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cs2_purchase_controller',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.json');
      const inventory =
          '{"success":1,"assets":[],"descriptions":[],"total_inventory_count":0}';
      final publicApi = Cs2InventoryApi(
        client: MockClient((_) async => http.Response(inventory, 200)),
      );
      addTearDown(publicApi.close);
      final session = _Session(
        (_) async => const Cs2InventoryPage(200, inventory),
      );
      var imports = 0;
      var inventoryImported = false;
      var failHistory = true;
      Cs2InventoryController build() => Cs2InventoryController(
        api: publicApi,
        profileFile: () async => file,
        refreshInterval: Duration.zero,
        importInventory: (_, _) async => inventoryImported = true,
        importPurchaseHistory: (id, actualSession, cancelled) async {
          expect(inventoryImported, isTrue);
          expect(id, _id);
          expect(actualSession, same(session));
          expect(cancelled(), isFalse);
          imports++;
          if (failHistory) throw const Cs2InventoryException('rate limited');
        },
      )..attachSession(session);
      final controller = build();
      addTearDown(controller.dispose);
      expect(await controller.connect(_id), isTrue);
      expect(imports, 0);
      expect(await controller.signIn(_id), isTrue);
      expect(imports, 1);
      expect(controller.sessionStatus, Cs2SteamSessionStatus.active);
      expect(controller.lastError, isNull);
      expect(controller.purchaseHistoryError, contains('rate limited'));
      failHistory = false;
      expect(await controller.refresh(), isTrue);
      expect(imports, 2);
      expect(controller.purchaseHistoryError, isNull);
      final restarted = build();
      addTearDown(restarted.dispose);
      await restarted.startup();
      expect(imports, 3);
      session.who = _otherId;
      expect(await restarted.refresh(), isTrue);
      expect(imports, 3);
      session.who = null;
      expect(await restarted.refresh(), isTrue);
      expect(imports, 3);
    },
  );
}

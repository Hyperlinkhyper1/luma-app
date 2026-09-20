import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_models.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_price_history.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';

const _redlineJson = {
  'id': 'skin-91a429af4a60',
  'name': 'AK-47 | Redline',
  'weapon': {'id': 'weapon_ak47', 'weapon_id': 7, 'name': 'AK-47'},
  'rarity': {'id': 'rarity_legendary_weapon', 'name': 'Classified', 'color': '#d32ce6'},
  'stattrak': true,
  'souvenir': true,
  'wears': [
    {'id': 'w1', 'name': 'Minimal Wear'},
    {'id': 'w2', 'name': 'Field-Tested'},
  ],
  'collections': [
    {'id': 'collection-set-community-2', 'name': 'The Phoenix Collection'},
  ],
  'crates': [
    {'id': 'crate-4011', 'name': 'Operation Phoenix Weapon Case'},
  ],
  'image': 'https://example.com/redline.png',
};

const _karambitJson = {
  'id': 'skin-e757fd7191f9',
  'name': '★ Karambit | Doppler',
  'weapon': {'id': 'knife_karambit', 'weapon_id': 507, 'name': 'Karambit'},
  'rarity': {'id': 'rarity_ancient', 'name': 'Extraordinary', 'color': '#eb4b4b'},
  'stattrak': true,
  'souvenir': false,
  'wears': [
    {'id': 'w1', 'name': 'Factory New'},
  ],
  'crates': <Map<String, Object?>>[],
  'collections': <Map<String, Object?>>[],
  'image': 'https://example.com/karambit.png',
};

Cs2MarketPricePoint _point(
  String hash,
  DateTime at, {
  int? lowest,
  int? median,
}) =>
    Cs2MarketPricePoint(
      id: at.microsecondsSinceEpoch,
      marketHashName: hash,
      observedAt: at,
      lowestCents: lowest,
      medianCents: median,
      currency: 'USD',
    );

void main() {
  group('market hash names', () {
    test('a plain skin with a wear', () {
      expect(
        cs2MarketHashName(baseName: 'AK-47 | Redline', wear: 'Field-Tested'),
        'AK-47 | Redline (Field-Tested)',
      );
    });

    test('StatTrak sits after the star, before the weapon name', () {
      expect(
        cs2MarketHashName(
          baseName: '★ Karambit | Doppler',
          wear: 'Factory New',
          statTrak: true,
        ),
        '★ StatTrak™ Karambit | Doppler (Factory New)',
      );
    });

    test('StatTrak with no star sits right at the start', () {
      expect(
        cs2MarketHashName(
          baseName: 'AK-47 | Redline',
          wear: 'Field-Tested',
          statTrak: true,
        ),
        'StatTrak™ AK-47 | Redline (Field-Tested)',
      );
    });

    test('a vanilla item with no wear has no suffix at all', () {
      expect(cs2MarketHashName(baseName: '★ Bayonet'), '★ Bayonet');
    });
  });

  group('catalog parsing', () {
    test('reads name, weapon, rarity, case and wears from the dataset shape',
        () {
      final skin = Cs2SkinDef.fromCatalogJson(_redlineJson)!;
      expect(skin.name, 'AK-47 | Redline');
      expect(skin.weaponName, 'AK-47');
      expect(skin.rarityName, 'Classified');
      expect(skin.rarityColor, '#d32ce6');
      expect(skin.wears, ['Minimal Wear', 'Field-Tested']);
      expect(skin.caseName, 'Operation Phoenix Weapon Case');
      expect(skin.stattrak, isTrue);
    });

    test('a skin with no crates has a null case, not a made-up one', () {
      final skin = Cs2SkinDef.fromCatalogJson(_karambitJson)!;
      expect(skin.caseName, isNull);
    });

    test('rejects an entry missing the fields a tile needs', () {
      expect(Cs2SkinDef.fromCatalogJson(const {'name': 'No rarity'}), isNull);
    });

    test('round-trips through the compact disk-cache form', () {
      final skin = Cs2SkinDef.fromCatalogJson(_redlineJson)!;
      final restored = Cs2SkinDef.fromCacheJson(skin.toCacheJson())!;
      expect(restored.name, skin.name);
      expect(restored.caseName, skin.caseName);
      expect(restored.wears, skin.wears);
      expect(restored.rarityColor, skin.rarityColor);
    });
  });

  group('price overview parsing', () {
    test('reads a normal USD reply into integer cents', () {
      final price = Cs2MarketPrice.fromJson(const {
        'success': true,
        'lowest_price': r'$37.09',
        'median_price': r'$41.50',
        'volume': '69',
      })!;
      expect(price.lowestCents, 3709);
      expect(price.medianCents, 4150);
      expect(price.volume, 69);
    });

    test('a thin market with only a median still parses', () {
      final price = Cs2MarketPrice.fromJson(const {
        'success': true,
        'median_price': r'$1,785.34',
      })!;
      expect(price.lowestCents, isNull);
      expect(price.medianCents, 178534);
    });

    test('success:false yields no price at all', () {
      expect(Cs2MarketPrice.fromJson(const {'success': false}), isNull);
    });
  });

  group('price series', () {
    const hash = 'AK-47 | Redline (Field-Tested)';
    final now = DateTime(2026, 1, 10);

    test('is empty with no readings', () {
      final series =
          buildCs2PriceSeries(const [], Cs2PriceRange.week, now);
      expect(series.isEmpty, isTrue);
    });

    test('a single reading is flagged, not drawn as a line', () {
      final series = buildCs2PriceSeries(
        [_point(hash, now, lowest: 1000)],
        Cs2PriceRange.week,
        now,
      );
      expect(series.isSingle, isTrue);
      expect(series.lowestCents, 1000);
    });

    test('falls back to the median when there is no lowest listing', () {
      final series = buildCs2PriceSeries(
        [_point(hash, now, median: 2500)],
        Cs2PriceRange.day,
        now,
      );
      expect(series.samples.single.priceCents, 2500);
    });

    test('readings before the window are excluded, not carried forward', () {
      final old = now.subtract(const Duration(days: 30));
      final recent = now.subtract(const Duration(hours: 2));
      final series = buildCs2PriceSeries(
        [_point(hash, old, lowest: 500), _point(hash, recent, lowest: 900)],
        Cs2PriceRange.week,
        now,
      );
      expect(series.samples, hasLength(1));
      expect(series.samples.single.priceCents, 900);
    });

    test('"All" ignores the cutoff entirely', () {
      final old = now.subtract(const Duration(days: 400));
      final series = buildCs2PriceSeries(
        [_point(hash, old, lowest: 500)],
        Cs2PriceRange.all,
        now,
      );
      expect(series.samples, hasLength(1));
    });
  });

  group('gain/loss series', () {
    const hash = 'AK-47 | Redline (Field-Tested)';
    final now = DateTime(2026, 1, 10);

    test('recentres every reading on the starting price', () {
      final priceSeries = buildCs2PriceSeries(
        [
          _point(hash, now.subtract(const Duration(hours: 2)), lowest: 1000),
          _point(hash, now, lowest: 1250),
        ],
        Cs2PriceRange.week,
        now,
      );
      final series = buildCs2GainLossSeries(priceSeries, 1100);
      expect(series.samples.map((s) => s.deltaCents), [-100, 150]);
      expect(series.currentDeltaCents, 150);
    });

    test('current percent is the last delta over the starting price', () {
      final priceSeries = buildCs2PriceSeries(
        [_point(hash, now, lowest: 1500)],
        Cs2PriceRange.week,
        now,
      );
      final series = buildCs2GainLossSeries(priceSeries, 1000);
      expect(series.currentPercent, closeTo(50, 0.001));
    });

    test('a zero starting price has no percent, not a divide-by-zero crash',
        () {
      final priceSeries = buildCs2PriceSeries(
        [_point(hash, now, lowest: 500)],
        Cs2PriceRange.week,
        now,
      );
      final series = buildCs2GainLossSeries(priceSeries, 0);
      expect(series.currentPercent, isNull);
    });

    test('empty price series yields an empty gain/loss series', () {
      final priceSeries =
          buildCs2PriceSeries(const [], Cs2PriceRange.week, now);
      final series = buildCs2GainLossSeries(priceSeries, 1000);
      expect(series.isEmpty, isTrue);
      expect(series.currentDeltaCents, isNull);
    });
  });

  group('portfolio series', () {
    const redline = 'AK-47 | Redline (Field-Tested)';
    const karambit = '★ Karambit | Doppler (Factory New)';
    final now = DateTime(2026, 1, 10);

    test('each reading updates the running total of every listing\'s '
        'latest known price', () {
      final points = [
        _point(redline, now.subtract(const Duration(hours: 2)), lowest: 1000),
        _point(karambit, now.subtract(const Duration(hours: 1)), lowest: 50000),
        _point(redline, now, lowest: 1200),
      ];
      final series = buildCs2PortfolioSeries(points, Cs2PriceRange.day, now);
      expect(series.samples.map((s) => s.priceCents), [1000, 51000, 51200]);
    });

    test('a reading from before the window is carried forward as a seed',
        () {
      final points = [
        _point(redline, now.subtract(const Duration(days: 10)), lowest: 1000),
        _point(karambit, now, lowest: 50000),
      ];
      final series = buildCs2PortfolioSeries(points, Cs2PriceRange.week, now);
      // Seeded at the window start with just the Redline's carried-forward
      // price, then the Karambit's own in-window reading adds to the total.
      expect(series.samples.first.priceCents, 1000);
      expect(series.samples.last.priceCents, 51000);
    });

    test('"All" has nothing to carry forward from, so no seed sample', () {
      final points = [
        _point(redline, now.subtract(const Duration(days: 400)), lowest: 1000),
      ];
      final series = buildCs2PortfolioSeries(points, Cs2PriceRange.all, now);
      expect(series.samples, hasLength(1));
      expect(series.samples.single.priceCents, 1000);
    });

    test('falls back to the median when a listing has no lowest', () {
      final points = [_point(redline, now, median: 750)];
      final series = buildCs2PortfolioSeries(points, Cs2PriceRange.day, now);
      expect(series.samples.single.priceCents, 750);
    });

    test('no readings at all is an empty series', () {
      final series =
          buildCs2PortfolioSeries(const [], Cs2PriceRange.week, now);
      expect(series.isEmpty, isTrue);
    });
  });

  group('tracking a listing needs no Steam account', () {
    late SteamDatabase db;

    setUp(() => db = SteamDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Cs2MarketItemsCompanion trackedRedline({String? wear, bool statTrak = false}) =>
        Cs2MarketItemsCompanion.insert(
          marketHashName:
              cs2MarketHashName(baseName: 'AK-47 | Redline', wear: wear, statTrak: statTrak),
          skinId: 'skin-91a429af4a60',
          displayName: 'AK-47 | Redline',
          weaponName: 'AK-47',
          rarityName: 'Classified',
          rarityColor: '#d32ce6',
          caseName: const Value('Operation Phoenix Weapon Case'),
          imageUrl: 'https://example.com/redline.png',
          wear: Value(wear),
          statTrak: Value(statTrak),
        );

    test('two wears of the same skin are independent listings', () {
      final ft = trackedRedline(wear: 'Field-Tested');
      final mw = trackedRedline(wear: 'Minimal Wear');
      expect(ft.marketHashName.value, isNot(mw.marketHashName.value));
    });

    test('recording a price appends history and mirrors the latest onto the row',
        () async {
      final item = trackedRedline(wear: 'Field-Tested');
      await db.addTrackedCs2Item(item);

      await db.recordCs2Price(
        item.marketHashName.value,
        lowestCents: 3709,
        medianCents: 4150,
        currency: 'USD',
      );
      await db.recordCs2Price(
        item.marketHashName.value,
        lowestCents: 3800,
        medianCents: null,
        currency: 'USD',
      );

      final row = await db.cs2Item(item.marketHashName.value);
      expect(row!.lastLowestCents, 3800);
      expect(row.priceFetchedAt, isNotNull);

      final history =
          await db.watchCs2PriceHistory(item.marketHashName.value).first;
      expect(history, hasLength(2));
      expect(history.first.lowestCents, 3709);
      expect(history.last.lowestCents, 3800);
    });

    test('watchAllCs2PriceHistory combines every tracked listing\'s readings',
        () async {
      final ft = trackedRedline(wear: 'Field-Tested');
      final mw = trackedRedline(wear: 'Minimal Wear');
      await db.addTrackedCs2Item(ft);
      await db.addTrackedCs2Item(mw);

      await db.recordCs2Price(ft.marketHashName.value,
          lowestCents: 1000, medianCents: null, currency: 'USD');
      await db.recordCs2Price(mw.marketHashName.value,
          lowestCents: 2000, medianCents: null, currency: 'USD');

      final all = await db.watchAllCs2PriceHistory().first;
      expect(all, hasLength(2));
      expect(
        all.map((p) => p.marketHashName),
        containsAll([ft.marketHashName.value, mw.marketHashName.value]),
      );
    });

    test(
        'watchAllCs2PriceHistory drops a listing\'s readings the moment it '
        'is untracked', () async {
      final ft = trackedRedline(wear: 'Field-Tested');
      final mw = trackedRedline(wear: 'Minimal Wear');
      await db.addTrackedCs2Item(ft);
      await db.addTrackedCs2Item(mw);
      await db.recordCs2Price(ft.marketHashName.value,
          lowestCents: 1000, medianCents: null, currency: 'USD');
      await db.recordCs2Price(mw.marketHashName.value,
          lowestCents: 2000, medianCents: null, currency: 'USD');

      await db.removeTrackedCs2Item(ft.marketHashName.value);

      final all = await db.watchAllCs2PriceHistory().first;
      expect(all, hasLength(1));
      expect(all.single.marketHashName, mw.marketHashName.value);
    });

    test('untracking drops the row and every reading with it', () async {
      final item = trackedRedline(wear: 'Field-Tested');
      await db.addTrackedCs2Item(item);
      await db.recordCs2Price(
        item.marketHashName.value,
        lowestCents: 3709,
        medianCents: null,
        currency: 'USD',
      );

      await db.removeTrackedCs2Item(item.marketHashName.value);

      expect(await db.cs2Item(item.marketHashName.value), isNull);
      expect(
        await db.watchCs2PriceHistory(item.marketHashName.value).first,
        isEmpty,
      );
    });

    test('tracking the same listing twice changes nothing', () async {
      final item = trackedRedline(wear: 'Field-Tested');
      await db.addTrackedCs2Item(item);
      await db.addTrackedCs2Item(item);

      final all = await db.watchTrackedCs2Items().first;
      expect(all, hasLength(1));
    });

    test('a starting price can be set on an already-tracked listing',
        () async {
      final item = trackedRedline(wear: 'Field-Tested');
      await db.addTrackedCs2Item(item);

      await db.setCs2StartingPrice(item.marketHashName.value, 3200);

      final row = await db.cs2Item(item.marketHashName.value);
      expect(row!.startingPriceCents, 3200);
      expect(row.startingPriceAt, isNotNull);
    });

    test('setting a starting price of null clears both the price and when it was set',
        () async {
      final item = trackedRedline(wear: 'Field-Tested');
      await db.addTrackedCs2Item(item);
      await db.setCs2StartingPrice(item.marketHashName.value, 3200);

      await db.setCs2StartingPrice(item.marketHashName.value, null);

      final row = await db.cs2Item(item.marketHashName.value);
      expect(row!.startingPriceCents, isNull);
      expect(row.startingPriceAt, isNull);
    });

    test('a starting price can be recorded at track time via the companion',
        () async {
      final item = trackedRedline(wear: 'Field-Tested');
      final withStart = Cs2MarketItemsCompanion(
        marketHashName: item.marketHashName,
        skinId: item.skinId,
        displayName: item.displayName,
        weaponName: item.weaponName,
        rarityName: item.rarityName,
        rarityColor: item.rarityColor,
        caseName: item.caseName,
        imageUrl: item.imageUrl,
        wear: item.wear,
        statTrak: item.statTrak,
        startingPriceCents: const Value(2999),
        startingPriceAt: Value(DateTime(2026, 1, 5)),
      );
      await db.addTrackedCs2Item(withStart);

      final row = await db.cs2Item(item.marketHashName.value);
      expect(row!.startingPriceCents, 2999);
    });
  });
}

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
  });
}

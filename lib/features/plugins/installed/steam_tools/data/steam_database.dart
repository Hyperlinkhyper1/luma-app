import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'steam_database.g.dart';

/// One game this device is tracking the price of, plus whatever of its
/// store page has been fetched so far.
///
/// A row gets here one of two ways: the user searched for it and chose to
/// track it, or it came in through a Steam library sync. [owned] is the only
/// thing that distinguishes the two — connecting a Steam account is an
/// optional way to bulk-add the games already owned, not a requirement to
/// track anything, so a row is never deleted just because a sync no longer
/// returns it. The store columns stay null until the game is opened for the
/// first time, because the store API is rate limited and a large tracked
/// list would blow through that budget on a screen where none of it shows.
class SteamGames extends Table {
  IntColumn get appId => integer()();
  TextColumn get name => text()();
  IntColumn get playtimeMinutes => integer().withDefault(const Constant(0))();

  /// Whether the last Steam library sync confirmed this account owns it.
  /// False for anything added by search, and for a game that used to be
  /// owned but dropped out of a later sync (refunded, account changed) —
  /// the row itself is left alone either way; only tracking removes it.
  BoolColumn get owned => boolean().withDefault(const Constant(false))();

  TextColumn get shortDescription => text().nullable()();
  TextColumn get headerImage => text().nullable()();
  TextColumn get backgroundImage => text().nullable()();

  /// Genres and store categories, newline separated.
  TextColumn get tags => text().nullable()();

  /// The parsed requirements blocks, as JSON — see `SteamRequirements`.
  TextColumn get requirements => text().nullable()();

  TextColumn get developers => text().nullable()();
  TextColumn get publishers => text().nullable()();
  TextColumn get releaseDate => text().nullable()();
  IntColumn get metacritic => integer().nullable()();
  BoolColumn get isFree => boolean().withDefault(const Constant(false))();
  BoolColumn get onWindows => boolean().withDefault(const Constant(true))();
  BoolColumn get onMac => boolean().withDefault(const Constant(false))();
  BoolColumn get onLinux => boolean().withDefault(const Constant(false))();

  /// The most recent price seen, mirrored here so the tracked-games grid can
  /// show a price without reading the history table once per tile.
  IntColumn get lastPriceCents => integer().nullable()();
  IntColumn get lastInitialCents => integer().nullable()();
  IntColumn get lastDiscountPercent => integer().nullable()();
  TextColumn get currency => text().nullable()();

  /// When the store page was last read. Null means "never".
  DateTimeColumn get detailsFetchedAt => dateTime().nullable()();

  /// IsThereAnyDeal's own UUID for this game, resolved once from the Steam
  /// app id and then reused — the lookup is a whole extra round trip.
  /// Null means "not looked up"; [itadUnknown] distinguishes that from
  /// "looked up, and ITAD does not carry it".
  TextColumn get itadId => text().nullable()();
  BoolColumn get itadUnknown => boolean().withDefault(const Constant(false))();

  /// The all-time low ITAD has on record, and when it happened.
  IntColumn get lowestEverCents => integer().nullable()();
  DateTimeColumn get lowestEverAt => dateTime().nullable()();

  /// When the price history was last pulled from ITAD.
  DateTimeColumn get historyFetchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {appId};
}

/// One price change on Steam, as recorded by IsThereAnyDeal.
///
/// Steam exposes only the current price, so the history behind the chart
/// comes from ITAD, which has been logging shop prices for years. These rows
/// are a local cache of that: [SteamDatabase.replacePriceHistory] swaps the
/// whole set for a game whenever it is refetched, so the cache can never
/// drift from what ITAD says.
class SteamPricePoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get appId => integer()();
  DateTimeColumn get observedAt => dateTime()();
  IntColumn get finalCents => integer()();
  IntColumn get initialCents => integer()();
  IntColumn get discountPercent => integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
}

/// One CS2 item this device is watching the Community Market price of.
///
/// Unlike [SteamGames], the primary key is the exact market listing name
/// rather than an id the dataset assigns — "AK-47 | Redline (Field-Tested)"
/// and its StatTrak counterpart are different listings with different
/// prices, and Steam itself has no more granular identifier for either.
class Cs2MarketItems extends Table {
  TextColumn get marketHashName => text()();

  /// The dataset id of the underlying finish, so a row can be re-associated
  /// with its catalog entry (image, rarity, case) after a catalog refresh.
  TextColumn get skinId => text()();

  TextColumn get displayName => text()();
  TextColumn get weaponName => text()();
  TextColumn get rarityName => text()();
  TextColumn get rarityColor => text()();
  TextColumn get caseName => text().nullable()();
  TextColumn get imageUrl => text()();
  TextColumn get wear => text().nullable()();
  BoolColumn get statTrak => boolean().withDefault(const Constant(false))();

  /// The most recent read, mirrored here so the browse grid can show a price
  /// without a join into the history table per tile.
  IntColumn get lastLowestCents => integer().nullable()();
  IntColumn get lastMedianCents => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get priceFetchedAt => dateTime().nullable()();

  DateTimeColumn get trackedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {marketHashName};
}

/// One Community Market reading for a tracked CS2 listing.
///
/// Steam's market exposes no price history at all — not even the version
/// behind a login, unlike the store page. Every row here is a price luma
/// itself observed by calling `priceoverview`, so the chart it feeds only
/// ever covers the time this device has actually been watching the item;
/// see `Cs2PriceHistoryCard` for how that is put to the user honestly.
class Cs2MarketPricePoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get marketHashName => text()();
  DateTimeColumn get observedAt => dateTime()();
  IntColumn get lowestCents => integer().nullable()();
  IntColumn get medianCents => integer().nullable()();
  TextColumn get currency => text()();
}

@DriftDatabase(
  tables: [SteamGames, SteamPricePoints, Cs2MarketItems, Cs2MarketPricePoints],
)
class SteamDatabase extends _$SteamDatabase {
  SteamDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_steam',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cs2MarketItems);
            await m.createTable(cs2MarketPricePoints);
          }
        },
      );

  /// Every game this device is tracking, alphabetical.
  Stream<List<SteamGame>> watchTrackedGames() {
    final query = select(steamGames)
      ..orderBy([(g) => OrderingTerm.asc(g.name)]);
    return query.watch();
  }

  Stream<SteamGame?> watchGame(int appId) {
    final query = select(steamGames)..where((g) => g.appId.equals(appId));
    return query.watchSingleOrNull();
  }

  /// Every price ever recorded for [appId], oldest first.
  Stream<List<SteamPricePoint>> watchPriceHistory(int appId) {
    final query = select(steamPricePoints)
      ..where((p) => p.appId.equals(appId))
      ..orderBy([(p) => OrderingTerm.asc(p.observedAt)]);
    return query.watch();
  }

  /// Adds [appId] to the tracked list if it isn't there yet. A no-op for a
  /// game already tracked — this starts tracking, it does not refresh
  /// details for a game that has some already.
  Future<void> addTrackedGame({required int appId, required String name}) =>
      into(steamGames).insert(
        SteamGamesCompanion.insert(appId: Value(appId), name: name),
        mode: InsertMode.insertOrIgnore,
      );

  /// Stops tracking a game and drops its price history with it.
  Future<void> removeTrackedGame(int appId) async {
    await transaction(() async {
      await (delete(steamPricePoints)..where((p) => p.appId.equals(appId)))
          .go();
      await (delete(steamGames)..where((g) => g.appId.equals(appId))).go();
    });
  }

  /// Folds a Steam library read into the tracked list: every game in
  /// [games] is added (or updated) and marked [SteamGames.owned]; anything
  /// that was owned before but is missing from this sync is marked unowned,
  /// never deleted — a refund or an account swap should not silently drop a
  /// game whose price the user was watching.
  Future<void> syncOwnedLibrary(
    Iterable<({int appId, String name, int playtimeMinutes})> games,
  ) async {
    final owned = <int>{};
    await batch((b) {
      for (final game in games) {
        owned.add(game.appId);
        b.insert(
          steamGames,
          SteamGamesCompanion.insert(
            appId: Value(game.appId),
            name: game.name,
            playtimeMinutes: Value(game.playtimeMinutes),
            owned: const Value(true),
          ),
          onConflict: DoUpdate(
            (_) => SteamGamesCompanion(
              name: Value(game.name),
              playtimeMinutes: Value(game.playtimeMinutes),
              owned: const Value(true),
            ),
          ),
        );
      }
    });

    final stillOwned = update(steamGames)..where((g) => g.owned.equals(true));
    if (owned.isEmpty) {
      await stillOwned.write(const SteamGamesCompanion(owned: Value(false)));
    } else {
      await (stillOwned..where((g) => g.appId.isNotIn(owned)))
          .write(const SteamGamesCompanion(owned: Value(false)));
    }
  }

  /// Swaps a game's cached history for [points].
  ///
  /// A wholesale replace rather than an append: ITAD is the source of truth
  /// here, and it can revise or drop entries, so merging would let a stale
  /// row survive forever.
  Future<void> replacePriceHistory(
    int appId,
    Iterable<SteamPricePointsCompanion> points,
  ) async {
    await transaction(() async {
      await (delete(steamPricePoints)..where((p) => p.appId.equals(appId)))
          .go();
      await batch((b) => b.insertAll(steamPricePoints, points.toList()));
    });
  }

  /// Drops every cached history and the ITAD ids behind them, so the next
  /// open refetches. Used when the ITAD key changes.
  Future<void> forgetAllHistory() async {
    await transaction(() async {
      await delete(steamPricePoints).go();
      await update(steamGames).write(const SteamGamesCompanion(
        itadId: Value(null),
        itadUnknown: Value(false),
        lowestEverCents: Value(null),
        lowestEverAt: Value(null),
        historyFetchedAt: Value(null),
      ));
    });
  }

  /// Every CS2 listing this device is watching, alphabetical.
  Stream<List<Cs2MarketItem>> watchTrackedCs2Items() {
    final query = select(cs2MarketItems)
      ..orderBy([(i) => OrderingTerm.asc(i.displayName)]);
    return query.watch();
  }

  Stream<Cs2MarketItem?> watchCs2Item(String marketHashName) {
    final query = select(cs2MarketItems)
      ..where((i) => i.marketHashName.equals(marketHashName));
    return query.watchSingleOrNull();
  }

  Future<Cs2MarketItem?> cs2Item(String marketHashName) =>
      (select(cs2MarketItems)
            ..where((i) => i.marketHashName.equals(marketHashName)))
          .getSingleOrNull();

  Stream<List<Cs2MarketPricePoint>> watchCs2PriceHistory(
    String marketHashName,
  ) {
    final query = select(cs2MarketPricePoints)
      ..where((p) => p.marketHashName.equals(marketHashName))
      ..orderBy([(p) => OrderingTerm.asc(p.observedAt)]);
    return query.watch();
  }

  /// Starts watching one specific listing. A no-op if it is already tracked
  /// — this does not refresh a row that already has one.
  Future<void> addTrackedCs2Item(Cs2MarketItemsCompanion item) =>
      into(cs2MarketItems).insert(item, mode: InsertMode.insertOrIgnore);

  /// Stops watching a listing and drops the local price history built for
  /// it — there is nowhere else that history lives.
  Future<void> removeTrackedCs2Item(String marketHashName) async {
    await transaction(() async {
      await (delete(cs2MarketPricePoints)
            ..where((p) => p.marketHashName.equals(marketHashName)))
          .go();
      await (delete(cs2MarketItems)
            ..where((i) => i.marketHashName.equals(marketHashName)))
          .go();
    });
  }

  /// Records one Community Market reading: mirrors it onto the tracked row
  /// for the grid, and appends it to the history table the chart reads.
  /// Unlike [replacePriceHistory], this appends rather than replaces — every
  /// reading is itself an observation this device made, not a copy of an
  /// external source that can be wholesale superseded.
  Future<void> recordCs2Price(
    String marketHashName, {
    required int? lowestCents,
    required int? medianCents,
    required String currency,
  }) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(cs2MarketItems)
            ..where((i) => i.marketHashName.equals(marketHashName)))
          .write(Cs2MarketItemsCompanion(
        lastLowestCents: Value(lowestCents),
        lastMedianCents: Value(medianCents),
        currency: Value(currency),
        priceFetchedAt: Value(now),
      ));
      await into(cs2MarketPricePoints).insert(
        Cs2MarketPricePointsCompanion.insert(
          marketHashName: marketHashName,
          observedAt: now,
          lowestCents: Value(lowestCents),
          medianCents: Value(medianCents),
          currency: currency,
        ),
      );
    });
  }
}

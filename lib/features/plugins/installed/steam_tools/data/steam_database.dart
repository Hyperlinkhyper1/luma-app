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

/// One CS2 listing this device is watching the Community Market price of —
/// a specific finish, wear and StatTrak combination, shared by every copy of
/// it the user tracks (see [Cs2MarketEntries]).
///
/// Unlike [SteamGames], the primary key is the exact market listing name
/// rather than an id the dataset assigns — "AK-47 | Redline (Field-Tested)"
/// and its StatTrak counterpart are different listings with different
/// prices, and Steam itself has no more granular identifier for either.
/// Price is fetched and cached once per listing regardless of how many
/// copies are tracked, since Steam prices the listing, not any individual
/// copy of it.
///
/// [startingPriceCents]/[startingPriceAt] are no longer written to for new
/// data (see [Cs2MarketEntries] instead, which lets each copy have its own
/// cost basis) but stay in the schema — a device upgrading from before
/// entries existed has its one starting price here, and the schemaVersion
/// 5 migration copies it into that device's first entry rather than losing
/// it.
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

  /// Superseded by [Cs2MarketEntries.startingPriceCents] — kept only so the
  /// schemaVersion 5 migration has something to read a pre-existing value
  /// from. New code should never write to this column.
  IntColumn get startingPriceCents => integer().nullable()();
  DateTimeColumn get startingPriceAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {marketHashName};
}

/// One copy of a [Cs2MarketItems] listing the user is tracking — "I have an
/// AK-47 | Redline (Field-Tested)" can mean more than one, bought at
/// different times for different prices, so this is a many-to-one child
/// table rather than a boolean on the listing itself.
///
/// [marketHashName] is a plain column, not a foreign key with a unique
/// constraint — the whole point of this table existing is that several rows
/// can share the same one. A listing's shared price data (current price,
/// history) still lives once on [Cs2MarketItems]; only the per-copy cost
/// basis and "since when" belong here.
class Cs2MarketEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get marketHashName => text()();

  /// What the user says they paid (or otherwise wants gain/loss measured
  /// from) for this one copy — a manual figure, never inferred from a
  /// market reading, since the market price when a copy was added and its
  /// actual cost are frequently different numbers. Null means no baseline
  /// has been set for this copy, in which case its chart has nothing to
  /// compare against and only shows raw price.
  IntColumn get startingPriceCents => integer().nullable()();
  DateTimeColumn get startingPriceAt => dateTime().nullable()();

  DateTimeColumn get trackedAt => dateTime().withDefault(currentDateAndTime)();
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

/// A skin pinned to the top of the CS2 Market browse grid.
///
/// Deliberately separate from [Cs2MarketItems]: pinning is a bookmark on the
/// *finish* ("I care about AK-47 | Redline"), not on one priced wear/StatTrak
/// listing of it, and it carries no price data of its own — it only changes
/// sort order in the UI.
class Cs2PinnedSkins extends Table {
  TextColumn get skinId => text()();
  DateTimeColumn get pinnedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {skinId};
}

@DriftDatabase(
  tables: [
    SteamGames,
    SteamPricePoints,
    Cs2MarketItems,
    Cs2MarketPricePoints,
    Cs2PinnedSkins,
    Cs2MarketEntries,
  ],
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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cs2MarketItems);
            await m.createTable(cs2MarketPricePoints);
          }
          if (from < 3) {
            await m.createTable(cs2PinnedSkins);
          }
          if (from < 4) {
            await m.addColumn(cs2MarketItems, cs2MarketItems.startingPriceCents);
            await m.addColumn(cs2MarketItems, cs2MarketItems.startingPriceAt);
          }
          if (from < 5) {
            await m.createTable(cs2MarketEntries);
            // Every listing tracked before entries existed becomes that
            // listing's first entry, carrying its starting price along —
            // otherwise upgrading would silently wipe out every baseline
            // (and, from the UI's point of view, every tracked listing,
            // since the Tracked tab now reads entries rather than listings)
            // a device already had. Checked for an existing match first so
            // this can never double a listing's entry if this step somehow
            // runs more than once against the same data (see schemaVersion
            // 6 below, added after exactly that happened for a real device).
            final existingListings = await select(cs2MarketItems).get();
            for (final item in existingListings) {
              final alreadyMigrated = await (select(cs2MarketEntries)
                    ..where((e) =>
                        e.marketHashName.equals(item.marketHashName) &
                        e.trackedAt.equals(item.trackedAt)))
                  .getSingleOrNull();
              if (alreadyMigrated != null) continue;
              await into(cs2MarketEntries).insert(
                Cs2MarketEntriesCompanion.insert(
                  marketHashName: item.marketHashName,
                  startingPriceCents: Value(item.startingPriceCents),
                  startingPriceAt: Value(item.startingPriceAt),
                  trackedAt: Value(item.trackedAt),
                ),
              );
            }
          }
          if (from < 6) {
            // The schemaVersion 5 step above ran twice on at least one real
            // device (most likely two app processes racing on first launch
            // after the update, each seeing "not yet migrated" before either
            // had committed), leaving two byte-for-byte identical entries
            // per listing — every tracked copy showing up twice in the
            // Tracked tab, doubling the portfolio total along with it.
            await dedupeCs2Entries();
          }
        },
      );

  /// Collapses entries that agree on listing, starting price and tracked-at
  /// down to one each, keeping the lowest id — such entries are
  /// indistinguishable copies of the same original one (a genuine second
  /// copy of a skin practically always differs in at least one of those
  /// fields), the signature a doubled schemaVersion-5 migration leaves
  /// behind. Exposed as its own method, rather than inlined in the
  /// migration, so it has something other than a live upgrade to be tested
  /// against.
  Future<void> dedupeCs2Entries() async {
    final allEntries = await select(cs2MarketEntries).get();
    final keptIdBySignature = <String, int>{};
    final duplicateIds = <int>[];
    for (final entry in allEntries) {
      final signature = [
        entry.marketHashName,
        entry.startingPriceCents,
        entry.startingPriceAt?.millisecondsSinceEpoch,
        entry.trackedAt.millisecondsSinceEpoch,
      ].join('|');
      if (keptIdBySignature.containsKey(signature)) {
        duplicateIds.add(entry.id);
      } else {
        keptIdBySignature[signature] = entry.id;
      }
    }
    if (duplicateIds.isNotEmpty) {
      await (delete(cs2MarketEntries)..where((e) => e.id.isIn(duplicateIds)))
          .go();
    }
  }

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

  /// Every reading across every tracked listing, oldest first — the raw
  /// material for a combined "all tracked items" total. [removeCs2Entry]
  /// deletes a listing's rows out of this table the moment its last copy is
  /// untracked, so unlike most "every row" queries this one never needs to
  /// filter by what's currently tracked — anything left in here already is.
  Stream<List<Cs2MarketPricePoint>> watchAllCs2PriceHistory() {
    final query = select(cs2MarketPricePoints)
      ..orderBy([(p) => OrderingTerm.asc(p.observedAt)]);
    return query.watch();
  }

  /// Starts watching one specific listing's price. A no-op if it is already
  /// watched — this does not refresh a row that already has one, and it
  /// deliberately doesn't add a copy either; call [addCs2Entry] for that.
  Future<void> addTrackedCs2Item(Cs2MarketItemsCompanion item) =>
      into(cs2MarketItems).insert(item, mode: InsertMode.insertOrIgnore);

  /// Every entry (copy) tracked for [marketHashName], oldest first.
  Stream<List<Cs2MarketEntry>> watchCs2Entries(String marketHashName) {
    final query = select(cs2MarketEntries)
      ..where((e) => e.marketHashName.equals(marketHashName))
      ..orderBy([(e) => OrderingTerm.asc(e.trackedAt)]);
    return query.watch();
  }

  /// Every entry across every listing — what the Tracked tab's grid and
  /// portfolio total are built from.
  Stream<List<Cs2MarketEntry>> watchAllCs2Entries() {
    final query = select(cs2MarketEntries)
      ..orderBy([(e) => OrderingTerm.asc(e.trackedAt)]);
    return query.watch();
  }

  /// Adds one more tracked copy of [entry.marketHashName] — always a new
  /// row, unlike [addTrackedCs2Item]'s insert-or-ignore, since tracking the
  /// same listing twice is exactly how a second copy gets added.
  Future<void> addCs2Entry(Cs2MarketEntriesCompanion entry) =>
      into(cs2MarketEntries).insert(entry);

  /// Stops tracking one copy. If it was the last entry for its listing, the
  /// listing itself and the local price history built for it are dropped
  /// too — there is nowhere else that history lives, and there is no reason
  /// to keep sweeping a listing's price once nothing here still cares about
  /// it. A sibling copy surviving is exactly why this checks first rather
  /// than always cleaning up.
  Future<void> removeCs2Entry(int id) async {
    await transaction(() async {
      final entry =
          await (select(cs2MarketEntries)..where((e) => e.id.equals(id)))
              .getSingleOrNull();
      if (entry == null) return;
      await (delete(cs2MarketEntries)..where((e) => e.id.equals(id))).go();

      final remaining = await (select(cs2MarketEntries)
            ..where((e) => e.marketHashName.equals(entry.marketHashName)))
          .get();
      if (remaining.isNotEmpty) return;

      await (delete(cs2MarketPricePoints)
            ..where((p) => p.marketHashName.equals(entry.marketHashName)))
          .go();
      await (delete(cs2MarketItems)
            ..where((i) => i.marketHashName.equals(entry.marketHashName)))
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

  /// Sets (or, with `null`, clears) the manual cost-basis one entry's
  /// gain/loss is measured from. [Cs2MarketEntries.startingPriceAt] is
  /// stamped to now alongside a non-null price so the chart can say when
  /// the baseline was set, and cleared along with it.
  Future<void> setCs2EntryStartingPrice(int entryId, int? cents) async {
    await (update(cs2MarketEntries)..where((e) => e.id.equals(entryId)))
        .write(Cs2MarketEntriesCompanion(
      startingPriceCents: Value(cents),
      startingPriceAt: Value(cents == null ? null : DateTime.now()),
    ));
  }

  /// Every pinned skin id, unordered — the browse grid sorts by this
  /// membership, not by [Cs2PinnedSkins.pinnedAt].
  Stream<Set<String>> watchPinnedSkinIds() => select(cs2PinnedSkins)
      .watch()
      .map((rows) => {for (final row in rows) row.skinId});

  Future<void> pinSkin(String skinId) => into(cs2PinnedSkins).insert(
        Cs2PinnedSkinsCompanion.insert(skinId: skinId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> unpinSkin(String skinId) async {
    await (delete(cs2PinnedSkins)..where((p) => p.skinId.equals(skinId))).go();
  }
}

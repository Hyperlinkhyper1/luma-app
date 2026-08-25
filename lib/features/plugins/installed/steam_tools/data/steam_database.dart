import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'steam_database.g.dart';

/// One game from the account's Steam library, plus whatever of its store
/// page has been fetched so far.
///
/// The library rows are written by a library sync; the store columns stay
/// null until the game is opened for the first time, because the store API
/// is rate limited and a library of several hundred games would blow through
/// that budget on a screen where none of it is shown.
class SteamGames extends Table {
  IntColumn get appId => integer()();
  TextColumn get name => text()();
  IntColumn get playtimeMinutes => integer().withDefault(const Constant(0))();

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

  /// The most recent price seen, mirrored here so the library grid can show
  /// a price without reading the history table once per tile.
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

@DriftDatabase(tables: [SteamGames, SteamPricePoints])
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
  int get schemaVersion => 1;

  /// Every game in the library, alphabetical.
  Stream<List<SteamGame>> watchLibrary() {
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

  /// Replaces the stored library with [games], keeping every column the
  /// store fetch filled in.
  ///
  /// Games no longer in the library are deleted along with their history —
  /// a library row that the account does not own is not something the user
  /// can act on, and leaving its price points behind would grow the file
  /// forever.
  Future<void> replaceLibrary(
    Iterable<({int appId, String name, int playtimeMinutes})> games,
  ) async {
    final keep = <int>{};
    await batch((b) {
      for (final game in games) {
        keep.add(game.appId);
        b.insert(
          steamGames,
          SteamGamesCompanion.insert(
            appId: Value(game.appId),
            name: game.name,
            playtimeMinutes: Value(game.playtimeMinutes),
          ),
          onConflict: DoUpdate(
            (_) => SteamGamesCompanion(
              name: Value(game.name),
              playtimeMinutes: Value(game.playtimeMinutes),
            ),
          ),
        );
      }
    });
    if (keep.isEmpty) return;
    await (delete(steamGames)..where((g) => g.appId.isNotIn(keep))).go();
    await (delete(steamPricePoints)..where((p) => p.appId.isNotIn(keep))).go();
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

  Future<void> clearLibrary() async {
    await delete(steamPricePoints).go();
    await delete(steamGames).go();
  }
}

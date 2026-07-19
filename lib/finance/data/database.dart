import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'seed_data.dart';

part 'database.g.dart';

/// What a ledger entry represents.
enum TxnKind { income, expense, allocation }

/// How often a recurring rule or allocation fires.
enum Cadence { weekly, monthly }

/// How an allocation rule computes its amount.
enum AllocMode { fixed, percent }

/// Spending tags (groceries, clothing, ...). Carried by merchants and entries.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodepoint => integer()();
}

/// Known companies/shops the user spends money at.
class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get defaultCategoryId =>
      integer().nullable().references(Categories, #id)();
}

/// Envelopes ("potjes") money is divided into.
class Pots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodepoint => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Every movement of money. Amount is a positive magnitude in cents; [kind]
/// and [potId] decide how it affects the main balance and pot balances.
class FinanceTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<TxnKind>()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get potId => integer().nullable().references(Pots, #id)();
  IntColumn get merchantId => integer().nullable().references(Merchants, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Fixed costs / income that repeat (Spotify, salary, ...).
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get kind => textEnum<TxnKind>()(); // income | expense
  IntColumn get amountCents => integer()();
  TextColumn get cadence => textEnum<Cadence>()();
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get lastApplied => dateTime().nullable()();
  IntColumn get potId => integer().nullable().references(Pots, #id)();
  IntColumn get merchantId => integer().nullable().references(Merchants, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Marks this as a bill/subscription (vs. an ordinary recurring expense or
  /// income) so it can be surfaced in the "due soon" reminder list. Only
  /// meaningful for expense-kind rules.
  BoolColumn get isBill => boolean().withDefault(const Constant(false))();
}

/// Rules that automatically move money from the main balance into a pot.
class AllocationRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get potId => integer().references(Pots, #id)();
  TextColumn get mode => textEnum<AllocMode>()();
  IntColumn get valueCents => integer().withDefault(const Constant(0))();
  IntColumn get percentBps => integer().withDefault(const Constant(0))();
  TextColumn get cadence => textEnum<Cadence>()();
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get lastApplied => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Stock positions. Live prices are fetched online and cached here.
class Holdings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ticker => text().withLength(min: 1, max: 20)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get shares => real()();
  IntColumn get avgCostCents => integer()();
  IntColumn get lastPriceCents => integer().nullable()();
  DateTimeColumn get lastPriceAt => dateTime().nullable()();
}

/// Simple key/value store for app-level state (e.g. last distribution run).
class MetaItems extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One daily snapshot of total net worth (main balance + all pots + holdings
/// market value), so the overview can chart a trend over time. Populated
/// once per day (see FinanceRepository.recordBalanceSnapshotIfNeeded) —
/// balances themselves are never stored anywhere else, only ever derived
/// from the transaction ledger, so this is purely an appendable history.
class BalanceSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get totalCents => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date}
      ];
}

/// User-configured graphs on the overview dashboard.
class OverviewGraphs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get graphType => text()();
  TextColumn get dataSource => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DriftDatabase(
  tables: [
    Categories,
    Merchants,
    Pots,
    FinanceTransactions,
    RecurringRules,
    AllocationRules,
    Holdings,
    MetaItems,
    OverviewGraphs,
    BalanceSnapshots,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_finance',
              // Store the database in the app's local support directory rather
              // than Documents (which can be OneDrive-synced). Keeps finance
              // data local and off the cloud.
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(overviewGraphs);
            await _seedGraphs();
          }
          if (from < 3) {
            await m.addColumn(recurringRules, recurringRules.isBill);
            await m.createTable(balanceSnapshots);
          }
        },
      );

  Future<void> _seedGraphs() async {
    await batch((b) {
      b.insertAll(
        overviewGraphs,
        seedOverviewGraphs
            .asMap()
            .entries
            .map((e) => OverviewGraphsCompanion.insert(
                  graphType: e.value.graphType,
                  dataSource: e.value.dataSource,
                  sortOrder: Value(e.key),
                ))
            .toList(),
      );
    });
  }

  /// Seeds the default categories and known merchants on first launch.
  Future<void> _seed() async {
    await batch((b) {
      b.insertAll(
        categories,
        seedCategories
            .map((c) => CategoriesCompanion.insert(
                  name: c.name,
                  colorValue: c.colorValue,
                  iconCodepoint: c.iconCodepoint,
                ))
            .toList(),
      );
    });

    // Resolve category ids by name so merchants can reference them.
    final cats = await select(categories).get();
    final idByName = {for (final c in cats) c.name: c.id};

    await batch((b) {
      b.insertAll(
        merchants,
        seedMerchants
            .map((m) => MerchantsCompanion.insert(
                  name: m.name,
                  defaultCategoryId: Value(idByName[m.categoryName]),
                ))
            .toList(),
      );
    });

    await _seedGraphs();
  }
}

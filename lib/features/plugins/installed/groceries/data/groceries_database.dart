import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'groceries_database.g.dart';

/// A user-created shopping list (e.g. "Weekly groceries", "BBQ Saturday").
class GroceryLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// One product added to a list. Price/name/image are snapshotted at add
/// time so a list keeps showing sensible totals even if the remote catalog
/// entry later changes or disappears.
class GroceryListItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().references(GroceryLists, #id)();

  /// The remote product id from the supermarket-db search API, if this item
  /// came from a search result (always true today, but kept nullable for
  /// manually-added items down the line).
  TextColumn get productId => text().nullable()();

  /// Supermarket slug: 'jumbo', 'ah', or 'lidl'.
  TextColumn get market => text()();
  TextColumn get marketName => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get category => text().nullable()();
  RealColumn get price => real().nullable()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [GroceryLists, GroceryListItems])
class GroceriesDatabase extends _$GroceriesDatabase {
  GroceriesDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_groceries',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}

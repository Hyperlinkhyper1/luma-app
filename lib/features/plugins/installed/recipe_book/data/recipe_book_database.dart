import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'recipe_book_database.g.dart';

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  IntColumn get servings => integer().withDefault(const Constant(2))();
  IntColumn get prepMinutes => integer().withDefault(const Constant(0))();
  IntColumn get cookMinutes => integer().withDefault(const Constant(0))();
  TextColumn get ingredients => text().withDefault(const Constant('[]'))();
  TextColumn get steps => text().withDefault(const Constant('[]'))();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Recipes])
class RecipeBookDatabase extends _$RecipeBookDatabase {
  RecipeBookDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_recipe_book',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}

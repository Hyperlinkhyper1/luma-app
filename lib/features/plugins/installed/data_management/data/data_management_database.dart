import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'data_management_database.g.dart';

/// A user-created dataset (table) with a name, column schema, and the set of
/// tags the user has defined for it (JSON list of {name, color}).
class DataDatasets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get columnsJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// One row in a dataset. Values are stored as a JSON map keyed by column
/// index; tags as a JSON list of tag names defined on the dataset.
class DataRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get datasetId => integer()();
  TextColumn get valuesJson => text().withDefault(const Constant('{}'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [DataDatasets, DataRows])
class DataManagementDatabase extends _$DataManagementDatabase {
  DataManagementDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_data_management',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(dataDatasets, dataDatasets.tagsJson);
            await m.addColumn(dataRows, dataRows.tagsJson);
          }
        },
      );
}

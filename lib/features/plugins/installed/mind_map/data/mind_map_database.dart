import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'mind_map_database.g.dart';

/// One mind map. The layout direction lives here rather than in settings so
/// each map keeps the shape it was drawn in.
class MindMaps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Index into `MindMapDirection.values`.
  IntColumn get direction => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// A node on a map.
///
/// Deliberately has no x/y: positions are derived by [MindMapLayout] every
/// time the tree changes, which is what keeps branches from overlapping and
/// spares the user from arranging anything by hand. Order among siblings is
/// [sortIndex]; structure is [parentId].
class MindMapNodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mapId => integer().references(MindMaps, #id)();
  IntColumn get parentId => integer().nullable()();
  TextColumn get label => text()();
  TextColumn get note => text().nullable()();
  TextColumn get link => text().nullable()();

  /// Null means "inherit the branch colour from the nearest coloured
  /// ancestor", so recolouring a branch is a single edit.
  IntColumn get color => integer().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Small key/value scratch space. Currently only records that the one-time
/// import of the old School mind maps has run; because the sync collection
/// ships every table, that flag travels between devices and stops a second
/// device from importing the same maps again.
class MindMapMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [MindMaps, MindMapNodes, MindMapMeta])
class MindMapDatabase extends _$MindMapDatabase {
  MindMapDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_mind_map',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}

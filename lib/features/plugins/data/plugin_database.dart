import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'plugin_database.g.dart';

/// Local record of which marketplace plugins have been downloaded onto this
/// device. The catalog/manifest data itself lives outside the app bundle
/// (see PluginCatalogService) — this table only tracks install state.
class InstalledPlugins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pluginId => text().withLength(min: 1, max: 80)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get icon => text().withDefault(const Constant('extension'))();
  TextColumn get version => text().withDefault(const Constant('1.0.0'))();
  DateTimeColumn get installedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [InstalledPlugins])
class PluginDatabase extends _$PluginDatabase {
  PluginDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_plugins',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}

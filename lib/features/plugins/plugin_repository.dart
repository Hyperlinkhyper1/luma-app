import 'package:drift/drift.dart';

import 'data/plugin_database.dart';
import 'plugin_catalog_service.dart';

/// A plugin that has been downloaded onto this device.
class InstalledPluginRecord {
  const InstalledPluginRecord({
    required this.pluginId,
    required this.name,
    required this.icon,
    required this.version,
    required this.installedAt,
    required this.downloadCount,
  });

  final String pluginId;
  final String name;
  final String icon;
  final String version;
  final DateTime installedAt;
  final int downloadCount;
}

/// CRUD over the local "installed plugins" record, backed by [PluginDatabase].
/// Installing fetches the plugin's manifest from the repo first, so a
/// download always involves a real round trip to the source of truth.
class PluginRepository {
  PluginRepository(this._db, this._service);

  final PluginDatabase _db;
  final PluginCatalogService _service;

  /// Streams installed plugins, oldest-installed first (so newly downloaded
  /// plugins appear at the bottom of the nav rail group).
  Stream<List<InstalledPluginRecord>> watchInstalled() {
    final query = _db.select(_db.installedPlugins)
      ..orderBy([(t) => OrderingTerm.asc(t.installedAt)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<void> install(PluginCatalogEntry entry) async {
    final manifest = await _service.fetchManifest(entry.id);
    final existing = await (_db.select(_db.installedPlugins)
          ..where((t) => t.pluginId.equals(entry.id)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.installedPlugins).insert(
            InstalledPluginsCompanion.insert(
              pluginId: entry.id,
              name: manifest.name,
              icon: Value(manifest.icon),
              version: Value(manifest.version),
              downloadCount: const Value(1),
            ),
          );
    } else {
      await (_db.update(_db.installedPlugins)
            ..where((t) => t.id.equals(existing.id)))
          .write(InstalledPluginsCompanion(
        name: Value(manifest.name),
        icon: Value(manifest.icon),
        version: Value(manifest.version),
        downloadCount: Value(existing.downloadCount + 1),
      ));
    }
  }

  Future<void> uninstall(String pluginId) {
    return (_db.delete(_db.installedPlugins)
          ..where((t) => t.pluginId.equals(pluginId)))
        .go();
  }

  InstalledPluginRecord _toRecord(InstalledPlugin row) => InstalledPluginRecord(
        pluginId: row.pluginId,
        name: row.name,
        icon: row.icon,
        version: row.version,
        installedAt: row.installedAt,
        downloadCount: row.downloadCount,
      );
}

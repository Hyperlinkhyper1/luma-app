import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../sync/server_access.dart';
import '../../sync/sync_api.dart' show kDefaultSyncServerUrl;
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
  PluginRepository(this._db, this._service, {String? Function()? authToken})
      : _authToken = authToken;

  final PluginDatabase _db;
  final PluginCatalogService _service;

  /// Reads the current account's bearer token. A callback rather than a
  /// value because the sync service is constructed after this repository —
  /// and because the token changes on every sign-in/out.
  final String? Function()? _authToken;

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
    unawaited(_reportDownload(entry.id, manifest.name));
  }

  static const _reportDownloadTimeout = Duration(seconds: 8);

  /// Best-effort ping to the default luma server's admin-only download
  /// counter (see the admin dashboard's "Plugins" tab), purely for aggregate
  /// stats — so any failure (offline, a self-hosted server without this
  /// route, …) is silently ignored.
  ///
  /// It only fires for a device with an approved account: a device that has
  /// not created and approved one talks to no server at all, stats included.
  /// [GatedServerClient] enforces that even if this check is ever missed.
  Future<void> _reportDownload(String pluginId, String name) async {
    final token = _authToken?.call();
    if (!ServerAccess.instance.approved || token == null) return;
    final client = GatedServerClient();
    try {
      await client
          .post(
            Uri.parse('$kDefaultSyncServerUrl/api/v1/plugins/download'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'pluginId': pluginId, 'name': name}),
          )
          .timeout(_reportDownloadTimeout);
    } catch (_) {
      // Stats-only; never let this affect the install flow.
    } finally {
      client.close();
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

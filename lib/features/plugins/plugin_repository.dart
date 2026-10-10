import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

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

/// Plugins nobody can download. They are not in the marketplace; the admin
/// grants one to an account from the dashboard, the server lists it in that
/// account's `grantedPlugins`, and it shows up in the nav rail on its own —
/// and leaves again when the grant is taken away.
const kGrantedOnlyPlugins = {
  'team-clipboard': (name: 'Team Clipboard', icon: 'content_paste'),
};

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

  /// The [kGrantedOnlyPlugins] the signed-in account has been granted, as
  /// the server last reported them. Set from the sync service; empty while
  /// signed out.
  final ValueNotifier<Set<String>> granted = ValueNotifier(const {});

  /// When each granted plugin first showed up this session, so it keeps its
  /// place at the bottom of the nav rail instead of jumping around.
  final Map<String, DateTime> _grantedSince = {};

  /// Streams installed plugins, oldest-installed first (so newly downloaded
  /// plugins appear at the bottom of the nav rail group), with the granted
  /// plugins after them. A granted-only plugin never comes from the
  /// database, so an old row for one can't keep it on screen.
  Stream<List<InstalledPluginRecord>> watchInstalled() {
    final query = _db.select(_db.installedPlugins)
      ..orderBy([(t) => OrderingTerm.asc(t.installedAt)]);
    late final StreamController<List<InstalledPluginRecord>> out;
    StreamSubscription<List<InstalledPlugin>>? rowsSub;
    List<InstalledPlugin>? rows;
    void emit() {
      final current = rows;
      if (current != null && !out.isClosed) out.add(_merge(current));
    }

    out = StreamController<List<InstalledPluginRecord>>(
      onListen: () {
        granted.addListener(emit);
        rowsSub = query.watch().listen((next) {
          rows = next;
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        granted.removeListener(emit);
        await rowsSub?.cancel();
      },
    );
    return out.stream;
  }

  List<InstalledPluginRecord> _merge(List<InstalledPlugin> rows) {
    final ids = granted.value.where(kGrantedOnlyPlugins.containsKey);
    _grantedSince.removeWhere((id, _) => !ids.contains(id));
    return [
      for (final row in rows)
        if (!kGrantedOnlyPlugins.containsKey(row.pluginId)) _toRecord(row),
      for (final id in ids)
        InstalledPluginRecord(
          pluginId: id,
          name: kGrantedOnlyPlugins[id]!.name,
          icon: kGrantedOnlyPlugins[id]!.icon,
          version: '1.0.0',
          installedAt: _grantedSince.putIfAbsent(id, DateTime.now),
          downloadCount: 0,
        ),
    ];
  }

  Future<void> install(PluginCatalogEntry entry) async {
    if (kGrantedOnlyPlugins.containsKey(entry.id)) {
      throw StateError('${entry.id} is granted by the admin, not downloaded.');
    }
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

  /// Plugins that were folded into another one, keyed by the plugin that now
  /// holds them. The merged plugin's manifest values are inlined so the
  /// migration runs offline at startup.
  static const _mergedPlugins = {
    'game-tools': (
      name: 'Game Tools',
      icon: 'sports_esports',
      version: '1.0.0',
      legacyIds: ['steam-tools', 'roblox-tools'],
    ),
  };

  /// Replaces installs of retired plugins with the plugin they were merged
  /// into, keeping the earliest install date so the nav rail order holds.
  /// An existing install of the merged plugin wins; legacy rows are dropped.
  Future<void> migrateMergedPlugins() async {
    for (final MapEntry(key: mergedId, value: merged)
        in _mergedPlugins.entries) {
      await _db.transaction(() async {
        final legacy = await (_db.select(_db.installedPlugins)
              ..where((t) => t.pluginId.isIn(merged.legacyIds))
              ..orderBy([(t) => OrderingTerm.asc(t.installedAt)]))
            .get();
        if (legacy.isEmpty) return;

        final existing = await (_db.select(_db.installedPlugins)
              ..where((t) => t.pluginId.equals(mergedId)))
            .getSingleOrNull();
        if (existing == null) {
          await _db.into(_db.installedPlugins).insert(
                InstalledPluginsCompanion.insert(
                  pluginId: mergedId,
                  name: merged.name,
                  icon: Value(merged.icon),
                  version: Value(merged.version),
                  installedAt: Value(legacy.first.installedAt),
                ),
              );
        }
        await (_db.delete(_db.installedPlugins)
              ..where((t) => t.pluginId.isIn(merged.legacyIds)))
            .go();
      });
    }
  }

  Future<void> uninstall(String pluginId) {
    if (kGrantedOnlyPlugins.containsKey(pluginId)) return Future.value();
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

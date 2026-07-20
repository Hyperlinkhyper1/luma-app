import 'dart:math';

import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/minecraft_launcher_database.dart';
import 'logic/offline_account_helper.dart';

class MinecraftLauncherRepository {
  MinecraftLauncherRepository(this._db);
  final MinecraftLauncherDatabase _db;

  /// A random, folder-name-safe id used both as the instance's primary key
  /// and its directory name under `minecraft/instances/`.
  static String _newInstanceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── Accounts ────────────────────────────────────────────────────────────

  Stream<List<McAccount>> watchAccounts() {
    final query = _db.select(_db.mcAccounts)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch();
  }

  Stream<McAccount?> watchActiveAccount() {
    final query = _db.select(_db.mcAccounts)
      ..where((t) => t.isActive.equals(true));
    return query.watchSingleOrNull();
  }

  /// Adds a local offline profile. No network call, no ownership check —
  /// works everywhere but can't join online-mode servers.
  Future<int> addOfflineAccount(String username) async {
    StorageGuard.instance.ensureWithinLimit();
    final id = await _db.into(_db.mcAccounts).insert(
          McAccountsCompanion.insert(
            type: 'offline',
            username: username,
            uuid: offlinePlayerUuid(username),
          ),
        );
    final hasActive = await (_db.select(_db.mcAccounts)
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();
    if (hasActive == null) await setActiveAccount(id);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<int> addOrUpdateMicrosoftAccount({
    required String username,
    required String uuid,
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
    String? avatarUrl,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final existing = await (_db.select(_db.mcAccounts)
          ..where((t) => t.type.equals('microsoft') & t.uuid.equals(uuid)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.mcAccounts)..where((t) => t.id.equals(existing.id)))
          .write(McAccountsCompanion(
        username: Value(username),
        accessToken: Value(accessToken),
        refreshToken: Value(refreshToken),
        accessTokenExpiresAt: Value(accessTokenExpiresAt),
        avatarUrl: Value(avatarUrl),
      ));
      StorageGuard.instance.scheduleRefresh();
      return existing.id;
    }
    final id = await _db.into(_db.mcAccounts).insert(
          McAccountsCompanion.insert(
            type: 'microsoft',
            username: username,
            uuid: uuid,
            accessToken: Value(accessToken),
            refreshToken: Value(refreshToken),
            accessTokenExpiresAt: Value(accessTokenExpiresAt),
            avatarUrl: Value(avatarUrl),
          ),
        );
    final hasActive = await (_db.select(_db.mcAccounts)
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();
    if (hasActive == null) await setActiveAccount(id);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> setActiveAccount(int id) async {
    await _db.update(_db.mcAccounts).write(const McAccountsCompanion(isActive: Value(false)));
    await (_db.update(_db.mcAccounts)..where((t) => t.id.equals(id)))
        .write(const McAccountsCompanion(isActive: Value(true)));
  }

  Future<void> deleteAccount(int id) =>
      (_db.delete(_db.mcAccounts)..where((t) => t.id.equals(id))).go();

  // ── Instances ───────────────────────────────────────────────────────────

  Stream<List<McInstance>> watchInstances() {
    final query = _db.select(_db.mcInstances)
      ..orderBy([(t) => OrderingTerm.desc(t.lastPlayedAt)]);
    return query.watch();
  }

  Stream<McInstance?> watchInstance(String id) {
    final query = _db.select(_db.mcInstances)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull();
  }

  Future<String> createInstance({
    required String name,
    required String versionId,
    String loader = 'vanilla',
    String? loaderVersion,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final id = _newInstanceId();
    await _db.into(_db.mcInstances).insert(
          McInstancesCompanion.insert(
            id: id,
            name: name,
            versionId: versionId,
            loader: Value(loader),
            loaderVersion: Value(loaderVersion),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> updateInstanceSettings(
    String id, {
    String? name,
    int? minMemoryMb,
    int? maxMemoryMb,
    String? jvmArgs,
    String? javaPath,
    int? resolutionWidth,
    int? resolutionHeight,
    bool? fullscreen,
    String? iconPath,
  }) {
    return (_db.update(_db.mcInstances)..where((t) => t.id.equals(id))).write(
      McInstancesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        minMemoryMb: minMemoryMb == null ? const Value.absent() : Value(minMemoryMb),
        maxMemoryMb: maxMemoryMb == null ? const Value.absent() : Value(maxMemoryMb),
        jvmArgs: jvmArgs == null ? const Value.absent() : Value(jvmArgs),
        javaPath: javaPath == null ? const Value.absent() : Value(javaPath),
        resolutionWidth:
            resolutionWidth == null ? const Value.absent() : Value(resolutionWidth),
        resolutionHeight:
            resolutionHeight == null ? const Value.absent() : Value(resolutionHeight),
        fullscreen: fullscreen == null ? const Value.absent() : Value(fullscreen),
        iconPath: iconPath == null ? const Value.absent() : Value(iconPath),
      ),
    );
  }

  Future<void> markLaunched(String id) {
    return (_db.update(_db.mcInstances)..where((t) => t.id.equals(id)))
        .write(McInstancesCompanion(lastPlayedAt: Value(DateTime.now())));
  }

  Future<void> addPlayTime(String id, int seconds) async {
    final row = await (_db.select(_db.mcInstances)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.mcInstances)..where((t) => t.id.equals(id))).write(
      McInstancesCompanion(
        totalPlayTimeSeconds: Value(row.totalPlayTimeSeconds + seconds),
      ),
    );
  }

  Future<void> deleteInstance(String id) async {
    await (_db.delete(_db.mcLaunchHistory)..where((t) => t.instanceId.equals(id))).go();
    await (_db.delete(_db.mcInstances)..where((t) => t.id.equals(id))).go();
  }

  // ── Launch history ──────────────────────────────────────────────────────

  Future<int> recordLaunchStart(String instanceId) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.mcLaunchHistory).insert(
          McLaunchHistoryCompanion.insert(
            instanceId: instanceId,
            startedAt: DateTime.now(),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> recordLaunchEnd(int launchId, {int? exitCode, String? logFilePath}) {
    return (_db.update(_db.mcLaunchHistory)..where((t) => t.id.equals(launchId))).write(
      McLaunchHistoryCompanion(
        endedAt: Value(DateTime.now()),
        exitCode: exitCode == null ? const Value.absent() : Value(exitCode),
        logFilePath: logFilePath == null ? const Value.absent() : Value(logFilePath),
      ),
    );
  }

  Stream<List<McLaunchHistoryData>> watchLaunchHistory(String instanceId) {
    final query = _db.select(_db.mcLaunchHistory)
      ..where((t) => t.instanceId.equals(instanceId))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return query.watch();
  }

  // ── Installed mods/resource packs/shader packs/datapacks ──────────────────

  Stream<List<McInstalledMod>> watchInstalledContent(String instanceId, {String? kind}) {
    final query = _db.select(_db.mcInstalledMods)
      ..where((t) => t.instanceId.equals(instanceId))
      ..orderBy([(t) => OrderingTerm.asc(t.fileName)]);
    if (kind != null) query.where((t) => t.kind.equals(kind));
    return query.watch();
  }

  Future<bool> isProjectInstalled(String instanceId, String projectId) async {
    final row = await (_db.select(_db.mcInstalledMods)
          ..where((t) => t.instanceId.equals(instanceId) & t.projectId.equals(projectId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<int> recordInstalledContent({
    required String instanceId,
    String? projectId,
    String? versionId,
    String? projectName,
    String? projectIconUrl,
    required String fileName,
    String? sha1,
    String kind = 'mod',
  }) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.mcInstalledMods).insert(
          McInstalledModsCompanion.insert(
            instanceId: instanceId,
            projectId: Value(projectId),
            versionId: Value(versionId),
            projectName: Value(projectName),
            projectIconUrl: Value(projectIconUrl),
            fileName: fileName,
            sha1: Value(sha1),
            kind: Value(kind),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> setContentEnabled(int id, bool enabled) {
    return (_db.update(_db.mcInstalledMods)..where((t) => t.id.equals(id)))
        .write(McInstalledModsCompanion(enabled: Value(enabled)));
  }

  Future<void> deleteInstalledContent(int id) =>
      (_db.delete(_db.mcInstalledMods)..where((t) => t.id.equals(id))).go();
}

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../../l10n/current_l.dart';
import '../../../../security/authenticated_cipher.dart';
import '../../../../security/secure_secret_store.dart';
import '../../../../storage/storage_guard.dart';
import 'data/minecraft_launcher_database.dart';
import 'logic/offline_account_helper.dart';

class MinecraftLauncherRepository {
  MinecraftLauncherRepository(this._db, {SecureSecretStore? secretStore})
    : _secretStore = secretStore ?? SecureSecretStore.instance {
    _ready = _open();
    _ready.ignore();
  }

  static const tokenKeyName = 'minecraft_launcher_tokens.key';
  static const _tokenPrefix = 'enc:v1:';
  final MinecraftLauncherDatabase _db;
  final SecureSecretStore _secretStore;
  late final Future<void> _ready;
  late final Uint8List _tokenKey;

  Future<void> _open() async {
    final accounts = await _db.select(_db.mcAccounts).get();
    _tokenKey = await _secretStore.loadKey(
      tokenKeyName,
      hasEncryptedData: () async => accounts.any(
        (account) =>
            _isEncrypted(account.accessToken) ||
            _isEncrypted(account.refreshToken),
      ),
    );
    await _db.transaction(() async {
      for (final account in accounts) {
        if (account.type != 'microsoft') continue;
        if (_secretStore.lostKeys.contains(tokenKeyName) &&
            (_isEncrypted(account.accessToken) ||
                _isEncrypted(account.refreshToken)) &&
            requiresSignIn(_decodeAccount(account))) {
          await (_db.update(
            _db.mcAccounts,
          )..where((table) => table.id.equals(account.id))).write(
            const McAccountsCompanion(
              accessToken: Value(null),
              refreshToken: Value(null),
              accessTokenExpiresAt: Value(null),
            ),
          );
          continue;
        }
        final access = _migrateToken(
          account.accessToken,
          account.uuid,
          'access',
        );
        final refresh = _migrateToken(
          account.refreshToken,
          account.uuid,
          'refresh',
        );
        if (access != account.accessToken || refresh != account.refreshToken) {
          await (_db.update(
            _db.mcAccounts,
          )..where((table) => table.id.equals(account.id))).write(
            McAccountsCompanion(
              accessToken: Value(access),
              refreshToken: Value(refresh),
            ),
          );
        }
      }
    });
  }

  static bool _isEncrypted(String? token) => token?.startsWith('enc:') ?? false;

  String? _migrateToken(String? token, String uuid, String kind) =>
      token == null || _isEncrypted(token)
      ? token
      : _sealToken(token, uuid, kind);

  String _sealToken(String token, String uuid, String kind) =>
      '$_tokenPrefix${base64Encode(AuthenticatedCipher.seal(utf8.encode(token), _tokenKey, 'luma-minecraft:$uuid:$kind'))}';

  String? _openToken(String? token, String uuid, String kind) {
    if (token == null) return null;
    if (!token.startsWith(_tokenPrefix)) {
      throw const FormatException('Unsupported Minecraft token envelope');
    }
    return utf8.decode(
      AuthenticatedCipher.open(
        base64Decode(token.substring(_tokenPrefix.length)),
        _tokenKey,
        'luma-minecraft:$uuid:$kind',
      ),
    );
  }

  McAccount _decodeAccount(McAccount account) {
    if (account.type != 'microsoft') return account;
    try {
      return account.copyWith(
        accessToken: Value(
          _openToken(account.accessToken, account.uuid, 'access'),
        ),
        refreshToken: Value(
          _openToken(account.refreshToken, account.uuid, 'refresh'),
        ),
      );
    } catch (_) {
      return account.copyWith(
        accessToken: const Value(null),
        refreshToken: const Value(null),
        accessTokenExpiresAt: const Value(null),
      );
    }
  }

  static bool requiresSignIn(McAccount account) =>
      account.type == 'microsoft' &&
      ((account.accessToken?.isEmpty ?? true) ||
          (account.refreshToken?.isEmpty ?? true));

  /// A random, folder-name-safe id used both as the instance's primary key
  /// and its directory name under `minecraft/instances/`.
  static String _newInstanceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // â”€â”€ Accounts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Stream<List<McAccount>> watchAccounts() async* {
    await _ready;
    final query = _db.select(_db.mcAccounts)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    yield* query.watch().map((rows) => rows.map(_decodeAccount).toList());
  }

  Stream<McAccount?> watchActiveAccount() async* {
    await _ready;
    final query = _db.select(_db.mcAccounts)
      ..where((t) => t.isActive.equals(true));
    yield* query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      final account = _decodeAccount(row);
      return requiresSignIn(account) ? null : account;
    });
  }

  /// Whether any Microsoft account has ever been added on this device. A
  /// successful Microsoft sign-in already fails with
  /// [MicrosoftAuthException] when the account doesn't own Minecraft (see
  /// `microsoft_auth_client.dart`'s profile-lookup 404 check), so its
  /// presence here is the ownership proof offline accounts piggyback on.
  Future<bool> hasVerifiedOwnership() async {
    await _ready;
    final row =
        await (_db.select(_db.mcAccounts)
              ..where((t) => t.type.equals('microsoft'))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Adds a local offline profile. luma never bundles or authorises the
  /// game itself, so this only works once at least one Microsoft account
  /// that owns Minecraft has been added on this device â€” offline mode is
  /// then just a convenience for playing without a network connection, not
  /// a way to skip proving ownership. Throws [StateError] otherwise.
  Future<int> addOfflineAccount(String username) async {
    if (!await hasVerifiedOwnership()) {
      throw StateError(currentL.minecraftLauncherOfflineNeedsMicrosoft);
    }
    final id = await _db
        .into(_db.mcAccounts)
        .insert(
          McAccountsCompanion.insert(
            type: 'offline',
            username: username,
            uuid: offlinePlayerUuid(username),
          ),
        );
    final hasActive = await (_db.select(
      _db.mcAccounts,
    )..where((t) => t.isActive.equals(true))).getSingleOrNull();
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
    await _ready;
    final encryptedAccess = _sealToken(accessToken, uuid, 'access');
    final encryptedRefresh = _sealToken(refreshToken, uuid, 'refresh');
    final existing =
        await (_db.select(_db.mcAccounts)
              ..where((t) => t.type.equals('microsoft') & t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.mcAccounts,
      )..where((t) => t.id.equals(existing.id))).write(
        McAccountsCompanion(
          username: Value(username),
          accessToken: Value(encryptedAccess),
          refreshToken: Value(encryptedRefresh),
          accessTokenExpiresAt: Value(accessTokenExpiresAt),
          avatarUrl: Value(avatarUrl),
        ),
      );
      StorageGuard.instance.scheduleRefresh();
      return existing.id;
    }
    final id = await _db
        .into(_db.mcAccounts)
        .insert(
          McAccountsCompanion.insert(
            type: 'microsoft',
            username: username,
            uuid: uuid,
            accessToken: Value(encryptedAccess),
            refreshToken: Value(encryptedRefresh),
            accessTokenExpiresAt: Value(accessTokenExpiresAt),
            avatarUrl: Value(avatarUrl),
          ),
        );
    final hasActive = await (_db.select(
      _db.mcAccounts,
    )..where((t) => t.isActive.equals(true))).getSingleOrNull();
    if (hasActive == null) await setActiveAccount(id);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> setActiveAccount(int id) async {
    await _ready;
    await _db
        .update(_db.mcAccounts)
        .write(const McAccountsCompanion(isActive: Value(false)));
    await (_db.update(_db.mcAccounts)..where((t) => t.id.equals(id))).write(
      const McAccountsCompanion(isActive: Value(true)),
    );
  }

  Future<void> deleteAccount(int id) async {
    await _ready;
    await (_db.delete(_db.mcAccounts)..where((t) => t.id.equals(id))).go();
  }

  // â”€â”€ Instances â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    final id = _newInstanceId();
    await _db
        .into(_db.mcInstances)
        .insert(
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
        minMemoryMb: minMemoryMb == null
            ? const Value.absent()
            : Value(minMemoryMb),
        maxMemoryMb: maxMemoryMb == null
            ? const Value.absent()
            : Value(maxMemoryMb),
        jvmArgs: jvmArgs == null ? const Value.absent() : Value(jvmArgs),
        javaPath: javaPath == null ? const Value.absent() : Value(javaPath),
        resolutionWidth: resolutionWidth == null
            ? const Value.absent()
            : Value(resolutionWidth),
        resolutionHeight: resolutionHeight == null
            ? const Value.absent()
            : Value(resolutionHeight),
        fullscreen: fullscreen == null
            ? const Value.absent()
            : Value(fullscreen),
        iconPath: iconPath == null ? const Value.absent() : Value(iconPath),
      ),
    );
  }

  Future<void> markLaunched(String id) {
    return (_db.update(_db.mcInstances)..where((t) => t.id.equals(id))).write(
      McInstancesCompanion(lastPlayedAt: Value(DateTime.now())),
    );
  }

  Future<void> addPlayTime(String id, int seconds) async {
    final row = await (_db.select(
      _db.mcInstances,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.mcInstances)..where((t) => t.id.equals(id))).write(
      McInstancesCompanion(
        totalPlayTimeSeconds: Value(row.totalPlayTimeSeconds + seconds),
      ),
    );
  }

  Future<void> deleteInstance(String id) async {
    await (_db.delete(
      _db.mcLaunchHistory,
    )..where((t) => t.instanceId.equals(id))).go();
    await (_db.delete(_db.mcInstances)..where((t) => t.id.equals(id))).go();
  }

  // â”€â”€ Launch history â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<int> recordLaunchStart(String instanceId) {
    final future = _db
        .into(_db.mcLaunchHistory)
        .insert(
          McLaunchHistoryCompanion.insert(
            instanceId: instanceId,
            startedAt: DateTime.now(),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> recordLaunchEnd(
    int launchId, {
    int? exitCode,
    String? logFilePath,
  }) {
    return (_db.update(
      _db.mcLaunchHistory,
    )..where((t) => t.id.equals(launchId))).write(
      McLaunchHistoryCompanion(
        endedAt: Value(DateTime.now()),
        exitCode: exitCode == null ? const Value.absent() : Value(exitCode),
        logFilePath: logFilePath == null
            ? const Value.absent()
            : Value(logFilePath),
      ),
    );
  }

  Stream<List<McLaunchHistoryData>> watchLaunchHistory(String instanceId) {
    final query = _db.select(_db.mcLaunchHistory)
      ..where((t) => t.instanceId.equals(instanceId))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return query.watch();
  }

  // â”€â”€ Installed mods/resource packs/shader packs/datapacks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Stream<List<McInstalledMod>> watchInstalledContent(
    String instanceId, {
    String? kind,
  }) {
    final query = _db.select(_db.mcInstalledMods)
      ..where((t) => t.instanceId.equals(instanceId))
      ..orderBy([(t) => OrderingTerm.asc(t.fileName)]);
    if (kind != null) query.where((t) => t.kind.equals(kind));
    return query.watch();
  }

  Future<bool> isProjectInstalled(String instanceId, String projectId) async {
    final row =
        await (_db.select(_db.mcInstalledMods)..where(
              (t) =>
                  t.instanceId.equals(instanceId) &
                  t.projectId.equals(projectId),
            ))
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
    final future = _db
        .into(_db.mcInstalledMods)
        .insert(
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

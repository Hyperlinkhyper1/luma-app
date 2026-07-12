import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'activity.dart';
import 'metrics_history.dart';
import 'util.dart';

/// Storage quota granted by each plan tier, in bytes. Mirrors the
/// client-side `Plan.storageMb` values in lib/account/plan.dart — keep the
/// two in sync if either changes. Granted/revoked by an admin (see
/// Api._adminSetPlan); 'core' is the default, free tier every account
/// starts on.
const kPlanQuotaBytes = <String, int>{
  'core': 10 * 1024 * 1024,
  'orbit': 25 * 1024 * 1024,
  'nova': 50 * 1024 * 1024,
};

const kDefaultPlanId = 'core';

/// A registered account. The server never sees the user's real password:
/// [authHash] is a slow hash of the *derived* login key the client sends,
/// and [kdfSalt]/[kdfIterations] are the public parameters the client needs
/// to re-derive its keys on a new device.
class StoredUser {
  StoredUser({
    required this.id,
    required this.email,
    required this.authHash,
    required this.authSalt,
    required this.kdfSalt,
    required this.kdfIterations,
    required this.quotaBytes,
    required this.createdAtMs,
    this.status = 'active',
    this.verificationTokenHash,
    this.verificationExpiresAtMs,
    this.lastLoginAtMs,
    this.planId = kDefaultPlanId,
  });

  final String id;
  String email;
  String authHash; // base64 of PBKDF2(authKey, authSalt)
  String authSalt; // base64
  String kdfSalt; // base64, client-side KDF salt (public)
  int kdfIterations;
  int quotaBytes;
  final int createdAtMs;

  /// 'core' (free), 'orbit', or 'nova' — see [kPlanQuotaBytes]. Granted by
  /// an admin via the /admin/plan endpoint; [quotaBytes] is kept in sync
  /// with whatever this is set to (see Store.open's migration pass).
  String planId;

  /// Set each time a login succeeds; null if the account has never logged in
  /// since this field was added.
  int? lastLoginAtMs;

  /// 'pending' until the email is verified, then 'active'. Accounts created
  /// before this field existed default to 'active' so they keep working.
  String status;

  /// SHA-256 of the current email-verification token, or null if there is
  /// none outstanding (never verified yet, or already verified/used).
  String? verificationTokenHash;
  int? verificationExpiresAtMs;

  bool get isPending => status == 'pending';

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'authHash': authHash,
        'authSalt': authSalt,
        'kdfSalt': kdfSalt,
        'kdfIterations': kdfIterations,
        'quotaBytes': quotaBytes,
        'createdAtMs': createdAtMs,
        'status': status,
        'verificationTokenHash': verificationTokenHash,
        'verificationExpiresAtMs': verificationExpiresAtMs,
        'lastLoginAtMs': lastLoginAtMs,
        'planId': planId,
      };

  factory StoredUser.fromJson(Map<String, dynamic> j) => StoredUser(
        id: j['id'] as String,
        email: j['email'] as String,
        authHash: j['authHash'] as String,
        authSalt: j['authSalt'] as String,
        kdfSalt: j['kdfSalt'] as String,
        kdfIterations: j['kdfIterations'] as int,
        quotaBytes: j['quotaBytes'] as int,
        createdAtMs: j['createdAtMs'] as int,
        status: j['status'] as String? ?? 'active',
        verificationTokenHash: j['verificationTokenHash'] as String?,
        verificationExpiresAtMs: j['verificationExpiresAtMs'] as int?,
        lastLoginAtMs: j['lastLoginAtMs'] as int?,
        planId: j['planId'] as String? ?? kDefaultPlanId,
      );
}

/// A login session. Only the SHA-256 of the bearer token is stored, so a
/// leaked data directory does not yield usable tokens.
class StoredSession {
  StoredSession({
    required this.tokenHash,
    required this.userId,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  final String tokenHash;
  final String userId;
  final int createdAtMs;
  int expiresAtMs;

  Map<String, dynamic> toJson() => {
        'tokenHash': tokenHash,
        'userId': userId,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
      };

  factory StoredSession.fromJson(Map<String, dynamic> j) => StoredSession(
        tokenHash: j['tokenHash'] as String,
        userId: j['userId'] as String,
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
      );
}

/// Metadata for one synced collection (the blob itself lives on disk).
class CollectionMeta {
  CollectionMeta({
    required this.name,
    required this.version,
    required this.size,
    required this.payloadSavedAtMs,
    required this.updatedAtMs,
  });

  final String name;
  int version;
  int size;
  int payloadSavedAtMs;
  int updatedAtMs;

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'size': size,
        'payloadSavedAtMs': payloadSavedAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory CollectionMeta.fromJson(Map<String, dynamic> j) => CollectionMeta(
        name: j['name'] as String,
        version: j['version'] as int,
        size: j['size'] as int,
        payloadSavedAtMs: j['payloadSavedAtMs'] as int,
        updatedAtMs: j['updatedAtMs'] as int,
      );
}

/// File-backed store. Everything is held in memory and written through to
/// JSON files with atomic replace; blobs are stored as individual files.
/// All mutations must go through [lock] (the API layer does this).
class Store {
  Store._(this.rootPath);

  final String rootPath;
  final AsyncLock lock = AsyncLock();

  final Map<String, StoredUser> usersById = {};
  final Map<String, String> userIdByEmail = {}; // lowercased email -> id
  final Map<String, StoredSession> sessionsByTokenHash = {};
  final Map<String, Map<String, CollectionMeta>> collectionsByUser = {};

  /// Admin dashboard's "Activity" feed, newest last. Capped at
  /// [_maxActivityEvents] so the file can't grow unbounded on a long-lived
  /// server; callers only ever display the last 24h anyway (see
  /// Api._adminActivity).
  final List<ActivityEvent> activity = [];
  static const _maxActivityEvents = 2000;

  /// Admin dashboard's "Metrics" graphs history — see MetricsHistory for the
  /// downsampling/persistence scheme. Set during [open].
  late final MetricsHistory metricsHistory;

  /// Random secret used to fabricate stable fake KDF salts for unknown
  /// emails (prevents account enumeration via the params endpoint).
  late final Uint8List serverSecret;

  String get _usersFile => '$rootPath/users.json';
  String get _sessionsFile => '$rootPath/sessions.json';
  String get _collectionsFile => '$rootPath/collections.json';
  String get _activityFile => '$rootPath/activity.json';
  String get _secretFile => '$rootPath/secret.key';

  static Future<Store> open(String path) async {
    final store = Store._(path);
    await Directory(path).create(recursive: true);
    await Directory('$path/blobs').create(recursive: true);

    final secretFile = File(store._secretFile);
    if (await secretFile.exists()) {
      store.serverSecret =
          Uint8List.fromList(base64Decode((await secretFile.readAsString()).trim()));
    } else {
      store.serverSecret = randomBytes(32);
      await atomicWriteString(store._secretFile, base64Encode(store.serverSecret));
    }

    final users = await _readJsonList(store._usersFile);
    var quotasMigrated = false;
    for (final u in users) {
      final user = StoredUser.fromJson(u as Map<String, dynamic>);
      // Keep quota in sync with the plan map — covers accounts created
      // before plans existed, and lets changing kPlanQuotaBytes apply
      // retroactively to everyone on the next restart.
      final planQuota = kPlanQuotaBytes[user.planId];
      if (planQuota != null && user.quotaBytes != planQuota) {
        user.quotaBytes = planQuota;
        quotasMigrated = true;
      }
      store.usersById[user.id] = user;
      store.userIdByEmail[user.email.toLowerCase()] = user.id;
    }
    if (quotasMigrated) await store.saveUsers();

    final sessions = await _readJsonList(store._sessionsFile);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in sessions) {
      final session = StoredSession.fromJson(s as Map<String, dynamic>);
      if (session.expiresAtMs > now && store.usersById.containsKey(session.userId)) {
        store.sessionsByTokenHash[session.tokenHash] = session;
      }
    }

    final collections = await _readJsonMap(store._collectionsFile);
    collections.forEach((userId, value) {
      if (!store.usersById.containsKey(userId)) return;
      final perUser = <String, CollectionMeta>{};
      (value as Map<String, dynamic>).forEach((name, meta) {
        perUser[name] = CollectionMeta.fromJson(meta as Map<String, dynamic>);
      });
      store.collectionsByUser[userId] = perUser;
    });

    final activity = await _readJsonList(store._activityFile);
    for (final a in activity) {
      store.activity.add(ActivityEvent.fromJson(a as Map<String, dynamic>));
    }

    store.metricsHistory = await MetricsHistory.open(path);

    return store;
  }

  static Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    return decoded is List ? decoded : const [];
  }

  static Future<Map<String, dynamic>> _readJsonMap(String path) async {
    final file = File(path);
    if (!await file.exists()) return const {};
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  // ---- Persistence -------------------------------------------------------

  Future<void> saveUsers() => atomicWriteString(
      _usersFile, jsonEncode(usersById.values.map((u) => u.toJson()).toList()));

  Future<void> saveSessions() => atomicWriteString(_sessionsFile,
      jsonEncode(sessionsByTokenHash.values.map((s) => s.toJson()).toList()));

  Future<void> saveCollections() => atomicWriteString(
      _collectionsFile,
      jsonEncode(collectionsByUser.map((userId, perUser) => MapEntry(
          userId, perUser.map((name, m) => MapEntry(name, m.toJson()))))));

  Future<void> saveActivity() => atomicWriteString(
      _activityFile, jsonEncode(activity.map((a) => a.toJson()).toList()));

  /// Appends one event to the activity feed and persists it. Caller holds
  /// [lock] (mirrors every other mutation in this class).
  Future<void> logActivity(String type, String message) async {
    activity.add(ActivityEvent(
      type: type,
      message: message,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (activity.length > _maxActivityEvents) {
      activity.removeRange(0, activity.length - _maxActivityEvents);
    }
    await saveActivity();
  }

  // ---- Blobs -------------------------------------------------------------

  String blobPath(String userId, String collection) =>
      '$rootPath/blobs/$userId/$collection.bin';

  Future<void> writeBlob(String userId, String collection, List<int> bytes) async {
    await Directory('$rootPath/blobs/$userId').create(recursive: true);
    await atomicWriteBytes(blobPath(userId, collection), bytes);
  }

  Future<Uint8List?> readBlob(String userId, String collection) async {
    final file = File(blobPath(userId, collection));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteBlob(String userId, String collection) async {
    final file = File(blobPath(userId, collection));
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteUserData(String userId) async {
    final dir = Directory('$rootPath/blobs/$userId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ---- Queries -----------------------------------------------------------

  int usedBytes(String userId) {
    final perUser = collectionsByUser[userId];
    if (perUser == null) return 0;
    return perUser.values.fold(0, (sum, m) => sum + m.size);
  }

  /// Drops expired sessions from memory (persisted on the next session save).
  void pruneSessions() {
    final now = DateTime.now().millisecondsSinceEpoch;
    sessionsByTokenHash.removeWhere((_, s) => s.expiresAtMs <= now);
  }
}

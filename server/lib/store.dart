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
  'core': 5 * 1024 * 1024,
  'orbit': 15 * 1024 * 1024,
  'nova': 30 * 1024 * 1024,
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
    this.passwordResetRequiredAtMs,
    Map<String, String>? oauthSubjects,
  }) : oauthSubjects = oauthSubjects ?? {};

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

  /// When an admin forced a password reset from the dashboard, or null when
  /// there is no reset outstanding.
  ///
  /// While this is set the old password no longer signs in — [_login]
  /// refuses with `password_reset_required`. Existing sessions are
  /// deliberately *kept*: sync is zero-knowledge, so only a device that
  /// still holds the current encryption key can re-seal the stored snapshots
  /// under the new password (see Api._resetPassword, which mirrors
  /// SyncService.changePassword's re-encryption pass). Cleared by finishing
  /// the reset, by an ordinary password change, or by the admin cancelling.
  int? passwordResetRequiredAtMs;

  bool get passwordResetRequired => passwordResetRequiredAtMs != null;

  /// SHA-256 of the current email-verification token, or null if there is
  /// none outstanding (never verified yet, or already verified/used).
  String? verificationTokenHash;
  int? verificationExpiresAtMs;

  /// Provider id ('google', 'github') -> that provider's immutable user id,
  /// for every identity linked to this account. Written the first time
  /// someone signs in with a provider whose *verified* address matches
  /// [email]; an account can carry both at once, and a password set here
  /// keeps working alongside them.
  ///
  /// The subject is kept rather than just a "linked" flag so a later email
  /// change at the provider still resolves back to this account.
  final Map<String, String> oauthSubjects;

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
        'passwordResetRequiredAtMs': passwordResetRequiredAtMs,
        'oauthSubjects': oauthSubjects,
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
        passwordResetRequiredAtMs: j['passwordResetRequiredAtMs'] as int?,
        oauthSubjects: (j['oauthSubjects'] as Map?)
            ?.map((k, v) => MapEntry('$k', '$v')),
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
    this.deviceLabel,
  });

  final String tokenHash;
  final String userId;
  final int createdAtMs;
  int expiresAtMs;

  /// Human-readable device/platform string the client sent at login (e.g.
  /// "windows", "android") — display-only, never used for auth. Null for
  /// sessions created before this field existed.
  String? deviceLabel;

  Map<String, dynamic> toJson() => {
        'tokenHash': tokenHash,
        'userId': userId,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
        'deviceLabel': deviceLabel,
      };

  factory StoredSession.fromJson(Map<String, dynamic> j) => StoredSession(
        tokenHash: j['tokenHash'] as String,
        userId: j['userId'] as String,
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
        deviceLabel: j['deviceLabel'] as String?,
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

/// One plugin's aggregate download count for the admin dashboard's "Plugins"
/// tab — see Api._reportPluginDownload. [name] is overwritten by whatever the
/// client last reported, so a plugin rename in the registry updates it here
/// too without any server-side catalog lookup.
class PluginDownloadStat {
  PluginDownloadStat({
    required this.pluginId,
    required this.name,
    required this.count,
    required this.lastDownloadedAtMs,
  });

  final String pluginId;
  String name;
  int count;
  int lastDownloadedAtMs;

  Map<String, dynamic> toJson() => {
        'pluginId': pluginId,
        'name': name,
        'count': count,
        'lastDownloadedAtMs': lastDownloadedAtMs,
      };

  factory PluginDownloadStat.fromJson(Map<String, dynamic> j) =>
      PluginDownloadStat(
        pluginId: j['pluginId'] as String,
        name: j['name'] as String,
        count: j['count'] as int,
        lastDownloadedAtMs: j['lastDownloadedAtMs'] as int,
      );
}

/// One account-data deletion the user asked for from inside the app, waiting
/// on the operator in the admin dashboard's Inbox tab.
///
/// The app never deletes anything server-side through this path: it only
/// files the request (with the user's own reason), and the operator accepts
/// or declines it. Accepting runs the same teardown as the self-service
/// delete (Api._deleteAccount); declining leaves the account untouched and
/// hands the user back the operator's note.
class DeletionRequest {
  DeletionRequest({
    required this.id,
    required this.userId,
    required this.email,
    required this.reason,
    required this.createdAtMs,
    this.status = statusPending,
    this.decidedAtMs,
    this.adminNote,
  });

  static const statusPending = 'pending';
  static const statusAccepted = 'accepted';
  static const statusDeclined = 'declined';

  final String id;

  /// The account the request was filed for. Stays on the record after an
  /// accepted request wiped the account, so the Inbox keeps its history.
  final String userId;
  final String email;

  /// Why the user wants their data gone, in their own words. Free text —
  /// always escape it before rendering.
  final String reason;

  final int createdAtMs;

  /// [statusPending], [statusAccepted] or [statusDeclined].
  String status;
  int? decidedAtMs;

  /// Optional note the operator left when deciding — shown to the user in
  /// the app so a decline can say why.
  String? adminNote;

  bool get isPending => status == statusPending;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'email': email,
        'reason': reason,
        'createdAtMs': createdAtMs,
        'status': status,
        'decidedAtMs': decidedAtMs,
        'adminNote': adminNote,
      };

  factory DeletionRequest.fromJson(Map<String, dynamic> j) => DeletionRequest(
        id: j['id'] as String,
        userId: j['userId'] as String,
        email: j['email'] as String,
        reason: j['reason'] as String? ?? '',
        createdAtMs: j['createdAtMs'] as int,
        status: j['status'] as String? ?? statusPending,
        decidedAtMs: j['decidedAtMs'] as int?,
        adminNote: j['adminNote'] as String?,
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

  /// "<provider>:<subject>" -> user id, for accounts with a linked Google or
  /// GitHub identity. Rebuilt from [StoredUser.oauthSubjects] on open; see
  /// [oauthKey] and [linkOAuthIdentity].
  final Map<String, String> userIdByOAuth = {};

  final Map<String, StoredSession> sessionsByTokenHash = {};
  final Map<String, Map<String, CollectionMeta>> collectionsByUser = {};

  /// Admin dashboard's "Activity" feed, newest last. Capped at
  /// [_maxActivityEvents] so the file can't grow unbounded on a long-lived
  /// server; callers only ever display the last 24h anyway (see
  /// Api._adminActivity).
  final List<ActivityEvent> activity = [];
  static const _maxActivityEvents = 2000;

  /// Admin dashboard's "Plugins" tab — per-plugin download counts reported
  /// by clients on install (see Api._reportPluginDownload). Keyed by
  /// pluginId.
  final Map<String, PluginDownloadStat> pluginDownloadsById = {};

  /// Admin dashboard's "Inbox" tab — account-data deletion requests filed
  /// from the app, newest last. Keyed by request id; at most one pending
  /// request per account (see Api._requestAccountDeletion).
  final Map<String, DeletionRequest> deletionRequestsById = {};

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
  String get _pluginDownloadsFile => '$rootPath/plugin_downloads.json';
  String get _deletionRequestsFile => '$rootPath/deletion_requests.json';
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
      user.oauthSubjects.forEach((provider, subject) {
        store.userIdByOAuth[oauthKey(provider, subject)] = user.id;
      });
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

    final pluginDownloads = await _readJsonList(store._pluginDownloadsFile);
    for (final p in pluginDownloads) {
      final stat = PluginDownloadStat.fromJson(p as Map<String, dynamic>);
      store.pluginDownloadsById[stat.pluginId] = stat;
    }

    final deletionRequests = await _readJsonList(store._deletionRequestsFile);
    for (final r in deletionRequests) {
      final req = DeletionRequest.fromJson(r as Map<String, dynamic>);
      store.deletionRequestsById[req.id] = req;
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

  // ---- OAuth identities --------------------------------------------------

  /// Index key for [userIdByOAuth].
  static String oauthKey(String provider, String subject) =>
      '$provider:$subject';

  /// Records that [user] owns [subject] at [provider], so a later sign-in
  /// resolves to this account even if the address at the provider changes.
  /// Caller holds [lock] and saves.
  void linkOAuthIdentity(StoredUser user, String provider, String subject) {
    final previous = user.oauthSubjects[provider];
    if (previous == subject) return;
    if (previous != null) userIdByOAuth.remove(oauthKey(provider, previous));
    user.oauthSubjects[provider] = subject;
    userIdByOAuth[oauthKey(provider, subject)] = user.id;
  }

  /// Drops every OAuth link held by [user] — part of deleting the account.
  void unlinkAllOAuthIdentities(StoredUser user) {
    user.oauthSubjects.forEach(
        (provider, subject) => userIdByOAuth.remove(oauthKey(provider, subject)));
    user.oauthSubjects.clear();
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

  Future<void> savePluginDownloads() => atomicWriteString(
      _pluginDownloadsFile,
      jsonEncode(pluginDownloadsById.values.map((p) => p.toJson()).toList()));

  /// Records one plugin install/download and persists it. Caller holds
  /// [lock] (mirrors every other mutation in this class).
  Future<void> recordPluginDownload(String pluginId, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = pluginDownloadsById[pluginId];
    if (existing == null) {
      pluginDownloadsById[pluginId] = PluginDownloadStat(
        pluginId: pluginId,
        name: name,
        count: 1,
        lastDownloadedAtMs: now,
      );
    } else {
      existing.name = name;
      existing.count++;
      existing.lastDownloadedAtMs = now;
    }
    await savePluginDownloads();
  }

  Future<void> saveDeletionRequests() => atomicWriteString(
      _deletionRequestsFile,
      jsonEncode(deletionRequestsById.values.map((r) => r.toJson()).toList()));

  /// The account's open deletion request, or null when it has none.
  DeletionRequest? pendingDeletionRequestFor(String userId) {
    for (final r in deletionRequestsById.values) {
      if (r.userId == userId && r.isPending) return r;
    }
    return null;
  }

  /// The account's most recent deletion request whatever its state — what the
  /// app shows so a decline (and the operator's note) is visible once.
  DeletionRequest? latestDeletionRequestFor(String userId) {
    DeletionRequest? newest;
    for (final r in deletionRequestsById.values) {
      if (r.userId != userId) continue;
      if (newest == null || r.createdAtMs > newest.createdAtMs) newest = r;
    }
    return newest;
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

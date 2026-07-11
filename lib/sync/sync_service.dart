import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256, Hmac;
import 'package:flutter/foundation.dart';

import '../storage/storage_guard.dart';
import 'sync_api.dart';
import 'sync_collections.dart';
import 'sync_crypto.dart';
import 'sync_state.dart';

enum SyncStatus { idle, syncing, error }

/// Thrown by [SyncService.enableCollection] when the current plan's limit
/// on the number of synced collections is already reached.
class SyncLimitExceededException implements Exception {
  const SyncLimitExceededException(this.limit);
  final int limit;

  @override
  String toString() =>
      'Your plan allows syncing up to $limit feature${limit == 1 ? '' : 's'} '
      'at once. Upgrade your plan to sync more.';
}

/// Orchestrates account state and synchronization.
///
/// Flow per enabled collection: snapshot the local data, compare against the
/// last synced state, then push, pull, or — when both sides changed — let the
/// newest edit win. Snapshots are end-to-end encrypted before upload; the
/// server only ever sees ciphertext.
class SyncService extends ChangeNotifier {
  SyncService({required this.collections, this.syncCollectionLimit});

  final List<SyncCollection> collections;

  /// Returns the current plan's cap on how many collections (besides the
  /// always-on 'settings' one) may be enabled at once, or null for
  /// unlimited. Read fresh on every check so plan changes apply immediately.
  final int? Function()? syncCollectionLimit;

  SyncStateStore? _state;
  SyncApi? _api;
  RemoteAccount? _account;

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  bool _requiresReauth = false;
  bool _importing = false;
  // One serialized chain for ALL mutations of synced collections, whether the
  // trigger is a cloud sync or a peer-to-peer import. `_syncTail` swallows
  // errors so one failed run can't poison the chain; each caller awaits its
  // own `run` future to observe its own outcome.
  Future<void> _syncTail = Future.value();

  Timer? _debounce;
  Timer? _periodic;
  final List<StreamSubscription<void>> _subscriptions = [];

  static const _debounceDelay = Duration(seconds: 8);
  // Without this, a device that hasn't edited anything itself only picks up
  // another device's changes on its next restart or a 15-minute wait — this
  // pulls much sooner so two signed-in devices converge close to live.
  static const _periodicInterval = Duration(seconds: 10);

  /// Tag bound into the ciphertext of every sealed snapshot, identifying the
  /// collection. P2P receivers reuse [applyPeerSnapshot] which checks this.
  static const _peerHandshakeTag = 'luma-p2p-handshake-v1';

  /// Tags for the LOCAL (serverless) account: the salt is derived from the
  /// email alone (not random) so any device that types the same email
  /// reproduces the same salt with no server to hand one out. Only the
  /// password's secrecy matters for security here — the email just keeps
  /// two different people's derivations from colliding.
  static const _localAccountSaltTag = 'luma-local-account-salt-v1';
  static const _localVerifierTag = 'luma-local-account-verify-v1';

  /// A deterministic, account-scoped token a peer presents to prove it is on
  /// the same account — derived (HMAC) from the encryption key. Revealing it
  /// gains nothing: blobs still need the real key, and the cloud server uses
  /// a separately derived auth key.
  String? peerHandshakeToken() {
    final key = _state?.encryptionKey;
    if (key == null) return null;
    final mac = Hmac(sha256, key)
        .convert(utf8.encode(_peerHandshakeTag))
        .bytes;
    return _hexEncode(mac);
  }

  // ---- Public state ----------------------------------------------------------

  bool get ready => _state != null;
  bool get signedIn => _state?.signedIn ?? false;
  bool get requiresReauth => _requiresReauth;
  String? get email => _state?.email;
  String? get serverUrl => _state?.serverUrl;

  /// The current bearer token, if signed in. Used by features (e.g. Families)
  /// that talk to their own, non-encrypted server endpoints rather than the
  /// zero-knowledge sync/blob ones — see [FamilyApi] in lib/family/family_api.dart.
  String? get authToken => _state?.token;
  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _state?.lastSyncAt;

  /// True once there's an encryption key at all — via a cloud account
  /// ([signedIn]) or a local-only, serverless identity ([isLocalOnly]). This
  /// is the actual gate for P2P: peers only need a shared key, not a server.
  bool get p2pReady => _state?.encryptionKey != null;

  /// True when [p2pReady] but the key did NOT come from a cloud account —
  /// i.e. set up purely for device-to-device sync via [setLocalAccount].
  bool get isLocalOnly => p2pReady && !signedIn;

  /// Latest known storage usage / quota, refreshed on every sync.
  RemoteAccount? get account => _account;

  bool isEnabled(String collectionId) =>
      _state?.collection(collectionId).enabled ?? false;

  // ---- Lifecycle -------------------------------------------------------------

  /// Loads persisted state and starts background syncing when signed in.
  Future<void> init() async {
    _state = await SyncStateStore.load();
    final s = _state!;
    if (!s.localAccountMigrated) {
      // One-time migration: local-only (serverless) identities predate the
      // plan-based server sync limits, so any device still using one is
      // reset back to "no account" and prompted to create a real cloud
      // account instead. Cloud accounts and fresh installs are unaffected.
      if (s.localVerifier != null) {
        s
          ..email = null
          ..encryptionKey = null
          ..kdfSalt = null
          ..kdfIterations = null
          ..localVerifier = null;
      }
      s.localAccountMigrated = true;
      await s.save();
    }
    if (s.signedIn) {
      _api = SyncApi(s.serverUrl!, token: s.token);
    }
    for (final collection in collections) {
      _subscriptions.add(
          collection.changes.listen((_) => _onLocalChange(collection.id)));
    }
    _periodic = Timer.periodic(_periodicInterval, (_) {
      if (signedIn) syncNow(silent: true);
    });
    notifyListeners();
    if (signedIn) {
      // Initial sync shortly after startup, off the critical path.
      Timer(const Duration(seconds: 3), () => syncNow(silent: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _api?.close();
    super.dispose();
  }

  void _onLocalChange(String collectionId) {
    if (_importing) return;
    final s = _state;
    if (s == null) return;
    final st = s.collection(collectionId);
    st.localChangedAt = DateTime.now();
    // Persist lazily along with the debounced sync.
    if (!signedIn || !st.enabled) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => syncNow(silent: true));
  }

  // ---- Account management ------------------------------------------------------

  /// Signs in to an existing account and starts syncing.
  Future<void> signIn({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    final s = _state ?? (_state = await SyncStateStore.load());
    final api = SyncApi(serverUrl);
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final params = await api.authParams(normalizedEmail);
      final keys = await SyncCrypto.deriveKeys(
        password: password,
        kdfSalt: params.kdfSalt,
        iterations: params.kdfIterations,
      );
      final token =
          await api.login(email: normalizedEmail, authKey: keys.authKey);
      api.token = token;

      _api?.close();
      _api = api;
      s
        ..serverUrl = api.baseUrl
        ..email = normalizedEmail
        ..token = token
        ..encryptionKey = keys.encryptionKey
        ..kdfSalt = params.kdfSalt
        ..kdfIterations = params.kdfIterations;
      // Fresh account on this device: forget previous sync bookkeeping.
      for (final st in s.collections.values) {
        st.lastSyncedVersion = null;
        st.lastSyncedHash = null;
      }
      _requiresReauth = false;
      _lastError = null;
      await s.save();
      notifyListeners();
      unawaited(syncNow(silent: true));
    } catch (_) {
      if (api != _api) api.close();
      rethrow;
    }
  }

  /// Creates a new account on the server. Returns null when the account is
  /// signed in immediately; returns a human-readable message when the
  /// server requires email verification first (the account exists, but the
  /// caller is NOT signed in yet — the user must verify, then [signIn]).
  Future<String?> register({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    final s = _state ?? (_state = await SyncStateStore.load());
    final api = SyncApi(serverUrl);
    try {
      final normalizedEmail = email.trim().toLowerCase();
      // If this device already has a local-only (serverless) identity for
      // the SAME email, reuse its salt so the resulting key comes out
      // identical (given the same password) — devices already paired over
      // P2P aren't orphaned by this device also gaining a cloud account.
      final reuseLocalSalt =
          isLocalOnly && s.email == normalizedEmail && s.kdfSalt != null;
      final kdfSalt = reuseLocalSalt ? s.kdfSalt! : SyncCrypto.randomBytes(16);
      const iterations = SyncCrypto.defaultKdfIterations;
      final keys = await SyncCrypto.deriveKeys(
        password: password,
        kdfSalt: kdfSalt,
        iterations: iterations,
      );
      final result = await api.register(
        email: normalizedEmail,
        authKey: keys.authKey,
        kdfSalt: kdfSalt,
        kdfIterations: iterations,
      );
      if (result.pendingVerification) {
        api.close();
        return result.message;
      }
      final token = result.token!;
      api.token = token;

      _api?.close();
      _api = api;
      s
        ..serverUrl = api.baseUrl
        ..email = normalizedEmail
        ..token = token
        ..encryptionKey = keys.encryptionKey
        ..kdfSalt = kdfSalt
        ..kdfIterations = iterations;
      for (final st in s.collections.values) {
        st.lastSyncedVersion = null;
        st.lastSyncedHash = null;
      }
      _requiresReauth = false;
      _lastError = null;
      await s.save();
      notifyListeners();
      unawaited(syncNow(silent: true));
      return null;
    } catch (_) {
      if (api != _api) api.close();
      rethrow;
    }
  }

  /// Signs out of this device. Data already on the server stays there.
  Future<void> signOut() async {
    final s = _state;
    if (s == null) return;
    try {
      await _api?.logout();
    } catch (_) {
      // Token may already be invalid; local sign-out proceeds regardless.
    }
    _api?.close();
    _api = null;
    _account = null;
    _requiresReauth = false;
    s.clearAccount();
    await s.save();
    notifyListeners();
  }

  /// Sets up (or re-enters) a LOCAL, serverless identity for peer-to-peer
  /// sync: the encryption key is derived from [email] + [password] alone —
  /// no network call, no server. Entering the same email and password on
  /// another device derives the exact same key, which is how two devices
  /// recognize each other as "the same account" over Wi-Fi.
  ///
  /// Throws [StateError] if this device already has a local identity and
  /// [password] doesn't reproduce it — the only mistyped-password check
  /// possible without a server, and only effective on the SAME device.
  Future<void> setLocalAccount({
    required String email,
    required String password,
  }) async {
    final s = _state ?? (_state = await SyncStateStore.load());
    final normalizedEmail = email.trim().toLowerCase();
    final kdfSalt = Uint8List.fromList(sha256
        .convert(utf8.encode('$_localAccountSaltTag:$normalizedEmail'))
        .bytes);
    const iterations = SyncCrypto.defaultKdfIterations;
    final keys = await SyncCrypto.deriveKeys(
      password: password,
      kdfSalt: kdfSalt,
      iterations: iterations,
    );
    final verifier = _hexEncode(Hmac(sha256, keys.encryptionKey)
        .convert(utf8.encode(_localVerifierTag))
        .bytes);

    if (isLocalOnly && s.localVerifier != null && s.localVerifier != verifier) {
      throw StateError('Wrong password for this device\'s existing '
          'device-sync identity.');
    }

    s
      ..email = normalizedEmail
      ..encryptionKey = keys.encryptionKey
      ..kdfSalt = kdfSalt
      ..kdfIterations = iterations
      ..localVerifier = verifier;
    await s.save();
    notifyListeners();
  }

  /// Removes the local-only identity set up by [setLocalAccount], stopping
  /// P2P. Refuses (no-op) if the current identity is actually a signed-in
  /// cloud account — sign out of that from Sync & account instead.
  Future<void> clearLocalAccount() async {
    final s = _state;
    if (s == null || !isLocalOnly) return;
    s
      ..email = null
      ..encryptionKey = null
      ..kdfSalt = null
      ..kdfIterations = null
      ..localVerifier = null;
    await s.save();
    notifyListeners();
  }

  /// Changes the account password. Requires the current password (to prove
  /// identity) and re-encrypts every server-side snapshot under the new key.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final s = _state;
    final api = _api;
    if (s == null || api == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }

    final currentKeys = await SyncCrypto.deriveKeys(
      password: currentPassword,
      kdfSalt: s.kdfSalt!,
      iterations: s.kdfIterations!,
    );
    final newSalt = SyncCrypto.randomBytes(16);
    const newIterations = SyncCrypto.defaultKdfIterations;
    final newKeys = await SyncCrypto.deriveKeys(
      password: newPassword,
      kdfSalt: newSalt,
      iterations: newIterations,
    );

    await api.changePassword(
      currentAuthKey: currentKeys.authKey,
      newAuthKey: newKeys.authKey,
      newKdfSalt: newSalt,
      newKdfIterations: newIterations,
    );

    final oldEncryptionKey = s.encryptionKey!;
    s
      ..encryptionKey = newKeys.encryptionKey
      ..kdfSalt = newSalt
      ..kdfIterations = newIterations;
    await s.save();

    // Re-encrypt every snapshot the server holds so other devices (which
    // will derive the new key) can still read them.
    final remote = await api.account();
    for (final meta in remote.collections.values) {
      try {
        final blob = await api.getBlob(meta.name);
        if (blob == null) continue;
        final payload =
            await SyncCrypto.openPayload(blob.bytes, oldEncryptionKey);
        final sealed =
            await SyncCrypto.sealPayload(payload!, newKeys.encryptionKey);
        final newVersion = await api.putBlob(
          meta.name,
          sealed,
          baseVersion: blob.version,
          payloadSavedAt: blob.payloadSavedAt,
        );
        final st = s.collection(meta.name);
        if (st.lastSyncedVersion == blob.version) {
          st.lastSyncedVersion = newVersion;
        }
      } catch (_) {
        // Snapshot stays under the old key; the next push from this device
        // replaces it.
      }
    }
    await s.save();
    notifyListeners();
  }

  /// Permanently deletes the account and everything stored on the server.
  Future<void> deleteAccount({required String password}) async {
    final s = _state;
    final api = _api;
    if (s == null || api == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }
    final keys = await SyncCrypto.deriveKeys(
      password: password,
      kdfSalt: s.kdfSalt!,
      iterations: s.kdfIterations!,
    );
    await api.deleteAccount(authKey: keys.authKey);
    _api?.close();
    _api = null;
    _account = null;
    s.clearAccount();
    await s.save();
    notifyListeners();
  }

  // ---- Collection toggles --------------------------------------------------------

  /// How many non-'settings' collections are currently enabled (the
  /// always-on 'settings' collection isn't a user choice, so it doesn't
  /// count against the plan limit).
  int get enabledSyncCollectionCount => _state?.collections.entries
          .where((e) => e.key != 'settings' && e.value.enabled)
          .length ??
      0;

  /// Turns syncing on for a collection and uploads it right away. Throws
  /// [SyncLimitExceededException] if the current plan's limit on the number
  /// of synced collections is already reached.
  Future<void> enableCollection(String id) async {
    final s = _state;
    if (s == null) return;
    final st = s.collection(id);
    if (id != 'settings' && !st.enabled) {
      final limit = syncCollectionLimit?.call();
      if (limit != null && enabledSyncCollectionCount >= limit) {
        throw SyncLimitExceededException(limit);
      }
    }
    st.enabled = true;
    await s.save();
    notifyListeners();
    if (signedIn) unawaited(syncNow(silent: true));
  }

  /// Turns syncing off. With [removeRemote], the server's copy is deleted
  /// too (other devices that still sync this collection may re-upload it).
  Future<void> disableCollection(String id, {bool removeRemote = false}) async {
    if (id == 'settings') return; // always synced — can't be turned off
    final s = _state;
    if (s == null) return;
    final st = s.collection(id)
      ..enabled = false
      ..lastSyncedVersion = null
      ..lastSyncedHash = null;
    if (removeRemote && signedIn) {
      try {
        await _api!.deleteBlob(id);
        await _refreshAccount();
      } catch (e) {
        _lastError = 'Could not remove the server copy: $e';
      }
    }
    st.localChangedAt ??= DateTime.now();
    await s.save();
    notifyListeners();
  }

  // ---- Cloud storage primitives (used by the Cloud Files plugin) ---------------
  //
  // These let a feature manage its own server-side blobs (files) using the
  // same account, token and end-to-end encryption key as sync. They do NOT go
  // through the auto-sync collection loop, and their blobs count against the
  // account's storage quota just like everything else.

  /// Refreshes the storage usage / quota snapshot and notifies listeners.
  Future<void> refreshCloudAccount() async {
    await _refreshAccount();
    notifyListeners();
  }

  /// Uploads [bytes] as an encrypted object under [collection] (optimistic
  /// locking via [baseVersion]; 0 = create). Returns the new server version.
  Future<int> putObject(String collection, Uint8List bytes,
      {int baseVersion = 0}) async {
    final api = _api, s = _state;
    if (api == null || s == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }
    StorageGuard.instance.ensureWithinLimit();
    final sealed = await SyncCrypto.sealBytes(bytes, s.encryptionKey!);
    return api.putBlob(collection, sealed,
        baseVersion: baseVersion, payloadSavedAt: DateTime.now());
  }

  /// Fetches and decrypts a raw object, or null if it does not exist.
  Future<Uint8List?> getObject(String collection) async {
    final api = _api, s = _state;
    if (api == null || s == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }
    final blob = await api.getBlob(collection);
    if (blob == null) return null;
    return SyncCrypto.openBytes(blob.bytes, s.encryptionKey!);
  }

  /// Fetches and decrypts a JSON object with its current version, or null.
  Future<({Object? data, int version})?> getJsonObject(
      String collection) async {
    final api = _api, s = _state;
    if (api == null || s == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }
    final blob = await api.getBlob(collection);
    if (blob == null) return null;
    final data = await SyncCrypto.openPayload(blob.bytes, s.encryptionKey!);
    return (data: data, version: blob.version);
  }

  /// Uploads a JSON object with optimistic locking. Returns the new version.
  Future<int> putJsonObject(String collection, Object payload,
      {int baseVersion = 0}) async {
    final api = _api, s = _state;
    if (api == null || s == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }
    StorageGuard.instance.ensureWithinLimit();
    final sealed = await SyncCrypto.sealPayload(payload, s.encryptionKey!);
    return api.putBlob(collection, sealed,
        baseVersion: baseVersion, payloadSavedAt: DateTime.now());
  }

  /// Deletes a server object (no-op if it doesn't exist).
  Future<void> deleteObject(String collection) async {
    final api = _api, s = _state;
    if (api == null || s == null || !s.signedIn) {
      throw StateError('Not signed in.');
    }
    await api.deleteBlob(collection);
  }

  // ---- Sync ---------------------------------------------------------------------

  /// Synchronizes all enabled collections. Safe to call at any time —
  /// concurrent calls are serialized, and awaiting the future always means
  /// "my run has completed".
  Future<void> syncNow({bool silent = false}) {
    final run = _syncTail.then((_) => _syncOnce(silent: silent));
    // The tail swallows errors so one failed run can't poison the chain.
    _syncTail = run.catchError((_) {});
    return run;
  }

  Future<void> _syncOnce({required bool silent}) async {
    final s = _state;
    final api = _api;
    if (s == null || api == null || !s.signedIn) return;

    if (StorageGuard.instance.isOverLimit) {
      _status = SyncStatus.error;
      _lastError =
          'Local storage limit reached — sync is paused until you free up space.';
      notifyListeners();
      return;
    }

    _status = SyncStatus.syncing;
    if (!silent) _lastError = null;
    notifyListeners();

    final errors = <String>[];
    try {
      final remote = await api.account();
      _account = remote;
      for (final collection in collections) {
        final st = s.collection(collection.id);
        if (!st.enabled) continue;
        try {
          await _syncCollection(collection, remote.collections[collection.id]);
        } on SyncApiException catch (e) {
          if (e.isUnauthorized) rethrow;
          errors.add('${collection.label}: ${e.message}');
        } catch (e) {
          errors.add('${collection.label}: $e');
        }
      }
      s.lastSyncAt = DateTime.now();
      await _refreshAccount();
    } on SyncApiException catch (e) {
      if (e.isUnauthorized) {
        // Token expired or revoked: require a fresh sign-in.
        _requiresReauth = true;
        s.token = null;
        errors.add('Session expired — please sign in again.');
      } else {
        errors.add(e.message);
      }
    } catch (e) {
      errors.add('$e');
    }

    await s.save();
    _status = errors.isEmpty ? SyncStatus.idle : SyncStatus.error;
    _lastError = errors.isEmpty ? null : errors.join('\n');
    notifyListeners();
  }

  Future<void> _syncCollection(
      SyncCollection collection, RemoteCollectionMeta? meta) async {
    final s = _state!;
    final st = s.collection(collection.id);

    final exported = await collection.export();
    final encoded = jsonEncode(exported);
    final hash = sha256.convert(utf8.encode(encoded)).toString();

    // First time this device links a collection that already exists on the
    // server: the server copy wins. Without this, a fresh install's default
    // (seed) data would count as the "newest edit" and overwrite real data.
    if (st.lastSyncedVersion == null && meta != null) {
      await _pull(collection, meta);
      return;
    }

    final localChanged = st.lastSyncedHash != hash;
    final serverVersion = meta?.version ?? 0;
    final serverChanged = serverVersion != (st.lastSyncedVersion ?? 0);

    if (!localChanged && !serverChanged) return;

    if (localChanged && !serverChanged) {
      await _push(collection, exported, hash, baseVersion: serverVersion);
      return;
    }
    if (!localChanged && serverChanged) {
      if (meta == null) {
        // The server copy was deleted elsewhere; keep local data and
        // re-upload so nothing is lost.
        await _push(collection, exported, hash, baseVersion: 0);
      } else {
        await _pull(collection, meta);
      }
      return;
    }

    // Both sides changed since the last sync: the newest edit wins.
    final localAt =
        st.localChangedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (meta == null || localAt.isAfter(meta.payloadSavedAt)) {
      await _push(collection, exported, hash, baseVersion: serverVersion);
    } else {
      await _pull(collection, meta);
    }
  }

  Future<void> _push(
    SyncCollection collection,
    Object? exported,
    String hash, {
    required int baseVersion,
    bool isRetry = false,
  }) async {
    final s = _state!;
    final st = s.collection(collection.id);
    final payload = {
      'v': 1,
      'collection': collection.id,
      'savedAtMs': (st.localChangedAt ?? DateTime.now()).millisecondsSinceEpoch,
      'data': exported,
    };
    final sealed = await SyncCrypto.sealPayload(payload, s.encryptionKey!);
    try {
      final version = await _api!.putBlob(
        collection.id,
        sealed,
        baseVersion: baseVersion,
        payloadSavedAt: st.localChangedAt ?? DateTime.now(),
      );
      st.lastSyncedVersion = version;
      st.lastSyncedHash = hash;
    } on SyncApiException catch (e) {
      if (!e.isConflict || isRetry) rethrow;
      // Someone uploaded in between: re-resolve newest-wins once.
      final conflictVersion = e.extra?['version'] as int? ?? 0;
      final conflictSavedAt = DateTime.fromMillisecondsSinceEpoch(
          e.extra?['payloadSavedAtMs'] as int? ?? 0);
      final localAt =
          st.localChangedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (localAt.isAfter(conflictSavedAt)) {
        await _push(collection, exported, hash,
            baseVersion: conflictVersion, isRetry: true);
      } else {
        final blob = await _api!.getBlob(collection.id);
        if (blob != null) {
          await _importBlob(collection, blob);
        }
      }
    }
  }

  Future<void> _pull(
      SyncCollection collection, RemoteCollectionMeta meta) async {
    final blob = await _api!.getBlob(collection.id);
    if (blob == null) return;
    await _importBlob(collection, blob);
  }

  Future<void> _importBlob(SyncCollection collection, RemoteBlob blob) async {
    final s = _state!;
    final st = s.collection(collection.id);

    final payload =
        await SyncCrypto.openPayload(blob.bytes, s.encryptionKey!);
    if (payload is! Map<String, dynamic> ||
        payload['collection'] != collection.id) {
      // Binding the collection name inside the ciphertext prevents a
      // (compromised) server from swapping snapshots between collections.
      throw const SyncCryptoException('Snapshot does not match collection.');
    }

    _importing = true;
    try {
      await collection.import(payload['data']);
    } finally {
      // Import triggers the change streams; swallow those events briefly.
      Timer(const Duration(seconds: 2), () => _importing = false);
    }

    // Hash the state as imported so it doesn't read as a fresh local edit.
    final reExported = await collection.export();
    st.lastSyncedHash =
        sha256.convert(utf8.encode(jsonEncode(reExported))).toString();
    st.lastSyncedVersion = blob.version;
    st.localChangedAt = null;
  }

  Future<void> _refreshAccount() async {
    try {
      _account = await _api!.account();
    } catch (_) {
      // Usage display just stays stale.
    }
  }

  // ---- Peer-to-peer sync seams ----------------------------------------------
  //
  // The transport coupling of cloud sync lives in `SyncApi`. These methods
  // expose the transport-AGNOSTIC parts (sealing, collection-binding check,
  // newest-edit-wins merge) so a peer link can ship the same sealed blobs
  // directly between two same-account devices, with no server in the loop.

  /// State to advertise to a peer: for every enabled collection, our last
  /// agreed cloud version and the timestamp of the freshest local edit. The
  /// peer compares against its own state to decide what to request.
  Map<String, ({int cloudVersion, int savedAtMs})> peerState() {
    final s = _state;
    if (s == null) return const {};
    final out = <String, ({int cloudVersion, int savedAtMs})>{};
    for (final c in collections) {
      final st = s.collection(c.id);
      if (!st.enabled) continue;
      out[c.id] = (
        cloudVersion: st.lastSyncedVersion ?? 0,
        savedAtMs:
            (st.localChangedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .millisecondsSinceEpoch,
      );
    }
    return out;
  }

  /// Builds a sealed snapshot of [collectionId] for a peer. Returns null when
  /// the collection is disabled, unknown, or we're not signed in. The
  /// returned [savedAtMs] is the local edit time the peer should compare
  /// against.
  Future<({Uint8List sealed, int savedAtMs})?> buildPeerSnapshot(
      String collectionId) async {
    final s = _state;
    if (s == null || s.encryptionKey == null) return null;
    final collection = collections.cast<SyncCollection?>().firstWhere(
        (c) => c?.id == collectionId,
        orElse: () => null);
    if (collection == null) return null;
    final st = s.collection(collectionId);
    if (!st.enabled) return null;

    final exported = await collection.export();
    final savedAt = st.localChangedAt ?? DateTime.now();
    final payload = {
      'v': 1,
      'collection': collectionId,
      'savedAtMs': savedAt.millisecondsSinceEpoch,
      'data': exported,
    };
    final sealed = await SyncCrypto.sealPayload(payload, s.encryptionKey!);
    return (sealed: sealed, savedAtMs: savedAt.millisecondsSinceEpoch);
  }

  /// Applies a sealed snapshot received from a peer. Performs the SAME crypto
  /// open + collection-binding check as cloud `_importBlob`, then decides via
  /// newest-edit-wins whether our local data is older.
  ///
  /// Returns true if applied, false if declined (we're newer or equal, or the
  /// collection is disabled here). On a successful apply the import is
  /// recorded as a LOCAL EDIT so the change fans out to the cloud and to any
  /// other connected peers via the normal change triggers.
  Future<bool> applyPeerSnapshot(
      String collectionId, Uint8List sealed, int peerSavedAtMs) async {
    final s = _state;
    if (s == null || s.encryptionKey == null) return false;
    final collection = collections.cast<SyncCollection?>().firstWhere(
        (c) => c?.id == collectionId,
        orElse: () => null);
    if (collection == null) return false;
    final st = s.collection(collectionId);
    if (!st.enabled) return false;

    // Serialize against cloud sync and any other concurrent peer import so
    // two writers can't interleave on the same collection.
    final run = _syncTail.then((_) =>
        _applyPeerLocked(collection, st, sealed, peerSavedAtMs));
    _syncTail = run.catchError((_) => false);
    return run;
  }

  Future<bool> _applyPeerLocked(SyncCollection collection,
      CollectionSyncState st, Uint8List sealed, int peerSavedAtMs) async {
    // A peer can't push new data past the cap either.
    if (StorageGuard.instance.isOverLimit) return false;
    final s = _state!;
    final payload =
        await SyncCrypto.openPayload(sealed, s.encryptionKey!);
    if (payload is! Map<String, dynamic> ||
        payload['collection'] != collection.id) {
      // Same collection-binding check as cloud sync: a malicious peer can't
      // swap a blob from another collection in.
      throw const SyncCryptoException('Snapshot does not match collection.');
    }

    // Newest-edit-wins, mirroring `_syncCollection`.
    final localAt =
        st.localChangedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final peerAt = DateTime.fromMillisecondsSinceEpoch(peerSavedAtMs);
    if (!peerAt.isAfter(localAt) && st.lastSyncedHash != null) {
      // We are at least as new as the peer — decline to avoid clobbering a
      // local edit that hasn't propagated yet.
      return false;
    }

    _importing = true;
    try {
      await collection.import(payload['data']);
    } finally {
      // The import re-triggers change streams; swallow them briefly so they
      // don't immediately fire off a fresh (lossy) push.
      Timer(const Duration(seconds: 2), () => _importing = false);
    }

    // Record as a local edit so it fans out to the cloud and other peers.
    st.localChangedAt = DateTime.now();
    final reExported = await collection.export();
    st.lastSyncedHash =
        sha256.convert(utf8.encode(jsonEncode(reExported))).toString();
    await s.save();
    notifyListeners();
    return true;
  }
}

/// Lowercase-hex encoder (avoids pulling in a hex package).
String _hexEncode(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Local sync bookkeeping for one collection.
class CollectionSyncState {
  CollectionSyncState({
    this.enabled = false,
    this.lastSyncedVersion,
    this.lastSyncedHash,
    this.localChangedAt,
  });

  /// Whether the user allows this collection to go to the server. Always
  /// starts off — nothing leaves the device until explicitly enabled.
  bool enabled;

  /// Server version our local data was last in agreement with.
  int? lastSyncedVersion;

  /// Hash of the local export at that moment (detects local edits).
  String? lastSyncedHash;

  /// When the local data last changed (drives newest-edit-wins).
  DateTime? localChangedAt;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'lastSyncedVersion': lastSyncedVersion,
        'lastSyncedHash': lastSyncedHash,
        'localChangedAt': localChangedAt?.millisecondsSinceEpoch,
      };

  factory CollectionSyncState.fromJson(Map<String, dynamic> j) =>
      CollectionSyncState(
        enabled: j['enabled'] == true,
        lastSyncedVersion: j['lastSyncedVersion'] as int?,
        lastSyncedHash: j['lastSyncedHash'] as String?,
        localChangedAt: j['localChangedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(j['localChangedAt'] as int)
            : null,
      );
}

/// Persisted sync configuration and credentials.
///
/// Stored in the app's local support directory, next to the other luma data
/// files. The encryption key saved here is what makes "stay signed in"
/// possible; it protects data *on the server*, while local data is already
/// on this disk unencrypted — so persisting it does not weaken the local
/// security model (same as the existing luma_pw.key).
class SyncStateStore {
  SyncStateStore._(this._file);

  static const _fileName = 'luma_sync.json';

  final File? _file;

  String? serverUrl;
  String? email;
  String? token;
  Uint8List? encryptionKey;
  Uint8List? kdfSalt;
  int? kdfIterations;
  DateTime? lastSyncAt;

  /// HMAC of a fixed tag under [encryptionKey], set only by a LOCAL (no
  /// server) identity created via `SyncService.setLocalAccount`. Lets this
  /// device catch a mistyped password when re-entering credentials, since
  /// there is no server to check against. Cleared on any full sign-out so a
  /// stale value can never reject a genuinely new identity.
  String? localVerifier;

  final Map<String, CollectionSyncState> collections = {};

  bool get signedIn =>
      token != null && encryptionKey != null && serverUrl != null;

  CollectionSyncState collection(String id) =>
      collections.putIfAbsent(id, CollectionSyncState.new);

  static Future<SyncStateStore> load() async {
    File? file;
    Map<String, dynamic> data = const {};
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      file = null;
    }

    final store = SyncStateStore._(file);
    try {
      store.serverUrl = data['serverUrl'] as String?;
      store.email = data['email'] as String?;
      store.token = data['token'] as String?;
      final enc = data['encryptionKey'];
      if (enc is String) {
        store.encryptionKey = Uint8List.fromList(base64Decode(enc));
      }
      final salt = data['kdfSalt'];
      if (salt is String) {
        store.kdfSalt = Uint8List.fromList(base64Decode(salt));
      }
      store.kdfIterations = data['kdfIterations'] as int?;
      store.localVerifier = data['localVerifier'] as String?;
      if (data['lastSyncAt'] is int) {
        store.lastSyncAt =
            DateTime.fromMillisecondsSinceEpoch(data['lastSyncAt'] as int);
      }
      final collections = data['collections'];
      if (collections is Map<String, dynamic>) {
        collections.forEach((id, raw) {
          if (raw is Map<String, dynamic>) {
            store.collections[id] = CollectionSyncState.fromJson(raw);
          }
        });
      }
    } catch (_) {
      // A corrupt state file just means signing in again.
    }
    return store;
  }

  Future<void> save() async {
    final file = _file;
    if (file == null) return;
    try {
      final payload = jsonEncode({
        'serverUrl': serverUrl,
        'email': email,
        'token': token,
        'encryptionKey':
            encryptionKey == null ? null : base64Encode(encryptionKey!),
        'kdfSalt': kdfSalt == null ? null : base64Encode(kdfSalt!),
        'kdfIterations': kdfIterations,
        'localVerifier': localVerifier,
        'lastSyncAt': lastSyncAt?.millisecondsSinceEpoch,
        'collections':
            collections.map((id, s) => MapEntry(id, s.toJson())),
      });
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (_) {
      // Best effort — sync state just won't survive a restart.
    }
  }

  /// Clears the account (sign-out). Collection toggles are kept, but their
  /// server bookkeeping is reset so a new account starts fresh.
  void clearAccount({bool keepServer = true}) {
    if (!keepServer) serverUrl = null;
    email = null;
    token = null;
    encryptionKey = null;
    kdfSalt = null;
    kdfIterations = null;
    localVerifier = null;
    lastSyncAt = null;
    for (final s in collections.values) {
      s.lastSyncedVersion = null;
      s.lastSyncedHash = null;
    }
  }
}

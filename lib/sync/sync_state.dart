import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../security/secure_secret_store.dart';

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
/// Non-secret bookkeeping stays in the app support directory. Tokens, keys,
/// and their account/origin binding are kept together in OS secure storage.
/// Legacy credentials are migrated before being removed from the JSON file.
class SyncStateStore {
  SyncStateStore._(this._file);

  static const _fileName = 'luma_sync.json';

  final File? _file;
  Future<void> _saving = Future.value();

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

  /// Whether the server has approved this account (email verified, or
  /// approved from the admin dashboard). Set when a sign-in succeeds — the
  /// server only hands out a token to an approved account — and cleared
  /// again if `/account` ever reports the account back to `pending`.
  ///
  /// This is what opens [ServerAccessGate]: while it is false, the app makes
  /// no requests to the server beyond the account handshake itself.
  bool accountApproved = false;

  /// The address of an account that was created on this device but is still
  /// waiting for approval. Purely so the UI can say who it is waiting for;
  /// it grants no access.
  String? pendingApprovalEmail;

  /// How that account gets approved, as the server reported it at
  /// registration: `manual` (the operator approves it — the default),
  /// `email` (the user opens a link), or `open`. Decides whether the UI
  /// offers to resend anything.
  String? pendingApprovalMode;

  /// One-time migration flag: the first time this device's state is loaded
  /// after this field was introduced, any existing local-only (serverless)
  /// identity is cleared so the user is prompted to create a real cloud
  /// account instead (see `SyncService.init`). Stays true forever after.
  bool localAccountMigrated = false;

  /// True once the user has dismissed the first-run account setup prompt
  /// without completing it (closed it, hit Cancel, tapped outside it).
  /// Stops that automatic prompt from reappearing on later launches — see
  /// `maybePromptAccountSetup` in main.dart. Manually opening the dialog
  /// from Settings is unaffected; this only gates the automatic one-time
  /// nag.
  bool accountSetupPromptDismissed = false;

  final Map<String, CollectionSyncState> collections = {};

  bool get signedIn =>
      token != null && encryptionKey != null && serverUrl != null;

  /// Signed in *and* approved — the state every server-backed feature
  /// requires before it does anything.
  bool get serverReady => signedIn && accountApproved;

  /// The 'settings' collection (theme, preferences — see main.dart) always
  /// syncs and can't be turned off, so it defaults to enabled the first time
  /// it's touched rather than the usual opt-in default.
  CollectionSyncState collection(String id) => collections.putIfAbsent(
    id,
    () => CollectionSyncState(enabled: id == 'settings'),
  );

  static Future<SyncStateStore> load({File? stateFile}) async {
    File? file;
    Map<String, dynamic> data = const {};
    try {
      if (stateFile != null) {
        file = stateFile;
      } else {
        final dir = await getApplicationSupportDirectory();
        file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      }
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid sync state.');
        }
        data = decoded;
      }
    } catch (_) {
      if (file != null) {
        throw StateError(
          'Sync state could not be read. Preserve it for recovery.',
        );
      }
      file = null;
    }

    final store = SyncStateStore._(file);
    final protected = data['credentialsProtected'] == true;
    if (protected) {
      final credentials = await SecureSecretStore.instance.read(
        'sync.credentials',
      );
      if (credentials == null) {
        throw StateError('Sync credentials are unavailable in secure storage.');
      }
      data = {...data, ...jsonDecode(credentials) as Map<String, dynamic>};
    }
    try {
      store.serverUrl = data['serverUrl'] as String?;
      store.email = data['email'] as String?;
      store.token = data['token'] as String?;
      final enc = data['encryptionKey'];
      if (enc is String) {
        store.encryptionKey = Uint8List.fromList(base64Decode(enc));
        if (store.encryptionKey!.length != 32) {
          throw const FormatException('Invalid sync encryption key.');
        }
      }
      final salt = data['kdfSalt'];
      if (salt is String) {
        store.kdfSalt = Uint8List.fromList(base64Decode(salt));
      }
      store.kdfIterations = data['kdfIterations'] as int?;
      // Devices that signed in before this flag existed already proved the
      // account is approved (the server only issues tokens to approved
      // accounts), so an existing token counts as approved on upgrade.
      store.accountApproved =
          data['accountApproved'] as bool? ?? (store.token != null);
      store.pendingApprovalEmail = data['pendingApprovalEmail'] as String?;
      store.pendingApprovalMode = data['pendingApprovalMode'] as String?;
      store.localVerifier = data['localVerifier'] as String?;
      store.localAccountMigrated = data['localAccountMigrated'] == true;
      store.accountSetupPromptDismissed =
          data['accountSetupPromptDismissed'] == true;
      if (data['lastSyncAt'] is int) {
        store.lastSyncAt = DateTime.fromMillisecondsSinceEpoch(
          data['lastSyncAt'] as int,
        );
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
      throw StateError('Invalid sync state. Restore the original credentials.');
    }
    if (file != null &&
        !protected &&
        (store.token != null || store.encryptionKey != null)) {
      await store.save();
    }
    return store;
  }

  Future<void> save() {
    final next = _saving.then((_) => _saveNow());
    _saving = next.catchError((Object _) {});
    return next;
  }

  Future<void> _saveNow() async {
    final file = _file;
    if (file == null) return;
    final credentials = jsonEncode({
      'serverUrl': serverUrl,
      'email': email,
      'kdfSalt': kdfSalt == null ? null : base64Encode(kdfSalt!),
      'kdfIterations': kdfIterations,
      'accountApproved': accountApproved,
      'token': token,
      'encryptionKey': encryptionKey == null
          ? null
          : base64Encode(encryptionKey!),
    });
    final payload = jsonEncode({
      'serverUrl': serverUrl,
      'email': email,
      'credentialsProtected': true,
      'kdfSalt': kdfSalt == null ? null : base64Encode(kdfSalt!),
      'kdfIterations': kdfIterations,
      'accountApproved': accountApproved,
      'pendingApprovalEmail': pendingApprovalEmail,
      'pendingApprovalMode': pendingApprovalMode,
      'localVerifier': localVerifier,
      'localAccountMigrated': localAccountMigrated,
      'accountSetupPromptDismissed': accountSetupPromptDismissed,
      'lastSyncAt': lastSyncAt?.millisecondsSinceEpoch,
      'collections': collections.map((id, s) => MapEntry(id, s.toJson())),
    });
    await SecureSecretStore.instance.write('sync.credentials', credentials);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(file.path);
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
    accountApproved = false;
    localVerifier = null;
    lastSyncAt = null;
    for (final s in collections.values) {
      s.lastSyncedVersion = null;
      s.lastSyncedHash = null;
    }
  }
}

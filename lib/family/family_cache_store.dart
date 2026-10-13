import 'dart:io';

import '../security/encrypted_json_cache.dart';
import '../security/secure_secret_store.dart';

/// Local, file-backed cache of the last-known family/invites/shared-events
/// state, so the UI (roster, inbox badge, calendar merge) has something to
/// show immediately on launch before the first network [FamilyRepository.refresh]
/// completes. Mirrors the minimal JSON-file persistence style of
/// `SyncStateStore` (lib/sync/sync_state.dart) rather than a Drift database —
/// this is a pure read-through cache of server state with no local mutations
/// of its own, so a relational schema would be more machinery than the job
/// needs.
///
/// Raw server JSON keeps its shape so [FamilyRepository] can decode it with
/// the same `fromJson` factories used for live responses. The file and all
/// temporary writes are encrypted with a device-protected key.
class FamilyCacheStore {
  FamilyCacheStore._(this._cache);

  static const _fileName = 'luma_family_cache.json';

  final EncryptedJsonCache _cache;

  Map<String, dynamic>? familyJson;
  List<dynamic> invitesJson = const [];
  List<dynamic> eventsJson = const [];
  List<dynamic> messagesJson = const [];

  static Future<FamilyCacheStore> load({
    Directory? storageDir,
    SecureSecretStore? secretStore,
  }) async {
    final cache = await EncryptedJsonCache.load(
      _fileName,
      'family-cache',
      storageDir: storageDir,
      secretStore: secretStore,
    );
    final data = cache.data;
    final store = FamilyCacheStore._(cache);
    try {
      store.familyJson = data['family'] as Map<String, dynamic>?;
      store.invitesJson = data['invites'] as List? ?? const [];
      store.eventsJson = data['events'] as List? ?? const [];
      store.messagesJson = data['messages'] as List? ?? const [];
    } catch (_) {
      // A corrupt cache file just means an empty cache until the next refresh.
    }
    return store;
  }

  Future<void> save() => _cache.save({
    'family': familyJson,
    'invites': invitesJson,
    'events': eventsJson,
    'messages': messagesJson,
  });
}

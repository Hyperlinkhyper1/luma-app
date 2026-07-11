import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local, file-backed cache of the last-known family/invites/shared-events
/// state, so the UI (roster, inbox badge, calendar merge) has something to
/// show immediately on launch before the first network [FamilyRepository.refresh]
/// completes. Mirrors the minimal JSON-file persistence style of
/// `SyncStateStore` (lib/sync/sync_state.dart) rather than a Drift database —
/// this is a pure read-through cache of server state with no local mutations
/// of its own, so a relational schema would be more machinery than the job
/// needs.
///
/// Raw server JSON is stored as-is (not re-typed) so [FamilyRepository] can
/// decode it with the exact same `fromJson` factories used for live network
/// responses.
class FamilyCacheStore {
  FamilyCacheStore._(this._file);

  static const _fileName = 'luma_family_cache.json';

  final File? _file;

  Map<String, dynamic>? familyJson;
  List<dynamic> invitesJson = const [];
  List<dynamic> eventsJson = const [];

  static Future<FamilyCacheStore> load() async {
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

    final store = FamilyCacheStore._(file);
    try {
      store.familyJson = data['family'] as Map<String, dynamic>?;
      store.invitesJson = data['invites'] as List? ?? const [];
      store.eventsJson = data['events'] as List? ?? const [];
    } catch (_) {
      // A corrupt cache file just means an empty cache until the next refresh.
    }
    return store;
  }

  Future<void> save() async {
    final file = _file;
    if (file == null) return;
    try {
      final payload = jsonEncode({
        'family': familyJson,
        'invites': invitesJson,
        'events': eventsJson,
      });
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (_) {
      // Best effort — the cache just won't survive a restart.
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persisted P2P state: a stable device id/name, the discovery+auto toggle,
/// and the set of trusted peer device ids. Stored as plain JSON next to the
/// other luma data files (no secrets live here).
class PeerSyncState {
  PeerSyncState._(this._file);

  static const _fileName = 'luma_p2p.json';

  final File? _file;

  /// Stable random id for THIS device. Generated once, reused forever so
  /// peers can dedupe us across reconnects.
  String deviceId = '';

  /// Human label shown to peers. Defaults to the platform name.
  String deviceName = '';

  /// Whether discovery is on (advertise + browse). Off by default; nothing
  /// happens until the user opens the Devices page.
  bool discoveryEnabled = false;

  /// Whether enabled collections auto-push to trusted peers on local change.
  /// When off, the user must hit "Sync now" per peer.
  bool autoSync = false;

  /// Peer device ids the user has connected to before (treated as trusted
  /// for auto-connect when seen again). We don't auto-trust brand-new peers.
  final Set<String> trustedPeerIds = {};

  /// Last connection time per peer id, for UI display ("last synced 2h ago").
  final Map<String, int> lastSeenMs = {};

  /// The local port this device prefers to listen on. Reused across restarts
  /// so mDNS caches on other devices remain valid.
  int listenPort = 0;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'discoveryEnabled': discoveryEnabled,
        'autoSync': autoSync,
        'trustedPeerIds': trustedPeerIds.toList(),
        'lastSeenMs': lastSeenMs,
        'listenPort': listenPort,
      };

  static Future<PeerSyncState> load({String? fallbackName}) async {
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

    final state = PeerSyncState._(file);
    state.listenPort = data['listenPort'] as int? ?? 0;
    state.deviceId = data['deviceId'] as String? ?? _randomId();
    state.deviceName =
        data['deviceName'] as String? ?? fallbackName ?? _platformLabel();
    state.discoveryEnabled = data['discoveryEnabled'] as bool? ?? false;
    state.autoSync = data['autoSync'] as bool? ?? false;
    state.trustedPeerIds
        .addAll((data['trustedPeerIds'] as List<dynamic>? ?? const [])
            .whereType<String>());
    final seen = data['lastSeenMs'];
    if (seen is Map<String, dynamic>) {
      seen.forEach((k, v) {
        if (v is int) state.lastSeenMs[k] = v;
      });
    }
    await state.save();
    return state;
  }

  Future<void> save() async {
    final file = _file;
    if (file == null) return;
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (_) {
      // Best effort — P2P prefs just won't survive a restart.
    }
  }

  void trust(String peerId) {
    trustedPeerIds.add(peerId);
  }

  void untrust(String peerId) {
    trustedPeerIds.remove(peerId);
  }

  void markSeen(String peerId) {
    lastSeenMs[peerId] = DateTime.now().millisecondsSinceEpoch;
  }

  static String _randomId() {
    final rng = DateTime.now().microsecondsSinceEpoch;
    final id = StringBuffer();
    // Quick, non-crypto id: timestamp + random. Stable across app sessions
    // only because we persist after first generation.
    var v = rng;
    for (var i = 0; i < 16; i++) {
      v = (v * 1103515245 + 12345) & 0x7fffffff;
      id.write((v % 36).toRadixString(36));
    }
    return id.toString();
  }

  static String _platformLabel() {
    // Plain Dart — avoid importing dart:io Platform name strings directly so
    // the label is stable and readable.
    return 'luma device';
  }
}

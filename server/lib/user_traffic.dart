import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'util.dart';

/// Known-length authenticated API payload counters before compression. These
/// are not device or network-interface usage; streamed bodies, headers, TLS,
/// WebSockets and proxy traffic are excluded.
class UserTraffic {
  UserTraffic({
    required this.startedAtMs,
    this.requests = 0,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
  });

  final int startedAtMs;
  int requests;
  int uploadBytes;
  int downloadBytes;

  Map<String, dynamic> toJson() => {
        'startedAtMs': startedAtMs,
        'requests': requests,
        'uploadBytes': uploadBytes,
        'downloadBytes': downloadBytes,
      };

  factory UserTraffic.fromJson(Map<String, dynamic> json) => UserTraffic(
        startedAtMs: json['startedAtMs'] as int,
        requests: json['requests'] as int? ?? 0,
        uploadBytes: json['uploadBytes'] as int? ?? 0,
        downloadBytes: json['downloadBytes'] as int? ?? 0,
      );
}

class UserTrafficStore {
  UserTrafficStore._(this._path);

  final String _path;
  final Map<String, UserTraffic> byUser = {};
  Timer? _saveTimer;
  Future<void> _writes = Future.value();

  static Future<UserTrafficStore> open(String dataDir) async {
    final store = UserTrafficStore._('$dataDir/user_traffic.json');
    final file = File(store._path);
    if (await file.exists()) {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      decoded.forEach((id, value) {
        store.byUser[id] = UserTraffic.fromJson(value as Map<String, dynamic>);
      });
    }
    return store;
  }

  void record(String userId,
      {required int uploadBytes, required int downloadBytes}) {
    final usage = byUser.putIfAbsent(
      userId,
      () => UserTraffic(startedAtMs: DateTime.now().millisecondsSinceEpoch),
    );
    usage.requests++;
    usage.uploadBytes += uploadBytes;
    usage.downloadBytes += downloadBytes;
    _scheduleSave();
  }

  void remove(String userId) {
    byUser.remove(userId);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer ??= Timer(const Duration(seconds: 30), () {
      _saveTimer = null;
      unawaited(flush().catchError((Object error) {
        stderr.writeln('[luma] could not save user traffic: $error');
      }));
    });
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final snapshot =
        jsonEncode(byUser.map((id, traffic) => MapEntry(id, traffic.toJson())));
    return _writes = _writes
        .catchError((Object _) {})
        .then((_) => atomicWriteString(_path, snapshot));
  }
}

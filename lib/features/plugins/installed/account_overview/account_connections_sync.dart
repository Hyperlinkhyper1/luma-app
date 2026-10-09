import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../security/secure_secret_store.dart';

/// Connection credentials travel only inside the encrypted sync collection.
/// Each service has its own revision so independent connections merge, and a
/// null credential remains a tombstone when another device was offline.
class AccountConnectionEndpoint {
  const AccountConnectionEndpoint({
    required this.changes,
    required this.read,
    required this.write,
  });

  final Listenable changes;
  final Future<Map<String, dynamic>?> Function() read;
  final Future<void> Function(Map<String, dynamic>?) write;
}

class AccountConnectionsSync extends ChangeNotifier {
  AccountConnectionsSync({required this.endpoints, SecureSecretStore? secrets})
    : _secrets = secrets ?? SecureSecretStore.instance {
    for (final changes in endpoints.values.map((e) => e.changes).toSet()) {
      changes.addListener(_changed);
    }
    _changed();
  }

  static const collectionId = 'account_connections';
  static const _storageKey = 'account_overview.sync_revisions';
  final Map<String, AccountConnectionEndpoint> endpoints;
  final SecureSecretStore _secrets;
  final Map<String, dynamic> _records = {};
  Future<void> _queue = Future.value();
  bool _loaded = false;
  bool _importing = false;
  bool _disposed = false;

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _changed() {
    if (_importing || _disposed) return;
    _serial(_capture).catchError((Object _) {});
  }

  Future<void> _capture() async {
    final migrating = !_loaded;
    if (!_loaded) {
      final saved = await _secrets.read(_storageKey);
      if (saved != null) {
        _records.addAll(jsonDecode(saved) as Map<String, dynamic>);
      }
      _loaded = true;
    }
    var changed = false;
    for (final entry in endpoints.entries) {
      final credential = await entry.value.read();
      final previous = _records[entry.key] as Map?;
      if (previous == null && credential == null) continue;
      if (previous != null &&
          jsonEncode(previous['credential']) == jsonEncode(credential)) {
        continue;
      }
      final oldTime = (previous?['updatedAt'] as num?)?.toInt() ?? 0;
      final now = DateTime.now().microsecondsSinceEpoch;
      _records[entry.key] = {
        'updatedAt': migrating && previous == null
            ? 1
            : (now > oldTime ? now : oldTime + 1),
        'credential': credential,
      };
      changed = true;
    }
    if (changed) {
      await _persist();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _persist() => _secrets.write(_storageKey, jsonEncode(_records));

  Future<Object?> exportData() => _serial(() async {
    await _capture();
    final keys = _records.keys.toList()..sort();
    return jsonDecode(
      jsonEncode({
        'version': 1,
        'connections': {for (final key in keys) key: _records[key]},
      }),
    );
  });

  Future<void> importData(Object? data) => _serial(() async {
    if (data is! Map || data['version'] != 1 || data['connections'] is! Map) {
      throw const FormatException('Invalid account connection sync data');
    }
    await _capture();
    _importing = true;
    try {
      for (final entry in (data['connections'] as Map).entries) {
        final endpoint = endpoints[entry.key];
        if (endpoint == null) continue;
        final incoming = Map<String, dynamic>.from(entry.value as Map);
        final time = (incoming['updatedAt'] as num).toInt();
        final local = _records[entry.key] as Map?;
        final localTime = (local?['updatedAt'] as num?)?.toInt() ?? 0;
        if (time < localTime) continue;
        if (time == localTime &&
            jsonEncode(incoming).compareTo(jsonEncode(local)) <= 0) {
          continue;
        }
        final credential = incoming['credential'];
        await endpoint.write(
          credential == null
              ? null
              : Map<String, dynamic>.from(credential as Map),
        );
        _records[entry.key as String] = incoming;
        await _persist();
      }
    } finally {
      _importing = false;
    }
    if (!_disposed) notifyListeners();
  });

  @override
  void dispose() {
    _disposed = true;
    for (final changes in endpoints.values.map((e) => e.changes).toSet()) {
      changes.removeListener(_changed);
    }
    super.dispose();
  }
}

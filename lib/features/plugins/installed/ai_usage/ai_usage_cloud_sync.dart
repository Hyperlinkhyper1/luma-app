import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../sync/sync_service.dart';
import 'ai_usage_source.dart';
import 'data/ai_usage_database.dart';

/// The sync collection id that switches AI Usage syncing on. The workbench
/// (agents + Markdown library) rides the ordinary collection loop under this
/// id; the usage numbers use it only as their on/off switch.
const String kAiUsageSyncCollectionId = 'ai_usage';

/// Server object names for per-device usage uploads start with this. The
/// server allows `[a-z0-9_]{1,32}`, so a 16-hex device id fits comfortably.
const String kAiUsageDeviceObjectPrefix = 'aiu_';

/// The few server operations the usage sync needs, so tests can run it
/// against an in-memory store rather than a real account.
abstract class AiUsageCloudStore {
  /// Whether this device may talk to the server for AI Usage right now: an
  /// approved account ([SyncService.serverReady]) with the collection on.
  bool get available;

  /// Whether the user switched AI Usage sync on, independent of connectivity.
  bool get enabled;

  /// Every object name starting with [prefix], with its server version.
  Future<Map<String, int>> list(String prefix);

  Future<({Object? data, int version})?> get(String name);

  Future<int> put(String name, Object payload, {required int baseVersion});
}

/// [AiUsageCloudStore] on top of the app's [SyncService]: same account, same
/// end-to-end encryption, same server gate as every other synced feature.
class SyncServiceAiUsageStore implements AiUsageCloudStore {
  SyncServiceAiUsageStore(this._sync);

  final SyncService _sync;

  @override
  bool get available => _sync.serverReady && enabled;

  @override
  bool get enabled => _sync.isEnabled(kAiUsageSyncCollectionId);

  @override
  Future<Map<String, int>> list(String prefix) async {
    await _sync.refreshCloudAccount();
    final collections = _sync.account?.collections ?? const {};
    return {
      for (final meta in collections.values)
        if (meta.name.startsWith(prefix)) meta.name: meta.version,
    };
  }

  @override
  Future<({Object? data, int version})?> get(String name) =>
      _sync.getJsonObject(name);

  @override
  Future<int> put(String name, Object payload, {required int baseVersion}) =>
      _sync.putJsonObject(name, payload, baseVersion: baseVersion);
}

/// Shares this device's AI usage with the user's other devices and pulls
/// theirs in, so the dashboard shows one total across every machine.
///
/// Each device owns exactly one server object (`aiu_<deviceId>`) holding
/// only the turns it scanned itself. Nobody ever writes another device's
/// object, so two devices can never overwrite each other's numbers — the
/// total is simply the sum of every object. Pulled turns are stored with
/// their `deviceId`, which keeps them out of this device's own upload.
///
/// Deliberately not part of the 10-second collection loop: usage logs grow
/// on every AI turn and the upload is the whole history, so it runs once on
/// open ([syncOnOpen]) and once on close ([pushOnClose]), and skips the
/// upload entirely when nothing was scanned since the last one.
class AiUsageCloudSync {
  AiUsageCloudSync({
    required this._db,
    required this._store,
    Future<Directory> Function()? supportDirectoryProvider,
    String? deviceName,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _deviceNameOverride = deviceName;

  static const _stateFileName = 'luma_ai_usage_sync.json';

  final AiUsageDatabase _db;
  final AiUsageCloudStore _store;
  final Future<Directory> Function() _supportDirectoryProvider;
  final String? _deviceNameOverride;

  _SyncIdentity? _identity;
  Future<void> _tail = Future.value();

  /// Pulls every other device's usage that changed, then uploads this
  /// device's own if it changed. Call after a fresh local scan.
  Future<void> syncOnOpen() => _serialized(() async {
    if (!_store.enabled) {
      await _forgetRemoteDevices();
      return;
    }
    if (!_store.available) return;
    final identity = await _loadIdentity();
    final objects = await _store.list(kAiUsageDeviceObjectPrefix);
    await _pull(identity, objects);
    await _push(identity, objects[identity.objectName] ?? 0);
  });

  /// Uploads this device's usage if it changed since the last upload. Cheap
  /// when nothing changed: one local COUNT/MAX query and no network at all.
  Future<void> pushOnClose() => _serialized(() async {
    if (!_store.available) return;
    final identity = await _loadIdentity();
    if (identity.pushedFingerprint == await _localFingerprint()) return;
    await _push(identity, identity.pushedVersion);
  });

  Future<void> _serialized(Future<void> Function() run) {
    final next = _tail.then((_) => run());
    _tail = next.catchError((_) {});
    return next;
  }

  Future<void> _pull(_SyncIdentity identity, Map<String, int> objects) async {
    final known = {
      for (final device in await _db.select(_db.aiUsageRemoteDevices).get())
        device.deviceId: device,
    };

    for (final entry in objects.entries) {
      final deviceId = entry.key.substring(kAiUsageDeviceObjectPrefix.length);
      if (deviceId == identity.deviceId) continue;
      if (known[deviceId]?.version == entry.value) continue;
      final object = await _store.get(entry.key);
      if (object == null) continue;
      final upload = AiUsageDeviceUpload.fromJson(object.data);
      if (upload == null || upload.deviceId != deviceId) continue;
      await _replaceDevice(upload, object.version);
    }

    // A device whose upload vanished from the server (its data was removed)
    // should stop counting towards the total here too.
    final live = {
      for (final name in objects.keys)
        name.substring(kAiUsageDeviceObjectPrefix.length),
    };
    for (final deviceId in known.keys) {
      if (!live.contains(deviceId)) await _removeDevice(deviceId);
    }
  }

  Future<void> _push(_SyncIdentity identity, int serverVersion) async {
    final fingerprint = await _localFingerprint();
    if (identity.pushedFingerprint == fingerprint &&
        identity.pushedVersion == serverVersion &&
        serverVersion != 0) {
      return;
    }
    final localTurns = await (_db.select(
      _db.aiUsageTurns,
    )..where((t) => t.deviceId.isNull())).get();
    final upload = AiUsageDeviceUpload(
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
      uploadedAt: DateTime.now(),
      turns: localTurns,
    );
    int version;
    try {
      version = await _store.put(
        identity.objectName,
        upload.toJson(),
        baseVersion: serverVersion,
      );
    } catch (_) {
      // Only this device writes this object, so a version clash means our
      // bookkeeping is stale (a reinstall, a restored backup). Re-read the
      // server's version once and overwrite with the authoritative local copy.
      final current = await _store.get(identity.objectName);
      version = await _store.put(
        identity.objectName,
        upload.toJson(),
        baseVersion: current?.version ?? 0,
      );
    }
    identity
      ..pushedFingerprint = fingerprint
      ..pushedVersion = version;
    await _saveIdentity(identity);
  }

  Future<void> _replaceDevice(AiUsageDeviceUpload upload, int version) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.aiUsageTurns,
      )..where((t) => t.deviceId.equals(upload.deviceId))).go();
      await _db.batch((b) {
        b.insertAll(_db.aiUsageTurns, [
          for (final turn in upload.turns)
            turn
                .toCompanion(false)
                .copyWith(
                  id: const Value.absent(),
                  deviceId: Value(upload.deviceId),
                ),
        ]);
      });
      await _db
          .into(_db.aiUsageRemoteDevices)
          .insertOnConflictUpdate(
            AiUsageRemoteDevicesCompanion.insert(
              deviceId: upload.deviceId,
              name: upload.deviceName,
              version: Value(version),
              turnCount: Value(upload.turns.length),
              uploadedAt: upload.uploadedAt,
            ),
          );
    });
  }

  Future<void> _removeDevice(String deviceId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.aiUsageTurns,
      )..where((t) => t.deviceId.equals(deviceId))).go();
      await (_db.delete(
        _db.aiUsageRemoteDevices,
      )..where((d) => d.deviceId.equals(deviceId))).go();
    });
  }

  /// Sync was switched off: other devices' numbers would only go stale here,
  /// so drop them and show this device's own usage again.
  Future<void> _forgetRemoteDevices() async {
    final devices = await _db.select(_db.aiUsageRemoteDevices).get();
    final orphaned = await (_db.selectOnly(_db.aiUsageTurns)
          ..addColumns([_db.aiUsageTurns.id.count()])
          ..where(_db.aiUsageTurns.deviceId.isNotNull()))
        .map((row) => row.read(_db.aiUsageTurns.id.count()) ?? 0)
        .getSingle();
    if (devices.isEmpty && orphaned == 0) return;
    await _db.transaction(() async {
      await (_db.delete(
        _db.aiUsageTurns,
      )..where((t) => t.deviceId.isNotNull())).go();
      await _db.delete(_db.aiUsageRemoteDevices).go();
    });
  }

  /// Scanners only ever insert, so the row count plus the highest id changes
  /// exactly when there is something new to upload.
  Future<String> _localFingerprint() async {
    final count = _db.aiUsageTurns.id.count();
    final maxId = _db.aiUsageTurns.id.max();
    final row =
        await (_db.selectOnly(_db.aiUsageTurns)
              ..addColumns([count, maxId])
              ..where(_db.aiUsageTurns.deviceId.isNull()))
            .getSingle();
    return '${row.read(count) ?? 0}:${row.read(maxId) ?? 0}';
  }

  Future<File> _stateFile() async {
    final directory = await _supportDirectoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_stateFileName');
  }

  Future<_SyncIdentity> _loadIdentity() async {
    if (_identity case final identity?) return identity;
    Map<String, dynamic> data = const {};
    final file = await _stateFile();
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      data = const {};
    }
    final storedId = data['deviceId'];
    final identity = _SyncIdentity(
      deviceId: storedId is String && _deviceIdPattern.hasMatch(storedId)
          ? storedId
          : _randomDeviceId(),
      deviceName: _deviceNameOverride ?? _defaultDeviceName(),
      pushedFingerprint: data['pushedFingerprint'] as String?,
      pushedVersion: data['pushedVersion'] as int? ?? 0,
    );
    if (identity.deviceId != storedId) await _saveIdentity(identity);
    return _identity = identity;
  }

  Future<void> _saveIdentity(_SyncIdentity identity) async {
    try {
      final file = await _stateFile();
      await file.writeAsString(jsonEncode(identity.toJson()), flush: true);
    } catch (_) {
      // Losing this only costs one redundant upload next time.
    }
  }

  static final _deviceIdPattern = RegExp(r'^[0-9a-f]{16}$');

  static String _randomDeviceId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 8; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  static String _defaultDeviceName() {
    try {
      final host = Platform.localHostname.trim();
      if (host.isNotEmpty && host != 'localhost') return host;
    } catch (_) {}
    final os = Platform.operatingSystem;
    return '${os[0].toUpperCase()}${os.substring(1)} device';
  }
}

class _SyncIdentity {
  _SyncIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.pushedFingerprint,
    required this.pushedVersion,
  });

  final String deviceId;
  final String deviceName;
  String? pushedFingerprint;
  int pushedVersion;

  String get objectName => '$kAiUsageDeviceObjectPrefix$deviceId';

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'pushedFingerprint': pushedFingerprint,
    'pushedVersion': pushedVersion,
  };
}

/// One device's uploaded usage.
///
/// Turns are stored column-per-field with repeated strings (session ids,
/// models, projects) interned into a table: a busy history is thousands of
/// turns sharing a handful of sessions and models, and the dictionary keeps
/// the upload a fraction of the size of one JSON object per turn. Only the
/// same usage metadata the local database holds travels — never any prompt
/// or response text, and not the per-message dedup keys either.
class AiUsageDeviceUpload {
  AiUsageDeviceUpload({
    required this.deviceId,
    required this.deviceName,
    required this.uploadedAt,
    required this.turns,
  });

  static const _format = 1;

  final String deviceId;
  final String deviceName;
  final DateTime uploadedAt;
  final List<AiUsageTurn> turns;

  Map<String, Object?> toJson() {
    final strings = <String>[];
    final index = <String, int>{};
    int intern(String? value) {
      if (value == null) return -1;
      return index.putIfAbsent(value, () {
        strings.add(value);
        return strings.length - 1;
      });
    }

    final rows = [
      for (final t in turns)
        [
          t.timestamp.toUtc().millisecondsSinceEpoch,
          intern(t.sessionId),
          intern(t.model),
          t.inputTokens,
          t.outputTokens,
          t.cacheReadTokens,
          t.cacheCreationTokens,
          intern(t.project),
          t.source.name,
          t.effort?.name,
          t.reportedCost,
        ],
    ];
    return {
      'format': _format,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'uploadedAtMs': uploadedAt.millisecondsSinceEpoch,
      'strings': strings,
      'turns': rows,
    };
  }

  /// Null for anything unreadable, including a newer format this build
  /// doesn't understand — that device's usage is then skipped, not guessed.
  static AiUsageDeviceUpload? fromJson(Object? json) {
    if (json is! Map) return null;
    if (json['format'] != _format) return null;
    final deviceId = json['deviceId'];
    final strings = json['strings'];
    final rows = json['turns'];
    if (deviceId is! String || strings is! List || rows is! List) return null;

    String? lookup(Object? i) =>
        i is int && i >= 0 && i < strings.length ? strings[i].toString() : null;
    int count(Object? v) => v is num ? v.toInt() : 0;

    final turns = <AiUsageTurn>[];
    for (final row in rows) {
      if (row is! List || row.length < 11) continue;
      final source = AiUsageSource.values
          .where((s) => s.name == row[8])
          .firstOrNull;
      final sessionId = lookup(row[1]);
      final model = lookup(row[2]);
      final ms = row[0];
      if (source == null || sessionId == null || model == null || ms is! int) {
        continue;
      }
      turns.add(
        AiUsageTurn(
          id: 0,
          sessionId: sessionId,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
          model: model,
          inputTokens: count(row[3]),
          outputTokens: count(row[4]),
          cacheReadTokens: count(row[5]),
          cacheCreationTokens: count(row[6]),
          project: lookup(row[7]),
          source: source,
          effort: row[9] is String ? effortFromLog(row[9] as String) : null,
          reportedCost: row[10] is num ? (row[10] as num).toDouble() : null,
          deviceId: deviceId,
        ),
      );
    }
    return AiUsageDeviceUpload(
      deviceId: deviceId,
      deviceName: json['deviceName']?.toString() ?? 'Another device',
      uploadedAt: DateTime.fromMillisecondsSinceEpoch(
        json['uploadedAtMs'] as int? ?? 0,
      ),
      turns: turns,
    );
  }
}

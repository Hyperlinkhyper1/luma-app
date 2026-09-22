import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'store.dart';
import 'util.dart';

/// The server-side part of CS2 offline saving.
///
/// This is deliberately separate from encrypted sync blobs: the scheduler has
/// to be able to read the market hash names in order to ask Steam for prices.
/// It contains only the tracked listing metadata and market observations, not
/// a Steam credential.
class Cs2OfflineStore {
  Cs2OfflineStore._(this._file);

  final File _file;
  final Map<String, Map<String, dynamic>> _byUser = {};

  static Future<Cs2OfflineStore> open(String dataDir) async {
    final store = Cs2OfflineStore._(File('$dataDir/cs2_offline.json'));
    if (!await store._file.exists()) return store;
    try {
      final decoded = jsonDecode(await store._file.readAsString());
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.key is String && entry.value is Map) {
            store._byUser[entry.key as String] =
                Map<String, dynamic>.from(entry.value as Map);
          }
        }
      }
    } catch (_) {
      // A malformed optional cache must not stop the sync server starting.
    }
    return store;
  }

  Map<String, dynamic>? forUser(String userId) => _byUser[userId];

  Future<void> put(String userId, Map<String, dynamic> value) async {
    _byUser[userId] = value;
    await atomicWriteString(_file.path, jsonEncode(_byUser));
  }

  Future<void> deleteForUser(String userId) async {
    if (_byUser.remove(userId) == null) return;
    await atomicWriteString(_file.path, jsonEncode(_byUser));
  }
}

/// Executes due offline checks. Schedule boundaries are UTC epoch boundaries:
/// Nova is checked on every hour and Orbit every sixth hour. A missed boundary
/// is skipped rather than run immediately when the process starts, so opening
/// the app or restarting the server never creates an extra refresh.
class Cs2OfflineScheduler {
  Cs2OfflineScheduler({required this.accounts, required this.store}) {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => runDue());
  }

  final Store accounts;
  final Cs2OfflineStore store;
  Timer? _timer;
  bool _running = false;

  static const _startupGrace = Duration(minutes: 2);

  Future<void> runDue({DateTime? now}) async {
    if (_running) return;
    _running = true;
    try {
      final current = now ?? DateTime.now().toUtc();
      for (final entry in accounts.usersById.entries) {
        final config = store.forUser(entry.key);
        if (config == null || config['enabled'] != true) continue;
        if (entry.value.planId != 'orbit' && entry.value.planId != 'nova') {
          continue;
        }
        final intervalHours = entry.value.planId == 'nova' ? 1 : 6;
        final configuredInterval =
            (config['intervalHours'] as num?)?.toInt() ?? intervalHours;
        if (configuredInterval != intervalHours) {
          // A plan change changes the cadence, but not the fact that checks
          // happen only on aligned boundaries. Re-anchor without checking.
          await _advanceSchedule(entry.key, config, current, intervalHours);
          continue;
        }
        final nextMs = (config['nextCheckAtMs'] as num?)?.toInt();
        if (nextMs == null) continue;
        final next = DateTime.fromMillisecondsSinceEpoch(nextMs, isUtc: true);
        if (next.isAfter(current)) continue;

        // A process may have been down over a boundary. Advance without
        // checking so a restart is never an implicit refresh.
        final age = current.difference(next);
        if (age > _startupGrace) {
          await _advanceSchedule(entry.key, config, current, intervalHours);
          continue;
        }

        await _advanceSchedule(entry.key, config, current, intervalHours);
        await _check(entry.key, config);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _advanceSchedule(
    String userId,
    Map<String, dynamic> config,
    DateTime now,
    int intervalHours,
  ) async {
    final intervalMs = Duration(hours: intervalHours).inMilliseconds;
    final nowMs = now.millisecondsSinceEpoch;
    final nextMs = ((nowMs ~/ intervalMs) + 1) * intervalMs;
    config['intervalHours'] = intervalHours;
    config['nextCheckAtMs'] = nextMs;
    await store.put(userId, config);
  }

  Future<void> _check(String userId, Map<String, dynamic> config) async {
    final rawItems = config['items'];
    if (rawItems is! List) return;
    final items =
        rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (items.isEmpty) return;

    final points = (config['points'] is List)
        ? (config['points'] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList()
        : <Map<String, dynamic>>[];
    final observedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final client = HttpClient();
    try {
      for (final item in items) {
        final hash = item['marketHashName'];
        if (hash is! String || hash.isEmpty) continue;
        try {
          final uri =
              Uri.https('steamcommunity.com', '/market/priceoverview/', {
            'appid': '730',
            'currency': '1',
            'market_hash_name': hash,
          });
          final request = await client.getUrl(uri);
          final response =
              await request.close().timeout(const Duration(seconds: 30));
          if (response.statusCode == 429) break;
          final body =
              jsonDecode(await response.transform(utf8.decoder).join());
          if (response.statusCode != 200 ||
              body is! Map ||
              body['success'] != true) {
            continue;
          }
          final lowest = _parseUsd(body['lowest_price']);
          final median = _parseUsd(body['median_price']);
          item
            ..['lastLowestCents'] = lowest
            ..['lastMedianCents'] = median
            ..['currency'] = 'USD'
            ..['priceFetchedAtMs'] = observedAtMs;
          points.add({
            'marketHashName': hash,
            'observedAtMs': observedAtMs,
            'lowestCents': lowest,
            'medianCents': median,
            'currency': 'USD',
          });
        } catch (_) {
          // One listing failing must not prevent the rest of the account's
          // scheduled sweep from being attempted.
        }
        await Future<void>.delayed(const Duration(milliseconds: 2600));
      }
    } finally {
      client.close(force: true);
    }

    config
      ..['items'] = items
      ..['points'] = points
      ..['lastCheckedAtMs'] = observedAtMs;
    if (points.length > 20000) {
      config['points'] = points.sublist(points.length - 20000);
    }
    await store.put(userId, config);
  }

  static int? _parseUsd(Object? raw) {
    if (raw is! String) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.contains('.')
        ? cleaned.replaceAll(',', '')
        : cleaned.replaceFirst(',', '.');
    final value = double.tryParse(normalized);
    return value == null ? null : (value * 100).round();
  }

  void dispose() => _timer?.cancel();
}

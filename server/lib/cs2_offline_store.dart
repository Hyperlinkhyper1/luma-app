import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'store.dart';
import 'util.dart';

/// Upper bound on one offline-saving upload. There is deliberately no cap on
/// how many listings or copies a user tracks — a linked inventory can hold
/// hundreds of stickers and cases — only on the size of a single request.
const kCs2OfflineMaxBodyBytes = 64 * 1024 * 1024;

/// Most recent price observations kept per user. Backfilled Steam history is
/// a few hundred points per listing, so this leaves room for well over a
/// thousand listings before the oldest readings roll off.
const kCs2OfflineMaxPoints = 400000;

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

enum _Cs2CheckResult { complete, pending, rateLimited }

/// Executes due offline checks. Schedule boundaries are UTC epoch boundaries:
/// Nova and Orbit are checked every hour. Missed checks are caught up when
/// the server starts again.
class Cs2OfflineScheduler {
  Cs2OfflineScheduler({
    required this.accounts,
    required this.store,
    Future<({int statusCode, String body})> Function(Uri uri)? fetchPrice,
    Duration requestSpacing = const Duration(milliseconds: 3500),
  })  : _fetchPrice = fetchPrice,
        _requestSpacing = requestSpacing {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => runDue());
  }

  final Store accounts;
  final Cs2OfflineStore store;
  final Future<({int statusCode, String body})> Function(Uri uri)? _fetchPrice;
  final Duration _requestSpacing;

  Timer? _timer;
  bool _running = false;
  DateTime? _rateLimitedUntil;
  DateTime? _lastRequestAt;
  int _nextUserIndex = 0;
  static const _requestsPerUserPerPass = 10;

  Future<void> runDue({DateTime? now}) async {
    if (_running) return;
    _running = true;
    try {
      final current = now ?? DateTime.now().toUtc();
      if (_rateLimitedUntil != null && current.isBefore(_rateLimitedUntil!)) {
        return;
      }
      final users = accounts.usersById.entries.toList();
      for (var offset = 0; offset < users.length; offset++) {
        final index = (_nextUserIndex + offset) % users.length;
        final entry = users[index];
        final config = store.forUser(entry.key);
        if (config == null || config['enabled'] != true) continue;
        if (entry.value.planId != 'orbit' && entry.value.planId != 'nova') {
          continue;
        }
        const intervalHours = 1;
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

        await _advanceSchedule(entry.key, config, current, intervalHours);
        final result = await _check(entry.key, config);
        if (result != _Cs2CheckResult.complete) {
          final finished = now ?? DateTime.now().toUtc();
          final retryDelay = result == _Cs2CheckResult.rateLimited
              ? const Duration(minutes: 15)
              : const Duration(seconds: 15);
          config['nextCheckAtMs'] =
              finished.add(retryDelay).millisecondsSinceEpoch;
          await store.put(entry.key, config);
          if (result == _Cs2CheckResult.rateLimited) {
            _rateLimitedUntil = finished.add(retryDelay);
            _nextUserIndex = (index + 1) % users.length;
            break;
          }
        }
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

  Future<_Cs2CheckResult> _check(
      String userId, Map<String, dynamic> config) async {
    final rawItems = config['items'];
    if (rawItems is! List) return _Cs2CheckResult.complete;
    final items =
        rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (items.isEmpty) return _Cs2CheckResult.complete;

    final points = (config['points'] is List)
        ? (config['points'] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList()
        : <Map<String, dynamic>>[];
    final pending = config['pendingPriceHashes'];
    final pendingHashes =
        pending is List ? pending.whereType<String>().toSet() : null;
    final checkOrder = items.indexed
        .where((item) =>
            pendingHashes == null ||
            pendingHashes.contains(item.$2['marketHashName']))
        .toList()
      ..sort((a, b) {
        final aValue = a.$2['priceFetchedAtMs'];
        final bValue = b.$2['priceFetchedAtMs'];
        final aTime = aValue is num ? aValue.toInt() : null;
        final bTime = bValue is num ? bValue.toInt() : null;
        if (aTime == null && bTime != null) return -1;
        if (aTime != null && bTime == null) return 1;
        final ageOrder = (aTime ?? 0).compareTo(bTime ?? 0);
        return ageOrder == 0 ? a.$1.compareTo(b.$1) : ageOrder;
      });
    final client = HttpClient();
    var requested = 0;
    var outcome = _Cs2CheckResult.complete;
    try {
      for (var index = 0; index < checkOrder.length; index++) {
        final (_, item) = checkOrder[index];
        final hash = item['marketHashName'];
        if (hash is! String || hash.isEmpty) continue;
        if (requested >= _requestsPerUserPerPass) {
          config['pendingPriceHashes'] = [
            for (final (_, remaining) in checkOrder.skip(index))
              if (remaining['marketHashName'] is String)
                remaining['marketHashName'],
          ];
          outcome = _Cs2CheckResult.pending;
          break;
        }
        final previous = _lastRequestAt;
        if (previous != null) {
          final remaining =
              _requestSpacing - DateTime.now().difference(previous);
          if (remaining > Duration.zero) await Future<void>.delayed(remaining);
        }
        _lastRequestAt = DateTime.now();
        requested++;
        try {
          final uri =
              Uri.https('steamcommunity.com', '/market/priceoverview/', {
            'appid': '730',
            'currency': '1',
            'market_hash_name': hash,
          });
          final fetchPrice = _fetchPrice;
          final result = fetchPrice == null
              ? await () async {
                  final request = await client.getUrl(uri);
                  final response = await request.close().timeout(
                        const Duration(seconds: 30),
                      );
                  if (response.statusCode == 429) {
                    return (statusCode: response.statusCode, body: '');
                  }
                  return (
                    statusCode: response.statusCode,
                    body: await response.transform(utf8.decoder).join(),
                  );
                }()
              : await fetchPrice(uri);
          if (result.statusCode == 429) {
            config['pendingPriceHashes'] = [
              for (final (_, remaining) in checkOrder.skip(index))
                if (remaining['marketHashName'] is String)
                  remaining['marketHashName'],
            ];
            outcome = _Cs2CheckResult.rateLimited;
            break;
          }
          final body = jsonDecode(result.body);
          if (result.statusCode != 200 ||
              body is! Map ||
              body['success'] != true) {
            continue;
          }
          final lowest = _parseUsd(body['lowest_price']);
          final median = _parseUsd(body['median_price']);
          if (lowest == null && median == null) continue;
          final observedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
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
      }
    } finally {
      client.close(force: true);
    }

    if (outcome == _Cs2CheckResult.complete)
      config.remove('pendingPriceHashes');

    config
      ..['items'] = items
      ..['points'] = points
      ..['lastCheckedAtMs'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (points.length > kCs2OfflineMaxPoints) {
      config['points'] = points.sublist(points.length - kCs2OfflineMaxPoints);
    }
    await store.put(userId, config);
    return outcome;
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

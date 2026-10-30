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

/// Executes due offline checks. Schedule boundaries are UTC epoch boundaries:
/// Nova is checked on every hour and Orbit every sixth hour. A missed boundary
/// is skipped rather than run immediately when the process starts, so opening
/// the app or restarting the server never creates an extra refresh.
class Cs2OfflineScheduler {
  Cs2OfflineScheduler({
    required this.accounts,
    required this.store,
    Future<({int statusCode, String body})> Function(Uri uri)? fetchPrice,
    Future<({int statusCode, String body})> Function(Uri uri)? fetchBulkPrices,
    Duration requestSpacing = const Duration(milliseconds: 3500),
  })  : _fetchPrice = fetchPrice,
        _fetchBulkPrices = fetchBulkPrices,
        // A test that fakes Steam alone must not reach the real bulk file.
        _bulkEnabled = fetchPrice == null || fetchBulkPrices != null,
        _requestSpacing = requestSpacing {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => runDue());
  }

  final Store accounts;
  final Cs2OfflineStore store;
  final Future<({int statusCode, String body})> Function(Uri uri)? _fetchPrice;
  final Future<({int statusCode, String body})> Function(Uri uri)?
      _fetchBulkPrices;
  final bool _bulkEnabled;
  final Duration _requestSpacing;

  /// csgotrader.app's daily file of every CS2 item's average Steam sale
  /// price, in USD. One download prices every user's every listing, where
  /// Steam's `priceoverview` would take one rate-limited request each.
  static final _bulkUri =
      Uri.https('prices.csgotrader.app', '/latest/steam.json');
  Map<String, int>? _bulk;
  DateTime? _bulkAt;
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
    final bulk = await _bulkPrices();
    final steamItems = <Map<String, dynamic>>[];
    for (final item in items) {
      final hash = item['marketHashName'];
      final cents = hash is String && bulk != null ? bulk[hash] : null;
      if (cents == null) {
        steamItems.add(item);
        continue;
      }
      // The file changes once a day; a check that finds the same price
      // again records nothing rather than another identical point.
      if (item['lastMedianCents'] == cents && item['lastLowestCents'] == null) {
        continue;
      }
      item
        ..['lastLowestCents'] = null
        ..['lastMedianCents'] = cents
        ..['currency'] = 'USD'
        ..['priceFetchedAtMs'] = observedAtMs;
      points.add({
        'marketHashName': hash,
        'observedAtMs': observedAtMs,
        'lowestCents': null,
        'medianCents': cents,
        'currency': 'USD',
      });
    }
    final checkOrder = steamItems.indexed.toList()
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
    var requested = false;
    try {
      for (final (_, item) in checkOrder) {
        final hash = item['marketHashName'];
        if (hash is! String || hash.isEmpty) continue;
        if (requested) await Future<void>.delayed(_requestSpacing);
        requested = true;
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
          if (result.statusCode == 429) break;
          final body = jsonDecode(result.body);
          if (result.statusCode != 200 ||
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
      }
    } finally {
      client.close(force: true);
    }

    config
      ..['items'] = items
      ..['points'] = points
      ..['lastCheckedAtMs'] = observedAtMs;
    if (points.length > kCs2OfflineMaxPoints) {
      config['points'] = points.sublist(points.length - kCs2OfflineMaxPoints);
    }
    await store.put(userId, config);
  }

  /// The bulk file, fetched at most once an hour and shared by every user's
  /// check in a run. Null when it can't be read; each listing then falls
  /// back to Steam.
  Future<Map<String, int>?> _bulkPrices() async {
    if (!_bulkEnabled) return null;
    final cached = _bulk;
    final at = _bulkAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(hours: 1)) {
      return cached;
    }
    try {
      final fetch = _fetchBulkPrices;
      final ({int statusCode, String body}) result;
      if (fetch != null) {
        result = await fetch(_bulkUri);
      } else {
        final client = HttpClient();
        try {
          final request = await client.getUrl(_bulkUri);
          final response =
              await request.close().timeout(const Duration(seconds: 60));
          result = (
            statusCode: response.statusCode,
            body: await response.transform(utf8.decoder).join(),
          );
        } finally {
          client.close(force: true);
        }
      }
      if (result.statusCode != 200) return null;
      final decoded = jsonDecode(result.body);
      if (decoded is! Map) return null;
      final cents = <String, int>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        if (key is! String || value is! Map) continue;
        for (final window in const [
          'last_24h',
          'last_7d',
          'last_30d',
          'last_90d',
        ]) {
          final price = value[window];
          if (price is num && price > 0) {
            cents[key] = (price * 100).round();
            break;
          }
        }
      }
      if (cents.isEmpty) return null;
      _bulk = cents;
      _bulkAt = DateTime.now();
      return cents;
    } catch (_) {
      return null;
    }
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

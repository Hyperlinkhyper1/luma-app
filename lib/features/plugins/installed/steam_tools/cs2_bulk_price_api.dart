import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;

/// Every CS2 market item's recent Steam price, from one download.
class Cs2BulkPrices {
  const Cs2BulkPrices({required this.updatedAt, required this.cents});

  /// When the file was last rebuilt upstream — the time its prices describe,
  /// not when this device downloaded it.
  final DateTime updatedAt;

  /// USD cents keyed by exact `market_hash_name`.
  final Map<String, int> cents;
}

/// Reads csgotrader.app's daily Steam Community Market price file.
///
/// Steam's own `priceoverview` answers one listing per request and starts
/// refusing a home IP after roughly twenty a minute, so an inventory with
/// hundreds of stickers and cases could never be priced from it. This file
/// is a public, keyless CDN download (~550 KB) carrying the average Steam
/// sale price of every CS2 item over the last 24 hours, 7, 30 and 90 days,
/// in USD. One request prices any number of tracked listings, which is what
/// lets tracking be unlimited without tripping Steam's rate limit at all.
class Cs2BulkPriceApi {
  Cs2BulkPriceApi({http.Client? client, this.cacheFor = const Duration(hours: 1)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration cacheFor;
  Cs2BulkPrices? _cached;
  DateTime? _cachedAt;

  static final _uri = Uri.https('prices.csgotrader.app', '/latest/steam.json');
  static const _timeout = Duration(seconds: 45);

  /// The latest file, reused for [cacheFor] so tracking several listings in
  /// a row costs one download. Null when it cannot be fetched or read —
  /// callers fall back to asking Steam per listing.
  Future<Cs2BulkPrices?> fetch({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (cached != null && cachedAt != null && at.difference(cachedAt) < cacheFor) {
      return cached;
    }
    try {
      final response = await _client.get(_uri).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final prices = parseCs2BulkPrices(
        response.body,
        updatedAt: _lastModified(response.headers['last-modified']) ?? at,
      );
      if (prices == null) return null;
      _cached = prices;
      _cachedAt = at;
      return prices;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _lastModified(String? header) {
    if (header == null) return null;
    try {
      return HttpDate.parse(header).toLocal();
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}

/// Parses the `{name: {last_24h, last_7d, last_30d, last_90d}}` file. The
/// freshest window that has a price wins: half the catalog sells too rarely
/// to have a sale in any given day.
Cs2BulkPrices? parseCs2BulkPrices(String body, {required DateTime updatedAt}) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  final cents = <String, int>{};
  for (final MapEntry(:key, :value) in decoded.entries) {
    if (key is! String || value is! Map) continue;
    for (final window in const ['last_24h', 'last_7d', 'last_30d', 'last_90d']) {
      final price = value[window];
      if (price is num && price > 0) {
        cents[key] = (price * 100).round();
        break;
      }
    }
  }
  if (cents.isEmpty) return null;
  return Cs2BulkPrices(updatedAt: updatedAt, cents: cents);
}

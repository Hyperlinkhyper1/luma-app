import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cs2_market_api.dart';

/// One historical Steam sale median, already converted to USD cents.
class Cs2HistoryPoint {
  const Cs2HistoryPoint({required this.at, required this.cents});

  final DateTime at;
  final int cents;
}

/// Reads a listing's full Community Market sale history.
///
/// Steam's redesigned market pages fetch their chart from
/// `/market/actions?q=QueryPriceHistory`, the same data the old logged-in
/// `pricehistory` endpoint returned, but without needing a session: daily
/// medians back to the listing's first sale and hourly ones for the last
/// month. Prices come back in the currency Steam picks for the caller's
/// region ([ecurrency]), so [usdPerUnit] converts them before they meet the
/// USD readings everything else in the CS2 tables is stored in.
class Cs2PriceHistoryApi {
  Cs2PriceHistoryApi({
    http.Client? client,
    required Future<double?> Function(String currency) usdPerUnit,
  })  : _client = client ?? http.Client(),
        _usdPerUnit = usdPerUnit;

  final http.Client _client;
  final Future<double?> Function(String currency) _usdPerUnit;
  static const _timeout = Duration(seconds: 30);

  /// Null when Steam has no history for the listing or it can't be read in
  /// a currency we can convert. Throws [Cs2MarketApiException] with status
  /// 429 when rate limited, so the caller can back off instead of skipping.
  Future<List<Cs2HistoryPoint>?> fetch(String marketHashName) async {
    final uri = Uri.https('steamcommunity.com', '/market/actions', {
      'q': 'QueryPriceHistory',
      'qp': jsonEncode([Cs2MarketApi.csAppId, marketHashName]),
    });
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'x-valve-request-type': 'queryAction'})
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
    if (response.statusCode == 429) {
      throw const Cs2MarketApiException('rate limited', status: 429);
    }
    if (response.statusCode != 200) return null;
    final parsed = parseCs2PriceHistory(response.body);
    if (parsed == null || parsed.prices.isEmpty) return null;
    final code = steamCurrencyCode(parsed.ecurrency);
    if (code == null) return null;
    final rate = code == 'USD' ? 1.0 : await _usdPerUnit(code);
    if (rate == null || rate <= 0) return null;
    return [
      for (final (at, median) in parsed.prices)
        Cs2HistoryPoint(at: at, cents: (median * rate * 100).round()),
    ];
  }

  void close() => _client.close();
}

/// `{data: {ecurrency, prices: [{time, price_median, purchases}]}}`, also
/// accepting the bare inner object the page embeds server-side.
({int ecurrency, List<(DateTime, double)> prices})? parseCs2PriceHistory(
  String body,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is Map && decoded['data'] is Map) decoded = decoded['data'];
  if (decoded is! Map) return null;
  final ecurrency = decoded['ecurrency'];
  final raw = decoded['prices'];
  if (ecurrency is! num || raw is! List) return null;
  final prices = <(DateTime, double)>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final time = entry['time'];
    final median = entry['price_median'];
    if (time is! num || median is! num || median <= 0) continue;
    prices.add((
      DateTime.fromMillisecondsSinceEpoch(time.toInt() * 1000),
      median.toDouble(),
    ));
  }
  prices.sort((a, b) => a.$1.compareTo(b.$1));
  return (ecurrency: ecurrency.toInt(), prices: prices);
}

/// Steam's numeric wallet currency ids, for the ones the ECB feed can
/// convert. Anything else is left unconverted rather than guessed at.
String? steamCurrencyCode(int ecurrency) => switch (ecurrency) {
      1 => 'USD',
      2 => 'GBP',
      3 => 'EUR',
      4 => 'CHF',
      6 => 'PLN',
      7 => 'BRL',
      8 => 'JPY',
      9 => 'NOK',
      10 => 'IDR',
      11 => 'MYR',
      12 => 'PHP',
      13 => 'SGD',
      14 => 'THB',
      16 => 'KRW',
      17 => 'TRY',
      19 => 'MXN',
      20 => 'CAD',
      21 => 'AUD',
      22 => 'NZD',
      23 => 'CNY',
      24 => 'INR',
      28 => 'ZAR',
      29 => 'HKD',
      35 => 'ILS',
      _ => null,
    };

/// Thins Steam's history to what a chart can use: hourly for the last two
/// days, six-hourly for the last month, weekly for the year before that.
/// Each bucket keeps its average, and anything older than a year is dropped
/// — a few hundred rows per listing rather than thousands, which matters
/// once an inventory has hundreds of listings.
List<Cs2HistoryPoint> downsampleCs2History(
  List<Cs2HistoryPoint> points,
  DateTime now,
) {
  final hour = Duration.millisecondsPerHour;
  int bucketMs(DateTime at) {
    final age = now.difference(at);
    if (age <= const Duration(days: 2)) return hour;
    if (age <= const Duration(days: 30)) return hour * 6;
    return hour * 24 * 7;
  }

  final cutoff = now.subtract(const Duration(days: 365));
  final buckets = <(int, int), (int, int, int)>{};
  for (final point in points) {
    if (point.at.isBefore(cutoff) || point.at.isAfter(now)) continue;
    final size = bucketMs(point.at);
    final key = (size, point.at.millisecondsSinceEpoch ~/ size);
    final (sum, count, latestMs) = buckets[key] ?? (0, 0, 0);
    final ms = point.at.millisecondsSinceEpoch;
    buckets[key] = (sum + point.cents, count + 1, ms > latestMs ? ms : latestMs);
  }
  final out = [
    for (final (sum, count, latestMs) in buckets.values)
      Cs2HistoryPoint(
        at: DateTime.fromMillisecondsSinceEpoch(latestMs),
        cents: (sum / count).round(),
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return out;
}

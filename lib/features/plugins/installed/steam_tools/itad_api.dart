import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../sync/server_access.dart';

/// Raised for every IsThereAnyDeal request that did not come back usable.
/// The message is already user-facing.
class ItadApiException implements Exception {
  const ItadApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// One price ITAD recorded for a shop at a moment in time.
class ItadPricePoint {
  const ItadPricePoint({
    required this.timestamp,
    required this.finalCents,
    required this.regularCents,
    required this.cut,
    required this.currency,
  });

  final DateTime timestamp;
  final int finalCents;
  final int regularCents;
  final int cut;
  final String currency;
}

/// What ITAD knows about a game's price right now, and the lowest it has
/// ever gone.
class ItadOverview {
  const ItadOverview({
    this.currentCents,
    this.regularCents,
    this.cut = 0,
    this.lowestCents,
    this.lowestAt,
    this.currency = 'USD',
  });

  final int? currentCents;
  final int? regularCents;
  final int cut;
  final int? lowestCents;
  final DateTime? lowestAt;
  final String currency;
}

/// Reads real price history from IsThereAnyDeal — through the luma server's
/// `/api/v1/steam/itad/*` proxy, never directly.
///
/// This is the plugin's history source because Steam publishes none of its
/// own — its store API only ever answers with today's price. ITAD has been
/// recording shop prices for years, which is what makes the 1Y and 5Y ranges
/// mean anything on the first day the plugin is opened.
///
/// The proxy exists so nobody has to register for an ITAD key themselves:
/// the operator configures one once (`LUMA_ITAD_API_KEY`) and every approved
/// account shares it, the same way the app's AI chat already shares an
/// operator-configured Mistral/Google key. That means this, unlike the rest
/// of Steam Tools, only works once this device has an approved luma account
/// — [SyncService.serverReady] gates it, and every request goes through
/// [GatedServerClient] like everything else that talks to a luma server.
class ItadApi {
  ItadApi({
    required String baseUrl,
    required this.authToken,
    http.Client? client,
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _client = GatedServerClient(inner: client);

  final String _baseUrl;
  final String? authToken;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, String> get _headers => {
        if (authToken case final token?) 'Authorization': 'Bearer $token',
      };

  /// ITAD identifies games by its own UUID, so a Steam app id has to be
  /// translated before anything else can be asked about it.
  ///
  /// Returns null when ITAD simply does not carry the game — a normal
  /// outcome for region-locked or delisted apps, not an error.
  Future<String?> lookupGameId(int steamAppId) async {
    final uri = Uri.parse('$_baseUrl/api/v1/steam/itad/lookup')
        .replace(queryParameters: {'appid': '$steamAppId'});
    final body = await _get(uri, what: 'look that game up');
    final json = jsonDecode(body);
    if (json is! Map) return null;
    if (json['found'] != true) return null;
    final game = json['game'];
    if (game is! Map) return null;
    final id = game['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Every Steam price change ITAD has on file for [gameId], oldest first.
  ///
  /// The shop filter is applied client-side rather than through the API's
  /// `shops` parameter: that parameter takes ITAD's numeric shop ids, and
  /// hard-coding the number for Steam would silently return an empty history
  /// if ITAD ever renumbered them. Matching on the shop's name cannot go
  /// quietly wrong.
  Future<List<ItadPricePoint>> steamPriceHistory(
    String gameId, {
    String country = 'US',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/steam/itad/history')
        .replace(queryParameters: {'id': gameId, 'country': country});
    final body = await _get(uri, what: 'read that price history');
    final json = jsonDecode(body);
    if (json is! List) {
      throw const ItadApiException(
        'IsThereAnyDeal sent back an unexpected price history.',
      );
    }

    final points = <ItadPricePoint>[];
    for (final entry in json) {
      if (entry is! Map) continue;
      if (!_isSteam(entry['shop'])) continue;

      final timestamp = _parseDate(entry['timestamp']);
      if (timestamp == null) continue;

      // A null deal marks the game leaving the shop. There is no price to
      // plot for that, so it is skipped rather than drawn as free.
      final deal = entry['deal'];
      if (deal is! Map) continue;

      final price = _cents(deal['price']);
      if (price == null) continue;

      points.add(ItadPricePoint(
        timestamp: timestamp,
        finalCents: price,
        regularCents: _cents(deal['regular']) ?? price,
        cut: _int(deal['cut']) ?? 0,
        currency: _currency(deal['price']) ?? 'USD',
      ));
    }

    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return points;
  }

  /// The current and all-time-lowest Steam price for [gameId].
  Future<ItadOverview?> overview(
    String gameId, {
    String country = 'US',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/steam/itad/overview')
        .replace(queryParameters: {'country': country});
    final body =
        await _post(uri, jsonEncode([gameId]), what: 'read that game');
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final prices = json['prices'];
    if (prices is! List || prices.isEmpty) return null;
    final entry = prices.first;
    if (entry is! Map) return null;

    final current = entry['current'];
    final lowest = entry['lowest'];
    return ItadOverview(
      currentCents: current is Map ? _cents(current['price']) : null,
      regularCents: current is Map ? _cents(current['regular']) : null,
      cut: current is Map ? _int(current['cut']) ?? 0 : 0,
      lowestCents: lowest is Map ? _cents(lowest['price']) : null,
      lowestAt: lowest is Map ? _parseDate(lowest['timestamp']) : null,
      currency: (current is Map ? _currency(current['price']) : null) ??
          (lowest is Map ? _currency(lowest['price']) : null) ??
          'USD',
    );
  }

  void close() => _client.close();

  static bool _isSteam(Object? shop) {
    if (shop is! Map) return false;
    final name = shop['name'];
    return name is String && name.trim().toLowerCase() == 'steam';
  }

  /// ITAD quotes money as both a decimal `amount` and an `amountInt` in minor
  /// units. Only the integer is read — money never becomes a double here.
  static int? _cents(Object? price) {
    if (price is! Map) return null;
    final amountInt = _int(price['amountInt']);
    if (amountInt != null) return amountInt;
    // Older payloads occasionally carry only the decimal amount.
    final amount = price['amount'];
    if (amount is num) return (amount * 100).round();
    return null;
  }

  static String? _currency(Object? price) {
    if (price is! Map) return null;
    final currency = price['currency'];
    return currency is String && currency.isNotEmpty ? currency : null;
  }

  static int? _int(Object? value) => switch (value) {
        final int v => v,
        final double v => v.round(),
        final String v => int.tryParse(v),
        _ => null,
      };

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Future<String> _get(Uri uri, {required String what}) async {
    http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(_timeout);
    } on ServerAccessDeniedException {
      rethrow;
    } catch (_) {
      throw ItadApiException(
        'Could not reach the luma server to $what. Check your connection '
        'and try again.',
      );
    }
    return _body(response, what);
  }

  Future<String> _post(Uri uri, String body, {required String what}) async {
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } on ServerAccessDeniedException {
      rethrow;
    } catch (_) {
      throw ItadApiException(
        'Could not reach the luma server to $what. Check your connection '
        'and try again.',
      );
    }
    return _body(response, what);
  }

  String _body(http.Response response, String what) {
    if (response.statusCode == 404) {
      throw const ItadApiException(
        'The server operator has not set up price history. Ask them to add '
        'an IsThereAnyDeal key.',
        status: 404,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ItadApiException(
        'This needs a signed-in luma account. Sign in under Settings → '
        'Sync & account.',
        status: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw ItadApiException(
        'Too many price history requests right now. Wait a bit and try '
        'again.',
        status: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw ItadApiException(
        'Could not $what (HTTP ${response.statusCode}).',
        status: response.statusCode,
      );
    }
    return response.body;
  }
}

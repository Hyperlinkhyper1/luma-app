import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cs2_models.dart';

/// Raised for every Community Market request that did not come back usable.
class Cs2MarketApiException implements Exception {
  const Cs2MarketApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Reads current prices from Steam's Community Market.
///
/// `priceoverview` is the same public, keyless endpoint the Steam market
/// page itself calls to show a listing's price — no login, no session
/// cookie. That is also its limit: it is the *only* price data Steam
/// publishes for an item with no account attached. The history behind the
/// chart is not read from here at all; it is built locally by the
/// repository recording what this call returns over time. Currency is
/// always requested as USD (Steam's numeric id `1`) so every reading in the
/// local price-history table is directly comparable — mixing currencies
/// into one line would make the chart meaningless.
class Cs2MarketApi {
  Cs2MarketApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'steamcommunity.com';
  static const _timeout = Duration(seconds: 20);

  /// The app id Steam's market still files CS2 items under.
  static const csAppId = 730;

  Future<Cs2MarketPrice?> priceOverview(String marketHashName) async {
    final uri = Uri.https(_host, '/market/priceoverview/', {
      'appid': '$csAppId',
      'currency': '1',
      'market_hash_name': marketHashName,
    });

    http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } catch (e) {
      throw const Cs2MarketApiException(
        'Could not reach the Steam Community Market. Check your connection '
        'and try again.',
      );
    }

    if (response.statusCode == 429) {
      throw Cs2MarketApiException(
        'The Steam Community Market is rate limiting this device. Wait a '
        'few minutes and try again.',
        status: 429,
      );
    }
    if (response.statusCode != 200) {
      throw Cs2MarketApiException(
        'The Steam Community Market could not price that item '
        '(HTTP ${response.statusCode}).',
        status: response.statusCode,
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      body = decoded.cast<String, dynamic>();
    } catch (_) {
      throw const Cs2MarketApiException(
        'The Steam Community Market sent back an unreadable reply.',
      );
    }

    return Cs2MarketPrice.fromJson(body);
  }

  void close() => _client.close();
}

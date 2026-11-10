import 'dart:convert';

import 'cs2_inventory_api.dart';
import 'cs2_price_history_api.dart' show steamCurrencyCode;
import 'cs2_steam_session.dart';

/// An actual purchase of one inventory copy, including the buyer's fees.
class Cs2Purchase {
  const Cs2Purchase({
    required this.assetId,
    required this.marketHashName,
    required this.cents,
    required this.at,
  });

  final String assetId;
  final String marketHashName;

  /// USD cents, converted at the current exchange rate when necessary.
  final int cents;
  final DateTime at;
}

/// Reads My Market History through the user's own Steam browser. Cookies
/// stay in that browser; only the matching costs reach the repository.
/// Only exact received asset IDs are matched, never names or estimated costs.
class Cs2PurchaseHistoryApi {
  Cs2PurchaseHistoryApi({
    required this._usdPerUnit,
    this.pageSpacing = const Duration(milliseconds: 1200),
  });

  final Future<double?> Function(String currency) _usdPerUnit;
  final Duration pageSpacing;

  /// Yields each page's matches so costs already read survive a later error.
  /// [assets] maps owned asset IDs with missing costs to their market names.
  Stream<List<Cs2Purchase>> fetch({
    required String steamId,
    required Cs2SteamSession session,
    required Map<String, String> assets,
    bool Function()? isCancelled,
  }) async* {
    bool cancelled() => isCancelled?.call() ?? false;
    if (assets.isEmpty || cancelled()) return;
    if (await session.signedInSteamId() != steamId) {
      throw const Cs2InventoryException(
        'Sign in to Steam with the connected inventory account to read purchase history.',
      );
    }
    final pending = Map.of(assets);
    final rates = <String, double?>{'USD': 1};
    String? conversionError;
    var start = 0;
    while (pending.isNotEmpty && !cancelled()) {
      final response = await session.load(
        Uri.https('steamcommunity.com', '/market/myhistory/render/', {
          'start': '$start',
          'count': '500',
          'norender': '1',
          'l': 'english',
        }),
      );
      if (cancelled()) return;
      if (response.statusCode != 200) {
        throw Cs2InventoryException(
          response.statusCode == 429
              ? 'Steam rate limited purchase history. Refresh the inventory to try again.'
              : 'Steam could not read purchase history. Try refreshing the inventory.',
          status: response.statusCode,
        );
      }
      Object? raw;
      try {
        raw = jsonDecode(response.body);
      } on FormatException {
        throw const Cs2InventoryException(
          'Steam returned unreadable purchase history.',
        );
      }
      if (raw is! Map ||
          (raw['success'] != true && raw['success'] != 1) ||
          raw['events'] is! List ||
          _integer(raw['total_count']) == null) {
        throw const Cs2InventoryException(
          'Steam did not provide purchase history. Check your Steam sign-in and try again.',
        );
      }
      final events = raw['events'] as List;
      final total = _integer(raw['total_count'])!;
      final pageStart = _integer(raw['start']);
      final pageSize = _integer(raw['pagesize']) ?? events.length;
      if ((pageStart != null && pageStart != start) ||
          total < 0 ||
          (start < total &&
              (events.isEmpty || pageSize <= 0 || pageSize > 500))) {
        throw const Cs2InventoryException(
          'Steam returned an incomplete purchase history page.',
        );
      }
      final purchases = raw['purchases'];
      final matches = <Cs2Purchase>[];
      for (final event in events.whereType<Map>()) {
        if (_integer(event['event_type']) != 4 || purchases is! Map) continue;
        final purchase =
            purchases['${event['listingid']}_${event['purchaseid']}'];
        if (purchase is! Map ||
            purchase['steamid_purchaser'] != steamId ||
            ['failed', 'needs_rollback', 'funds_returned', 'funds_revoked'].any(
              (key) =>
                  purchase[key] == true || (_integer(purchase[key]) ?? 0) != 0,
            )) {
          continue;
        }
        final asset = purchase['asset'];
        if (asset is! Map ||
            _integer(asset['appid']) != 730 ||
            '${asset['new_contextid'] ?? asset['contextid']}' != '2' ||
            _integer(asset['amount']) != 1) {
          continue;
        }
        final assetId = asset['new_id'];
        if (assetId is! String || !pending.containsKey(assetId)) continue;
        final amount = _integer(purchase['paid_amount']);
        final fee = _integer(purchase['paid_fee']);
        final time = _integer(event['time_event']);
        final currencyId = _integer(purchase['currencyid']);
        if (amount == null ||
            amount < 0 ||
            fee == null ||
            fee < 0 ||
            time == null ||
            time <= 0 ||
            time > 8640000000000 ||
            currencyId == null) {
          continue;
        }
        final hash = pending.remove(assetId)!;
        final currency = steamCurrencyCode(
          currencyId >= 2000 ? currencyId - 2000 : currencyId,
        );
        if (currency == null) {
          conversionError =
              'Some purchase prices use an unsupported currency. Set those costs manually.';
          continue;
        }
        if (!rates.containsKey(currency)) {
          rates[currency] = await _usdPerUnit(currency);
        }
        final rate = rates[currency];
        if (rate == null || !rate.isFinite || rate <= 0) {
          conversionError =
              'Could not convert some purchase prices to USD. Refresh the inventory to try again.';
          continue;
        }
        matches.add(
          Cs2Purchase(
            assetId: assetId,
            marketHashName: hash,
            cents: ((amount + fee) * rate).round(),
            at: DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true),
          ),
        );
      }
      if (cancelled()) return;
      if (matches.isNotEmpty) yield matches;
      start += pageSize;
      if (start >= total || pending.isEmpty) break;
      if (pageSpacing > Duration.zero) await Future<void>.delayed(pageSpacing);
    }
    if (conversionError != null && !cancelled()) {
      throw Cs2InventoryException(conversionError);
    }
  }

  static int? _integer(Object? value) => switch (value) {
    int n => n,
    String s => int.tryParse(s),
    _ => null,
  };
}

import 'dart:convert';

import 'package:http/http.dart' as http;

/// A live quote for a ticker.
class StockQuote {
  const StockQuote({required this.priceCents, this.currency, this.name});
  final int priceCents;
  final String? currency;
  final String? name;
}

/// A single point in a price history series.
class PricePoint {
  const PricePoint(this.time, this.priceCents);
  final DateTime time;
  final int priceCents;
}

/// Selectable history windows for the chart, mapped to Yahoo range/interval.
enum ChartRange {
  day('1D', '1d', '5m'),
  week('1W', '5d', '30m'),
  month('1M', '1mo', '1d'),
  sixMonths('6M', '6mo', '1d'),
  year('1Y', '1y', '1d');

  const ChartRange(this.label, this.range, this.interval);
  final String label;
  final String range;
  final String interval;
}

/// Fetches stock prices without an API key.
///
/// Tries Stooq's CSV endpoint first (simple, keyless), then falls back to
/// Yahoo Finance's chart endpoint. Both require network access; on the web
/// build they may be blocked by CORS, but on the native desktop build they
/// work directly. Prices are returned in the instrument's native currency.
class StockService {
  const StockService._();

  static Future<StockQuote?> fetchQuote(String ticker) async {
    final t = ticker.trim();
    if (t.isEmpty) return null;
    return await _stooq(t) ??
        await _stooq('$t.us') ??
        await _yahoo(t);
  }

  /// Fetches an intraday/historical close-price series for [ticker] over
  /// [range] from Yahoo's chart endpoint. Returns an empty list on failure.
  static Future<List<PricePoint>> fetchHistory(
      String ticker, ChartRange range) async {
    try {
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(ticker)}?interval=${range.interval}&range=${range.range}');
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) luma-app/1.0',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = (json['chart']?['result'] as List?)?.firstOrNull;
      final timestamps = (result?['timestamp'] as List?)?.cast<num>();
      final quote =
          ((result?['indicators']?['quote'] as List?)?.firstOrNull)
              as Map<String, dynamic>?;
      final closes = quote?['close'] as List?;
      if (timestamps == null || closes == null) return const [];

      final points = <PricePoint>[];
      for (var i = 0; i < timestamps.length && i < closes.length; i++) {
        final close = closes[i];
        if (close is! num) continue;
        points.add(PricePoint(
          DateTime.fromMillisecondsSinceEpoch(timestamps[i].toInt() * 1000),
          (close * 100).round(),
        ));
      }
      return points;
    } catch (_) {
      return const [];
    }
  }

  static Future<StockQuote?> _stooq(String symbol) async {
    try {
      final uri = Uri.parse(
          'https://stooq.com/q/l/?s=${Uri.encodeComponent(symbol.toLowerCase())}&f=sd2t2ohlcvn&h&e=csv');
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final lines = const LineSplitter().convert(res.body);
      if (lines.length < 2) return null;
      final cols = lines[1].split(',');
      if (cols.length < 7) return null;
      final close = cols[6];
      if (close == 'N/D' || close.isEmpty) return null;
      final price = double.tryParse(close);
      if (price == null || price <= 0) return null;
      final name = cols.length > 8 ? cols[8] : null;
      return StockQuote(
        priceCents: (price * 100).round(),
        name: (name != null && name != 'N/D' && name.isNotEmpty) ? name : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<StockQuote?> _yahoo(String symbol) async {
    try {
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(symbol)}?interval=1d&range=1d');
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) luma-app/1.0',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = (json['chart']?['result'] as List?)?.firstOrNull;
      final meta = result?['meta'] as Map<String, dynamic>?;
      final price = (meta?['regularMarketPrice'] as num?)?.toDouble();
      if (price == null || price <= 0) return null;
      return StockQuote(
        priceCents: (price * 100).round(),
        currency: meta?['currency'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : this[0];
}

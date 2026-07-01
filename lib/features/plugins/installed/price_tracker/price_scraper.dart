import 'dart:convert';

import 'package:http/http.dart' as http;

class ScrapedPrice {
  ScrapedPrice({required this.price, required this.currency});
  final double price;
  final String currency;
}

class PriceScraperException implements Exception {
  PriceScraperException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PriceScraper {
  static const _timeout = Duration(seconds: 20);

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  Future<ScrapedPrice> fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw PriceScraperException('Invalid URL.');
    }

    final http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(_timeout);
    } catch (_) {
      throw PriceScraperException(
          'Could not reach the URL. Check your connection.');
    }

    if (res.statusCode != 200) {
      throw PriceScraperException(
          'The page returned an error (${res.statusCode}).');
    }

    final html = res.body;

    final result = _tryOpenGraph(html) ??
        _tryJsonLd(html) ??
        _tryMetaItemprop(html) ??
        _tryRegex(html);

    if (result == null) {
      throw PriceScraperException(
          'Could not find a price on this page. The site may require JavaScript or block scraping.');
    }

    return result;
  }

  static ScrapedPrice? _tryOpenGraph(String html) {
    final priceRe = RegExp(
        r'<meta[^>]+property=[\x22\x27](?:og|product):price:amount[\x22\x27][^>]+content=[\x22\x27]([0-9]+[.,][0-9]{1,2})[\x22\x27]',
        caseSensitive: false);
    final currencyRe = RegExp(
        r'<meta[^>]+property=[\x22\x27](?:og|product):price:currency[\x22\x27][^>]+content=[\x22\x27]([A-Z]{3})[\x22\x27]',
        caseSensitive: false);

    final m = priceRe.firstMatch(html);
    if (m == null) return null;

    final price = _parsePrice(m.group(1)!);
    if (price == null) return null;

    final currency = currencyRe.firstMatch(html)?.group(1) ?? '?';
    return ScrapedPrice(price: price, currency: currency);
  }

  static ScrapedPrice? _tryJsonLd(String html) {
    final scriptRe = RegExp(
        r'<script[^>]+type=[\x22\x27]application/ld\+json[\x22\x27][^>]*>([\s\S]*?)</script>',
        caseSensitive: false);

    for (final m in scriptRe.allMatches(html)) {
      try {
        final json = jsonDecode(m.group(1)!) as Object?;
        final result = _extractFromJsonLd(json);
        if (result != null) return result;
      } catch (_) {}
    }
    return null;
  }

  static ScrapedPrice? _extractFromJsonLd(Object? json) {
    if (json is List) {
      for (final item in json) {
        final r = _extractFromJsonLd(item);
        if (r != null) return r;
      }
      return null;
    }
    if (json is! Map) return null;

    final type = json['@type'];
    if (type == 'Product' || type == 'Offer') {
      final offers = json['offers'];
      if (offers != null) {
        final r = _extractFromJsonLd(offers);
        if (r != null) return r;
      }
      final rawPrice = json['price'];
      if (rawPrice != null) {
        final price = _parsePrice(rawPrice.toString());
        if (price != null) {
          final currency = json['priceCurrency']?.toString() ?? '?';
          return ScrapedPrice(price: price, currency: currency);
        }
      }
    }

    for (final value in json.values) {
      if (value is Map || value is List) {
        final r = _extractFromJsonLd(value as Object);
        if (r != null) return r;
      }
    }
    return null;
  }

  static ScrapedPrice? _tryMetaItemprop(String html) {
    final priceRe = RegExp(
        r'<[^>]+itemprop=[\x22\x27]price[\x22\x27][^>]+content=[\x22\x27]([0-9]+[.,][0-9]{1,2})[\x22\x27]',
        caseSensitive: false);
    final currencyRe = RegExp(
        r'<[^>]+itemprop=[\x22\x27]priceCurrency[\x22\x27][^>]+content=[\x22\x27]([A-Z]{3})[\x22\x27]',
        caseSensitive: false);

    final m = priceRe.firstMatch(html);
    if (m == null) return null;
    final price = _parsePrice(m.group(1)!);
    if (price == null) return null;
    final currency = currencyRe.firstMatch(html)?.group(1) ?? '?';
    return ScrapedPrice(price: price, currency: currency);
  }

  static ScrapedPrice? _tryRegex(String html) {
    final strippedHtml = html.replaceAll(RegExp(r'<[^>]+>'), ' ');

    final patterns = [
      RegExp(r'\$\s*([0-9]{1,4}(?:[.,][0-9]{3})*[.,][0-9]{2})'),
      RegExp(r'€\s*([0-9]{1,4}(?:[.,][0-9]{3})*[.,][0-9]{2})'),
      RegExp(r'£\s*([0-9]{1,4}(?:[.,][0-9]{3})*[.,][0-9]{2})'),
      RegExp(r'([0-9]{1,4}(?:[.,][0-9]{3})*[.,][0-9]{2})\s*(?:USD|EUR|GBP)'),
    ];

    final currencies = ['USD', 'EUR', 'GBP', '?'];

    for (var i = 0; i < patterns.length; i++) {
      final m = patterns[i].firstMatch(strippedHtml);
      if (m != null) {
        final price = _parsePrice(m.group(1)!);
        if (price != null) {
          final currency = i < 3 ? currencies[i] : currencies[3];
          return ScrapedPrice(price: price, currency: currency);
        }
      }
    }
    return null;
  }

  static double? _parsePrice(String raw) {
    var s = raw.trim();

    if (s.contains(',') && s.contains('.')) {
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      if (lastComma > lastDot) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (s.contains(',')) {
      final commaIdx = s.lastIndexOf(',');
      if (s.length - commaIdx == 3) {
        s = s.replaceAll(',', '');
      } else {
        s = s.replaceAll(',', '.');
      }
    }

    return double.tryParse(s);
  }
}

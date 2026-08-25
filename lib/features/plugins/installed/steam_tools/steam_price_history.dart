import 'data/steam_database.dart';

/// The windows the price chart can be shown over, in the order they appear
/// in the selector.
enum SteamPriceRange {
  fiveYears('5Y', Duration(days: 1826), 'the last five years'),
  year('1Y', Duration(days: 365), 'the last year'),
  sixMonths('6M', Duration(days: 182), 'the last six months'),
  month('1M', Duration(days: 30), 'the last month'),
  week('1W', Duration(days: 7), 'the last week'),
  day('1D', Duration(days: 1), 'the last day');

  const SteamPriceRange(this.label, this.span, this.blurb);

  final String label;
  final Duration span;

  /// Sentence fragment for the empty/short-history note.
  final String blurb;

  DateTime startFrom(DateTime now) => now.subtract(span);
}

/// One point on the chart: a price that held from [at] until the next
/// sample.
class SteamPriceSample {
  const SteamPriceSample({
    required this.at,
    required this.finalCents,
    required this.discountPercent,
  });

  final DateTime at;
  final int finalCents;
  final int discountPercent;
}

/// What the chart needs to draw itself, and to be honest about what it is
/// drawing.
class SteamPriceSeries {
  const SteamPriceSeries({
    required this.samples,
    required this.range,
    required this.currency,
    this.historyFrom,
    this.coversFullRange = false,
  });

  final List<SteamPriceSample> samples;
  final SteamPriceRange range;
  final String currency;

  /// The oldest price IsThereAnyDeal has on file for this game. Null when
  /// there is no history at all.
  ///
  /// A game released last month has no five-year history, and never will.
  /// The UI uses this to say where the record actually starts instead of
  /// letting a short flat line imply five unchanging years.
  final DateTime? historyFrom;

  /// Whether the record starts at or before the window opened — i.e. whether
  /// the line really does span the whole range the user picked.
  final bool coversFullRange;

  bool get isEmpty => samples.isEmpty;

  int? get lowestCents => samples.isEmpty
      ? null
      : samples.map((s) => s.finalCents).reduce((a, b) => a < b ? a : b);

  int? get highestCents => samples.isEmpty
      ? null
      : samples.map((s) => s.finalCents).reduce((a, b) => a > b ? a : b);

  /// True when the price never moved across the window — the chart is a
  /// straight line and the "lowest/highest" pair would be the same number
  /// twice.
  bool get isFlat => lowestCents != null && lowestCents == highestCents;
}

/// Builds the series for [range] out of a game's full price history.
///
/// [points] must be ordered oldest first, and holds one row per price
/// *change* — that is how IsThereAnyDeal records them. Drawing those points
/// alone would leave the line starting wherever the last change happened and
/// stopping there too. Two fixes make the window whole:
///
///  * the most recent price from *before* the window is carried forward to
///    the window's start, so a game whose price last moved two years ago
///    still draws a full line across "1M";
///  * the newest known price is repeated at [now], so the line always runs
///    to the right-hand edge rather than trailing off at the last change.
SteamPriceSeries buildSteamPriceSeries(
  List<SteamPricePoint> points,
  SteamPriceRange range,
  DateTime now, {
  String fallbackCurrency = 'USD',
}) {
  final start = range.startFrom(now);
  final currency = points.isEmpty ? fallbackCurrency : points.last.currency;

  if (points.isEmpty) {
    return SteamPriceSeries(
      samples: const [],
      range: range,
      currency: currency,
    );
  }

  final historyFrom = points.first.observedAt;
  final inWindow = points.where((p) => !p.observedAt.isBefore(start)).toList();

  SteamPricePoint? carried;
  for (final point in points) {
    if (point.observedAt.isBefore(start)) {
      carried = point;
    } else {
      break;
    }
  }

  final samples = <SteamPriceSample>[
    if (carried != null)
      SteamPriceSample(
        at: start,
        finalCents: carried.finalCents,
        discountPercent: carried.discountPercent,
      ),
    for (final p in inWindow)
      SteamPriceSample(
        at: p.observedAt,
        finalCents: p.finalCents,
        discountPercent: p.discountPercent,
      ),
  ];

  if (samples.isEmpty) {
    return SteamPriceSeries(
      samples: const [],
      range: range,
      currency: currency,
      historyFrom: historyFrom,
    );
  }

  final last = samples.last;
  if (last.at.isBefore(now)) {
    samples.add(SteamPriceSample(
      at: now,
      finalCents: last.finalCents,
      discountPercent: last.discountPercent,
    ));
  }

  return SteamPriceSeries(
    samples: samples,
    range: range,
    currency: currency,
    historyFrom: historyFrom,
    coversFullRange: !historyFrom.isAfter(start),
  );
}

/// Formats integer minor units the way the store does.
///
/// Steam quotes every price in minor units (5999 = $59.99) and luma stores
/// them that way, so this is the only place the value becomes a decimal.
String formatSteamPrice(int cents, String currency) {
  final symbol = _currencySymbols[currency.toUpperCase()];
  final amount = (cents / 100).toStringAsFixed(2);
  if (symbol != null) return '$symbol$amount';
  return '$amount ${currency.toUpperCase()}';
}

const _currencySymbols = <String, String>{
  'USD': '\$',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'NZD': 'NZ\$',
  'EUR': '\u20ac',
  'GBP': '\u00a3',
  'JPY': '\u00a5',
  'CNY': '\u00a5',
  'BRL': 'R\$',
  'MXN': 'MX\$',
  'INR': '\u20b9',
  'RUB': '\u20bd',
  'KRW': '\u20a9',
  'TRY': '\u20ba',
  'PLN': 'z\u0142',
  'CHF': 'CHF ',
  'NOK': 'kr ',
  'SEK': 'kr ',
  'DKK': 'kr ',
  'ZAR': 'R',
};

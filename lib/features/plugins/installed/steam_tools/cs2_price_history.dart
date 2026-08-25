import 'data/steam_database.dart';

/// The windows the CS2 price chart can be shown over.
///
/// Deliberately shorter than [SteamPriceRange]'s options: that chart's "5Y"
/// is meaningful because IsThereAnyDeal has actually been logging Steam
/// prices for years before the plugin ever asked. Nothing plays that role
/// here — Steam's Community Market publishes no history of its own, so
/// every point in this chart is a reading luma itself took. Offering "5Y"
/// on data that cannot be older than this device's own tracking would imply
/// a record that does not exist.
enum Cs2PriceRange {
  day('1D', Duration(days: 1)),
  week('1W', Duration(days: 7)),
  month('1M', Duration(days: 30)),
  all('All', null);

  const Cs2PriceRange(this.label, this.span);

  final String label;

  /// Null for [all] — there is no cutoff to compute.
  final Duration? span;

  DateTime? startFrom(DateTime now) =>
      span == null ? null : now.subtract(span!);
}

/// One Community Market reading, ready to plot.
class Cs2PriceSample {
  const Cs2PriceSample({required this.at, required this.priceCents});

  final DateTime at;

  /// The lowest listing at the time, falling back to the median when Steam
  /// reported no lowest (a thin market with only a couple of listings).
  final int priceCents;
}

/// What the chart needs to draw itself, and to say honestly how far back it
/// goes.
class Cs2PriceSeries {
  const Cs2PriceSeries({
    required this.samples,
    required this.range,
    required this.currency,
  });

  final List<Cs2PriceSample> samples;
  final Cs2PriceRange range;
  final String currency;

  bool get isEmpty => samples.isEmpty;

  /// True when there is exactly one reading — a line needs two points, and
  /// one is a "here is today's price" fact, not a trend.
  bool get isSingle => samples.length == 1;

  int? get lowestCents => samples.isEmpty
      ? null
      : samples.map((s) => s.priceCents).reduce((a, b) => a < b ? a : b);

  int? get highestCents => samples.isEmpty
      ? null
      : samples.map((s) => s.priceCents).reduce((a, b) => a > b ? a : b);

  bool get isFlat => lowestCents != null && lowestCents == highestCents;
}

/// Builds the series for [range] out of every reading luma has taken.
///
/// Unlike the game price chart, there is no carrying a value forward from
/// before the window: these are direct observations, not a log of changes,
/// so a gap in the window is simply a gap — the line starts at whatever the
/// first reading inside the window happened to be.
Cs2PriceSeries buildCs2PriceSeries(
  List<Cs2MarketPricePoint> points,
  Cs2PriceRange range,
  DateTime now, {
  String fallbackCurrency = 'USD',
}) {
  final currency = points.isEmpty ? fallbackCurrency : points.last.currency;
  final start = range.startFrom(now);

  final samples = <Cs2PriceSample>[
    for (final p in points)
      if (start == null || !p.observedAt.isBefore(start))
        if ((p.lowestCents ?? p.medianCents) case final cents?)
          Cs2PriceSample(at: p.observedAt, priceCents: cents),
  ];

  return Cs2PriceSeries(samples: samples, range: range, currency: currency);
}

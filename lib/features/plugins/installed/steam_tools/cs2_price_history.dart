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

/// Combines every tracked listing's readings into one "total value" series
/// — at each observation, the sum of every listing's most-recently-known
/// price. Reuses [Cs2PriceSeries]/[Cs2PriceSample] rather than a parallel
/// "portfolio" type, since a total is just another price over time as far as
/// the chart is concerned.
///
/// This is the one series in this file that *does* carry a value forward
/// across a gap, unlike [buildCs2PriceSeries] just above. That's deliberate,
/// not an oversight: a single listing's chart is a log of direct
/// observations, so a gap is honestly just a gap. A portfolio total is a
/// different kind of number — it only means something if every tracked
/// listing contributes at once, and listings are checked staggered (see
/// `Cs2MarketRepository._marketCallSpacing`), never in lockstep. Without
/// carrying forward, the total would appear to crash to a fraction of its
/// real value every time it was drawn between two listings' checks.
Cs2PriceSeries buildCs2PortfolioSeries(
  List<Cs2MarketPricePoint> allPoints,
  Cs2PriceRange range,
  DateTime now, {
  String fallbackCurrency = 'USD',
}) {
  final currency =
      allPoints.isEmpty ? fallbackCurrency : allPoints.last.currency;
  final start = range.startFrom(now);
  final lastKnown = <String, int>{};
  final samples = <Cs2PriceSample>[];

  int total() => lastKnown.values.fold<int>(0, (sum, cents) => sum + cents);

  final before = start == null
      ? const <Cs2MarketPricePoint>[]
      : allPoints.where((p) => p.observedAt.isBefore(start));
  for (final p in before) {
    if ((p.lowestCents ?? p.medianCents) case final cents?) {
      lastKnown[p.marketHashName] = cents;
    }
  }
  // Seed one sample right at the window start from whatever was already
  // known coming in, so a real portfolio with no reading that happens to
  // land inside a narrow window still draws something rather than looking
  // empty.
  if (start != null && lastKnown.isNotEmpty) {
    samples.add(Cs2PriceSample(at: start, priceCents: total()));
  }

  final within = start == null
      ? allPoints
      : allPoints.where((p) => !p.observedAt.isBefore(start));
  for (final p in within) {
    if ((p.lowestCents ?? p.medianCents) case final cents?) {
      lastKnown[p.marketHashName] = cents;
      samples.add(Cs2PriceSample(at: p.observedAt, priceCents: total()));
    }
  }

  return Cs2PriceSeries(samples: samples, range: range, currency: currency);
}

/// One reading recentred on a starting price — positive means it's worth
/// more now than the baseline, negative means less.
class Cs2GainLossSample {
  const Cs2GainLossSample({required this.at, required this.deltaCents});

  final DateTime at;
  final int deltaCents;
}

/// A [Cs2PriceSeries] re-expressed as change from [startingPriceCents], for
/// the "how much have I gained or lost" view rather than the raw-price one.
///
/// Built from an already-windowed [Cs2PriceSeries] rather than raw points, so
/// the range selector (1D/1W/1M/All) behaves identically in both views —
/// this only ever changes what the y-axis means, never which readings are in
/// scope.
class Cs2GainLossSeries {
  const Cs2GainLossSeries({
    required this.samples,
    required this.range,
    required this.currency,
    required this.startingPriceCents,
  });

  final List<Cs2GainLossSample> samples;
  final Cs2PriceRange range;
  final String currency;
  final int startingPriceCents;

  bool get isEmpty => samples.isEmpty;
  bool get isSingle => samples.length == 1;

  int? get currentDeltaCents => samples.isEmpty ? null : samples.last.deltaCents;

  /// Null when [startingPriceCents] is zero — a percentage change from
  /// nothing is undefined, not zero.
  double? get currentPercent {
    if (samples.isEmpty || startingPriceCents == 0) return null;
    return samples.last.deltaCents / startingPriceCents * 100;
  }

  int? get lowestDeltaCents => samples.isEmpty
      ? null
      : samples.map((s) => s.deltaCents).reduce((a, b) => a < b ? a : b);

  int? get highestDeltaCents => samples.isEmpty
      ? null
      : samples.map((s) => s.deltaCents).reduce((a, b) => a > b ? a : b);
}

Cs2GainLossSeries buildCs2GainLossSeries(
  Cs2PriceSeries priceSeries,
  int startingPriceCents,
) =>
    Cs2GainLossSeries(
      samples: [
        for (final sample in priceSeries.samples)
          Cs2GainLossSample(
            at: sample.at,
            deltaCents: sample.priceCents - startingPriceCents,
          ),
      ],
      range: priceSeries.range,
      currency: priceSeries.currency,
      startingPriceCents: startingPriceCents,
    );

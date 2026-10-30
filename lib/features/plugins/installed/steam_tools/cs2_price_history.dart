import '../../../../l10n/current_l.dart';
import 'data/steam_database.dart';

/// The windows the CS2 price chart can be shown over.
///
/// Shorter than [SteamPriceRange]'s options: a tracked listing's chart is
/// luma's own readings plus at most a year of Steam's sale history, which
/// `Cs2MarketRepository.backfillHistory` thins and keeps no further back
/// than that, so a "5Y" would imply a record that isn't held.
enum Cs2PriceRange {
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  all(null);

  const Cs2PriceRange(this.span);

  /// Null for [all] — there is no cutoff to compute.
  final Duration? span;

  String get label => switch (this) {
    Cs2PriceRange.day => '1D',
    Cs2PriceRange.week => '1W',
    Cs2PriceRange.month => '1M',
    Cs2PriceRange.all => currentL.commonAll,
  };

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

/// The most points a CS2 chart is handed. Beyond this a line of hourly
/// readings is mostly jitter at chart width; averaging neighbours into time
/// buckets keeps the trend and drops the noise.
const kCs2MaxChartSamples = 80;

/// Averages [samples] (oldest first) into at most [maxSamples] equal time
/// buckets. The first and last samples are kept exactly, so the line still
/// starts and ends on real values — the current price in particular.
List<Cs2PriceSample> smoothCs2Samples(
  List<Cs2PriceSample> samples, {
  int maxSamples = kCs2MaxChartSamples,
}) {
  if (samples.length <= maxSamples || maxSamples < 3) return samples;
  final first = samples.first;
  final last = samples.last;
  final startMs = first.at.millisecondsSinceEpoch;
  final spanMs = last.at.millisecondsSinceEpoch - startMs;
  if (spanMs <= 0) return [first, last];
  final buckets = maxSamples - 2;
  final sums = List<int>.filled(buckets, 0);
  final times = List<int>.filled(buckets, 0);
  final counts = List<int>.filled(buckets, 0);
  for (var i = 1; i < samples.length - 1; i++) {
    final ms = samples[i].at.millisecondsSinceEpoch;
    final index = ((ms - startMs) * buckets ~/ spanMs).clamp(0, buckets - 1);
    sums[index] += samples[i].priceCents;
    times[index] += ms - startMs;
    counts[index]++;
  }
  return [
    first,
    for (var i = 0; i < buckets; i++)
      if (counts[i] > 0)
        Cs2PriceSample(
          at: DateTime.fromMillisecondsSinceEpoch(
            startMs + times[i] ~/ counts[i],
          ),
          priceCents: (sums[i] / counts[i]).round(),
        ),
    last,
  ];
}

/// Builds the series for [range] out of every reading held for a listing.
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

  return Cs2PriceSeries(
    samples: smoothCs2Samples(samples),
    range: range,
    currency: currency,
  );
}

/// Combines every tracked copy's readings into one "total value" series:
/// what everything held *now* was worth at each moment in the window.
/// Reuses [Cs2PriceSeries]/[Cs2PriceSample] rather than a parallel
/// "portfolio" type, since a total is just another price over time as far as
/// the chart is concerned.
///
/// This is the one series in this file that *does* carry a value forward
/// across a gap, unlike [buildCs2PriceSeries] just above. A single
/// listing's chart is a log of direct observations, so a gap is honestly
/// just a gap. A portfolio total only means something if every copy
/// contributes at once, and listings are priced at different moments —
/// without carrying each one's last-known price forward, the total would
/// appear to crash every time it was drawn between two listings' readings.
///
/// Every copy in [entries] counts across the whole window, regardless of
/// when it was tracked: an inventory linked today is worth charting from
/// before today, and Steam's backfilled history is what makes that
/// possible. For the same reason a listing whose first reading falls inside
/// the window counts at that first price before it, rather than as $0 —
/// otherwise every newly linked item would draw a cliff from nothing.
///
/// Readings that share a timestamp (one bulk price update covers every
/// listing at once) become one sample, and the line always ends at [now]
/// with the current total.
Cs2PriceSeries buildCs2PortfolioSeries(
  List<Cs2MarketPricePoint> allPoints,
  List<Cs2MarketEntry> entries,
  Cs2PriceRange range,
  DateTime now, {
  String fallbackCurrency = 'USD',
}) {
  final currency =
      allPoints.isEmpty ? fallbackCurrency : allPoints.last.currency;
  final start = range.startFrom(now);

  final units = <String, int>{};
  for (final entry in entries) {
    units[entry.marketHashName] = (units[entry.marketHashName] ?? 0) + 1;
  }

  final price = <String, int>{};
  for (final p in allPoints) {
    if (!units.containsKey(p.marketHashName)) continue;
    if ((p.lowestCents ?? p.medianCents) case final cents?) {
      price.putIfAbsent(p.marketHashName, () => cents);
    }
  }
  if (price.isEmpty) {
    return Cs2PriceSeries(samples: const [], range: range, currency: currency);
  }

  var total = price.entries.fold<int>(
    0,
    (sum, e) => sum + e.value * units[e.key]!,
  );
  void apply(Cs2MarketPricePoint p) {
    final count = units[p.marketHashName];
    if (count == null) return;
    if ((p.lowestCents ?? p.medianCents) case final cents?) {
      total += (cents - price[p.marketHashName]!) * count;
      price[p.marketHashName] = cents;
    }
  }

  final samples = <Cs2PriceSample>[];
  void add(DateTime at) {
    if (samples.isNotEmpty && samples.last.at == at) {
      samples[samples.length - 1] = Cs2PriceSample(at: at, priceCents: total);
    } else {
      samples.add(Cs2PriceSample(at: at, priceCents: total));
    }
  }

  var seeded = false;
  for (final p in allPoints) {
    if (start != null && p.observedAt.isBefore(start)) {
      apply(p);
      seeded = true;
      continue;
    }
    // Seed one sample right at the window start from whatever was already
    // known coming in, so a narrow window with no reading of its own still
    // draws the carried-forward total rather than looking empty.
    if (seeded && samples.isEmpty) add(start!);
    apply(p);
    add(p.observedAt);
  }
  if (seeded && samples.isEmpty) add(start!);
  if (samples.isNotEmpty && samples.last.at.isBefore(now)) add(now);

  return Cs2PriceSeries(
    samples: smoothCs2Samples(samples),
    range: range,
    currency: currency,
  );
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

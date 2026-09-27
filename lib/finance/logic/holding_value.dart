import '../data/database.dart';

/// Quote currencies that are a hundredth of a major currency: London quotes
/// in pence (GBp), Johannesburg in cents (ZAc), Tel Aviv in agorot (ILA).
const _minorUnits = {'GBp': 'GBP', 'GBX': 'GBP', 'ZAc': 'ZAR', 'ILA': 'ILS'};

/// The major currency and divisor for a quote currency, e.g.
/// "GBp" -> ("GBP", 100) and "usd" -> ("USD", 1).
(String, int) majorCurrency(String currency) {
  final major = _minorUnits[currency];
  if (major != null) return (major, 100);
  return (currency.toUpperCase(), 1);
}

/// Euro values of a holding. Prices and average cost are kept in the quote's
/// own currency; [Holding.eurPerUnit] converts them. A holding with no known
/// currency is taken to be priced in euros already.
extension HoldingEuroValue on Holding {
  /// True when the holding is in a foreign currency with no rate yet, so
  /// its euro value is really the unconverted native amount.
  bool get missingFxRate => !isEuro && eurPerUnit == null;

  bool get isEuro => currency == null || currency!.toUpperCase() == 'EUR';

  double get _rate => isEuro ? 1.0 : (eurPerUnit ?? 1.0);

  int get valueEurCents =>
      ((lastPriceCents ?? avgCostCents) * shares * _rate).round();

  int get costEurCents => (avgCostCents * shares * _rate).round();
}

/// Sum of [holdings]' euro market values.
int portfolioEurCents(Iterable<Holding> holdings) =>
    holdings.fold(0, (sum, h) => sum + h.valueEurCents);

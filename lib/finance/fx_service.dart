import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'logic/holding_value.dart';

/// Keyless exchange rates from the European Central Bank's daily reference
/// feed, which quotes every currency per one euro.
class FxService {
  const FxService._();

  static const _feed =
      'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml';

  static Map<String, double>? _perEuro;
  static DateTime? _fetchedAt;

  /// Euros per one unit of [currency] (a quote currency such as "USD" or
  /// "GBp"), or null when the rate can't be fetched. EUR is always 1.
  static Future<double?> eurPerUnit(String currency) async {
    final (major, divisor) = majorCurrency(currency);
    if (major == 'EUR') return 1.0 / divisor;
    final rates = await _rates();
    final perEuro = rates?[major];
    if (perEuro == null || perEuro <= 0) return null;
    return 1.0 / perEuro / divisor;
  }

  static Future<Map<String, double>?> _rates() async {
    final at = _fetchedAt;
    // The ECB publishes once a working day; a few hours of caching is plenty.
    if (_perEuro != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(hours: 6)) {
      return _perEuro;
    }
    try {
      final res = await http
          .get(Uri.parse(_feed))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _perEuro;
      final parsed = parseEcbRates(res.body);
      if (parsed.isEmpty) return _perEuro;
      _perEuro = parsed;
      _fetchedAt = DateTime.now();
    } catch (_) {
      // Keep whatever was cached; callers treat null as "no rate".
    }
    return _perEuro;
  }
}

/// Reads `<Cube currency="USD" rate="1.0823"/>` entries out of the ECB feed.
Map<String, double> parseEcbRates(String body) {
  final rates = <String, double>{};
  try {
    final doc = XmlDocument.parse(body);
    for (final cube in doc.descendants.whereType<XmlElement>()) {
      if (cube.name.local != 'Cube') continue;
      final currency = cube.getAttribute('currency');
      final rate = double.tryParse(cube.getAttribute('rate') ?? '');
      if (currency != null && rate != null) rates[currency] = rate;
    }
  } on XmlException {
    return const {};
  }
  return rates;
}

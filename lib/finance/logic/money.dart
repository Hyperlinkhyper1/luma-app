import 'package:intl/intl.dart';

final NumberFormat _euro =
    NumberFormat.currency(locale: 'nl_NL', symbol: '€', decimalDigits: 2);

/// Formats integer [cents] as a euro string, e.g. 123456 -> "€1.234,56".
String formatCents(int cents) => _euro.format(cents / 100.0);

/// Like [formatCents] but with an explicit + / - sign.
String formatSignedCents(int cents) {
  final formatted = formatCents(cents.abs());
  if (cents > 0) return '+$formatted';
  if (cents < 0) return '-$formatted';
  return formatted;
}

/// Parses free-form user input into cents, tolerating both Dutch ("1.234,56")
/// and plain ("1234.56") number styles. Returns null if it isn't a number.
int? parseToCents(String input) {
  var s = input.trim().replaceAll('€', '').replaceAll(' ', '');
  if (s.isEmpty) return null;

  final hasComma = s.contains(',');
  final hasDot = s.contains('.');
  if (hasComma && hasDot) {
    // Last separator is the decimal one; the other groups thousands.
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (hasComma) {
    s = s.replaceAll(',', '.');
  }

  final value = double.tryParse(s);
  if (value == null) return null;
  return (value * 100).round();
}

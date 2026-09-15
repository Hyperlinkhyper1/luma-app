/// Money formatting for the airline.
///
/// `lib/finance/logic/money.dart` is deliberately not reused here: it is
/// hard-locked to nl_NL grouping and always prints cents, which at tycoon
/// scale turns every figure into an unreadable wall of digits. An airline
/// deals in millions, so it wants an abbreviator.
library;

/// Compact euros for headline figures: 1,240,000 reads as "EUR 1.24M".
String fmtMoney(int euros) {
  final sign = euros < 0 ? '-' : '';
  final n = euros.abs();
  if (n >= 1000000000) return '$sign€${(n / 1000000000).toStringAsFixed(2)}B';
  if (n >= 10000000) return '$sign€${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000000) return '$sign€${(n / 1000000).toStringAsFixed(2)}M';
  if (n >= 10000) return '$sign€${(n / 1000).toStringAsFixed(0)}K';
  if (n >= 1000) return '$sign€${(n / 1000).toStringAsFixed(1)}K';
  return '$sign€$n';
}

/// Like [fmtMoney] but always carrying an explicit sign, for deltas in the
/// books where "did this line make or lose money" is the whole point.
String fmtSignedMoney(int euros) =>
    euros >= 0 ? '+${fmtMoney(euros)}' : fmtMoney(euros);

/// Grouped exact euros, for prices the player is about to commit to.
String fmtExactMoney(int euros) {
  final sign = euros < 0 ? '-' : '';
  final digits = euros.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$sign€$buffer';
}

/// Thousands separator for plain counts (passengers, flights).
String fmtCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// "3,400 m" style distances.
String fmtKm(double km) =>
    km >= 1000 ? '${fmtCount(km.round())} km' : '${km.round()} km';

/// A duration as a person would say it: "2h 40m", "14h", "3d 6h".
String fmtDuration(Duration d) {
  if (d.inDays >= 1) {
    final hours = d.inHours % 24;
    return hours == 0 ? '${d.inDays}d' : '${d.inDays}d ${hours}h';
  }
  if (d.inHours >= 1) {
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? '${d.inHours}h' : '${d.inHours}h ${minutes}m';
  }
  return '${d.inMinutes}m';
}

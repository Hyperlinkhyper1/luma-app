/// Number and date formatting shared by the leaderboard's table, graphs and
/// model pages, so the same value never appears two ways on one screen.
library;

/// A context window as people talk about it: `1048576` → `1.0M`, `128000` →
/// `128K`. Null for an unknown window, which the table shows as "–".
String? formatTokens(int? tokens) {
  if (tokens == null || tokens <= 0) return null;
  if (tokens >= 1000000) {
    final millions = tokens / 1000000;
    // 1M and 2M are exact enough to read without a decimal; 1.05M is not.
    return millions >= 10
        ? '${millions.round()}M'
        : '${millions.toStringAsFixed(millions == millions.roundToDouble() ? 0 : 1)}M';
  }
  if (tokens >= 1000) return '${(tokens / 1000).round()}K';
  return '$tokens';
}

/// USD per million tokens. Sub-dollar prices keep enough decimals to stay
/// distinguishable — at two decimals a third of the board reads `$0.00`.
String? formatPrice(double? usdPerMillion) {
  if (usdPerMillion == null) return null;
  if (usdPerMillion == 0) return r'$0';
  if (usdPerMillion < 0.1) return '\$${usdPerMillion.toStringAsFixed(3)}';
  // Cents matter well past $10 — the gap between $7.22 and $7.78 is the whole
  // argument for one model over another.
  if (usdPerMillion < 100) return '\$${usdPerMillion.toStringAsFixed(2)}';
  return '\$${usdPerMillion.toStringAsFixed(0)}';
}

/// A token count in full, for detail pages: `1048576` → `1,048,576`.
String formatExactTokens(int tokens) {
  final digits = tokens.abs().toString();
  final buffer = StringBuffer(tokens < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// How long ago something happened, at the granularity that reads naturally
/// for catalogue freshness — hours, then days, then a date.
String relativeDay(DateTime when) {
  final delta = DateTime.now().difference(when);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 30) return '${delta.inDays}d ago';
  return '${when.year}-${_two(when.month)}-${_two(when.day)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

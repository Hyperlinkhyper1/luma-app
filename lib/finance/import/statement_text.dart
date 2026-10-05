import 'dart:convert';

/// Text handling shared by bank exports. A file has one delimiter; decimal
/// commas must never be treated as extra columns in a semicolon export.
class StatementText {
  StatementText._();

  static String decode(List<int> bytes) {
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
            (bytes[0] == 0xfe && bytes[1] == 0xff))) {
      if (bytes.length.isOdd) {
        throw const FormatException('Incomplete UTF-16 statement.');
      }
      final littleEndian = bytes[0] == 0xff;
      return String.fromCharCodes([
        for (var i = 2; i < bytes.length; i += 2)
          littleEndian
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1],
      ]);
    }
    try {
      return utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), '');
    } on FormatException {
      // Older Dutch exports use Windows-1252, which differs from Latin-1
      // in the 0x80–0x9f range.
      const replacements = [
        0x20ac,
        0x81,
        0x201a,
        0x192,
        0x201e,
        0x2026,
        0x2020,
        0x2021,
        0x2c6,
        0x2030,
        0x160,
        0x2039,
        0x152,
        0x8d,
        0x17d,
        0x8f,
        0x90,
        0x2018,
        0x2019,
        0x201c,
        0x201d,
        0x2022,
        0x2013,
        0x2014,
        0x2dc,
        0x2122,
        0x161,
        0x203a,
        0x153,
        0x9d,
        0x17e,
        0x178,
      ];
      return String.fromCharCodes(
        bytes.map((b) => b >= 0x80 && b <= 0x9f ? replacements[b - 0x80] : b),
      );
    }
  }

  static List<List<String>> rows(String text, {String? delimiter}) {
    text = text.replaceFirst(RegExp(r'^\uFEFF'), '');
    if (text.startsWith('sep=') && text.length > 4) {
      delimiter ??= text[4];
      final end = text.indexOf('\n');
      text = end < 0 ? '' : text.substring(end + 1);
    }
    delimiter ??= _delimiter(text);
    final result = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    var closedQuote = false;

    void endField() {
      row.add(field.toString());
      field.clear();
      closedQuote = false;
    }

    void endRow() {
      endField();
      result.add(row);
      row = [];
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closedQuote = true;
          }
        } else {
          field.write(c);
        }
      } else if (c == delimiter) {
        endField();
      } else if (c == '\r' || c == '\n') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else if (c == '"' && field.isEmpty && !closedQuote) {
        quoted = true;
      } else if (closedQuote) {
        if (c.trim().isNotEmpty) {
          throw const FormatException('Unexpected text after a quoted field.');
        }
      } else {
        field.write(c);
      }
    }
    if (quoted) throw const FormatException('Unclosed quote in statement.');
    if (field.isNotEmpty || row.isNotEmpty || closedQuote) endRow();
    return result;
  }

  static String _delimiter(String text) {
    final counts = {',': 0, ';': 0, '\t': 0};
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted) {
        if (counts.containsKey(c)) counts[c] = counts[c]! + 1;
        // Decide from the first row with separators (normally the header),
        // before punctuation in transaction descriptions can skew the count.
        if (c == '\n' && counts.values.any((n) => n > 0)) break;
      }
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static DateTime? date(String raw) {
    final value = raw.trim();
    final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[ T]\d{2}:\d{2}(?::\d{2})?)?$',
    ).firstMatch(value);
    final dutch = RegExp(
      r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$',
    ).firstMatch(value);
    final match = compact ?? iso ?? dutch;
    if (match == null) return null;
    final year = int.parse(match.group(dutch == match ? 3 : 1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(dutch == match ? 1 : 3)!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  /// Exact integer cents, including bunq's older trailing minus notation.
  static int? cents(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[€\s\u00a0]'), '');
    if (value.endsWith('-')) value = '-${value.substring(0, value.length - 1)}';
    if (value.contains(',') && value.contains('.')) {
      if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
        if (!RegExp(r'^[+-]?\d{1,3}(?:\.\d{3})+,\d{1,2}$').hasMatch(value)) {
          return null;
        }
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        if (!RegExp(r'^[+-]?\d{1,3}(?:,\d{3})+\.\d{1,2}$').hasMatch(value)) {
          return null;
        }
        value = value.replaceAll(',', '');
      }
    } else {
      value = value.replaceAll(',', '.');
    }
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
    if (match == null) return null;
    final whole = int.tryParse(match.group(2)!);
    if (whole == null || whole > 90071992547409) return null;
    final fraction = int.parse((match.group(3) ?? '').padRight(2, '0'));
    final amount = whole * 100 + fraction;
    if (amount > 9007199254740991) return null;
    return match.group(1) == '-' ? -amount : amount;
  }
}

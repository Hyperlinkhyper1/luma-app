/// One line of a hardware requirements block: usually a labelled pair
/// ("Memory" / "12 GB RAM"), sometimes a bare note with no label.
class SteamRequirementLine {
  const SteamRequirementLine({this.label, required this.value});

  final String? label;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is SteamRequirementLine &&
      other.label == label &&
      other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => label == null ? value : '$label: $value';
}

/// The minimum and recommended PC specs for a game.
///
/// Steam serves these as a blob of store HTML rather than structured data —
/// `<strong>OS:</strong> 64-bit Windows 10<br>` inside an unordered list —
/// so it is parsed here into label/value pairs. Rendering the raw HTML would
/// mean shipping an HTML renderer for six lines of text, and stripping the
/// tags without parsing them would collapse the whole block into one
/// unreadable paragraph.
class SteamRequirements {
  const SteamRequirements({
    this.minimum = const [],
    this.recommended = const [],
  });

  final List<SteamRequirementLine> minimum;
  final List<SteamRequirementLine> recommended;

  bool get isEmpty => minimum.isEmpty && recommended.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Reads the `pc_requirements` field. Steam sends an object with
  /// `minimum`/`recommended` keys for most apps, but an empty **list** for
  /// apps that never filled them in, so the type is checked rather than
  /// assumed.
  static SteamRequirements fromJson(Object? raw) {
    if (raw is! Map) return const SteamRequirements();
    return SteamRequirements(
      minimum: parseSteamRequirementBlock(raw['minimum'] as String?),
      recommended: parseSteamRequirementBlock(raw['recommended'] as String?),
    );
  }
}

final _liPattern = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true);
final _brPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
final _leadingStrong =
    RegExp(r'^\s*<strong>(.*?)</strong>\s*', caseSensitive: false, dotAll: true);
final _tagPattern = RegExp(r'<[^>]*>');
final _whitespace = RegExp(r'\s+');

/// Turns one requirements HTML blob into readable label/value lines.
///
/// The leading `<strong>Minimum:</strong>` heading is dropped — the caller
/// already knows which block this is, and repeating it inside the list would
/// read as a spec named "Minimum".
List<SteamRequirementLine> parseSteamRequirementBlock(String? html) {
  if (html == null || html.trim().isEmpty) return const [];

  final items = _liPattern
      .allMatches(html)
      .map((m) => m.group(1) ?? '')
      .toList(growable: false);

  // A few apps write the block as plain text with <br> separators and no
  // list at all. Splitting on the line breaks recovers the same shape.
  final rawLines = items.isNotEmpty
      ? items
      : html.replaceAll(_brPattern, '\n').split('\n');

  final lines = <SteamRequirementLine>[];
  for (final raw in rawLines) {
    final line = _lineFrom(raw);
    if (line != null) lines.add(line);
  }
  return lines;
}

SteamRequirementLine? _lineFrom(String raw) {
  var body = raw.replaceAll(_brPattern, ' ');

  String? label;
  final strong = _leadingStrong.firstMatch(body);
  if (strong != null) {
    final candidate = _clean(strong.group(1) ?? '');
    final trimmed = candidate.endsWith(':')
        ? candidate.substring(0, candidate.length - 1).trim()
        : candidate;
    // "Minimum:" / "Recommended:" is the block's own heading, not a spec.
    final heading = trimmed.toLowerCase();
    if (heading == 'minimum' || heading == 'recommended') {
      body = body.substring(strong.end);
      final rest = _clean(body);
      return rest.isEmpty ? null : SteamRequirementLine(value: rest);
    }
    if (trimmed.isNotEmpty) {
      label = trimmed;
      body = body.substring(strong.end);
    }
  }

  final value = _clean(body);
  if (value.isEmpty) return null;
  return SteamRequirementLine(label: label, value: value);
}

String _clean(String input) => _unescape(input.replaceAll(_tagPattern, ' '))
    .replaceAll(_whitespace, ' ')
    .trim();

String _unescape(String input) {
  if (!input.contains('&')) return input;
  var out = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  out = out.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    },
  );
  // Ampersand last, so an escaped "&amp;lt;" does not become a real tag.
  return out.replaceAll('&amp;', '&');
}

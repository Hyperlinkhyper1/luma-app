import 'dart:math' as math;

/// The three Office formats the Assistant can build and edit piece by piece.
enum OfficeKind { docx, pptx, xlsx }

OfficeKind? officeKindOf(String nameOrType) {
  final lower = nameOrType.toLowerCase();
  for (final kind in OfficeKind.values) {
    if (lower == kind.name || lower.endsWith('.${kind.name}')) return kind;
  }
  return null;
}

const officeMimeTypes = <OfficeKind, String>{
  OfficeKind.docx:
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  OfficeKind.pptx:
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  OfficeKind.xlsx:
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

enum DocBlockType {
  heading,
  paragraph,
  bullet,
  numbered,
  quote,
  table,
  pageBreak,
}

/// One block of a Word document. [text] keeps inline `**bold**` and
/// `*italic*` markers; the exporter and the preview both turn them into runs.
class DocBlock {
  const DocBlock(
    this.type, {
    this.text = '',
    this.level = 0,
    this.rows = const [],
  });
  final DocBlockType type;
  final String text;

  /// Heading level (1–3) for headings, nesting depth (0–2) for list items.
  final int level;
  final List<List<String>> rows;

  Map<String, dynamic> toJson() => {
    't': type.name,
    if (text.isNotEmpty) 'x': text,
    if (level != 0) 'l': level,
    if (rows.isNotEmpty) 'r': rows,
  };

  factory DocBlock.fromJson(Map<String, dynamic> json) => DocBlock(
    DocBlockType.values.asNameMap()[json['t']] ?? DocBlockType.paragraph,
    text: json['x'] as String? ?? '',
    level: (json['l'] as num?)?.toInt() ?? 0,
    rows: [
      for (final row in json['r'] as List? ?? const [])
        [for (final cell in row as List) cell.toString()],
    ],
  );

  String toMarkdown() => switch (type) {
    DocBlockType.heading => '${'#' * level.clamp(1, 3)} $text',
    DocBlockType.paragraph => text,
    DocBlockType.bullet => '${'  ' * level}- $text',
    DocBlockType.numbered => '${'  ' * level}1. $text',
    DocBlockType.quote => '> $text',
    DocBlockType.pageBreak => '---',
    DocBlockType.table => [
      for (final (i, row) in rows.indexed) ...[
        '| ${row.join(' | ')} |',
        if (i == 0) '|${List.filled(row.length, ' --- ').join('|')}|',
      ],
    ].join('\n'),
  };
}

class SlideBullet {
  const SlideBullet(this.text, [this.level = 0]);
  final String text;
  final int level;
}

class OfficeSlide {
  const OfficeSlide({
    this.title = '',
    this.subtitle = '',
    this.bullets = const [],
  });
  final String title;
  final String subtitle;
  final List<SlideBullet> bullets;

  Map<String, dynamic> toJson() => {
    'title': title,
    if (subtitle.isNotEmpty) 'subtitle': subtitle,
    'bullets': [
      for (final b in bullets) [b.level, b.text],
    ],
  };

  factory OfficeSlide.fromJson(Map<String, dynamic> json) => OfficeSlide(
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    bullets: [
      for (final b in json['bullets'] as List? ?? const [])
        SlideBullet((b as List)[1].toString(), (b[0] as num).toInt()),
    ],
  );

  String toMarkdown() => [
    if (title.isNotEmpty) '# $title',
    if (subtitle.isNotEmpty) '## $subtitle',
    for (final b in bullets) '${'  ' * b.level}- ${b.text}',
  ].join('\n');
}

class OfficeSheet {
  OfficeSheet(this.name, [List<List<String>>? rows]) : rows = rows ?? [];
  final String name;

  /// Ragged grid, row-major. Values starting with `=` are formulas.
  final List<List<String>> rows;

  int get columnCount => rows.fold(0, (m, r) => math.max(m, r.length));

  String cell(int row, int col) =>
      row < rows.length && col < rows[row].length ? rows[row][col] : '';

  void setCell(int row, int col, String value) {
    while (rows.length <= row) {
      rows.add([]);
    }
    final target = rows[row];
    while (target.length <= col) {
      target.add('');
    }
    target[col] = value;
  }

  Map<String, dynamic> toJson() => {'name': name, 'rows': rows};

  factory OfficeSheet.fromJson(Map<String, dynamic> json) =>
      OfficeSheet(json['name'] as String? ?? 'Sheet1', [
        for (final row in json['rows'] as List? ?? const [])
          [for (final cell in row as List) cell.toString()],
      ]);
}

/// Which part of the document the model touched last, and how. The preview
/// highlights it and scrolls it into view.
enum OfficeActivity { reading, writing, deleting }

class OfficeFocus {
  const OfficeFocus({
    required this.activity,
    required this.start,
    this.end,
    this.cellStart,
    this.cellEnd,
  });
  final OfficeActivity activity;

  /// Block index (Word), slide index (PowerPoint) or sheet index (Excel).
  final int start;

  /// Last index touched, inclusive; null when only [start] was touched.
  final int? end;

  /// Excel only: the touched cell range, as (row, column) pairs.
  final (int, int)? cellStart;
  final (int, int)? cellEnd;

  int get last => end ?? start;
  bool covers(int index) => index >= start && index <= last;

  bool coversCell(int row, int col) {
    final from = cellStart;
    if (from == null) return false;
    final to = cellEnd ?? from;
    return row >= math.min(from.$1, to.$1) &&
        row <= math.max(from.$1, to.$1) &&
        col >= math.min(from.$2, to.$2) &&
        col <= math.max(from.$2, to.$2);
  }
}

/// The editable content behind one generated Office file. It is kept as a
/// JSON sidecar next to the file so a later turn can read and change it.
class OfficeDocument {
  OfficeDocument(
    this.kind, {
    this.title = '',
    List<DocBlock>? blocks,
    List<OfficeSlide>? slides,
    List<OfficeSheet>? sheets,
  }) : blocks = blocks ?? [],
       slides = slides ?? [],
       sheets = sheets ?? [];

  final OfficeKind kind;
  String title;
  final List<DocBlock> blocks;
  final List<OfficeSlide> slides;
  final List<OfficeSheet> sheets;

  int get partCount => switch (kind) {
    OfficeKind.docx => blocks.length,
    OfficeKind.pptx => slides.length,
    OfficeKind.xlsx => sheets.length,
  };

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    if (kind == OfficeKind.docx) 'blocks': [for (final b in blocks) b.toJson()],
    if (kind == OfficeKind.pptx) 'slides': [for (final s in slides) s.toJson()],
    if (kind == OfficeKind.xlsx) 'sheets': [for (final s in sheets) s.toJson()],
  };

  factory OfficeDocument.fromJson(Map<String, dynamic> json) => OfficeDocument(
    OfficeKind.values.byName(json['kind'] as String),
    title: json['title'] as String? ?? '',
    blocks: [
      for (final b in json['blocks'] as List? ?? const [])
        DocBlock.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
    slides: [
      for (final s in json['slides'] as List? ?? const [])
        OfficeSlide.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    sheets: [
      for (final s in json['sheets'] as List? ?? const [])
        OfficeSheet.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );

  /// A short numbered listing the model reads to find what to change.
  List<Map<String, dynamic>> outline() => switch (kind) {
    OfficeKind.docx => [
      for (final (i, b) in blocks.indexed)
        {'index': i, 'type': b.type.name, 'preview': _clip(b.toMarkdown())},
    ],
    OfficeKind.pptx => [
      for (final (i, s) in slides.indexed)
        {'index': i, 'title': s.title, 'bullets': s.bullets.length},
    ],
    OfficeKind.xlsx => [
      for (final (i, s) in sheets.indexed)
        {
          'index': i,
          'sheet': s.name,
          'used_range': s.rows.isEmpty
              ? null
              : 'A1:${cellName(s.rows.length - 1, math.max(0, s.columnCount - 1))}',
        },
    ],
  };

  /// Inserts, replaces or deletes Word blocks or slides from Markdown and
  /// returns the indices that changed.
  OfficeFocus edit({required String action, int? index, String content = ''}) {
    if (kind == OfficeKind.xlsx) {
      throw const FormatException(
        'Spreadsheets are edited with sheet, cell and rows.',
      );
    }
    final parts = kind == OfficeKind.docx
        ? parseDocMarkdown(content)
        : parseSlideMarkdown(content);
    final list = kind == OfficeKind.docx ? blocks : slides;
    final count = list.length;
    int checked(int? value, {required bool allowEnd}) {
      final max = allowEnd ? count : count - 1;
      if (value == null || value < 0 || value > max) {
        throw FormatException(
          count == 0 && !allowEnd
              ? 'The document is still empty; use append.'
              : 'Index must be between 0 and $max.',
        );
      }
      return value;
    }

    void put(int at, int removing) {
      if (parts.isEmpty) {
        throw const FormatException('The content is empty.');
      }
      if (kind == OfficeKind.docx) {
        blocks.replaceRange(at, at + removing, parts.cast<DocBlock>());
      } else {
        slides.replaceRange(at, at + removing, parts.cast<OfficeSlide>());
      }
    }

    switch (action) {
      case 'append':
        put(count, 0);
        return _written(count, parts.length);
      case 'insert':
        final at = checked(index, allowEnd: true);
        put(at, 0);
        return _written(at, parts.length);
      case 'replace':
        final at = checked(index, allowEnd: false);
        put(at, 1);
        return _written(at, parts.length);
      case 'delete':
        final at = checked(index, allowEnd: false);
        list.removeAt(at);
        return OfficeFocus(
          activity: OfficeActivity.deleting,
          start: math.min(at, math.max(0, list.length - 1)),
        );
      default:
        throw FormatException('Unknown action "$action".');
    }
  }

  static OfficeFocus _written(int at, int length) => OfficeFocus(
    activity: OfficeActivity.writing,
    start: at,
    end: length > 1 ? at + length - 1 : null,
  );

  /// Writes [values] into [sheetName] starting at [cell] (A1 notation),
  /// creating the sheet when it does not exist yet.
  OfficeFocus writeCells({
    required String sheetName,
    required String cell,
    required List<List<String>> values,
  }) {
    final name = safeSheetName(sheetName);
    var sheetIndex = sheets.indexWhere(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    );
    if (sheetIndex < 0) {
      sheets.add(OfficeSheet(name));
      sheetIndex = sheets.length - 1;
    }
    final origin = parseCellName(cell);
    if (origin == null) throw FormatException('"$cell" is not a cell like B2.');
    if (values.isEmpty || values.every((r) => r.isEmpty)) {
      throw const FormatException('rows must contain at least one value.');
    }
    if (origin.$1 + values.length > 5000) {
      throw const FormatException('Sheets are limited to 5,000 rows.');
    }
    final sheet = sheets[sheetIndex];
    var widest = 0;
    for (final (r, row) in values.indexed) {
      widest = math.max(widest, row.length);
      for (final (c, value) in row.indexed) {
        if (origin.$2 + c >= 200) {
          throw const FormatException('Sheets are limited to 200 columns.');
        }
        sheet.setCell(origin.$1 + r, origin.$2 + c, value);
      }
    }
    return OfficeFocus(
      activity: OfficeActivity.writing,
      start: sheetIndex,
      cellStart: origin,
      cellEnd: (
        origin.$1 + values.length - 1,
        origin.$2 + math.max(0, widest - 1),
      ),
    );
  }

  OfficeFocus deleteSheet(String sheetName) {
    final index = sheets.indexWhere(
      (s) => s.name.toLowerCase() == sheetName.trim().toLowerCase(),
    );
    if (index < 0) throw FormatException('There is no sheet "$sheetName".');
    sheets.removeAt(index);
    return OfficeFocus(
      activity: OfficeActivity.deleting,
      start: math.min(index, math.max(0, sheets.length - 1)),
    );
  }

  /// One part in full, in the same Markdown the edit tool accepts.
  String readPart(int index) => switch (kind) {
    OfficeKind.docx => blocks[index].toMarkdown(),
    OfficeKind.pptx => slides[index].toMarkdown(),
    OfficeKind.xlsx => [
      for (final (r, row) in sheets[index].rows.take(200).indexed)
        '${r + 1}: ${row.join(' | ')}',
    ].join('\n'),
  };

  static String _clip(String value) {
    final line = value.replaceAll('\n', ' ');
    return line.length <= 90 ? line : '${line.substring(0, 87)}...';
  }
}

String safeSheetName(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  final name = cleaned.isEmpty ? 'Sheet1' : cleaned;
  return name.length > 31 ? name.substring(0, 31) : name;
}

String columnName(int col) {
  var n = col + 1;
  var name = '';
  while (n > 0) {
    final rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = (n - 1) ~/ 26;
  }
  return name;
}

String cellName(int row, int col) => '${columnName(col)}${row + 1}';

/// `B3` → (2, 1). Returns null for anything that is not a single cell.
(int, int)? parseCellName(String raw) {
  final match = RegExp(
    r'^\$?([A-Za-z]{1,3})\$?(\d{1,6})$',
  ).firstMatch(raw.trim());
  if (match == null) return null;
  var col = 0;
  for (final unit in match.group(1)!.toUpperCase().codeUnits) {
    col = col * 26 + (unit - 64);
  }
  final row = int.parse(match.group(2)!);
  if (row < 1) return null;
  return (row - 1, col - 1);
}

final _tableSeparator = RegExp(r'^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$');
final _numberedItem = RegExp(r'^(\d+)[.)]\s+(.*)$');

List<String> _tableCells(String line) {
  var body = line.trim();
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);
  return [for (final cell in body.split('|')) cell.trim()];
}

/// Parses Markdown into Word blocks: `#` headings, `-`/`1.` lists (indent
/// two spaces per level), `>` quotes, pipe tables, `---` page breaks and
/// paragraphs separated by blank lines.
List<DocBlock> parseDocMarkdown(String source) {
  final blocks = <DocBlock>[];
  final paragraph = <String>[];
  List<List<String>>? table;

  void flush() {
    if (paragraph.isNotEmpty) {
      blocks.add(DocBlock(DocBlockType.paragraph, text: paragraph.join(' ')));
      paragraph.clear();
    }
    if (table != null) {
      if (table!.isNotEmpty) {
        blocks.add(DocBlock(DocBlockType.table, rows: table!));
      }
      table = null;
    }
  }

  for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
    final indent = rawLine.length - rawLine.trimLeft().length;
    final line = rawLine.trim();
    final depth = (indent ~/ 2).clamp(0, 2);
    if (line.startsWith('|')) {
      if (paragraph.isNotEmpty) flush();
      if (_tableSeparator.hasMatch(line)) continue;
      (table ??= []).add(_tableCells(line));
      continue;
    }
    if (table != null) flush();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add(
        DocBlock(
          DocBlockType.heading,
          text: heading.group(2)!.trim(),
          level: heading.group(1)!.length.clamp(1, 3),
        ),
      );
    } else if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line)) {
      flush();
      blocks.add(const DocBlock(DocBlockType.pageBreak));
    } else if (RegExp(r'^[-*+]\s+').hasMatch(line)) {
      flush();
      blocks.add(
        DocBlock(
          DocBlockType.bullet,
          text: line.replaceFirst(RegExp(r'^[-*+]\s+'), ''),
          level: depth,
        ),
      );
    } else if (_numberedItem.hasMatch(line)) {
      flush();
      blocks.add(
        DocBlock(
          DocBlockType.numbered,
          text: _numberedItem.firstMatch(line)!.group(2)!,
          level: depth,
        ),
      );
    } else if (line.startsWith('>')) {
      flush();
      blocks.add(DocBlock(DocBlockType.quote, text: line.substring(1).trim()));
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return blocks;
}

/// Parses slides separated by `---` lines. In each: `# Title`,
/// `## Subtitle`, and `-` bullets (indent two spaces per level); any other
/// line becomes a bullet too.
List<OfficeSlide> parseSlideMarkdown(String source) {
  final slides = <OfficeSlide>[];
  for (final chunk
      in source
          .replaceAll('\r\n', '\n')
          .split(RegExp(r'^\s*-{3,}\s*$', multiLine: true))) {
    var title = '';
    var subtitle = '';
    final bullets = <SlideBullet>[];
    for (final rawLine in chunk.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final depth = ((rawLine.length - rawLine.trimLeft().length) ~/ 2).clamp(
        0,
        2,
      );
      if (line.startsWith('## ') && subtitle.isEmpty) {
        subtitle = line.substring(3).trim();
      } else if (line.startsWith('# ') && title.isEmpty) {
        title = line.substring(2).trim();
      } else {
        bullets.add(
          SlideBullet(
            line.replaceFirst(RegExp(r'^([-*+]|\d+[.)])\s+'), ''),
            depth,
          ),
        );
      }
    }
    if (title.isNotEmpty || subtitle.isNotEmpty || bullets.isNotEmpty) {
      slides.add(
        OfficeSlide(title: title, subtitle: subtitle, bullets: bullets),
      );
    }
  }
  return slides;
}

/// A run of text with inline emphasis, from `**bold**` and `*italic*`.
class InlineRun {
  const InlineRun(this.text, {this.bold = false, this.italic = false});
  final String text;
  final bool bold;
  final bool italic;
}

List<InlineRun> parseInline(String text) {
  final runs = <InlineRun>[];
  final pattern = RegExp(
    r'\*\*(.+?)\*\*|(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?!\*)',
  );
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      runs.add(InlineRun(text.substring(cursor, match.start)));
    }
    if (match.group(1) != null) {
      runs.add(InlineRun(match.group(1)!, bold: true));
    } else {
      runs.add(InlineRun(match.group(2)!, italic: true));
    }
    cursor = match.end;
  }
  if (cursor < text.length) runs.add(InlineRun(text.substring(cursor)));
  return runs;
}

/// Evaluates the small formula subset the preview and the exporter's cached
/// values need: cell references, + - * /, parentheses and SUM, AVERAGE, MIN,
/// MAX and COUNT over ranges. Anything else returns null.
num? evaluateSheetFormula(OfficeSheet sheet, String formula, [int depth = 0]) {
  if (depth > 20) return null;
  try {
    return _FormulaParser(sheet, formula.substring(1), depth).parse();
  } catch (_) {
    return null;
  }
}

/// What a cell shows: a formula's result where it can be computed.
String displayCellValue(OfficeSheet sheet, String raw) {
  if (!raw.startsWith('=')) return raw;
  final value = evaluateSheetFormula(sheet, raw);
  if (value == null) return raw;
  return formatSheetNumber(value);
}

String formatSheetNumber(num value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return double.parse(value.toStringAsFixed(6)).toString();
}

num? parseSheetNumber(String raw) {
  final trimmed = raw.trim();
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(trimmed)) return null;
  return num.tryParse(trimmed);
}

class _FormulaParser {
  _FormulaParser(this.sheet, String source, this.depth)
    : tokens = _tokenize(source);

  static final _token = RegExp(
    r'\s*(\$?[A-Za-z]+\$?\d+:\$?[A-Za-z]+\$?\d+|\$?[A-Za-z]+\$?\d+|[A-Za-z]+(?=\()|\d+(?:\.\d+)?|[-+*/(),])',
  );

  static List<String> _tokenize(String source) {
    final tokens = <String>[];
    var cursor = 0;
    for (final match in _token.allMatches(source)) {
      if (match.start != cursor) break;
      tokens.add(match.group(1)!);
      cursor = match.end;
    }
    if (source.substring(cursor).trim().isNotEmpty) {
      throw const FormatException('Unsupported formula.');
    }
    return tokens;
  }

  final OfficeSheet sheet;
  final int depth;
  final List<String> tokens;
  var _pos = 0;

  num parse() {
    final value = _expression();
    if (_pos != tokens.length) throw const FormatException('Trailing input.');
    return value;
  }

  String? get _peek => _pos < tokens.length ? tokens[_pos] : null;
  String _next() => tokens[_pos++];

  num _expression() {
    var value = _term();
    while (_peek == '+' || _peek == '-') {
      value = _next() == '+' ? value + _term() : value - _term();
    }
    return value;
  }

  num _term() {
    var value = _factor();
    while (_peek == '*' || _peek == '/') {
      if (_next() == '*') {
        value = value * _factor();
      } else {
        final divisor = _factor();
        if (divisor == 0) throw const FormatException('Division by zero.');
        value = value / divisor;
      }
    }
    return value;
  }

  num _factor() {
    final token = _next();
    if (token == '-') return -_factor();
    if (token == '(') {
      final value = _expression();
      if (_next() != ')') throw const FormatException('Missing ).');
      return value;
    }
    final number = num.tryParse(token);
    if (number != null) return number;
    if (_peek == '(') {
      _next();
      final values = <num>[];
      var counted = 0;
      if (_peek != ')') {
        while (true) {
          final arg = _peek!;
          if (arg.contains(':')) {
            _next();
            final range = _range(arg);
            values.addAll(range);
            counted += range.length;
          } else {
            values.add(_expression());
            counted++;
          }
          if (_peek == ',') {
            _next();
            continue;
          }
          break;
        }
      }
      if (_next() != ')') throw const FormatException('Missing ).');
      return switch (token.toUpperCase()) {
        'SUM' => values.fold<num>(0, (a, b) => a + b),
        'AVERAGE' || 'AVG' =>
          values.isEmpty
              ? throw const FormatException('Empty average.')
              : values.fold<num>(0, (a, b) => a + b) / values.length,
        'MIN' => values.isEmpty ? 0 : values.reduce(math.min),
        'MAX' => values.isEmpty ? 0 : values.reduce(math.max),
        'COUNT' => counted,
        _ => throw const FormatException('Unknown function.'),
      };
    }
    final ref = parseCellName(token);
    if (ref == null) throw const FormatException('Bad token.');
    return _cellValue(ref.$1, ref.$2) ?? 0;
  }

  num? _cellValue(int row, int col) {
    final raw = sheet.cell(row, col);
    if (raw.startsWith('=')) {
      final value = evaluateSheetFormula(sheet, raw, depth + 1);
      if (value == null) throw const FormatException('Unresolved cell.');
      return value;
    }
    return parseSheetNumber(raw);
  }

  List<num> _range(String token) {
    final parts = token.split(':');
    final a = parseCellName(parts[0]);
    final b = parseCellName(parts[1]);
    if (a == null || b == null) throw const FormatException('Bad range.');
    final values = <num>[];
    for (var r = math.min(a.$1, b.$1); r <= math.max(a.$1, b.$1); r++) {
      for (var c = math.min(a.$2, b.$2); c <= math.max(a.$2, b.$2); c++) {
        final value = _cellValue(r, c);
        if (value != null) values.add(value);
      }
    }
    return values;
  }
}

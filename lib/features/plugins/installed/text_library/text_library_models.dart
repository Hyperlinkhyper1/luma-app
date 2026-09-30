import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The sixteen text colours Minecraft's formatting codes know, in code order
/// (`§0`..`§f`). Books written in the Minecraft view and in the classic
/// editor share this palette, so a colour chosen in one reads the same in the
/// other.
enum McColor {
  black('black', 0xFF000000),
  darkBlue('dark_blue', 0xFF0000AA),
  darkGreen('dark_green', 0xFF00AA00),
  darkAqua('dark_aqua', 0xFF00AAAA),
  darkRed('dark_red', 0xFFAA0000),
  darkPurple('dark_purple', 0xFFAA00AA),
  gold('gold', 0xFFFFAA00),
  gray('gray', 0xFFAAAAAA),
  darkGray('dark_gray', 0xFF555555),
  blue('blue', 0xFF5555FF),
  green('green', 0xFF55FF55),
  aqua('aqua', 0xFF55FFFF),
  red('red', 0xFFFF5555),
  lightPurple('light_purple', 0xFFFF55FF),
  yellow('yellow', 0xFFFFFF55),
  white('white', 0xFFFFFFFF);

  const McColor(this.id, this.argb);

  /// The name Minecraft uses in JSON text components.
  final String id;
  final int argb;

  Color get color => Color(argb);

  static McColor? byId(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// The sixteen dye colours, used for a subject's banner and a book's cover.
enum DyeColor {
  white(0xFFF9FFFE),
  orange(0xFFF9801D),
  magenta(0xFFC74EBD),
  lightBlue(0xFF3AB3DA),
  yellow(0xFFFED83D),
  lime(0xFF80C71F),
  pink(0xFFF38BAA),
  gray(0xFF474F52),
  lightGray(0xFF9D9D97),
  cyan(0xFF169C9C),
  purple(0xFF8932B8),
  blue(0xFF3C44AA),
  brown(0xFF835432),
  green(0xFF5E7C16),
  red(0xFFB02E26),
  black(0xFF1D1D21);

  const DyeColor(this.argb);

  final int argb;

  Color get color => Color(argb);

  static DyeColor at(int index) =>
      index >= 0 && index < values.length ? values[index] : DyeColor.brown;
}

/// How one run of text is drawn.
@immutable
class RichStyle {
  const RichStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
  });

  static const plain = RichStyle();

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Null means the page's default ink.
  final McColor? color;

  bool get isPlain =>
      !bold && !italic && !underline && !strike && color == null;

  RichStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    McColor? color,
    bool clearColor = false,
  }) => RichStyle(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strike: strike ?? this.strike,
    color: clearColor ? null : (color ?? this.color),
  );

  Map<String, Object?> toJson() => {
    if (bold) 'b': true,
    if (italic) 'i': true,
    if (underline) 'u': true,
    if (strike) 's': true,
    if (color != null) 'c': color!.id,
  };

  static RichStyle fromJson(Map<Object?, Object?> json) => RichStyle(
    bold: json['b'] == true,
    italic: json['i'] == true,
    underline: json['u'] == true,
    strike: json['s'] == true,
    color: McColor.byId(json['c']),
  );

  TextStyle toTextStyle(TextStyle base) {
    final decorations = [
      if (underline) TextDecoration.underline,
      if (strike) TextDecoration.lineThrough,
    ];
    return base.copyWith(
      fontWeight: bold ? FontWeight.w700 : null,
      fontStyle: italic ? FontStyle.italic : null,
      color: color?.color,
      decoration: decorations.isEmpty
          ? null
          : TextDecoration.combine(decorations),
      decorationColor: color?.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RichStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.color == color;

  @override
  int get hashCode => Object.hash(bold, italic, underline, strike, color);
}

@immutable
class RichSpan {
  const RichSpan(this.text, [this.style = RichStyle.plain]);

  final String text;
  final RichStyle style;

  @override
  bool operator ==(Object other) =>
      other is RichSpan && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);
}

/// A text's body: styled runs, newlines included, and any little pictures
/// drawn on its pages.
///
/// Stored as `{"v":1,"spans":[{"t":"…","b":true,"c":"gold"}]}` — the same
/// shape the Minecraft view reads and writes, so neither side has to
/// translate. A body that isn't that JSON is read as plain text rather than
/// thrown away.
@immutable
class RichDoc {
  RichDoc(Iterable<RichSpan> spans, {List<Object?> drawings = const []})
    : spans = List.unmodifiable(_normalize(spans)),
      drawings = List.unmodifiable(drawings);

  RichDoc.plain(String text) : this([RichSpan(text)]);

  static final empty = RichDoc(const []);

  final List<RichSpan> spans;

  /// Shapes drawn on the pages in the Minecraft view, kept exactly as that
  /// page wrote them (`{"k":"star","p":0,"x0":…}`). Only the Minecraft view
  /// draws them; everywhere else they are carried along untouched, so an
  /// edit in the classic editor never wipes them.
  final List<Object?> drawings;

  String get plainText => spans.map((s) => s.text).join();

  bool get isBlank => plainText.trim().isEmpty && drawings.isEmpty;

  RichDoc withDrawings(List<Object?> drawings) =>
      RichDoc(spans, drawings: drawings);

  /// One style per UTF-16 code unit, which is what a [TextEditingController]
  /// indexes by.
  List<RichStyle> get styles => [
    for (final span in spans)
      for (var i = 0; i < span.text.length; i++) span.style,
  ];

  static RichDoc fromStyles(String text, List<RichStyle> styles) {
    assert(styles.length == text.length);
    final spans = <RichSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || styles[i] != styles[start]) {
        spans.add(RichSpan(text.substring(start, i), styles[start]));
        start = i;
      }
    }
    return RichDoc(spans);
  }

  String encode() => jsonEncode({
    'v': 1,
    'spans': [
      for (final span in spans) {'t': span.text, ...span.style.toJson()},
    ],
    if (drawings.isNotEmpty) 'drawings': drawings,
  });

  static RichDoc decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is Map && json['spans'] is List) {
        return RichDoc(
          [
            for (final span in json['spans'] as List)
              if (span is Map && span['t'] is String)
                RichSpan(span['t'] as String, RichStyle.fromJson(span)),
          ],
          drawings: [
            if (json['drawings'] is List)
              for (final d in json['drawings'] as List)
                if (d is Map) d,
          ],
        );
      }
    } on FormatException {
      // Not JSON: fall through and keep it as plain text.
    }
    return RichDoc.plain(raw);
  }

  /// The first [max] characters on one line, for list previews.
  String preview([int max = 140]) {
    final flat = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max - 1)}…';
  }

  static List<RichSpan> _normalize(Iterable<RichSpan> spans) {
    final out = <RichSpan>[];
    for (final span in spans) {
      if (span.text.isEmpty) continue;
      if (out.isNotEmpty && out.last.style == span.style) {
        out[out.length - 1] = RichSpan(out.last.text + span.text, span.style);
      } else {
        out.add(span);
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is RichDoc &&
      other.spans.length == spans.length &&
      Iterable.generate(
        spans.length,
      ).every((i) => other.spans[i] == spans[i]) &&
      jsonEncode(other.drawings) == jsonEncode(drawings);

  @override
  int get hashCode => Object.hash(Object.hashAll(spans), drawings.length);
}

/// A subject: one bookcase in the Minecraft view.
@immutable
class LibrarySubject {
  const LibrarySubject({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
  });

  final int id;
  final String name;
  final DyeColor color;
  final int sortOrder;
  final DateTime createdAt;
}

/// One text — a note, a summary, anything — shelved under a subject.
@immutable
class LibraryText {
  const LibraryText({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.spine,
    required this.body,
    required this.cover,
    required this.slot,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int subjectId;
  final String title;

  /// What is written on the book's spine; falls back to [title] when empty.
  final String spine;
  final RichDoc body;
  final DyeColor cover;

  /// Position in the subject's bookcase, row-major from the top-left slot.
  final int slot;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get spineLabel => spine.trim().isNotEmpty ? spine.trim() : title;
}

/// Bookcase geometry shared with the Minecraft view: a case is four chiseled
/// bookshelves wide and three high, each holding two rows of three books.
const int kShelfColumns = 12;
const int kShelfRows = 6;
const int kSlotsPerCase = kShelfColumns * kShelfRows;

/// The lowest slot at or after [preferred] that is not in [taken].
int firstFreeSlot(Iterable<int> taken, {int preferred = 0}) {
  final used = taken.toSet();
  var slot = preferred < 0 ? 0 : preferred;
  while (used.contains(slot)) {
    slot++;
  }
  return slot;
}

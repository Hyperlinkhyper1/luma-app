import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';

/// Minecraft's sixteen chat colours, in legacy-code order.
enum McChatColor {
  black('0', 0xFF000000),
  darkBlue('1', 0xFF0000AA),
  darkGreen('2', 0xFF00AA00),
  darkAqua('3', 0xFF00AAAA),
  darkRed('4', 0xFFAA0000),
  darkPurple('5', 0xFFAA00AA),
  gold('6', 0xFFFFAA00),
  gray('7', 0xFFAAAAAA),
  darkGray('8', 0xFF555555),
  blue('9', 0xFF5555FF),
  green('a', 0xFF55FF55),
  aqua('b', 0xFF55FFFF),
  red('c', 0xFFFF5555),
  lightPurple('d', 0xFFFF55FF),
  yellow('e', 0xFFFFFF55),
  white('f', 0xFFFFFFFF);

  const McChatColor(this.code, this.argb);

  final String code;
  final int argb;

  Color get color => Color(argb);

  /// The name a JSON text component uses, e.g. `dark_aqua`.
  String get id => name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );

  String get label => id
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static McChatColor? fromCode(String c) {
    for (final v in values) {
      if (v.code == c.toLowerCase()) return v;
    }
    return null;
  }

  static McChatColor? fromId(String id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// The formatting codes that are not colours.
enum McFormat {
  obfuscated('k'),
  bold('l'),
  strikethrough('m'),
  underlined('n'),
  italic('o'),
  reset('r');

  const McFormat(this.code);
  final String code;
}

enum McClickAction {
  none,
  openUrl,
  runCommand,
  suggestCommand,
  copyToClipboard,
  changePage;

  String get id => switch (this) {
    McClickAction.none => '',
    McClickAction.openUrl => 'open_url',
    McClickAction.runCommand => 'run_command',
    McClickAction.suggestCommand => 'suggest_command',
    McClickAction.copyToClipboard => 'copy_to_clipboard',
    McClickAction.changePage => 'change_page',
  };

  String label(L t) => switch (this) {
    McClickAction.none => t.mcClickNothing,
    McClickAction.openUrl => t.mcClickOpenUrl,
    McClickAction.runCommand => t.mcClickRunCommand,
    McClickAction.suggestCommand => t.mcClickSuggestCommand,
    McClickAction.copyToClipboard => t.mcClickCopy,
    McClickAction.changePage => t.mcClickChangePage,
  };

  /// The field name the 1.21.5+ component format uses for the value.
  String get valueKey => switch (this) {
    McClickAction.openUrl => 'url',
    McClickAction.runCommand || McClickAction.suggestCommand => 'command',
    McClickAction.changePage => 'page',
    _ => 'value',
  };
}

/// One run of text with one style — a JSON text component's leaf.
class McTextSpan {
  McTextSpan({
    this.text = '',
    this.color,
    this.bold = false,
    this.italic = false,
    this.underlined = false,
    this.strikethrough = false,
    this.obfuscated = false,
    this.click = McClickAction.none,
    this.clickValue = '',
    this.hover = '',
  });

  String text;

  /// A [McChatColor] id or a `#RRGGBB` hex string; null inherits.
  String? color;
  bool bold;
  bool italic;
  bool underlined;
  bool strikethrough;
  bool obfuscated;
  McClickAction click;
  String clickValue;
  String hover;

  McTextSpan copy() => McTextSpan(
    text: text,
    color: color,
    bold: bold,
    italic: italic,
    underlined: underlined,
    strikethrough: strikethrough,
    obfuscated: obfuscated,
    click: click,
    clickValue: clickValue,
    hover: hover,
  );

  Color resolvedColor([Color fallback = Colors.white]) {
    final c = color;
    if (c == null) return fallback;
    if (c.startsWith('#') && c.length == 7) {
      final v = int.tryParse(c.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return McChatColor.fromId(c)?.color ?? fallback;
  }

  bool get plain =>
      color == null &&
      !bold &&
      !italic &&
      !underlined &&
      !strikethrough &&
      !obfuscated &&
      click == McClickAction.none &&
      hover.isEmpty;

  /// This span as a component map, in the 1.21.5+ field names.
  Map<String, Object> toComponent({bool explicitItalic = false}) {
    final m = <String, Object>{'text': text};
    if (color != null) m['color'] = color!;
    if (bold) m['bold'] = true;
    if (italic) {
      m['italic'] = true;
    } else if (explicitItalic) {
      m['italic'] = false;
    }
    if (underlined) m['underlined'] = true;
    if (strikethrough) m['strikethrough'] = true;
    if (obfuscated) m['obfuscated'] = true;
    if (click != McClickAction.none && clickValue.isNotEmpty) {
      m['click_event'] = {
        'action': click.id,
        click.valueKey: click == McClickAction.changePage
            ? (int.tryParse(clickValue) ?? 1)
            : clickValue,
      };
    }
    if (hover.isNotEmpty) {
      m['hover_event'] = {'action': 'show_text', 'value': hover};
    }
    return m;
  }
}

/// Text components for [spans]: a bare string when nothing is styled, one
/// object for one span, otherwise a list whose first element is `""` so later
/// spans do not inherit the first one's style.
String mcComponentJson(
  List<McTextSpan> spans, {
  bool explicitItalic = false,
  bool pretty = false,
}) {
  final encoder = pretty
      ? const JsonEncoder.withIndent('  ')
      : const JsonEncoder();
  final live = spans.where((s) => s.text.isNotEmpty).toList();
  if (live.isEmpty) return '""';
  if (live.length == 1 && live.first.plain && !explicitItalic) {
    return encoder.convert(live.first.text);
  }
  if (live.length == 1) {
    return encoder.convert(
      live.first.toComponent(explicitItalic: explicitItalic),
    );
  }
  return encoder.convert([
    '',
    for (final s in live) s.toComponent(explicitItalic: explicitItalic),
  ]);
}

/// Parses `&`-style (or `§`-style) legacy codes into spans. `&#RRGGBB` is
/// read as a hex colour, the way most server plugins accept it.
List<McTextSpan> mcParseLegacy(String input) {
  final spans = <McTextSpan>[];
  var current = McTextSpan();
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) return;
    current.text = buffer.toString();
    spans.add(current);
    current = current.copy()..text = '';
    buffer.clear();
  }

  var i = 0;
  while (i < input.length) {
    final ch = input[i];
    if ((ch == '&' || ch == '§') && i + 1 < input.length) {
      if (input[i + 1] == '#' && i + 8 <= input.length) {
        final hex = input.substring(i + 2, i + 8);
        if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
          flush();
          current = McTextSpan(color: '#${hex.toUpperCase()}');
          i += 8;
          continue;
        }
      }
      final code = input[i + 1].toLowerCase();
      final color = McChatColor.fromCode(code);
      if (color != null) {
        flush();
        // A colour code resets formatting, as in the game.
        current = McTextSpan(color: color.id);
        i += 2;
        continue;
      }
      final format = McFormat.values.where((f) => f.code == code);
      if (format.isNotEmpty) {
        flush();
        switch (format.first) {
          case McFormat.obfuscated:
            current.obfuscated = true;
          case McFormat.bold:
            current.bold = true;
          case McFormat.strikethrough:
            current.strikethrough = true;
          case McFormat.underlined:
            current.underlined = true;
          case McFormat.italic:
            current.italic = true;
          case McFormat.reset:
            current = McTextSpan();
        }
        i += 2;
        continue;
      }
    }
    buffer.write(ch);
    i++;
  }
  flush();
  return spans;
}

/// Spans back to legacy codes with [sign] (`§` or `&`). Hex colours only
/// survive with [hex] set, as `&#RRGGBB`; vanilla has no legacy hex code.
String mcToLegacy(List<McTextSpan> spans, {String sign = '§', bool hex = false}) {
  final b = StringBuffer();
  for (final s in spans) {
    final c = s.color;
    if (c != null) {
      final named = McChatColor.fromId(c);
      if (named != null) {
        b.write('$sign${named.code}');
      } else if (hex && c.startsWith('#')) {
        b.write('$sign$c');
      } else if (c.startsWith('#')) {
        b.write('$sign${_nearestChatColor(s.resolvedColor()).code}');
      }
    } else {
      b.write('${sign}r');
    }
    if (s.obfuscated) b.write('${sign}k');
    if (s.bold) b.write('${sign}l');
    if (s.strikethrough) b.write('${sign}m');
    if (s.underlined) b.write('${sign}n');
    if (s.italic) b.write('${sign}o');
    b.write(s.text);
  }
  return b.toString();
}

/// MiniMessage tags, for Paper servers and Adventure-based plugins.
String mcToMiniMessage(List<McTextSpan> spans) {
  final b = StringBuffer();
  for (final s in spans) {
    final open = <String>[];
    if (s.color != null) open.add(s.color!.startsWith('#') ? s.color! : s.color!);
    if (s.bold) open.add('bold');
    if (s.italic) open.add('italic');
    if (s.underlined) open.add('underlined');
    if (s.strikethrough) open.add('strikethrough');
    if (s.obfuscated) open.add('obfuscated');
    if (s.hover.isNotEmpty) open.add("hover:show_text:'${s.hover}'");
    if (s.click != McClickAction.none && s.clickValue.isNotEmpty) {
      open.add("click:${s.click.id}:'${s.clickValue}'");
    }
    for (final tag in open) {
      b.write('<$tag>');
    }
    b.write(s.text);
    if (open.isNotEmpty) b.write('<reset>');
  }
  return b.toString();
}

McChatColor _nearestChatColor(Color c) {
  var best = McChatColor.white;
  var bestD = double.infinity;
  for (final v in McChatColor.values) {
    final o = v.color;
    final d = math.pow(o.r - c.r, 2) +
        math.pow(o.g - c.g, 2) +
        math.pow(o.b - c.b, 2);
    if (d < bestD) {
      bestD = d.toDouble();
      best = v;
    }
  }
  return best;
}

/// Escapes legacy text for server.properties, where `§` must be written as
/// `§` and non-ASCII as escapes too.
String mcPropertiesEscape(String text) {
  final b = StringBuffer();
  for (final rune in text.runes) {
    if (rune == 0x0A) {
      b.write(r'\n');
    } else if (rune < 0x80 && rune != 0x5C) {
      b.writeCharCode(rune);
    } else if (rune == 0x5C) {
      b.write(r'\\');
    } else {
      b.write('\\u${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}');
    }
  }
  return b.toString();
}

/// Renders spans the way the game draws chat: coloured, with a dark drop
/// shadow a quarter of the colour's brightness, obfuscated runs cycling.
class McTextPreview extends StatefulWidget {
  const McTextPreview({
    super.key,
    required this.spans,
    this.fontSize = 16,
    this.align = TextAlign.left,
    this.fallback = Colors.white,
    this.maxLines,
  });

  final List<McTextSpan> spans;
  final double fontSize;
  final TextAlign align;
  final Color fallback;
  final int? maxLines;

  @override
  State<McTextPreview> createState() => _McTextPreviewState();
}

class _McTextPreviewState extends State<McTextPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(McTextPreview old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final obfuscated = widget.spans.any((s) => s.obfuscated);
    if (obfuscated && !_tick.isAnimating) {
      _tick.repeat();
    } else if (!obfuscated && _tick.isAnimating) {
      _tick.stop();
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  String _scramble(String s) {
    const pool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#%&@';
    return String.fromCharCodes(
      s.runes.map(
        (r) => r == 0x20 ? r : pool.codeUnitAt(_random.nextInt(pool.length)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tick,
      builder: (context, _) => Text.rich(
        TextSpan(
          children: [
            for (final s in widget.spans)
              TextSpan(
                text: s.obfuscated ? _scramble(s.text) : s.text,
                style: _style(s),
              ),
          ],
        ),
        textAlign: widget.align,
        maxLines: widget.maxLines,
        overflow: widget.maxLines == null ? null : TextOverflow.clip,
      ),
    );
  }

  TextStyle _style(McTextSpan s) {
    final color = s.resolvedColor(widget.fallback);
    final shadow = Color.fromARGB(
      255,
      ((color.r * 255) / 4).round(),
      ((color.g * 255) / 4).round(),
      ((color.b * 255) / 4).round(),
    );
    final decorations = [
      if (s.underlined) TextDecoration.underline,
      if (s.strikethrough) TextDecoration.lineThrough,
    ];
    return TextStyle(
      color: color,
      fontSize: widget.fontSize,
      height: 1.3,
      fontWeight: s.bold ? FontWeight.w800 : FontWeight.w500,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isEmpty
          ? TextDecoration.none
          : TextDecoration.combine(decorations),
      decorationColor: color,
      decorationThickness: 2,
      shadows: [
        Shadow(color: shadow, offset: Offset(widget.fontSize / 8, widget.fontSize / 8)),
      ],
    );
  }
}

/// A dark, game-like panel to show previews on.
class McGameBackdrop extends StatelessWidget {
  const McGameBackdrop({
    super.key,
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.sky = false,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  /// A daytime-sky gradient instead of the chat-dark one — for titles shown
  /// over the world.
  final bool sky;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky
              ? const [Color(0xFF79A6FF), Color(0xFFA9C7FF), Color(0xFF5E8C3A)]
              : const [Color(0xFF2B2A33), Color(0xFF1A1920)],
          stops: sky ? const [0, 0.72, 0.72] : null,
        ),
      ),
      child: child,
    );
  }
}

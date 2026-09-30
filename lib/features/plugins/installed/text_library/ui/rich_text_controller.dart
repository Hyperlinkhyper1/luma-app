import 'package:flutter/widgets.dart';

import '../text_library_models.dart';

/// A [TextEditingController] that keeps a [RichStyle] for every character.
///
/// Edits arrive as whole new values, so each one is diffed against the old
/// text: removed characters drop their styles and inserted ones take the
/// typing style — whatever the character before the caret wears, unless a
/// format button was pressed with nothing selected.
class RichTextController extends TextEditingController {
  RichTextController([RichDoc? doc])
    : _styles = List.of((doc ?? RichDoc.empty).styles),
      _drawings = (doc ?? RichDoc.empty).drawings,
      super(text: (doc ?? RichDoc.empty).plainText);

  List<RichStyle> _styles;

  /// The Minecraft view's drawings: not edited here, only kept.
  List<Object?> _drawings;

  /// Set by a format toggle with a collapsed selection; used for the next
  /// characters typed there.
  RichStyle? _pending;
  int? _pendingAt;

  RichDoc get doc => RichDoc.fromStyles(text, _styles).withDrawings(_drawings);

  set doc(RichDoc doc) {
    _pending = null;
    _styles = List.of(doc.styles);
    _drawings = doc.drawings;
    super.value = TextEditingValue(
      text: doc.plainText,
      selection: TextSelection.collapsed(offset: doc.plainText.length),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = super.value.text;
    final newText = newValue.text;
    if (oldText != newText) {
      _applyEdit(oldText, newText);
    } else if (_pendingAt != null &&
        (!newValue.selection.isCollapsed ||
            newValue.selection.baseOffset != _pendingAt)) {
      _pending = null;
      _pendingAt = null;
    }
    super.value = newValue;
  }

  void _applyEdit(String oldText, String newText) {
    var prefix = 0;
    final shortest = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < shortest &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        oldText.codeUnitAt(oldText.length - 1 - suffix) ==
            newText.codeUnitAt(newText.length - 1 - suffix)) {
      suffix++;
    }
    final inserted = newText.length - suffix - prefix;
    final style = _pending ?? _styleBefore(prefix);
    _styles = [
      ..._styles.take(prefix),
      for (var i = 0; i < inserted; i++) style,
      ..._styles.skip(oldText.length - suffix),
    ];
    if (_pending != null) _pendingAt = prefix + inserted;
    // Guard against drift from an unexpected edit shape.
    if (_styles.length != newText.length) {
      _styles = [
        for (var i = 0; i < newText.length; i++)
          i < _styles.length ? _styles[i] : style,
      ];
    }
  }

  RichStyle _styleBefore(int offset) {
    if (_styles.isEmpty) return RichStyle.plain;
    if (offset <= 0) return _styles.first;
    return _styles[(offset - 1).clamp(0, _styles.length - 1)];
  }

  TextRange get _range {
    final s = selection;
    if (!s.isValid) return TextRange.collapsed(text.length);
    return TextRange(start: s.start, end: s.end);
  }

  /// The style the toolbar should show as active.
  RichStyle get activeStyle {
    final range = _range;
    if (range.isCollapsed) return _pending ?? _styleBefore(range.start);
    final slice = _styles.sublist(range.start, range.end);
    return RichStyle(
      bold: slice.every((s) => s.bold),
      italic: slice.every((s) => s.italic),
      underline: slice.every((s) => s.underline),
      strike: slice.every((s) => s.strike),
      color: slice.every((s) => s.color == slice.first.color)
          ? slice.first.color
          : null,
    );
  }

  void toggleBold() => _toggle((s) => s.bold, (s, v) => s.copyWith(bold: v));
  void toggleItalic() =>
      _toggle((s) => s.italic, (s, v) => s.copyWith(italic: v));
  void toggleUnderline() =>
      _toggle((s) => s.underline, (s, v) => s.copyWith(underline: v));
  void toggleStrike() =>
      _toggle((s) => s.strike, (s, v) => s.copyWith(strike: v));

  void setColor(McColor? color) => _restyle(
    (s) =>
        color == null ? s.copyWith(clearColor: true) : s.copyWith(color: color),
  );

  void clearFormatting() => _restyle((_) => RichStyle.plain);

  void _toggle(
    bool Function(RichStyle) read,
    RichStyle Function(RichStyle, bool) write,
  ) {
    final on = !read(activeStyle);
    _restyle((s) => write(s, on));
  }

  void _restyle(RichStyle Function(RichStyle) change) {
    final range = _range;
    if (range.isCollapsed) {
      _pending = change(_pending ?? _styleBefore(range.start));
      _pendingAt = range.start;
    } else {
      for (var i = range.start; i < range.end; i++) {
        _styles[i] = change(_styles[i]);
      }
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (_styles.length != text.length) {
      return TextSpan(style: base, text: text);
    }
    var styles = _styles;
    final composing = value.composing;
    if (withComposing &&
        composing.isValid &&
        !composing.isCollapsed &&
        composing.end <= text.length) {
      styles = [
        for (var i = 0; i < styles.length; i++)
          i >= composing.start && i < composing.end
              ? styles[i].copyWith(underline: true)
              : styles[i],
      ];
    }
    final doc = RichDoc.fromStyles(text, styles);
    return TextSpan(
      style: base,
      children: [
        for (final span in doc.spans)
          TextSpan(text: span.text, style: span.style.toTextStyle(base)),
      ],
    );
  }
}

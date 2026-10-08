import 'package:flutter/material.dart';

import '../../../../../l10n/current_l.dart';
import 'whiteboard_element.dart';

/// What a pointer drag on the board does right now.
enum WhiteboardTool {
  select,
  pan,
  pen,
  highlighter,
  eraser,
  line,
  arrow,
  rect,
  ellipse,
  note,
  text;

  IconData get icon => switch (this) {
        WhiteboardTool.select => Icons.near_me_rounded,
        WhiteboardTool.pan => Icons.pan_tool_rounded,
        WhiteboardTool.pen => Icons.edit_rounded,
        WhiteboardTool.highlighter => Icons.format_color_fill_rounded,
        WhiteboardTool.eraser => Icons.cleaning_services_rounded,
        WhiteboardTool.line => Icons.horizontal_rule_rounded,
        WhiteboardTool.arrow => Icons.arrow_right_alt_rounded,
        WhiteboardTool.rect => Icons.crop_square_rounded,
        WhiteboardTool.ellipse => Icons.circle_outlined,
        WhiteboardTool.note => Icons.sticky_note_2_rounded,
        WhiteboardTool.text => Icons.title_rounded,
      };

  String get label => switch (this) {
        WhiteboardTool.select => currentL.whiteboardToolSelect,
        WhiteboardTool.pan => currentL.whiteboardToolPan,
        WhiteboardTool.pen => currentL.whiteboardToolPen,
        WhiteboardTool.highlighter => currentL.whiteboardToolHighlighter,
        WhiteboardTool.eraser => currentL.whiteboardToolEraser,
        WhiteboardTool.line => currentL.whiteboardToolLine,
        WhiteboardTool.arrow => currentL.whiteboardToolArrow,
        WhiteboardTool.rect => currentL.whiteboardToolRectangle,
        WhiteboardTool.ellipse => currentL.whiteboardToolEllipse,
        WhiteboardTool.note => currentL.whiteboardToolStickyNote,
        WhiteboardTool.text => currentL.whiteboardToolText,
      };

  /// The single key that picks this tool, shown in its tooltip.
  String get shortcut => switch (this) {
        WhiteboardTool.select => 'V',
        WhiteboardTool.pan => 'H',
        WhiteboardTool.pen => 'P',
        WhiteboardTool.highlighter => 'M',
        WhiteboardTool.eraser => 'E',
        WhiteboardTool.line => 'L',
        WhiteboardTool.arrow => 'A',
        WhiteboardTool.rect => 'R',
        WhiteboardTool.ellipse => 'O',
        WhiteboardTool.note => 'N',
        WhiteboardTool.text => 'T',
      };

  /// The element this tool draws, or null for the tools that do not draw.
  WhiteboardKind? get kind => switch (this) {
        WhiteboardTool.pen => WhiteboardKind.pen,
        WhiteboardTool.highlighter => WhiteboardKind.highlighter,
        WhiteboardTool.line => WhiteboardKind.line,
        WhiteboardTool.arrow => WhiteboardKind.arrow,
        WhiteboardTool.rect => WhiteboardKind.rect,
        WhiteboardTool.ellipse => WhiteboardKind.ellipse,
        WhiteboardTool.note => WhiteboardKind.note,
        WhiteboardTool.text => WhiteboardKind.text,
        _ => null,
      };

  /// Shapes are dragged corner-to-corner; freehand tools sample every move.
  bool get isDragShape =>
      this == WhiteboardTool.line ||
      this == WhiteboardTool.arrow ||
      this == WhiteboardTool.rect ||
      this == WhiteboardTool.ellipse;

  /// Tools that place something with a single tap rather than a drag.
  bool get isPlacement =>
      this == WhiteboardTool.note || this == WhiteboardTool.text;
}

/// The board's ink.
///
/// These are fixed rather than theme-derived on purpose: the paper is always
/// light (see `whiteboardPaper`), so a stroke drawn in dark mode still reads
/// after the user switches to light mode, and an exported PNG looks like what
/// was on screen. Every entry clears 4.5:1 against both paper shades.
List<({String name, int value})> get whiteboardInks => [
      (name: currentL.whiteboardInkGraphite, value: 0xFF26222F),
      (name: currentL.whiteboardInkRed, value: 0xFFD23B3F),
      (name: currentL.whiteboardInkOrange, value: 0xFFD2690B),
      (name: currentL.whiteboardInkGreen, value: 0xFF12875F),
      (name: currentL.whiteboardInkBlue, value: 0xFF2563DB),
      (name: currentL.whiteboardInkPurple, value: 0xFF6B45C4),
      (name: currentL.whiteboardInkPink, value: 0xFFC4357F),
    ];

/// Stroke widths offered in the toolbar, in board units.
List<({String name, double value})> get whiteboardWidths => [
      (name: currentL.whiteboardWidthFine, value: 2),
      (name: currentL.whiteboardWidthMedium, value: 4),
      (name: currentL.whiteboardWidthBold, value: 8),
    ];

/// The paper.
///
/// A whiteboard is a light surface in both themes — ink colours and exports
/// only make sense against one. Dark mode gets a softened paper rather than a
/// pure white one so it is not a flashlight in a dim room.
Color whiteboardPaper(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFFE7E4EF)
    : const Color(0xFFFFFFFF);

Color whiteboardGrid(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFFC3BED2)
    : const Color(0xFFDCD6EA);

/// A sticky note in the currently selected ink: the same hue, washed out far
/// enough that the note's own text stays readable on it.
Color whiteboardNoteFill(int ink) =>
    Color.lerp(Color(ink), const Color(0xFFFFFFFF), 0.74)!;

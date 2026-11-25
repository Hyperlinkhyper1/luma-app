import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';

/// Inner padding of the composer's popup menus, so their rows sit inset from
/// the border with a rounded hover instead of a full-width band.
const kCompactMenuPadding = EdgeInsets.symmetric(vertical: 5);

/// Horizontal inset of a row's hover highlight from the menu's edge.
const _rowInset = 5.0;

/// Text inset inside a row; headers line up with it.
const _rowPadding = 10.0;

/// Where a non-row entry (a header, a caption) starts, matching row text.
const kCompactMenuTextPadding = _rowInset + _rowPadding;

/// The shape every compact menu uses.
ShapeBorder compactMenuShape(LumaPalette luma) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  side: BorderSide(color: luma.border),
);

/// A small popup menu row whose hover is a rounded, inset highlight rather
/// than [PopupMenuItem]'s edge-to-edge band.
class CompactMenuItem<T> extends PopupMenuEntry<T> {
  const CompactMenuItem({
    super.key,
    required this.value,
    required this.child,
    this.enabled = true,
    this.rowHeight = 30,
  });

  final T value;
  final Widget child;
  final bool enabled;
  final double rowHeight;

  @override
  double get height => rowHeight + 2;

  @override
  bool represents(T? value) => value == this.value;

  @override
  State<CompactMenuItem<T>> createState() => _CompactMenuItemState<T>();
}

class _CompactMenuItemState<T> extends State<CompactMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final radius = BorderRadius.circular(7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _rowInset, vertical: 1),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          hoverColor: luma.surfaceHover,
          focusColor: luma.surfaceHover,
          highlightColor: luma.surfaceHover,
          splashColor: Colors.transparent,
          mouseCursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: widget.enabled
              ? () => Navigator.pop<T>(context, widget.value)
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.rowHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A non-interactive line in a compact menu: a header or a description.
class CompactMenuLabel<T> extends PopupMenuEntry<T> {
  const CompactMenuLabel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      kCompactMenuTextPadding,
      4,
      kCompactMenuTextPadding,
      4,
    ),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  double get height => 24;

  @override
  bool represents(T? value) => false;

  @override
  State<CompactMenuLabel<T>> createState() => _CompactMenuLabelState<T>();
}

class _CompactMenuLabelState<T> extends State<CompactMenuLabel<T>> {
  @override
  Widget build(BuildContext context) =>
      Padding(padding: widget.padding, child: widget.child);
}

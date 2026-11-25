import 'package:flutter/material.dart';

/// Keeps a side panel laid out at its normal width while revealing or hiding
/// it, preserving search and scroll state throughout a desktop transition.
/// [alignment] is the edge the panel is pinned to as it slides.
class AssistantSidebarTransition extends StatelessWidget {
  const AssistantSidebarTransition({
    super.key,
    required this.open,
    required this.child,
    this.width = 264,
    this.alignment = Alignment.topLeft,
  });
  final bool open;
  final Widget child;
  final double width;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: open ? width : 0,
      child: OverflowBox(
        alignment: alignment,
        minWidth: width,
        maxWidth: width,
        child: IgnorePointer(
          ignoring: !open,
          child: ExcludeFocus(
            excluding: !open,
            child: ExcludeSemantics(excluding: !open, child: child),
          ),
        ),
      ),
    ),
  );
}

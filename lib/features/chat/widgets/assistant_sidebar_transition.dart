import 'package:flutter/material.dart';

/// Keeps the sidebar laid out at its normal width while revealing or hiding
/// it, preserving search and scroll state throughout a desktop transition.
class AssistantSidebarTransition extends StatelessWidget {
  const AssistantSidebarTransition({
    super.key,
    required this.open,
    required this.child,
  });
  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: open ? 264 : 0,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 264,
        maxWidth: 264,
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

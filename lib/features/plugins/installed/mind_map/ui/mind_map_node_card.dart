import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../data/mind_map_database.dart';
import 'mind_map_style.dart';

/// One node on the canvas.
///
/// The card is sized by the layout engine rather than by its own content, so
/// it renders the label with exactly the constraints [MindMapStyle.measure]
/// used — anything else and the text would spill out of the rectangle the
/// layout reserved for it.
class MindMapNodeCard extends StatelessWidget {
  const MindMapNodeCard({
    super.key,
    required this.node,
    required this.size,
    required this.color,
    required this.depth,
    required this.hiddenCount,
    required this.selected,
    required this.editing,
    required this.dropTarget,
    required this.dragging,
    required this.controller,
    required this.focusNode,
    required this.onEditingComplete,
    required this.onToggleCollapse,
  });

  final MindMapNode node;
  final Size size;
  final Color color;
  final int depth;

  /// How many descendants sit under this node. When the node is folded the
  /// pill shows the number, so it says what is hidden instead of leaving a
  /// bare chevron to guess at.
  final int hiddenCount;

  final bool selected;
  final bool editing;
  final bool dropTarget;
  final bool dragging;

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEditingComplete;
  final VoidCallback onToggleCollapse;

  bool get _isRoot => depth == 0;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final style = MindMapStyle.labelStyle(isRoot: _isRoot);

    final background = _isRoot
        ? color
        : Color.alphaBlend(color.withValues(alpha: 0.14), luma.surface);
    final textColor = _isRoot ? luma.onAccent : luma.textPrimary;

    final borderColor = dropTarget
        ? luma.success
        : selected || editing
            ? luma.accent
            : color.withValues(alpha: _isRoot ? 0.0 : 0.55);
    final borderWidth = dropTarget || selected || editing ? 2.0 : 1.5;

    final showNote = node.note != null && node.note!.trim().isNotEmpty;
    final showLink = node.link != null && node.link!.trim().isNotEmpty;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: dragging ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: size.width,
        height: size.height,
        padding: const EdgeInsets.symmetric(
          horizontal: MindMapStyle.horizontalPadding,
          vertical: MindMapStyle.verticalPadding,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(MindMapStyle.cornerRadius),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.18 : 0.08),
              blurRadius: selected ? 14 : 6,
              offset: Offset(0, selected ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: editing
                  ? TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      maxLines: null,
                      expands: false,
                      cursorColor: textColor,
                      style: style.copyWith(color: textColor),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'New idea',
                        hintStyle: style.copyWith(
                          color: textColor.withValues(alpha: 0.45),
                        ),
                      ),
                      onEditingComplete: onEditingComplete,
                    )
                  : Text(
                      node.label.trim().isEmpty ? 'New idea' : node.label,
                      style: style.copyWith(
                        color: node.label.trim().isEmpty
                            ? textColor.withValues(alpha: 0.45)
                            : textColor,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (showNote) _Badge(icon: Icons.notes_rounded, color: textColor),
            if (showLink) _Badge(icon: Icons.link_rounded, color: textColor),
            if (hiddenCount > 0)
              _CollapsePill(
                count: hiddenCount,
                collapsed: node.collapsed,
                color: _isRoot ? luma.onAccent : color,
                background: _isRoot
                    ? luma.onAccent.withValues(alpha: 0.18)
                    : color.withValues(alpha: 0.18),
                onTap: onToggleCollapse,
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MindMapStyle.badgeWidth,
      child: Icon(icon, size: 14, color: color.withValues(alpha: 0.55)),
    );
  }
}

/// The fold affordance, shown on every node that has children.
///
/// Folded, it carries the hidden descendant count — a bare chevron does not
/// tell you whether anything is behind it. Expanded, it is the chevron that
/// makes folding discoverable without knowing the keyboard shortcut. It keeps
/// a fixed width either way so folding never resizes the node.
class _CollapsePill extends StatelessWidget {
  const _CollapsePill({
    required this.count,
    required this.collapsed,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final int count;
  final bool collapsed;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plural = count == 1 ? 'node' : 'nodes';
    return Semantics(
      button: true,
      expanded: !collapsed,
      label: collapsed ? 'Expand $count hidden $plural' : 'Collapse $count $plural',
      child: Tooltip(
        message: collapsed ? 'Show $count hidden' : 'Hide $count',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: MindMapStyle.collapsePillWidth,
              height: 20,
              margin: const EdgeInsets.only(left: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: collapsed ? background : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: collapsed
                  ? Text(
                      count > 99 ? '99+' : '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    )
                  : Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: color.withValues(alpha: 0.6),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

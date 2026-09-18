import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../model/whiteboard_tool.dart';

/// What a drag on the board does: the tools, the ink and the history.
///
/// Everything here is an icon with a tooltip that names it and its shortcut —
/// eleven tools cannot carry text labels and still fit, so the tooltip is what
/// announces each one to sighted users and screen readers alike.
///
/// Controls that act on the *view* or the *whole board* — zoom, grid, export,
/// clear — deliberately live in the header instead (see [WhiteboardViewBar]),
/// both so this bar fits one row on a laptop and so "what I am drawing with"
/// and "what I am looking at" do not read as the same kind of choice.
class WhiteboardToolbar extends StatelessWidget {
  const WhiteboardToolbar({
    super.key,
    required this.tool,
    required this.ink,
    required this.strokeWidth,
    required this.canUndo,
    required this.canRedo,
    required this.hasSelection,
    required this.onTool,
    required this.onInk,
    required this.onStrokeWidth,
    required this.onUndo,
    required this.onRedo,
    required this.onDeleteSelection,
  });

  final WhiteboardTool tool;
  final int ink;
  final double strokeWidth;
  final bool canUndo;
  final bool canRedo;
  final bool hasSelection;

  final ValueChanged<WhiteboardTool> onTool;
  final ValueChanged<int> onInk;
  final ValueChanged<double> onStrokeWidth;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(context.lumaDecor.cardRadius),
        border: Border.all(
          color: luma.border,
          width: context.lumaDecor.borderWidth,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final option in WhiteboardTool.values)
            _ToolbarButton(
              icon: option.icon,
              tooltip: '${option.label}  (${option.shortcut})',
              selected: option == tool,
              onTap: () => onTool(option),
            ),
          _Divider(luma: luma),
          for (final swatch in whiteboardInks)
            _InkSwatch(
              color: Color(swatch.value),
              name: swatch.name,
              selected: swatch.value == ink,
              onTap: () => onInk(swatch.value),
            ),
          _Divider(luma: luma),
          for (final width in whiteboardWidths)
            _WidthButton(
              width: width.value,
              name: width.name,
              selected: width.value == strokeWidth,
              onTap: () => onStrokeWidth(width.value),
            ),
          _Divider(luma: luma),
          _ToolbarButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo  (Ctrl+Z)',
            onTap: canUndo ? onUndo : null,
          ),
          _ToolbarButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo  (Ctrl+Shift+Z)',
            onTap: canRedo ? onRedo : null,
          ),
          _ToolbarButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete selection  (Del)',
            onTap: hasSelection ? onDeleteSelection : null,
          ),
        ],
      ),
    );
  }
}

/// Zoom, grid, export and clear — what you do to the board rather than on it.
class WhiteboardViewBar extends StatelessWidget {
  const WhiteboardViewBar({
    super.key,
    required this.zoom,
    required this.showGrid,
    required this.onZoom,
    required this.onFit,
    required this.onToggleGrid,
    required this.onExport,
    required this.onClear,
  });

  final double zoom;
  final bool showGrid;
  final ValueChanged<double> onZoom;
  final VoidCallback onFit;
  final VoidCallback onToggleGrid;
  final VoidCallback onExport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        _ToolbarButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom out',
          onTap: () => onZoom(1 / 1.25),
        ),
        Tooltip(
          message: 'Reset zoom  (Ctrl+0)',
          child: InkWell(
            onTap: onFit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(minWidth: 48),
              child: Text(
                '${(zoom * 100).round()}%',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  // Tabular figures so the board does not twitch sideways as
                  // the percentage changes while zooming.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        _ToolbarButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom in',
          onTap: () => onZoom(1.25),
        ),
        _ToolbarButton(
          icon: Icons.grid_4x4_rounded,
          tooltip: showGrid ? 'Hide grid' : 'Show grid',
          selected: showGrid,
          onTap: onToggleGrid,
        ),
        _Divider(luma: luma),
        _ToolbarButton(
          icon: Icons.image_outlined,
          tooltip: 'Export as PNG',
          onTap: onExport,
        ),
        _ToolbarButton(
          icon: Icons.layers_clear_rounded,
          tooltip: 'Clear board',
          danger: true,
          onTap: onClear,
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final disabled = onTap == null;
    final color = disabled
        ? luma.textMuted.withValues(alpha: 0.45)
        : danger
            ? luma.danger
            : selected
                ? luma.accent
                : luma.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !disabled,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          // 44x44 is the minimum comfortable target; the visual chip inside is
          // smaller so the toolbar still reads as dense.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? luma.accentSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkSwatch extends StatelessWidget {
  const _InkSwatch({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name ink',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 44,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  // Selection is a ring, not just colour — the swatches differ
                  // only by colour, so colour alone could not show which is on.
                  border: Border.all(
                    color: selected ? luma.accent : luma.border,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded,
                        size: 12, color: _onColor(color))
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _onColor(Color color) => color.computeLuminance() > 0.5
      ? const Color(0xFF1B1726)
      : const Color(0xFFFFFFFF);
}

class _WidthButton extends StatelessWidget {
  const _WidthButton({
    required this.width,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: '$name stroke',
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name stroke',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 44,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? luma.accentSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  width: 18,
                  height: width.clamp(2, 8),
                  decoration: BoxDecoration(
                    color: selected ? luma.accent : luma.textSecondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.luma});

  final LumaPalette luma;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        color: luma.border,
      );
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';

class ShellTabItem {
  const ShellTabItem({
    required this.id,
    required this.title,
    required this.icon,
  });

  final String id;
  final String title;
  final IconData icon;
}

/// Scrollable navigation tabs embedded in the window title bar.
class PluginTabBar extends StatelessWidget {
  const PluginTabBar({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    required this.onAdd,
  });

  final List<ShellTabItem> tabs;

  /// The selected navigation slot.
  final String? activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Container(
      height: 46,
      color: luma.background,
      padding: const EdgeInsets.only(left: 6, top: 5),
      child: Row(
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final tab in tabs)
                    _PluginTab(
                      key: ValueKey(tab.id),
                      plugin: tab,
                      selected: tab.id == activeTabId,
                      closeTooltip: t.tabClose,
                      onTap: () => onSelect(tab.id),
                      onClose: () => onClose(tab.id),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: IconButton(
              tooltip: t.tabNew,
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              color: luma.textSecondary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginTab extends StatefulWidget {
  const _PluginTab({
    super.key,
    required this.plugin,
    required this.selected,
    required this.closeTooltip,
    required this.onTap,
    required this.onClose,
  });

  final ShellTabItem plugin;
  final bool selected;
  final String closeTooltip;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_PluginTab> createState() => _PluginTabState();
}

class _PluginTabState extends State<_PluginTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected = widget.selected;
    final fg = selected ? luma.textPrimary : luma.textSecondary;
    final bg = selected
        ? luma.background
        : (_hovering ? luma.surfaceHover : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        // Middle-click closes, as in a browser.
        onPointerDown: (e) {
          if (e.buttons == kMiddleMouseButton) widget.onClose();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            // Clipped rather than given a borderRadius: Flutter only rounds
            // borders whose sides share one colour, and the accent top edge
            // doesn't.
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: Container(
                height: 40,
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
                padding: const EdgeInsets.only(left: 10, right: 4),
                decoration: BoxDecoration(
                  color: bg,
                  border: selected
                      ? Border(
                          top: BorderSide(color: luma.accent, width: 2),
                          left: BorderSide(color: luma.border),
                          right: BorderSide(color: luma.border),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.plugin.icon,
                      size: 16,
                      color: selected ? luma.accent : fg,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.plugin.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12.5,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: selected || _hovering ? 1 : 0.55,
                      child: IconButton(
                        tooltip: widget.closeTooltip,
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded, size: 14),
                        color: fg,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 22,
                          height: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

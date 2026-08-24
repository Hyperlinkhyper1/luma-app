import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'ui/steam_price_tracker_tab.dart';

/// The plugin's sections, in sidebar order.
///
/// Only one tool ships so far. The rail is here from the start anyway
/// because the plugin is a hub by design — adding the second tool should be
/// a new enum value and a new child, not a rewrite of the frame.
enum SteamToolsSection {
  priceTracker(
    icon: Icons.trending_down_rounded,
    label: 'Price Tracker',
    blurb: 'Your library, priced',
  );

  const SteamToolsSection({
    required this.icon,
    required this.label,
    required this.blurb,
  });

  final IconData icon;
  final String label;

  /// One-line description, shown under the label while the rail is expanded
  /// and as the tooltip while it is collapsed.
  final String blurb;
}

/// The Steam Tools plugin's frame: a collapsible sidebar on the left and the
/// selected section on the right.
///
/// The sections are kept alive in an [IndexedStack] rather than rebuilt on
/// every switch — the price tracker holds a scroll position, a search term
/// and possibly a refresh in flight, none of which should reset because the
/// user glanced at another tool.
class SteamToolsPage extends StatefulWidget {
  const SteamToolsPage({super.key});

  @override
  State<SteamToolsPage> createState() => _SteamToolsPageState();
}

class _SteamToolsPageState extends State<SteamToolsPage> {
  SteamToolsSection _section = SteamToolsSection.priceTracker;
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionRail(
          selected: _section,
          collapsed: _collapsed,
          onSelect: (s) => setState(() => _section = s),
          onToggleCollapsed: () => setState(() => _collapsed = !_collapsed),
        ),
        Container(width: 1, color: luma.border),
        Expanded(
          child: IndexedStack(
            index: _section.index,
            children: const [
              SteamPriceTrackerTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The collapsible rail. Expanded it shows an icon, a label and a blurb;
/// collapsed it is icons only, each with a tooltip so the destination is
/// still nameable — an icon with no accessible name is not a navigation
/// item.
class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.selected,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapsed,
  });

  final SteamToolsSection selected;
  final bool collapsed;
  final ValueChanged<SteamToolsSection> onSelect;
  final VoidCallback onToggleCollapsed;

  static const double _expandedWidth = 208;
  static const double _collapsedWidth = 64;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: collapsed ? _collapsedWidth : _expandedWidth,
      color: luma.rail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          for (final section in SteamToolsSection.values)
            _RailItem(
              section: section,
              selected: section == selected,
              collapsed: collapsed,
              onTap: () => onSelect(section),
            ),
          const Spacer(),
          _CollapseButton(collapsed: collapsed, onTap: onToggleCollapsed),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final SteamToolsSection section;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final foreground = selected ? luma.textPrimary : luma.textSecondary;

    final row = Row(
      children: [
        // The selected marker is a bar, not just a tint: colour alone should
        // never be the only thing distinguishing the current destination.
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 3,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? luma.accent : Colors.transparent,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(3),
            ),
          ),
        ),
        SizedBox(width: collapsed ? 17 : 13),
        Icon(section.icon, size: 20, color: selected ? luma.accent : foreground),
        if (!collapsed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Text(
                  section.blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: Tooltip(
            message: collapsed ? '${section.label} — ${section.blurb}' : '',
            waitDuration: const Duration(milliseconds: 400),
            child: Semantics(
              label: section.label,
              selected: selected,
              button: true,
              child: SizedBox(height: 48, child: row),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = collapsed ? 'Expand sidebar' : 'Collapse sidebar';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: Tooltip(
            message: label,
            child: Semantics(
              label: label,
              button: true,
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(width: collapsed ? 20 : 16),
                    Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      size: 18,
                      color: luma.textMuted,
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Collapse',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
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

import 'package:flutter/material.dart';

import '../theme/luma_theme.dart';

/// A single destination shown in the [NavRail].
class NavDestination {
  const NavDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The fixed left icon sidebar, modeled on the Modrinth app.
///
/// For now it shows only the file-converter destination beneath the brand
/// mark. New destinations can be appended to [_destinations] later.
class NavRail extends StatelessWidget {
  const NavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Top destinations, in index order. [settingsIndex] is pinned separately at
  /// the bottom of the rail.
  static const List<NavDestination> _destinations = [
    NavDestination(icon: Icons.dashboard_rounded, label: 'Home'),
    NavDestination(icon: Icons.swap_horiz_rounded, label: 'File Converter'),
    NavDestination(
        icon: Icons.account_balance_wallet_rounded, label: 'Finance'),
    NavDestination(
        icon: Icons.lock_rounded, label: 'Password Manager'),
  ];

  static const NavDestination _pluginsDestination =
      NavDestination(icon: Icons.extension_rounded, label: 'Plugins');

  static const NavDestination _settingsDestination =
      NavDestination(icon: Icons.settings_rounded, label: 'Settings');

  /// Index of the Plugins destination (pinned above Settings).
  static const int pluginsIndex = 4;

  /// Index of the Settings destination (pinned to the bottom-left).
  static const int settingsIndex = 5;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: luma.rail,
        border: Border(right: BorderSide(color: luma.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _BrandMark(),
          const SizedBox(height: 18),
          Container(
            height: 1,
            width: 36,
            color: luma.border,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _destinations.length; i++) ...[
            _RailButton(
              destination: _destinations[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          // Plugins and Settings sit at the bottom-left of the rail.
          _RailButton(
            destination: _pluginsDestination,
            selected: selectedIndex == pluginsIndex,
            onTap: () => onSelect(pluginsIndex),
          ),
          const SizedBox(height: 8),
          _RailButton(
            destination: _settingsDestination,
            selected: selectedIndex == settingsIndex,
            onTap: () => onSelect(settingsIndex),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [luma.accentHover, luma.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: luma.accent.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome_rounded, color: luma.onAccent, size: 22),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected = widget.selected;

    final Color bg = selected
        ? luma.accentSubtle
        : (_hovering ? luma.surfaceHover : Colors.transparent);
    final Color fg = selected ? luma.accent : luma.textSecondary;

    return Tooltip(
      message: widget.destination.label,
      preferBelow: false,
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Active indicator bar on the left edge.
            if (selected)
              Positioned(
                left: 0,
                child: Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: luma.accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.destination.icon, color: fg, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

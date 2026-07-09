import 'package:flutter/material.dart';

import '../account/plan.dart';
import '../features/plugins/plugin_icons.dart';
import '../features/plugins/plugin_repository.dart';
import '../settings/settings_scope.dart';
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
    this.installedPlugins = const [],
    this.selectedPluginId,
    required this.onSelectPlugin,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Downloaded plugins, each rendered as its own icon between the fixed
  /// destinations and the pinned Plugins/Settings group.
  final List<InstalledPluginRecord> installedPlugins;
  final String? selectedPluginId;
  final ValueChanged<String> onSelectPlugin;

  /// Top destinations, in index order. [settingsIndex] is pinned separately at
  /// the bottom of the rail.
  static const List<NavDestination> _destinations = [
    NavDestination(icon: Icons.dashboard_rounded, label: 'Home'),
    NavDestination(icon: Icons.swap_horiz_rounded, label: 'File Converter'),
    NavDestination(
        icon: Icons.account_balance_wallet_rounded, label: 'Finance'),
    NavDestination(
        icon: Icons.lock_rounded, label: 'Password Manager'),
    NavDestination(icon: Icons.sticky_note_2_rounded, label: 'Notes'),
    NavDestination(icon: Icons.smart_toy_rounded, label: 'Assistant'),
  ];

  static const NavDestination _pluginsDestination =
      NavDestination(icon: Icons.extension_rounded, label: 'Plugins');

  static const NavDestination _settingsDestination =
      NavDestination(icon: Icons.settings_rounded, label: 'Settings');

  static const NavDestination _accountDestination =
      NavDestination(icon: Icons.badge_rounded, label: 'Account');

  /// Index of the Plugins destination (pinned above Settings).
  static const int pluginsIndex = 6;

  /// Index of the Settings destination (pinned to the bottom-left).
  static const int settingsIndex = 7;

  /// Index of the Account destination (pinned directly below Settings).
  static const int accountIndex = 8;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final plan = planById(SettingsScope.of(context).selectedPlanId);
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: luma.rail,
        border: Border(right: BorderSide(color: luma.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _destinations.length; i++) ...[
                    _RailButton(
                      destination: _destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (installedPlugins.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(height: 1, width: 36, color: luma.border),
                    const SizedBox(height: 10),
                    for (final plugin in installedPlugins) ...[
                      _RailButton(
                        destination: NavDestination(
                          icon: pluginIconFor(plugin.icon),
                          label: plugin.name,
                        ),
                        selected: selectedPluginId == plugin.pluginId,
                        onTap: () => onSelectPlugin(plugin.pluginId),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          ),
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
          const SizedBox(height: 8),
          _RailButton(
            destination: _accountDestination,
            selected: selectedIndex == accountIndex,
            onTap: () => onSelect(accountIndex),
          ),
          const SizedBox(height: 8),
          _PlanBadge(plan: plan, onTap: () => onSelect(accountIndex)),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

/// A small pinned pill at the very bottom of the rail showing which plan is
/// currently selected — purely cosmetic (see `account/plan.dart`), updates
/// live and taps straight through to the Account tab's Plan section.
class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan, required this.onTap});
  final Plan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: '${plan.name} plan',
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: luma.accent.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              plan.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: luma.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
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

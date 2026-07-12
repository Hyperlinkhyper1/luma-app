import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/plan.dart';
import '../features/plugins/plugin_icons.dart';
import '../features/plugins/plugin_repository.dart';
import '../l10n/app_localizations.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';

/// A single destination shown in the [NavRail].
class NavDestination {
  const NavDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Internal model for one reorderable rail entry.
class _NavItem {
  const _NavItem({
    required this.id,
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
}

/// The fixed left icon sidebar, modeled on the Modrinth app.
///
/// The top section (built-in destinations + installed plugins) is
/// drag-to-reorder: long-press (touch) or click-drag (mouse) an icon to
/// move it up or down. The order is persisted via [SettingsController].
class NavRail extends StatefulWidget {
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
  static List<NavDestination> _destinations(L t) => [
        NavDestination(icon: Icons.dashboard_rounded, label: t.navHome),
        NavDestination(
            icon: Icons.swap_horiz_rounded, label: t.navFileConverter),
        NavDestination(
            icon: Icons.account_balance_wallet_rounded, label: t.navFinance),
        NavDestination(
            icon: Icons.lock_rounded, label: t.navPasswordManager),
        NavDestination(icon: Icons.sticky_note_2_rounded, label: t.navNotes),
        NavDestination(icon: Icons.smart_toy_rounded, label: t.navAssistant),
      ];

  static NavDestination _pluginsDestination(L t) =>
      NavDestination(icon: Icons.extension_rounded, label: t.navPlugins);

  static NavDestination _settingsDestination(L t) =>
      NavDestination(icon: Icons.settings_rounded, label: t.navSettings);

  static NavDestination _accountDestination(L t) =>
      NavDestination(icon: Icons.badge_rounded, label: t.navAccount);

  /// Index of the Plugins destination (pinned above Settings).
  static const int pluginsIndex = 6;

  /// Index of the Settings destination (pinned to the bottom-left).
  static const int settingsIndex = 7;

  /// Index of the Account destination (pinned directly below Settings).
  static const int accountIndex = 8;

  @override
  State<NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<NavRail> {
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final settings = SettingsScope.of(context);
    final plan = planById(settings.selectedPlanId);
    final destinations = NavRail._destinations(t);

    final effectiveOrder =
        _reconcileOrder(settings.navOrder, destinations.length);
    final items = [
      for (final id in effectiveOrder)
        _itemForId(id, destinations, widget.installedPlugins),
    ];

    final isTouch = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

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
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              onReorderStart: (_) => HapticFeedback.mediumImpact(),
              onReorderItem: (oldIndex, newIndex) {
                final order = List<String>.from(effectiveOrder);
                final moved = order.removeAt(oldIndex);
                order.insert(newIndex, moved);
                settings.setNavOrder(order);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 6 * animation.value,
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = items[index];
                final button = _RailButton(
                  destination: item.destination,
                  selected: item.selected,
                  onTap: item.onTap,
                );
                final dragListener = isTouch
                    ? ReorderableDelayedDragStartListener(
                        index: index,
                        child: button,
                      )
                    : ReorderableDragStartListener(
                        index: index,
                        child: button,
                      );
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(child: dragListener),
                );
              },
            ),
          ),
          _RailButton(
            destination: NavRail._pluginsDestination(t),
            selected: widget.selectedIndex == NavRail.pluginsIndex,
            onTap: () => widget.onSelect(NavRail.pluginsIndex),
          ),
          const SizedBox(height: 8),
          _RailButton(
            destination: NavRail._settingsDestination(t),
            selected: widget.selectedIndex == NavRail.settingsIndex,
            onTap: () => widget.onSelect(NavRail.settingsIndex),
          ),
          const SizedBox(height: 8),
          _RailButton(
            destination: NavRail._accountDestination(t),
            selected: widget.selectedIndex == NavRail.accountIndex,
            onTap: () => widget.onSelect(NavRail.accountIndex),
          ),
          const SizedBox(height: 8),
          _PlanBadge(plan: plan, onTap: () => widget.onSelect(NavRail.accountIndex)),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  /// Reconciles the persisted [saved] order with the currently available
  /// items: drops IDs for uninstalled plugins / out-of-range fixed indices
  /// and appends any new items at the end in their default order.
  List<String> _reconcileOrder(List<String> saved, int fixedCount) {
    final fixedIds = [for (var i = 0; i < fixedCount; i++) 'fixed:$i'];
    final pluginIds = [
      for (final p in widget.installedPlugins) 'plugin:${p.pluginId}',
    ];
    final allIds = [...fixedIds, ...pluginIds];
    final allIdSet = allIds.toSet();

    final result = <String>[];
    for (final id in saved) {
      if (allIdSet.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }
    for (final id in allIds) {
      if (!result.contains(id)) {
        result.add(id);
      }
    }
    return result;
  }

  _NavItem _itemForId(
    String id,
    List<NavDestination> destinations,
    List<InstalledPluginRecord> installed,
  ) {
    if (id.startsWith('fixed:')) {
      final i = int.parse(id.substring(6));
      return _NavItem(
        id: id,
        destination: destinations[i],
        selected: i == widget.selectedIndex,
        onTap: () => widget.onSelect(i),
      );
    }
    final pluginId = id.substring(7);
    final plugin = installed.firstWhere((p) => p.pluginId == pluginId);
    return _NavItem(
      id: id,
      destination: NavDestination(
        icon: pluginIconFor(plugin.icon),
        label: plugin.name,
      ),
      selected: widget.selectedPluginId == pluginId,
      onTap: () => widget.onSelectPlugin(pluginId),
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
    final t = L.of(context);
    return Tooltip(
      message: t.planSuffix(plan.name),
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

class _RailButtonState extends State<_RailButton>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

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
              onEnter: (_) {
                setState(() => _hovering = true);
                _scaleCtrl.forward();
              },
              onExit: (_) {
                setState(() => _hovering = false);
                _scaleCtrl.reverse();
              },
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
                  child: ScaleTransition(
                    scale: _scale,
                    child: Icon(widget.destination.icon, color: fg, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

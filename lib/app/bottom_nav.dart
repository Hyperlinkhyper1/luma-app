import 'package:flutter/material.dart';

import '../account/plan.dart';
import '../features/plugins/plugin_icons.dart';
import '../features/plugins/plugin_repository.dart';
import '../l10n/app_localizations.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'nav_rail.dart';

/// Phone-width replacement for [NavRail]: a bottom bar with the primary
/// destinations plus a "More" tab that opens a sheet with everything else
/// (Notes, Plugins, Settings and any installed plugins), keeping to the
/// platform's max-5-items guidance for bottom navigation.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.installedPlugins = const [],
    this.selectedPluginId,
    required this.onSelectPlugin,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<InstalledPluginRecord> installedPlugins;
  final String? selectedPluginId;
  final ValueChanged<String> onSelectPlugin;

  static List<NavDestination> _primary(L t) => [
        NavDestination(icon: Icons.dashboard_rounded, label: t.navHome),
        NavDestination(
            icon: Icons.account_balance_wallet_rounded, label: t.navFinance),
        NavDestination(icon: Icons.swap_horiz_rounded, label: t.navConvert),
        NavDestination(icon: Icons.lock_rounded, label: t.navVault),
      ];

  // Index into AppShell's fixed screen list for each primary tab above.
  static const _primaryTargets = [0, 2, 1, 3];

  bool get _moreSelected =>
      selectedPluginId != null ||
      selectedIndex == 4 ||
      selectedIndex == 5 ||
      selectedIndex == NavRail.pluginsIndex ||
      selectedIndex == NavRail.settingsIndex ||
      selectedIndex == NavRail.accountIndex;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final primary = _primary(t);
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: luma.rail,
          border: Border(top: BorderSide(color: luma.border)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < primary.length; i++)
              Expanded(
                child: _BottomNavButton(
                  destination: primary[i],
                  selected:
                      !_moreSelected && selectedIndex == _primaryTargets[i],
                  onTap: () => onSelect(_primaryTargets[i]),
                ),
              ),
            Expanded(
              child: _BottomNavButton(
                destination:
                    NavDestination(icon: Icons.more_horiz_rounded, label: t.navMore),
                selected: _moreSelected,
                onTap: () => _openMoreSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreSheet(BuildContext context) {
    final t = L.of(context);
    final plan = planById(SettingsScope.of(context).selectedPlanId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.luma.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          // Without isScrollControlled + an explicit scroll view, a sheet
          // taller than the default (non-scrollable) bottom sheet height
          // just clips its overflowing rows instead of scrolling to them —
          // e.g. installed plugins past the first couple become untappable.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MoreRow(
                  icon: Icons.sticky_note_2_rounded,
                  label: t.navNotes,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelect(4);
                  },
                ),
                _MoreRow(
                  icon: Icons.smart_toy_rounded,
                  label: t.navAssistant,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelect(5);
                  },
                ),
                _MoreRow(
                  icon: Icons.extension_rounded,
                  label: t.navPlugins,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelect(NavRail.pluginsIndex);
                  },
                ),
                _MoreRow(
                  icon: Icons.settings_rounded,
                  label: t.navSettings,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelect(NavRail.settingsIndex);
                  },
                ),
                _MoreRow(
                  icon: Icons.badge_rounded,
                  label: t.navAccount,
                  trailing: t.planSuffix(plan.name),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onSelect(NavRail.accountIndex);
                  },
                ),
                if (installedPlugins.isNotEmpty) ...[
                  const Divider(height: 20),
                  for (final plugin in installedPlugins)
                    _MoreRow(
                      icon: pluginIconFor(plugin.icon),
                      label: plugin.name,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onSelectPlugin(plugin.pluginId);
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = selected ? luma.accent : luma.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(destination.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ListTile(
      leading: Icon(icon, color: luma.textSecondary),
      title: Text(label, style: TextStyle(color: luma.textPrimary)),
      trailing: trailing == null
          ? null
          : Text(trailing!, style: TextStyle(color: luma.textMuted, fontSize: 12)),
      onTap: onTap,
    );
  }
}

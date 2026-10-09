import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import '../roblox_tools/mafia/mafia_role_counter_tab.dart';
import '../steam_tools/ui/cs2_market_tab.dart';
import '../steam_tools/ui/cs2_selling_calculator_tab.dart';
import '../steam_tools/ui/steam_price_tracker_tab.dart';
import 'minecraft/mc_tool_catalog.dart';
import 'minecraft/minecraft_tools_page.dart';

/// A game (or game platform) the sidebar groups its sections under.
///
/// Game Tools replaced the separate Steam Tools and Roblox Tools plugins, so
/// the rail is a list of games the way Account Overview's is a list of
/// accounts: adding the next one is a new value here plus its sections.
enum GameToolsGame {
  steam('Steam', Icons.sports_esports_rounded),
  roblox('Roblox', Icons.videogame_asset_rounded),
  minecraft('Minecraft', Icons.widgets_rounded);

  const GameToolsGame(this.label, this.icon);

  final String label;
  final IconData icon;

  List<GameToolsSection> get sections => [
    for (final section in GameToolsSection.values)
      if (section.game == this) section,
  ];

  /// A game with a single section has nothing to fold away — its heading
  /// opens that section directly instead of toggling a one-item list.
  bool get collapsible => sections.length > 1;
}

/// The plugin's sections, in sidebar order, grouped by [game]. The enum's
/// index is also the [IndexedStack] index in [GameToolsPage].
enum GameToolsSection {
  priceTracker(game: GameToolsGame.steam, icon: Icons.trending_down_rounded),
  cs2Market(game: GameToolsGame.steam, icon: Icons.diamond_outlined),
  sellingCalculator(game: GameToolsGame.steam, icon: Icons.calculate_outlined),
  mafia(game: GameToolsGame.roblox, icon: Icons.theater_comedy_rounded),
  minecraft(game: GameToolsGame.minecraft, icon: Icons.widgets_rounded);

  const GameToolsSection({required this.game, required this.icon});

  final GameToolsGame game;
  final IconData icon;

  String label(L t) => switch (this) {
    GameToolsSection.priceTracker => t.pluginNamePriceTracker,
    GameToolsSection.cs2Market => t.gameToolsCs2MarketLabel,
    GameToolsSection.sellingCalculator => t.gameToolsSellingCalculatorLabel,
    GameToolsSection.mafia => 'Mafia',
    GameToolsSection.minecraft => t.mcToolsCount(McTool.values.length),
  };

  /// One-line description, shown under the label while the rail is expanded
  /// and inside the tooltip while it is collapsed.
  String blurb(L t) => switch (this) {
    GameToolsSection.priceTracker => t.gameToolsPriceTrackerBlurb,
    GameToolsSection.cs2Market => t.gameToolsCs2MarketBlurb,
    GameToolsSection.sellingCalculator => t.gameToolsSellingCalculatorBlurb,
    GameToolsSection.mafia => t.gameToolsMafiaBlurb,
    GameToolsSection.minecraft => t.gameToolsMinecraftBlurb,
  };

  /// The label a flat tab strip uses, where there is no heading to say which
  /// game a section belongs to.
  String flatLabel(L t) =>
      game.collapsible ? '${game.label} · ${label(t)}' : game.label;
}

/// The Game Tools plugin's frame: a collapsible game sidebar on the left and
/// the selected section on the right, the same shape as Account Overview.
///
/// Sections are kept alive in an [IndexedStack] rather than rebuilt on every
/// switch — the price tracker holds a scroll position, a search term and
/// possibly a refresh in flight, and the Mafia counter holds a round's claims,
/// none of which should reset because the user glanced at another tool.
class GameToolsPage extends StatefulWidget {
  const GameToolsPage({
    super.key,
    this.initialSection = GameToolsSection.priceTracker,
  });

  final GameToolsSection initialSection;

  @override
  State<GameToolsPage> createState() => _GameToolsPageState();
}

class _GameToolsPageState extends State<GameToolsPage> {
  late GameToolsSection _section = widget.initialSection;
  bool _collapsed = false;

  /// Sections built so far. A section is built on its first visit and kept
  /// alive after, so opening the plugin on Mafia does not start the CS2
  /// market loading behind it.
  late final Set<GameToolsSection> _visited = {_section};

  /// The one game whose sections are shown under its heading — an accordion,
  /// so picking a section in one game folds every other one away.
  late GameToolsGame? _expandedGame = _section.game;

  void _selectSection(GameToolsSection section) {
    setState(() {
      _section = section;
      _visited.add(section);
      _expandedGame = section.game;
    });
  }

  void _onGameTap(GameToolsGame game) {
    if (!game.collapsible) {
      _selectSection(game.sections.first);
      return;
    }
    setState(() => _expandedGame = _expandedGame == game ? null : game);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final body = IndexedStack(
      index: _section.index,
      children: [
        for (final section in GameToolsSection.values)
          if (!_visited.contains(section))
            const SizedBox.shrink()
          else
            switch (section) {
              GameToolsSection.priceTracker => const SteamPriceTrackerTab(),
              GameToolsSection.cs2Market => const Cs2MarketTab(),
              GameToolsSection.sellingCalculator =>
                const Cs2SellingCalculatorTab(),
              GameToolsSection.mafia => const MafiaRoleCounterTab(),
              GameToolsSection.minecraft => const MinecraftToolsPage(),
            },
      ],
    );

    if (context.isPhoneWidth) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: LumaSegmentedTabs(
              tabs: [
                for (final section in GameToolsSection.values)
                  section.flatLabel(t),
              ],
              selectedIndex: _section.index,
              scrollable: true,
              onSelect: (index) =>
                  _selectSection(GameToolsSection.values[index]),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GameRail(
          selected: _section,
          collapsed: _collapsed,
          expandedGame: _expandedGame,
          onSelect: _selectSection,
          onGameTap: _onGameTap,
          onToggleCollapsed: () => setState(() => _collapsed = !_collapsed),
        ),
        Container(width: 1, color: luma.border),
        Expanded(child: body),
      ],
    );
  }
}

/// The collapsible rail. Expanded it shows each game's heading and, under the
/// open one, its sections; collapsed it is icons only, each with a tooltip so
/// the destination is still nameable.
class _GameRail extends StatelessWidget {
  const _GameRail({
    required this.selected,
    required this.collapsed,
    required this.expandedGame,
    required this.onSelect,
    required this.onGameTap,
    required this.onToggleCollapsed,
  });

  final GameToolsSection selected;
  final bool collapsed;
  final GameToolsGame? expandedGame;
  final ValueChanged<GameToolsSection> onSelect;
  final ValueChanged<GameToolsGame> onGameTap;
  final VoidCallback onToggleCollapsed;

  static const double _expandedWidth = 210;
  static const double _collapsedWidth = 64;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final target = collapsed ? _collapsedWidth : _expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: target,
      decoration: BoxDecoration(color: luma.rail),
      clipBehavior: Clip.hardEdge,
      // Laying the children out at the target width and clipping the
      // difference turns the first frame of the resize into a clean slide
      // instead of an overflow.
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: target,
        maxWidth: target,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final game in GameToolsGame.values) ...[
                    _GameHeading(
                      game: game,
                      collapsed: collapsed,
                      expanded: expandedGame == game,
                      selected: !game.collapsible && selected.game == game,
                      onTap: () => onGameTap(game),
                    ),
                    if (game.collapsible)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: expandedGame != game
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 4),
                                  for (final section in game.sections)
                                    _RailItem(
                                      section: section,
                                      selected: section == selected,
                                      collapsed: collapsed,
                                      onTap: () => onSelect(section),
                                    ),
                                ],
                              ),
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            _CollapseButton(collapsed: collapsed, onTap: onToggleCollapsed),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// A game's heading. For a game with several sections it folds them in and
/// out; for a game with one it is the destination itself, so it carries the
/// selected marker.
class _GameHeading extends StatelessWidget {
  const _GameHeading({
    required this.game,
    required this.collapsed,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final GameToolsGame game;
  final bool collapsed;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final count = game.sections.length;
    final line = game.collapsible
        ? t.gameToolsToolCount(count)
        : game.sections.first.label(t);

    final content = Row(
      mainAxisAlignment: collapsed
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? luma.accent : luma.accentSubtle,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            game.icon,
            size: 17,
            color: selected ? luma.onAccent : luma.accent,
          ),
        ),
        if (!collapsed) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  game.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: luma.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (game.collapsible)
            AnimatedRotation(
              duration: const Duration(milliseconds: 160),
              turns: expanded ? 0 : -0.25,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: luma.textMuted,
              ),
            ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: Tooltip(
            message: collapsed ? '${game.label} — $line' : '',
            waitDuration: const Duration(milliseconds: 400),
            child: Semantics(
              label: game.label,
              button: true,
              selected: selected,
              expanded: game.collapsible ? expanded : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 2 : 6,
                  vertical: 8,
                ),
                child: content,
              ),
            ),
          ),
        ),
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

  final GameToolsSection section;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
        Icon(
          section.icon,
          size: 20,
          color: selected ? luma.accent : foreground,
        ),
        if (!collapsed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.label(t),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Text(
                  section.blurb(t),
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
            message: collapsed
                ? t.gameToolsSectionTooltip(section.label(t), section.blurb(t))
                : '',
            waitDuration: const Duration(milliseconds: 400),
            child: Semantics(
              label: section.label(t),
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
    final t = L.of(context);
    final label = collapsed
        ? t.accountOverviewExpandSidebar
        : t.accountOverviewCollapseSidebar;
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
                          t.aiUsageSidebarCollapseShort,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 12),
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

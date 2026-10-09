import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import 'data/mc_registries_data.dart';
import 'mc_tool_catalog.dart';
import 'mc_tool_host.dart';
import 'tools/admins/color_codes_tool.dart';
import 'tools/admins/command_generator_tool.dart';
import 'tools/admins/custom_potions_tool.dart';
import 'tools/admins/custom_world_tool.dart';
import 'tools/admins/flat_preset_tool.dart';
import 'tools/admins/loot_table_tool.dart';
import 'tools/admins/motd_tool.dart';
import 'tools/admins/tellraw_tool.dart';
import 'tools/admins/title_tool.dart';
import 'tools/developers/advancement_tool.dart';
import 'tools/developers/asset_library_tool.dart';
import 'tools/developers/enchantment_tool.dart';
import 'tools/developers/recipe_tool.dart';
import 'tools/players/armor_designer_tool.dart';
import 'tools/players/banner_tool.dart';
import 'tools/players/beacon_guide_tool.dart';
import 'tools/players/build_planner_tool.dart';
import 'tools/players/enchant_optimizer_tool.dart';
import 'tools/players/firework_tool.dart';
import 'tools/players/map_art_tool.dart';
import 'tools/players/ore_guide_tool.dart';
import 'tools/players/potion_guide_tool.dart';
import 'tools/players/roof_tool.dart';
import 'tools/players/schematic_organizer_tool.dart';
import 'tools/players/shape_generator_tool.dart';
import 'tools/players/skin_editor_tool.dart';
import 'tools/players/sulfur_cube_tool.dart';
import 'tools/players/villager_guide_tool.dart';
import 'ui/mc_showcase.dart';
import 'ui/mc_style.dart';

export 'ui/mc_showcase.dart' show McToolCard;

/// Game Tools → Minecraft: a hub of tools in the Pugtools mould, split into
/// three sub-tabs by who they are for, each opening its own screen.
class MinecraftToolsPage extends StatefulWidget {
  const MinecraftToolsPage({super.key, this.initialTool});

  /// Opens straight into a tool, for tests and deep links.
  final McTool? initialTool;

  @override
  State<MinecraftToolsPage> createState() => _MinecraftToolsPageState();
}

class _MinecraftToolsPageState extends State<MinecraftToolsPage> {
  late McTool? _open = widget.initialTool;
  late McAudience _audience = widget.initialTool?.group.audience ??
      McAudience.players;
  final TextEditingController _search = TextEditingController();
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    final Widget child;
    if (open != null) {
      final host = McToolHost(
        tool: open,
        onBack: () => setState(() => _open = null),
      );
      child = KeyedSubtree(key: ValueKey(open), child: buildMcTool(host));
    } else {
      child = _Hub(
        key: const ValueKey('hub'),
        audience: _audience,
        search: _search,
        onAudience: (a) => setState(() => _audience = a),
        onSearch: () => setState(() {}),
        onOpen: (tool) => setState(() => _open = tool),
      );
    }
    // Opening a tool zooms it up out of the hub; going back settles the hub
    // into place again.
    return PageStorage(
      bucket: _bucket,
      child: AnimatedSwitcher(
        duration: McMotion.reduced(context) ? Duration.zero : McMotion.medium,
        reverseDuration:
            McMotion.reduced(context) ? Duration.zero : McMotion.fast,
        switchInCurve: McMotion.enter,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// The tool screen for [host]'s tool.
Widget buildMcTool(McToolHost host) => switch (host.tool) {
  McTool.enchantOptimizer => EnchantOptimizerTool(host: host),
  McTool.shapeGenerator => ShapeGeneratorTool(host: host),
  McTool.skinEditor => SkinEditorTool(host: host),
  McTool.schematicOrganizer => SchematicOrganizerTool(host: host),
  McTool.villagerGuide => VillagerGuideTool(host: host),
  McTool.oreGuide => OreGuideTool(host: host),
  McTool.potionGuide => PotionGuideTool(host: host),
  McTool.sulfurCubeGuide => SulfurCubeTool(host: host),
  McTool.beaconGuide => BeaconGuideTool(host: host),
  McTool.shieldMaker => BannerTool(host: host, shield: true),
  McTool.fireworkMaker => FireworkTool(host: host),
  McTool.bannerMaker => BannerTool(host: host),
  McTool.buildPlanner => BuildPlannerTool(host: host),
  McTool.mapArtGenerator => MapArtTool(host: host),
  McTool.roofGenerator => RoofTool(host: host),
  McTool.armorDesigner => ArmorDesignerTool(host: host),
  McTool.flatPreset => FlatPresetTool(host: host),
  McTool.customWorld => CustomWorldTool(host: host),
  McTool.colorCodes => ColorCodesTool(host: host),
  McTool.titleGenerator => TitleTool(host: host),
  McTool.tellrawGenerator => TellrawTool(host: host),
  McTool.motdGenerator => MotdTool(host: host),
  McTool.lootTables => LootTableTool(host: host),
  McTool.customPotions => CustomPotionsTool(host: host),
  McTool.commandGenerator => CommandGeneratorTool(host: host),
  McTool.assetLibrary => AssetLibraryTool(host: host),
  McTool.recipeGenerator => RecipeTool(host: host),
  McTool.enchantmentGenerator => EnchantmentTool(host: host),
  McTool.advancementGenerator => AdvancementTool(host: host),
};

/// The stagger between cards rising into a grid, capped so a long list
/// does not keep the user waiting for its last row.
Duration _stagger(int index) =>
    Duration(milliseconds: 40 * (index < 10 ? index : 10));

class _Hub extends StatelessWidget {
  const _Hub({
    super.key,
    required this.audience,
    required this.search,
    required this.onAudience,
    required this.onSearch,
    required this.onOpen,
  });

  final McAudience audience;
  final TextEditingController search;
  final ValueChanged<McAudience> onAudience;
  final VoidCallback onSearch;
  final ValueChanged<McTool> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final phone = context.isPhoneWidth;
    final pad = phone ? 16.0 : 40.0;
    final query = search.text.trim();
    final results = query.isEmpty
        ? const <McTool>[]
        : [
            for (final tool in McTool.values)
              if (tool.matches(t, query)) tool,
          ];
    final minTile = phone ? 260.0 : 270.0;

    Widget section(Widget child) => SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          // Pugtools keeps its page to a column; past this, cards only get
          // wider, not better.
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            // Full width, so a narrow child (the hero) lines up on the left
            // edge with everything else instead of being centred.
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );

    var cardIndex = 0;
    return McBackdrop(
      child: CustomScrollView(
        key: const PageStorageKey('mc-tools-hub'),
        slivers: [
          section(
            Padding(
              padding: EdgeInsets.only(top: phone ? 20 : 40),
              child: _Hero(phone: phone),
            ),
          ),
          section(
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: _AudienceBar(
                selected: query.isEmpty ? audience : null,
                onSelect: (a) {
                  search.clear();
                  onAudience(a);
                },
                search: search,
                onSearch: onSearch,
              ),
            ),
          ),
          if (query.isNotEmpty)
            section(
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: results.isEmpty
                    ? McHint(
                        icon: Icons.search_off_rounded,
                        title: t.mcToolsSearchResults(0),
                        body: t.mcToolsNoMatchBody,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          McHeading(t.mcToolsSearchResults(results.length)),
                          const SizedBox(height: 16),
                          McGrid(
                            minTileWidth: minTile,
                            spacing: 20,
                            children: [
                              for (final (i, tool) in results.indexed)
                                McReveal(
                                  key: ValueKey('search-${tool.name}'),
                                  delay: _stagger(i),
                                  child: McToolCard(
                                    tool: tool,
                                    onTap: () => onOpen(tool),
                                    showAudience: true,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            )
          else ...[
            section(
              Padding(
                padding: EdgeInsets.only(top: phone ? 22 : 30),
                child: McReveal(
                  key: ValueKey('spot-${audience.name}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      McHeading(
                        audience.blurb(t),
                        size: phone ? 24 : 34,
                      ),
                      const SizedBox(height: 18),
                      McSpotlight(tools: audience.tools, onOpen: onOpen),
                    ],
                  ),
                ),
              ),
            ),
            for (final group in audience.groups)
              section(
                Padding(
                  padding: EdgeInsets.only(top: phone ? 34 : 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      McHeading(
                        group.label(t),
                        size: phone ? 22 : 28,
                        trailing: Text(
                          t.mcToolsCount(group.tools.length),
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      McGrid(
                        minTileWidth: minTile,
                        spacing: 20,
                        children: [
                          for (final tool in group.tools)
                            McReveal(
                              key: ValueKey('card-${tool.name}'),
                              delay: _stagger(cardIndex++),
                              child: McToolCard(
                                tool: tool,
                                onTap: () => onOpen(tool),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          section(
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 48, 0, 32),
              child: Text(
                t.mcToolsDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.phone});

  final bool phone;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return McReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Pulse(),
                const SizedBox(width: 8),
                Text(
                  t.mcToolsKicker(kMcDataVersion),
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Text(
              t.mcToolsHeadline,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: phone ? 32 : 52,
                fontWeight: FontWeight.w900,
                letterSpacing: phone ? -0.8 : -1.6,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              t.mcToolsSubtitle,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: phone ? 14.5 : 16.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live dot on the version pill: a soft ring that breathes outwards.
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (McMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = McHue.green.color;
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 7 + 7 * v,
                height: 7 + 7 * v,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.35 * (1 - v)),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AudienceBar extends StatelessWidget {
  const _AudienceBar({
    required this.selected,
    required this.onSelect,
    required this.search,
    required this.onSearch,
  });

  final McAudience? selected;
  final ValueChanged<McAudience> onSelect;
  final TextEditingController search;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final field = SizedBox(
      width: context.isPhoneWidth ? double.infinity : 280,
      child: TextField(
        controller: search,
        onChanged: (_) => onSearch(),
        style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
        decoration: mcInputDecoration(
          context,
          hint: t.mcToolsSearchHint,
          prefixIcon: Icons.search_rounded,
        ).copyWith(
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
                  onPressed: () {
                    search.clear();
                    onSearch();
                  },
                ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AudienceTabs(selected: selected, onSelect: onSelect, compact: true),
              const SizedBox(height: 10),
              field,
            ],
          );
        }
        return Row(
          children: [
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _AudienceTabs(selected: selected, onSelect: onSelect),
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
            field,
          ],
        );
      },
    );
  }
}

/// A segmented control whose highlight slides between the sub-tabs. The
/// tabs share one width so the highlight only has to move, never resize.
class _AudienceTabs extends StatelessWidget {
  const _AudienceTabs({
    required this.selected,
    required this.onSelect,
    this.compact = false,
  });

  final McAudience? selected;
  final ValueChanged<McAudience> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final count = McAudience.values.length;
    final index = selected?.index;
    final row = Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final a in McAudience.values)
          Expanded(
            child: _AudienceTab(
              audience: a,
              selected: a == selected,
              compact: compact,
              onTap: () => onSelect(a),
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: McMotion.fast,
              opacity: index == null ? 0 : 1,
              child: AnimatedAlign(
                duration: McMotion.reduced(context) ? Duration.zero : McMotion.medium,
                curve: Curves.easeOutBack,
                alignment: Alignment(
                  count == 1 ? 0 : -1 + 2 * (index ?? 0) / (count - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: luma.accent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: luma.accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (compact) row else IntrinsicWidth(child: row),
        ],
      ),
    );
  }
}

class _AudienceTab extends StatelessWidget {
  const _AudienceTab({
    required this.audience,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final McAudience audience;
  final bool selected;
  final VoidCallback onTap;

  /// Phone width: icon and name only, sharing the row equally.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final count = audience.tools.length;
    final fg = selected ? luma.onAccent : luma.textPrimary;
    return Tooltip(
      message: audience.blurb(t),
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${audience.label(t)}, ${t.mcToolsCount(count)}',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            hoverColor: selected ? Colors.transparent : luma.surfaceHover,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: selected ? luma.onAccent : luma.textSecondary),
                    duration: McMotion.fast,
                    builder: (context, color, _) =>
                        Icon(audience.icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: McMotion.fast,
                      style: DefaultTextStyle.of(context).style.copyWith(
                        color: fg,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text(
                        audience.label(t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (!compact) const SizedBox(width: 8),
                  if (!compact)
                    AnimatedContainer(
                      duration: McMotion.fast,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? luma.onAccent.withValues(alpha: 0.18)
                            : luma.surfaceHover,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: selected ? luma.onAccent : luma.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

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
import 'ui/mc_style.dart';

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
    if (open != null) {
      final host = McToolHost(
        tool: open,
        onBack: () => setState(() => _open = null),
      );
      return KeyedSubtree(key: ValueKey(open), child: buildMcTool(host));
    }
    return PageStorage(
      bucket: _bucket,
      child: _Hub(
        audience: _audience,
        search: _search,
        onAudience: (a) => setState(() => _audience = a),
        onSearch: () => setState(() {}),
        onOpen: (tool) => setState(() => _open = tool),
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

class _Hub extends StatelessWidget {
  const _Hub({
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
    final pad = phone ? 14.0 : 32.0;
    final query = search.text.trim();
    final results = query.isEmpty
        ? const <McTool>[]
        : [
            for (final tool in McTool.values)
              if (tool.matches(t, query)) tool,
          ];

    return McBackdrop(
      child: CustomScrollView(
        key: const PageStorageKey('mc-tools-hub'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, phone ? 16 : 30, pad, 0),
              child: _Hero(phone: phone),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 22, pad, 6),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 18, pad, 0),
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
                          const SizedBox(height: 14),
                          McGrid(
                            minTileWidth: phone ? 260 : 250,
                            children: [
                              for (final tool in results)
                                McToolCard(
                                  tool: tool,
                                  onTap: () => onOpen(tool),
                                  showAudience: true,
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            )
          else
            for (final group in audience.groups)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 26, pad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      McHeading(
                        group.label(t),
                        size: phone ? 20 : 24,
                        trailing: Text(
                          t.mcToolsCount(group.tools.length),
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      McGrid(
                        minTileWidth: phone ? 260 : 250,
                        children: [
                          for (final tool in group.tools)
                            McToolCard(tool: tool, onTap: () => onOpen(tool)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 34, pad, 30),
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
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: McHue.green.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
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
        const SizedBox(height: 12),
        McHeading(t.mcToolsHeadline, size: phone ? 26 : 36),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            t.mcToolsSubtitle,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: phone ? 13.5 : 15,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
    if (phone) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: text),
        const SizedBox(width: 24),
        SizedBox(
          width: 220,
          height: 150,
          child: CustomPaint(
            painter: _CubeClusterPainter(
              colors: [
                McHue.green.color,
                McHue.indigo.color,
                McHue.amber.color,
                McHue.sky.color,
                McHue.violet.color,
                McHue.rose.color,
              ],
              seed: 7,
              count: 9,
            ),
          ),
        ),
      ],
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
    Widget tabs({bool compact = false}) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final a in McAudience.values)
            if (compact)
              Expanded(
                child: _AudienceTab(
                  audience: a,
                  selected: a == selected,
                  compact: true,
                  onTap: () => onSelect(a),
                ),
              )
            else
              _AudienceTab(
                audience: a,
                selected: a == selected,
                onTap: () => onSelect(a),
              ),
        ],
      ),
    );
    final field = SizedBox(
      width: context.isPhoneWidth ? double.infinity : 260,
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
              tabs(compact: true),
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
                child: tabs(),
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
    return Tooltip(
      message: audience.blurb(t),
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${audience.label(t)}, ${t.mcToolsCount(count)}',
        child: Material(
          color: selected ? luma.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            hoverColor: luma.surfaceHover,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    audience.icon,
                    size: 17,
                    color: selected ? luma.onAccent : luma.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      audience.label(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? luma.onAccent : luma.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!compact) const SizedBox(width: 8),
                  if (!compact) Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
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

/// One tool on the hub: a picture on top, the name in bold and a line of
/// what it does — the card Pugtools lists every tool with.
class McToolCard extends StatefulWidget {
  const McToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.showAudience = false,
  });

  final McTool tool;
  final VoidCallback onTap;
  final bool showAudience;

  @override
  State<McToolCard> createState() => _McToolCardState();
}

class _McToolCardState extends State<McToolCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final tool = widget.tool;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '${tool.title(t)}. ${tool.blurb(t)}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hover
                    ? tool.hue.color.withValues(alpha: 0.6)
                    : luma.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_hover ? tool.hue.color : Colors.black).withValues(
                    alpha: _hover ? 0.16 : (dark ? 0.12 : 0.04),
                  ),
                  blurRadius: _hover ? 22 : 12,
                  offset: Offset(0, _hover ? 8 : 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: AspectRatio(
                      aspectRatio: 16 / 8.5,
                      child: _CardArt(tool: tool, hover: _hover),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tool.title(t),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: _hover ? 1 : 0,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: tool.hue.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.blurb(t),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      if (widget.showAudience) ...[
                        const SizedBox(height: 8),
                        Text(
                          tool.group.audience.label(t),
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture on a tool card: a soft wash in the tool's hue, a scatter of
/// little blocks and the tool's icon on a raised tile.
class _CardArt extends StatelessWidget {
  const _CardArt({required this.tool, required this.hover});

  final McTool tool;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = tool.hue.color;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(luma.surface, hue, dark ? 0.16 : 0.10)!,
                Color.lerp(luma.surface, hue, dark ? 0.32 : 0.24)!,
              ],
            ),
          ),
        ),
        CustomPaint(
          painter: _CubeClusterPainter(
            colors: [hue, Color.lerp(hue, Colors.white, 0.35)!],
            seed: tool.index * 31 + 3,
            count: 6,
            opacity: dark ? 0.55 : 0.7,
            scatter: true,
          ),
        ),
        Positioned(
          left: 12,
          top: 10,
          child: McTag(tool.tagLabel(L.of(context)), hue: tool.hue),
        ),
        Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: hover ? 1.08 : 1,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: dark ? luma.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: hue.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(tool.icon, color: hue, size: 30),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws little isometric blocks: a cluster for the hero, or a loose scatter
/// behind a card's icon.
class _CubeClusterPainter extends CustomPainter {
  _CubeClusterPainter({
    required this.colors,
    required this.seed,
    required this.count,
    this.opacity = 1,
    this.scatter = false,
  });

  final List<Color> colors;
  final int seed;
  final int count;
  final double opacity;
  final bool scatter;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final cubes = <(Offset, double, Color)>[];
    if (scatter) {
      for (var i = 0; i < count; i++) {
        final s = 9 + rnd.nextDouble() * 12;
        // Keep the middle clear for the icon tile.
        var x = rnd.nextDouble() * size.width;
        if ((x - size.width / 2).abs() < 50) x += x < size.width / 2 ? -60 : 60;
        var y = 10 + rnd.nextDouble() * (size.height - 20);
        // Keep the top-left corner clear for the card's tag.
        if (x < 110 && y < 44) y += 44;
        cubes.add((Offset(x, y), s, colors[i % colors.length]));
      }
    } else {
      final s = size.height / 7;
      final origin = Offset(size.width / 2, size.height * 0.30);
      const layout = [
        (0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0), (2, 0, 0),
        (0, 0, 1), (1, 0, 1), (0, 1, 1), (0, 0, 2),
      ];
      for (var i = 0; i < math.min(count, layout.length); i++) {
        final (gx, gz, gy) = layout[i];
        final p = origin +
            Offset((gx - gz) * s * 0.87, (gx + gz) * s * 0.5 - gy * s);
        cubes.add((p, s, colors[(i + seed) % colors.length]));
      }
      cubes.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    }
    for (final (p, s, c) in cubes) {
      _cube(canvas, p, s, c);
    }
  }

  void _cube(Canvas canvas, Offset top, double s, Color color) {
    final w = s * 0.87;
    final h = s * 0.5;
    final topFace = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + w, top.dy + h)
      ..lineTo(top.dx, top.dy + 2 * h)
      ..lineTo(top.dx - w, top.dy + h)
      ..close();
    final left = Path()
      ..moveTo(top.dx - w, top.dy + h)
      ..lineTo(top.dx, top.dy + 2 * h)
      ..lineTo(top.dx, top.dy + 2 * h + s)
      ..lineTo(top.dx - w, top.dy + h + s)
      ..close();
    final right = Path()
      ..moveTo(top.dx + w, top.dy + h)
      ..lineTo(top.dx, top.dy + 2 * h)
      ..lineTo(top.dx, top.dy + 2 * h + s)
      ..lineTo(top.dx + w, top.dy + h + s)
      ..close();
    Paint fill(Color c) => Paint()..color = c.withValues(alpha: opacity);
    canvas.drawPath(topFace, fill(Color.lerp(color, Colors.white, 0.25)!));
    canvas.drawPath(left, fill(color));
    canvas.drawPath(right, fill(Color.lerp(color, Colors.black, 0.22)!));
  }

  @override
  bool shouldRepaint(_CubeClusterPainter old) =>
      old.seed != seed || old.colors != colors || old.opacity != opacity;
}

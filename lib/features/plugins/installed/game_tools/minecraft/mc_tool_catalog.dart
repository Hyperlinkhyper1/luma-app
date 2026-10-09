import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import 'ui/mc_style.dart';

/// Who a tool is for — the hub's three sub-tabs.
enum McAudience {
  players(Icons.person_rounded),
  admins(Icons.admin_panel_settings_rounded),
  developers(Icons.data_object_rounded);

  const McAudience(this.icon);
  final IconData icon;

  String label(L t) => switch (this) {
    McAudience.players => t.mcToolsAudiencePlayers,
    McAudience.admins => t.mcToolsAudienceAdmins,
    McAudience.developers => t.mcToolsAudienceDevelopers,
  };

  String blurb(L t) => switch (this) {
    McAudience.players => t.mcToolsAudiencePlayersBlurb,
    McAudience.admins => t.mcToolsAudienceAdminsBlurb,
    McAudience.developers => t.mcToolsAudienceDevelopersBlurb,
  };

  List<McToolGroup> get groups => [
    for (final g in McToolGroup.values)
      if (g.audience == this) g,
  ];

  List<McTool> get tools => [
    for (final tool in McTool.values)
      if (tool.group.audience == this) tool,
  ];
}

/// A heading on the hub, grouping related tools under one audience.
enum McToolGroup {
  build(McAudience.players),
  gear(McAudience.players),
  guides(McAudience.players),
  worlds(McAudience.admins),
  chat(McAudience.admins),
  gameplay(McAudience.admins),
  assets(McAudience.developers),
  datapacks(McAudience.developers);

  const McToolGroup(this.audience);
  final McAudience audience;

  String label(L t) => switch (this) {
    McToolGroup.build => t.mcToolsGroupBuild,
    McToolGroup.gear => t.mcToolsGroupGear,
    McToolGroup.guides => t.mcToolsGroupGuides,
    McToolGroup.worlds => t.mcToolsGroupWorlds,
    McToolGroup.chat => t.mcToolsGroupChat,
    McToolGroup.gameplay => t.mcToolsGroupGameplay,
    McToolGroup.assets => t.mcToolsGroupAssets,
    McToolGroup.datapacks => t.mcToolsGroupDatapacks,
  };

  List<McTool> get tools => [
    for (final tool in McTool.values)
      if (tool.group == this) tool,
  ];
}

/// Every Minecraft tool, in hub order.
enum McTool {
  shapeGenerator(McToolGroup.build, Icons.blur_circular_rounded, McHue.indigo, '3D'),
  buildPlanner(McToolGroup.build, Icons.view_in_ar_rounded, McHue.violet, '3D'),
  schematicOrganizer(McToolGroup.build, Icons.folder_special_rounded, McHue.sky, 'Files'),
  mapArtGenerator(McToolGroup.build, Icons.image_rounded, McHue.orange, 'Export'),
  roofGenerator(McToolGroup.build, Icons.roofing_rounded, McHue.rose, '3D'),
  skinEditor(McToolGroup.build, Icons.face_retouching_natural_rounded, McHue.mint, 'Paint'),
  enchantOptimizer(McToolGroup.gear, Icons.auto_fix_high_rounded, McHue.violet, 'Popular'),
  bannerMaker(McToolGroup.gear, Icons.flag_rounded, McHue.rose, 'Design'),
  shieldMaker(McToolGroup.gear, Icons.shield_rounded, McHue.sky, 'Design'),
  fireworkMaker(McToolGroup.gear, Icons.celebration_rounded, McHue.orange, 'Design'),
  armorDesigner(McToolGroup.gear, Icons.checkroom_rounded, McHue.amber, 'Design'),
  villagerGuide(McToolGroup.guides, Icons.storefront_rounded, McHue.green, 'Guide'),
  oreGuide(McToolGroup.guides, Icons.diamond_rounded, McHue.sky, 'Guide'),
  potionGuide(McToolGroup.guides, Icons.science_rounded, McHue.violet, 'Guide'),
  sulfurCubeGuide(McToolGroup.guides, Icons.check_box_outline_blank_rounded, McHue.amber, 'New'),
  beaconGuide(McToolGroup.guides, Icons.wb_iridescent_rounded, McHue.mint, 'Guide'),
  flatPreset(McToolGroup.worlds, Icons.layers_rounded, McHue.green, 'World'),
  customWorld(McToolGroup.worlds, Icons.terrain_rounded, McHue.mint, 'Datapack'),
  colorCodes(McToolGroup.chat, Icons.palette_rounded, McHue.rose, 'Text'),
  titleGenerator(McToolGroup.chat, Icons.title_rounded, McHue.indigo, 'Command'),
  tellrawGenerator(McToolGroup.chat, Icons.chat_rounded, McHue.sky, 'Command'),
  motdGenerator(McToolGroup.chat, Icons.dns_rounded, McHue.violet, 'Server'),
  lootTables(McToolGroup.gameplay, Icons.inventory_2_rounded, McHue.amber, 'JSON'),
  customPotions(McToolGroup.gameplay, Icons.local_drink_rounded, McHue.violet, 'Command'),
  commandGenerator(McToolGroup.gameplay, Icons.terminal_rounded, McHue.indigo, 'Command'),
  assetLibrary(McToolGroup.assets, Icons.photo_library_rounded, McHue.green, 'Browse'),
  recipeGenerator(McToolGroup.datapacks, Icons.grid_on_rounded, McHue.orange, 'JSON'),
  enchantmentGenerator(McToolGroup.datapacks, Icons.auto_awesome_rounded, McHue.violet, 'JSON'),
  advancementGenerator(McToolGroup.datapacks, Icons.emoji_events_rounded, McHue.amber, 'JSON');

  const McTool(this.group, this.icon, this.hue, this.tag);

  final McToolGroup group;
  final IconData icon;
  final McHue hue;

  /// The pill on the tool's card, shown through [tagLabel].
  final String tag;

  String tagLabel(L t) => switch (tag) {
    'Files' => t.mcTagFiles,
    'Export' => t.mcTagExport,
    'Paint' => t.mcTagPaint,
    'Popular' => t.mcTagPopular,
    'Design' => t.mcTagDesign,
    'Guide' => t.mcTagGuide,
    'New' => t.mcTagNew,
    'World' => t.mcTagWorld,
    'Datapack' => t.mcTagDatapack,
    'Text' => t.mcTagText,
    'Command' => t.mcTagCommand,
    'Server' => t.mcTagServer,
    'Browse' => t.mcTagBrowse,
    _ => tag,
  };

  String title(L t) => switch (this) {
    McTool.enchantOptimizer => t.mcToolEnchantOptimizer,
    McTool.shapeGenerator => t.mcToolShapeGenerator,
    McTool.skinEditor => t.mcToolSkinEditor,
    McTool.schematicOrganizer => t.mcToolSchematicOrganizer,
    McTool.villagerGuide => t.mcToolVillagerGuide,
    McTool.oreGuide => t.mcToolOreGuide,
    McTool.potionGuide => t.mcToolPotionGuide,
    McTool.sulfurCubeGuide => t.mcToolSulfurCubeGuide,
    McTool.beaconGuide => t.mcToolBeaconGuide,
    McTool.shieldMaker => t.mcToolShieldMaker,
    McTool.fireworkMaker => t.mcToolFireworkMaker,
    McTool.bannerMaker => t.mcToolBannerMaker,
    McTool.buildPlanner => t.mcToolBuildPlanner,
    McTool.mapArtGenerator => t.mcToolMapArtGenerator,
    McTool.roofGenerator => t.mcToolRoofGenerator,
    McTool.armorDesigner => t.mcToolArmorDesigner,
    McTool.flatPreset => t.mcToolFlatPreset,
    McTool.customWorld => t.mcToolCustomWorld,
    McTool.colorCodes => t.mcToolColorCodes,
    McTool.titleGenerator => t.mcToolTitleGenerator,
    McTool.tellrawGenerator => t.mcToolTellrawGenerator,
    McTool.motdGenerator => t.mcToolMotdGenerator,
    McTool.lootTables => t.mcToolLootTables,
    McTool.customPotions => t.mcToolCustomPotions,
    McTool.commandGenerator => t.mcToolCommandGenerator,
    McTool.assetLibrary => t.mcToolAssetLibrary,
    McTool.recipeGenerator => t.mcToolRecipeGenerator,
    McTool.enchantmentGenerator => t.mcToolEnchantmentGenerator,
    McTool.advancementGenerator => t.mcToolAdvancementGenerator,
  };

  String blurb(L t) => switch (this) {
    McTool.enchantOptimizer => t.mcToolEnchantOptimizerBlurb,
    McTool.shapeGenerator => t.mcToolShapeGeneratorBlurb,
    McTool.skinEditor => t.mcToolSkinEditorBlurb,
    McTool.schematicOrganizer => t.mcToolSchematicOrganizerBlurb,
    McTool.villagerGuide => t.mcToolVillagerGuideBlurb,
    McTool.oreGuide => t.mcToolOreGuideBlurb,
    McTool.potionGuide => t.mcToolPotionGuideBlurb,
    McTool.sulfurCubeGuide => t.mcToolSulfurCubeGuideBlurb,
    McTool.beaconGuide => t.mcToolBeaconGuideBlurb,
    McTool.shieldMaker => t.mcToolShieldMakerBlurb,
    McTool.fireworkMaker => t.mcToolFireworkMakerBlurb,
    McTool.bannerMaker => t.mcToolBannerMakerBlurb,
    McTool.buildPlanner => t.mcToolBuildPlannerBlurb,
    McTool.mapArtGenerator => t.mcToolMapArtGeneratorBlurb,
    McTool.roofGenerator => t.mcToolRoofGeneratorBlurb,
    McTool.armorDesigner => t.mcToolArmorDesignerBlurb,
    McTool.flatPreset => t.mcToolFlatPresetBlurb,
    McTool.customWorld => t.mcToolCustomWorldBlurb,
    McTool.colorCodes => t.mcToolColorCodesBlurb,
    McTool.titleGenerator => t.mcToolTitleGeneratorBlurb,
    McTool.tellrawGenerator => t.mcToolTellrawGeneratorBlurb,
    McTool.motdGenerator => t.mcToolMotdGeneratorBlurb,
    McTool.lootTables => t.mcToolLootTablesBlurb,
    McTool.customPotions => t.mcToolCustomPotionsBlurb,
    McTool.commandGenerator => t.mcToolCommandGeneratorBlurb,
    McTool.assetLibrary => t.mcToolAssetLibraryBlurb,
    McTool.recipeGenerator => t.mcToolRecipeGeneratorBlurb,
    McTool.enchantmentGenerator => t.mcToolEnchantmentGeneratorBlurb,
    McTool.advancementGenerator => t.mcToolAdvancementGeneratorBlurb,
  };

  /// Extra words a search should match besides the name and blurb.
  String get keywords => switch (this) {
    McTool.enchantOptimizer => 'anvil xp levels books combine',
    McTool.shapeGenerator => 'circle sphere dome cylinder arch curve ellipse torus cone pixel',
    McTool.skinEditor => 'skin paint png steve alex',
    McTool.schematicOrganizer => 'litematic schem nbt folder rename',
    McTool.villagerGuide => 'villager trade emerald librarian profession wandering trader',
    McTool.oreGuide => 'ore diamond iron gold y level mining',
    McTool.potionGuide => 'brewing potion recipe',
    McTool.sulfurCubeGuide => 'sulfur cube mob caves',
    McTool.beaconGuide => 'beacon pyramid range effects',
    McTool.shieldMaker => 'shield banner pattern',
    McTool.fireworkMaker => 'firework rocket star elytra',
    McTool.bannerMaker => 'banner loom pattern flag',
    McTool.buildPlanner => 'schematic litematic materials shopping list 3d viewer',
    McTool.mapArtGenerator => 'map art image pixel staircase',
    McTool.roofGenerator => 'roof stairs gable hip',
    McTool.armorDesigner => 'armor trim leather dye colour color',
    McTool.flatPreset => 'superflat flat world layers preset',
    McTool.customWorld => 'world preset datapack noise sea level biome',
    McTool.colorCodes => 'colour color codes section sign formatting',
    McTool.titleGenerator => 'title subtitle actionbar',
    McTool.tellrawGenerator => 'tellraw json text chat click hover',
    McTool.motdGenerator => 'motd server properties',
    McTool.lootTables => 'loot table chest drops datapack',
    McTool.customPotions => 'potion splash lingering tipped arrow effect give',
    McTool.commandGenerator => 'mcstacker give summon effect enchant tp teleport fill setblock',
    McTool.assetLibrary => 'textures images sounds blocks items mobs',
    McTool.recipeGenerator => 'recipe crafting smelting datapack',
    McTool.enchantmentGenerator => 'enchantment datapack custom',
    McTool.advancementGenerator => 'advancement achievement datapack',
  };

  bool matches(L t, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = '${title(t)} ${blurb(t)} $keywords'.toLowerCase();
    return q.split(RegExp(r'\s+')).every(haystack.contains);
  }
}

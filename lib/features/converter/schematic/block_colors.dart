import 'dart:ui';

import 'schematic_model.dart';

/// Approximate top-face colours for rendering a build without shipping the
/// game's textures.
///
/// Named blocks come from the table; the dyed families are derived from the
/// dye palette so all sixteen variants of wool, concrete, glass and terracotta
/// are covered without sixty-four more table rows. Anything still unknown gets
/// a colour derived from its name, which keeps distinct blocks visually
/// distinct instead of collapsing them all onto one placeholder grey.
class BlockColors {
  const BlockColors._();

  /// Minecraft's sixteen dye colours.
  static const Map<String, int> _dyes = {
    'white': 0xFFF9FFFE,
    'orange': 0xFFF9801D,
    'magenta': 0xFFC74EBD,
    'light_blue': 0xFF3AB3DA,
    'yellow': 0xFFFED83D,
    'lime': 0xFF80C71F,
    'pink': 0xFFF38BAA,
    'gray': 0xFF474F52,
    'light_gray': 0xFF9D9D97,
    'cyan': 0xFF169C9C,
    'purple': 0xFF8932B8,
    'blue': 0xFF3C44AA,
    'brown': 0xFF835432,
    'green': 0xFF5E7C16,
    'red': 0xFFB02E26,
    'black': 0xFF1D1D21,
  };

  static const Map<String, int> _table = {
    'stone': 0xFF7E7E7E,
    'smooth_stone': 0xFF9E9E9E,
    'cobblestone': 0xFF7A7A7A,
    'mossy_cobblestone': 0xFF6C7A5B,
    'granite': 0xFF9A6A5B,
    'polished_granite': 0xFFA5705E,
    'diorite': 0xFFBDBDBD,
    'polished_diorite': 0xFFC7C7C1,
    'andesite': 0xFF888888,
    'polished_andesite': 0xFF969996,
    'deepslate': 0xFF515154,
    'cobbled_deepslate': 0xFF4E4E52,
    'tuff': 0xFF6C6E63,
    'calcite': 0xFFDFDEDA,
    'dripstone_block': 0xFF876B5F,
    'dirt': 0xFF866043,
    'coarse_dirt': 0xFF7A5637,
    'rooted_dirt': 0xFF90674C,
    'podzol': 0xFF6B4A2B,
    'mud': 0xFF3C3A3E,
    'grass_block': 0xFF7FB238,
    'mycelium': 0xFF6F6265,
    'dirt_path': 0xFF97814D,
    'farmland': 0xFF5A3B21,
    'sand': 0xFFDBD3A0,
    'red_sand': 0xFFBE6B2F,
    'gravel': 0xFF837E7C,
    'clay': 0xFF9FA5B1,
    'bedrock': 0xFF565656,
    'water': 0xFF3F76E4,
    'lava': 0xFFE25822,
    'ice': 0xFF7DADFF,
    'packed_ice': 0xFF8DB4FB,
    'blue_ice': 0xFF74A8FB,
    'snow': 0xFFF0FBFB,
    'snow_block': 0xFFF0FBFB,
    'powder_snow': 0xFFF7FCFC,
    'obsidian': 0xFF15121D,
    'crying_obsidian': 0xFF25074F,
    'netherrack': 0xFF6D3230,
    'soul_sand': 0xFF503A2E,
    'soul_soil': 0xFF4B3A30,
    'magma_block': 0xFF8E3B1B,
    'glowstone': 0xFFF9D49C,
    'sea_lantern': 0xFFACC7BE,
    'shroomlight': 0xFFF0764B,
    'end_stone': 0xFFDDE0A0,
    'end_stone_bricks': 0xFFDBE0A6,
    'purpur_block': 0xFFA97BA9,
    'purpur_pillar': 0xFFAE81AE,
    'coal_ore': 0xFF6E6E6E,
    'iron_ore': 0xFF9A8A7E,
    'copper_ore': 0xFF8B7B63,
    'gold_ore': 0xFF9C8B62,
    'redstone_ore': 0xFF8E6E6E,
    'lapis_ore': 0xFF6A7B8E,
    'diamond_ore': 0xFF6E8E8B,
    'emerald_ore': 0xFF6E8E76,
    'nether_quartz_ore': 0xFF7C4A46,
    'ancient_debris': 0xFF5C4438,
    'coal_block': 0xFF191919,
    'iron_block': 0xFFE0E0E0,
    'copper_block': 0xFFC06D51,
    'gold_block': 0xFFFAEE4D,
    'diamond_block': 0xFF62DBD5,
    'emerald_block': 0xFF4AEC7D,
    'lapis_block': 0xFF1D47A5,
    'redstone_block': 0xFFAA1D0F,
    'netherite_block': 0xFF443A3B,
    'quartz_block': 0xFFECE9E2,
    'smooth_quartz': 0xFFEDE9E2,
    'quartz_pillar': 0xFFEBE7DE,
    'chiseled_quartz_block': 0xFFE9E5DC,
    'amethyst_block': 0xFF8663CB,
    'bricks': 0xFF96604A,
    'stone_bricks': 0xFF7A7A7A,
    'mossy_stone_bricks': 0xFF74796A,
    'cracked_stone_bricks': 0xFF767671,
    'chiseled_stone_bricks': 0xFF787878,
    'deepslate_bricks': 0xFF474749,
    'deepslate_tiles': 0xFF373739,
    'nether_bricks': 0xFF2C171B,
    'red_nether_bricks': 0xFF460A0F,
    'nether_wart_block': 0xFF721114,
    'warped_wart_block': 0xFF167A70,
    'sandstone': 0xFFE0D6A5,
    'smooth_sandstone': 0xFFE2D8A8,
    'chiseled_sandstone': 0xFFDDD3A0,
    'cut_sandstone': 0xFFDFD5A3,
    'red_sandstone': 0xFFBE6E32,
    'smooth_red_sandstone': 0xFFC07135,
    'terracotta': 0xFF985E44,
    'prismarine': 0xFF639C97,
    'prismarine_bricks': 0xFF63AC9F,
    'dark_prismarine': 0xFF325B52,
    'bone_block': 0xFFE5E2D5,
    'hay_block': 0xFFA68C1C,
    'melon': 0xFF6E9A32,
    'pumpkin': 0xFFC07615,
    'carved_pumpkin': 0xFFC07615,
    'jack_o_lantern': 0xFFCE8B26,
    'sponge': 0xFFC3C233,
    'wet_sponge': 0xFFA8AE2E,
    'slime_block': 0xFF6FC05A,
    'honey_block': 0xFFFBB934,
    'bookshelf': 0xFFA0814F,
    'crafting_table': 0xFF7B4B2A,
    'furnace': 0xFF6D6D6D,
    'chest': 0xFF9B6E2E,
    'barrel': 0xFF87613A,
    'tnt': 0xFFA33F30,
    'glass': 0xFFC0F5FE,
    'glass_pane': 0xFFC0F5FE,
    'tinted_glass': 0xFF35313A,
    'glowstone_dust': 0xFFF9D49C,
    'cobweb': 0xFFDCE4E4,
    'vine': 0xFF3B6E22,
    'lily_pad': 0xFF20821F,
    'cactus': 0xFF58822B,
    'sugar_cane': 0xFF97BD6C,
    'bamboo': 0xFF7A9A2B,
    'moss_block': 0xFF596E30,
    'sculk': 0xFF0E1A20,
    'crimson_nylium': 0xFF7B0E0E,
    'warped_nylium': 0xFF2B7169,
    'crimson_planks': 0xFF6A344B,
    'warped_planks': 0xFF2B6C62,
    'crimson_stem': 0xFF6A344B,
    'warped_stem': 0xFF3A5250,
    'oak_planks': 0xFFB08B50,
    'spruce_planks': 0xFF785A34,
    'birch_planks': 0xFFD6C58B,
    'jungle_planks': 0xFFB07A54,
    'acacia_planks': 0xFFBA6538,
    'dark_oak_planks': 0xFF48311A,
    'mangrove_planks': 0xFF773A33,
    'cherry_planks': 0xFFE3B5A8,
    'bamboo_planks': 0xFFC5A94A,
    'oak_log': 0xFF9C7B4E,
    'spruce_log': 0xFF6B5433,
    'birch_log': 0xFFCFCBA5,
    'jungle_log': 0xFF9A7050,
    'acacia_log': 0xFF9A6244,
    'dark_oak_log': 0xFF3B2812,
    'mangrove_log': 0xFF6A3B32,
    'cherry_log': 0xFF56303F,
    'oak_leaves': 0xFF48B518,
    'spruce_leaves': 0xFF4A7A4A,
    'birch_leaves': 0xFF80A755,
    'jungle_leaves': 0xFF30BB0F,
    'acacia_leaves': 0xFF6B9F35,
    'dark_oak_leaves': 0xFF3F8F1E,
    'mangrove_leaves': 0xFF3F8F35,
    'cherry_leaves': 0xFFF0B8CE,
    'azalea_leaves': 0xFF5E8B36,
    'torch': 0xFFFFD966,
    'wall_torch': 0xFFFFD966,
    'lantern': 0xFFEDB35A,
    'campfire': 0xFFD87B2A,
    'redstone_lamp': 0xFF8A5E33,
    'note_block': 0xFF67432B,
    'jukebox': 0xFF6A4632,
    'iron_bars': 0xFFB6B6B6,
    'anvil': 0xFF4A4A4A,
    'cauldron': 0xFF4A4A4A,
    'beacon': 0xFF7BE0DA,
    'spawner': 0xFF25383F,
    'ladder': 0xFFA1804D,
    'scaffolding': 0xFFC0A15C,
    'rail': 0xFF9C8A6B,
    'barrier': 0xFFD01A1A,
    'structure_block': 0xFF5B4B5F,
    'command_block': 0xFFB98A5A,
  };

  /// Suffix families whose colour is derived from the dye in the block name.
  /// The value is how much the dye is tinted towards the family's own base.
  static const Map<String, (double, int)> _dyedFamilies = {
    '_wool': (0.0, 0),
    '_carpet': (0.0, 0),
    '_concrete': (0.12, 0xFF000000),
    '_concrete_powder': (0.18, 0xFFFFFFFF),
    '_stained_glass': (0.0, 0),
    '_stained_glass_pane': (0.0, 0),
    '_terracotta': (0.45, 0xFF985E44),
    '_glazed_terracotta': (0.30, 0xFF985E44),
    '_shulker_box': (0.20, 0xFF000000),
    '_bed': (0.10, 0xFF000000),
    '_banner': (0.0, 0),
    '_candle': (0.0, 0),
  };

  /// Blocks you should be able to see through in the viewer.
  static const Set<String> _translucent = {
    'water',
    'glass',
    'glass_pane',
    'ice',
    'tinted_glass',
    'slime_block',
    'honey_block',
    'barrier',
    'nether_portal',
  };

  /// The rendering colour for a block state, alpha included.
  static Color of(BlockState state) {
    final name = state.shortName;

    final exact = _table[name];
    if (exact != null) return Color(_withAlpha(exact, name));

    for (final entry in _dyedFamilies.entries) {
      if (!name.endsWith(entry.key)) continue;
      final dye = _dyes[name.substring(0, name.length - entry.key.length)];
      if (dye == null) continue;
      final (mix, towards) = entry.value;
      final blended = mix == 0 ? dye : _blend(dye, towards, mix);
      return Color(_withAlpha(blended, name));
    }

    // Families that share a base block: a stair, slab or wall is the colour of
    // whatever it is made of.
    for (final suffix in const [
      '_stairs',
      '_slab',
      '_wall',
      '_fence',
      '_fence_gate',
      '_door',
      '_trapdoor',
      '_button',
      '_pressure_plate',
      '_sign',
      '_wall_sign',
      '_pillar',
      '_bricks',
      '_brick',
    ]) {
      if (!name.endsWith(suffix)) continue;
      final base = name.substring(0, name.length - suffix.length);
      final parent = _table[base] ??
          _table['${base}_planks'] ??
          _table['${base}_block'] ??
          _table['${base}s'];
      if (parent != null) return Color(_withAlpha(parent, name));
    }

    return Color(_fallback(name));
  }

  static int _withAlpha(int argb, String name) =>
      _translucent.contains(name) ? (argb & 0x00FFFFFF) | 0xB0000000 : argb;

  static int _blend(int a, int b, double t) {
    int channel(int shift) {
      final av = (a >> shift) & 0xFF;
      final bv = (b >> shift) & 0xFF;
      return (av + (bv - av) * t).round().clamp(0, 255);
    }

    return 0xFF000000 |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }

  /// A stable, muted colour derived from the block name, so two unknown
  /// blocks never look like the same block.
  ///
  /// The saturation and lightness stay in a narrow band so these sit visually
  /// alongside the hand-picked colours instead of glowing next to them.
  static int _fallback(String name) {
    var hash = 0x811C9DC5;
    for (var i = 0; i < name.length; i++) {
      hash ^= name.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final hue = (hash % 360) / 60.0;
    final saturation = 0.28 + ((hash >> 9) % 22) / 100;
    final lightness = 0.42 + ((hash >> 17) % 24) / 100;

    final c = (1 - (2 * lightness - 1).abs()) * saturation;
    final x = c * (1 - ((hue % 2) - 1).abs());
    final m = lightness - c / 2;
    final (r, g, b) = switch (hue.floor()) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    int channel(double v) => ((v + m) * 255).round().clamp(0, 255);
    return 0xFF000000 |
        (channel(r) << 16) |
        (channel(g) << 8) |
        channel(b);
  }
}

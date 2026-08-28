import 'schematic_model.dart';

/// Translation between the pre-1.13 numeric `(id, data)` pairs that MCEdit
/// `.schematic` files store and modern namespaced block states.
///
/// The mapping is written once, forwards. [toLegacy] inverts that same
/// function at first use rather than repeating the table backwards, so the
/// two directions cannot drift apart.
class LegacyBlocks {
  const LegacyBlocks._();

  static const List<String> _colors = [
    'white',
    'orange',
    'magenta',
    'light_blue',
    'yellow',
    'lime',
    'pink',
    'gray',
    'light_gray',
    'cyan',
    'purple',
    'blue',
    'brown',
    'green',
    'red',
    'black',
  ];

  static const List<String> _woods = [
    'oak',
    'spruce',
    'birch',
    'jungle',
    'acacia',
    'dark_oak',
  ];

  /// Legacy stair/ladder/torch facing order: east, west, south, north.
  static const List<String> _stairFacing = ['east', 'west', 'south', 'north'];

  static BlockState _b(String name, [Map<String, String>? props]) =>
      BlockState('minecraft:$name', props);

  static BlockState _stairs(String kind, int meta) => _b(
        '${kind}_stairs',
        {
          'facing': _stairFacing[meta & 3],
          'half': (meta & 4) != 0 ? 'top' : 'bottom',
        },
      );

  static BlockState _slab(String kind, int meta) => _b(
        '${kind}_slab',
        {'type': (meta & 8) != 0 ? 'top' : 'bottom'},
      );

  static BlockState _doubleSlab(String kind) =>
      _b('${kind}_slab', {'type': 'double'});

  static BlockState _log(String wood, int meta) {
    final orientation = (meta >> 2) & 3;
    // Orientation 3 is "bark on all six sides", which became its own block.
    if (orientation == 3) return _b('${wood}_wood', {'axis': 'y'});
    const axes = ['y', 'x', 'z'];
    return _b('${wood}_log', {'axis': axes[orientation]});
  }

  static BlockState _door(String wood, int meta) {
    // The top half stores the hinge side, the bottom half stores facing.
    if ((meta & 8) != 0) {
      return _b('${wood}_door', {
        'half': 'upper',
        'hinge': (meta & 1) != 0 ? 'right' : 'left',
      });
    }
    return _b('${wood}_door', {
      'half': 'lower',
      'facing': _stairFacing[(meta + 3) & 3],
      'open': (meta & 4) != 0 ? 'true' : 'false',
    });
  }

  /// Maps a legacy `(id, data)` pair to a modern block state, or null when the
  /// id is not one this table knows.
  static BlockState? fromLegacy(int id, int data) {
    final meta = data & 15;
    switch (id) {
      case 0:
        return BlockState.air;
      case 1:
        const kinds = [
          'stone',
          'granite',
          'polished_granite',
          'diorite',
          'polished_diorite',
          'andesite',
          'polished_andesite',
        ];
        return _b(meta < kinds.length ? kinds[meta] : 'stone');
      case 2:
        return _b('grass_block', {'snowy': 'false'});
      case 3:
        return _b(const ['dirt', 'coarse_dirt', 'podzol'][meta.clamp(0, 2)]);
      case 4:
        return _b('cobblestone');
      case 5:
        return _b('${_woods[meta.clamp(0, 5)]}_planks');
      case 6:
        return _b('${_woods[(meta & 7) > 5 ? 0 : (meta & 7)]}_sapling');
      case 7:
        return _b('bedrock');
      case 8:
      case 9:
        return _b('water', {'level': '${meta.clamp(0, 15)}'});
      case 10:
      case 11:
        return _b('lava', {'level': '${meta.clamp(0, 15)}'});
      case 12:
        return _b(meta == 1 ? 'red_sand' : 'sand');
      case 13:
        return _b('gravel');
      case 14:
        return _b('gold_ore');
      case 15:
        return _b('iron_ore');
      case 16:
        return _b('coal_ore');
      case 17:
        return _log(_woods[meta & 3], meta);
      case 18:
        return _b('${_woods[meta & 3]}_leaves', {'persistent': 'false'});
      case 19:
        return _b(meta == 1 ? 'wet_sponge' : 'sponge');
      case 20:
        return _b('glass');
      case 21:
        return _b('lapis_ore');
      case 22:
        return _b('lapis_block');
      case 23:
        return _b('dispenser', {'facing': _facing6(meta & 7)});
      case 24:
        return _b(const [
          'sandstone',
          'chiseled_sandstone',
          'cut_sandstone',
        ][meta.clamp(0, 2)]);
      case 25:
        return _b('note_block');
      case 26:
        return _b('red_bed', {'facing': _stairFacing[(meta + 3) & 3]});
      case 27:
        return _b('powered_rail');
      case 28:
        return _b('detector_rail');
      case 29:
        return _b('sticky_piston', {'facing': _facing6(meta & 7)});
      case 30:
        return _b('cobweb');
      case 31:
        return _b(const ['dead_bush', 'short_grass', 'fern'][meta.clamp(0, 2)]);
      case 32:
        return _b('dead_bush');
      case 33:
        return _b('piston', {'facing': _facing6(meta & 7)});
      case 34:
        return _b('piston_head', {'facing': _facing6(meta & 7)});
      case 35:
        return _b('${_colors[meta]}_wool');
      case 37:
        return _b('dandelion');
      case 38:
        const flowers = [
          'poppy',
          'blue_orchid',
          'allium',
          'azure_bluet',
          'red_tulip',
          'orange_tulip',
          'white_tulip',
          'pink_tulip',
          'oxeye_daisy',
        ];
        return _b(meta < flowers.length ? flowers[meta] : 'poppy');
      case 39:
        return _b('brown_mushroom');
      case 40:
        return _b('red_mushroom');
      case 41:
        return _b('gold_block');
      case 42:
        return _b('iron_block');
      case 43:
        const kinds = [
          'smooth_stone',
          'sandstone',
          'petrified_oak',
          'cobblestone',
          'brick',
          'stone_brick',
          'nether_brick',
          'quartz',
        ];
        return _doubleSlab(kinds[meta & 7]);
      case 44:
        const kinds = [
          'smooth_stone',
          'sandstone',
          'petrified_oak',
          'cobblestone',
          'brick',
          'stone_brick',
          'nether_brick',
          'quartz',
        ];
        return _slab(kinds[meta & 7], meta);
      case 45:
        return _b('bricks');
      case 46:
        return _b('tnt');
      case 47:
        return _b('bookshelf');
      case 48:
        return _b('mossy_cobblestone');
      case 49:
        return _b('obsidian');
      case 50:
        if (meta >= 1 && meta <= 4) {
          return _b('wall_torch', {'facing': _stairFacing[meta - 1]});
        }
        return _b('torch');
      case 51:
        return _b('fire');
      case 52:
        return _b('spawner');
      case 53:
        return _stairs('oak', meta);
      case 54:
        return _b('chest', {'facing': _facing6(meta & 7)});
      case 55:
        return _b('redstone_wire');
      case 56:
        return _b('diamond_ore');
      case 57:
        return _b('diamond_block');
      case 58:
        return _b('crafting_table');
      case 59:
        return _b('wheat', {'age': '$meta'});
      case 60:
        return _b('farmland', {'moisture': '${meta.clamp(0, 7)}'});
      case 61:
      case 62:
        return _b('furnace', {
          'facing': _facing6(meta & 7),
          'lit': id == 62 ? 'true' : 'false',
        });
      case 63:
        return _b('oak_sign', {'rotation': '$meta'});
      case 64:
        return _door('oak', meta);
      case 65:
        return _b('ladder', {'facing': _facing6(meta & 7)});
      case 66:
        return _b('rail', {'shape': _railShape(meta)});
      case 67:
        return _stairs('cobblestone', meta);
      case 68:
        return _b('oak_wall_sign', {'facing': _facing6(meta & 7)});
      case 69:
        return _b('lever');
      case 70:
        return _b('stone_pressure_plate');
      case 71:
        return _door('iron', meta);
      case 72:
        return _b('oak_pressure_plate');
      case 73:
      case 74:
        return _b('redstone_ore', {'lit': id == 74 ? 'true' : 'false'});
      case 75:
      case 76:
        final lit = id == 76 ? 'true' : 'false';
        if (meta >= 1 && meta <= 4) {
          return _b('redstone_wall_torch', {
            'facing': _stairFacing[meta - 1],
            'lit': lit,
          });
        }
        return _b('redstone_torch', {'lit': lit});
      case 77:
        return _b('stone_button');
      case 78:
        return _b('snow', {'layers': '${(meta & 7) + 1}'});
      case 79:
        return _b('ice');
      case 80:
        return _b('snow_block');
      case 81:
        return _b('cactus');
      case 82:
        return _b('clay');
      case 83:
        return _b('sugar_cane');
      case 84:
        return _b('jukebox');
      case 85:
        return _b('oak_fence');
      case 86:
        return _b('carved_pumpkin', {'facing': _stairFacing[(meta + 3) & 3]});
      case 87:
        return _b('netherrack');
      case 88:
        return _b('soul_sand');
      case 89:
        return _b('glowstone');
      case 90:
        return _b('nether_portal');
      case 91:
        return _b('jack_o_lantern', {'facing': _stairFacing[(meta + 3) & 3]});
      case 92:
        return _b('cake');
      case 93:
      case 94:
        return _b('repeater', {
          'facing': _stairFacing[(meta + 3) & 3],
          'delay': '${((meta >> 2) & 3) + 1}',
          'powered': id == 94 ? 'true' : 'false',
        });
      case 95:
        return _b('${_colors[meta]}_stained_glass');
      case 96:
        return _b('oak_trapdoor', {
          'facing': _stairFacing[(meta & 3) ^ 1],
          'half': (meta & 8) != 0 ? 'top' : 'bottom',
          'open': (meta & 4) != 0 ? 'true' : 'false',
        });
      case 97:
        return _b('infested_stone');
      case 98:
        return _b(const [
          'stone_bricks',
          'mossy_stone_bricks',
          'cracked_stone_bricks',
          'chiseled_stone_bricks',
        ][meta.clamp(0, 3)]);
      case 99:
        return _b('brown_mushroom_block');
      case 100:
        return _b('red_mushroom_block');
      case 101:
        return _b('iron_bars');
      case 102:
        return _b('glass_pane');
      case 103:
        return _b('melon');
      case 104:
        return _b('pumpkin_stem');
      case 105:
        return _b('melon_stem');
      case 106:
        return _b('vine');
      case 107:
        return _b('oak_fence_gate', {
          'facing': _stairFacing[(meta + 3) & 3],
          'open': (meta & 4) != 0 ? 'true' : 'false',
        });
      case 108:
        return _stairs('brick', meta);
      case 109:
        return _stairs('stone_brick', meta);
      case 110:
        return _b('mycelium');
      case 111:
        return _b('lily_pad');
      case 112:
        return _b('nether_bricks');
      case 113:
        return _b('nether_brick_fence');
      case 114:
        return _stairs('nether_brick', meta);
      case 115:
        return _b('nether_wart', {'age': '${meta.clamp(0, 3)}'});
      case 116:
        return _b('enchanting_table');
      case 117:
        return _b('brewing_stand');
      case 118:
        return _b('cauldron');
      case 119:
        return _b('end_portal');
      case 120:
        return _b('end_portal_frame', {
          'facing': _stairFacing[(meta + 3) & 3],
          'eye': (meta & 4) != 0 ? 'true' : 'false',
        });
      case 121:
        return _b('end_stone');
      case 122:
        return _b('dragon_egg');
      case 123:
      case 124:
        return _b('redstone_lamp', {'lit': id == 124 ? 'true' : 'false'});
      case 125:
        return _doubleSlab(_woods[(meta & 7) > 5 ? 0 : (meta & 7)]);
      case 126:
        return _slab(_woods[(meta & 7) > 5 ? 0 : (meta & 7)], meta);
      case 127:
        return _b('cocoa', {'facing': _stairFacing[(meta + 3) & 3]});
      case 128:
        return _stairs('sandstone', meta);
      case 129:
        return _b('emerald_ore');
      case 130:
        return _b('ender_chest', {'facing': _facing6(meta & 7)});
      case 131:
        return _b('tripwire_hook');
      case 132:
        return _b('tripwire');
      case 133:
        return _b('emerald_block');
      case 134:
        return _stairs('spruce', meta);
      case 135:
        return _stairs('birch', meta);
      case 136:
        return _stairs('jungle', meta);
      case 137:
        return _b('command_block');
      case 138:
        return _b('beacon');
      case 139:
        return _b(meta == 1 ? 'mossy_cobblestone_wall' : 'cobblestone_wall');
      case 140:
        return _b('flower_pot');
      case 141:
        return _b('carrots', {'age': '${meta.clamp(0, 7)}'});
      case 142:
        return _b('potatoes', {'age': '${meta.clamp(0, 7)}'});
      case 143:
        return _b('oak_button');
      case 144:
        return _b('skeleton_skull');
      case 145:
        return _b('anvil');
      case 146:
        return _b('trapped_chest', {'facing': _facing6(meta & 7)});
      case 147:
        return _b('light_weighted_pressure_plate');
      case 148:
        return _b('heavy_weighted_pressure_plate');
      case 149:
      case 150:
        return _b('comparator', {'facing': _stairFacing[(meta + 3) & 3]});
      case 151:
        return _b('daylight_detector', {'inverted': 'false'});
      case 152:
        return _b('redstone_block');
      case 153:
        return _b('nether_quartz_ore');
      case 154:
        return _b('hopper', {'facing': _facing6(meta & 7)});
      case 155:
        if (meta == 1) return _b('chiseled_quartz_block');
        if (meta >= 2) {
          const axes = ['y', 'x', 'z'];
          return _b('quartz_pillar', {'axis': axes[(meta - 2).clamp(0, 2)]});
        }
        return _b('quartz_block');
      case 156:
        return _stairs('quartz', meta);
      case 157:
        return _b('activator_rail');
      case 158:
        return _b('dropper', {'facing': _facing6(meta & 7)});
      case 159:
        return _b('${_colors[meta]}_terracotta');
      case 160:
        return _b('${_colors[meta]}_stained_glass_pane');
      case 161:
        return _b('${_woods[4 + (meta & 1)]}_leaves', {'persistent': 'false'});
      case 162:
        return _log(_woods[4 + (meta & 1)], meta);
      case 163:
        return _stairs('acacia', meta);
      case 164:
        return _stairs('dark_oak', meta);
      case 165:
        return _b('slime_block');
      case 166:
        return _b('barrier');
      case 167:
        return _b('iron_trapdoor', {
          'facing': _stairFacing[(meta & 3) ^ 1],
          'half': (meta & 8) != 0 ? 'top' : 'bottom',
          'open': (meta & 4) != 0 ? 'true' : 'false',
        });
      case 168:
        return _b(const [
          'prismarine',
          'prismarine_bricks',
          'dark_prismarine',
        ][meta.clamp(0, 2)]);
      case 169:
        return _b('sea_lantern');
      case 170:
        const axes = ['y', 'x', 'z'];
        return _b('hay_block', {'axis': axes[((meta >> 2) & 3).clamp(0, 2)]});
      case 171:
        return _b('${_colors[meta]}_carpet');
      case 172:
        return _b('terracotta');
      case 173:
        return _b('coal_block');
      case 174:
        return _b('packed_ice');
      case 175:
        const tall = [
          'sunflower',
          'lilac',
          'tall_grass',
          'large_fern',
          'rose_bush',
          'peony',
        ];
        return _b(
          tall[(meta & 7).clamp(0, 5)],
          {'half': (meta & 8) != 0 ? 'upper' : 'lower'},
        );
      case 176:
        return _b('white_banner', {'rotation': '$meta'});
      case 177:
        return _b('white_wall_banner', {'facing': _facing6(meta & 7)});
      case 178:
        return _b('daylight_detector', {'inverted': 'true'});
      case 179:
        return _b(const [
          'red_sandstone',
          'chiseled_red_sandstone',
          'cut_red_sandstone',
        ][meta.clamp(0, 2)]);
      case 180:
        return _stairs('red_sandstone', meta);
      case 181:
        return _doubleSlab('red_sandstone');
      case 182:
        return _slab('red_sandstone', meta);
      case 183:
        return _b('spruce_fence_gate', {
          'facing': _stairFacing[(meta + 3) & 3],
        });
      case 184:
        return _b('birch_fence_gate', {'facing': _stairFacing[(meta + 3) & 3]});
      case 185:
        return _b('jungle_fence_gate', {
          'facing': _stairFacing[(meta + 3) & 3],
        });
      case 186:
        return _b('dark_oak_fence_gate', {
          'facing': _stairFacing[(meta + 3) & 3],
        });
      case 187:
        return _b('acacia_fence_gate', {
          'facing': _stairFacing[(meta + 3) & 3],
        });
      case 188:
        return _b('spruce_fence');
      case 189:
        return _b('birch_fence');
      case 190:
        return _b('jungle_fence');
      case 191:
        return _b('dark_oak_fence');
      case 192:
        return _b('acacia_fence');
      case 193:
        return _door('spruce', meta);
      case 194:
        return _door('birch', meta);
      case 195:
        return _door('jungle', meta);
      case 196:
        return _door('acacia', meta);
      case 197:
        return _door('dark_oak', meta);
      case 198:
        return _b('end_rod', {'facing': _facing6(meta & 7)});
      case 199:
        return _b('chorus_plant');
      case 200:
        return _b('chorus_flower', {'age': '${meta.clamp(0, 5)}'});
      case 201:
        return _b('purpur_block');
      case 202:
        const pillarAxes = ['y', 'x', 'z'];
        return _b(
          'purpur_pillar',
          {'axis': pillarAxes[((meta >> 2) & 3).clamp(0, 2)]},
        );
      case 203:
        return _stairs('purpur', meta);
      case 204:
        return _doubleSlab('purpur');
      case 205:
        return _slab('purpur', meta);
      case 206:
        return _b('end_stone_bricks');
      case 207:
        return _b('beetroots', {'age': '${meta.clamp(0, 3)}'});
      case 208:
        return _b('dirt_path');
      case 209:
        return _b('end_gateway');
      case 210:
        return _b('repeating_command_block');
      case 211:
        return _b('chain_command_block');
      case 212:
        return _b('frosted_ice');
      case 213:
        return _b('magma_block');
      case 214:
        return _b('nether_wart_block');
      case 215:
        return _b('red_nether_bricks');
      case 216:
        const boneAxes = ['y', 'x', 'z'];
        return _b(
          'bone_block',
          {'axis': boneAxes[((meta >> 2) & 3).clamp(0, 2)]},
        );
      case 217:
        return _b('structure_void');
      case 218:
        return _b('observer', {'facing': _facing6(meta & 7)});
      case 255:
        return _b('structure_block');
      default:
        if (id >= 219 && id <= 234) {
          return _b('${_colors[id - 219]}_shulker_box');
        }
        if (id >= 235 && id <= 250) {
          return _b('${_colors[id - 235]}_glazed_terracotta', {
            'facing': _stairFacing[(meta + 3) & 3],
          });
        }
        if (id == 251) return _b('${_colors[meta]}_concrete');
        if (id == 252) return _b('${_colors[meta]}_concrete_powder');
        return null;
    }
  }

  /// Legacy 6-way facing order: down, up, north, south, west, east.
  static String _facing6(int meta) => const [
        'down',
        'up',
        'north',
        'south',
        'west',
        'east',
      ][meta.clamp(0, 5)];

  static String _railShape(int meta) => const [
        'north_south',
        'east_west',
        'ascending_east',
        'ascending_west',
        'ascending_north',
        'ascending_south',
        'south_east',
        'south_west',
        'north_west',
        'north_east',
      ][meta.clamp(0, 9)];

  /// Reverse lookup, built by walking [fromLegacy] over the whole `(id, data)`
  /// space once. Keyed both by the full state string and — as a fallback for
  /// states whose properties do not round-trip — by bare block name.
  static Map<String, int>? _reverseExact;
  static Map<String, int>? _reverseByName;

  static void _buildReverse() {
    final exact = <String, int>{};
    final byName = <String, int>{};
    for (var id = 0; id <= 255; id++) {
      for (var data = 0; data <= 15; data++) {
        final BlockState? state;
        try {
          state = fromLegacy(id, data);
        } catch (_) {
          continue;
        }
        if (state == null) continue;
        final packed = (id << 4) | data;
        exact.putIfAbsent(state.toStateString(), () => packed);
        byName.putIfAbsent(state.name, () => packed);
      }
    }
    _reverseExact = exact;
    _reverseByName = byName;
  }

  /// Maps a modern block state back to a legacy `(id, data)` pair, or null when
  /// the block did not exist before the flattening.
  ///
  /// [exact] reports whether the block-state properties survived; when false
  /// the block itself matched but its orientation or variant was dropped.
  static ({int id, int data, bool exact})? toLegacy(BlockState state) {
    if (_reverseExact == null) _buildReverse();
    final packed = _reverseExact![state.toStateString()];
    if (packed != null) {
      return (id: packed >> 4, data: packed & 15, exact: true);
    }
    final byName = _reverseByName![state.name];
    if (byName != null) {
      return (id: byName >> 4, data: byName & 15, exact: false);
    }
    return null;
  }
}

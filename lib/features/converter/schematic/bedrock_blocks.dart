import 'schematic_model.dart';

/// Translation between Java Edition block states and Bedrock Edition ones.
///
/// The two editions do not share a block vocabulary. Most ids line up since
/// Bedrock's own flattening, but a long tail of blocks kept their pre-
/// flattening names, and the block-state *properties* are a different scheme
/// entirely: Java's `facing=east` on a stair is Bedrock's
/// `weirdo_direction=0`, and Java's `waterlogged` is not a property at all —
/// Bedrock stores water in a second block layer.
///
/// The mapping is therefore deliberately approximate, and reports how much it
/// had to guess so the UI can say so rather than implying a clean round trip.
class BedrockBlocks {
  const BedrockBlocks._();

  /// Blocks whose id differs between the editions, written Java → Bedrock.
  static const Map<String, String> _javaToBedrockName = {
    'dirt_path': 'grass_path',
    'note_block': 'noteblock',
    'cobweb': 'web',
    'snow_block': 'snow',
    'snow': 'snow_layer',
    'magma_block': 'magma',
    'slime_block': 'slime',
    'nether_bricks': 'nether_brick',
    'red_nether_bricks': 'red_nether_brick',
    'bricks': 'brick_block',
    'terracotta': 'hardened_clay',
    'melon': 'melon_block',
    'lily_pad': 'waterlily',
    'spawner': 'mob_spawner',
    'oak_sign': 'standing_sign',
    'oak_wall_sign': 'wall_sign',
    'powered_rail': 'golden_rail',
    'end_stone_bricks': 'end_bricks',
    'sugar_cane': 'reeds',
    'tripwire': 'trip_wire',
    'beetroots': 'beetroot',
    'jack_o_lantern': 'lit_pumpkin',
    'nether_portal': 'portal',
    'moving_piston': 'moving_block',
    'piston_head': 'piston_arm_collision',
    'dead_bush': 'deadbush',
    'dandelion': 'yellow_flower',
    'cobblestone_stairs': 'stone_stairs',
    'repeater': 'unpowered_repeater',
    'comparator': 'unpowered_comparator',
    'redstone_wall_torch': 'redstone_torch',
    'wall_torch': 'torch',
    'soul_wall_torch': 'soul_torch',
    'cave_air': 'air',
    'void_air': 'air',
    'sunflower': 'double_plant',
    'potatoes': 'potato',
    'carrots': 'carrot',
    'cocoa': 'cocoa',
    'nether_wart': 'nether_wart',
    'redstone_lamp': 'redstone_lamp',
    'iron_trapdoor': 'iron_trapdoor',
    'oak_trapdoor': 'trapdoor',
    'attached_melon_stem': 'melon_stem',
    'attached_pumpkin_stem': 'pumpkin_stem',
    'infested_stone': 'monster_egg',
    'smooth_stone_slab': 'normal_stone_slab',
    'petrified_oak_slab': 'petrified_oak_slab',
    'small_amethyst_bud': 'small_amethyst_bud',
  };

  static final Map<String, String> _bedrockToJavaName = {
    for (final e in _javaToBedrockName.entries)
      if (!const {'cave_air', 'void_air'}.contains(e.key)) e.value: e.key,
  };

  /// Bedrock's `weirdo_direction` order for stairs.
  static const List<String> _stairDirections = [
    'east',
    'west',
    'south',
    'north',
  ];

  /// Bedrock's `facing_direction` order.
  static const List<String> _facing6 = [
    'down',
    'up',
    'north',
    'south',
    'west',
    'east',
  ];

  /// Java → Bedrock. `exact` is false when a name or property had to be
  /// guessed at or dropped.
  static ({BlockState state, bool exact}) toBedrock(BlockState java) {
    if (java.isAir) return (state: BlockState('minecraft:air'), exact: true);

    final short = java.shortName;
    final mapped = _javaToBedrockName[short];
    final name = 'minecraft:${mapped ?? short}';

    final props = <String, String>{};
    var exact = true;

    java.properties.forEach((key, value) {
      switch (key) {
        case 'facing':
          if (short.endsWith('_stairs')) {
            final index = _stairDirections.indexOf(value);
            if (index >= 0) props['weirdo_direction'] = '$index';
          } else if (_facing6.contains(value)) {
            props['facing_direction'] = '${_facing6.indexOf(value)}';
          } else {
            exact = false;
          }
        case 'half':
          if (short.endsWith('_stairs')) {
            props['upside_down_bit'] = value == 'top' ? '1' : '0';
          } else {
            props['upper_block_bit'] = value == 'upper' ? '1' : '0';
          }
        case 'type':
          if (value == 'double') {
            exact = false;
          } else {
            props['minecraft:vertical_half'] = value;
          }
        case 'axis':
          props['pillar_axis'] = value;
        case 'open':
          props['open_bit'] = value == 'true' ? '1' : '0';
        case 'powered':
          props['powered_bit'] = value == 'true' ? '1' : '0';
        case 'lit':
          props['lit'] = value;
        case 'age':
          props['growth'] = value;
        case 'layers':
          props['height'] = '${(int.tryParse(value) ?? 1) - 1}';
        case 'level':
          props['liquid_depth'] = value;
        case 'rotation':
          props['ground_sign_direction'] = value;
        case 'waterlogged':
          // Not a property on Bedrock — the caller lifts this into the
          // structure's second block layer instead.
          break;
        case 'snowy':
        case 'persistent':
        case 'distance':
        case 'hinge':
        case 'shape':
        case 'delay':
        case 'eye':
        case 'moisture':
          exact = false;
        default:
          exact = false;
      }
    });

    return (state: BlockState(name, props), exact: exact);
  }

  /// Bedrock → Java.
  static ({BlockState state, bool exact}) toJava(BlockState bedrock) {
    if (bedrock.isAir) return (state: BlockState.air, exact: true);

    final short = bedrock.shortName;
    final mapped = _bedrockToJavaName[short];
    final name = 'minecraft:${mapped ?? short}';

    final props = <String, String>{};
    var exact = true;

    bedrock.properties.forEach((key, value) {
      switch (key) {
        case 'weirdo_direction':
          final index = int.tryParse(value);
          if (index != null && index >= 0 && index < 4) {
            props['facing'] = _stairDirections[index];
          }
        case 'facing_direction':
          final index = int.tryParse(value);
          if (index != null && index >= 0 && index < 6) {
            props['facing'] = _facing6[index];
          }
        case 'upside_down_bit':
          props['half'] = value == '1' ? 'top' : 'bottom';
        case 'upper_block_bit':
          props['half'] = value == '1' ? 'upper' : 'lower';
        case 'minecraft:vertical_half':
        case 'top_slot_bit':
          props['type'] =
              (value == 'top' || value == '1') ? 'top' : 'bottom';
        case 'pillar_axis':
          props['axis'] = value;
        case 'open_bit':
          props['open'] = value == '1' ? 'true' : 'false';
        case 'powered_bit':
          props['powered'] = value == '1' ? 'true' : 'false';
        case 'lit':
          props['lit'] = value;
        case 'growth':
          props['age'] = value;
        case 'height':
          props['layers'] = '${(int.tryParse(value) ?? 0) + 1}';
        case 'liquid_depth':
          props['level'] = value;
        case 'ground_sign_direction':
          props['rotation'] = value;
        case 'minecraft:cardinal_direction':
          props['facing'] = value;
        default:
          exact = false;
      }
    });

    return (state: BlockState(name, props), exact: exact);
  }
}

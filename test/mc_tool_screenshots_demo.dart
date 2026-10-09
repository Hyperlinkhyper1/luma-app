// Demo builds for test/mc_tool_screenshots_test.dart: small, recognisable
// structures so the build tools' banners show something worth looking at.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:luma/features/converter/schematic/schematic_model.dart';

class _Builder {
  _Builder(this.width, this.height, this.length)
    : _blocks = Uint16List(width * height * length);

  final int width;
  final int height;
  final int length;
  final Uint16List _blocks;
  final List<BlockState> _palette = [BlockState.air];
  final Map<String, int> _ids = {'minecraft:air': 0};

  void set(int x, int y, int z, String state) {
    if (x < 0 || y < 0 || z < 0 || x >= width || y >= height || z >= length) {
      return;
    }
    final id = _ids.putIfAbsent(state, () {
      _palette.add(_parse(state));
      return _palette.length - 1;
    });
    _blocks[x + z * width + y * width * length] = id;
  }

  void fill(int x0, int y0, int z0, int x1, int y1, int z1, String state) {
    for (var y = y0; y <= y1; y++) {
      for (var z = z0; z <= z1; z++) {
        for (var x = x0; x <= x1; x++) {
          set(x, y, z, state);
        }
      }
    }
  }

  static BlockState _parse(String state) {
    final open = state.indexOf('[');
    if (open < 0) return BlockState(state);
    final props = <String, String>{
      for (final pair in state.substring(open + 1, state.length - 1).split(','))
        pair.split('=')[0]: pair.split('=')[1],
    };
    return BlockState(state.substring(0, open), props);
  }

  Schematic build(String name) => Schematic(
    width: width,
    height: height,
    length: length,
    palette: _palette,
    blocks: _blocks,
    name: name,
    author: 'luma',
  );
}

/// A timber-framed cottage on a patch of garden.
Schematic demoCottage() {
  final b = _Builder(19, 16, 17);
  // Ground and garden.
  b.fill(0, 0, 0, 18, 0, 16, 'minecraft:grass_block[snowy=false]');
  for (var z = 13; z <= 16; z++) {
    b.set(9, 0, z, 'minecraft:dirt_path');
  }
  // Foundation and floor.
  b.fill(2, 1, 2, 16, 1, 12, 'minecraft:cobblestone');
  b.fill(3, 1, 3, 15, 1, 11, 'minecraft:spruce_planks');
  // Walls with log posts.
  for (var y = 2; y <= 5; y++) {
    for (var x = 2; x <= 16; x++) {
      b.set(x, y, 2, 'minecraft:white_terracotta');
      b.set(x, y, 12, 'minecraft:white_terracotta');
    }
    for (var z = 2; z <= 12; z++) {
      b.set(2, y, z, 'minecraft:white_terracotta');
      b.set(16, y, z, 'minecraft:white_terracotta');
    }
    for (final (x, z) in [(2, 2), (16, 2), (2, 12), (16, 12), (9, 2), (9, 12), (2, 7), (16, 7)]) {
      b.set(x, y, z, 'minecraft:spruce_log[axis=y]');
    }
  }
  // Beams.
  b.fill(2, 5, 2, 16, 5, 2, 'minecraft:stripped_spruce_log[axis=x]');
  b.fill(2, 5, 12, 16, 5, 12, 'minecraft:stripped_spruce_log[axis=x]');
  b.fill(2, 5, 2, 2, 5, 12, 'minecraft:stripped_spruce_log[axis=z]');
  b.fill(16, 5, 2, 16, 5, 12, 'minecraft:stripped_spruce_log[axis=z]');
  // Windows.
  for (final x in [5, 6, 12, 13]) {
    b.fill(x, 3, 12, x, 4, 12, 'minecraft:glass_pane[east=true,west=true,north=false,south=false,waterlogged=false]');
    b.fill(x, 3, 2, x, 4, 2, 'minecraft:glass_pane[east=true,west=true,north=false,south=false,waterlogged=false]');
  }
  for (final z in [4, 5, 9, 10]) {
    b.fill(2, 3, z, 2, 4, z, 'minecraft:glass_pane[north=true,south=true,east=false,west=false,waterlogged=false]');
    b.fill(16, 3, z, 16, 4, z, 'minecraft:glass_pane[north=true,south=true,east=false,west=false,waterlogged=false]');
  }
  // Door.
  b.set(9, 2, 12, 'minecraft:spruce_door[facing=south,half=lower,hinge=left,open=false,powered=false]');
  b.set(9, 3, 12, 'minecraft:spruce_door[facing=south,half=upper,hinge=left,open=false,powered=false]');
  b.set(9, 4, 13, 'minecraft:lantern[hanging=false,waterlogged=false]');
  // Gable roof along x, overhanging by one.
  for (var k = 0; k <= 6; k++) {
    final y = 6 + k;
    final front = 1 + k;
    final back = 13 - k;
    if (front > back) break;
    for (var x = 1; x <= 17; x++) {
      if (front == back) {
        b.set(x, y, front, 'minecraft:dark_oak_slab[type=bottom,waterlogged=false]');
        continue;
      }
      b.set(x, y, front, 'minecraft:dark_oak_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]');
      b.set(x, y, back, 'minecraft:dark_oak_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]');
    }
    // Gable ends.
    for (var z = front + 1; z <= back - 1; z++) {
      b.set(2, y, z, 'minecraft:spruce_planks');
      b.set(16, y, z, 'minecraft:spruce_planks');
    }
  }
  // Chimney.
  b.fill(13, 2, 4, 13, 13, 4, 'minecraft:bricks');
  b.set(13, 14, 4, 'minecraft:campfire[facing=north,lit=true,signal_fire=false,waterlogged=false]');
  // Flower beds.
  const flowers = [
    'minecraft:poppy', 'minecraft:dandelion', 'minecraft:oxeye_daisy',
    'minecraft:cornflower', 'minecraft:allium', 'minecraft:azure_bluet',
  ];
  var f = 0;
  for (var x = 3; x <= 15; x++) {
    if (x == 9 || x == 8 || x == 10) continue;
    b.set(x, 1, 13, flowers[f++ % flowers.length]);
  }
  for (final (x, z) in [(0, 0), (18, 0), (0, 16), (18, 16)]) {
    b.fill(x, 1, z, x, 3, z, 'minecraft:oak_log[axis=y]');
    b.fill(x - 1, 4, z - 1, x + 1, 5, z + 1, 'minecraft:oak_leaves[distance=1,persistent=true,waterlogged=false]');
  }
  return b.build('Cozy Cottage');
}

/// A round stone watchtower.
Schematic demoTower() {
  final b = _Builder(11, 22, 11);
  for (var y = 0; y < 22; y++) {
    for (var z = 0; z < 11; z++) {
      for (var x = 0; x < 11; x++) {
        final d = math.sqrt(math.pow(x - 5, 2) + math.pow(z - 5, 2));
        if (y < 17 && d <= 4.4 && d > 3.4) {
          b.set(x, y, z, y % 6 == 5 ? 'minecraft:chiseled_stone_bricks' : 'minecraft:stone_bricks');
        }
        if (y == 17 && d <= 5.4) b.set(x, y, z, 'minecraft:spruce_planks');
        if (y > 17 && d <= 5.4 - (y - 17) * 1.2 && d > 4.2 - (y - 17) * 1.2) {
          b.set(x, y, z, 'minecraft:dark_oak_planks');
        }
      }
    }
  }
  return b.build('Watch Tower');
}

/// An oak with a round crown.
Schematic demoTree() {
  final b = _Builder(11, 14, 11);
  b.fill(5, 0, 5, 5, 7, 5, 'minecraft:oak_log[axis=y]');
  for (var y = 5; y < 14; y++) {
    for (var z = 0; z < 11; z++) {
      for (var x = 0; x < 11; x++) {
        final d = math.sqrt(math.pow(x - 5, 2) + math.pow((y - 9) * 1.2, 2) + math.pow(z - 5, 2));
        if (d <= 4.6 && b._blocks[x + z * 11 + y * 121] == 0) {
          b.set(x, y, z, 'minecraft:oak_leaves[distance=1,persistent=true,waterlogged=false]');
        }
      }
    }
  }
  return b.build('Big Oak');
}

/// A tiered fountain.
Schematic demoFountain() {
  final b = _Builder(9, 5, 9);
  b.fill(0, 0, 0, 8, 0, 8, 'minecraft:smooth_stone');
  for (var z = 0; z < 9; z++) {
    for (var x = 0; x < 9; x++) {
      final rim = x == 0 || z == 0 || x == 8 || z == 8;
      b.set(
        x,
        1,
        z,
        rim
            ? 'minecraft:stone_brick_wall[east=low,north=none,south=none,up=true,waterlogged=false,west=low]'
            : 'minecraft:water[level=0]',
      );
    }
  }
  b.fill(4, 1, 4, 4, 3, 4, 'minecraft:quartz_pillar[axis=y]');
  b.set(4, 4, 4, 'minecraft:sea_lantern');
  return b.build('Fountain');
}

/// A short arched bridge.
Schematic demoBridge() {
  final b = _Builder(21, 7, 5);
  for (var x = 0; x < 21; x++) {
    final h = (4 - math.pow((x - 10) / 5, 2)).clamp(0, 4).round() + 1;
    b.fill(x, 0, 1, x, h, 3, 'minecraft:stone_bricks');
    b.set(x, h + 1, 0, 'minecraft:spruce_fence[east=true,north=false,south=false,waterlogged=false,west=true]');
    b.set(x, h + 1, 4, 'minecraft:spruce_fence[east=true,north=false,south=false,waterlogged=false,west=true]');
    b.fill(x, h, 1, x, h, 3, 'minecraft:spruce_planks');
  }
  return b.build('Stone Bridge');
}

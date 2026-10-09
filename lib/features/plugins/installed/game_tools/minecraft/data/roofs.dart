import 'dart:math' as math;

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../converter/schematic/schematic_model.dart';

/// A roof material: the stairs, slab and full block of one set.
class McRoofMaterial {
  const McRoofMaterial(this.label, this.stairs, this.slab, this.block);
  final String label;
  final String stairs;
  final String slab;
  final String block;
}

const kMcRoofMaterials = [
  McRoofMaterial('Dark oak', 'dark_oak_stairs', 'dark_oak_slab', 'dark_oak_planks'),
  McRoofMaterial('Spruce', 'spruce_stairs', 'spruce_slab', 'spruce_planks'),
  McRoofMaterial('Oak', 'oak_stairs', 'oak_slab', 'oak_planks'),
  McRoofMaterial('Birch', 'birch_stairs', 'birch_slab', 'birch_planks'),
  McRoofMaterial('Jungle', 'jungle_stairs', 'jungle_slab', 'jungle_planks'),
  McRoofMaterial('Acacia', 'acacia_stairs', 'acacia_slab', 'acacia_planks'),
  McRoofMaterial('Mangrove', 'mangrove_stairs', 'mangrove_slab', 'mangrove_planks'),
  McRoofMaterial('Cherry', 'cherry_stairs', 'cherry_slab', 'cherry_planks'),
  McRoofMaterial('Pale oak', 'pale_oak_stairs', 'pale_oak_slab', 'pale_oak_planks'),
  McRoofMaterial('Bamboo', 'bamboo_stairs', 'bamboo_slab', 'bamboo_planks'),
  McRoofMaterial('Crimson', 'crimson_stairs', 'crimson_slab', 'crimson_planks'),
  McRoofMaterial('Warped', 'warped_stairs', 'warped_slab', 'warped_planks'),
  McRoofMaterial('Deepslate tiles', 'deepslate_tile_stairs', 'deepslate_tile_slab', 'deepslate_tiles'),
  McRoofMaterial('Stone bricks', 'stone_brick_stairs', 'stone_brick_slab', 'stone_bricks'),
  McRoofMaterial('Bricks', 'brick_stairs', 'brick_slab', 'bricks'),
  McRoofMaterial('Mud bricks', 'mud_brick_stairs', 'mud_brick_slab', 'mud_bricks'),
  McRoofMaterial('Blackstone', 'blackstone_stairs', 'blackstone_slab', 'blackstone'),
  McRoofMaterial('Nether bricks', 'nether_brick_stairs', 'nether_brick_slab', 'nether_bricks'),
  McRoofMaterial('Tuff bricks', 'tuff_brick_stairs', 'tuff_brick_slab', 'tuff_bricks'),
  McRoofMaterial('Cut copper', 'cut_copper_stairs', 'cut_copper_slab', 'cut_copper'),
  McRoofMaterial('Prismarine bricks', 'prismarine_brick_stairs', 'prismarine_brick_slab', 'prismarine_bricks'),
];

enum McRoofStyle {
  gable,
  steepGable,
  gentleGable,
  gambrel,
  hip,
  gentleHip,
  mansard,
  shed,
  aFrame;

  String label(L t) => switch (this) {
    gable => t.mcRoofGable,
    steepGable => t.mcRoofSteepGable,
    gentleGable => t.mcRoofGentleGable,
    gambrel => t.mcRoofGambrel,
    hip => t.mcRoofHip,
    gentleHip => t.mcRoofGentleHip,
    mansard => t.mcRoofMansard,
    shed => t.mcRoofShed,
    aFrame => t.mcRoofAFrame,
  };

  bool get hipped => this == hip || this == gentleHip || this == mansard;
  bool get oneSided => this == shed;
}

/// Directions on the horizontal plane, as stairs name them.
enum McFacing {
  north(0, -1),
  east(1, 0),
  south(0, 1),
  west(-1, 0);

  const McFacing(this.dx, this.dz);
  final int dx;
  final int dz;

  McFacing get ccw => switch (this) {
    north => west,
    west => south,
    south => east,
    east => north,
  };

  McFacing get opposite => switch (this) {
    north => south,
    south => north,
    east => west,
    west => east,
  };

  bool sameAxis(McFacing o) => (dx == 0) == (o.dx == 0);
}

/// The rise, in half blocks, of each step out from the eave for [style] on
/// a slope [span] steps long.
int _rise(McRoofStyle style, int step, int span) => switch (style) {
  McRoofStyle.gable || McRoofStyle.hip || McRoofStyle.shed => 2,
  McRoofStyle.steepGable || McRoofStyle.aFrame => 4,
  McRoofStyle.gentleGable || McRoofStyle.gentleHip => 1,
  McRoofStyle.gambrel => step < math.max(1, span ~/ 3) ? 4 : 2,
  McRoofStyle.mansard => step < math.max(1, span ~/ 3) ? 4 : 1,
};

class McRoofResult {
  const McRoofResult(this.blocks, this.stairs, this.slabs, this.fill, this.peak);

  final Map<(int, int, int), BlockState> blocks;
  final int stairs;
  final int slabs;
  final int fill;
  final int peak;
}

/// Generates a roof over a [width] × [depth] footprint (plus [overhang] on
/// every side) as block states, with stairs facing up the slope and corner
/// shapes worked out the way the game does when the stairs are placed.
McRoofResult mcGenerateRoof({
  required McRoofStyle style,
  required int width,
  required int depth,
  required McRoofMaterial material,
  int overhang = 1,
  String? gableFill,
  bool ridgeCap = true,
}) {
  final w = width + overhang * 2;
  final d = depth + overhang * 2;
  // Which way the slopes run for gable-type roofs: across the shorter side,
  // so the ridge runs along the longer one.
  final slopeAlongZ = w >= d;

  int distance(int x, int z) {
    if (style.hipped) {
      return [x, w - 1 - x, z, d - 1 - z].reduce(math.min);
    }
    if (style.oneSided) return slopeAlongZ ? z : x;
    return slopeAlongZ ? math.min(z, d - 1 - z) : math.min(x, w - 1 - x);
  }

  McFacing uphill(int x, int z) {
    if (style.oneSided) return slopeAlongZ ? McFacing.south : McFacing.east;
    if (style.hipped) {
      final dz = math.min(z, d - 1 - z);
      final dx = math.min(x, w - 1 - x);
      if (dz <= dx) return z < d / 2 ? McFacing.south : McFacing.north;
      return x < w / 2 ? McFacing.east : McFacing.west;
    }
    if (slopeAlongZ) return z < d / 2 ? McFacing.south : McFacing.north;
    return x < w / 2 ? McFacing.east : McFacing.west;
  }

  final span = style.hipped
      ? (math.min(w, d) - 1) ~/ 2
      : style.oneSided
      ? (slopeAlongZ ? d - 1 : w - 1)
      : ((slopeAlongZ ? d : w) - 1) ~/ 2;

  // Surface height in half blocks at each distance.
  final surface = <int>[];
  var h = 0;
  for (var s = 0; s <= span; s++) {
    h += _rise(style, s, span);
    surface.add(h);
  }

  final blocks = <(int, int, int), BlockState>{};
  final facings = <(int, int, int), McFacing>{};
  var stairs = 0, slabs = 0, fill = 0, peak = 0;
  final stairName = 'minecraft:${material.stairs}';
  final slabName = 'minecraft:${material.slab}';
  final full = BlockState('minecraft:${material.block}');

  for (var z = 0; z < d; z++) {
    for (var x = 0; x < w; x++) {
      final dist = distance(x, z);
      final top = surface[dist];
      final rise = _rise(style, dist, span);
      final isRidge = !style.oneSided && dist == span &&
          (style.hipped
              ? false
              : ((slopeAlongZ ? d : w).isOdd));
      if (rise == 1) {
        // Half-block steps: slabs, top half on even heights.
        final y = (top - 1) ~/ 2;
        final half = top.isEven ? 'top' : 'bottom';
        blocks[(x, y, z)] = BlockState(slabName, {'type': half, 'waterlogged': 'false'});
        slabs++;
        peak = math.max(peak, y);
        continue;
      }
      final y = top ~/ 2 - 1;
      peak = math.max(peak, y);
      if (isRidge) {
        blocks[(x, y, z)] = full;
        fill++;
        if (ridgeCap) {
          blocks[(x, y + 1, z)] = BlockState(slabName, {'type': 'bottom', 'waterlogged': 'false'});
          slabs++;
          peak = math.max(peak, y + 1);
        }
        continue;
      }
      final facing = uphill(x, z);
      facings[(x, y, z)] = facing;
      if (rise == 4) {
        blocks[(x, y - 1, z)] = full;
        fill++;
      }
      stairs++;
    }
  }

  // Hip roofs meet in a single ridge line or point at the top.
  if (style.hipped && ridgeCap) {
    for (final e in facings.entries.toList()) {
      final (x, y, z) = e.key;
      if (distance(x, z) == span) {
        blocks[(x, y + 1, z)] = BlockState(slabName, {'type': 'bottom', 'waterlogged': 'false'});
        slabs++;
        peak = math.max(peak, y + 1);
      }
    }
  }

  // Stair shapes, the game's own rule: look at the stairs in front of and
  // behind each one on the same level.
  McFacing? at(int x, int y, int z) => facings[(x, y, z)];
  bool canTake(int x, int y, int z, McFacing self, McFacing face) {
    final n = at(x + face.dx, y, z + face.dz);
    return n == null || n != self;
  }

  for (final e in facings.entries) {
    final (x, y, z) = e.key;
    final dir = e.value;
    var shape = 'straight';
    final behind = at(x + dir.dx, y, z + dir.dz);
    if (behind != null && !behind.sameAxis(dir) && canTake(x, y, z, dir, behind.opposite)) {
      shape = behind == dir.ccw ? 'outer_left' : 'outer_right';
    } else {
      final front = at(x - dir.dx, y, z - dir.dz);
      if (front != null && !front.sameAxis(dir) && canTake(x, y, z, dir, front)) {
        shape = front == dir.ccw ? 'inner_left' : 'inner_right';
      }
    }
    blocks[(x, y, z)] = BlockState(stairName, {
      'facing': dir.name,
      'half': 'bottom',
      'shape': shape,
      'waterlogged': 'false',
    });
  }

  // Gable walls under the two ends of a gable-type roof, inside the walls'
  // footprint only.
  if (gableFill != null && !style.hipped) {
    final wall = BlockState('minecraft:$gableFill');
    final ends = slopeAlongZ ? [overhang, w - 1 - overhang] : [overhang, d - 1 - overhang];
    for (final end in ends) {
      final length = slopeAlongZ ? d : w;
      for (var i = overhang; i < length - overhang; i++) {
        final x = slopeAlongZ ? end : i;
        final z = slopeAlongZ ? i : end;
        final dist = distance(x, z);
        final top = surface[dist];
        final roofY = _rise(style, dist, span) == 1 ? (top - 1) ~/ 2 : top ~/ 2 - 1;
        for (var y = 0; y < roofY; y++) {
          if (blocks.containsKey((x, y, z))) continue;
          blocks[(x, y, z)] = wall;
          fill++;
        }
      }
    }
  }

  return McRoofResult(blocks, stairs, slabs, fill, peak);
}

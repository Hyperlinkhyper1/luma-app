import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../converter/schematic/schematic_model.dart';

/// A map base colour and the block luma suggests for it. Colours are the
/// game's map palette; each shows in four shades depending on height.
class McMapColor {
  const McMapColor(this.id, this.name, this.rgb, this.block, {this.fragile = false});

  /// The game's map colour id, 1–61.
  final int id;
  final String name;
  final int rgb;
  final String block;

  /// Needs support or care when placing (leaves decay without a log nearby
  /// unless they are persistent; we place them persistent).
  final bool fragile;
}

const kMcMapColors = [
  McMapColor(1, 'Grass', 0x7FB238, 'grass_block'),
  McMapColor(2, 'Sand', 0xF7E9A3, 'sandstone'),
  McMapColor(3, 'Wool', 0xC7C7C7, 'mushroom_stem'),
  McMapColor(4, 'Fire', 0xFF0000, 'redstone_block'),
  McMapColor(5, 'Ice', 0xA0A0FF, 'packed_ice'),
  McMapColor(6, 'Metal', 0xA7A7A7, 'iron_block'),
  McMapColor(7, 'Plant', 0x007C00, 'oak_leaves', fragile: true),
  McMapColor(8, 'Snow', 0xFFFFFF, 'white_concrete'),
  McMapColor(9, 'Clay', 0xA4A8B8, 'clay'),
  McMapColor(10, 'Dirt', 0x976D4D, 'dirt'),
  McMapColor(11, 'Stone', 0x707070, 'cobblestone'),
  McMapColor(13, 'Wood', 0x8F7748, 'oak_planks'),
  McMapColor(14, 'Quartz', 0xFFFCF5, 'quartz_block'),
  McMapColor(15, 'Orange', 0xD87F33, 'orange_concrete'),
  McMapColor(16, 'Magenta', 0xB24CD8, 'magenta_concrete'),
  McMapColor(17, 'Light Blue', 0x6699D8, 'light_blue_concrete'),
  McMapColor(18, 'Yellow', 0xE5E533, 'yellow_concrete'),
  McMapColor(19, 'Lime', 0x7FCC19, 'lime_concrete'),
  McMapColor(20, 'Pink', 0xF27FA5, 'pink_concrete'),
  McMapColor(21, 'Gray', 0x4C4C4C, 'gray_concrete'),
  McMapColor(22, 'Light Gray', 0x999999, 'light_gray_concrete'),
  McMapColor(23, 'Cyan', 0x4C7F99, 'cyan_concrete'),
  McMapColor(24, 'Purple', 0x7F3FB2, 'purple_concrete'),
  McMapColor(25, 'Blue', 0x334CB2, 'blue_concrete'),
  McMapColor(26, 'Brown', 0x664C33, 'brown_concrete'),
  McMapColor(27, 'Green', 0x667F33, 'green_concrete'),
  McMapColor(28, 'Red', 0x993333, 'red_concrete'),
  McMapColor(29, 'Black', 0x191919, 'black_concrete'),
  McMapColor(30, 'Gold', 0xFAEE4D, 'gold_block'),
  McMapColor(31, 'Diamond', 0x5CDBD5, 'diamond_block'),
  McMapColor(32, 'Lapis', 0x4A80FF, 'lapis_block'),
  McMapColor(33, 'Emerald', 0x00D93A, 'emerald_block'),
  McMapColor(34, 'Podzol', 0x815631, 'spruce_planks'),
  McMapColor(35, 'Nether', 0x700200, 'netherrack'),
  McMapColor(36, 'White Terracotta', 0xD1B1A1, 'white_terracotta'),
  McMapColor(37, 'Orange Terracotta', 0x9F5224, 'orange_terracotta'),
  McMapColor(38, 'Magenta Terracotta', 0x95576C, 'magenta_terracotta'),
  McMapColor(39, 'Light Blue Terracotta', 0x706C8A, 'light_blue_terracotta'),
  McMapColor(40, 'Yellow Terracotta', 0xBA8524, 'yellow_terracotta'),
  McMapColor(41, 'Lime Terracotta', 0x677535, 'lime_terracotta'),
  McMapColor(42, 'Pink Terracotta', 0xA04D4E, 'pink_terracotta'),
  McMapColor(43, 'Gray Terracotta', 0x392923, 'gray_terracotta'),
  McMapColor(44, 'Light Gray Terracotta', 0x876B62, 'light_gray_terracotta'),
  McMapColor(45, 'Cyan Terracotta', 0x575C5C, 'cyan_terracotta'),
  McMapColor(46, 'Purple Terracotta', 0x7A4958, 'purple_terracotta'),
  McMapColor(47, 'Blue Terracotta', 0x4C3E5C, 'blue_terracotta'),
  McMapColor(48, 'Brown Terracotta', 0x4C3223, 'brown_terracotta'),
  McMapColor(49, 'Green Terracotta', 0x4C522A, 'green_terracotta'),
  McMapColor(50, 'Red Terracotta', 0x8E3C2E, 'red_terracotta'),
  McMapColor(51, 'Black Terracotta', 0x251610, 'black_terracotta'),
  McMapColor(52, 'Crimson Nylium', 0xBD3031, 'crimson_nylium'),
  McMapColor(53, 'Crimson Stem', 0x943F61, 'crimson_planks'),
  McMapColor(54, 'Crimson Hyphae', 0x5C191D, 'crimson_hyphae'),
  McMapColor(55, 'Warped Nylium', 0x167E86, 'warped_nylium'),
  McMapColor(56, 'Warped Stem', 0x3A8E8C, 'warped_planks'),
  McMapColor(57, 'Warped Hyphae', 0x562C3E, 'warped_hyphae'),
  McMapColor(58, 'Warped Wart', 0x14B485, 'warped_wart_block'),
  McMapColor(59, 'Deepslate', 0x646464, 'cobbled_deepslate'),
  McMapColor(60, 'Raw Iron', 0xD8AF93, 'raw_iron_block'),
  McMapColor(61, 'Glow Lichen', 0x7FA796, 'verdant_froglight'),
];

/// The map shade multipliers: darker, flat, brighter (staircase uses all
/// three; a flat build only ever shows the middle one).
const kMcMapShades = [180, 220, 255];

int mcShade(int rgb, int shade) {
  final r = ((rgb >> 16) & 0xFF) * shade ~/ 255;
  final g = ((rgb >> 8) & 0xFF) * shade ~/ 255;
  final b = (rgb & 0xFF) * shade ~/ 255;
  return (r << 16) | (g << 8) | b;
}

enum McDither {
  none,
  floydSteinberg,
  ordered;

  String label(L t) => switch (this) {
    none => t.mcMapDitherNone,
    floydSteinberg => t.mcMapDitherFs,
    ordered => t.mcMapDitherOrdered,
  };
}

/// How a pixel is matched to the nearest map colour.
enum McColorMatch {
  /// "Redmean" weighted RGB: cheap and close to perceptual.
  balanced,

  /// Distance in CIELAB, which follows the eye best.
  best,

  /// Plain RGB distance.
  fast;

  String label(L t) => switch (this) {
    balanced => t.mcMapMatchBalanced,
    best => t.mcMapMatchBest,
    fast => t.mcMapMatchFast,
  };
}

/// Input for [mcConvertMapArt], kept to plain data so it can cross isolates.
class McMapArtJob {
  const McMapArtJob({
    required this.pixels,
    required this.width,
    required this.height,
    required this.colors,
    required this.staircase,
    required this.dither,
    this.ditherStrength = 1,
    this.match = McColorMatch.balanced,
  });

  /// RGBA, already scaled to [width] × [height] (128 per map).
  final Uint8List pixels;
  final int width;
  final int height;

  /// Indices into [kMcMapColors] that may be used.
  final List<int> colors;
  final bool staircase;
  final McDither dither;

  /// 0–1: how much of the dither is applied.
  final double ditherStrength;
  final McColorMatch match;
}

class McMapArtResult {
  const McMapArtResult({
    required this.width,
    required this.height,
    required this.color,
    required this.shade,
    required this.preview,
  });

  final int width;
  final int height;

  /// Per pixel, an index into [kMcMapColors]; -1 for transparent.
  final Int16List color;

  /// Per pixel, 0 (darker), 1 (flat) or 2 (brighter).
  final Uint8List shade;

  /// RGBA of how the map will look in game.
  final Uint8List preview;
}

double _redmean(int r1, int g1, int b1, int rgb) {
  final r2 = (rgb >> 16) & 0xFF, g2 = (rgb >> 8) & 0xFF, b2 = rgb & 0xFF;
  final rm = (r1 + r2) / 2;
  final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
  return (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db;
}

double _rgbDistance(int r1, int g1, int b1, int rgb) {
  final dr = r1 - ((rgb >> 16) & 0xFF), dg = g1 - ((rgb >> 8) & 0xFF), db = b1 - (rgb & 0xFF);
  return (dr * dr + dg * dg + db * db).toDouble();
}

double _linear(int c) {
  final v = c / 255;
  return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _labF(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

/// sRGB to CIELAB (D65).
(double, double, double) _lab(int r, int g, int b) {
  final lr = _linear(r), lg = _linear(g), lb = _linear(b);
  final x = (lr * 0.4124 + lg * 0.3576 + lb * 0.1805) / 0.95047;
  final y = lr * 0.2126 + lg * 0.7152 + lb * 0.0722;
  final z = (lr * 0.0193 + lg * 0.1192 + lb * 0.9505) / 1.08883;
  final fx = _labF(x), fy = _labF(y), fz = _labF(z);
  return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

const _bayer = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

/// Matches every pixel to the nearest allowed map colour and shade.
McMapArtResult mcConvertMapArt(McMapArtJob job) {
  final w = job.width, h = job.height;
  final shades = job.staircase ? const [0, 1, 2] : const [1];
  final candidates = <(int, int, int)>[];
  for (final ci in job.colors) {
    for (final s in shades) {
      candidates.add((ci, s, mcShade(kMcMapColors[ci].rgb, kMcMapShades[s])));
    }
  }
  final colorOut = Int16List(w * h)..fillRange(0, w * h, -1);
  final shadeOut = Uint8List(w * h);
  final preview = Uint8List(w * h * 4);
  final work = Float32List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    work[i * 3] = job.pixels[i * 4].toDouble();
    work[i * 3 + 1] = job.pixels[i * 4 + 1].toDouble();
    work[i * 3 + 2] = job.pixels[i * 4 + 2].toDouble();
  }
  if (candidates.isEmpty) {
    return McMapArtResult(width: w, height: h, color: colorOut, shade: shadeOut, preview: preview);
  }

  final best = job.match == McColorMatch.best;
  final labs = [
    if (best)
      for (final c in candidates) _lab((c.$3 >> 16) & 0xFF, (c.$3 >> 8) & 0xFF, c.$3 & 0xFF),
  ];
  // The same colour turns up again and again, dithered or not.
  final cache = <int, int>{};
  int nearest(int r, int g, int b) => cache.putIfAbsent((r << 16) | (g << 8) | b, () {
    var found = 0;
    var foundD = double.infinity;
    final lab = best ? _lab(r, g, b) : null;
    for (var k = 0; k < candidates.length; k++) {
      final double d;
      if (lab != null) {
        final c = labs[k];
        final dl = lab.$1 - c.$1, da = lab.$2 - c.$2, db = lab.$3 - c.$3;
        d = dl * dl + da * da + db * db;
      } else if (job.match == McColorMatch.fast) {
        d = _rgbDistance(r, g, b, candidates[k].$3);
      } else {
        d = _redmean(r, g, b, candidates[k].$3);
      }
      if (d < foundD) {
        foundD = d;
        found = k;
      }
    }
    return found;
  });

  final strength = job.ditherStrength.clamp(0.0, 1.0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (job.pixels[i * 4 + 3] < 128) continue;
      var r = work[i * 3], g = work[i * 3 + 1], b = work[i * 3 + 2];
      if (job.dither == McDither.ordered) {
        final t = (_bayer[y % 4][x % 4] / 16 - 0.5) * 32 * strength;
        r += t;
        g += t;
        b += t;
      }
      final match = candidates[nearest(
        r.round().clamp(0, 255),
        g.round().clamp(0, 255),
        b.round().clamp(0, 255),
      )];
      colorOut[i] = match.$1;
      shadeOut[i] = match.$2;
      final rgb = match.$3;
      final pr = (rgb >> 16) & 0xFF, pg = (rgb >> 8) & 0xFF, pb = rgb & 0xFF;
      preview[i * 4] = pr;
      preview[i * 4 + 1] = pg;
      preview[i * 4 + 2] = pb;
      preview[i * 4 + 3] = 255;
      if (job.dither == McDither.floydSteinberg && strength > 0) {
        final er = (r - pr) * strength, eg = (g - pg) * strength, eb = (b - pb) * strength;
        void spread(int dx, int dy, double f) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny >= h) return;
          final j = (ny * w + nx) * 3;
          work[j] += er * f;
          work[j + 1] += eg * f;
          work[j + 2] += eb * f;
        }

        spread(1, 0, 7 / 16);
        spread(-1, 1, 3 / 16);
        spread(0, 1, 5 / 16);
        spread(1, 1, 1 / 16);
      }
    }
  }
  return McMapArtResult(width: w, height: h, color: colorOut, shade: shadeOut, preview: preview);
}

/// Block heights for a staircase build, one column (x) at a time from the
/// north, in shade steps (multiply by [mcShadeStep] for blocks). Row −1 is
/// the "noobline" of blocks north of the map whose height sets the first
/// row's shade.
///
/// Aligned climbs or drops exactly one step per shade change and lifts each
/// column so its lowest block sits at 0. Compact uses the slack the game
/// allows — a darker block only has to be lower than its neighbour, not one
/// lower — and drops every descent as far as it can, which keeps columns far
/// shorter.
Int32List mcStaircaseHeights(McMapArtResult art, {bool compact = false}) {
  final w = art.width, h = art.height;
  // Index (z + 1) * w + x; z = −1 is the noobline.
  final heights = Int32List(w * (h + 1));
  // How row p (1-based; 0 is the noobline) relates to the row north of it.
  int relation(int x, int p) {
    final i = (p - 1) * w + x;
    return art.color[i] < 0 ? 1 : art.shade[i];
  }

  for (var x = 0; x < w; x++) {
    if (compact) {
      // descents[p]: darker steps still to come before the next brighter
      // one, which is how high row p must be for all of them to fit above 0.
      final descents = Int32List(h + 1);
      for (var p = h - 1; p >= 0; p--) {
        final next = relation(x, p + 1);
        descents[p] = next == 2 ? 0 : descents[p + 1] + (next == 0 ? 1 : 0);
      }
      var current = descents[0];
      heights[x] = current;
      for (var p = 1; p <= h; p++) {
        current = switch (relation(x, p)) {
          0 => descents[p],
          2 => math.max(descents[p], current + 1),
          _ => current,
        };
        heights[p * w + x] = current;
      }
      continue;
    }
    var current = 0;
    var lowest = 0;
    heights[x] = 0;
    for (var z = 0; z < h; z++) {
      final i = z * w + x;
      if (art.color[i] >= 0) {
        current += switch (art.shade[i]) {
          0 => -1,
          2 => 1,
          _ => 0,
        };
      }
      heights[(z + 1) * w + x] = current;
      lowest = math.min(lowest, current);
    }
    for (var z = 0; z <= h; z++) {
      heights[z * w + x] -= lowest;
    }
  }
  return heights;
}

/// Blocks per map pixel side at a map's zoom level 0–4: 1, 2, 4, 8 or 16.
int mcMapScaleBlocks(int scale) => 1 << scale;

/// How many blocks higher or lower a pixel must sit than the one north of it
/// to read as brighter or darker on a map at [scale].
///
/// The game compares the two pixels' average heights, scaled by 4 / (k + 4)
/// for k blocks a pixel, adds ±0.2 of checkerboard noise, and changes the
/// shade past 0.6. One block is enough at 1:1; zoomed-out maps need more.
/// Worked out in doubles as the game does, rounding included.
int mcShadeStep(int scale) {
  final k = mcMapScaleBlocks(scale);
  for (var d = 1;; d++) {
    if (d * 4.0 / (k + 4) + (0 - 0.5) * 0.4 > 0.6) return d;
  }
}

/// Past this many cells a build would take hundreds of megabytes.
const kMcMapMaxVoxels = 48 * 1024 * 1024;

/// Builds the schematic for a converted map: each pixel a square of
/// [mcMapScaleBlocks] blocks, plus the strip of cobblestone north of the map
/// that sets the first row's shade. Null when the build would be larger than
/// [kMcMapMaxVoxels].
Schematic? mcBuildMapSchematic(
  McMapArtResult art, {
  required bool staircase,
  bool compact = false,
  int scale = 0,
}) {
  final k = mcMapScaleBlocks(scale);
  final step = mcShadeStep(scale);
  final w = art.width, h = art.height;
  final heights = staircase ? mcStaircaseHeights(art, compact: compact) : null;
  var maxStep = 0;
  if (heights != null) {
    for (final v in heights) {
      if (v > maxStep) maxStep = v;
    }
  }
  final width = w * k;
  final length = (h + 1) * k;
  final height = maxStep * step + 1;
  if (width * length * height > kMcMapMaxVoxels) return null;
  final palette = PaletteBuilder();
  final blocks = Uint16List(width * height * length);
  final noob = palette.add(BlockState('minecraft:cobblestone'));
  final ids = <int, int>{};
  // Zoomed-out maps read a pixel from a k × k area, so each one is a square.
  void square(int px, int pz, int y, int id) {
    for (var dz = 0; dz < k; dz++) {
      final row = (pz * k + dz) * width + y * width * length + px * k;
      for (var dx = 0; dx < k; dx++) {
        blocks[row + dx] = id;
      }
    }
  }

  for (var x = 0; x < w; x++) {
    square(x, 0, heights == null ? 0 : heights[x] * step, noob);
    for (var z = 0; z < h; z++) {
      final ci = art.color[z * w + x];
      if (ci < 0) continue;
      final p = ids.putIfAbsent(ci, () {
        final c = kMcMapColors[ci];
        return palette.add(
          c.block == 'oak_leaves'
              ? BlockState('minecraft:oak_leaves', {'persistent': 'true'})
              : BlockState('minecraft:${c.block}'),
        );
      });
      square(x, z + 1, heights == null ? 0 : heights[(z + 1) * w + x] * step, p);
    }
  }
  return Schematic(
    width: width,
    height: height,
    length: length,
    palette: palette.build(),
    blocks: blocks,
    name: 'map_art',
    author: 'luma',
    dataVersion: 5023,
  );
}

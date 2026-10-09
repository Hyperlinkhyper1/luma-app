import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../../../l10n/app_localizations.dart';

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

/// Input for [mcConvertMapArt], kept to plain data so it can cross isolates.
class McMapArtJob {
  const McMapArtJob({
    required this.pixels,
    required this.width,
    required this.height,
    required this.colors,
    required this.staircase,
    required this.dither,
  });

  /// RGBA, already scaled to [width] × [height] (128 per map).
  final Uint8List pixels;
  final int width;
  final int height;

  /// Indices into [kMcMapColors] that may be used.
  final List<int> colors;
  final bool staircase;
  final McDither dither;
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

double _distance(int r1, int g1, int b1, int rgb) {
  final r2 = (rgb >> 16) & 0xFF, g2 = (rgb >> 8) & 0xFF, b2 = rgb & 0xFF;
  // "Redmean" weighting — cheap and close to perceptual for this job.
  final rm = (r1 + r2) / 2;
  final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
  return (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db;
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

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (job.pixels[i * 4 + 3] < 128) continue;
      var r = work[i * 3], g = work[i * 3 + 1], b = work[i * 3 + 2];
      if (job.dither == McDither.ordered) {
        final t = (_bayer[y % 4][x % 4] / 16 - 0.5) * 32;
        r += t;
        g += t;
        b += t;
      }
      final ri = r.round().clamp(0, 255), gi = g.round().clamp(0, 255), bi = b.round().clamp(0, 255);
      var best = candidates.first;
      var bestD = double.infinity;
      for (final c in candidates) {
        final d = _distance(ri, gi, bi, c.$3);
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      colorOut[i] = best.$1;
      shadeOut[i] = best.$2;
      final rgb = best.$3;
      final pr = (rgb >> 16) & 0xFF, pg = (rgb >> 8) & 0xFF, pb = rgb & 0xFF;
      preview[i * 4] = pr;
      preview[i * 4 + 1] = pg;
      preview[i * 4 + 2] = pb;
      preview[i * 4 + 3] = 255;
      if (job.dither == McDither.floydSteinberg) {
        final er = r - pr, eg = g - pg, eb = b - pb;
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
/// north. Row −1 is the "noobline" of blocks north of the map whose height
/// sets the first row's shade. Each column is lifted so its lowest block
/// sits at 0.
Int32List mcStaircaseHeights(McMapArtResult art) {
  final w = art.width, h = art.height;
  // Index (z + 1) * w + x; z = −1 is the noobline.
  final heights = Int32List(w * (h + 1));
  for (var x = 0; x < w; x++) {
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

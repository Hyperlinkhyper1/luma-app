import 'dart:math' as math;

import 'mc_dyes.dart';

/// Leather armour colour after crafting it with [dyes], exactly as the game
/// mixes them: average the channels, then rescale so the brightest channel
/// matches the average brightness of the inputs. [existing] is the armour's
/// current colour, if it is already dyed.
int mcMixLeather(List<McDye> dyes, {int? existing}) {
  var r = 0, g = 0, b = 0, totalMax = 0, count = 0;
  void add(int rgb) {
    final cr = (rgb >> 16) & 0xFF, cg = (rgb >> 8) & 0xFF, cb = rgb & 0xFF;
    r += cr;
    g += cg;
    b += cb;
    totalMax += math.max(cr, math.max(cg, cb));
    count++;
  }

  if (existing != null) add(existing);
  for (final d in dyes) {
    add(d.rgb);
  }
  if (count == 0) return 0xA06540;
  var ar = r ~/ count, ag = g ~/ count, ab = b ~/ count;
  final avgMax = totalMax / count;
  final maxComp = math.max(ar, math.max(ag, ab));
  if (maxComp == 0) return 0;
  ar = (ar * avgMax / maxComp).toInt();
  ag = (ag * avgMax / maxComp).toInt();
  ab = (ab * avgMax / maxComp).toInt();
  return (ar << 16) | (ag << 8) | ab;
}

/// CIE L*a*b* for a 0xRRGGBB colour, for perceptual distances.
(double, double, double) mcLab(int rgb) {
  double lin(int c) {
    final v = c / 255;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = lin((rgb >> 16) & 0xFF), g = lin((rgb >> 8) & 0xFF), b = lin(rgb & 0xFF);
  var x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  var y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  var z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  x = f(x);
  y = f(y);
  z = f(z);
  return (116 * y - 16, 500 * (x - y), 200 * (y - z));
}

double mcDeltaE(int a, int b) {
  final (l1, a1, b1) = mcLab(a);
  final (l2, a2, b2) = mcLab(b);
  return math.sqrt(
    (l1 - l2) * (l1 - l2) + (a1 - a2) * (a1 - a2) + (b1 - b2) * (b1 - b2),
  );
}

class McDyeMatch {
  const McDyeMatch(this.dyes, this.rgb, this.deltaE);
  final List<McDye> dyes;
  final int rgb;
  final double deltaE;
}

/// The single-craft dye combination (up to [maxDyes] dyes on undyed leather)
/// that lands closest to [target]. Tries every multiset; with eight dyes
/// that is about 735 thousand mixes.
McDyeMatch mcBestDyeMix(int target, {int maxDyes = 8}) {
  final (tl, ta, tb) = mcLab(target);
  McDyeMatch? best;
  final counts = List<int>.filled(16, 0);
  final picked = <McDye>[];

  void consider() {
    final rgb = mcMixLeather(picked);
    final (l, a, b) = mcLab(rgb);
    final d = math.sqrt((l - tl) * (l - tl) + (a - ta) * (a - ta) + (b - tb) * (b - tb));
    if (best == null || d < best!.deltaE - 1e-9 ||
        (d <= best!.deltaE + 1e-9 && picked.length < best!.dyes.length)) {
      best = McDyeMatch(List.of(picked), rgb, d);
    }
  }

  void walk(int from, int left) {
    if (picked.isNotEmpty) consider();
    if (left == 0) return;
    for (var i = from; i < 16; i++) {
      picked.add(McDye.values[i]);
      counts[i]++;
      walk(i, left - 1);
      counts[i]--;
      picked.removeLast();
    }
  }

  walk(0, maxDyes);
  return best!;
}

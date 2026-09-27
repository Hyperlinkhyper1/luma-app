import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../model/brush.dart';

/// The bitmaps behind the textured brush tips and paper grains.
///
/// Everything is generated from seeded noise when the studio opens rather
/// than shipped as assets: the whole set is a few hundred milliseconds of
/// arithmetic in an isolate, and it keeps the plugin free of binary files.
/// Only the alpha channel of these images is ever read — tips are tinted with
/// a `srcIn` colour filter and grains are applied with `dstOut` — so the
/// pixels are written premultiplied white, which reads the same whichever way
/// the engine interprets them.
class BrushTextures {
  BrushTextures._(this._tips, this._grains);

  static const tipSize = 256;
  static const grainSize = 256;

  final Map<BrushTip, ui.Image> _tips;
  final Map<BrushGrain, ui.Image> _grains;

  ui.Image? tip(BrushTip tip) => _tips[tip];
  ui.Image? grain(BrushGrain grain) => _grains[grain];

  /// Canvas pixels per grain texel. Paper tooth is fine; canvas weave coarse.
  static double grainScale(BrushGrain grain) => switch (grain) {
        BrushGrain.paper => 1,
        BrushGrain.canvas => 1.25,
        BrushGrain.rough => 2,
        BrushGrain.none => 1,
      };

  static BrushTextures? _loaded;
  static Future<BrushTextures>? _loading;

  /// Generates (once per app run) and decodes every tip and grain.
  ///
  /// The finished set is cached rather than the future that made it: a
  /// completed future still delivers its value through the zone it was
  /// created in, which is gone once that caller is.
  static Future<BrushTextures> load() async {
    final loaded = _loaded;
    if (loaded != null) return loaded;
    final textures = await (_loading ??= _load());
    _loaded = textures;
    return textures;
  }

  static Future<BrushTextures> _load() async {
    final raw = await Isolate.run(generateAll);
    final tips = <BrushTip, ui.Image>{};
    final grains = <BrushGrain, ui.Image>{};
    for (final entry in raw.tips.entries) {
      tips[entry.key] = await _decode(entry.value, tipSize);
    }
    for (final entry in raw.grains.entries) {
      grains[entry.key] = await _decode(entry.value, grainSize);
    }
    return BrushTextures._(tips, grains);
  }

  static Future<ui.Image> _decode(Uint8List rgba, int size) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, size, size, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Pure pixel generation, safe to run off the UI isolate.
  static RawTextures generateAll() => RawTextures(
        tips: {
          for (final tip in BrushTip.values)
            if (tip != BrushTip.round) tip: generateTip(tip),
        },
        grains: {
          for (final grain in BrushGrain.values)
            if (grain != BrushGrain.none) grain: generateGrain(grain),
        },
      );

  static Uint8List generateTip(BrushTip tip) {
    const n = tipSize;
    final alpha = Float64List(n * n);
    final noise = _Noise(tip.index * 7919 + 17);
    switch (tip) {
      case BrushTip.round:
        break;
      case BrushTip.pencil:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final edge = _smooth(1, 0.7, r);
          final n1 = 0.6 * noise.pixel(x, y) + 0.4 * noise.value(u * 6, v * 6);
          return edge * _smooth(0.28, 0.9, n1);
        });
      case BrushTip.charcoal:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final theta = math.atan2(v, u);
          final rim = 0.78 + 0.2 * noise.angular(theta, 7);
          final edge = _smooth(rim, rim - 0.3, r);
          final n1 = 0.5 * noise.pixel(x, y) + 0.5 * noise.fbm(u * 5, v * 5);
          return edge * _smooth(0.32, 0.78, n1);
        });
      case BrushTip.chalk:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final theta = math.atan2(v, u);
          final rim = 0.84 + 0.14 * noise.angular(theta, 11);
          final edge = _smooth(rim, rim - 0.12, r);
          final n1 = 0.45 * noise.pixel(x, y) + 0.55 * noise.value(u * 14, v * 14);
          return edge * _smooth(0.42, 0.72, n1);
        });
      case BrushTip.crayon:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final edge = _smooth(1, 0.82, r);
          final streak = noise.value(u * 3, v * 26);
          final n1 = 0.55 * streak + 0.45 * noise.pixel(x, y);
          return edge * _smooth(0.3, 0.62, n1);
        });
      case BrushTip.ink:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final theta = math.atan2(v, u);
          final rim = 0.9 + 0.08 * noise.angular(theta, 23);
          final speck = noise.pixel(x, y) > 0.97 ? 0.55 : 1.0;
          return _smooth(rim, rim - 0.05, r) * speck;
        });
      case BrushTip.bristle:
        final random = math.Random(41);
        const count = 26;
        final bristles = [
          for (var i = 0; i < count; i++)
            (
              y: -0.92 + 1.84 * (i + random.nextDouble() * 0.8) / count,
              x: (random.nextDouble() - 0.5) * 0.25,
              r: 0.035 + random.nextDouble() * 0.045,
              a: 0.45 + random.nextDouble() * 0.55,
            ),
        ];
        _field(alpha, (u, v, x, y) {
          var best = 0.0;
          for (final b in bristles) {
            final dx = (u - b.x) / 0.32;
            final dy = (v - b.y) / b.r;
            final d = math.sqrt(dx * dx + dy * dy);
            final a = b.a * _smooth(1, 0.35, d);
            if (a > best) best = a;
          }
          return best;
        });
      case BrushTip.spray:
        final random = math.Random(97);
        _dots(alpha, [
          for (var i = 0; i < 110; i++)
            _gaussianDot(random, spread: 0.42, minR: 0.012, maxR: 0.03),
        ]);
      case BrushTip.watercolor:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final theta = math.atan2(v, u);
          final rim = 0.82 + 0.14 * noise.angular(theta, 5);
          final t = r / rim;
          if (t >= 1) return 0;
          final bloom = 0.55 + 0.45 * noise.fbm(u * 2.5, v * 2.5);
          return bloom * _smooth(1, 0.8, t);
        });
      case BrushTip.splatter:
        final random = math.Random(211);
        final drops = <_Dot>[
          for (var i = 0; i < 9; i++)
            _Dot(
              (random.nextDouble() - 0.5) * 1.0,
              (random.nextDouble() - 0.5) * 1.0,
              0.06 + random.nextDouble() * 0.16,
            ),
          for (var i = 0; i < 34; i++)
            () {
              final theta = random.nextDouble() * math.pi * 2;
              final d = 0.35 + random.nextDouble() * 0.58;
              return _Dot(
                math.cos(theta) * d,
                math.sin(theta) * d,
                0.012 + random.nextDouble() * 0.03,
              );
            }(),
        ];
        _dots(alpha, drops);
      case BrushTip.sparkle:
        _field(alpha, (u, v, x, y) {
          final r = math.sqrt(u * u + v * v);
          final core = math.exp(-math.pow(r / 0.14, 2));
          double ray(double along, double across) {
            final fade = math.max(0.0, 1 - along.abs());
            final width = 0.02 + 0.07 * fade;
            return math.exp(-math.pow(across / width, 2)) * fade * fade;
          }

          final d1 = (u + v) / math.sqrt2;
          final d2 = (u - v) / math.sqrt2;
          final a = core + ray(u, v) + ray(v, u) + 0.45 * (ray(d1 * 1.6, d2) + ray(d2 * 1.6, d1));
          return a.clamp(0.0, 1.0).toDouble();
        });
      case BrushTip.leaf:
        _field(alpha, (u, v, x, y) {
          if (u.abs() >= 0.98) return 0;
          final t = (u + 0.98) / 1.96;
          final half =
              0.44 * math.pow(math.sin(math.pi * t), 0.75).toDouble() * (1 - 0.25 * t);
          if (half <= 0) return 0;
          final edge = _smooth(half, half - 0.03, v.abs());
          final vein = v.abs() < 0.018 && u > -0.9 ? 0.72 : 1.0;
          final shade = 0.82 + 0.18 * (1 - (v / half).abs());
          return edge * vein * shade;
        });
    }
    return _toPremultipliedWhite(alpha);
  }

  static Uint8List generateGrain(BrushGrain grain) {
    const n = grainSize;
    final alpha = Float64List(n * n);
    final noise = _Noise(grain.index * 104729 + 3);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        double pit;
        switch (grain) {
          case BrushGrain.none:
            pit = 0;
          case BrushGrain.paper:
            final fine = noise.pixel(x, y);
            final tooth = noise.tiled(x / 4, y / 4, 64);
            pit = _smooth(0.5, 0.95, 0.5 * fine + 0.5 * tooth);
          case BrushGrain.canvas:
            // Linen: noise stretched along x for the weft and along y for
            // the warp — threads of uneven thickness, never a regular grid.
            final weft = noise.tiled2(x / 4, y / 1.6, 64, 160);
            final warp = noise.tiled2(x / 1.6, y / 4, 160, 64);
            final f = 0.4 * weft + 0.4 * warp + 0.2 * noise.pixel(x, y);
            pit = _smooth(0.42, 0.82, f);
          case BrushGrain.rough:
            final f = 0.5 * noise.tiled(x / 8, y / 8, 32) +
                0.3 * noise.tiled(x / 16, y / 16, 16) +
                0.2 * noise.pixel(x, y);
            pit = _smooth(0.45, 0.85, f);
        }
        alpha[y * n + x] = pit;
      }
    }
    return _toPremultipliedWhite(alpha);
  }

  static void _field(
    Float64List out,
    double Function(double u, double v, int x, int y) f,
  ) {
    const n = tipSize;
    for (var y = 0; y < n; y++) {
      final v = (y + 0.5) / n * 2 - 1;
      for (var x = 0; x < n; x++) {
        final u = (x + 0.5) / n * 2 - 1;
        out[y * n + x] = f(u, v, x, y).clamp(0.0, 1.0).toDouble();
      }
    }
  }

  static void _dots(Float64List out, List<_Dot> dots) {
    const n = tipSize;
    for (final dot in dots) {
      final cx = (dot.x + 1) / 2 * n;
      final cy = (dot.y + 1) / 2 * n;
      final r = dot.r / 2 * n;
      final x0 = math.max(0, (cx - r - 1).floor());
      final x1 = math.min(n - 1, (cx + r + 1).ceil());
      final y0 = math.max(0, (cy - r - 1).floor());
      final y1 = math.min(n - 1, (cy + r + 1).ceil());
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final d = math.sqrt(math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2));
          final a = (r + 0.5 - d).clamp(0.0, 1.0).toDouble();
          final i = y * n + x;
          if (a > out[i]) out[i] = a;
        }
      }
    }
  }

  static _Dot _gaussianDot(
    math.Random random, {
    required double spread,
    required double minR,
    required double maxR,
  }) {
    double gauss() {
      final u1 = math.max(1e-9, random.nextDouble());
      final u2 = random.nextDouble();
      return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    var x = gauss() * spread;
    var y = gauss() * spread;
    final d = math.sqrt(x * x + y * y);
    if (d > 0.92) {
      x *= 0.92 / d;
      y *= 0.92 / d;
    }
    return _Dot(x, y, minR + random.nextDouble() * (maxR - minR));
  }

  static Uint8List _toPremultipliedWhite(Float64List alpha) {
    final out = Uint8List(alpha.length * 4);
    for (var i = 0; i < alpha.length; i++) {
      final a = (alpha[i] * 255).round().clamp(0, 255);
      final o = i * 4;
      out[o] = a;
      out[o + 1] = a;
      out[o + 2] = a;
      out[o + 3] = a;
    }
    return out;
  }

  static double _smooth(double edge0, double edge1, double x) {
    if (edge0 == edge1) return x < edge0 ? 0 : 1;
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

class RawTextures {
  const RawTextures({required this.tips, required this.grains});
  final Map<BrushTip, Uint8List> tips;
  final Map<BrushGrain, Uint8List> grains;
}

class _Dot {
  const _Dot(this.x, this.y, this.r);
  final double x;
  final double y;
  final double r;
}

/// Deterministic hash noise. `tiled` wraps at its period so grain textures
/// repeat without a seam.
class _Noise {
  _Noise(this.seed);

  final int seed;

  double _hash(int x, int y) {
    var h = seed ^ (x * 374761393) ^ (y * 668265263);
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xFFFFFF) / 0xFFFFFF;
  }

  double pixel(int x, int y) => _hash(x, y);

  double value(double x, double y) => _lattice(x, y, null);

  double tiled(double x, double y, num period) => _lattice(x, y, period.round());

  double tiled2(double x, double y, int periodX, int periodY) =>
      _lattice(x, y, periodX, periodY);

  double fbm(double x, double y) =>
      0.55 * value(x, y) + 0.3 * value(x * 2.1, y * 2.1) + 0.15 * value(x * 4.3, y * 4.3);

  /// Smooth noise around a circle, for irregular tip outlines. Returns -1..1.
  double angular(double theta, int lobes) {
    final t = (theta + math.pi) / (2 * math.pi) * lobes;
    return _lattice(t, 0.5, lobes) * 2 - 1;
  }

  double _lattice(double x, double y, int? period, [int? periodY]) {
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;
    final py = periodY ?? period;
    int wrapX(int v) => period == null || period == 0 ? v : v % period;
    int wrapY(int v) => py == null || py == 0 ? v : v % py;
    final a = _hash(wrapX(x0), wrapY(y0));
    final b = _hash(wrapX(x0 + 1), wrapY(y0));
    final c = _hash(wrapX(x0), wrapY(y0 + 1));
    final d = _hash(wrapX(x0 + 1), wrapY(y0 + 1));
    final sx = fx * fx * (3 - 2 * fx);
    final sy = fy * fy * (3 - 2 * fy);
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
  }
}

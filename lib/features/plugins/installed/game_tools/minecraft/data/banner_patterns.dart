import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mc_dyes.dart';

/// Banner patterns drawn on the game's 20 × 40 banner grid. The shapes are
/// luma's own pixel drawings of each charge — no game textures are used.
class McBannerPattern {
  const McBannerPattern(this.id, this.name, {this.item});

  final String id;
  final String name;

  /// The banner pattern item the loom needs, if any.
  final String? item;
}

const kMcBannerPatterns = [
  McBannerPattern('stripe_bottom', 'Base'),
  McBannerPattern('stripe_top', 'Chief'),
  McBannerPattern('stripe_left', 'Pale Dexter'),
  McBannerPattern('stripe_right', 'Pale Sinister'),
  McBannerPattern('stripe_center', 'Pale'),
  McBannerPattern('stripe_middle', 'Fess'),
  McBannerPattern('stripe_downright', 'Bend'),
  McBannerPattern('stripe_downleft', 'Bend Sinister'),
  McBannerPattern('small_stripes', 'Paly'),
  McBannerPattern('cross', 'Saltire'),
  McBannerPattern('straight_cross', 'Cross'),
  McBannerPattern('diagonal_left', 'Per Bend Sinister'),
  McBannerPattern('diagonal_right', 'Per Bend'),
  McBannerPattern('diagonal_up_left', 'Per Bend Inverted'),
  McBannerPattern('diagonal_up_right', 'Per Bend Sinister Inverted'),
  McBannerPattern('half_vertical', 'Per Pale'),
  McBannerPattern('half_vertical_right', 'Per Pale Inverted'),
  McBannerPattern('half_horizontal', 'Per Fess'),
  McBannerPattern('half_horizontal_bottom', 'Per Fess Inverted'),
  McBannerPattern('square_bottom_left', 'Base Dexter Canton'),
  McBannerPattern('square_bottom_right', 'Base Sinister Canton'),
  McBannerPattern('square_top_left', 'Chief Dexter Canton'),
  McBannerPattern('square_top_right', 'Chief Sinister Canton'),
  McBannerPattern('triangle_bottom', 'Chevron'),
  McBannerPattern('triangle_top', 'Inverted Chevron'),
  McBannerPattern('triangles_bottom', 'Base Indented'),
  McBannerPattern('triangles_top', 'Chief Indented'),
  McBannerPattern('circle', 'Roundel'),
  McBannerPattern('rhombus', 'Lozenge'),
  McBannerPattern('border', 'Bordure'),
  McBannerPattern('curly_border', 'Bordure Indented', item: 'bordure_indented_banner_pattern'),
  McBannerPattern('bricks', 'Field Masoned', item: 'field_masoned_banner_pattern'),
  McBannerPattern('gradient', 'Gradient'),
  McBannerPattern('gradient_up', 'Base Gradient'),
  McBannerPattern('creeper', 'Creeper Charge', item: 'creeper_banner_pattern'),
  McBannerPattern('skull', 'Skull Charge', item: 'skull_banner_pattern'),
  McBannerPattern('flower', 'Flower Charge', item: 'flower_banner_pattern'),
  McBannerPattern('mojang', 'Thing', item: 'mojang_banner_pattern'),
  McBannerPattern('globe', 'Globe', item: 'globe_banner_pattern'),
  McBannerPattern('piglin', 'Snout', item: 'piglin_banner_pattern'),
  McBannerPattern('flow', 'Flow', item: 'flow_banner_pattern'),
  McBannerPattern('guster', 'Guster', item: 'guster_banner_pattern'),
];

McBannerPattern mcBannerPattern(String id) =>
    kMcBannerPatterns.firstWhere((p) => p.id == id);

const _creeper = [
  '........',
  '.XX..XX.',
  '.XX..XX.',
  '...XX...',
  '..XXXX..',
  '..XXXX..',
  '..X..X..',
  '........',
];

const _skull = [
  '..XXXXXX..',
  '.XXXXXXXX.',
  '.X..XX..X.',
  '.X..XX..X.',
  '.XXXXXXXX.',
  '..XX..XX..',
  '..XXXXXX..',
  '...X.X....',
  'X........X',
  '.XX....XX.',
  '...XXXX...',
  '...XXXX...',
  '.XX....XX.',
  'X........X',
];

const _snout = [
  '.XXXXXXXX.',
  'XXXXXXXXXX',
  'XX..XX..XX',
  'XX..XX..XX',
  'XXXXXXXXXX',
  '.XXXXXXXX.',
];

const _thing = [
  '....XXXX....',
  '..XXXXXXXX..',
  '.XXX....XXX.',
  'XXX.XXXX.XXX',
  'XX.XX..XX.XX',
  'XX.X.XX.X.XX',
  'XX.X.XX.X.XX',
  'XX.XX..XX.XX',
  'XXX.XXXX.XXX',
  '.XXX....XXX.',
  '..XXXXXXXX..',
  '....XXXX....',
];

bool _art(List<String> art, int x, int y, {required int left, required int top, int scale = 1}) {
  final ax = (x - left);
  final ay = (y - top);
  if (ax < 0 || ay < 0) return false;
  final gx = ax ~/ scale, gy = ay ~/ scale;
  if (gy >= art.length || gx >= art[gy].length) return false;
  return art[gy][gx] == 'X';
}

/// How much of the pixel at (x, y) the pattern covers, from 0 to 1. Only the
/// gradients use values between.
double mcBannerCoverage(String pattern, int x, int y) {
  final cx = x + 0.5, cy = y + 0.5;
  final inside = switch (pattern) {
    'base' => true,
    'stripe_bottom' => y >= 27,
    'stripe_top' => y < 13,
    'stripe_left' => x < 7,
    'stripe_right' => x >= 13,
    'stripe_center' => x >= 7 && x < 13,
    'stripe_middle' => y >= 14 && y < 26,
    'stripe_downright' => (cx - cy / 2).abs() < 2.6,
    'stripe_downleft' => (cx - (20 - cy / 2)).abs() < 2.6,
    'small_stripes' => (x ~/ 2) % 2 == 1 && y < 38,
    'cross' => (cx - cy / 2).abs() < 2.2 || (cx - (20 - cy / 2)).abs() < 2.2,
    'straight_cross' => (x >= 8 && x < 12) || (y >= 18 && y < 22),
    'diagonal_left' => cx / 20 + cy / 40 < 1,
    'diagonal_right' => cx / 20 > cy / 40,
    'diagonal_up_left' => cx / 20 < cy / 40,
    'diagonal_up_right' => cx / 20 + cy / 40 > 1,
    'half_vertical' => x < 10,
    'half_vertical_right' => x >= 10,
    'half_horizontal' => y < 20,
    'half_horizontal_bottom' => y >= 20,
    'square_bottom_left' => x < 8 && y >= 26,
    'square_bottom_right' => x >= 12 && y >= 26,
    'square_top_left' => x < 8 && y < 14,
    'square_top_right' => x >= 12 && y < 14,
    'triangle_bottom' => cy > 40 - (10 - (cx - 10).abs()) * 1.25,
    'triangle_top' => cy < (10 - (cx - 10).abs()) * 1.25,
    'triangles_bottom' => cy > 39 - (1 - (2 * (((x % 5) + 0.5) / 5) - 1).abs()) * 5,
    'triangles_top' => cy < 1 + (1 - (2 * (((x % 5) + 0.5) / 5) - 1).abs()) * 5,
    'circle' => math.pow(cx - 10, 2) + math.pow(cy - 20, 2) <= 4.6 * 4.6,
    'rhombus' => (cx - 10).abs() / 6.5 + (cy - 20).abs() / 12 <= 1,
    'border' => x < 1 || x >= 19 || y < 1 || y >= 39,
    'curly_border' => _curly(x, y),
    'bricks' => y % 4 == 3 || (x + ((y ~/ 4) % 2) * 3) % 6 == 0,
    'creeper' => _art(_creeper, x, y, left: 2, top: 12, scale: 2),
    'skull' => _art(_skull, x, y, left: 5, top: 13),
    'flower' => _flower(cx, cy),
    'mojang' => _art(_thing, x, y, left: 4, top: 14),
    'globe' => _globe(cx, cy),
    'piglin' => _art(_snout, x, y, left: 5, top: 17),
    'flow' => _spiral(cx, cy, turns: 2.4, band: 0.42),
    'guster' => _spiral(cx, cy, turns: 1.6, band: 0.36) || (y == 30 && x > 3 && x < 16),
    'gradient' || 'gradient_up' => true,
    _ => false,
  };
  if (!inside) return 0;
  return switch (pattern) {
    'gradient' => (1 - y / 39).clamp(0.0, 1.0),
    'gradient_up' => (y / 39).clamp(0.0, 1.0),
    _ => 1,
  };
}

bool _curly(int x, int y) {
  final d = [x, 19 - x, y, 39 - y].reduce(math.min);
  if (d == 0) return true;
  if (d == 1) return (x + y) % 2 == 0;
  return false;
}

bool _flower(double x, double y) {
  final dx = x - 10, dy = y - 20;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r <= 1.8) return true;
  if (r > 6.5) return false;
  for (var i = 0; i < 8; i++) {
    final pa = i * math.pi / 4;
    final px = 10 + math.cos(pa) * 4.6, py = 20 + math.sin(pa) * 4.6;
    if (math.pow(x - px, 2) + math.pow(y - py, 2) <= 2.1 * 2.1) return true;
  }
  return false;
}

bool _globe(double x, double y) {
  final dx = x - 10, dy = y - 20;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r > 7.2) return false;
  if (r > 6.1) return true;
  if (dy.abs() < 0.6 || (dy - 3.5).abs() < 0.5 || (dy + 3.5).abs() < 0.5) {
    return true;
  }
  return dx.abs() < 0.6 || (dx.abs() - 3.6 * math.sqrt(1 - math.min(1, dy * dy / 49))).abs() < 0.6;
}

bool _spiral(double x, double y, {required double turns, required double band}) {
  final dx = x - 10, dy = (y - 20) * 0.8;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r > 8.5 || r < 0.6) return r < 0.6;
  final a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi);
  final v = r / 8.5 * turns - a;
  return (v - v.floorToDouble()) < band;
}

/// One layer on a banner.
class McBannerLayer {
  McBannerLayer(this.pattern, this.color);
  String pattern;
  McDye color;
}

/// Paints a banner (or, with [shield], a shield) from its base colour and
/// layers, pixel for pixel on the 20 × 40 grid.
class McBannerPainter extends CustomPainter {
  McBannerPainter({
    required this.base,
    required this.layers,
    this.shield = false,
  });

  final McDye base;
  final List<McBannerLayer> layers;
  final bool shield;

  @override
  void paint(Canvas canvas, Size size) {
    const gw = 20, gh = 40;
    final sw = shield ? 12 : gw;
    final sh = shield ? 22 : gh;
    final cell = math.min(size.width / (sw + (shield ? 2 : 0)), size.height / (sh + (shield ? 2 : 3)));
    final ox = (size.width - sw * cell) / 2;
    final oy = shield ? (size.height - sh * cell) / 2 : cell * 2.2;

    if (!shield) {
      final pole = Paint()..color = const Color(0xFF6B4A2B);
      canvas.drawRect(
        Rect.fromLTWH(ox - cell, oy - cell * 1.6, sw * cell + 2 * cell, cell * 1.0),
        pole,
      );
      canvas.drawRect(
        Rect.fromLTWH(ox + sw * cell / 2 - cell * 0.5, oy - cell * 2.2, cell, cell * 0.8),
        pole,
      );
    } else {
      final rim = RRect.fromRectAndCorners(
        Rect.fromLTWH(ox - cell, oy - cell, (sw + 2) * cell, (sh + 2) * cell),
        bottomLeft: Radius.circular(cell * 5),
        bottomRight: Radius.circular(cell * 5),
        topLeft: Radius.circular(cell),
        topRight: Radius.circular(cell),
      );
      canvas.drawRRect(rim, Paint()..color = const Color(0xFF7A7A80));
    }

    final clip = shield
        ? (Path()
            ..addRRect(RRect.fromRectAndCorners(
              Rect.fromLTWH(ox, oy, sw * cell, sh * cell),
              bottomLeft: Radius.circular(cell * 4.5),
              bottomRight: Radius.circular(cell * 4.5),
            )))
        : (Path()..addRect(Rect.fromLTWH(ox, oy, sw * cell, sh * cell)));
    canvas.save();
    canvas.clipPath(clip);
    final paint = Paint();
    for (var y = 0; y < sh; y++) {
      for (var x = 0; x < sw; x++) {
        final bx = shield ? (x * gw / sw).floor() : x;
        final by = shield ? (y * gh / sh).floor() : y;
        var color = base.color;
        for (final layer in layers) {
          final cov = mcBannerCoverage(layer.pattern, bx, by);
          if (cov > 0) color = Color.lerp(color, layer.color.color, cov)!;
        }
        // A little fabric shading so flat colours still read as cloth.
        final shade = ((x * 7 + y * 13) % 5) * 0.012;
        paint.color = Color.lerp(color, Colors.black, shade + (y > sh - 2 ? 0.06 : 0))!;
        canvas.drawRect(
          Rect.fromLTWH(ox + x * cell, oy + y * cell, cell + 0.6, cell + 0.6),
          paint,
        );
      }
    }
    canvas.restore();
    canvas.drawPath(
      clip,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, cell * 0.25),
    );
  }

  @override
  bool shouldRepaint(McBannerPainter old) => true;
}

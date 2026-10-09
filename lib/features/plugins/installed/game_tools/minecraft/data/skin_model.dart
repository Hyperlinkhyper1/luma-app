import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A 64 × 64 skin held as ARGB pixels.
class McSkin {
  McSkin([Uint32List? pixels]) : pixels = pixels ?? Uint32List(64 * 64);

  final Uint32List pixels;

  int at(int x, int y) => pixels[y * 64 + x];
  void put(int x, int y, int argb) => pixels[y * 64 + x] = argb;

  McSkin copy() => McSkin(Uint32List.fromList(pixels));

  /// Reads a skin PNG: 64 × 64, or the legacy 64 × 32 layout (whose left
  /// arm and leg are mirrored from the right ones, as the game does).
  static McSkin? fromPng(Uint8List bytes) {
    final decoded = img.decodePng(bytes);
    if (decoded == null) return null;
    final scale = decoded.width ~/ 64;
    if (scale < 1 || decoded.width % 64 != 0) return null;
    final rows = decoded.height ~/ scale;
    if (rows != 64 && rows != 32) return null;
    final skin = McSkin();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < 64; x++) {
        final p = decoded.getPixel(x * scale, y * scale);
        skin.put(
          x,
          y,
          (p.a.toInt() << 24) | (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt(),
        );
      }
    }
    if (rows == 32) {
      _mirrorBox(skin, 0, 16, 4, 12, 4, 16, 48);
      _mirrorBox(skin, 40, 16, 4, 12, 4, 32, 48);
    }
    return skin;
  }

  static void _mirrorBox(McSkin s, int u, int v, int w, int h, int d, int tu, int tv) {
    for (var y = 0; y < h + d; y++) {
      for (var x = 0; x < 2 * (w + d); x++) {
        final sx = u + (2 * (w + d) - 1 - x);
        final sy = v + y;
        s.put(tu + x, tv + y, s.at(sx, sy));
      }
    }
  }

  Uint8List toPng() {
    final image = img.Image(width: 64, height: 64, numChannels: 4);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final c = at(x, y);
        image.setPixelRgba(x, y, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, (c >> 24) & 0xFF);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Fills connected pixels of the same colour as (x, y) with [argb].
  void flood(int x, int y, int argb) {
    final target = at(x, y);
    if (target == argb) return;
    final stack = <int>[y * 64 + x];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      if (pixels[i] != target) continue;
      pixels[i] = argb;
      final px = i % 64, py = i ~/ 64;
      if (px > 0) stack.add(i - 1);
      if (px < 63) stack.add(i + 1);
      if (py > 0) stack.add(i - 64);
      if (py < 63) stack.add(i + 64);
    }
  }
}

/// One cuboid of the player model, in 1/16-block pixels with y up and the
/// player facing +z.
class McSkinBox {
  const McSkinBox({
    required this.name,
    required this.x,
    required this.y,
    required this.z,
    required this.w,
    required this.h,
    required this.d,
    required this.u,
    required this.v,
    this.overlay = false,
  });

  final String name;
  final double x, y, z;
  final int w, h, d;
  final int u, v;
  final bool overlay;
}

List<McSkinBox> mcSkinBoxes({required bool slim}) {
  final arm = slim ? 3 : 4;
  return [
    const McSkinBox(name: 'Head', x: -4, y: 24, z: -4, w: 8, h: 8, d: 8, u: 0, v: 0),
    const McSkinBox(name: 'Body', x: -4, y: 12, z: -2, w: 8, h: 12, d: 4, u: 16, v: 16),
    McSkinBox(name: 'Right arm', x: -4.0 - arm, y: 12, z: -2, w: arm, h: 12, d: 4, u: 40, v: 16),
    McSkinBox(name: 'Left arm', x: 4, y: 12, z: -2, w: arm, h: 12, d: 4, u: 32, v: 48),
    const McSkinBox(name: 'Right leg', x: -4, y: 0, z: -2, w: 4, h: 12, d: 4, u: 0, v: 16),
    const McSkinBox(name: 'Left leg', x: 0, y: 0, z: -2, w: 4, h: 12, d: 4, u: 16, v: 48),
    const McSkinBox(name: 'Hat', x: -4, y: 24, z: -4, w: 8, h: 8, d: 8, u: 32, v: 0, overlay: true),
    const McSkinBox(name: 'Jacket', x: -4, y: 12, z: -2, w: 8, h: 12, d: 4, u: 16, v: 32, overlay: true),
    McSkinBox(name: 'Right sleeve', x: -4.0 - arm, y: 12, z: -2, w: arm, h: 12, d: 4, u: 40, v: 32, overlay: true),
    McSkinBox(name: 'Left sleeve', x: 4, y: 12, z: -2, w: arm, h: 12, d: 4, u: 48, v: 48, overlay: true),
    const McSkinBox(name: 'Right pants', x: -4, y: 0, z: -2, w: 4, h: 12, d: 4, u: 0, v: 32, overlay: true),
    const McSkinBox(name: 'Left pants', x: 0, y: 0, z: -2, w: 4, h: 12, d: 4, u: 0, v: 48, overlay: true),
  ];
}

class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
}

/// One face of a box: an origin corner and two edge vectors in model space,
/// and the texture rectangle stretched over it (texel (0,0) at [origin]).
class McSkinFace {
  const McSkinFace({
    required this.box,
    required this.origin,
    required this.across,
    required this.down,
    required this.normal,
    required this.u,
    required this.v,
    required this.tw,
    required this.th,
  });

  final McSkinBox box;
  final Vec3 origin;

  /// Along increasing texture u, and increasing texture v.
  final Vec3 across;
  final Vec3 down;
  final Vec3 normal;
  final int u, v, tw, th;
}

List<McSkinFace> mcSkinFaces(McSkinBox b) {
  final grow = b.overlay ? (b.name == 'Hat' ? 0.5 : 0.25) : 0.0;
  final x0 = b.x - grow, x1 = b.x + b.w + grow;
  final y0 = b.y - grow, y1 = b.y + b.h + grow;
  final z0 = b.z - grow, z1 = b.z + b.d + grow;
  final w = x1 - x0, h = y1 - y0, d = z1 - z0;
  return [
    // Front (+z): u runs −x → +x, v runs top → bottom.
    McSkinFace(box: b, origin: Vec3(x0, y1, z1), across: Vec3(w, 0, 0), down: Vec3(0, -h, 0),
        normal: const Vec3(0, 0, 1), u: b.u + b.d, v: b.v + b.d, tw: b.w, th: b.h),
    // Back (−z): u runs +x → −x.
    McSkinFace(box: b, origin: Vec3(x1, y1, z0), across: Vec3(-w, 0, 0), down: Vec3(0, -h, 0),
        normal: const Vec3(0, 0, -1), u: b.u + 2 * b.d + b.w, v: b.v + b.d, tw: b.w, th: b.h),
    // Right side (−x): u runs −z → +z.
    McSkinFace(box: b, origin: Vec3(x0, y1, z0), across: Vec3(0, 0, d), down: Vec3(0, -h, 0),
        normal: const Vec3(-1, 0, 0), u: b.u, v: b.v + b.d, tw: b.d, th: b.h),
    // Left side (+x): u runs +z → −z.
    McSkinFace(box: b, origin: Vec3(x1, y1, z1), across: Vec3(0, 0, -d), down: Vec3(0, -h, 0),
        normal: const Vec3(1, 0, 0), u: b.u + b.d + b.w, v: b.v + b.d, tw: b.d, th: b.h),
    // Top (+y): u runs −x → +x, v runs −z → +z.
    McSkinFace(box: b, origin: Vec3(x0, y1, z0), across: Vec3(w, 0, 0), down: Vec3(0, 0, d),
        normal: const Vec3(0, 1, 0), u: b.u + b.d, v: b.v, tw: b.w, th: b.d),
    // Bottom (−y): u runs −x → +x, v runs +z → −z.
    McSkinFace(box: b, origin: Vec3(x0, y0, z1), across: Vec3(w, 0, 0), down: Vec3(0, 0, -d),
        normal: const Vec3(0, -1, 0), u: b.u + b.d + b.w, v: b.v, tw: b.w, th: b.d),
  ];
}

/// A camera: yaw about y, then pitch about x, orthographic.
class McSkinCamera {
  const McSkinCamera(this.yaw, this.pitch);
  final double yaw;
  final double pitch;

  Vec3 apply(Vec3 p) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = p.x * cy + p.z * sy;
    final z1 = -p.x * sy + p.z * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = p.y * cp - z1 * sp;
    final z2 = p.y * sp + z1 * cp;
    return Vec3(x1, y2, z2);
  }
}

/// The luma default skin: an original character, drawn here pixel by pixel
/// so no game skin is ever shipped.
McSkin mcDefaultSkin() {
  final s = McSkin();
  void rect(int x, int y, int w, int h, int argb) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        s.put(i, j, argb);
      }
    }
  }

  void box(McSkinBox b, int argb) {
    rect(b.u + b.d, b.v, b.w * 2, b.d, argb);
    rect(b.u, b.v + b.d, 2 * (b.w + b.d), b.h, argb);
  }

  const skin = 0xFFE0AC8A, skinShade = 0xFFC98F6E;
  const hair = 0xFF3B2A20, shirt = 0xFF7C5AD9, shirtShade = 0xFF6446B8;
  const pants = 0xFF2E3A5C, shoe = 0xFF4A4A4A;
  final boxes = mcSkinBoxes(slim: false);
  box(boxes[0], skin);
  // Hair on top, back and the upper band of the face.
  rect(8, 0, 8, 8, hair);
  rect(0, 8, 32, 2, hair);
  rect(24, 8, 8, 8, hair);
  rect(0, 10, 2, 3, hair);
  rect(22, 10, 2, 3, hair);
  // Eyes and mouth on the front (8..16, 8..16).
  rect(9, 12, 2, 1, 0xFFFFFFFF);
  rect(10, 12, 1, 1, 0xFF3A6EA5);
  rect(13, 12, 2, 1, 0xFFFFFFFF);
  rect(13, 12, 1, 1, 0xFF3A6EA5);
  rect(11, 14, 2, 1, skinShade);
  rect(11, 15, 2, 1, 0xFF9C5A4A);
  box(boxes[1], shirt);
  rect(20, 30, 8, 2, shirtShade);
  box(boxes[2], skin);
  rect(40, 20, 16, 5, shirt);
  box(boxes[3], skin);
  rect(32, 52, 16, 5, shirt);
  box(boxes[4], pants);
  rect(0, 28, 16, 4, shoe);
  box(boxes[5], pants);
  rect(16, 60, 16, 4, shoe);
  return s;
}

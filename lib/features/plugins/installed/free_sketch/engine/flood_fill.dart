import 'dart:typed_data';

/// Scanline flood fill over raw RGBA pixels.
///
/// Returns a coverage mask (one byte per pixel, 0 or 255) of the region
/// connected to ([x], [y]) whose colour is within [tolerance] of the seed's.
/// The region is then grown by [grow] pixels: line art is antialiased, so
/// without growing, a fill stops one soft pixel short of every line and
/// leaves a pale halo between the fill and the ink.
Uint8List floodFillMask(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y, {
  double tolerance = 0.12,
  int grow = 1,
}) {
  final mask = Uint8List(width * height);
  if (x < 0 || y < 0 || x >= width || y >= height) return mask;
  final pixels = rgba.buffer.asUint32List(rgba.offsetInBytes, width * height);
  final seed = pixels[y * width + x];
  final limit = (tolerance.clamp(0.0, 1.0) * 255).round();

  bool matches(int index) {
    if (mask[index] != 0) return false;
    final p = pixels[index];
    if (p == seed) return true;
    if (limit == 0) return false;
    for (var shift = 0; shift < 32; shift += 8) {
      final a = (p >> shift) & 0xFF;
      final b = (seed >> shift) & 0xFF;
      if ((a - b).abs() > limit) return false;
    }
    return true;
  }

  final stack = <int>[y * width + x];
  while (stack.isNotEmpty) {
    final index = stack.removeLast();
    if (!matches(index)) continue;
    final row = index ~/ width;
    final rowStart = row * width;
    var left = index;
    while (left > rowStart && matches(left - 1)) {
      left--;
    }
    var right = index;
    final rowEnd = rowStart + width - 1;
    while (right < rowEnd && matches(right + 1)) {
      right++;
    }
    var aboveOpen = false;
    var belowOpen = false;
    for (var i = left; i <= right; i++) {
      mask[i] = 255;
      if (row > 0) {
        final up = i - width;
        if (matches(up)) {
          if (!aboveOpen) {
            stack.add(up);
            aboveOpen = true;
          }
        } else {
          aboveOpen = false;
        }
      }
      if (row < height - 1) {
        final down = i + width;
        if (matches(down)) {
          if (!belowOpen) {
            stack.add(down);
            belowOpen = true;
          }
        } else {
          belowOpen = false;
        }
      }
    }
  }

  var result = mask;
  for (var i = 0; i < grow; i++) {
    result = _dilate(result, width, height);
  }
  return result;
}

Uint8List _dilate(Uint8List mask, int width, int height) {
  final out = Uint8List.fromList(mask);
  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      if (mask[row + x] != 0) continue;
      if ((x > 0 && mask[row + x - 1] != 0) ||
          (x < width - 1 && mask[row + x + 1] != 0) ||
          (y > 0 && mask[row - width + x] != 0) ||
          (y < height - 1 && mask[row + width + x] != 0)) {
        out[row + x] = 255;
      }
    }
  }
  return out;
}

/// Tight bounds of the non-transparent pixels, or null when there are none.
/// Used to put the transform box around what is actually on a layer.
({int left, int top, int right, int bottom})? opaqueBounds(
  Uint8List rgba,
  int width,
  int height,
) {
  var left = width;
  var top = height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < height; y++) {
    final row = y * width * 4;
    for (var x = 0; x < width; x++) {
      if (rgba[row + x * 4 + 3] == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < 0) return null;
  return (left: left, top: top, right: right + 1, bottom: bottom + 1);
}

/// A mask as premultiplied white RGBA, ready to decode into an image that is
/// tinted with a `srcIn` colour filter.
Uint8List maskToRgba(Uint8List mask) {
  final out = Uint8List(mask.length * 4);
  for (var i = 0; i < mask.length; i++) {
    final a = mask[i];
    if (a == 0) continue;
    final o = i * 4;
    out[o] = a;
    out[o + 1] = a;
    out[o + 2] = a;
    out[o + 3] = a;
  }
  return out;
}

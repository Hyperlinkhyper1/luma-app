import 'dart:convert';
import 'dart:typed_data';

/// One layer for [encodePsd]: full-canvas straight (non-premultiplied) RGBA.
class PsdLayerData {
  const PsdLayerData({
    required this.name,
    required this.rgba,
    this.opacity = 1,
    this.blendKey = 'norm',
    this.visible = true,
    this.clipped = false,
    this.alphaLocked = false,
  });

  final String name;
  final Uint8List rgba;
  final double opacity;

  /// Photoshop's four-character blend key, e.g. `mul ` or `scrn`.
  final String blendKey;
  final bool visible;
  final bool clipped;
  final bool alphaLocked;
}

/// Writes a layered Photoshop document (PSD version 1, 8-bit RGB).
///
/// Layers are stored bottom to top, trimmed to the pixels they actually use
/// and PackBits-compressed, which is what keeps a mostly-transparent layer
/// down to a few kilobytes. [composite] is the flattened image that viewers
/// without layer support show; it is written opaque, over [compositeMatte]
/// wherever the artwork is transparent.
Uint8List encodePsd({
  required int width,
  required int height,
  required List<PsdLayerData> layers,
  required Uint8List composite,
  int compositeMatte = 0xFFFFFFFF,
}) {
  final out = _Writer();

  // File header.
  out.ascii('8BPS');
  out.u16(1);
  out.zeros(6);
  out.u16(3);
  out.u32(height);
  out.u32(width);
  out.u16(8);
  out.u16(3);

  // Color mode data, image resources.
  out.u32(0);
  out.u32(0);

  // Layer and mask information.
  final layerInfo = _layerInfo(width, height, layers);
  out.u32(4 + layerInfo.length + 4);
  out.u32(layerInfo.length);
  out.bytes(layerInfo);
  out.u32(0);

  // Merged image data, RLE: every row's byte count for every channel first,
  // then the rows.
  final planes = _compositePlanes(composite, width, height, compositeMatte);
  final rows = <Uint8List>[];
  for (final plane in planes) {
    for (var y = 0; y < height; y++) {
      rows.add(packBits(Uint8List.sublistView(plane, y * width, (y + 1) * width)));
    }
  }
  out.u16(1);
  for (final row in rows) {
    out.u16(row.length);
  }
  for (final row in rows) {
    out.bytes(row);
  }
  return out.take();
}

Uint8List _layerInfo(int width, int height, List<PsdLayerData> layers) {
  final records = _Writer();
  final channelData = _Writer();
  records.i16(layers.length);

  for (final layer in layers) {
    final box = _trim(layer.rgba, width, height);
    final channels = <int, Uint8List>{};
    if (box != null) {
      final w = box.right - box.left;
      final h = box.bottom - box.top;
      for (final (id, offset) in const [(-1, 3), (0, 0), (1, 1), (2, 2)]) {
        final encoded = _Writer();
        encoded.u16(1);
        final encodedRows = <Uint8List>[];
        final row = Uint8List(w);
        for (var y = 0; y < h; y++) {
          final base = ((box.top + y) * width + box.left) * 4 + offset;
          for (var x = 0; x < w; x++) {
            row[x] = layer.rgba[base + x * 4];
          }
          encodedRows.add(packBits(row));
        }
        for (final r in encodedRows) {
          encoded.u16(r.length);
        }
        for (final r in encodedRows) {
          encoded.bytes(r);
        }
        channels[id] = encoded.take();
      }
    } else {
      for (final id in const [-1, 0, 1, 2]) {
        channels[id] = Uint8List(2);
      }
    }

    records.i32(box?.top ?? 0);
    records.i32(box?.left ?? 0);
    records.i32(box?.bottom ?? 0);
    records.i32(box?.right ?? 0);
    records.u16(4);
    for (final id in const [-1, 0, 1, 2]) {
      records.i16(id);
      records.u32(channels[id]!.length);
    }
    records.ascii('8BIM');
    records.ascii(_blendKey(layer.blendKey));
    records.u8((layer.opacity.clamp(0.0, 1.0) * 255).round());
    records.u8(layer.clipped ? 1 : 0);
    var flags = 0x08;
    if (layer.alphaLocked) flags |= 0x01;
    // Despite the spec calling bit 1 "visible", every reader treats it as
    // "hidden".
    if (!layer.visible) flags |= 0x02;
    records.u8(flags);
    records.u8(0);

    final extra = _Writer();
    extra.u32(0);
    extra.u32(0);
    final name = _pascalName(layer.name);
    extra.bytes(name);
    extra.bytes(_unicodeName(layer.name));
    records.u32(extra.length);
    records.bytes(extra.take());

    for (final id in const [-1, 0, 1, 2]) {
      channelData.bytes(channels[id]!);
    }
  }

  final info = _Writer();
  info.bytes(records.take());
  info.bytes(channelData.take());
  if (info.length.isOdd) info.u8(0);
  return info.take();
}

String _blendKey(String key) => '$key    '.substring(0, 4);

/// The layer name as a Pascal string padded to a multiple of four bytes.
/// Photoshop reads the Unicode copy in `luni`; this one is for older readers.
Uint8List _pascalName(String name) {
  final ascii = [
    for (final unit in name.codeUnits.take(255)) unit < 128 ? unit : 0x3F,
  ];
  final total = 1 + ascii.length;
  final padded = (total + 3) & ~3;
  final out = Uint8List(padded);
  out[0] = ascii.length;
  out.setRange(1, 1 + ascii.length, ascii);
  return out;
}

Uint8List _unicodeName(String name) {
  final units = name.codeUnits;
  final body = _Writer();
  body.u32(units.length);
  for (final unit in units) {
    body.u16(unit);
  }
  while (body.length % 4 != 0) {
    body.u8(0);
  }
  final block = _Writer();
  block.ascii('8BIM');
  block.ascii('luni');
  block.u32(body.length);
  block.bytes(body.take());
  return block.take();
}

({int left, int top, int right, int bottom})? _trim(Uint8List rgba, int width, int height) {
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

List<Uint8List> _compositePlanes(Uint8List rgba, int width, int height, int matte) {
  final count = width * height;
  final r = Uint8List(count);
  final g = Uint8List(count);
  final b = Uint8List(count);
  final mr = (matte >> 16) & 0xFF;
  final mg = (matte >> 8) & 0xFF;
  final mb = matte & 0xFF;
  for (var i = 0; i < count; i++) {
    final o = i * 4;
    final a = rgba[o + 3];
    if (a == 255) {
      r[i] = rgba[o];
      g[i] = rgba[o + 1];
      b[i] = rgba[o + 2];
    } else {
      r[i] = (rgba[o] * a + mr * (255 - a) + 127) ~/ 255;
      g[i] = (rgba[o + 1] * a + mg * (255 - a) + 127) ~/ 255;
      b[i] = (rgba[o + 2] * a + mb * (255 - a) + 127) ~/ 255;
    }
  }
  return [r, g, b];
}

/// PackBits run-length encoding, as used by PSD and TIFF.
Uint8List packBits(Uint8List input) {
  final out = BytesBuilder(copy: false);
  final n = input.length;
  var i = 0;
  while (i < n) {
    var run = 1;
    while (i + run < n && run < 128 && input[i + run] == input[i]) {
      run++;
    }
    if (run >= 3) {
      out.addByte(257 - run);
      out.addByte(input[i]);
      i += run;
      continue;
    }
    final start = i;
    while (i < n && i - start < 128) {
      if (i + 2 < n && input[i] == input[i + 1] && input[i] == input[i + 2]) break;
      i++;
    }
    out.addByte(i - start - 1);
    out.add(Uint8List.sublistView(input, start, i));
  }
  return out.takeBytes();
}

/// Inverse of [packBits], for tests and for reading our own output back.
Uint8List unpackBits(Uint8List input, int expected) {
  final out = Uint8List(expected);
  var i = 0;
  var o = 0;
  while (i < input.length && o < expected) {
    final header = input[i++];
    if (header < 128) {
      final count = header + 1;
      out.setRange(o, o + count, input, i);
      i += count;
      o += count;
    } else if (header > 128) {
      final count = 257 - header;
      out.fillRange(o, o + count, input[i++]);
      o += count;
    }
  }
  return out;
}

class _Writer {
  final _builder = BytesBuilder();

  int get length => _builder.length;

  void u8(int v) => _builder.addByte(v & 0xFF);

  void u16(int v) {
    _builder.addByte((v >> 8) & 0xFF);
    _builder.addByte(v & 0xFF);
  }

  void i16(int v) => u16(v & 0xFFFF);

  void u32(int v) {
    _builder.addByte((v >> 24) & 0xFF);
    _builder.addByte((v >> 16) & 0xFF);
    _builder.addByte((v >> 8) & 0xFF);
    _builder.addByte(v & 0xFF);
  }

  void i32(int v) => u32(v & 0xFFFFFFFF);

  void ascii(String s) => _builder.add(latin1.encode(s));

  void zeros(int count) => _builder.add(Uint8List(count));

  void bytes(List<int> data) => _builder.add(data);

  Uint8List take() => _builder.takeBytes();
}

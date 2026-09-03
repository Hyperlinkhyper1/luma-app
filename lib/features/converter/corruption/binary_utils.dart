import 'dart:typed_data';

/// Deterministic 32-bit xorshift.
///
/// `dart:math`'s [Random] makes no promise that a given seed keeps producing
/// the same stream across SDK versions or platforms, and a corruption recipe is
/// worthless the moment the stream drifts. This one is fixed forever.
class Prng {
  Prng(int seed)
    : _state = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int _state;

  int next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x;
    return x;
  }

  int nextInt(int max) => max <= 0 ? 0 : next() % max;

  int nextByte() => next() & 0xFF;

  /// A byte in 1..255, so a XOR with it always changes something.
  int nextNonZeroByte() => (next() % 255) + 1;

  /// Fisher-Yates over `0..count-1`.
  List<int> permutation(int count) {
    final list = List<int>.generate(count, (i) => i);
    for (var i = count - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }
}

/// CRC-32 (IEEE 802.3) — the checksum PNG chunks and ZIP entries both use.
class Crc32 {
  Crc32._();

  static final Uint32List _table = _buildTable();

  static Uint32List _buildTable() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      table[i] = c;
    }
    return table;
  }

  static int compute(List<int> bytes, [int start = 0, int? end]) {
    final stop = end ?? bytes.length;
    var crc = 0xFFFFFFFF;
    for (var i = start; i < stop; i++) {
      crc = _table[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}

int readU16le(List<int> b, int o) => b[o] | (b[o + 1] << 8);

int readU32le(List<int> b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

int readU16be(List<int> b, int o) => (b[o] << 8) | b[o + 1];

int readU32be(List<int> b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

void writeU16le(List<int> b, int o, int v) {
  b[o] = v & 0xFF;
  b[o + 1] = (v >> 8) & 0xFF;
}

void writeU32le(List<int> b, int o, int v) {
  b[o] = v & 0xFF;
  b[o + 1] = (v >> 8) & 0xFF;
  b[o + 2] = (v >> 16) & 0xFF;
  b[o + 3] = (v >> 24) & 0xFF;
}

void writeU32be(List<int> b, int o, int v) {
  b[o] = (v >> 24) & 0xFF;
  b[o + 1] = (v >> 16) & 0xFF;
  b[o + 2] = (v >> 8) & 0xFF;
  b[o + 3] = v & 0xFF;
}

/// True when [bytes] contains [pattern] starting at [offset].
bool matchesAt(List<int> bytes, int offset, List<int> pattern) {
  if (offset < 0 || offset + pattern.length > bytes.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (bytes[offset + i] != pattern[i]) return false;
  }
  return true;
}

/// First index of [pattern] at or after [from], or -1.
int indexOfBytes(List<int> bytes, List<int> pattern, [int from = 0, int? to]) {
  if (pattern.isEmpty) return -1;
  final stop = (to ?? bytes.length) - pattern.length;
  final first = pattern[0];
  for (var i = from < 0 ? 0 : from; i <= stop; i++) {
    if (bytes[i] != first) continue;
    var ok = true;
    for (var j = 1; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

/// Last index of [pattern] at or before [from].
int lastIndexOfBytes(List<int> bytes, List<int> pattern, [int? from]) {
  if (pattern.isEmpty) return -1;
  var i = (from ?? bytes.length - pattern.length);
  if (i > bytes.length - pattern.length) i = bytes.length - pattern.length;
  for (; i >= 0; i--) {
    if (matchesAt(bytes, i, pattern)) return i;
  }
  return -1;
}

List<int> asciiBytes(String s) => s.codeUnits;

Uint8List concatBytes(List<List<int>> parts) {
  var total = 0;
  for (final p in parts) {
    total += p.length;
  }
  final out = Uint8List(total);
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

String formatOffset(int offset) =>
    '0x${offset.toRadixString(16).toUpperCase()}';

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatOffsetRange(int start, int length) =>
    '${formatSize(length)} at ${formatOffset(start)}';

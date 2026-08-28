import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A hand-rolled NBT (Named Binary Tag) codec covering both the big-endian
/// Java flavour and the little-endian Bedrock flavour, in both directions.
///
/// The read-only parser in the Minecraft launcher plugin only walks
/// `level.dat`, so it is deliberately lossy: every integer collapses to a
/// plain `int`. Round-tripping a schematic needs the exact tag *widths* back
/// out again — writing a palette index as a long where the format wants a
/// short produces a file no editor will open — so the tags here stay typed.
sealed class NbtTag {
  const NbtTag();

  /// The NBT wire type id for this tag.
  int get typeId;
}

class NbtByte extends NbtTag {
  const NbtByte(this.value);
  final int value;
  @override
  int get typeId => 1;
}

class NbtShort extends NbtTag {
  const NbtShort(this.value);
  final int value;
  @override
  int get typeId => 2;
}

class NbtInt extends NbtTag {
  const NbtInt(this.value);
  final int value;
  @override
  int get typeId => 3;
}

class NbtLong extends NbtTag {
  const NbtLong(this.value);
  final int value;
  @override
  int get typeId => 4;
}

class NbtFloat extends NbtTag {
  const NbtFloat(this.value);
  final double value;
  @override
  int get typeId => 5;
}

class NbtDouble extends NbtTag {
  const NbtDouble(this.value);
  final double value;
  @override
  int get typeId => 6;
}

class NbtByteArray extends NbtTag {
  const NbtByteArray(this.value);
  final Int8List value;
  @override
  int get typeId => 7;
}

class NbtString extends NbtTag {
  const NbtString(this.value);
  final String value;
  @override
  int get typeId => 8;
}

class NbtList extends NbtTag {
  const NbtList(this.elementType, this.items);

  /// The wire type of every element. NBT lists are homogeneous, and an empty
  /// list still carries a type (conventionally 0).
  final int elementType;
  final List<NbtTag> items;

  factory NbtList.of(List<NbtTag> items, {int emptyType = 0}) =>
      NbtList(items.isEmpty ? emptyType : items.first.typeId, items);

  @override
  int get typeId => 9;
}

class NbtIntArray extends NbtTag {
  const NbtIntArray(this.value);
  final Int32List value;
  @override
  int get typeId => 11;
}

class NbtLongArray extends NbtTag {
  const NbtLongArray(this.value);
  final Int64List value;
  @override
  int get typeId => 12;
}

class NbtCompound extends NbtTag {
  const NbtCompound(this.values);

  NbtCompound.empty() : values = <String, NbtTag>{};

  final Map<String, NbtTag> values;

  @override
  int get typeId => 10;

  NbtTag? operator [](String key) => values[key];
  void operator []=(String key, NbtTag tag) => values[key] = tag;
  bool has(String key) => values.containsKey(key);

  /// Reads any of the integer tag types as a Dart int.
  int? intValue(String key) {
    final tag = values[key];
    return switch (tag) {
      NbtByte(:final value) => value,
      NbtShort(:final value) => value,
      NbtInt(:final value) => value,
      NbtLong(:final value) => value,
      _ => null,
    };
  }

  /// Same as [intValue] but reinterpreted as unsigned 16-bit.
  ///
  /// Sponge and MCEdit store dimensions in a signed short, so a schematic
  /// wider than 32767 blocks reads back negative unless the sign bit is
  /// masked off.
  int? unsignedShortValue(String key) {
    final v = intValue(key);
    return v == null ? null : v & 0xFFFF;
  }

  String? stringValue(String key) {
    final tag = values[key];
    return tag is NbtString ? tag.value : null;
  }

  NbtCompound? compound(String key) {
    final tag = values[key];
    return tag is NbtCompound ? tag : null;
  }

  NbtList? list(String key) {
    final tag = values[key];
    return tag is NbtList ? tag : null;
  }

  Int8List? byteArray(String key) {
    final tag = values[key];
    return tag is NbtByteArray ? tag.value : null;
  }

  Int32List? intArray(String key) {
    final tag = values[key];
    return tag is NbtIntArray ? tag.value : null;
  }

  Int64List? longArray(String key) {
    final tag = values[key];
    return tag is NbtLongArray ? tag.value : null;
  }
}

/// A root tag plus the name it was stored under.
class NamedTag {
  const NamedTag(this.name, this.tag);
  final String name;
  final NbtTag tag;

  NbtCompound get asCompound => tag is NbtCompound
      ? tag as NbtCompound
      : throw const FormatException('The NBT root is not a compound tag.');
}

/// How an NBT document was framed on disk, so a re-write can match it.
enum NbtCompression { none, gzip, zlib }

class Nbt {
  const Nbt._();

  /// Strips gzip/zlib framing if present. Returns the plain NBT bytes.
  static (Uint8List, NbtCompression) decompress(Uint8List raw) {
    if (raw.length >= 2 && raw[0] == 0x1F && raw[1] == 0x8B) {
      return (GZipDecoder().decodeBytes(raw), NbtCompression.gzip);
    }
    // A zlib stream starts with a CMF byte whose low nibble is the
    // compression method (8 = deflate), and the two header bytes together
    // are a multiple of 31. An NBT root tag is 0x0A, so there is no clash.
    if (raw.length >= 2 &&
        (raw[0] & 0x0F) == 0x08 &&
        ((raw[0] << 8) | raw[1]) % 31 == 0) {
      return (
        Uint8List.fromList(ZLibDecoder().decodeBytes(raw)),
        NbtCompression.zlib,
      );
    }
    return (raw, NbtCompression.none);
  }

  static Uint8List compress(Uint8List plain, NbtCompression mode) =>
      switch (mode) {
        NbtCompression.none => plain,
        NbtCompression.gzip =>
          Uint8List.fromList(GZipEncoder().encode(plain, level: 6)),
        NbtCompression.zlib =>
          Uint8List.fromList(ZLibEncoder().encode(plain, level: 6)),
      };

  /// Parses a whole document, transparently decompressing it first.
  static NamedTag read(Uint8List raw, {Endian endian = Endian.big}) {
    final (plain, _) = decompress(raw);
    return _NbtReader(plain, endian).readRoot();
  }

  /// Serialises a document, optionally compressing it.
  static Uint8List write(
    NamedTag root, {
    Endian endian = Endian.big,
    NbtCompression compression = NbtCompression.gzip,
  }) {
    final writer = _NbtWriter(endian);
    writer.writeRoot(root);
    return compress(writer.takeBytes(), compression);
  }
}

class _NbtReader {
  _NbtReader(Uint8List bytes, this._endian)
      : _data = ByteData.sublistView(bytes);

  final ByteData _data;
  final Endian _endian;
  int _pos = 0;

  NamedTag readRoot() {
    final type = _u8();
    if (type != 10) {
      throw const FormatException(
        'This does not look like an NBT file: the root is not a compound tag.',
      );
    }
    final name = _string();
    return NamedTag(name, _compoundBody());
  }

  NbtCompound _compoundBody() {
    final map = <String, NbtTag>{};
    while (true) {
      final type = _u8();
      if (type == 0) break;
      final name = _string();
      map[name] = _payload(type);
    }
    return NbtCompound(map);
  }

  NbtTag _payload(int type) {
    switch (type) {
      case 1:
        return NbtByte(_i8());
      case 2:
        return NbtShort(_i16());
      case 3:
        return NbtInt(_i32());
      case 4:
        return NbtLong(_i64());
      case 5:
        return NbtFloat(_f32());
      case 6:
        return NbtDouble(_f64());
      case 7:
        final byteLen = _i32();
        _guardLength(byteLen, 1);
        final bytes = Int8List(byteLen);
        for (var i = 0; i < byteLen; i++) {
          bytes[i] = _i8();
        }
        return NbtByteArray(bytes);
      case 8:
        return NbtString(_string());
      case 9:
        final elementType = _u8();
        final listLen = _i32();
        _guardLength(listLen, 1);
        final items = <NbtTag>[];
        for (var i = 0; i < listLen; i++) {
          items.add(_payload(elementType));
        }
        return NbtList(elementType, items);
      case 10:
        return _compoundBody();
      case 11:
        final intLen = _i32();
        _guardLength(intLen, 4);
        final ints = Int32List(intLen);
        for (var i = 0; i < intLen; i++) {
          ints[i] = _i32();
        }
        return NbtIntArray(ints);
      case 12:
        final longLen = _i32();
        _guardLength(longLen, 8);
        final longs = Int64List(longLen);
        for (var i = 0; i < longLen; i++) {
          longs[i] = _i64();
        }
        return NbtLongArray(longs);
      default:
        throw FormatException('Unknown NBT tag type $type at byte $_pos.');
    }
  }

  /// A corrupt or misread length field would otherwise ask for a gigabyte
  /// list before the read fails, so sanity-check it against what is left.
  void _guardLength(int len, int elementBytes) {
    if (len < 0 || _pos + len * elementBytes > _data.lengthInBytes) {
      throw FormatException(
        'The file is truncated or not valid NBT (bad length $len at byte '
        '$_pos).',
      );
    }
  }

  int _u8() => _data.getUint8(_pos++);
  int _i8() => _data.getInt8(_pos++);

  int _i16() {
    final v = _data.getInt16(_pos, _endian);
    _pos += 2;
    return v;
  }

  int _i32() {
    final v = _data.getInt32(_pos, _endian);
    _pos += 4;
    return v;
  }

  int _i64() {
    final v = _data.getInt64(_pos, _endian);
    _pos += 8;
    return v;
  }

  double _f32() {
    final v = _data.getFloat32(_pos, _endian);
    _pos += 4;
    return v;
  }

  double _f64() {
    final v = _data.getFloat64(_pos, _endian);
    _pos += 8;
    return v;
  }

  String _string() {
    final len = _data.getUint16(_pos, _endian);
    _pos += 2;
    _guardLength(len, 1);
    final bytes = Uint8List.sublistView(_data, _pos, _pos + len);
    _pos += len;
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }
}

class _NbtWriter {
  _NbtWriter(this._endian);

  final Endian _endian;

  // Must copy: every scalar is encoded through the one reusable [_scratch]
  // buffer, and a non-copying builder would hold references to it rather than
  // its contents, so the whole file would end up as the last value written.
  final BytesBuilder _out = BytesBuilder(copy: true);
  final Uint8List _scratch = Uint8List(8);
  late final ByteData _scratchView = ByteData.sublistView(_scratch);

  Uint8List takeBytes() => _out.takeBytes();

  void writeRoot(NamedTag root) {
    _out.addByte(root.tag.typeId);
    _string(root.name);
    _payload(root.tag);
  }

  void _payload(NbtTag tag) {
    switch (tag) {
      case NbtByte(:final value):
        _out.addByte(value & 0xFF);
      case NbtShort(:final value):
        _emit(2, (d) => d.setInt16(0, _wrapSigned(value, 16), _endian));
      case NbtInt(:final value):
        _emit(4, (d) => d.setInt32(0, _wrapSigned(value, 32), _endian));
      case NbtLong(:final value):
        _emit(8, (d) => d.setInt64(0, value, _endian));
      case NbtFloat(:final value):
        _emit(4, (d) => d.setFloat32(0, value, _endian));
      case NbtDouble(:final value):
        _emit(8, (d) => d.setFloat64(0, value, _endian));
      case NbtByteArray(:final value):
        _int32(value.length);
        _out.add(Uint8List.sublistView(value));
      case NbtString(:final value):
        _string(value);
      case NbtList(:final elementType, :final items):
        _out.addByte(items.isEmpty ? elementType : items.first.typeId);
        _int32(items.length);
        for (final item in items) {
          _payload(item);
        }
      case NbtCompound(:final values):
        values.forEach((name, child) {
          _out.addByte(child.typeId);
          _string(name);
          _payload(child);
        });
        _out.addByte(0);
      case NbtIntArray(:final value):
        _int32(value.length);
        for (final v in value) {
          _int32(v);
        }
      case NbtLongArray(:final value):
        _int32(value.length);
        for (final v in value) {
          _emit(8, (d) => d.setInt64(0, v, _endian));
        }
    }
  }

  void _emit(int byteCount, void Function(ByteData) encode) {
    encode(_scratchView);
    _out.add(Uint8List.sublistView(_scratch, 0, byteCount));
  }

  /// Wraps an out-of-range value into the tag's width the way the game does,
  /// rather than letting [ByteData] throw mid-write and leave a partial file.
  int _wrapSigned(int value, int bits) {
    final masked = value & ((1 << bits) - 1);
    final signBit = 1 << (bits - 1);
    return (masked & signBit) != 0 ? masked - (1 << bits) : masked;
  }

  void _int32(int value) {
    _emit(4, (d) => d.setInt32(0, _wrapSigned(value, 32), _endian));
  }

  void _string(String value) {
    final bytes = utf8.encode(value);
    _emit(2, (d) => d.setUint16(0, bytes.length, _endian));
    _out.add(bytes);
  }
}

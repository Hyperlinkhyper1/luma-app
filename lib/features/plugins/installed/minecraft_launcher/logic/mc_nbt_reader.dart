import 'dart:convert';
import 'dart:typed_data';

/// A tiny, read-only NBT (Named Binary Tag) parser — just enough to read
/// `level.dat`'s world metadata. No package on pub covers this, so it's
/// hand-rolled: NBT is a simple big-endian, self-describing tree format
/// (tag type byte + name + payload, recursively for compounds/lists), which
/// is straightforward to walk without a general-purpose library.
///
/// Compounds and lists become [Map]/[List]; everything else becomes the
/// natural Dart numeric/String type. Byte/Int/Long arrays become typed lists.
class NbtReader {
  NbtReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);
  final ByteData _data;
  int _pos = 0;

  /// Parses a full NBT document, returning the root compound's contents
  /// (the outer nameless compound tag itself is unwrapped).
  Map<String, dynamic> parseRoot() {
    final type = _readU8();
    if (type != 10) {
      throw const FormatException('Expected a root compound tag.');
    }
    _readString(); // root tag name, conventionally empty
    return _readCompoundBody();
  }

  Map<String, dynamic> _readCompoundBody() {
    final map = <String, dynamic>{};
    while (true) {
      final type = _readU8();
      if (type == 0) break; // TAG_End
      final name = _readString();
      map[name] = _readPayload(type);
    }
    return map;
  }

  dynamic _readPayload(int type) {
    switch (type) {
      case 1:
        return _readI8();
      case 2:
        return _readI16();
      case 3:
        return _readI32();
      case 4:
        return _readI64();
      case 5:
        return _readF32();
      case 6:
        return _readF64();
      case 7:
        final len = _readI32();
        final bytes = List<int>.generate(len, (_) => _readI8());
        return bytes;
      case 8:
        return _readString();
      case 9:
        final elementType = _readU8();
        final len = _readI32();
        return List<dynamic>.generate(len, (_) => _readPayload(elementType));
      case 10:
        return _readCompoundBody();
      case 11:
        final len = _readI32();
        return List<int>.generate(len, (_) => _readI32());
      case 12:
        final len = _readI32();
        return List<int>.generate(len, (_) => _readI64());
      default:
        throw FormatException('Unknown NBT tag type $type at byte $_pos.');
    }
  }

  int _readU8() => _data.getUint8(_pos++);
  int _readI8() => _data.getInt8(_pos++);

  int _readI16() {
    final v = _data.getInt16(_pos, Endian.big);
    _pos += 2;
    return v;
  }

  int _readI32() {
    final v = _data.getInt32(_pos, Endian.big);
    _pos += 4;
    return v;
  }

  int _readI64() {
    final v = _data.getInt64(_pos, Endian.big);
    _pos += 8;
    return v;
  }

  double _readF32() {
    final v = _data.getFloat32(_pos, Endian.big);
    _pos += 4;
    return v;
  }

  double _readF64() {
    final v = _data.getFloat64(_pos, Endian.big);
    _pos += 8;
    return v;
  }

  String _readString() {
    final len = _data.getUint16(_pos, Endian.big);
    _pos += 2;
    final bytes = Uint8List.sublistView(_data, _pos, _pos + len);
    _pos += len;
    return utf8.decode(bytes);
  }
}

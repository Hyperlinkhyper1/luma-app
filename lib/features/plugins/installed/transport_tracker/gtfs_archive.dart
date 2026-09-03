import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown when the static GTFS archive can't be read the way this code needs.
class GtfsArchiveException implements Exception {
  GtfsArchiveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads individual members out of the national GTFS zip over HTTP, without
/// downloading the archive.
///
/// The file is ~215 MB, but it is a plain zip served with `Accept-Ranges`.
/// Reading its central directory takes two small range requests, after which
/// a single member can be fetched on its own. That keeps `stops.txt` to about
/// 1.4 MB and `routes.txt` to 40 KB, instead of 215 MB for either.
///
/// The two enormous members are deliberately never requested: `stop_times.txt`
/// is 1 GB and `shapes.txt` is 255 MB, and the realtime feeds already provide
/// what those would be used for.
class GtfsArchive {
  static const url = 'https://gtfs.ovapi.nl/nl/gtfs-nl.zip';

  /// Downloads one member and returns its decompressed bytes.
  static Future<Uint8List> fetchMember(
    String name, {
    http.Client? httpClient,
    void Function(int bytes)? onProgress,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final member = await _locate(client, name, onProgress);
      final bytes = await _rangeGet(
        client,
        member.dataStart,
        member.dataStart + member.compressedSize - 1,
      );
      onProgress?.call(bytes.length);
      // Zip stores deflate without a zlib wrapper.
      return member.method == 0
          ? bytes
          : Uint8List.fromList(ZLibCodec(raw: true).decode(bytes));
    } finally {
      if (httpClient == null) client.close();
    }
  }

  static Future<Uint8List> _rangeGet(
      http.Client client, int start, int end) async {
    final response = await client.get(
      Uri.parse(url),
      headers: {'Range': 'bytes=$start-$end'},
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 206 && response.statusCode != 200) {
      throw GtfsArchiveException(
          'The transit archive does not support partial downloads '
          '(HTTP ${response.statusCode}).');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  static Future<int> _size(http.Client client) async {
    final response =
        await client.head(Uri.parse(url)).timeout(const Duration(seconds: 30));
    final length = response.headers['content-length'];
    final size = length == null ? null : int.tryParse(length);
    if (size == null || size <= 0) {
      throw GtfsArchiveException('Could not determine the archive size.');
    }
    return size;
  }

  static Future<({int dataStart, int compressedSize, int method})> _locate(
    http.Client client,
    String name,
    void Function(int bytes)? onProgress,
  ) async {
    final size = await _size(client);

    // The End Of Central Directory record sits within the last 64 KB.
    const tailLength = 65536;
    final tailStart = size - tailLength < 0 ? 0 : size - tailLength;
    final tail = await _rangeGet(client, tailStart, size - 1);
    final eocd = _lastIndexOfSignature(tail, 0x06054b50);
    if (eocd < 0) {
      throw GtfsArchiveException('The archive index is unreadable.');
    }

    final view = ByteData.sublistView(tail);
    var entryCount = view.getUint16(eocd + 10, Endian.little);
    var cdSize = view.getUint32(eocd + 12, Endian.little);
    var cdOffset = view.getUint32(eocd + 16, Endian.little);

    // Saturated 32-bit fields mean the real values live in the zip64 record.
    if (cdOffset == 0xffffffff || cdSize == 0xffffffff || entryCount == 0xffff) {
      final locator = _lastIndexOfSignature(tail, 0x07064b50);
      if (locator < 0) {
        throw GtfsArchiveException('The archive index is unreadable (zip64).');
      }
      final z64Offset = view.getUint64(locator + 8, Endian.little);
      final z64 = await _rangeGet(client, z64Offset, z64Offset + 55);
      final z64View = ByteData.sublistView(z64);
      cdSize = z64View.getUint64(40, Endian.little);
      cdOffset = z64View.getUint64(48, Endian.little);
    }

    final centralDirectory =
        await _rangeGet(client, cdOffset, cdOffset + cdSize - 1);
    onProgress?.call(centralDirectory.length);

    final entry = _findEntry(centralDirectory, name);
    if (entry == null) {
      throw GtfsArchiveException('$name is not in the archive.');
    }

    // The local header repeats the name/extra lengths, and they can differ
    // from the central copy, so the data offset must be read from it.
    final localHeader =
        await _rangeGet(client, entry.localOffset, entry.localOffset + 29);
    final lhView = ByteData.sublistView(localHeader);
    final nameLength = lhView.getUint16(26, Endian.little);
    final extraLength = lhView.getUint16(28, Endian.little);

    return (
      dataStart: entry.localOffset + 30 + nameLength + extraLength,
      compressedSize: entry.compressedSize,
      method: entry.method,
    );
  }

  static int _lastIndexOfSignature(Uint8List bytes, int signature) {
    final b0 = signature & 0xff;
    final b1 = (signature >> 8) & 0xff;
    final b2 = (signature >> 16) & 0xff;
    final b3 = (signature >> 24) & 0xff;
    for (var i = bytes.length - 4; i >= 0; i--) {
      if (bytes[i] == b0 &&
          bytes[i + 1] == b1 &&
          bytes[i + 2] == b2 &&
          bytes[i + 3] == b3) {
        return i;
      }
    }
    return -1;
  }

  static ({int localOffset, int compressedSize, int method})? _findEntry(
      Uint8List cd, String name) {
    final view = ByteData.sublistView(cd);
    var p = 0;
    while (p + 46 <= cd.length &&
        view.getUint32(p, Endian.little) == 0x02014b50) {
      final method = view.getUint16(p + 10, Endian.little);
      var compressedSize = view.getUint32(p + 20, Endian.little);
      var uncompressedSize = view.getUint32(p + 24, Endian.little);
      final nameLength = view.getUint16(p + 28, Endian.little);
      final extraLength = view.getUint16(p + 30, Endian.little);
      final commentLength = view.getUint16(p + 32, Endian.little);
      var localOffset = view.getUint32(p + 42, Endian.little);
      final entryName = utf8.decode(cd.sublist(p + 46, p + 46 + nameLength),
          allowMalformed: true);

      if (localOffset == 0xffffffff ||
          compressedSize == 0xffffffff ||
          uncompressedSize == 0xffffffff) {
        var e = p + 46 + nameLength;
        final extraEnd = e + extraLength;
        while (e + 4 <= extraEnd) {
          final tag = view.getUint16(e, Endian.little);
          final tagSize = view.getUint16(e + 2, Endian.little);
          if (tag == 0x0001) {
            var q = e + 4;
            if (uncompressedSize == 0xffffffff) {
              uncompressedSize = view.getUint64(q, Endian.little);
              q += 8;
            }
            if (compressedSize == 0xffffffff) {
              compressedSize = view.getUint64(q, Endian.little);
              q += 8;
            }
            if (localOffset == 0xffffffff) {
              localOffset = view.getUint64(q, Endian.little);
            }
          }
          e += 4 + tagSize;
        }
      }

      if (entryName == name) {
        return (
          localOffset: localOffset,
          compressedSize: compressedSize,
          method: method,
        );
      }
      p += 46 + nameLength + extraLength + commentLength;
    }
    return null;
  }

  /// Splits one CSV record, honouring quoted fields and doubled quotes.
  static List<String> splitCsvLine(String line) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        out.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    out.add(buffer.toString());
    return out;
  }
}

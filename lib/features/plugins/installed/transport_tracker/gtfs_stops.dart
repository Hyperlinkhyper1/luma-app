import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A stop or station from the static GTFS dataset.
class GtfsStop {
  const GtfsStop(this.id, this.name, this.lat, this.lon);

  final String id;
  final String name;
  final double lat;
  final double lon;

  /// Some entries in the national dataset — mostly cross-border stations
  /// such as Dortmund Hbf and Hannover Hbf — are published with no
  /// coordinates at all, which the file records as 0,0. That is a real
  /// place in the Gulf of Guinea, so it must never be used to position
  /// anything; the name is still perfectly good for a stop list.
  bool get hasPosition => lat != 0 || lon != 0;
}

/// Thrown when the archive can't be read the way this class needs.
class GtfsStopsException implements Exception {
  GtfsStopsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Stop names and coordinates for the Dutch network, fetched once and cached.
///
/// The realtime feeds identify stops only by id, so names have to come from
/// the static GTFS dataset. That archive is ~215 MB — but it is a plain zip
/// served with `Accept-Ranges`, and only `stops.txt` is needed. So instead of
/// downloading it, this reads the zip's central directory with a couple of
/// range requests and then pulls down just that one member: **about 1.4 MB
/// compressed**, rather than 215 MB. (`stop_times.txt` in the same archive is
/// 1 GB on its own and is deliberately never touched — the live feeds already
/// carry the stop sequence and times.)
class GtfsStopsCache {
  GtfsStopsCache._(this._stops, this.fetchedAt);

  /// Builds a cache straight from CSV, for tests that need known stops
  /// without touching the network or the filesystem.
  @visibleForTesting
  factory GtfsStopsCache.fromCsv(String csv) =>
      GtfsStopsCache._(_parseStopsCsv(csv), DateTime.now());

  final Map<String, GtfsStop> _stops;
  final DateTime? fetchedAt;

  static const archiveUrl = 'https://gtfs.ovapi.nl/nl/gtfs-nl.zip';
  static const _memberName = 'stops.txt';
  static const _cacheFileName = 'luma_gtfs_stops.tsv';

  /// Stop names change rarely; a week keeps the cache fresh without making
  /// the download a recurring cost.
  static const maxAge = Duration(days: 7);

  int get length => _stops.length;
  bool get isEmpty => _stops.isEmpty;
  bool get isStale =>
      fetchedAt == null || DateTime.now().difference(fetchedAt!) > maxAge;

  GtfsStop? operator [](String? stopId) =>
      stopId == null ? null : _stops[stopId];

  /// Resolves a stop id, tolerating the `stoparea:` / `IFF:` prefixes the
  /// Dutch feeds sometimes use on parent stations.
  GtfsStop? lookup(String? stopId) {
    if (stopId == null) return null;
    final direct = _stops[stopId];
    if (direct != null) return direct;
    final colon = stopId.lastIndexOf(':');
    if (colon >= 0 && colon < stopId.length - 1) {
      return _stops[stopId.substring(colon + 1)];
    }
    return null;
  }

  /// [directory] overrides where the cache lives; it exists so tests can
  /// point at a scratch folder instead of the app support directory.
  static Future<File> _cacheFile([Directory? directory]) async {
    final dir = directory ?? await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_cacheFileName');
  }

  /// Loads the cached copy, or an empty cache when there is none.
  static Future<GtfsStopsCache> load({Directory? directory}) async {
    try {
      final file = await _cacheFile(directory);
      if (!await file.exists()) return GtfsStopsCache._({}, null);
      final stat = await file.stat();
      final stops = _parseCacheFile(await file.readAsString());
      return GtfsStopsCache._(stops, stat.modified);
    } catch (_) {
      return GtfsStopsCache._({}, null);
    }
  }

  /// Downloads `stops.txt` out of the archive and replaces the cache.
  ///
  /// [onProgress] reports bytes downloaded so a long fetch can show progress.
  static Future<GtfsStopsCache> download({
    http.Client? httpClient,
    void Function(int bytes)? onProgress,
    Directory? directory,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final member = await _locateMember(client, onProgress);
      final bytes = await _rangeGet(
        client,
        member.dataStart,
        member.dataStart + member.compressedSize - 1,
      );
      onProgress?.call(bytes.length);

      final raw = member.method == 0
          ? bytes
          // Zip stores deflate without a zlib wrapper.
          : Uint8List.fromList(ZLibCodec(raw: true).decode(bytes));

      final stops = _parseStopsCsv(utf8.decode(raw, allowMalformed: true));
      if (stops.isEmpty) {
        throw GtfsStopsException('The stop list came back empty.');
      }
      final file = await _cacheFile(directory);
      await file.writeAsString(_encodeCacheFile(stops), flush: true);
      return GtfsStopsCache._(stops, DateTime.now());
    } finally {
      if (httpClient == null) client.close();
    }
  }

  // ---- Zip central-directory reading over HTTP ranges -------------------

  static Future<Uint8List> _rangeGet(
      http.Client client, int start, int end) async {
    final response = await client.get(
      Uri.parse(archiveUrl),
      headers: {'Range': 'bytes=$start-$end'},
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 206 && response.statusCode != 200) {
      throw GtfsStopsException(
          'The stop archive does not support partial downloads '
          '(HTTP ${response.statusCode}).');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  static Future<int> _archiveSize(http.Client client) async {
    final response = await client
        .head(Uri.parse(archiveUrl))
        .timeout(const Duration(seconds: 30));
    final length = response.headers['content-length'];
    final size = length == null ? null : int.tryParse(length);
    if (size == null || size <= 0) {
      throw GtfsStopsException('Could not determine the archive size.');
    }
    return size;
  }

  static Future<
      ({int dataStart, int compressedSize, int method})> _locateMember(
    http.Client client,
    void Function(int bytes)? onProgress,
  ) async {
    final size = await _archiveSize(client);

    // The End Of Central Directory record sits within the last 64 KB.
    const tailLength = 65536;
    final tailStart = size - tailLength < 0 ? 0 : size - tailLength;
    final tail = await _rangeGet(client, tailStart, size - 1);
    final eocd = _lastIndexOfSignature(tail, 0x06054b50);
    if (eocd < 0) throw GtfsStopsException('The archive index is unreadable.');

    final view = ByteData.sublistView(tail);
    var entryCount = view.getUint16(eocd + 10, Endian.little);
    var cdSize = view.getUint32(eocd + 12, Endian.little);
    var cdOffset = view.getUint32(eocd + 16, Endian.little);

    // Saturated 32-bit fields mean the real values live in the zip64 record.
    if (cdOffset == 0xffffffff || cdSize == 0xffffffff || entryCount == 0xffff) {
      final locator = _lastIndexOfSignature(tail, 0x07064b50);
      if (locator < 0) {
        throw GtfsStopsException('The archive index is unreadable (zip64).');
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

    final member = _findMember(centralDirectory, _memberName);
    if (member == null) {
      throw GtfsStopsException('$_memberName is not in the archive.');
    }

    // The local header repeats the name/extra lengths, and they can differ
    // from the central copy, so the data offset must be read from it.
    final localHeader =
        await _rangeGet(client, member.localOffset, member.localOffset + 29);
    final lhView = ByteData.sublistView(localHeader);
    final nameLength = lhView.getUint16(26, Endian.little);
    final extraLength = lhView.getUint16(28, Endian.little);

    return (
      dataStart: member.localOffset + 30 + nameLength + extraLength,
      compressedSize: member.compressedSize,
      method: member.method,
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

  static ({int localOffset, int compressedSize, int method})? _findMember(
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
      final entryName =
          utf8.decode(cd.sublist(p + 46, p + 46 + nameLength), allowMalformed: true);

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

  // ---- Parsing ----------------------------------------------------------

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

  static Map<String, GtfsStop> _parseStopsCsv(String csv) {
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return {};
    final header = splitCsvLine(lines.first);
    final idIndex = header.indexOf('stop_id');
    final nameIndex = header.indexOf('stop_name');
    final latIndex = header.indexOf('stop_lat');
    final lonIndex = header.indexOf('stop_lon');
    if (idIndex < 0 || nameIndex < 0 || latIndex < 0 || lonIndex < 0) {
      throw GtfsStopsException('The stop list is missing expected columns.');
    }

    final out = <String, GtfsStop>{};
    final maxIndex = [idIndex, nameIndex, latIndex, lonIndex]
        .reduce((a, b) => a > b ? a : b);
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final fields = splitCsvLine(line);
      if (fields.length <= maxIndex) continue;
      final id = fields[idIndex];
      final lat = double.tryParse(fields[latIndex]);
      final lon = double.tryParse(fields[lonIndex]);
      if (id.isEmpty || lat == null || lon == null) continue;
      out[id] = GtfsStop(id, fields[nameIndex], lat, lon);
    }
    return out;
  }

  /// Tab-separated, because stop names contain commas but never tabs. Much
  /// cheaper to re-read than the original CSV.
  static String _encodeCacheFile(Map<String, GtfsStop> stops) {
    final buffer = StringBuffer();
    for (final stop in stops.values) {
      buffer
        ..write(stop.id)
        ..write('\t')
        ..write(stop.name.replaceAll('\t', ' '))
        ..write('\t')
        ..write(stop.lat)
        ..write('\t')
        ..write(stop.lon)
        ..write('\n');
    }
    return buffer.toString();
  }

  static Map<String, GtfsStop> _parseCacheFile(String contents) {
    final out = <String, GtfsStop>{};
    for (final line in const LineSplitter().convert(contents)) {
      if (line.isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 4) continue;
      final lat = double.tryParse(parts[2]);
      final lon = double.tryParse(parts[3]);
      if (lat == null || lon == null) continue;
      out[parts[0]] = GtfsStop(parts[0], parts[1], lat, lon);
    }
    return out;
  }
}

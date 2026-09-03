import 'dart:convert';

/// One country for [encodeWorldMap]: outlines are plain flat lists of
/// `[lon, lat, lon, lat, …]` degrees.
class FixtureCountry {
  const FixtureCountry(this.code, this.name, this.region, this.rings);

  final String code;
  final String name;
  final String region;
  final List<List<double>> rings;
}

/// Builds an asset in the same shape as `assets/world/world_countries.json`.
///
/// This is deliberately a second, independent implementation of the encoder
/// the Python build script uses, so the tests pin the decoder rather than
/// echoing it back at itself.
String encodeWorldMap(List<FixtureCountry> countries, {int q = 1}) {
  final blob = <int>[];

  void writeVarint(int value) {
    var v = (value << 1) ^ (value >> 63); // zigzag
    while (true) {
      final byte = v & 0x7F;
      v >>= 7;
      if (v != 0) {
        blob.add(byte | 0x80);
      } else {
        blob.add(byte);
        return;
      }
    }
  }

  final entries = <Map<String, Object?>>[];
  for (final country in countries) {
    for (final ring in country.rings) {
      var x = 0, y = 0;
      for (var i = 0; i < ring.length; i += 2) {
        final nextX = (ring[i] * q).round();
        final nextY = (ring[i + 1] * q).round();
        writeVarint(nextX - x);
        writeVarint(nextY - y);
        x = nextX;
        y = nextY;
      }
    }
    entries.add({
      'c': country.code,
      'n': country.name,
      'r': country.region,
      'p': [for (final ring in country.rings) ring.length ~/ 2],
    });
  }

  return jsonEncode({
    'q': q,
    'countries': entries,
    'points': base64Encode(blob),
  });
}

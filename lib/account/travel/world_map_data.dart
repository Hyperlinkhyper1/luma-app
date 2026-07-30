import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

/// Where the bundled world outline lives (built from public-domain Natural
/// Earth 1:10m country polygons, simplified, quantised and delta-encoded —
/// see `assets/world/README.md`).
const String kWorldMapAsset = 'assets/world/world_countries.json';

/// One country's outline, already projected into unit space (see
/// [MillerProjection]) so painting and hit-testing are a plain multiply.
class WorldCountry {
  WorldCountry({
    required this.code,
    required this.name,
    required this.region,
    required this.rings,
    required this.bounds,
  });

  /// ISO 3166-1 alpha-2 where the source data has one (a three-letter
  /// Natural Earth code for the handful of places that don't).
  final String code;
  final String name;

  /// Continent, used to group the picker list.
  final String region;

  /// Outlines in unit space: each entry is a flat `[x0, y0, x1, y1, …]` list
  /// of points in 0..1, largest landmass first.
  final List<Float32List> rings;

  /// Unit-space bounding box of every ring together.
  final Rect bounds;

  /// Cheap stand-in for the country's on-screen size — small countries win
  /// ties when hit-testing so an enclave stays reachable inside the state
  /// that surrounds it.
  double get area => bounds.width * bounds.height;

  /// Whether [point] (unit space) falls inside any of this country's rings.
  bool contains(Offset point) {
    if (!bounds.contains(point)) return false;
    for (final ring in rings) {
      if (_ringContains(ring, point)) return true;
    }
    return false;
  }

  static bool _ringContains(Float32List ring, Offset p) {
    // Standard even-odd ray cast against the flat coordinate list.
    var inside = false;
    final count = ring.length ~/ 2;
    for (var i = 0, j = count - 1; i < count; j = i++) {
      final xi = ring[i * 2], yi = ring[i * 2 + 1];
      final xj = ring[j * 2], yj = ring[j * 2 + 1];
      if ((yi > p.dy) != (yj > p.dy) &&
          p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Every country in the bundled outline, ready to paint.
class WorldMap {
  WorldMap(this.countries);

  /// Sorted by name — the order the picker list shows them in.
  final List<WorldCountry> countries;

  /// Same countries, largest first: the painting order that keeps enclaves
  /// (Lesotho, San Marino, …) drawn on top of the country around them.
  late final List<WorldCountry> byDescendingSize = [...countries]
    ..sort((a, b) => b.area.compareTo(a.area));

  /// Hit-test order — smallest first, so the enclave wins the tap.
  late final List<WorldCountry> _byAscendingSize =
      byDescendingSize.reversed.toList();

  late final Map<String, WorldCountry> _byCode = {
    for (final country in countries) country.code: country,
  };

  WorldCountry? byCode(String code) => _byCode[code];

  /// The country under [point] (unit space), or null for open ocean.
  WorldCountry? countryAt(Offset point) {
    for (final country in _byAscendingSize) {
      if (country.contains(point)) return country;
    }
    return null;
  }

  /// Like [countryAt], but a tap that misses everything falls back to the
  /// smallest country whose outline sits within [slop] of [point] (unit
  /// space). Without it, Malta and Singapore are untappable on a phone.
  WorldCountry? countryNear(Offset point, double slop) {
    final exact = countryAt(point);
    if (exact != null || slop <= 0) return exact;
    for (final country in _byAscendingSize) {
      if (country.bounds.inflate(slop).contains(point)) return country;
    }
    return null;
  }

  /// Country codes grouped by continent, each group name-sorted.
  Map<String, List<WorldCountry>> get byRegion {
    final grouped = <String, List<WorldCountry>>{};
    for (final country in countries) {
      grouped.putIfAbsent(country.region, () => []).add(country);
    }
    return grouped;
  }

  static WorldMap? _cached;
  static Future<WorldMap>? _loading;

  /// Loads (and then caches) the bundled outline. Safe to call from several
  /// widgets at once — they share one decode.
  static Future<WorldMap> load({AssetBundle? bundle}) {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= (bundle ?? rootBundle)
        .loadString(kWorldMapAsset)
        .then(parse)
        .then((map) {
      _cached = map;
      _loading = null;
      return map;
    });
  }

  /// Parses the asset.
  ///
  /// `countries` carries the metadata plus the point count of each of that
  /// country's rings; every ring's coordinates live in one base64 `points`
  /// blob, delta-encoded as zigzag varints in integers of 1/`q` of a degree.
  /// Rings are read in the order the countries are listed, and projected once
  /// here rather than on every frame.
  static WorldMap parse(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final quantisation = (decoded['q'] as num).toDouble();
    final bytes = base64Decode(decoded['points'] as String);
    final countries = <WorldCountry>[];
    var offset = 0;

    int readDelta() {
      var result = 0;
      var shift = 0;
      while (true) {
        final byte = bytes[offset++];
        result |= (byte & 0x7F) << shift;
        if (byte < 0x80) break;
        shift += 7;
      }
      // Zigzag: …, -2 -> 3, -1 -> 1, 0 -> 0, 1 -> 2, 2 -> 4, …
      return (result >> 1) ^ -(result & 1);
    }

    for (final raw in decoded['countries'] as List) {
      final entry = raw as Map<String, dynamic>;
      final rings = <Float32List>[];
      var left = double.infinity, top = double.infinity;
      var right = -double.infinity, bottom = -double.infinity;

      for (final rawCount in entry['p'] as List) {
        final count = rawCount as int;
        final ring = Float32List(count * 2);
        var x = 0, y = 0;
        for (var i = 0; i < count; i++) {
          x += readDelta();
          y += readDelta();
          final point =
              MillerProjection.project(x / quantisation, y / quantisation);
          ring[i * 2] = point.dx;
          ring[i * 2 + 1] = point.dy;
          if (point.dx < left) left = point.dx;
          if (point.dx > right) right = point.dx;
          if (point.dy < top) top = point.dy;
          if (point.dy > bottom) bottom = point.dy;
        }
        rings.add(ring);
      }
      if (rings.isEmpty) continue;

      countries.add(WorldCountry(
        code: entry['c'] as String,
        name: entry['n'] as String,
        region: entry['r'] as String,
        rings: rings,
        bounds: Rect.fromLTRB(left, top, right, bottom),
      ));
    }

    countries.sort((a, b) => a.name.compareTo(b.name));
    return WorldMap(countries);
  }

  Size? _pathSize;
  Map<String, Path>? _paths;

  /// Every country's outline as a [Path] scaled to [size], keyed by country
  /// code. Built once per size and reused: with ~100k points, rebuilding the
  /// paths on every frame would show up as jank while panning.
  Map<String, Path> pathsFor(Size size) {
    final cached = _paths;
    if (cached != null && _pathSize == size) return cached;

    final paths = <String, Path>{};
    for (final country in countries) {
      final path = Path();
      for (final ring in country.rings) {
        path.moveTo(ring[0] * size.width, ring[1] * size.height);
        for (var i = 2; i < ring.length; i += 2) {
          path.lineTo(ring[i] * size.width, ring[i + 1] * size.height);
        }
        path.close();
      }
      paths[country.code] = path;
    }
    _pathSize = size;
    return _paths = paths;
  }
}

/// Miller cylindrical projection onto the unit square. Straight
/// equirectangular smears the far north; Miller keeps Europe and Canada the
/// shape people recognise without Mercator's runaway poles.
class MillerProjection {
  const MillerProjection._();

  /// Latitudes outside this band are clamped onto the edge of the map. The
  /// band is set just wide enough to hold every point in the bundled outline
  /// — northern Greenland at 83.63°N, South Georgia at 59.47°S — so nothing
  /// real is ever squashed against an edge. Antarctica isn't in the data.
  static const double maxLatitude = 83.7;
  static const double minLatitude = -59.6;

  static final double _top = _millerY(maxLatitude);
  static final double _bottom = _millerY(minLatitude);

  static double _millerY(double latitude) =>
      1.25 * math.log(math.tan(math.pi / 4 + 0.4 * latitude * math.pi / 180));

  /// Projects [longitude]/[latitude] (degrees) to the unit square, x east
  /// from the antimeridian, y down from the top of the map.
  static Offset project(double longitude, double latitude) {
    final clamped = latitude.clamp(minLatitude, maxLatitude).toDouble();
    return Offset(
      (longitude + 180) / 360,
      (_top - _millerY(clamped)) / (_top - _bottom),
    );
  }

  /// Width / height of the projected world, so the unit square can be drawn
  /// without squashing it. Longitude spans 2π in Miller's units; the visible
  /// latitude band spans whatever is left between [minLatitude] and
  /// [maxLatitude] (roughly 2.04 : 1).
  static double get aspectRatio => 2 * math.pi / (_top - _bottom);
}

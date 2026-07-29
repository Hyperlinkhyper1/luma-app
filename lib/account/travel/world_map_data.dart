import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

/// Where the bundled world outline lives (built from public-domain Natural
/// Earth 1:50m country polygons, simplified and quantised — see
/// `assets/world/README.md`).
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

  /// Parses the asset's JSON. Coordinates arrive as integers of 1/`q` of a
  /// degree and are projected once, here, rather than on every frame.
  static WorldMap parse(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final quantisation = (decoded['q'] as num).toDouble();
    final countries = <WorldCountry>[];

    for (final raw in decoded['countries'] as List) {
      final entry = raw as Map<String, dynamic>;
      final rings = <Float32List>[];
      var left = double.infinity, top = double.infinity;
      var right = -double.infinity, bottom = -double.infinity;

      for (final rawRing in entry['p'] as List) {
        final flat = (rawRing as List).cast<num>();
        final ring = Float32List(flat.length);
        for (var i = 0; i < flat.length; i += 2) {
          final point = MillerProjection.project(
            flat[i] / quantisation,
            flat[i + 1] / quantisation,
          );
          ring[i] = point.dx;
          ring[i + 1] = point.dy;
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
}

/// Miller cylindrical projection onto the unit square. Straight
/// equirectangular smears the far north; Miller keeps Europe and Canada the
/// shape people recognise without Mercator's runaway poles.
class MillerProjection {
  const MillerProjection._();

  /// Latitudes outside this band are clipped away — the map stops just below
  /// the Antarctic coast (no country there to pick) and just above Svalbard.
  static const double maxLatitude = 83.6;
  static const double minLatitude = -56.0;

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

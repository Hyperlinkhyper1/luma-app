import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../sim/geo.dart';

/// One airport in the bundled world. See `assets/airline_tycoon/README.md`
/// for where the data comes from and what [catchment] means.
class Airport {
  const Airport({
    required this.iata,
    required this.name,
    required this.city,
    required this.country,
    required this.lat,
    required this.lon,
    required this.runwayM,
    required this.catchment,
  });

  final String iata;
  final String name;
  final String city;
  final String country;
  final double lat;
  final double lon;

  /// Longest runway, in metres. Decides which aircraft can use the field.
  final int runwayM;

  /// Derived 1-100 demand score. Game balance, not source data.
  final int catchment;

  /// "Amsterdam (AMS)" — how the airport reads in a list.
  String get label => '$city ($iata)';

  double distanceToKm(Airport other) =>
      Geo.distanceKm(lat, lon, other.lat, other.lon);

  static Airport? fromJson(Map<String, Object?> json) {
    final iata = json['iata'];
    final lat = json['lat'];
    final lon = json['lon'];
    // A row missing any of these cannot be flown to, so it is dropped rather
    // than defaulted into something that would sit at (0, 0) in the Atlantic.
    if (iata is! String || iata.isEmpty) return null;
    if (lat is! num || lon is! num) return null;
    return Airport(
      iata: iata.toUpperCase(),
      name: json['name'] as String? ?? iata,
      city: json['city'] as String? ?? iata,
      country: json['country'] as String? ?? '',
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      runwayM: (json['runwayM'] as num?)?.round() ?? 0,
      catchment: (json['catchment'] as num?)?.round() ?? 1,
    );
  }
}

/// The bundled airport list.
///
/// [load] does the asset I/O once and memoises it; [parse] is pure, so the
/// dataset can be unit-tested without a Flutter binding or `rootBundle`. Same
/// split as `device_health/services/bloatware_catalog.dart`.
class AirportCatalog {
  AirportCatalog._(this.airports)
      : _byIata = {for (final a in airports) a.iata: a};

  /// Sorted by city, which is the order every picker wants.
  final List<Airport> airports;
  final Map<String, Airport> _byIata;

  static const assetPath = 'assets/airline_tycoon/airports.json';

  static AirportCatalog? _instance;
  static Future<AirportCatalog>? _loading;

  static Future<AirportCatalog> load({AssetBundle? bundle}) {
    final cached = _instance;
    if (cached != null) return Future.value(cached);
    return _loading ??= (bundle ?? rootBundle)
        .loadString(assetPath)
        .then(parse)
        .then((catalog) {
      _instance = catalog;
      _loading = null;
      return catalog;
    });
  }

  /// Parses the asset. Malformed rows are skipped rather than thrown on, so a
  /// bad edit to the JSON costs a destination instead of the whole plugin.
  static AirportCatalog parse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, Object?>) {
      return AirportCatalog._(const []);
    }
    final rows = decoded['airports'];
    if (rows is! List) return AirportCatalog._(const []);

    final airports = <Airport>[];
    final seen = <String>{};
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final airport = Airport.fromJson(row);
      if (airport == null) continue;
      if (!seen.add(airport.iata)) continue;
      airports.add(airport);
    }
    airports.sort((a, b) => a.city.compareTo(b.city));
    return AirportCatalog._(airports);
  }

  Airport? byIata(String? iata) =>
      iata == null ? null : _byIata[iata.toUpperCase()];

  /// Airports this hub could actually serve: within [maxRangeKm] and with a
  /// runway of at least [minRunwayM]. The hub itself is never included.
  List<Airport> reachableFrom(
    Airport hub, {
    required double maxRangeKm,
    required int minRunwayM,
  }) {
    final out = <Airport>[];
    for (final airport in airports) {
      if (airport.iata == hub.iata) continue;
      if (airport.runwayM < minRunwayM) continue;
      if (hub.distanceToKm(airport) > maxRangeKm) continue;
      out.add(airport);
    }
    return out;
  }

  /// Candidate home hubs: big enough to be worth starting at, but not so big
  /// that the first route is trivially profitable.
  List<Airport> starterHubs() {
    final candidates = airports
        .where((a) => a.catchment >= 30 && a.catchment <= 56)
        .toList()
      ..sort((a, b) => b.catchment.compareTo(a.catchment));
    return candidates;
  }

  /// Test seam: drops the memoised instance so a test can load a fixture.
  static void resetForTest() {
    _instance = null;
    _loading = null;
  }
}

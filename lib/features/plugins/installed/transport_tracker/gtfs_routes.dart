import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'gtfs_archive.dart';
import 'transit_vehicle.dart';

/// One published route (a line, in everyday terms).
class GtfsRoute {
  const GtfsRoute({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.type,
    this.agencyId,
    this.color,
  });

  final String id;

  /// What the line is called on the vehicle: `ICE`, `Eurostar`, `Sprinter`,
  /// `326`…
  final String shortName;

  /// Usually `Origin <-> Destination` plus the service number.
  final String longName;

  /// GTFS `route_type`: 0 tram, 1 metro, 2 rail, 3 bus, 4 ferry.
  final int type;
  final String? agencyId;

  /// `rrggbb` as published by the operator, without the leading `#`.
  final String? color;

  /// The pair of places this route runs between, pulled out of the long
  /// name's `A <-> B` form. Null when it isn't in that shape.
  ({String from, String to})? get endpoints {
    final parts = longName.split('<->');
    if (parts.length != 2) return null;
    return (from: _clean(parts[0]), to: _clean(parts[1]));
  }

  /// Long names end with the internal service code — "Roosendaal ST2550",
  /// "Lelystad Centrum ICD2400" — which is noise next to a place name.
  static final _serviceCode = RegExp(r'\s+[A-Z]{2,4}\d+$');
  static String _clean(String value) =>
      value.trim().replaceFirst(_serviceCode, '').trim();

  /// Services sold as fast, long-distance or international. These are the
  /// ones a tracker wants to show apart from stopping trains — ICE, Eurostar
  /// and the night trains crossing the Netherlands.
  static const _highSpeedNames = {
    'ice',
    'eurostar',
    'thalys',
    'nightjet',
    'european sleeper',
    'eurocity',
    'eurocity direct',
    'intercity direct',
    'tgv',
    'railjet',
  };

  bool get isHighSpeed =>
      type == 2 && _highSpeedNames.contains(shortName.trim().toLowerCase());

  /// The mode to draw this route as. `route_type` is authoritative here,
  /// which removes the operator/line-number guesswork entirely.
  TransitMode get mode {
    if (isHighSpeed) return TransitMode.highSpeed;
    return switch (type) {
      0 => TransitMode.tram,
      1 => TransitMode.metro,
      2 => TransitMode.train,
      4 => TransitMode.ferry,
      _ => TransitMode.bus,
    };
  }
}

/// Route names, types and colours for the Dutch network.
///
/// `routes.txt` is 40 KB inside the archive, so unlike stop names this is
/// cheap enough to keep permanently. It is what turns "Train 152372" into
/// "ICE — Amsterdam Centraal ↔ Frankfurt (M) Hbf".
class GtfsRoutesCache {
  GtfsRoutesCache._(this._routes, this.fetchedAt);

  @visibleForTesting
  factory GtfsRoutesCache.fromCsv(String csv) =>
      GtfsRoutesCache._(_parseCsv(csv), DateTime.now());

  final Map<String, GtfsRoute> _routes;
  final DateTime? fetchedAt;

  static const _memberName = 'routes.txt';
  static const _cacheFileName = 'luma_gtfs_routes.csv';
  static const maxAge = Duration(days: 7);

  int get length => _routes.length;
  bool get isEmpty => _routes.isEmpty;
  bool get isStale =>
      fetchedAt == null || DateTime.now().difference(fetchedAt!) > maxAge;

  GtfsRoute? operator [](String? routeId) =>
      routeId == null ? null : _routes[routeId];

  static Future<File> _cacheFile([Directory? directory]) async {
    final dir = directory ?? await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_cacheFileName');
  }

  static Future<GtfsRoutesCache> load({Directory? directory}) async {
    try {
      final file = await _cacheFile(directory);
      if (!await file.exists()) return GtfsRoutesCache._({}, null);
      final stat = await file.stat();
      return GtfsRoutesCache._(
          _parseCsv(await file.readAsString()), stat.modified);
    } catch (_) {
      return GtfsRoutesCache._({}, null);
    }
  }

  static Future<GtfsRoutesCache> download({
    http.Client? httpClient,
    Directory? directory,
  }) async {
    final bytes =
        await GtfsArchive.fetchMember(_memberName, httpClient: httpClient);
    final csv = utf8.decode(bytes, allowMalformed: true);
    final routes = _parseCsv(csv);
    if (routes.isEmpty) {
      throw GtfsArchiveException('The route list came back empty.');
    }
    final file = await _cacheFile(directory);
    await file.writeAsString(csv, flush: true);
    return GtfsRoutesCache._(routes, DateTime.now());
  }

  static Map<String, GtfsRoute> _parseCsv(String csv) {
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return {};
    final header = GtfsArchive.splitCsvLine(lines.first);
    int index(String name) => header.indexOf(name);
    final idIndex = index('route_id');
    final shortIndex = index('route_short_name');
    final longIndex = index('route_long_name');
    final typeIndex = index('route_type');
    final agencyIndex = index('agency_id');
    final colorIndex = index('route_color');
    if (idIndex < 0 || typeIndex < 0) return {};

    final out = <String, GtfsRoute>{};
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final f = GtfsArchive.splitCsvLine(lines[i]);
      String at(int idx) => (idx >= 0 && idx < f.length) ? f[idx] : '';
      final id = at(idIndex);
      final type = int.tryParse(at(typeIndex));
      if (id.isEmpty || type == null) continue;
      final color = at(colorIndex);
      out[id] = GtfsRoute(
        id: id,
        shortName: at(shortIndex),
        longName: at(longIndex),
        type: type,
        agencyId: at(agencyIndex).isEmpty ? null : at(agencyIndex),
        color: color.isEmpty ? null : color,
      );
    }
    return out;
  }
}

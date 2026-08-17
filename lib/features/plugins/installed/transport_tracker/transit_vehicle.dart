import 'package:flutter/material.dart';

/// Mode of a tracked public-transport vehicle.
///
/// GTFS-realtime position feeds only carry a `route_id` that points into the
/// *static* GTFS dataset, which this plugin does not download — so the mode
/// is inferred from the operator and line code instead. That inference is
/// deliberately conservative: anything it can't place confidently stays
/// [TransitMode.bus], which is what the overwhelming majority of Dutch
/// vehicles in the feed actually are.
enum TransitMode { highSpeed, train, metro, tram, bus, ferry }

extension TransitModeInfo on TransitMode {
  String get label => switch (this) {
        TransitMode.highSpeed => 'High-speed',
        TransitMode.train => 'Train',
        TransitMode.metro => 'Metro',
        TransitMode.tram => 'Tram',
        TransitMode.bus => 'Bus',
        TransitMode.ferry => 'Ferry',
      };

  Color get color => switch (this) {
        TransitMode.highSpeed => const Color(0xFFD452C4),
        TransitMode.train => const Color(0xFF7A6FF0),
        TransitMode.metro => const Color(0xFFE05252),
        TransitMode.tram => const Color(0xFF2E9E4F),
        TransitMode.bus => const Color(0xFFF2A33C),
        TransitMode.ferry => const Color(0xFF39C1D1),
      };

  IconData get icon => switch (this) {
        TransitMode.highSpeed => Icons.bolt_rounded,
        TransitMode.train => Icons.train_rounded,
        TransitMode.metro => Icons.subway_rounded,
        TransitMode.tram => Icons.tram_rounded,
        TransitMode.bus => Icons.directions_bus_rounded,
        TransitMode.ferry => Icons.directions_boat_rounded,
      };

  /// Both rail modes are placed by interpolating the timetable, so they
  /// share the same data path.
  bool get isRail =>
      this == TransitMode.train || this == TransitMode.highSpeed;

  String get hex =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

/// Operators that run a single mode across their whole fleet.
const _operatorModes = <String, TransitMode>{
  'NS': TransitMode.train,
  'NSI': TransitMode.train,
  'ARR': TransitMode.bus,
  'DOEKSEN': TransitMode.ferry,
  'TESO': TransitMode.ferry,
  'WPD': TransitMode.ferry,
};

/// Infers a mode from the operator code and line designation found in a
/// GTFS-realtime entity id (`date:OPERATOR:LINE:journey`).
TransitMode transitModeFor(String? operator, String? line) {
  final op = operator?.toUpperCase();
  final direct = op == null ? null : _operatorModes[op];
  if (direct != null) return direct;

  final l = line?.toUpperCase() ?? '';
  // Rotterdam's metro lines are lettered A-E and appear as M###/A-E; its
  // trams are plain numbers. Amsterdam's metro lines are 50-54.
  if (op == 'RET') {
    if (l.startsWith('M') || RegExp(r'^[A-E]$').hasMatch(l)) {
      return TransitMode.metro;
    }
    return TransitMode.tram;
  }
  if (op == 'GVB') {
    final n = int.tryParse(l);
    if (n != null && n >= 50 && n <= 54) return TransitMode.metro;
    if (n != null && n <= 27) return TransitMode.tram;
    return TransitMode.bus;
  }
  if (op == 'HTM') {
    final n = int.tryParse(l);
    if (n != null && n <= 19) return TransitMode.tram;
    return TransitMode.bus;
  }
  if (l.startsWith('M')) return TransitMode.metro;
  if (l.startsWith('T')) return TransitMode.tram;
  return TransitMode.bus;
}

/// One live public-transport vehicle from a GTFS-realtime feed.
@immutable
class TransitVehicle {
  const TransitVehicle({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.mode,
    this.operator,
    this.line,
    this.label,
    this.speed,
    this.timestamp,
    this.tripId,
    this.routeId,
    this.serviceName,
    this.destination,
    this.interpolated = false,
  });

  /// GTFS-realtime entity id — stable for the life of a journey.
  final String id;
  final double latitude;
  final double longitude;
  final TransitMode mode;

  /// Operator code as published in the feed (GVB, RET, QBUZZ, ...).
  final String? operator;

  /// Line/route designation as it appears in the entity id.
  final String? line;

  /// Vehicle number from the feed's own vehicle descriptor.
  final String? label;

  /// Metres per second, when the feed provides it.
  final double? speed;
  final DateTime? timestamp;

  /// Links this vehicle to its entry in the trip-update feed, which is where
  /// the remaining calls and their delays come from.
  final String? tripId;

  /// The route this journey runs on, used to look up its published name.
  final String? routeId;

  /// Published service name from `routes.txt` — "ICE", "Eurostar",
  /// "Sprinter", "326".
  final String? serviceName;

  /// Where the journey terminates, when the feed or route says.
  final String? destination;

  /// True when the position was derived from the timetable rather than
  /// broadcast by the vehicle — currently only rail. Surfaced in the UI so
  /// the reading isn't presented as more precise than it is.
  final bool interpolated;

  String get displayName {
    final service = serviceName?.trim();
    final l = line?.trim();
    if (service != null && service.isNotEmpty) {
      // "ICE 120" reads better than "High-speed 120"; for a bus the service
      // name is already the line number, so don't repeat it.
      if (l != null && l.isNotEmpty && l != service) return '$service $l';
      return service;
    }
    if (l != null && l.isNotEmpty) return '${mode.label} $l';
    return mode.label;
  }

  Map<String, dynamic> toGeoJsonFeature() => {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
        'properties': {
          'id': id,
          'line': line ?? '',
          'color': mode.hex,
          'mode': mode.name,
        },
      };
}

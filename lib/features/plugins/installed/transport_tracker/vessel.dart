import 'package:flutter/material.dart';

/// Broad grouping of the numeric AIS "ship type" code (ITU-R M.1371), used
/// to color and label markers the way MarineTraffic/VesselFinder do.
enum VesselCategory {
  cargo,
  tanker,
  passenger,
  fishing,
  highSpeed,
  tug,
  lawEnforcement,
  searchAndRescue,
  pleasureCraft,
  other,
  unspecified,
}

extension VesselCategoryInfo on VesselCategory {
  String get label => switch (this) {
        VesselCategory.cargo => 'Cargo',
        VesselCategory.tanker => 'Tanker',
        VesselCategory.passenger => 'Passenger',
        VesselCategory.fishing => 'Fishing',
        VesselCategory.highSpeed => 'High-speed craft',
        VesselCategory.tug => 'Tug / service',
        VesselCategory.lawEnforcement => 'Law enforcement',
        VesselCategory.searchAndRescue => 'Search & rescue',
        VesselCategory.pleasureCraft => 'Pleasure craft',
        VesselCategory.other => 'Other',
        VesselCategory.unspecified => 'Unspecified',
      };

  Color get color => switch (this) {
        VesselCategory.cargo => const Color(0xFF34C38F),
        VesselCategory.tanker => const Color(0xFFE6584C),
        VesselCategory.passenger => const Color(0xFF3B82F6),
        VesselCategory.fishing => const Color(0xFFF5A623),
        VesselCategory.highSpeed => const Color(0xFFA970FF),
        VesselCategory.tug => const Color(0xFF8A93A6),
        VesselCategory.lawEnforcement => const Color(0xFFCF6BFF),
        VesselCategory.searchAndRescue => const Color(0xFFCF6BFF),
        VesselCategory.pleasureCraft => const Color(0xFF39C1D1),
        VesselCategory.other => const Color(0xFF6B7280),
        VesselCategory.unspecified => const Color(0xFF9AA3B2),
      };

  /// `#rrggbb`, for handing the color to the MapLibre layer running in JS.
  String get hex =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

/// Maps an AIS "ship type" code (0-99) to a [VesselCategory]. See ITU-R
/// M.1371 table 18 — ranges below follow that standard.
VesselCategory vesselCategoryForShipType(int? type) {
  if (type == null || type == 0) return VesselCategory.unspecified;
  if (type == 30) return VesselCategory.fishing;
  if (type == 37) return VesselCategory.pleasureCraft;
  if (type == 36) return VesselCategory.pleasureCraft; // sailing
  if (type >= 40 && type <= 49) return VesselCategory.highSpeed;
  if (type == 51) return VesselCategory.searchAndRescue;
  if (type == 55) return VesselCategory.lawEnforcement;
  if (type == 52 || type == 53 || type == 54 || type == 58) {
    return VesselCategory.tug;
  }
  if (type >= 60 && type <= 69) return VesselCategory.passenger;
  if (type >= 70 && type <= 79) return VesselCategory.cargo;
  if (type >= 80 && type <= 89) return VesselCategory.tanker;
  return VesselCategory.other;
}

/// Human-readable label for the AIS "navigational status" code (0-15).
String navStatusLabel(int? code) => switch (code) {
      0 => 'Under way (engine)',
      1 => 'At anchor',
      2 => 'Not under command',
      3 => 'Restricted manoeuvrability',
      4 => 'Constrained by draught',
      5 => 'Moored',
      6 => 'Aground',
      7 => 'Fishing',
      8 => 'Under way (sailing)',
      14 => 'AIS-SART (distress beacon)',
      _ => 'Unknown',
    };

/// One live-tracked vessel, built by folding [VesselPatch]es (position
/// reports and static-data reports) received from the AIS feed.
@immutable
class Vessel {
  const Vessel({
    required this.mmsi,
    required this.latitude,
    required this.longitude,
    required this.lastUpdate,
    this.name,
    this.sog,
    this.cog,
    this.trueHeading,
    this.navStatus,
    this.shipType,
    this.imo,
    this.callSign,
    this.destination,
    this.draught,
  });

  final int mmsi;
  final double latitude;
  final double longitude;
  final DateTime lastUpdate;

  final String? name;

  /// Speed over ground, in knots.
  final double? sog;

  /// Course over ground, in degrees.
  final double? cog;

  /// True heading, in degrees (0-359); 511 in the raw feed means unknown
  /// and is normalized away to null by [VesselPatch].
  final int? trueHeading;
  final int? navStatus;
  final int? shipType;
  final int? imo;
  final String? callSign;
  final String? destination;
  final double? draught;

  VesselCategory get category => vesselCategoryForShipType(shipType);

  String get displayName {
    final n = name?.trim();
    return (n != null && n.isNotEmpty) ? n : 'MMSI $mmsi';
  }

  /// Best available pointing direction for the marker: true heading when
  /// broadcast, falling back to course over ground.
  double get markerHeading => (trueHeading ?? cog ?? 0).toDouble();

  factory Vessel.fromPatch(VesselPatch patch) => Vessel(
        mmsi: patch.mmsi,
        latitude: patch.latitude,
        longitude: patch.longitude,
        lastUpdate: DateTime.now(),
        name: patch.name,
        sog: patch.sog,
        cog: patch.cog,
        trueHeading: patch.trueHeading,
        navStatus: patch.navStatus,
        shipType: patch.shipType,
        imo: patch.imo,
        callSign: patch.callSign,
        destination: patch.destination,
        draught: patch.draught,
      );

  Vessel mergedWith(VesselPatch patch) => Vessel(
        mmsi: mmsi,
        latitude: patch.latitude,
        longitude: patch.longitude,
        lastUpdate: DateTime.now(),
        name: patch.name ?? name,
        sog: patch.sog ?? sog,
        cog: patch.cog ?? cog,
        trueHeading: patch.trueHeading ?? trueHeading,
        navStatus: patch.navStatus ?? navStatus,
        shipType: patch.shipType ?? shipType,
        imo: patch.imo ?? imo,
        callSign: patch.callSign ?? callSign,
        destination: patch.destination ?? destination,
        draught: patch.draught ?? draught,
      );

  Map<String, dynamic> toGeoJsonFeature({required bool selected}) => {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
        'properties': {
          'mmsi': mmsi,
          'name': displayName,
          'color': category.hex,
          'heading': markerHeading,
          'selected': selected,
        },
      };
}

/// An incoming AIS report, either a position update or a static-data update
/// (or both fields populated at once, for reports that carry position).
/// Null fields mean "unknown/unchanged" so [Vessel.mergedWith] leaves the
/// previously-known value alone.
@immutable
class VesselPatch {
  const VesselPatch({
    required this.mmsi,
    required this.latitude,
    required this.longitude,
    this.name,
    this.sog,
    this.cog,
    this.trueHeading,
    this.navStatus,
    this.shipType,
    this.imo,
    this.callSign,
    this.destination,
    this.draught,
  });

  final int mmsi;
  final double latitude;
  final double longitude;
  final String? name;
  final double? sog;
  final double? cog;
  final int? trueHeading;
  final int? navStatus;
  final int? shipType;
  final int? imo;
  final String? callSign;
  final String? destination;
  final double? draught;
}

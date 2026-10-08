import '../../../../../l10n/current_l.dart';

/// What a building is made of, as far as the renderer cares. Kept as a
/// semantic enum rather than a `Color` so the hub can follow the app's light,
/// dark and Coffee themes instead of carrying its own hardcoded palette.
enum BuildingMaterial { asphalt, concrete, glass, metal, grass }

enum BuildingKind {
  apron,
  gate,
  terminal,
  runwayShort,
  runwayMedium,
  runwayLong,
  hangar,
  fuelDepot,
  cargo,
  lounge,
}

class BuildingDef {
  const BuildingDef({
    required this.kind,
    required this.width,
    required this.depth,
    required this.levels,
    required this.costEur,
    required this.upkeepPerDayEur,
    required this.material,
    this.rotatable = false,
    this.runwayM = 0,
  });

  final BuildingKind kind;

  /// Display name and one-line description in the language picked in
  /// settings. Keyed on [kind], so only the label changes and nothing
  /// translated is ever persisted.
  String get name => switch (kind) {
    BuildingKind.apron => currentL.airlineBuildingApronName,
    BuildingKind.gate => currentL.airlineBuildingGateName,
    BuildingKind.terminal => currentL.airlineBuildingTerminalName,
    BuildingKind.runwayShort => currentL.airlineBuildingRunwayShortName,
    BuildingKind.runwayMedium => currentL.airlineBuildingRunwayMediumName,
    BuildingKind.runwayLong => currentL.airlineBuildingRunwayLongName,
    BuildingKind.hangar => currentL.airlineBuildingHangarName,
    BuildingKind.fuelDepot => currentL.airlineBuildingFuelDepotName,
    BuildingKind.cargo => currentL.airlineBuildingCargoName,
    BuildingKind.lounge => currentL.airlineBuildingLoungeName,
  };

  String get blurb => switch (kind) {
    BuildingKind.apron => currentL.airlineBuildingApronBlurb,
    BuildingKind.gate => currentL.airlineBuildingGateBlurb,
    BuildingKind.terminal => currentL.airlineBuildingTerminalBlurb,
    BuildingKind.runwayShort => currentL.airlineBuildingRunwayShortBlurb,
    BuildingKind.runwayMedium => currentL.airlineBuildingRunwayMediumBlurb,
    BuildingKind.runwayLong => currentL.airlineBuildingRunwayLongBlurb,
    BuildingKind.hangar => currentL.airlineBuildingHangarBlurb,
    BuildingKind.fuelDepot => currentL.airlineBuildingFuelDepotBlurb,
    BuildingKind.cargo => currentL.airlineBuildingCargoBlurb,
    BuildingKind.lounge => currentL.airlineBuildingLoungeBlurb,
  };

  /// Footprint in tiles, before rotation.
  final int width;
  final int depth;

  /// Height in storeys. Flat surfaces use a fraction of a level.
  final double levels;

  final int costEur;
  final int upkeepPerDayEur;
  final BuildingMaterial material;

  /// Whether the footprint can be turned 90°. Only matters for oblong pieces.
  final bool rotatable;

  /// Usable length in metres, for runways. Zero for everything else.
  final int runwayM;

  bool get isRunway => runwayM > 0;

  /// Footprint after [rotation] (0 or 1 quarter turns).
  ({int width, int depth}) footprint(int rotation) =>
      rotation.isOdd ? (width: depth, depth: width) : (width: width, depth: depth);
}

const List<BuildingDef> kBuildingCatalog = [
  BuildingDef(
    kind: BuildingKind.apron,
    width: 1,
    depth: 1,
    levels: 0.06,
    costEur: 250000,
    upkeepPerDayEur: 120,
    material: BuildingMaterial.asphalt,
  ),
  BuildingDef(
    kind: BuildingKind.gate,
    width: 1,
    depth: 1,
    levels: 0.9,
    costEur: 1200000,
    upkeepPerDayEur: 900,
    material: BuildingMaterial.metal,
  ),
  BuildingDef(
    kind: BuildingKind.terminal,
    width: 2,
    depth: 2,
    levels: 2.6,
    costEur: 4000000,
    upkeepPerDayEur: 2600,
    material: BuildingMaterial.glass,
  ),
  BuildingDef(
    kind: BuildingKind.runwayShort,
    width: 1,
    depth: 5,
    levels: 0.1,
    costEur: 6000000,
    upkeepPerDayEur: 1800,
    material: BuildingMaterial.asphalt,
    rotatable: true,
    runwayM: 1800,
  ),
  BuildingDef(
    kind: BuildingKind.runwayMedium,
    width: 1,
    depth: 7,
    levels: 0.1,
    costEur: 13000000,
    upkeepPerDayEur: 3200,
    material: BuildingMaterial.asphalt,
    rotatable: true,
    runwayM: 2600,
  ),
  BuildingDef(
    kind: BuildingKind.runwayLong,
    width: 1,
    depth: 9,
    levels: 0.1,
    costEur: 24000000,
    upkeepPerDayEur: 5000,
    material: BuildingMaterial.asphalt,
    rotatable: true,
    runwayM: 3400,
  ),
  BuildingDef(
    kind: BuildingKind.hangar,
    width: 2,
    depth: 2,
    levels: 1.7,
    costEur: 3000000,
    upkeepPerDayEur: 1400,
    material: BuildingMaterial.metal,
  ),
  BuildingDef(
    kind: BuildingKind.fuelDepot,
    width: 1,
    depth: 1,
    levels: 1.2,
    costEur: 2000000,
    upkeepPerDayEur: 1100,
    material: BuildingMaterial.metal,
  ),
  BuildingDef(
    kind: BuildingKind.cargo,
    width: 2,
    depth: 2,
    levels: 1.5,
    costEur: 3500000,
    upkeepPerDayEur: 1900,
    material: BuildingMaterial.concrete,
  ),
  BuildingDef(
    kind: BuildingKind.lounge,
    width: 1,
    depth: 1,
    levels: 1.1,
    costEur: 1800000,
    upkeepPerDayEur: 1300,
    material: BuildingMaterial.glass,
  ),
];

final Map<BuildingKind, BuildingDef> kBuildingByKind = {
  for (final def in kBuildingCatalog) def.kind: def,
};

BuildingDef buildingDef(BuildingKind kind) => kBuildingByKind[kind]!;

BuildingKind? buildingKindByName(String? name) {
  if (name == null) return null;
  for (final kind in BuildingKind.values) {
    if (kind.name == name) return kind;
  }
  return null;
}

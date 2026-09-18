import '../data/buildings.dart';

/// One building placed on the hub grid.
class PlacedBuilding {
  const PlacedBuilding({
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
  });

  final BuildingKind kind;
  final int x;
  final int y;

  /// Quarter turns. Only 0 and 1 are distinct for the rectangles here.
  final int rotation;

  BuildingDef get def => buildingDef(kind);

  ({int width, int depth}) get size => def.footprint(rotation);

  /// Every tile this building covers.
  Iterable<({int x, int y})> get tiles sync* {
    final s = size;
    for (var dx = 0; dx < s.width; dx++) {
      for (var dy = 0; dy < s.depth; dy++) {
        yield (x: x + dx, y: y + dy);
      }
    }
  }

  /// Tiles orthogonally touching this building but not part of it. Two
  /// buildings count as adjacent when one footprint reaches the other's
  /// border; corner contact deliberately does not count, so adjacency is
  /// something the player can judge at a glance.
  Iterable<({int x, int y})> get border sync* {
    final s = size;
    for (var dx = 0; dx < s.width; dx++) {
      yield (x: x + dx, y: y - 1);
      yield (x: x + dx, y: y + s.depth);
    }
    for (var dy = 0; dy < s.depth; dy++) {
      yield (x: x - 1, y: y + dy);
      yield (x: x + s.width, y: y + dy);
    }
  }

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'x': x,
        'y': y,
        'r': rotation,
      };

  static PlacedBuilding? fromJson(Map<String, Object?> json) {
    final kind = buildingKindByName(json['kind'] as String?);
    if (kind == null) return null;
    final x = json['x'];
    final y = json['y'];
    if (x is! int || y is! int) return null;
    return PlacedBuilding(
      kind: kind,
      x: x,
      y: y,
      rotation: (json['r'] as int?) ?? 0,
    );
  }
}

/// Why a placement was refused, or null when it is allowed.
enum PlacementError { outOfBounds, overlaps }

/// Everything the economy needs to know about the hub, resolved from the
/// layout in one pass.
class HubEffects {
  const HubEffects({
    required this.activeGates,
    required this.inactiveGates,
    required this.maxRunwayM,
    required this.maintenanceMultiplier,
    required this.fuelMultiplier,
    required this.hasCargo,
    required this.premiumMultiplier,
    required this.upkeepPerDayEur,
  });

  /// Gates touching a terminal. This is the cap on simultaneously active
  /// routes.
  final int activeGates;

  /// Gates that are not — built, paid for, and doing nothing. Surfaced in the
  /// UI so the rule teaches itself.
  final int inactiveGates;

  /// Longest runway on the field, which decides what can fly at all.
  final int maxRunwayM;

  /// Multipliers applied to cost, so 0.75 means a 25% saving.
  final double maintenanceMultiplier;
  final double fuelMultiplier;

  final bool hasCargo;

  /// Fare uplift on long-haul from lounges, as a multiplier (1.0 = none).
  final double premiumMultiplier;

  final int upkeepPerDayEur;

  static const empty = HubEffects(
    activeGates: 0,
    inactiveGates: 0,
    maxRunwayM: 0,
    maintenanceMultiplier: 1,
    fuelMultiplier: 1,
    hasCargo: false,
    premiumMultiplier: 1,
    upkeepPerDayEur: 0,
  );
}

/// Pure grid logic. Nothing here touches Flutter, so every rule below is
/// unit-testable on its own.
class HubGrid {
  const HubGrid._();

  /// Discount each hangar contributes, and the floor the total may reach.
  static const double _hangarStep = 0.08;
  static const double _hangarFloor = 0.65;
  static const double _fuelStep = 0.06;
  static const double _fuelFloor = 0.80;
  static const double _loungeStep = 0.04;
  static const double _loungeCeiling = 1.20;

  /// Extra credit for a hangar or depot that opens onto an apron.
  static const double _apronBonus = 1.15;

  static Set<({int x, int y})> occupied(List<PlacedBuilding> buildings) {
    final taken = <({int x, int y})>{};
    for (final building in buildings) {
      taken.addAll(building.tiles);
    }
    return taken;
  }

  /// Whether [candidate] may be placed, and why not if it may not.
  static PlacementError? check(
    PlacedBuilding candidate,
    int gridSize,
    List<PlacedBuilding> existing,
  ) {
    for (final tile in candidate.tiles) {
      if (tile.x < 0 || tile.y < 0 || tile.x >= gridSize || tile.y >= gridSize) {
        return PlacementError.outOfBounds;
      }
    }
    final taken = occupied(existing);
    for (final tile in candidate.tiles) {
      if (taken.contains(tile)) return PlacementError.overlaps;
    }
    return null;
  }

  /// The building covering [tile], or null.
  static PlacedBuilding? at(
    ({int x, int y}) tile,
    List<PlacedBuilding> buildings,
  ) {
    for (final building in buildings) {
      for (final owned in building.tiles) {
        if (owned.x == tile.x && owned.y == tile.y) return building;
      }
    }
    return null;
  }

  static bool _touches(
    PlacedBuilding building,
    Set<({int x, int y})> targetTiles,
  ) {
    for (final tile in building.border) {
      if (targetTiles.contains(tile)) return true;
    }
    return false;
  }

  static Set<({int x, int y})> _tilesOfKind(
    List<PlacedBuilding> buildings,
    bool Function(PlacedBuilding) test,
  ) {
    final tiles = <({int x, int y})>{};
    for (final building in buildings) {
      if (test(building)) tiles.addAll(building.tiles);
    }
    return tiles;
  }

  /// Resolves the whole layout into the handful of numbers the economy uses.
  static HubEffects resolve(List<PlacedBuilding> buildings) {
    if (buildings.isEmpty) return HubEffects.empty;

    final terminalTiles =
        _tilesOfKind(buildings, (b) => b.kind == BuildingKind.terminal);
    final apronTiles =
        _tilesOfKind(buildings, (b) => b.kind == BuildingKind.apron);

    var activeGates = 0;
    var inactiveGates = 0;
    var maxRunwayM = 0;
    var hangarSaving = 0.0;
    var fuelSaving = 0.0;
    var premium = 0.0;
    var hasCargo = false;
    var upkeep = 0;

    for (final building in buildings) {
      upkeep += building.def.upkeepPerDayEur;

      switch (building.kind) {
        case BuildingKind.gate:
          if (_touches(building, terminalTiles)) {
            activeGates++;
          } else {
            inactiveGates++;
          }
        case BuildingKind.hangar:
          final bonus = _touches(building, apronTiles) ? _apronBonus : 1.0;
          hangarSaving += _hangarStep * bonus;
        case BuildingKind.fuelDepot:
          final bonus = _touches(building, apronTiles) ? _apronBonus : 1.0;
          fuelSaving += _fuelStep * bonus;
        case BuildingKind.lounge:
          if (_touches(building, terminalTiles)) premium += _loungeStep;
        case BuildingKind.cargo:
          hasCargo = true;
        case BuildingKind.runwayShort:
        case BuildingKind.runwayMedium:
        case BuildingKind.runwayLong:
          if (building.def.runwayM > maxRunwayM) {
            maxRunwayM = building.def.runwayM;
          }
        case BuildingKind.apron:
        case BuildingKind.terminal:
          break;
      }
    }

    return HubEffects(
      activeGates: activeGates,
      inactiveGates: inactiveGates,
      maxRunwayM: maxRunwayM,
      maintenanceMultiplier:
          (1 - hangarSaving).clamp(_hangarFloor, 1.0).toDouble(),
      fuelMultiplier: (1 - fuelSaving).clamp(_fuelFloor, 1.0).toDouble(),
      hasCargo: hasCargo,
      premiumMultiplier: (1 + premium).clamp(1.0, _loungeCeiling).toDouble(),
      upkeepPerDayEur: upkeep,
    );
  }
}

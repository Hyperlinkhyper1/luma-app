import 'dart:ui';

import 'map_maker_geometry.dart';

const kCityGrid = 24.0;
const kCitySheetSize = Size(3200, 2400);

enum CityRoadKind { street, avenue, highway, pedestrian }

extension CityRoadKindWidth on CityRoadKind {
  double get width => switch (this) {
    CityRoadKind.street => 24,
    CityRoadKind.avenue => 40,
    CityRoadKind.highway => 56,
    CityRoadKind.pedestrian => 12,
  };
}

class CityRoad {
  CityRoad({
    required this.id,
    this.kind = CityRoadKind.street,
    List<Offset>? points,
  }) : points = points ?? [];

  final String id;
  CityRoadKind kind;
  final List<Offset> points;

  CityRoad clone() =>
      CityRoad(id: id, kind: kind, points: List<Offset>.from(points));

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'points': [
      for (final point in points) {'x': point.dx, 'y': point.dy},
    ],
  };

  factory CityRoad.fromJson(Map<String, dynamic> json) => CityRoad(
    id: json['id']?.toString() ?? '',
    kind: CityRoadKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => CityRoadKind.street,
    ),
    points: (json['points'] as List<dynamic>? ?? [])
        .map(
          (point) => Offset(
            (point['x'] as num?)?.toDouble() ?? 0,
            (point['y'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(),
  );
}

enum CityBuildingKind {
  house,
  apartment,
  shop,
  office,
  school,
  hospital,
  park,
  tree,
}

class CityBuilding {
  CityBuilding({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.quarterTurns = 0,
    this.name = '',
  });

  final String id;
  CityBuildingKind kind;
  double x;
  double y;
  int quarterTurns;
  String name;

  Offset get position => Offset(x, y);

  set position(Offset value) {
    x = value.dx;
    y = value.dy;
  }

  Size get size => switch (kind) {
    CityBuildingKind.house => const Size(48, 48),
    CityBuildingKind.apartment => const Size(72, 72),
    CityBuildingKind.shop => const Size(72, 48),
    CityBuildingKind.office => const Size(72, 96),
    CityBuildingKind.school => const Size(120, 72),
    CityBuildingKind.hospital => const Size(96, 96),
    CityBuildingKind.park => const Size(120, 96),
    CityBuildingKind.tree => const Size(24, 24),
  };

  Rect get bounds => Rect.fromCenter(
    center: position,
    width: quarterTurns.isOdd ? size.height : size.width,
    height: quarterTurns.isOdd ? size.width : size.height,
  );

  CityBuilding clone() => CityBuilding(
    id: id,
    kind: kind,
    x: x,
    y: y,
    quarterTurns: quarterTurns,
    name: name,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'quarterTurns': quarterTurns,
    'name': name,
  };

  factory CityBuilding.fromJson(Map<String, dynamic> json) => CityBuilding(
    id: json['id']?.toString() ?? '',
    kind: CityBuildingKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => CityBuildingKind.house,
    ),
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    quarterTurns: ((json['quarterTurns'] as num?)?.toInt() ?? 0) % 4,
    name: json['name']?.toString() ?? '',
  );
}

class CityMap {
  CityMap({List<CityRoad>? roads, List<CityBuilding>? buildings})
    : roads = roads ?? [],
      buildings = buildings ?? [];

  final List<CityRoad> roads;
  final List<CityBuilding> buildings;

  CityMap clone() => CityMap(
    roads: roads.map((road) => road.clone()).toList(),
    buildings: buildings.map((building) => building.clone()).toList(),
  );

  CityBuilding? hitBuilding(Offset point) {
    for (final building in buildings.reversed) {
      if (building.kind != CityBuildingKind.park &&
          building.bounds.contains(point)) {
        return building;
      }
    }
    for (final building in buildings.reversed) {
      if (building.kind == CityBuildingKind.park &&
          building.bounds.contains(point)) {
        return building;
      }
    }
    return null;
  }

  CityRoad? hitRoad(Offset point, {double tolerance = 8}) {
    for (final road in roads.reversed) {
      if (distanceToPolyline(point, road.points) <=
          road.kind.width / 2 + tolerance) {
        return road;
      }
    }
    return null;
  }

  Offset snap(Offset point) => Offset(
    ((point.dx / kCityGrid).round() * kCityGrid)
        .clamp(0.0, (kCitySheetSize.width / kCityGrid).floor() * kCityGrid)
        .toDouble(),
    ((point.dy / kCityGrid).round() * kCityGrid)
        .clamp(0.0, (kCitySheetSize.height / kCityGrid).floor() * kCityGrid)
        .toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'roads': roads.map((road) => road.toJson()).toList(),
    'buildings': buildings.map((building) => building.toJson()).toList(),
  };

  factory CityMap.fromJson(Map<String, dynamic> json) => CityMap(
    roads: (json['roads'] as List<dynamic>? ?? [])
        .map((road) => CityRoad.fromJson(road as Map<String, dynamic>))
        .toList(),
    buildings: (json['buildings'] as List<dynamic>? ?? [])
        .map(
          (building) => CityBuilding.fromJson(building as Map<String, dynamic>),
        )
        .toList(),
  );
}

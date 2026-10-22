import 'dart:math' as math;
import 'dart:ui';

import 'map_maker_geometry.dart';

const kCityGrid = 24.0;
const kCitySheetSize = Size(3200, 2400);
const kCityMetersPerUnit = .25;

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
    this.curved = false,
    this.name = '',
  }) : points = points ?? [];

  final String id;
  CityRoadKind kind;
  final List<Offset> points;
  bool curved;
  String name;

  List<Offset> get centerline {
    if (!curved || points.length < 3) return List.of(points);
    final result = <Offset>[points.first];
    for (var index = 0; index < points.length - 1; index++) {
      final p1 = points[index];
      final p2 = points[index + 1];
      final p0 = index == 0 ? p1 * 2 - p2 : points[index - 1];
      final p3 = index + 2 >= points.length ? p2 * 2 - p1 : points[index + 2];
      final steps = math
          .max(12, ((p2 - p1).distance / 6).ceil())
          .clamp(12, 180);
      for (var step = 1; step <= steps; step++) {
        final t = step / steps;
        final t2 = t * t;
        final t3 = t2 * t;
        result.add(
          (p1 * 2 +
                  (p2 - p0) * t +
                  (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
                  (p0 * -1 + p1 * 3 - p2 * 3 + p3) * t3) *
              .5,
        );
      }
    }
    return result;
  }

  double get length {
    final path = centerline;
    var total = 0.0;
    for (var index = 1; index < path.length; index++) {
      total += (path[index] - path[index - 1]).distance;
    }
    return total;
  }

  CityRoad clone() => CityRoad(
    id: id,
    kind: kind,
    points: List<Offset>.from(points),
    curved: curved,
    name: name,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'curved': curved,
    'name': name,
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
    curved: json['curved'] == true,
    name: json['name']?.toString() ?? '',
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
    this.angle = 0,
    this.roadId,
    this.roadAnchor,
  });

  final String id;
  CityBuildingKind kind;
  double x;
  double y;
  int quarterTurns;
  String name;
  double angle;
  String? roadId;
  Offset? roadAnchor;

  double get rotation => angle + quarterTurns * math.pi / 2;
  bool get hasParcel =>
      kind != CityBuildingKind.park && kind != CityBuildingKind.tree;
  bool get connected => roadId != null && roadAnchor != null;

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

  Offset transform(Offset point) =>
      position +
      Offset(
        point.dx * math.cos(rotation) - point.dy * math.sin(rotation),
        point.dx * math.sin(rotation) + point.dy * math.cos(rotation),
      );

  List<Offset> _corners(Size dimensions) => [
    transform(Offset(-dimensions.width / 2, -dimensions.height / 2)),
    transform(Offset(dimensions.width / 2, -dimensions.height / 2)),
    transform(Offset(dimensions.width / 2, dimensions.height / 2)),
    transform(Offset(-dimensions.width / 2, dimensions.height / 2)),
  ];

  List<Offset> get footprint => _corners(size);
  List<Offset> get parcel =>
      hasParcel ? _corners(Size(size.width + 24, size.height + 24)) : const [];
  Offset get entrance => transform(Offset(0, size.height / 2));

  Rect get bounds {
    final corners = footprint;
    return Rect.fromLTRB(
      corners.map((point) => point.dx).reduce(math.min),
      corners.map((point) => point.dy).reduce(math.min),
      corners.map((point) => point.dx).reduce(math.max),
      corners.map((point) => point.dy).reduce(math.max),
    );
  }

  bool contains(Offset point) {
    final delta = point - position;
    final local = Offset(
      delta.dx * math.cos(rotation) + delta.dy * math.sin(rotation),
      -delta.dx * math.sin(rotation) + delta.dy * math.cos(rotation),
    );
    return local.dx.abs() <= size.width / 2 &&
        local.dy.abs() <= size.height / 2;
  }

  CityBuilding clone() => CityBuilding(
    id: id,
    kind: kind,
    x: x,
    y: y,
    quarterTurns: quarterTurns,
    name: name,
    angle: angle,
    roadId: roadId,
    roadAnchor: roadAnchor,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'quarterTurns': quarterTurns,
    'name': name,
    'angle': angle,
    'roadId': roadId,
    'roadAnchor': roadAnchor == null
        ? null
        : {'x': roadAnchor!.dx, 'y': roadAnchor!.dy},
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
    angle: (json['angle'] as num?)?.toDouble() ?? 0,
    roadId: json['roadId']?.toString(),
    roadAnchor: json['roadAnchor'] is Map
        ? Offset(
            (json['roadAnchor']['x'] as num?)?.toDouble() ?? 0,
            (json['roadAnchor']['y'] as num?)?.toDouble() ?? 0,
          )
        : null,
  );
}

class CityJunction {
  CityJunction({
    required this.id,
    required this.position,
    required this.roadIds,
  });

  final String id;
  final Offset position;
  final List<String> roadIds;

  CityJunction clone() =>
      CityJunction(id: id, position: position, roadIds: List.of(roadIds));

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': position.dx,
    'y': position.dy,
    'roadIds': roadIds,
  };

  factory CityJunction.fromJson(Map<String, dynamic> json) => CityJunction(
    id: json['id']?.toString() ?? '',
    position: Offset(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
    ),
    roadIds: (json['roadIds'] as List<dynamic>? ?? [])
        .map((id) => id.toString())
        .toList(),
  );
}

class CityMap {
  CityMap({
    List<CityRoad>? roads,
    List<CityBuilding>? buildings,
    List<CityJunction>? junctions,
  }) : roads = roads ?? [],
       buildings = buildings ?? [],
       junctions = junctions ?? [];

  final List<CityRoad> roads;
  final List<CityBuilding> buildings;
  final List<CityJunction> junctions;

  CityMap clone() => CityMap(
    roads: roads.map((road) => road.clone()).toList(),
    buildings: buildings.map((building) => building.clone()).toList(),
    junctions: junctions.map((junction) => junction.clone()).toList(),
  );

  CityBuilding? hitBuilding(Offset point) {
    for (final building in buildings.reversed) {
      if (building.kind != CityBuildingKind.park && building.contains(point)) {
        return building;
      }
    }
    for (final building in buildings.reversed) {
      if (building.kind == CityBuildingKind.park && building.contains(point)) {
        return building;
      }
    }
    return null;
  }

  CityRoad? hitRoad(Offset point, {double tolerance = 8}) {
    for (final road in roads.reversed) {
      if (distanceToPolyline(point, road.centerline) <=
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
    'junctions': junctions.map((junction) => junction.toJson()).toList(),
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
    junctions: (json['junctions'] as List<dynamic>? ?? [])
        .map(
          (junction) => CityJunction.fromJson(junction as Map<String, dynamic>),
        )
        .toList(),
  );
}

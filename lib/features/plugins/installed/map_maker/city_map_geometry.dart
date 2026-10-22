import 'dart:math' as math;
import 'dart:ui';

import 'city_map_models.dart';
import 'map_maker_geometry.dart';

enum CitySnapKind { none, grid, vertex, segment, intersection }

class CitySnapResult {
  const CitySnapResult({
    required this.position,
    required this.kind,
    this.roadId,
  });

  final Offset position;
  final CitySnapKind kind;
  final String? roadId;
}

class CityPlacement {
  const CityPlacement({required this.building, required this.valid});

  final CityBuilding building;
  final bool valid;
}

class CityGeometry {
  CityGeometry(this.map);

  final CityMap map;

  CitySnapResult snap(
    Offset point, {
    double tolerance = 12,
    bool grid = true,
    bool vertices = true,
    bool segments = true,
    bool intersections = true,
    String? excludeRoadId,
    Set<String> excludeRoadIds = const {},
  }) {
    CitySnapResult? best;
    var nearest = tolerance;
    if (intersections) {
      for (final junction in map.junctions) {
        if (junction.roadIds
                .where(
                  (id) => id != excludeRoadId && !excludeRoadIds.contains(id),
                )
                .length <
            2) {
          continue;
        }
        final distance = (junction.position - point).distance;
        if (distance <= nearest) {
          nearest = distance;
          best = CitySnapResult(
            position: junction.position,
            kind: CitySnapKind.intersection,
            roadId: junction.roadIds.firstWhere(
              (id) => id != excludeRoadId && !excludeRoadIds.contains(id),
            ),
          );
        }
      }
    }
    if (best != null) return best;
    if (vertices) {
      for (final road in map.roads) {
        if (road.id == excludeRoadId || excludeRoadIds.contains(road.id)) {
          continue;
        }
        for (final vertex in road.points) {
          final distance = (vertex - point).distance;
          if (distance <= nearest) {
            nearest = distance;
            best = CitySnapResult(
              position: vertex,
              kind: CitySnapKind.vertex,
              roadId: road.id,
            );
          }
        }
      }
    }
    if (best != null) return best;
    if (segments) {
      for (final road in map.roads) {
        if (road.id == excludeRoadId || excludeRoadIds.contains(road.id)) {
          continue;
        }
        final projection = _project(point, road.centerline);
        if (projection != null && projection.distance <= nearest) {
          nearest = projection.distance;
          best = CitySnapResult(
            position: projection.position,
            kind: CitySnapKind.segment,
            roadId: road.id,
          );
        }
      }
    }
    if (best != null) return best;
    return CitySnapResult(
      position: grid ? map.snap(point) : _boundPoint(point),
      kind: grid ? CitySnapKind.grid : CitySnapKind.none,
    );
  }

  CityPlacement placeBuilding(
    CityBuilding prototype,
    Offset pointer, {
    bool connect = true,
    bool grid = true,
  }) {
    final centerlines = {
      for (final road in map.roads) road.id: road.centerline,
    };
    final free = prototype.clone()
      ..roadId = null
      ..roadAnchor = null
      ..position = grid ? map.snap(pointer) : _boundPoint(pointer);
    _boundBuilding(free);
    if (!connect || !prototype.hasParcel) {
      return CityPlacement(
        building: free,
        valid: _available(free, centerlines),
      );
    }

    final nearby = <({CityRoad road, _Projection projection})>[];
    for (final road in map.roads) {
      if (!_accessible(road)) continue;
      final projection = _project(pointer, centerlines[road.id]!);
      if (projection != null && projection.distance <= 240) {
        nearby.add((road: road, projection: projection));
      }
    }
    nearby.sort(
      (a, b) => a.projection.distance.compareTo(b.projection.distance),
    );
    CityBuilding? preview;
    for (final option in nearby) {
      final road = option.road;
      final centerline = centerlines[road.id]!;
      final frontage = prototype.size.width + 24;
      final depth = prototype.size.height + 24;
      final length = _length(centerline);
      if (length < frontage) continue;
      final rounded = (option.projection.along / frontage).round() * frontage;
      final distances = <double>{};
      for (final offset in [0, -1, 1, -2, 2, -3, 3, -4, 4]) {
        distances.add(
          (rounded + offset * frontage)
              .clamp(frontage / 2, length - frontage / 2)
              .toDouble(),
        );
      }
      final tangent = option.projection.tangent;
      final normal = Offset(-tangent.dy, tangent.dx);
      final preferredSide =
          _dot(pointer - option.projection.position, normal) < 0 ? -1.0 : 1.0;
      for (final along in distances) {
        final section = _atDistance(centerline, along);
        if (section == null) continue;
        final perpendicular = Offset(-section.tangent.dy, section.tangent.dx);
        final center =
            section.position +
            perpendicular *
                preferredSide *
                (road.kind.width / 2 + 6 + depth / 2);
        final candidate = prototype.clone()
          ..position = center
          ..angle =
              math.atan2(section.tangent.dy, section.tangent.dx) +
              (preferredSide > 0 ? math.pi : 0)
          ..quarterTurns = 0
          ..roadId = road.id
          ..roadAnchor =
              section.position +
              perpendicular * preferredSide * road.kind.width / 2;
        preview ??= candidate;
        if (_available(candidate, centerlines)) {
          return CityPlacement(building: candidate, valid: true);
        }
      }
    }
    return CityPlacement(building: preview ?? free, valid: false);
  }

  void rebuildTopology() {
    final nodes = <_Node>[];
    void add(Offset position, Iterable<String> ids) {
      _Node? existing;
      for (final node in nodes) {
        if ((node.position - position).distance <= .05) {
          existing = node;
          break;
        }
      }
      if (existing == null) {
        nodes.add(_Node(position, ids.toSet()));
      } else {
        existing.roadIds.addAll(ids);
      }
    }

    final segments = <_Segment>[];
    for (final road in map.roads) {
      final line = road.centerline;
      if (line.isEmpty) continue;
      add(line.first, [road.id]);
      add(line.last, [road.id]);
      for (var index = 1; index < line.length; index++) {
        if ((line[index] - line[index - 1]).distance > .001) {
          segments.add(_Segment(road.id, line[index - 1], line[index]));
        }
      }
    }
    final buckets = <String, List<int>>{};
    final seen = <String>{};
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final bounds = Rect.fromPoints(segment.a, segment.b);
      for (
        var x = (bounds.left / 128).floor();
        x <= (bounds.right / 128).floor();
        x++
      ) {
        for (
          var y = (bounds.top / 128).floor();
          y <= (bounds.bottom / 128).floor();
          y++
        ) {
          final key = '$x:$y';
          final bucket = buckets.putIfAbsent(key, () => []);
          for (final otherIndex in bucket) {
            if (!seen.add('$otherIndex:$index')) continue;
            final other = segments[otherIndex];
            if (segment.roadId == other.roadId) continue;
            for (final point in _intersections(
              segment.a,
              segment.b,
              other.a,
              other.b,
            )) {
              add(point, [segment.roadId, other.roadId]);
            }
          }
          bucket.add(index);
        }
      }
    }
    map.junctions
      ..clear()
      ..addAll(
        nodes.map(
          (node) => CityJunction(
            id: 'node-${(node.position.dx * 1000).round()}-${(node.position.dy * 1000).round()}',
            position: node.position,
            roadIds: node.roadIds.toList()..sort(),
          ),
        ),
      );
    for (final building in map.buildings) {
      if (building.roadId == null) continue;
      CityRoad? attached;
      for (final road in map.roads) {
        if (road.id == building.roadId && _accessible(road)) {
          attached = road;
          break;
        }
      }
      final projection = attached == null
          ? null
          : _project(building.entrance, attached.centerline);
      if (attached == null ||
          projection == null ||
          projection.distance > 240 ||
          _dot(
                building.entrance - building.position,
                projection.position - building.entrance,
              ) <
              -.001) {
        building.roadId = null;
        building.roadAnchor = null;
      } else {
        final delta = building.entrance - projection.position;
        final normal = delta.distance > .001
            ? delta / delta.distance
            : Offset(-projection.tangent.dy, projection.tangent.dx);
        building.roadAnchor =
            projection.position + normal * attached.kind.width / 2;
      }
    }
  }

  Set<String> connectedRoadIds(String roadId) {
    if (!map.roads.any((road) => road.id == roadId)) return {};
    final result = <String>{roadId};
    final pending = <String>[roadId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final node in map.junctions) {
        if (!node.roadIds.contains(current)) continue;
        for (final id in node.roadIds) {
          if (result.add(id)) pending.add(id);
        }
      }
    }
    return result;
  }

  bool _available(
    CityBuilding candidate,
    Map<String, List<Offset>> centerlines,
  ) {
    final polygon = candidate.hasParcel
        ? candidate.parcel
        : candidate.footprint;
    if (polygon.any(
      (point) =>
          point.dx < 0 ||
          point.dy < 0 ||
          point.dx > kCitySheetSize.width ||
          point.dy > kCitySheetSize.height,
    )) {
      return false;
    }
    final bounds = _polygonBounds(polygon);
    for (final other in map.buildings) {
      if (other.id == candidate.id ||
          other.kind == CityBuildingKind.tree ||
          candidate.kind == CityBuildingKind.tree) {
        continue;
      }
      final boundary = other.hasParcel ? other.parcel : other.footprint;
      if (!bounds.overlaps(_polygonBounds(boundary))) continue;
      if (_polygonsOverlap(polygon, boundary)) return false;
    }
    if (candidate.kind == CityBuildingKind.tree) return true;
    for (final road in map.roads) {
      final centerline = centerlines[road.id]!;
      for (var index = 1; index < centerline.length; index++) {
        if (!Rect.fromPoints(
          centerline[index - 1],
          centerline[index],
        ).inflate(road.kind.width / 2 + 2).overlaps(bounds)) {
          continue;
        }
        if (_segmentPolygonDistance(
              centerline[index - 1],
              centerline[index],
              polygon,
            ) <
            road.kind.width / 2 + 2) {
          return false;
        }
      }
    }
    return true;
  }
}

bool _accessible(CityRoad road) =>
    road.kind == CityRoadKind.street || road.kind == CityRoadKind.avenue;

Offset _boundPoint(Offset point) => Offset(
  point.dx.clamp(0, kCitySheetSize.width).toDouble(),
  point.dy.clamp(0, kCitySheetSize.height).toDouble(),
);

void _boundBuilding(CityBuilding building) {
  final bounds = building.hasParcel
      ? _polygonBounds(building.parcel)
      : building.bounds;
  var dx = 0.0;
  var dy = 0.0;
  if (bounds.left < 0) dx = -bounds.left;
  if (bounds.right > kCitySheetSize.width) {
    dx = kCitySheetSize.width - bounds.right;
  }
  if (bounds.top < 0) dy = -bounds.top;
  if (bounds.bottom > kCitySheetSize.height) {
    dy = kCitySheetSize.height - bounds.bottom;
  }
  building.position += Offset(dx, dy);
}

Rect _polygonBounds(List<Offset> points) => Rect.fromLTRB(
  points.map((point) => point.dx).reduce(math.min),
  points.map((point) => point.dy).reduce(math.min),
  points.map((point) => point.dx).reduce(math.max),
  points.map((point) => point.dy).reduce(math.max),
);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

class _Projection {
  const _Projection(this.position, this.tangent, this.along, this.distance);
  final Offset position;
  final Offset tangent;
  final double along;
  final double distance;
}

_Projection? _project(Offset point, List<Offset> line) {
  _Projection? best;
  var along = 0.0;
  for (var index = 1; index < line.length; index++) {
    final a = line[index - 1];
    final delta = line[index] - a;
    final length = delta.distance;
    if (length < .001) continue;
    final t = (_dot(point - a, delta) / (length * length)).clamp(0.0, 1.0);
    final projected = a + delta * t;
    final distance = (point - projected).distance;
    if (best == null || distance < best.distance) {
      best = _Projection(
        projected,
        delta / length,
        along + length * t,
        distance,
      );
    }
    along += length;
  }
  return best;
}

double _length(List<Offset> line) {
  var length = 0.0;
  for (var index = 1; index < line.length; index++) {
    length += (line[index] - line[index - 1]).distance;
  }
  return length;
}

_Projection? _atDistance(List<Offset> line, double distance) {
  var along = 0.0;
  for (var index = 1; index < line.length; index++) {
    final delta = line[index] - line[index - 1];
    final length = delta.distance;
    if (length < .001) continue;
    if (along + length >= distance || index == line.length - 1) {
      final t = ((distance - along) / length).clamp(0.0, 1.0);
      return _Projection(
        line[index - 1] + delta * t,
        delta / length,
        along + length * t,
        0,
      );
    }
    along += length;
  }
  return null;
}

Iterable<Offset> _intersections(Offset a, Offset b, Offset c, Offset d) sync* {
  final ab = b - a;
  final cd = d - c;
  final denominator = _cross(ab, cd);
  if (denominator.abs() < .000001) {
    if (_cross(c - a, ab).abs() > .001) return;
    final seen = <Offset>{};
    for (final point in [a, b, c, d]) {
      if (distanceToSegment(point, a, b) < .001 &&
          distanceToSegment(point, c, d) < .001 &&
          seen.add(point)) {
        yield point;
      }
    }
    return;
  }
  final t = _cross(c - a, cd) / denominator;
  final u = _cross(c - a, ab) / denominator;
  if (t >= -.000001 && t <= 1.000001 && u >= -.000001 && u <= 1.000001) {
    yield a + ab * t.clamp(0, 1);
  }
}

bool _polygonsOverlap(List<Offset> a, List<Offset> b) {
  for (final polygon in [a, b]) {
    for (var index = 0; index < polygon.length; index++) {
      final edge = polygon[(index + 1) % polygon.length] - polygon[index];
      final normal = Offset(-edge.dy, edge.dx);
      final valuesA = a.map((point) => _dot(point, normal));
      final valuesB = b.map((point) => _dot(point, normal));
      if (valuesA.reduce(math.max) <= valuesB.reduce(math.min) + .001 ||
          valuesB.reduce(math.max) <= valuesA.reduce(math.min) + .001) {
        return false;
      }
    }
  }
  return true;
}

bool _inside(Offset point, List<Offset> polygon) {
  var positive = false;
  var negative = false;
  for (var index = 0; index < polygon.length; index++) {
    final value = _cross(
      polygon[(index + 1) % polygon.length] - polygon[index],
      point - polygon[index],
    );
    positive = positive || value > .000001;
    negative = negative || value < -.000001;
  }
  return !(positive && negative);
}

double _segmentPolygonDistance(Offset a, Offset b, List<Offset> polygon) {
  if (_inside(a, polygon) || _inside(b, polygon)) return 0;
  var distance = double.infinity;
  for (var index = 0; index < polygon.length; index++) {
    final c = polygon[index];
    final d = polygon[(index + 1) % polygon.length];
    if (_intersections(a, b, c, d).isNotEmpty) return 0;
    distance = math.min(distance, distanceToSegment(c, a, b));
    distance = math.min(distance, distanceToSegment(a, c, d));
    distance = math.min(distance, distanceToSegment(b, c, d));
  }
  return distance;
}

class _Node {
  _Node(this.position, this.roadIds);
  final Offset position;
  final Set<String> roadIds;
}

class _Segment {
  _Segment(this.roadId, this.a, this.b);
  final String roadId;
  final Offset a;
  final Offset b;
}

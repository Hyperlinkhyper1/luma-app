import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_geometry.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_models.dart';

CityRoad _road(
  String id,
  Offset from,
  Offset to, {
  CityRoadKind kind = CityRoadKind.street,
}) => CityRoad(id: id, kind: kind, points: [from, to]);

CityBuilding _house(String id) =>
    CityBuilding(id: id, kind: CityBuildingKind.house, x: 0, y: 0);

void main() {
  test(
    'smooth roads retain authored vertices and hit their actual centerline',
    () {
      final road = CityRoad(
        id: 'curve',
        curved: true,
        points: [
          const Offset(100, 300),
          const Offset(300, 100),
          const Offset(500, 300),
        ],
      );
      final line = road.centerline;
      expect(line.length, greaterThan(10));
      expect(line.first, road.points.first);
      expect(line.last, road.points.last);
      expect(line, contains(road.points[1]));
      final sample = line[line.length ~/ 4];
      final city = CityMap(roads: [road]);
      expect(city.hitRoad(sample, tolerance: 0), same(road));
      final straight = road.clone()..curved = false;
      expect(straight.centerline, road.points);
      expect(city.hitRoad(const Offset(300, 300), tolerance: 0), isNull);
      expect(road.length, greaterThan(straight.length));
    },
  );

  test(
    'feature snapping preserves off-grid coordinates and respects scene tolerance',
    () {
      final road = _road(
        'street',
        const Offset(101, 203),
        const Offset(701, 203),
      );
      final geometry = CityGeometry(CityMap(roads: [road]));
      final vertex = geometry.snap(const Offset(107, 208), tolerance: 12);
      expect(vertex.kind, CitySnapKind.vertex);
      expect(vertex.position, const Offset(101, 203));
      final segment = geometry.snap(const Offset(355, 210), tolerance: 12);
      expect(segment.kind, CitySnapKind.segment);
      expect(segment.position, const Offset(355, 203));
      expect(
        geometry.snap(const Offset(355, 210), tolerance: 5).kind,
        CitySnapKind.grid,
      );
      expect(
        geometry.snap(const Offset(107, 208), excludeRoadId: 'street').kind,
        CitySnapKind.grid,
      );
      expect(
        geometry.snap(const Offset(17, 29), grid: false).position,
        const Offset(17, 29),
      );
    },
  );

  test(
    'T junctions, crossings and shared endpoints create saved network connectivity',
    () {
      final city = CityMap(
        roads: [
          _road('main', const Offset(100, 300), const Offset(700, 300)),
          _road('branch', const Offset(300, 100), const Offset(300, 300)),
          _road('crossing', const Offset(500, 100), const Offset(500, 500)),
          _road('extension', const Offset(700, 300), const Offset(900, 400)),
          _road('isolated', const Offset(1000, 100), const Offset(1200, 100)),
        ],
      );
      final geometry = CityGeometry(city)..rebuildTopology();
      expect(geometry.connectedRoadIds('branch'), {
        'main',
        'branch',
        'crossing',
        'extension',
      });
      expect(geometry.connectedRoadIds('isolated'), {'isolated'});
      expect(
        city.junctions
            .singleWhere((node) => node.position == const Offset(300, 300))
            .roadIds
            .toSet(),
        {'main', 'branch'},
      );
      final snap = geometry.snap(const Offset(302, 303));
      expect(snap.kind, CitySnapKind.intersection);
      final restored = CityMap.fromJson(jsonDecode(jsonEncode(city.toJson())));
      expect(CityGeometry(restored).connectedRoadIds('crossing'), {
        'main',
        'branch',
        'crossing',
        'extension',
      });
    },
  );

  test(
    'snapping to a curve creates a true shared junction without reshaping it',
    () {
      final curve = CityRoad(
        id: 'curve',
        curved: true,
        points: [
          const Offset(100, 300),
          const Offset(300, 100),
          const Offset(500, 300),
        ],
      );
      final city = CityMap(roads: [curve]);
      final original = List.of(curve.centerline);
      final anchor = original[original.length ~/ 3];
      final geometry = CityGeometry(city);
      final snap = geometry.snap(
        anchor + const Offset(1, 2),
        vertices: false,
        tolerance: 8,
      );
      city.roads.add(_road('branch', const Offset(220, 500), snap.position));
      geometry.rebuildTopology();
      expect(curve.centerline, original);
      expect(geometry.connectedRoadIds('branch'), {'branch', 'curve'});
    },
  );

  test(
    'houses align to frontage, connect at curb and occupy adjoining parcels',
    () {
      final road = _road(
        'street',
        const Offset(100, 400),
        const Offset(1100, 400),
      );
      final city = CityMap(roads: [road]);
      final geometry = CityGeometry(city);
      final first = geometry.placeBuilding(
        _house('one'),
        const Offset(320, 330),
      );
      expect(first.valid, isTrue);
      expect(first.building.roadId, 'street');
      expect(first.building.roadAnchor!.dy, 388);
      expect(
        first.building.entrance.dy,
        lessThan(first.building.roadAnchor!.dy),
      );
      expect(first.building.rotation, closeTo(0, .0001));
      city.buildings.add(first.building);
      final second = geometry.placeBuilding(
        _house('two'),
        const Offset(320, 330),
      );
      expect(second.valid, isTrue);
      expect(
        (first.building.position.dx - second.building.position.dx).abs(),
        72,
      );
      expect(first.building.position.dy, second.building.position.dy);
      expect(
        first.building.parcel.toSet().intersection(
          second.building.parcel.toSet(),
        ),
        hasLength(2),
      );
      city.buildings.add(second.building);
      geometry.rebuildTopology();
      final reopened = CityMap.fromJson(jsonDecode(jsonEncode(city.toJson())));
      expect(reopened.buildings.first.roadId, 'street');
      expect(reopened.buildings.first.roadAnchor, first.building.roadAnchor);
    },
  );

  test(
    'curved frontage follows tangent and exact rotated footprint selection',
    () {
      final city = CityMap(
        roads: [
          CityRoad(
            id: 'curve',
            curved: true,
            points: [
              const Offset(100, 500),
              const Offset(450, 300),
              const Offset(900, 500),
            ],
          ),
        ],
      );
      final placement = CityGeometry(
        city,
      ).placeBuilding(_house('house'), const Offset(270, 350));
      expect(placement.valid, isTrue);
      expect(placement.building.connected, isTrue);
      expect(placement.building.angle.abs(), greaterThan(.01));
      city.buildings.add(placement.building);
      expect(
        city.hitBuilding(placement.building.position),
        same(placement.building),
      );
      final building = _house('rotated')
        ..position = const Offset(1300, 1000)
        ..angle = math.pi / 4;
      city.buildings.add(building);
      expect(building.bounds.contains(const Offset(1330, 1030)), isTrue);
      expect(city.hitBuilding(const Offset(1330, 1030)), isNull);
    },
  );

  test('housing cannot access highways or overlap occupied lots and roads', () {
    final city = CityMap(
      roads: [
        _road(
          'highway',
          const Offset(100, 400),
          const Offset(1100, 400),
          kind: CityRoadKind.highway,
        ),
      ],
    );
    final geometry = CityGeometry(city);
    expect(
      geometry.placeBuilding(_house('house'), const Offset(350, 330)).valid,
      isFalse,
    );
    final detached = geometry.placeBuilding(
      _house('house'),
      const Offset(350, 300),
      connect: false,
    );
    expect(detached.valid, isTrue);
    expect(detached.building.connected, isFalse);
    city.buildings.add(detached.building);
    expect(
      geometry
          .placeBuilding(
            _house('second'),
            detached.building.position,
            connect: false,
          )
          .valid,
      isFalse,
    );
    expect(
      geometry
          .placeBuilding(
            _house('house'),
            detached.building.position,
            connect: false,
          )
          .valid,
      isTrue,
    );
    expect(
      geometry
          .placeBuilding(
            _house('road-overlap'),
            const Offset(350, 400),
            connect: false,
          )
          .valid,
      isFalse,
    );
  });

  test(
    'deleted or ineligible roads clear housing references and undo snapshots isolate topology',
    () {
      final road = _road(
        'street',
        const Offset(100, 400),
        const Offset(1100, 400),
      );
      final city = CityMap(roads: [road]);
      final geometry = CityGeometry(city);
      city.buildings.add(
        geometry
            .placeBuilding(_house('house'), const Offset(350, 330))
            .building,
      );
      geometry.rebuildTopology();
      final before = city.clone();
      road.kind = CityRoadKind.highway;
      geometry.rebuildTopology();
      expect(city.buildings.single.connected, isFalse);
      expect(before.buildings.single.connected, isTrue);
      city.roads.clear();
      geometry.rebuildTopology();
      expect(city.junctions, isEmpty);
      expect(before.junctions, hasLength(2));
    },
  );

  test('a driveway never crosses a building when its road moves behind it', () {
    final road = _road(
      'street',
      const Offset(100, 400),
      const Offset(1100, 400),
    );
    final city = CityMap(roads: [road]);
    final geometry = CityGeometry(city);
    final house = geometry
        .placeBuilding(_house('house'), const Offset(350, 330))
        .building;
    city.buildings.add(house);
    geometry.rebuildTopology();
    expect(house.connected, isTrue);
    road.points[0] = const Offset(100, 200);
    road.points[1] = const Offset(1100, 200);
    geometry.rebuildTopology();
    expect(house.roadId, isNull);
    expect(house.roadAnchor, isNull);
  });
}

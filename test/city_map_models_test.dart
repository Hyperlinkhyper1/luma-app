import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_models.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_models.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_store.dart';

CityMap sampleCity() => CityMap(
  roads: [
    for (final kind in CityRoadKind.values)
      CityRoad(
        id: 'road-${kind.name}',
        kind: kind,
        points: [
          Offset(24, 120.0 * kind.index),
          Offset(240, 120.0 * kind.index),
          Offset(288, 120.0 * kind.index + 48),
        ],
      ),
  ],
  buildings: [
    for (final kind in CityBuildingKind.values)
      CityBuilding(
        id: 'building-${kind.name}',
        kind: kind,
        x: 240.0 * kind.index + 120,
        y: 600,
        quarterTurns: kind.index % 4,
        name: 'Custom ${kind.name}',
      ),
  ],
);

void main() {
  test('all roads and building types retain identity through JSON', () {
    final original = sampleCity();
    final serialized = jsonDecode(jsonEncode(original.toJson()));
    final restored = CityMap.fromJson(serialized as Map<String, dynamic>);

    expect(restored.toJson(), original.toJson());
    expect(restored.roads.map((road) => road.kind), CityRoadKind.values);
    expect(
      restored.buildings.map((building) => building.kind),
      CityBuildingKind.values,
    );
  });

  test('city cloning isolates edits and nested road point lists', () {
    final original = sampleCity();
    final originalData = jsonEncode(original.toJson());
    final working = original.clone();

    working.roads.first.kind = CityRoadKind.highway;
    working.roads.first.points[0] = const Offset(999, 999);
    working.roads.removeLast();
    working.buildings.first.position = const Offset(0, 0);
    working.buildings.first.name = 'Edited';
    working.buildings.removeLast();

    expect(jsonEncode(original.toJson()), originalData);
  });

  test('rotated footprints select the topmost visible building', () {
    final building = CityBuilding(
      id: 'shop',
      kind: CityBuildingKind.shop,
      x: 120,
      y: 120,
    );
    final city = CityMap(buildings: [building]);

    expect(city.hitBuilding(const Offset(152, 120)), same(building));
    expect(city.hitBuilding(const Offset(120, 152)), isNull);
    building.quarterTurns = 1;
    expect(city.hitBuilding(const Offset(152, 120)), isNull);
    expect(city.hitBuilding(const Offset(120, 152)), same(building));

    final overlapping = CityBuilding(
      id: 'house',
      kind: CityBuildingKind.house,
      x: 120,
      y: 120,
    );
    city.buildings.add(overlapping);
    expect(city.hitBuilding(const Offset(120, 120)), same(overlapping));
  });

  test('parks remain behind buildings regardless of insertion order', () {
    final house = CityBuilding(
      id: 'house',
      kind: CityBuildingKind.house,
      x: 120,
      y: 120,
    );
    final park = CityBuilding(
      id: 'park',
      kind: CityBuildingKind.park,
      x: 120,
      y: 120,
    );
    final city = CityMap(buildings: [house, park]);

    expect(city.hitBuilding(const Offset(120, 120)), same(house));
    expect(city.hitBuilding(const Offset(168, 120)), same(park));
    city.buildings.remove(house);
    expect(city.hitBuilding(const Offset(120, 120)), same(park));
  });

  test('road selection covers actual road width and respects stacking', () {
    final highway = CityRoad(
      id: 'highway',
      kind: CityRoadKind.highway,
      points: [const Offset(24, 120), const Offset(240, 120)],
    );
    final street = CityRoad(
      id: 'street',
      points: [const Offset(24, 120), const Offset(240, 120)],
    );
    final city = CityMap(roads: [highway, street]);

    expect(city.hitRoad(const Offset(120, 120)), same(street));
    expect(city.hitRoad(const Offset(120, 146), tolerance: 0), same(highway));
    expect(city.hitRoad(const Offset(120, 149), tolerance: 0), isNull);
    expect(city.hitRoad(const Offset(120, 155)), same(highway));
    expect(city.hitRoad(const Offset(120, 157)), isNull);
  });

  test('grid snapping stays inside the sheet at every edge', () {
    final city = CityMap();
    expect(city.snap(const Offset(23, 25)), const Offset(24, 24));
    expect(city.snap(const Offset(-100, -1)), Offset.zero);
    final edge = city.snap(const Offset(9000, 9000));
    expect(edge.dx, lessThanOrEqualTo(kCitySheetSize.width));
    expect(edge.dy, lessThanOrEqualTo(kCitySheetSize.height));
    expect(edge.dx % kCityGrid, 0);
    expect(edge.dy % kCityGrid, 0);
  });

  test('legacy saves open with empty cities and retain transit content', () {
    final legacy = {
      'id': 'legacy',
      'title': 'Old transit map',
      'kind': 'transit',
      'updatedAt': '2026-10-01T12:00:00.000',
      'transit': {
        'stations': [
          {'id': 'station', 'name': 'Central', 'x': 48, 'y': 72},
        ],
      },
    };
    final restored = MapMakerSave.fromJson(legacy);

    expect(restored.kind, MapMakerKind.transit);
    expect(restored.transit.stations.single.name, 'Central');
    expect(restored.city.roads, isEmpty);
    expect(restored.city.buildings, isEmpty);
    expect(
      MapMakerSave.fromJson(restored.toJson()).transit.toJson(),
      restored.transit.toJson(),
    );
  });

  test('unknown future types use editable defaults', () {
    expect(
      CityRoad.fromJson({'id': 'future', 'kind': 'future'}).kind,
      CityRoadKind.street,
    );
    final future = CityBuilding.fromJson({
      'id': 'future',
      'kind': 'future',
      'quarterTurns': -1,
    });
    expect(future.kind, CityBuildingKind.house);
    expect(future.quarterTurns, 3);
  });

  test(
    'mixed saves reopen with every city object and independent copies',
    () async {
      final store = MapMakerStore.memory();
      final transit = await store.createTransit(title: 'Metro');
      final city = await store.createCity(title: '  New town  ');
      expect(city.kind, MapMakerKind.city);
      expect(city.title, 'New town');
      expect(city.id, isNot(transit.id));

      final working = city.clone();
      working.city = sampleCity();
      expect(store.byId(city.id)!.city.roads, isEmpty);
      store.put(working);
      await store.flush();

      final snapshot = jsonDecode(jsonEncode(await store.exportData()));
      final reopened = MapMakerStore.memory();
      await reopened.importData(snapshot);
      expect(reopened.saves.length, 2);
      expect(reopened.byId(city.id)!.city.toJson(), working.city.toJson());
      expect(reopened.byId(city.id)!.kind, MapMakerKind.city);
      expect(reopened.byId(transit.id)!.kind, MapMakerKind.transit);

      await reopened.rename(city.id, 'Renamed town');
      expect(reopened.byId(city.id)!.title, 'Renamed town');
      expect(store.byId(city.id)!.title, 'New town');
      await reopened.delete(city.id);
      expect(reopened.saves.single.id, transit.id);
      store.dispose();
      reopened.dispose();
    },
  );
}

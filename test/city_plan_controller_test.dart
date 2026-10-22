import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_geometry.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_models.dart';
import 'package:luma/features/plugins/installed/map_maker/city_plan_controller.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_store.dart';

void main() {
  late MapMakerStore store;
  late CityPlanController plan;

  setUp(() async {
    store = MapMakerStore.memory();
    plan = CityPlanController(save: await store.createCity(), store: store);
  });
  tearDown(() async {
    await store.flush();
    plan.dispose();
    store.dispose();
  });

  test('road drafts commit different kinds and undo independently', () {
    for (final kind in CityRoadKind.values) {
      plan.chooseRoad(kind);
      plan.tap(const Offset(101, 99));
      plan.tap(const Offset(101, 99));
      expect(plan.finishRoad(), isFalse);
      plan.tap(const Offset(301, 99));
      expect(plan.finishRoad(), isTrue);
    }
    expect(plan.map.roads.map((road) => road.kind), CityRoadKind.values);
    expect(plan.map.roads.first.points, [
      const Offset(96, 96),
      const Offset(312, 96),
    ]);
    plan.undo();
    expect(plan.save.city.roads, hasLength(3));
    plan.redo();
    expect(plan.save.city.roads, hasLength(4));
    plan.chooseRoad(CityRoadKind.street);
    plan.tap(const Offset(20, 20));
    plan.cancelRoad();
    expect(plan.draftRoad, isEmpty);
    expect(plan.save.city.roads, hasLength(4));
  });

  test('moving is one undo step and rotation keeps pieces in bounds', () {
    plan.setConnectHousing(false);
    plan.chooseBuilding(CityBuildingKind.school);
    plan.tap(const Offset(120, 120));
    final id = plan.map.buildings.single.id;
    plan.setTool(CityPlanTool.select);
    plan.beginMove(const Offset(120, 120));
    plan.moveTo(const Offset(240, 240));
    plan.moveTo(const Offset(400, 400));
    plan.endMove();
    expect(plan.map.buildings.single.position, const Offset(408, 408));
    plan.undo();
    expect(plan.map.buildings.single.id, id);
    expect(plan.map.buildings.single.position, const Offset(120, 120));
    plan.redo();
    plan.selectAt(const Offset(408, 408));
    plan.beginMove(const Offset(408, 408));
    plan.moveTo(const Offset(-1000, -1000));
    plan.endMove();
    plan.rotate();
    final bounds = plan.map.buildings.single.bounds;
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(plan.map.buildings.single.quarterTurns, 1);
    plan.deleteSelection();
    expect(plan.save.city.buildings, isEmpty);
    plan.undo();
    expect(plan.save.city.buildings.single.id, id);
  });

  test('new edits discard redo and saved snapshots stay isolated', () {
    plan.setConnectHousing(false);
    plan.chooseBuilding(CityBuildingKind.house);
    plan.tap(const Offset(120, 120));
    final savedSnapshot = plan.save.city;
    plan.setTool(CityPlanTool.select);
    plan.beginMove(const Offset(120, 120));
    plan.moveTo(const Offset(240, 240));
    expect(savedSnapshot.buildings.single.position, const Offset(120, 120));
    plan.endMove();
    plan.undo();
    plan.chooseBuilding(CityBuildingKind.shop);
    plan.tap(const Offset(360, 360));
    expect(plan.canRedo, isFalse);
    expect(plan.save.city.buildings.map((building) => building.kind), [
      CityBuildingKind.house,
      CityBuildingKind.shop,
    ]);
  });

  test('feature snapping respects zoom tolerance and disabled modes', () {
    plan.map.roads.add(
      CityRoad(
        id: 'off-grid',
        points: [const Offset(101, 103), const Offset(301, 103)],
      ),
    );
    plan.setSnapping(grid: false, segments: false, intersections: false);
    plan.updateHover(const Offset(108, 103));
    expect(plan.hoverSnap!.kind, CitySnapKind.vertex);
    expect(plan.hoverSnap!.position, const Offset(101, 103));
    plan.viewScale = 4;
    plan.updateHover(const Offset(108, 103));
    expect(plan.hoverSnap!.kind, CitySnapKind.none);
    expect(plan.hoverSnap!.position, const Offset(108, 103));
    plan.viewScale = 1;
    plan.setSnapping(vertices: false, segments: true);
    plan.updateHover(const Offset(178, 108));
    expect(plan.hoverSnap!.kind, CitySnapKind.segment);
    expect(plan.hoverSnap!.position, const Offset(178, 103));
    plan.setSnapping(enabled: false);
    expect(plan.snappedPoint(const Offset(178, 108)), const Offset(178, 108));
  });

  test('curved drafts need three points and persist their geometry', () {
    plan.chooseRoad(CityRoadKind.avenue);
    plan.setCurvedRoad(true);
    plan.tap(const Offset(120, 240));
    plan.tap(const Offset(240, 120));
    expect(plan.canFinishRoad, isFalse);
    expect(plan.finishRoad(), isFalse);
    plan.tap(const Offset(480, 240));
    expect(plan.finishRoad(), isTrue);
    final road = plan.save.city.roads.single;
    expect(road.curved, isTrue);
    expect(road.centerline.length, greaterThan(road.points.length));
    plan.undo();
    expect(plan.save.city.roads, isEmpty);
    plan.redo();
    expect(plan.save.city.roads.single.curved, isTrue);
  });

  test('houses connect to streets and road deletion clears actual access', () {
    plan.chooseRoad(CityRoadKind.street);
    plan.tap(const Offset(96, 240));
    plan.tap(const Offset(960, 240));
    plan.finishRoad();
    final roadId = plan.map.roads.single.id;
    plan.chooseBuilding(CityBuildingKind.house);
    expect(plan.previewPlacement(const Offset(240, 320)).valid, isTrue);
    plan.tap(const Offset(240, 320));
    final house = plan.save.city.buildings.single;
    expect(house.roadId, roadId);
    expect(house.roadAnchor, isNotNull);
    expect(house.roadAnchor!.dy, closeTo(252, .01));
    expect((house.entrance - house.roadAnchor!).distance, greaterThan(0));
    plan.setTool(CityPlanTool.select);
    plan.selectAt(const Offset(600, 240));
    plan.deleteSelection();
    expect(plan.save.city.buildings.single.roadId, isNull);
    expect(plan.save.city.buildings.single.roadAnchor, isNull);
    plan.undo();
    expect(plan.save.city.buildings.single.roadId, roadId);
    expect(plan.save.city.roads.single.id, roadId);
  });

  test('connected housing rejects highways and detached overlap', () {
    plan.chooseRoad(CityRoadKind.highway);
    plan.tap(const Offset(96, 240));
    plan.tap(const Offset(960, 240));
    plan.finishRoad();
    plan.chooseBuilding(CityBuildingKind.house);
    expect(plan.placementValid(const Offset(240, 320)), isFalse);
    plan.tap(const Offset(240, 320));
    expect(plan.save.city.buildings, isEmpty);
    plan.setConnectHousing(false);
    plan.tap(const Offset(240, 400));
    plan.tap(const Offset(240, 400));
    expect(plan.save.city.buildings, hasLength(1));
    expect(plan.save.city.buildings.single.roadId, isNull);
  });

  test('road control point drag is one undo step and supports attributes', () {
    plan.chooseRoad(CityRoadKind.street);
    plan.tap(const Offset(120, 120));
    plan.tap(const Offset(360, 120));
    plan.tap(const Offset(480, 240));
    plan.finishRoad();
    plan.setTool(CityPlanTool.select);
    plan.beginMove(const Offset(360, 120));
    expect(plan.movingRoadVertex, isTrue);
    plan.moveTo(const Offset(360, 240));
    plan.moveTo(const Offset(360, 360));
    plan.endMove();
    expect(plan.save.city.roads.single.points[1], const Offset(360, 360));
    plan.undo();
    expect(plan.save.city.roads.single.points[1], const Offset(360, 120));
    plan.redo();
    plan.selectAt(const Offset(120, 120));
    plan.renameSelection('Oak Avenue');
    plan.changeSelectedRoadKind(CityRoadKind.avenue);
    plan.changeSelectedRoadCurve(true);
    expect(plan.save.city.roads.single.name, 'Oak Avenue');
    expect(plan.save.city.roads.single.kind, CityRoadKind.avenue);
    expect(plan.save.city.roads.single.curved, isTrue);
    plan.undo();
    expect(plan.save.city.roads.single.curved, isFalse);
  });

  test('hidden layers do not intercept selection or vertex dragging', () {
    plan.chooseRoad(CityRoadKind.street);
    plan.tap(const Offset(120, 120));
    plan.tap(const Offset(480, 120));
    plan.finishRoad();
    plan.roadsVisible = false;
    plan.setTool(CityPlanTool.select);
    plan.selectAt(const Offset(120, 120));
    expect(plan.selectedId, isNull);
    plan.beginMove(const Offset(120, 120));
    plan.moveTo(const Offset(240, 240));
    plan.endMove();
    expect(plan.save.city.roads.single.points.first, const Offset(120, 120));
    plan.setConnectHousing(false);
    plan.chooseBuilding(CityBuildingKind.house);
    plan.tap(const Offset(240, 400));
    plan.buildingsVisible = false;
    plan.setTool(CityPlanTool.select);
    plan.selectAt(const Offset(240, 400));
    expect(plan.selectedId, isNull);
  });

  test(
    'dragging a T junction moves its shared straight segment and access',
    () {
      plan.chooseRoad(CityRoadKind.street);
      plan.tap(const Offset(96, 240));
      plan.tap(const Offset(960, 240));
      plan.finishRoad();
      final streetId = plan.map.roads.single.id;
      plan.chooseRoad(CityRoadKind.avenue);
      plan.tap(const Offset(480, 240));
      plan.tap(const Offset(480, 720));
      plan.finishRoad();
      final avenueId = plan.map.roads.last.id;
      plan.chooseBuilding(CityBuildingKind.house);
      plan.tap(const Offset(240, 150));
      final houseId = plan.map.buildings.single.id;
      plan.setTool(CityPlanTool.select);
      plan.beginMove(const Offset(480, 240));
      plan.moveTo(const Offset(480, 360));
      plan.endMove();
      final street = plan.save.city.roads.first;
      final avenue = plan.save.city.roads.last;
      expect(street.points, contains(const Offset(480, 360)));
      expect(avenue.points.first, const Offset(480, 360));
      expect(
        CityGeometry(plan.map).connectedRoadIds(streetId),
        contains(avenueId),
      );
      expect(plan.save.city.buildings.single.id, houseId);
      expect(plan.save.city.buildings.single.roadId, streetId);
      expect(plan.save.city.buildings.single.roadAnchor, isNotNull);
      plan.undo();
      expect(plan.save.city.roads.first.points, [
        const Offset(96, 240),
        const Offset(960, 240),
      ]);
      expect(plan.save.city.roads.last.points.first, const Offset(480, 240));
      expect(plan.save.city.buildings.single.roadId, streetId);
    },
  );

  test('clicking an unmoved T junction does not insert a hidden edit', () {
    plan.map.roads.addAll([
      CityRoad(
        id: 'a',
        points: [const Offset(96, 240), const Offset(960, 240)],
      ),
      CityRoad(
        id: 'b',
        points: [const Offset(480, 240), const Offset(480, 720)],
      ),
    ]);
    CityGeometry(plan.map).rebuildTopology();
    plan.setTool(CityPlanTool.select);
    plan.beginMove(const Offset(480, 240));
    plan.endMove();
    expect(plan.map.roads.first.points, hasLength(2));
    expect(plan.canUndo, isFalse);
  });

  test(
    'feature name commit keeps its captured identity after selection changes',
    () {
      plan.setConnectHousing(false);
      plan.chooseBuilding(CityBuildingKind.house);
      plan.tap(const Offset(120, 120));
      final firstId = plan.map.buildings.single.id;
      plan.tap(const Offset(360, 360));
      final secondId = plan.map.buildings.last.id;
      plan.setTool(CityPlanTool.select);
      plan.selectAt(const Offset(360, 360));
      expect(plan.selectedId, secondId);
      plan.renameFeature(firstId, '  Oak House  ');
      plan.renameFeature(firstId, 'Oak House');
      expect(plan.save.city.buildings.first.name, 'Oak House');
      expect(plan.save.city.buildings.last.name, isEmpty);
      plan.undo();
      expect(plan.save.city.buildings.first.name, isEmpty);
      plan.renameFeature('deleted-feature', 'Ignored');
      expect(plan.canRedo, isTrue);
      plan.redo();
      expect(plan.save.city.buildings.first.name, 'Oak House');
    },
  );

  test(
    'staged feature names commit together without notifying while typing',
    () {
      plan.setConnectHousing(false);
      plan.chooseBuilding(CityBuildingKind.house);
      plan.tap(const Offset(120, 120));
      plan.tap(const Offset(360, 360));
      final firstId = plan.map.buildings.first.id;
      final secondId = plan.map.buildings.last.id;
      var notifications = 0;
      plan.addListener(() => notifications++);
      plan.stageFeatureName(firstId, '  Oak House  ');
      plan.stageFeatureName(secondId, 'Birch House');
      plan.stageFeatureName('deleted-feature', 'Ignored');
      expect(notifications, 0);
      expect(plan.stagedFeatureName(firstId), '  Oak House  ');
      expect(
        plan.save.city.buildings.every((building) => building.name.isEmpty),
        isTrue,
      );
      plan.commitFeatureNames();
      expect(notifications, 1);
      expect(plan.save.city.buildings.map((building) => building.name), [
        'Oak House',
        'Birch House',
      ]);
      expect(plan.stagedFeatureName(firstId), isNull);
      plan.commitFeatureNames();
      expect(notifications, 1);
      plan.undo();
      expect(
        plan.save.city.buildings.every((building) => building.name.isEmpty),
        isTrue,
      );
      plan.stageFeatureName(firstId, 'Quiet House');
      notifications = 0;
      plan.commitFeatureNames(notify: false);
      expect(notifications, 0);
      expect(plan.save.city.buildings.first.name, 'Quiet House');
      plan.stageFeatureName(secondId, 'Selected House');
      plan.setTool(CityPlanTool.select);
      expect(plan.save.city.buildings.last.name, 'Selected House');
      plan.stageFeatureName(firstId, 'Committed on select');
      plan.selectAt(const Offset(360, 360));
      expect(plan.selectedId, secondId);
      expect(plan.save.city.buildings.first.name, 'Committed on select');
    },
  );

  test(
    'save export reopens curved roads with housing and shared junctions',
    () async {
      plan.chooseRoad(CityRoadKind.street);
      plan.tap(const Offset(96, 240));
      plan.tap(const Offset(960, 240));
      plan.finishRoad();
      final streetId = plan.map.roads.single.id;
      plan.chooseRoad(CityRoadKind.avenue);
      plan.setCurvedRoad(true);
      plan.tap(const Offset(480, 240));
      plan.tap(const Offset(600, 480));
      plan.tap(const Offset(960, 600));
      plan.finishRoad();
      final avenueId = plan.map.roads.last.id;
      plan.chooseBuilding(CityBuildingKind.house);
      plan.tap(const Offset(240, 320));
      final otherStore = MapMakerStore.memory();
      await otherStore.importData(await store.exportData());
      final other = CityPlanController(
        save: otherStore.saves.single,
        store: otherStore,
      );
      expect(other.map.roads.last.curved, isTrue);
      expect(other.map.buildings.single.roadId, streetId);
      expect(
        CityGeometry(other.map).connectedRoadIds(streetId),
        contains(avenueId),
      );
      await otherStore.flush();
      other.dispose();
      otherStore.dispose();
    },
  );
}

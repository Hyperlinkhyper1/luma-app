import 'package:flutter_test/flutter_test.dart';
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
}

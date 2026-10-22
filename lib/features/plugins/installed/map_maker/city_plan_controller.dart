import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'city_map_models.dart';
import 'map_maker_models.dart';
import 'map_maker_store.dart';

enum CityPlanTool { select, pan, road, building, delete }

class CityPlanController extends ChangeNotifier {
  CityPlanController({required this.save, required this.store})
    : map = save.city.clone();

  final MapMakerSave save;
  final MapMakerStore store;
  CityMap map;
  CityPlanTool tool = CityPlanTool.select;
  CityRoadKind roadKind = CityRoadKind.street;
  CityBuildingKind buildingKind = CityBuildingKind.house;
  int placementRotation = 0;
  String? selectedId;
  final List<Offset> draftRoad = [];
  final List<CityMap> _undo = [];
  final List<CityMap> _redo = [];
  CityMap? _beforeMove;
  Offset? _moveOrigin;
  int _nextId = 0;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  CityBuilding? get selectedBuilding {
    for (final building in map.buildings) {
      if (building.id == selectedId) return building;
    }
    return null;
  }

  CityRoad? get selectedRoad {
    for (final road in map.roads) {
      if (road.id == selectedId) return road;
    }
    return null;
  }

  String _id() => 'city-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  void _remember(CityMap before) {
    _undo.add(before);
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
  }

  void _persist() {
    save.city = map.clone();
    store.put(save);
    notifyListeners();
  }

  void setTool(CityPlanTool value) {
    endMove();
    tool = value;
    draftRoad.clear();
    selectedId = null;
    notifyListeners();
  }

  void chooseRoad(CityRoadKind kind) {
    setTool(CityPlanTool.road);
    roadKind = kind;
    notifyListeners();
  }

  void chooseBuilding(CityBuildingKind kind) {
    setTool(CityPlanTool.building);
    buildingKind = kind;
    notifyListeners();
  }

  CityBuilding previewBuilding(Offset position) => _boundedBuilding(
    CityBuilding(
      id: 'preview',
      kind: buildingKind,
      x: position.dx,
      y: position.dy,
      quarterTurns: placementRotation,
    ),
    position,
  );

  CityBuilding _boundedBuilding(CityBuilding building, Offset position) {
    final snapped = map.snap(position);
    final half = building.bounds.size / 2;
    final minX = (half.width / kCityGrid).ceil() * kCityGrid;
    final minY = (half.height / kCityGrid).ceil() * kCityGrid;
    final maxX =
        ((kCitySheetSize.width - half.width) / kCityGrid).floor() * kCityGrid;
    final maxY =
        ((kCitySheetSize.height - half.height) / kCityGrid).floor() * kCityGrid;
    building.position = Offset(
      snapped.dx.clamp(minX, maxX).toDouble(),
      snapped.dy.clamp(minY, maxY).toDouble(),
    );
    return building;
  }

  void tap(Offset position) {
    switch (tool) {
      case CityPlanTool.select:
        selectAt(position);
      case CityPlanTool.pan:
        return;
      case CityPlanTool.road:
        final point = map.snap(position);
        if (draftRoad.isEmpty || draftRoad.last != point) {
          draftRoad.add(point);
          notifyListeners();
        }
      case CityPlanTool.building:
        _remember(map.clone());
        final building = previewBuilding(position);
        final placed = CityBuilding(
          id: _id(),
          kind: building.kind,
          x: building.x,
          y: building.y,
          quarterTurns: building.quarterTurns,
        );
        map.buildings.add(placed);
        selectedId = placed.id;
        _persist();
      case CityPlanTool.delete:
        selectAt(position);
        deleteSelection();
    }
  }

  void selectAt(Offset position) {
    final building = map.hitBuilding(position);
    final road = map.hitRoad(position);
    selectedId = building != null && building.kind != CityBuildingKind.park
        ? building.id
        : road?.id ?? building?.id;
    notifyListeners();
  }

  bool finishRoad() {
    if (draftRoad.toSet().length < 2) return false;
    _remember(map.clone());
    final road = CityRoad(
      id: _id(),
      kind: roadKind,
      points: List.of(draftRoad),
    );
    map.roads.add(road);
    selectedId = road.id;
    draftRoad.clear();
    _persist();
    return true;
  }

  void cancelRoad() {
    draftRoad.clear();
    notifyListeners();
  }

  void rotate() {
    if (tool == CityPlanTool.building) {
      placementRotation = (placementRotation + 1) % 4;
      notifyListeners();
      return;
    }
    final building = selectedBuilding;
    if (building == null) return;
    _remember(map.clone());
    building.quarterTurns = (building.quarterTurns + 1) % 4;
    _boundedBuilding(building, building.position);
    _persist();
  }

  void deleteSelection() {
    if (selectedBuilding == null && selectedRoad == null) return;
    _remember(map.clone());
    map.buildings.removeWhere((building) => building.id == selectedId);
    map.roads.removeWhere((road) => road.id == selectedId);
    selectedId = null;
    _persist();
  }

  void beginMove(Offset position) {
    if (tool != CityPlanTool.select) return;
    selectAt(position);
    if (selectedBuilding == null) return;
    _beforeMove = map.clone();
    _moveOrigin = selectedBuilding!.position;
  }

  void moveTo(Offset position) {
    final building = selectedBuilding;
    if (_beforeMove == null || building == null) return;
    _boundedBuilding(building, position);
    notifyListeners();
  }

  void endMove() {
    final before = _beforeMove;
    _beforeMove = null;
    if (before == null || selectedBuilding?.position == _moveOrigin) return;
    _remember(before);
    _persist();
  }

  void rename(String title) {
    final next = title.trim();
    if (next.isEmpty || next == save.title) return;
    save.title = next;
    _persist();
  }

  void undo() {
    endMove();
    if (!canUndo) return;
    _redo.add(map.clone());
    map = _undo.removeLast();
    selectedId = null;
    draftRoad.clear();
    _persist();
  }

  void redo() {
    endMove();
    if (!canRedo) return;
    _undo.add(map.clone());
    map = _redo.removeLast();
    selectedId = null;
    draftRoad.clear();
    _persist();
  }
}

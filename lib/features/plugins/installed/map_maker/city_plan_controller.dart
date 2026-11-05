import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'city_map_geometry.dart';
import 'city_map_models.dart';
import 'map_maker_geometry.dart';
import 'map_maker_models.dart';
import 'map_maker_store.dart';

enum CityPlanTool { select, pan, road, building, delete }

class CityPlanController extends ChangeNotifier {
  CityPlanController({required this.save, required this.store})
    : map = save.city.clone() {
    _geometry.rebuildTopology();
  }

  final MapMakerSave save;
  final MapMakerStore store;
  CityMap map;
  CityPlanTool tool = CityPlanTool.select;
  CityRoadKind roadKind = CityRoadKind.street;
  CityBuildingKind buildingKind = CityBuildingKind.house;
  bool curvedRoad = false;
  bool snapEnabled = true;
  bool snapGrid = true;
  bool snapVertices = true;
  bool snapSegments = true;
  bool snapIntersections = true;
  bool connectHousing = true;
  bool roadsVisible = true;
  bool buildingsVisible = true;
  double viewScale = 1;
  double snapTolerancePixels = 12;
  int placementRotation = 0;
  String? selectedId;
  CitySnapResult? hoverSnap;
  final List<Offset> draftRoad = [];
  final List<CityMap> _undo = [];
  final List<CityMap> _redo = [];
  final Map<String, String> _pendingFeatureNames = {};
  CityMap? _beforeMove;
  Offset? _lastHover;
  String? _movingRoadId;
  final List<({String roadId, int index})> _movingVertices = [];
  bool _moveChanged = false;
  int _nextId = 0;

  CityGeometry get _geometry => CityGeometry(map);
  double get _tolerance =>
      snapTolerancePixels / (viewScale > 0 ? viewScale : 1);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get canDuplicateSelection =>
      selectedBuilding != null || selectedRoad != null;
  Rect? get selectionBounds =>
      selectedBuilding?.parcelBounds ?? selectedRoad?.bounds;
  bool get canFinishRoad => draftRoad.toSet().length >= (curvedRoad ? 3 : 2);
  bool get movingRoadVertex => _movingRoadId != null;
  CityPlacement? get placementPreview =>
      _lastHover == null ? null : previewPlacement(_lastHover!);

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

  void _persist({bool notify = true}) {
    _geometry.rebuildTopology();
    save.city = map.clone();
    store.put(save);
    if (notify) notifyListeners();
  }

  void setTool(CityPlanTool value) {
    endMove();
    commitFeatureNames();
    tool = value;
    draftRoad.clear();
    selectedId = null;
    _refreshHover();
    notifyListeners();
  }

  void chooseRoad(CityRoadKind kind) {
    setTool(CityPlanTool.road);
    roadKind = kind;
    notifyListeners();
  }

  void setCurvedRoad(bool value) {
    if (curvedRoad == value) return;
    curvedRoad = value;
    notifyListeners();
  }

  void chooseBuilding(CityBuildingKind kind) {
    setTool(CityPlanTool.building);
    buildingKind = kind;
    notifyListeners();
  }

  void setSnapping({
    bool? enabled,
    bool? grid,
    bool? vertices,
    bool? segments,
    bool? intersections,
  }) {
    snapEnabled = enabled ?? snapEnabled;
    snapGrid = grid ?? snapGrid;
    snapVertices = vertices ?? snapVertices;
    snapSegments = segments ?? snapSegments;
    snapIntersections = intersections ?? snapIntersections;
    _refreshHover();
    notifyListeners();
  }

  void setConnectHousing(bool value) {
    if (connectHousing == value) return;
    connectHousing = value;
    notifyListeners();
  }

  CitySnapResult _snap(
    Offset point, {
    String? excludeRoadId,
    Set<String> excludeRoadIds = const {},
  }) => _geometry.snap(
    point,
    tolerance: _tolerance,
    grid: snapEnabled && snapGrid,
    vertices: snapEnabled && roadsVisible && snapVertices,
    segments: snapEnabled && roadsVisible && snapSegments,
    intersections: snapEnabled && roadsVisible && snapIntersections,
    excludeRoadId: excludeRoadId,
    excludeRoadIds: excludeRoadIds,
  );

  Offset snappedPoint(Offset point) => _snap(point).position;

  void updateHover(Offset? point) {
    _lastHover = point;
    _refreshHover();
    notifyListeners();
  }

  void _refreshHover() {
    hoverSnap = _lastHover == null ? null : _snap(_lastHover!);
  }

  CityPlacement previewPlacement(Offset position) => _geometry.placeBuilding(
    CityBuilding(
      id: 'preview',
      kind: buildingKind,
      x: position.dx,
      y: position.dy,
      quarterTurns: placementRotation,
    ),
    position,
    connect: connectHousing,
    grid: snapEnabled && snapGrid,
  );

  CityBuilding previewBuilding(Offset position) =>
      previewPlacement(position).building;
  bool placementValid(Offset position) => previewPlacement(position).valid;

  void tap(Offset position) {
    switch (tool) {
      case CityPlanTool.select:
        selectAt(position);
      case CityPlanTool.pan:
        return;
      case CityPlanTool.road:
        final point = snappedPoint(position);
        if (draftRoad.isEmpty || draftRoad.last != point) {
          draftRoad.add(point);
          notifyListeners();
        }
      case CityPlanTool.building:
        final placement = previewPlacement(position);
        if (!placement.valid) return;
        _remember(map.clone());
        final preview = placement.building;
        final building = CityBuilding(
          id: _id(),
          kind: preview.kind,
          x: preview.x,
          y: preview.y,
          quarterTurns: preview.quarterTurns,
          angle: preview.angle,
          name: preview.name,
          roadId: preview.roadId,
          roadAnchor: preview.roadAnchor,
        );
        map.buildings.add(building);
        selectedId = building.id;
        _persist();
      case CityPlanTool.delete:
        selectAt(position);
        deleteSelection();
    }
  }

  void selectAt(Offset position) {
    commitFeatureNames();
    final building = buildingsVisible ? map.hitBuilding(position) : null;
    final road = roadsVisible
        ? map.hitRoad(position, tolerance: 8 / (viewScale > 0 ? viewScale : 1))
        : null;
    selectedId = building != null && building.kind != CityBuildingKind.park
        ? building.id
        : road?.id ?? building?.id;
    notifyListeners();
  }

  bool finishRoad() {
    if (!canFinishRoad) return false;
    _remember(map.clone());
    final road = CityRoad(
      id: _id(),
      kind: roadKind,
      points: List.of(draftRoad),
      curved: curvedRoad,
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
    final candidate = building.clone()
      ..quarterTurns = (building.quarterTurns + 1) % 4;
    final placement = _geometry.placeBuilding(
      candidate,
      candidate.position,
      connect: false,
      grid: false,
    );
    if (!placement.valid) return;
    final next = placement.building
      ..roadId = building.roadId
      ..roadAnchor = building.roadAnchor;
    _remember(map.clone());
    map.buildings[map.buildings.indexOf(building)] = next;
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

  bool duplicateSelection() {
    endMove();
    commitFeatureNames();
    final building = selectedBuilding;
    final road = selectedRoad;
    if (building != null) {
      final prototype = building.clone(id: _id());
      final bounds = building.parcelBounds;
      for (var ring = 1; ring <= 12; ring++) {
        final dx = (bounds.width / kCityGrid).ceil() * kCityGrid * ring;
        final dy = (bounds.height / kCityGrid).ceil() * kCityGrid * ring;
        for (final delta in [
          Offset(dx, 0),
          Offset(0, dy),
          Offset(-dx, 0),
          Offset(0, -dy),
          Offset(dx, dy),
          Offset(-dx, dy),
          Offset(-dx, -dy),
          Offset(dx, -dy),
        ]) {
          final placement = _geometry.placeBuilding(
            prototype,
            building.position + delta,
            connect: building.connected && connectHousing,
            grid: snapEnabled && snapGrid,
          );
          if (!placement.valid) continue;
          _remember(map.clone());
          map.buildings.add(placement.building);
          selectedId = placement.building.id;
          tool = CityPlanTool.select;
          draftRoad.clear();
          _persist();
          return true;
        }
      }
      return false;
    }
    if (road != null) {
      final duplicate = road.clone(id: _id());
      var direction = road.points.isEmpty
          ? const Offset(1, 0)
          : road.points.last - road.points.first;
      if (direction.distance < .001) {
        for (var index = 1; index < road.points.length; index++) {
          final segment = road.points[index] - road.points[index - 1];
          if (segment.distance < .001) continue;
          direction = segment;
          break;
        }
      }
      if (direction.distance < .001) direction = const Offset(1, 0);
      final normal = Offset(-direction.dy, direction.dx) / direction.distance;
      final delta = map.snap(normal * (road.kind.width + kCityGrid * 2));
      var translation = delta;
      bool occupied(Offset offset) {
        for (final other in map.roads) {
          if (other.points.length != road.points.length) continue;
          var forward = true;
          var reverse = true;
          for (var index = 0; index < road.points.length; index++) {
            final point = road.points[index] + offset;
            forward = forward && (point - other.points[index]).distance < .001;
            reverse =
                reverse &&
                (point - other.points[other.points.length - index - 1])
                        .distance <
                    .001;
          }
          if (forward || reverse) return true;
        }
        return false;
      }

      for (
        var attempt = 1;
        attempt <= map.roads.length && occupied(translation);
        attempt++
      ) {
        translation = delta * (attempt + 1).toDouble();
      }
      for (var index = 0; index < duplicate.points.length; index++) {
        duplicate.points[index] += translation;
      }
      _remember(map.clone());
      map.roads.add(duplicate);
      selectedId = duplicate.id;
      tool = CityPlanTool.select;
      draftRoad.clear();
      _persist();
      return true;
    }
    return false;
  }

  void beginMove(Offset position) {
    if (tool != CityPlanTool.select) return;
    endMove();
    commitFeatureNames();
    final building = buildingsVisible ? map.hitBuilding(position) : null;
    if (roadsVisible &&
        (building == null || building.kind == CityBuildingKind.park)) {
      final selected = selectedRoad;
      final candidates = [
        ?selected,
        ...map.roads.reversed.where((road) => road != selected),
      ];
      for (final road in candidates) {
        for (var index = 0; index < road.points.length; index++) {
          if ((road.points[index] - position).distance <= _tolerance) {
            selectedId = road.id;
            _beforeMove = map.clone();
            _movingRoadId = road.id;
            _prepareSharedVertex(road.points[index]);
            notifyListeners();
            return;
          }
        }
      }
    }
    selectAt(position);
    if (selectedBuilding != null) _beforeMove = map.clone();
  }

  void _prepareSharedVertex(Offset point) {
    _movingVertices.clear();
    for (final road in map.roads) {
      final indexes = <int>[];
      for (var index = 0; index < road.points.length; index++) {
        if ((road.points[index] - point).distance <= .05) indexes.add(index);
      }
      if (indexes.isEmpty && !road.curved) {
        for (var index = 1; index < road.points.length; index++) {
          if (distanceToSegment(
                point,
                road.points[index - 1],
                road.points[index],
              ) <=
              .05) {
            road.points.insert(index, point);
            indexes.add(index);
            break;
          }
        }
      }
      for (final index in indexes) {
        _movingVertices.add((roadId: road.id, index: index));
      }
    }
  }

  void moveTo(Offset position) {
    if (_beforeMove == null) return;
    if (_movingRoadId != null) {
      final point = _snap(
        position,
        excludeRoadIds: _movingVertices.map((vertex) => vertex.roadId).toSet(),
      ).position;
      var changed = false;
      for (final vertex in _movingVertices) {
        final road = map.roads.firstWhere((road) => road.id == vertex.roadId);
        final index = vertex.index;
        if ((index > 0 && road.points[index - 1] == point) ||
            (index + 1 < road.points.length &&
                road.points[index + 1] == point)) {
          return;
        }
        changed = changed || road.points[index] != point;
      }
      if (!changed) return;
      for (final vertex in _movingVertices) {
        map.roads
                .firstWhere((road) => road.id == vertex.roadId)
                .points[vertex.index] =
            point;
      }
      _moveChanged = true;
      _geometry.rebuildTopology();
      notifyListeners();
      return;
    }
    final building = selectedBuilding;
    if (building == null) return;
    final placement = _geometry.placeBuilding(
      building,
      position,
      connect: connectHousing,
      grid: snapEnabled && snapGrid,
    );
    if (!placement.valid) return;
    map.buildings[map.buildings.indexOf(building)] = placement.building;
    _moveChanged = true;
    notifyListeners();
  }

  void endMove() {
    final before = _beforeMove;
    _beforeMove = null;
    _movingRoadId = null;
    _movingVertices.clear();
    final changed = _moveChanged;
    _moveChanged = false;
    if (before != null && !changed) {
      map = before;
      notifyListeners();
      return;
    }
    if (before == null ||
        jsonEncode(before.toJson()) == jsonEncode(map.toJson())) {
      return;
    }
    _remember(before);
    _persist();
  }

  void renameSelection(String name) {
    final id = selectedId;
    if (id != null) renameFeature(id, name);
  }

  String? stagedFeatureName(String id) => _pendingFeatureNames[id];

  void stageFeatureName(String id, String name) {
    _pendingFeatureNames[id] = name;
  }

  void commitFeatureNames({bool notify = true}) {
    if (_pendingFeatureNames.isEmpty) return;
    final pending = Map<String, String>.of(_pendingFeatureNames);
    _pendingFeatureNames.clear();
    CityMap? before;
    for (final entry in pending.entries) {
      final next = entry.value.trim();
      for (final building in map.buildings) {
        if (building.id != entry.key || building.name == next) continue;
        before ??= map.clone();
        building.name = next;
        break;
      }
      for (final road in map.roads) {
        if (road.id != entry.key || road.name == next) continue;
        before ??= map.clone();
        road.name = next;
        break;
      }
    }
    if (before == null) return;
    _remember(before);
    _persist(notify: notify);
  }

  void renameFeature(String id, String name) {
    _pendingFeatureNames.remove(id);
    final next = name.trim();
    for (final building in map.buildings) {
      if (building.id != id) continue;
      if (building.name == next) return;
      _remember(map.clone());
      building.name = next;
      _persist();
      return;
    }
    for (final road in map.roads) {
      if (road.id != id) continue;
      if (road.name == next) return;
      _remember(map.clone());
      road.name = next;
      _persist();
      return;
    }
  }

  void changeSelectedRoadKind(CityRoadKind kind) {
    final road = selectedRoad;
    if (road == null || road.kind == kind) return;
    _remember(map.clone());
    road.kind = kind;
    _persist();
  }

  void changeSelectedRoadCurve(bool curved) {
    final road = selectedRoad;
    if (road == null ||
        road.curved == curved ||
        (curved && road.points.length < 3)) {
      return;
    }
    _remember(map.clone());
    road.curved = curved;
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

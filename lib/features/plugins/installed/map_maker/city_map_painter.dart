import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'city_map_geometry.dart';
import 'city_map_models.dart';
import 'map_maker_geometry.dart';

const kCityPaper = Color(0xFFF5F5F0);
const _selectionColor = Color(0xFF07839B);
const _snapColor = Color(0xFFBC4088);
const _invalidColor = Color(0xFFBA5148);

class CityMapPainter extends CustomPainter {
  CityMapPainter({
    required this.map,
    this.selectedId,
    this.draftRoad = const [],
    this.roadKind = CityRoadKind.street,
    this.previewBuilding,
    this.showGrid = true,
    this.textDirection = TextDirection.ltr,
    this.showRoads = true,
    this.showBuildings = true,
    this.showParcels = true,
    this.showConnections = true,
    this.showJunctions = false,
    this.draftCurved = false,
    this.snapResult,
    this.validPlacement = true,
    this.viewScale = 1,
    this.fontFamily,
    this.visibleWorldBounds,
    this.showLabels = true,
    this.worldTransform,
  });

  final CityMap map;
  final String? selectedId;
  final List<Offset> draftRoad;
  final CityRoadKind roadKind;
  final CityBuilding? previewBuilding;
  final bool showGrid;
  final TextDirection textDirection;
  final bool showRoads;
  final bool showBuildings;
  final bool showParcels;
  final bool showConnections;
  final bool showJunctions;
  final bool draftCurved;
  final CitySnapResult? snapResult;
  final bool validPlacement;
  final double viewScale;
  final String? fontFamily;
  final Rect? visibleWorldBounds;
  final bool showLabels;
  final Matrix4? worldTransform;

  late Rect _paintBounds;
  final _dashPhases = <List<Offset>, double>{};
  late _LabelSpace _labels;
  late _LabelSpace _roadSurfaces;

  double get _scale => viewScale.clamp(.000001, 20);
  double get _fine => .75 / _scale;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = worldTransform;
    if (transform == null) {
      _paint(canvas, size);
      return;
    }
    final inverse = Matrix4.inverted(transform);
    final bounds =
        visibleWorldBounds ??
        Rect.fromPoints(
          MatrixUtils.transformPoint(inverse, Offset.zero),
          MatrixUtils.transformPoint(inverse, Offset(size.width, size.height)),
        );
    if (bounds.isEmpty || !bounds.isFinite) return;
    // Keep GPU coordinates near the camera while retaining world coordinates.
    final origin = bounds.center;
    final localTransform = transform.clone();
    final screenOrigin = MatrixUtils.transformPoint(transform, origin);
    localTransform.storage[12] = screenOrigin.dx;
    localTransform.storage[13] = screenOrigin.dy;
    final margin = showLabels && _scale >= .5 ? 120 / _scale : 16 / _scale;
    CityBuilding rebaseBuilding(CityBuilding building) {
      final local = building.clone()..position = building.position - origin;
      if (building.roadAnchor != null) {
        local.roadAnchor = building.roadAnchor! - origin;
      }
      return local;
    }

    final localMap = CityMap(
      roads: [
        for (final road in map.roads)
          if (road.points.isNotEmpty &&
              road.bounds.inflate(16 / _scale).overlaps(bounds))
            CityRoad(
              id: road.id,
              kind: road.kind,
              points: [for (final point in road.points) point - origin],
              curved: road.curved,
              name: road.name,
            ),
      ],
      buildings: [
        for (final building in map.buildings)
          if (building.bounds.inflate(16 + margin).overlaps(bounds) ||
              showConnections &&
                  building.roadAnchor != null &&
                  Rect.fromPoints(
                    building.entrance,
                    building.roadAnchor!,
                  ).inflate(8).overlaps(bounds))
            rebaseBuilding(building),
      ],
      junctions: [
        for (final junction in map.junctions)
          if (bounds.inflate(64).contains(junction.position))
            CityJunction(
              id: junction.id,
              position: junction.position - origin,
              roadIds: junction.roadIds,
            ),
      ],
    );
    CityMapPainter(
      map: localMap,
      selectedId: selectedId,
      draftRoad: [for (final point in draftRoad) point - origin],
      roadKind: roadKind,
      previewBuilding: previewBuilding == null
          ? null
          : rebaseBuilding(previewBuilding!),
      showGrid: showGrid,
      textDirection: textDirection,
      showRoads: showRoads,
      showBuildings: showBuildings,
      showParcels: showParcels,
      showConnections: showConnections,
      showJunctions: showJunctions,
      draftCurved: draftCurved,
      snapResult: snapResult == null
          ? null
          : CitySnapResult(
              position: snapResult!.position - origin,
              kind: snapResult!.kind,
              roadId: snapResult!.roadId,
            ),
      validPlacement: validPlacement,
      viewScale: viewScale,
      fontFamily: fontFamily,
      visibleWorldBounds: bounds.shift(-origin),
      showLabels: showLabels,
      worldTransform: localTransform,
    )._paint(canvas, size, worldOrigin: origin);
  }

  void _paint(Canvas canvas, Size size, {Offset worldOrigin = Offset.zero}) {
    _paintBounds = visibleWorldBounds ?? Offset.zero & size;
    if (_paintBounds.isEmpty || !_paintBounds.isFinite) return;
    _dashPhases.clear();
    final buildings = map.buildings.where((building) {
      final margin = showLabels && _scale >= .5 ? 120 / _scale : 16 / _scale;
      return building.bounds.inflate(16 + margin).overlaps(_paintBounds);
    }).toList();
    final roads = map.roads.where((road) {
      if (road.points.isEmpty) return false;
      return road.bounds.inflate(16 / _scale).overlaps(_paintBounds);
    }).toList();
    final junctions = map.junctions
        .where(
          (junction) => _paintBounds.inflate(64).contains(junction.position),
        )
        .toList();
    _labels = _LabelSpace(192 / _scale);
    _roadSurfaces = _LabelSpace(192 / _scale);
    final roadWidths = {for (final road in roads) road.id: road.kind.width};
    if (showLabels && showBuildings) {
      for (final building in buildings) {
        _labels.add(building.bounds.inflate(3 / _scale));
      }
    }
    if (showLabels && showRoads) {
      for (final junction in junctions) {
        if (junction.roadIds.length < 2) continue;
        var clearance = 0.0;
        for (final id in junction.roadIds) {
          clearance = math.max(clearance, (roadWidths[id] ?? 0) / 2);
        }
        _labels.add(
          Rect.fromCircle(
            center: junction.position,
            radius: clearance + 8 / _scale,
          ),
        );
      }
    }
    final lines = <String, List<List<Offset>>>{};
    canvas.save();
    if (worldTransform != null) {
      canvas.clipRect(Offset.zero & size);
      canvas.transform(worldTransform!.storage);
    }
    canvas.clipRect(_paintBounds);
    canvas.drawRect(_paintBounds, Paint()..color = kCityPaper);
    if (showGrid) _paintGrid(canvas, _paintBounds, worldOrigin);
    if (showBuildings) {
      for (final building in buildings) {
        if (building.kind == CityBuildingKind.park) {
          _paintBuilding(canvas, building);
        }
      }
    }
    if (showParcels) {
      for (final building in buildings) {
        _paintParcel(canvas, building);
      }
    }
    if (showRoads) {
      for (final road in roads) {
        lines[road.id] = _visiblePolylines(
          road.centerline,
          _paintBounds.inflate(road.kind.width + 8 / _scale),
        );
        if (showLabels) {
          for (final points in lines[road.id]!) {
            for (var index = 1; index < points.length; index++) {
              _roadSurfaces.add(
                Rect.fromPoints(
                  points[index - 1],
                  points[index],
                ).inflate(road.kind.width / 2 + 3 / _scale),
              );
            }
          }
        }
      }
      for (var pass = 0; pass < 3; pass++) {
        for (final road in roads) {
          for (final points in lines[road.id]!) {
            _paintRoadBase(canvas, points, road.kind, pass: pass);
          }
        }
      }
      canvas.save();
      var markingArea = Path()..addRect(_paintBounds);
      for (final junction in junctions) {
        if (junction.roadIds.length < 2) continue;
        var width = 0.0;
        for (final id in junction.roadIds) {
          width = math.max(width, roadWidths[id] ?? 0);
        }
        markingArea = Path.combine(
          PathOperation.difference,
          markingArea,
          Path()..addOval(
            Rect.fromCircle(center: junction.position, radius: width / 2 + 4),
          ),
        );
      }
      canvas.clipPath(markingArea);
      for (final road in roads) {
        for (final points in lines[road.id]!) {
          _paintRoadMarkings(canvas, points, road.kind);
        }
      }
      canvas.restore();
    }
    if (showConnections) {
      for (final building in map.buildings) {
        final anchor = building.roadAnchor;
        if (anchor != null &&
            Rect.fromPoints(
              building.entrance,
              anchor,
            ).inflate(8).overlaps(_paintBounds)) {
          _paintConnection(canvas, building);
        }
      }
    }
    if (showBuildings) {
      for (final building in buildings) {
        if (building.kind != CityBuildingKind.park) {
          _paintBuilding(canvas, building);
        }
      }
      for (final building in buildings) {
        if (building.id == selectedId) {
          _paintBuildingSelection(canvas, building);
        }
      }
    }
    if (showLabels) {
      if (showBuildings) {
        for (final building in buildings) {
          if (building.id == selectedId && building.name.trim().isNotEmpty) {
            _paintBuildingName(canvas, building);
          }
        }
      }
      if (showRoads) {
        for (final selected in [true, false]) {
          for (final road in roads) {
            if ((road.id == selectedId) != selected ||
                road.name.trim().isEmpty ||
                lines[road.id]!.isEmpty) {
              continue;
            }
            final visible = lines[road.id]!.reduce(
              (a, b) => _polylineLength(a) >= _polylineLength(b) ? a : b,
            );
            _paintRoadName(canvas, road, visible);
          }
        }
      }
      if (showBuildings) {
        for (final building in buildings) {
          if (building.id != selectedId && building.name.trim().isNotEmpty) {
            _paintBuildingName(canvas, building);
          }
        }
      }
    }
    if (showJunctions && showRoads) {
      for (final junction in junctions) {
        if (junction.roadIds.length >= 2) {
          _paintHandle(
            canvas,
            junction.position,
            color: const Color(0xFF638775),
          );
        }
      }
    }
    if (showRoads) {
      for (final road in roads) {
        if (road.id == selectedId) _paintRoadSelection(canvas, road);
      }
    }
    _paintDraft(canvas);
    final preview = previewBuilding;
    if (preview != null) {
      canvas.saveLayer(null, Paint()..color = const Color(0xBFFFFFFF));
      _paintParcel(canvas, preview, preview: true);
      _paintConnection(canvas, preview);
      _paintBuilding(canvas, preview);
      canvas.restore();
      _paintBuildingSelection(canvas, preview, invalid: !validPlacement);
    }
    final snap = snapResult;
    if (snap != null) _paintSnap(canvas, snap);
    canvas.restore();
  }

  double _polylineLength(List<Offset> points) {
    var length = 0.0;
    for (var index = 1; index < points.length; index++) {
      length += (points[index] - points[index - 1]).distance;
    }
    return length;
  }

  List<List<Offset>> _visiblePolylines(List<Offset> points, Rect bounds) {
    final visible = <List<Offset>>[];
    List<Offset>? run;
    var travelled = 0.0;
    for (var index = 1; index < points.length; index++) {
      final start = points[index - 1];
      final end = points[index];
      final delta = end - start;
      var entry = 0.0;
      var exit = 1.0;
      var rejected = false;
      final directions = [-delta.dx, delta.dx, -delta.dy, delta.dy];
      final distances = [
        start.dx - bounds.left,
        bounds.right - start.dx,
        start.dy - bounds.top,
        bounds.bottom - start.dy,
      ];
      for (var edge = 0; edge < 4; edge++) {
        final direction = directions[edge];
        final distance = distances[edge];
        if (direction.abs() < 1e-12) {
          if (distance < 0) rejected = true;
        } else {
          final ratio = distance / direction;
          if (direction < 0) {
            entry = math.max(entry, ratio);
          } else {
            exit = math.min(exit, ratio);
          }
          if (entry > exit) rejected = true;
        }
        if (rejected) break;
      }
      if (rejected) {
        run = null;
        travelled += delta.distance;
        continue;
      }
      final clippedStart = start + delta * entry;
      final clippedEnd = start + delta * exit;
      if (run != null && (run.last - clippedStart).distanceSquared < .0001) {
        run.add(clippedEnd);
      } else {
        run = [clippedStart, clippedEnd];
        visible.add(run);
        _dashPhases[run] = travelled + delta.distance * entry;
      }
      if (exit < 1) run = null;
      travelled += delta.distance;
    }
    return visible;
  }

  void _paintGrid(Canvas canvas, Rect bounds, Offset worldOrigin) {
    var step = kCityGrid;
    while (step * _scale < 18 ||
        bounds.width / step + bounds.height / step > 1200) {
      step *= 5;
    }
    final minor = Paint()
      ..color = const Color(0x135F6B68)
      ..strokeWidth = .5 / _scale;
    final major = Paint()
      ..color = const Color(0x245F6B68)
      ..strokeWidth = .65 / _scale;
    final firstX = ((bounds.left + worldOrigin.dx) / step).floor();
    final lastX = ((bounds.right + worldOrigin.dx) / step).ceil();
    final firstY = ((bounds.top + worldOrigin.dy) / step).floor();
    final lastY = ((bounds.bottom + worldOrigin.dy) / step).ceil();
    for (var index = firstX; index <= lastX; index++) {
      final x = index * step - worldOrigin.dx;
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.bottom),
        index % 5 == 0 ? major : minor,
      );
    }
    for (var index = firstY; index <= lastY; index++) {
      final y = index * step - worldOrigin.dy;
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        index % 5 == 0 ? major : minor,
      );
    }
    final axis = Paint()
      ..color = const Color(0x496A9290)
      ..strokeWidth = 1 / _scale;
    final axisOrigin = -worldOrigin;
    if (bounds.left <= axisOrigin.dx && bounds.right >= axisOrigin.dx) {
      canvas.drawLine(
        Offset(axisOrigin.dx, bounds.top),
        Offset(axisOrigin.dx, bounds.bottom),
        axis,
      );
    }
    if (bounds.top <= axisOrigin.dy && bounds.bottom >= axisOrigin.dy) {
      canvas.drawLine(
        Offset(bounds.left, axisOrigin.dy),
        Offset(bounds.right, axisOrigin.dy),
        axis,
      );
    }
  }

  void _paintRoadBase(
    Canvas canvas,
    List<Offset> points,
    CityRoadKind kind, {
    required int pass,
  }) {
    if (points.length < 2) return;
    final pedestrian = kind == CityRoadKind.pedestrian;
    final color = switch (pass) {
      0 => pedestrian ? const Color(0xFFB8B5A9) : const Color(0xFFADB3B1),
      1 => pedestrian ? const Color(0xFFE9E5D9) : const Color(0xFFECEDE7),
      _ => switch (kind) {
        CityRoadKind.street => const Color(0xFFD3D8D5),
        CityRoadKind.avenue => const Color(0xFFCAD1CD),
        CityRoadKind.highway => const Color(0xFFB6C0BD),
        CityRoadKind.pedestrian => const Color(0xFFE6E1D3),
      },
    };
    canvas.drawPath(
      polylinePath(points),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            kind.width +
            (pass == 0
                ? 7
                : pass == 1
                ? 5
                : 0)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintRoadMarkings(
    Canvas canvas,
    List<Offset> points,
    CityRoadKind kind,
  ) {
    if (points.length < 2 || kind.width * _scale < 5) return;
    final path = polylinePath(points);
    switch (kind) {
      case CityRoadKind.street:
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = const Color(0xDDF8FAF4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
          dash: 8,
          gap: 9,
          phase: _dashPhases[points] ?? 0,
        );
      case CityRoadKind.avenue:
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFE6E8DB)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeJoin = StrokeJoin.round,
        );
        _paintOffsetLane(canvas, points, 11, dashed: true);
        _paintOffsetLane(canvas, points, -11, dashed: true);
      case CityRoadKind.highway:
        _paintOffsetLane(
          canvas,
          points,
          2,
          dashed: false,
          color: const Color(0xFFE9E2B9),
        );
        _paintOffsetLane(
          canvas,
          points,
          -2,
          dashed: false,
          color: const Color(0xFFE9E2B9),
        );
        _paintOffsetLane(canvas, points, 13, dashed: true);
        _paintOffsetLane(canvas, points, -13, dashed: true);
        _paintOffsetLane(canvas, points, 24, dashed: false);
        _paintOffsetLane(canvas, points, -24, dashed: false);
      case CityRoadKind.pedestrian:
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = const Color(0x88978F7F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .9,
          dash: 1,
          gap: 6,
          phase: _dashPhases[points] ?? 0,
        );
    }
  }

  void _paintOffsetLane(
    Canvas canvas,
    List<Offset> points,
    double offset, {
    required bool dashed,
    Color color = const Color(0xEAF7F9F2),
  }) {
    if (points.length < 2) return;
    final shifted = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final before = points[math.max(0, i - 1)];
      final after = points[math.min(points.length - 1, i + 1)];
      final tangent = after - before;
      final length = tangent.distance;
      shifted.add(
        length < .001
            ? points[i]
            : points[i] + Offset(-tangent.dy, tangent.dx) / length * offset,
      );
    }
    final path = polylinePath(shifted);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.1;
    if (dashed) {
      _drawDashedPath(
        canvas,
        path,
        paint,
        dash: 9,
        gap: 9,
        phase: _dashPhases[points] ?? 0,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }

  bool _hasParcel(CityBuilding building) =>
      building.kind != CityBuildingKind.tree &&
      building.kind != CityBuildingKind.park;

  void _paintParcel(
    Canvas canvas,
    CityBuilding building, {
    bool preview = false,
  }) {
    if (!_hasParcel(building) || building.parcel.length < 3) return;
    if (building.size.shortestSide * _scale < 6 && !preview) return;
    final path = polylinePath(building.parcel, close: true);
    canvas.drawPath(path, Paint()..color = const Color(0x55E5DFCC));
    canvas.drawPath(
      path,
      Paint()
        ..color = preview
            ? _selectionColor.withValues(alpha: .65)
            : const Color(0xFFB4B6A9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _fine,
    );
    if (building.roadId != null && building.roadAnchor != null) {
      final angle = building.rotation;
      final tangent = Offset(math.cos(angle), math.sin(angle));
      final front =
          building.position +
          Offset(-math.sin(angle), math.cos(angle)) *
              (building.size.height / 2 + 12);
      final halfWidth = building.size.width / 2 + 12;
      canvas.drawLine(
        front - tangent * halfWidth,
        front + tangent * halfWidth,
        Paint()
          ..color = const Color(0xFF788F7B)
          ..strokeWidth = 1.4 / _scale,
      );
    }
  }

  void _paintConnection(Canvas canvas, CityBuilding building) {
    final anchor = building.roadAnchor;
    if (building.roadId == null || anchor == null || !_hasParcel(building)) {
      return;
    }
    final entrance = building.entrance;
    if ((anchor - entrance).distance < .01) return;
    canvas.drawLine(
      entrance,
      anchor,
      Paint()
        ..color = const Color(0xFFB5B9AE)
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = 7,
    );
    canvas.drawLine(
      entrance,
      anchor,
      Paint()
        ..color = const Color(0xFFF0EEE4)
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = 5.5,
    );
    canvas.drawCircle(
      anchor,
      1.6 / _scale,
      Paint()..color = const Color(0xFF6E897B),
    );
  }

  void _paintBuilding(Canvas canvas, CityBuilding building) {
    canvas.save();
    canvas.translate(building.x, building.y);
    canvas.rotate(building.rotation);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: building.size.width,
      height: building.size.height,
    );
    if (building.kind == CityBuildingKind.tree) {
      _paintTree(canvas, Offset.zero, 9);
    } else if (building.kind == CityBuildingKind.park) {
      _paintPark(canvas, bounds);
    } else {
      final color = switch (building.kind) {
        CityBuildingKind.house => const Color(0xFFDCD3BF),
        CityBuildingKind.apartment => const Color(0xFFD7CFBD),
        CityBuildingKind.shop => const Color(0xFFDBCEBC),
        CityBuildingKind.office => const Color(0xFFCDD6D8),
        CityBuildingKind.school => const Color(0xFFE0D9C0),
        CityBuildingKind.hospital => const Color(0xFFDFD5D2),
        _ => const Color(0xFFD9D6CB),
      };
      if (_scale >= .3) {
        canvas.drawRect(
          bounds.shift(const Offset(2, 3)),
          Paint()..color = const Color(0x1881837D),
        );
      }
      canvas.drawRect(bounds, Paint()..color = color);
      if (building.size.shortestSide * _scale >= 5) {
        canvas.drawRect(
          bounds,
          Paint()
            ..color = const Color(0xFF81867D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.min(1 / _scale, 2),
        );
      }
      if (building.size.shortestSide * _scale < 16) {
        canvas.restore();
        return;
      }
      if (building.kind == CityBuildingKind.house) {
        final paint = Paint()
          ..color = const Color(0xFFB3AB96)
          ..strokeWidth = _fine;
        canvas.drawLine(
          Offset(0, bounds.top + 3),
          Offset(0, bounds.bottom - 3),
          paint,
        );
        canvas.drawLine(
          Offset(bounds.left + 3, bounds.top + 3),
          Offset(0, bounds.top + 12),
          paint,
        );
        canvas.drawLine(
          Offset(bounds.right - 3, bounds.top + 3),
          Offset(0, bounds.top + 12),
          paint,
        );
      } else {
        canvas.drawRect(
          bounds.deflate(5),
          Paint()
            ..color = const Color(0x70868A80)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _fine,
        );
      }
      final connected = building.roadId != null && building.roadAnchor != null;
      canvas.drawLine(
        Offset(-4, bounds.bottom),
        Offset(4, bounds.bottom),
        Paint()
          ..color = connected
              ? const Color(0xFF607F70)
              : const Color(0xFFBD8752)
          ..strokeWidth = 2 / _scale,
      );
      if (building.kind == CityBuildingKind.hospital) {
        final paint = Paint()
          ..color = const Color(0xFFAB8D87)
          ..strokeWidth = 3;
        canvas.drawLine(const Offset(-7, 0), const Offset(7, 0), paint);
        canvas.drawLine(const Offset(0, -7), const Offset(0, 7), paint);
      }
    }
    canvas.restore();
  }

  void _paintPark(Canvas canvas, Rect bounds) {
    canvas.drawRect(bounds, Paint()..color = const Color(0xFFDDE7D5));
    if (bounds.shortestSide * _scale < 12) return;
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0xFFACBBA1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _fine,
    );
    canvas.drawLine(
      Offset(bounds.left + 10, bounds.bottom - 10),
      Offset(bounds.right - 10, bounds.top + 10),
      Paint()
        ..color = const Color(0xFFEEEBDD)
        ..strokeWidth = 5,
    );
    _paintTree(canvas, Offset(bounds.left + 22, bounds.top + 22), 10);
    _paintTree(canvas, Offset(bounds.left + 23, bounds.bottom - 24), 8);
    _paintTree(canvas, Offset(bounds.right - 24, bounds.top + 25), 9);
  }

  void _paintTree(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0x888DA67D));
    if (radius * _scale < 3) return;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF879B79)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _fine,
    );
    final paint = Paint()
      ..color = const Color(0xFF6D8063)
      ..strokeWidth = _fine;
    canvas.drawLine(
      center - const Offset(2.5, 0),
      center + const Offset(2.5, 0),
      paint,
    );
    canvas.drawLine(
      center - const Offset(0, 2.5),
      center + const Offset(0, 2.5),
      paint,
    );
  }

  void _paintBuildingSelection(
    Canvas canvas,
    CityBuilding building, {
    bool invalid = false,
  }) {
    final color = invalid ? _invalidColor : _selectionColor;
    if (showParcels && _hasParcel(building)) {
      _drawDashedPath(
        canvas,
        polylinePath(building.parcel, close: true),
        Paint()
          ..color = color.withValues(alpha: .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / _scale,
        dash: 5 / _scale,
        gap: 3 / _scale,
      );
    }
    canvas.drawPath(
      polylinePath(building.footprint, close: true),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 / _scale,
    );
    for (final point in building.footprint) {
      _paintHandle(canvas, point, color: color, radius: 3);
    }
    if (invalid) {
      final offset = Offset(6 / _scale, 6 / _scale);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2 / _scale;
      canvas.drawLine(
        building.position - offset,
        building.position + offset,
        paint,
      );
      canvas.drawLine(
        building.position + Offset(-offset.dx, offset.dy),
        building.position + Offset(offset.dx, -offset.dy),
        paint,
      );
    }
  }

  void _paintRoadSelection(Canvas canvas, CityRoad road) {
    if (road.points.length < 2) return;
    for (final points in _visiblePolylines(
      road.centerline,
      _paintBounds.inflate(12 / _scale),
    )) {
      canvas.drawPath(
        polylinePath(points),
        Paint()
          ..color = _selectionColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / _scale,
      );
    }
    for (final point in road.points) {
      _paintHandle(canvas, point);
    }
  }

  void _paintDraft(Canvas canvas) {
    if (draftRoad.isEmpty) return;
    if (draftRoad.length > 1) {
      final centerline = CityRoad(
        id: 'draft',
        points: draftRoad,
        curved: draftCurved,
      ).centerline;
      canvas.saveLayer(null, Paint()..color = const Color(0xBDFFFFFF));
      final lines = _visiblePolylines(
        centerline,
        _paintBounds.inflate(roadKind.width + 8 / _scale),
      );
      for (final points in lines) {
        for (var pass = 0; pass < 3; pass++) {
          _paintRoadBase(canvas, points, roadKind, pass: pass);
        }
        _paintRoadMarkings(canvas, points, roadKind);
      }
      canvas.restore();
      for (final points in lines) {
        _drawDashedPath(
          canvas,
          polylinePath(points),
          Paint()
            ..color = _selectionColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 / _scale,
          dash: 6 / _scale,
          gap: 4 / _scale,
          phase: _dashPhases[points] ?? 0,
        );
      }
    }
    for (final point in draftRoad) {
      _paintHandle(canvas, point);
    }
  }

  void _paintHandle(
    Canvas canvas,
    Offset point, {
    Color color = _selectionColor,
    double radius = 3.5,
  }) {
    final rect = Rect.fromCenter(
      center: point,
      width: radius * 2 / _scale,
      height: radius * 2 / _scale,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0xFFFDFEFA));
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / _scale,
    );
  }

  void _paintSnap(Canvas canvas, CitySnapResult snap) {
    final point = snap.position;
    final radius = 6 / _scale;
    final paint = Paint()
      ..color = snap.kind == CitySnapKind.none
          ? const Color(0xFF7F8D89)
          : _snapColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / _scale;
    final rect = Rect.fromCircle(center: point, radius: radius);
    switch (snap.kind) {
      case CitySnapKind.vertex:
        canvas.drawRect(rect, paint);
      case CitySnapKind.segment:
        canvas.drawCircle(point, radius, paint);
        canvas.drawLine(
          point - Offset(radius * 1.6, 0),
          point + Offset(radius * 1.6, 0),
          paint,
        );
      case CitySnapKind.intersection:
        canvas.drawPath(
          Path()
            ..moveTo(point.dx, point.dy - radius * 1.3)
            ..lineTo(point.dx + radius * 1.3, point.dy)
            ..lineTo(point.dx, point.dy + radius * 1.3)
            ..lineTo(point.dx - radius * 1.3, point.dy)
            ..close(),
          paint,
        );
      case CitySnapKind.grid:
      case CitySnapKind.none:
        canvas.drawLine(
          point - Offset(radius, 0),
          point + Offset(radius, 0),
          paint,
        );
        canvas.drawLine(
          point - Offset(0, radius),
          point + Offset(0, radius),
          paint,
        );
    }
  }

  void _paintRoadName(Canvas canvas, CityRoad road, List<Offset> points) {
    if (_scale < .45 || points.length < 2) return;
    final metrics = polylinePath(points).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final maxWidth = math.min(160 / _scale, metric.length - 24 / _scale);
    if (maxWidth < 32 / _scale) return;
    final painter = TextPainter(
      text: TextSpan(
        text: road.name,
        style: TextStyle(
          fontFamily: fontFamily,
          color: const Color(0xFF5E6A64),
          fontSize: 10 / _scale,
          fontWeight: FontWeight.w500,
          backgroundColor: const Color(0xCFEEF0E9),
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final endMargin = painter.width / 2 + 4 / _scale;
    for (final fraction in const [.5, .3, .7, .15, .85, .4, .6]) {
      final distance = (metric.length * fraction).clamp(
        endMargin,
        metric.length - endMargin,
      );
      final tangent = metric.getTangentForOffset(distance);
      if (tangent == null) continue;
      var angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
      if (angle > math.pi / 2) angle -= math.pi;
      if (angle < -math.pi / 2) angle += math.pi;
      final cosine = math.cos(angle).abs();
      final sine = math.sin(angle).abs();
      final bounds = Rect.fromCenter(
        center: tangent.position,
        width: painter.width * cosine + painter.height * sine,
        height: painter.width * sine + painter.height * cosine,
      ).inflate(4 / _scale);
      if (!_labelInViewport(bounds) || _labels.overlaps(bounds)) continue;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(angle);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
      _labels.add(bounds);
      break;
    }
    painter.dispose();
  }

  void _paintBuildingName(Canvas canvas, CityBuilding building) {
    if (_scale < .5 && building.id != selectedId) return;
    final painter =
        TextPainter(
          text: TextSpan(
            text: building.name,
            style: TextStyle(
              fontFamily: fontFamily,
              color: const Color(0xFF59615A),
              fontSize: 10 / _scale,
              backgroundColor: const Color(0xDDF5F5F0),
            ),
          ),
          textDirection: textDirection,
          maxLines: 1,
          ellipsis: '…',
        )..layout(
          maxWidth: math.min(
            160 / _scale,
            math.max(96 / _scale, building.bounds.width + 24),
          ),
        );
    final footprint = building.bounds;
    final left = building.x - painter.width / 2;
    Offset? position;
    for (final candidate in [
      Offset(left, footprint.bottom + 6 / _scale),
      Offset(left, footprint.top - painter.height - 6 / _scale),
    ]) {
      final bounds = (candidate & painter.size).inflate(3 / _scale);
      if (!_labelInViewport(bounds) ||
          _labels.overlaps(bounds) ||
          _roadSurfaces.overlaps(bounds)) {
        continue;
      }
      position = candidate;
      break;
    }
    if (position == null && building.id == selectedId) {
      final margin = 6 / _scale;
      position = Offset(
        left.clamp(
          _paintBounds.left + margin,
          math.max(
            _paintBounds.left + margin,
            _paintBounds.right - painter.width - margin,
          ),
        ),
        (building.y - painter.height / 2).clamp(
          _paintBounds.top + margin,
          math.max(
            _paintBounds.top + margin,
            _paintBounds.bottom - painter.height - margin,
          ),
        ),
      );
    }
    if (position != null) {
      painter.paint(canvas, position);
      _labels.add((position & painter.size).inflate(3 / _scale));
    }
    painter.dispose();
  }

  bool _labelInViewport(Rect bounds) =>
      bounds.left >= _paintBounds.left &&
      bounds.right <= _paintBounds.right &&
      bounds.top >= _paintBounds.top &&
      bounds.bottom <= _paintBounds.bottom;

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dash = 8,
    double gap = 5,
    double phase = 0,
  }) {
    if ((dash + gap) * _scale < 3) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      final step = math.max(dash + gap, metric.length / 4096);
      final visibleDash = step * dash / (dash + gap);
      for (
        var distance = -(phase % step);
        distance < metric.length;
        distance += step
      ) {
        if (distance + visibleDash <= 0) continue;
        canvas.drawPath(
          metric.extractPath(
            math.max(0.0, distance),
            math.min(distance + visibleDash, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CityMapPainter oldDelegate) => true;
}

class _LabelSpace {
  _LabelSpace(this.cellSize);

  final double cellSize;
  final _cells = <(int, int), List<Rect>>{};

  void add(Rect bounds) {
    for (
      var x = (bounds.left / cellSize).floor();
      x <= (bounds.right / cellSize).floor();
      x++
    ) {
      for (
        var y = (bounds.top / cellSize).floor();
        y <= (bounds.bottom / cellSize).floor();
        y++
      ) {
        (_cells[(x, y)] ??= []).add(bounds);
      }
    }
  }

  bool overlaps(Rect bounds) {
    for (
      var x = (bounds.left / cellSize).floor();
      x <= (bounds.right / cellSize).floor();
      x++
    ) {
      for (
        var y = (bounds.top / cellSize).floor();
        y <= (bounds.bottom / cellSize).floor();
        y++
      ) {
        for (final occupied in _cells[(x, y)] ?? const <Rect>[]) {
          if (bounds.overlaps(occupied)) return true;
        }
      }
    }
    return false;
  }
}

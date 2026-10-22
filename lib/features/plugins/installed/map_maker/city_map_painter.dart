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

  double get _scale => viewScale.clamp(.1, 5);
  double get _fine => .75 / _scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = kCityPaper);
    if (showGrid) _paintGrid(canvas, size);
    if (showBuildings) {
      for (final building in map.buildings) {
        if (building.kind == CityBuildingKind.park) {
          _paintBuilding(canvas, building);
        }
      }
    }
    if (showParcels) {
      for (final building in map.buildings) {
        _paintParcel(canvas, building);
      }
    }
    if (showRoads) {
      final lines = {for (final road in map.roads) road.id: road.centerline};
      for (var pass = 0; pass < 3; pass++) {
        for (final road in map.roads) {
          _paintRoadBase(canvas, lines[road.id]!, road.kind, pass: pass);
        }
      }
      canvas.save();
      var markingArea = Path()..addRect(Offset.zero & size);
      for (final junction in map.junctions) {
        if (junction.roadIds.length < 2) continue;
        var width = 0.0;
        for (final road in map.roads) {
          if (junction.roadIds.contains(road.id)) {
            width = math.max(width, road.kind.width);
          }
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
      for (final road in map.roads) {
        _paintRoadMarkings(canvas, lines[road.id]!, road.kind);
      }
      canvas.restore();
      for (final road in map.roads) {
        if (road.name.trim().isNotEmpty) {
          _paintRoadName(canvas, road, lines[road.id]!);
        }
      }
    }
    if (showConnections) {
      for (final building in map.buildings) {
        _paintConnection(canvas, building);
      }
    }
    if (showBuildings) {
      for (final building in map.buildings) {
        if (building.kind != CityBuildingKind.park) {
          _paintBuilding(canvas, building);
        }
      }
      for (final building in map.buildings) {
        if (building.id == selectedId) {
          _paintBuildingSelection(canvas, building);
        }
        if (building.name.trim().isNotEmpty) {
          _paintBuildingName(canvas, building);
        }
      }
    }
    if (showJunctions && showRoads) {
      for (final junction in map.junctions) {
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
      for (final road in map.roads) {
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

  void _paintGrid(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0x145F6B68)
      ..strokeWidth = .5 / _scale;
    final major = Paint()
      ..color = const Color(0x235F6B68)
      ..strokeWidth = .65 / _scale;
    for (var x = 0.0; x <= size.width; x += kCityGrid) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        (x / kCityGrid).round() % 5 == 0 ? major : minor,
      );
    }
    for (var y = 0.0; y <= size.height; y += kCityGrid) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        (y / kCityGrid).round() % 5 == 0 ? major : minor,
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
    if (points.length < 2) return;
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
      _drawDashedPath(canvas, path, paint, dash: 9, gap: 9);
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
      canvas.drawRect(bounds, Paint()..color = color);
      canvas.drawRect(
        bounds,
        Paint()
          ..color = const Color(0xFF81867D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / _scale,
      );
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
    canvas.drawPath(
      polylinePath(road.centerline),
      Paint()
        ..color = _selectionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / _scale,
    );
    for (final point in road.points) {
      _paintHandle(canvas, point);
    }
  }

  void _paintDraft(Canvas canvas) {
    if (draftRoad.isEmpty) return;
    if (draftRoad.length > 1) {
      final points = CityRoad(
        id: 'draft',
        points: draftRoad,
        curved: draftCurved,
      ).centerline;
      canvas.saveLayer(null, Paint()..color = const Color(0xBDFFFFFF));
      for (var pass = 0; pass < 3; pass++) {
        _paintRoadBase(canvas, points, roadKind, pass: pass);
      }
      _paintRoadMarkings(canvas, points, roadKind);
      canvas.restore();
      _drawDashedPath(
        canvas,
        polylinePath(points),
        Paint()
          ..color = _selectionColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 / _scale,
        dash: 6 / _scale,
        gap: 4 / _scale,
      );
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
    final tangent = metrics.first.getTangentForOffset(metrics.first.length / 2);
    if (tangent == null) return;
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
    )..layout(maxWidth: 160 / _scale);
    var angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
    if (angle > math.pi / 2) angle -= math.pi;
    if (angle < -math.pi / 2) angle += math.pi;
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _paintBuildingName(Canvas canvas, CityBuilding building) {
    if (_scale < .5 && building.id != selectedId) return;
    final painter = TextPainter(
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
    )..layout(maxWidth: math.max(96 / _scale, building.bounds.width + 24));
    painter.paint(
      canvas,
      Offset(
        building.x - painter.width / 2,
        building.bounds.bottom + 5 / _scale,
      ),
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dash = 8,
    double gap = 5,
  }) {
    for (final metric in path.computeMetrics()) {
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dash + gap
      ) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CityMapPainter oldDelegate) => true;
}

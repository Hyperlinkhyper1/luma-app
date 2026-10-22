import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'city_map_models.dart';
import 'map_maker_geometry.dart';

const kCityPaper = Color(0xFFEAF0E3);
const _selectionColor = Color(0xFF008CA8);

class CityMapPainter extends CustomPainter {
  CityMapPainter({
    required this.map,
    this.selectedId,
    this.draftRoad = const [],
    this.roadKind = CityRoadKind.street,
    this.previewBuilding,
    this.showGrid = true,
    this.textDirection = TextDirection.ltr,
  });

  final CityMap map;
  final String? selectedId;
  final List<Offset> draftRoad;
  final CityRoadKind roadKind;
  final CityBuilding? previewBuilding;
  final bool showGrid;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kCityPaper);
    if (showGrid) _paintGrid(canvas, size);

    for (final building in map.buildings) {
      if (building.kind == CityBuildingKind.park) {
        _paintBuilding(canvas, building);
      }
    }
    for (final road in map.roads) {
      _paintRoadBase(canvas, road.points, road.kind, border: true);
    }
    for (final road in map.roads) {
      _paintRoadBase(canvas, road.points, road.kind, border: false);
    }
    for (final road in map.roads) {
      _paintRoadMarkings(canvas, road.points, road.kind);
    }
    for (final building in map.buildings) {
      if (building.kind != CityBuildingKind.park) {
        _paintBuilding(canvas, building);
      }
    }
    for (final building in map.buildings) {
      if (building.id == selectedId) _paintBuildingSelection(canvas, building);
      if (building.name.trim().isNotEmpty) _paintName(canvas, building);
    }
    for (final road in map.roads) {
      if (road.id == selectedId) _paintRoadSelection(canvas, road);
    }

    if (draftRoad.isNotEmpty) {
      if (draftRoad.length > 1) {
        canvas.saveLayer(null, Paint()..color = const Color(0xBBFFFFFF));
        _paintRoadBase(canvas, draftRoad, roadKind, border: true);
        _paintRoadBase(canvas, draftRoad, roadKind, border: false);
        _paintRoadMarkings(canvas, draftRoad, roadKind);
        canvas.restore();
        _drawDashedPath(
          canvas,
          polylinePath(draftRoad),
          Paint()
            ..color = _selectionColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      for (final point in draftRoad) {
        _paintHandle(canvas, point);
      }
    }

    final preview = previewBuilding;
    if (preview != null) {
      canvas.saveLayer(null, Paint()..color = const Color(0xAFFFFFFF));
      _paintBuilding(canvas, preview);
      canvas.restore();
      _paintBuildingSelection(canvas, preview);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0x13546D4A)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = const Color(0x22546D4A)
      ..strokeWidth = 1;
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
    required bool border,
  }) {
    if (points.length < 2) return;
    final isPath = kind == CityRoadKind.pedestrian;
    canvas.drawPath(
      polylinePath(points),
      Paint()
        ..color = border
            ? (isPath ? const Color(0xFFB8AD91) : const Color(0xFFC8CCBE))
            : switch (kind) {
                CityRoadKind.street => const Color(0xFF697174),
                CityRoadKind.avenue => const Color(0xFF596368),
                CityRoadKind.highway => const Color(0xFF48545C),
                CityRoadKind.pedestrian => const Color(0xFFDDCFAB),
              }
        ..style = PaintingStyle.stroke
        ..strokeWidth = kind.width + (border ? (isPath ? 3 : 8) : 0)
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
            ..color = const Color(0xBCEEF0E5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
          dash: 9,
          gap: 11,
        );
      case CityRoadKind.avenue:
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFB9BEA5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
        _paintOffsetLane(canvas, points, 12, dashed: true);
        _paintOffsetLane(canvas, points, -12, dashed: true);
      case CityRoadKind.highway:
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFDDC57D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF48545C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round,
        );
        _paintOffsetLane(canvas, points, 14, dashed: true);
        _paintOffsetLane(canvas, points, -14, dashed: true);
        _paintOffsetLane(canvas, points, 25, dashed: false);
        _paintOffsetLane(canvas, points, -25, dashed: false);
      case CityRoadKind.pedestrian:
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = const Color(0x75A99A76)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
          dash: 2,
          gap: 8,
        );
    }
  }

  void _paintOffsetLane(
    Canvas canvas,
    List<Offset> points,
    double offset, {
    required bool dashed,
  }) {
    final paint = Paint()
      ..color = const Color(0xB8F2F1DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 1; i < points.length; i++) {
      final delta = points[i] - points[i - 1];
      if (delta.distance < 0.1) continue;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance * offset;
      final path = Path()
        ..moveTo((points[i - 1] + normal).dx, (points[i - 1] + normal).dy)
        ..lineTo((points[i] + normal).dx, (points[i] + normal).dy);
      if (dashed) {
        _drawDashedPath(canvas, path, paint, dash: 11, gap: 10);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _paintBuilding(Canvas canvas, CityBuilding building) {
    canvas.save();
    canvas.translate(building.x, building.y);
    canvas.rotate(building.quarterTurns * math.pi / 2);
    final size = building.size;
    final lot = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );

    switch (building.kind) {
      case CityBuildingKind.house:
        _paintHouse(canvas, lot);
      case CityBuildingKind.apartment:
        _paintApartment(canvas, lot);
      case CityBuildingKind.shop:
        _paintShop(canvas, lot);
      case CityBuildingKind.office:
        _paintOffice(canvas, lot);
      case CityBuildingKind.school:
        _paintSchool(canvas, lot);
      case CityBuildingKind.hospital:
        _paintHospital(canvas, lot);
      case CityBuildingKind.park:
        _paintPark(canvas, lot);
      case CityBuildingKind.tree:
        _paintTree(canvas, Offset.zero, 9.5);
    }
    canvas.restore();
  }

  void _paintLot(Canvas canvas, Rect lot, {bool paved = false}) {
    _roundRect(
      canvas,
      lot.deflate(1),
      paved ? const Color(0xFFD6DBD1) : const Color(0xFFCBDEB8),
      radius: 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot.deflate(1), const Radius.circular(4)),
      Paint()
        ..color = const Color(0x557F9272)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _paintRoof(Canvas canvas, Rect rect, Color color, {double radius = 2}) {
    _roundRect(
      canvas,
      rect.shift(const Offset(2, 3)),
      const Color(0x33505D47),
      radius: radius,
    );
    _roundRect(canvas, rect, color, radius: radius);
  }

  void _paintHouse(Canvas canvas, Rect lot) {
    _paintLot(canvas, lot);
    canvas.drawRect(
      Rect.fromLTWH(-3, 8, 6, lot.bottom - 8),
      Paint()..color = const Color(0xFFE3D7BD),
    );
    final roof = Rect.fromLTRB(lot.left + 7, lot.top + 6, lot.right - 7, 11);
    _paintRoof(canvas, roof, const Color(0xFFB9674E));
    final rightSlope = Rect.fromLTRB(0, roof.top, roof.right, roof.bottom);
    canvas.drawRect(rightSlope, Paint()..color = const Color(0xFF9C4F3E));
    canvas.drawLine(
      Offset(0, roof.top),
      Offset(0, roof.bottom),
      Paint()
        ..color = const Color(0xFFD49371)
        ..strokeWidth = 2,
    );
    for (var y = roof.top + 6; y < roof.bottom - 2; y += 6) {
      canvas.drawLine(
        Offset(roof.left + 1, y),
        Offset(roof.right - 1, y),
        Paint()
          ..color = const Color(0x33713D31)
          ..strokeWidth = 0.8,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(roof.left + 5, roof.top + 4, 5, 7),
      Paint()..color = const Color(0xFFE2D9BF),
    );
    _paintTree(canvas, Offset(lot.right - 7, lot.bottom - 8), 4.5);
  }

  void _paintApartment(Canvas canvas, Rect lot) {
    _paintLot(canvas, lot, paved: true);
    final roof = lot.deflate(8);
    _paintRoof(canvas, roof, const Color(0xFFCCBC9A));
    canvas.drawRect(
      Rect.fromLTRB(
        roof.left + 4,
        roof.top + 4,
        roof.right - 4,
        roof.bottom - 4,
      ),
      Paint()..color = const Color(0xFFE1D5B8),
    );
    _paintWindows(
      canvas,
      roof,
      columns: 4,
      rows: 3,
      color: const Color(0xFF768F91),
    );
    _roundRect(canvas, Rect.fromLTWH(-7, -8, 14, 16), const Color(0xFFACAD9E));
    canvas.drawRect(
      const Rect.fromLTWH(-3, -4, 6, 8),
      Paint()..color = const Color(0xFF7E8D85),
    );
    canvas.drawRect(
      Rect.fromLTWH(-6, roof.bottom, 12, 5),
      Paint()..color = const Color(0xFF8D8C7D),
    );
    _paintTree(canvas, Offset(lot.left + 5, lot.bottom - 6), 4);
    _paintTree(canvas, Offset(lot.right - 5, lot.bottom - 6), 4);
  }

  void _paintShop(Canvas canvas, Rect lot) {
    _paintLot(canvas, lot, paved: true);
    final roof = Rect.fromLTRB(
      lot.left + 6,
      lot.top + 5,
      lot.right - 6,
      lot.bottom - 10,
    );
    _paintRoof(canvas, roof, const Color(0xFFDAAF65));
    _roundRect(
      canvas,
      Rect.fromLTWH(roof.left + 8, roof.top + 6, 16, 8),
      const Color(0xFFE9D19B),
    );
    final count = (roof.width / 6).floor();
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          roof.left + i * roof.width / count,
          roof.bottom - 2,
          roof.width / count,
          7,
        ),
        Paint()
          ..color = i.isEven
              ? const Color(0xFFCF7660)
              : const Color(0xFFF3E6CD),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(-4, roof.bottom + 5, 8, 3),
      Paint()..color = const Color(0xFF7D9C9C),
    );
    _paintTree(canvas, Offset(lot.right - 5, lot.bottom - 5), 3.5);
  }

  void _paintOffice(Canvas canvas, Rect lot) {
    _paintLot(canvas, lot, paved: true);
    final roof = Rect.fromLTRB(
      lot.left + 10,
      lot.top + 6,
      lot.right - 10,
      lot.bottom - 9,
    );
    _paintRoof(canvas, roof, const Color(0xFF789FA6), radius: 3);
    _paintWindows(
      canvas,
      roof,
      columns: 4,
      rows: 7,
      color: const Color(0xFFBDD4D2),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        roof.left + 10,
        roof.top + 10,
        roof.width - 20,
        roof.height - 20,
      ),
      Paint()..color = const Color(0xFF567D87),
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(-9, -12, 18, 24),
      const Color(0xFFB5C6BC),
    );
    for (var y = -8.0; y <= 7; y += 5) {
      canvas.drawLine(
        Offset(-6, y),
        Offset(6, y),
        Paint()
          ..color = const Color(0xFF7D948C)
          ..strokeWidth = 1.2,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(-8, roof.bottom - 2, 16, 7),
      Paint()..color = const Color(0xFFCCE1D9),
    );
  }

  void _paintSchool(Canvas canvas, Rect lot) {
    _paintLot(canvas, lot);
    final yard = Rect.fromLTRB(
      lot.left + 7,
      lot.top + 7,
      lot.left + 43,
      lot.bottom - 7,
    );
    _roundRect(canvas, yard, const Color(0xFFB8CCA0));
    canvas.drawRect(
      yard.deflate(4),
      Paint()
        ..color = const Color(0x99F4F1D5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(yard.left + 4, yard.center.dy),
      Offset(yard.right - 4, yard.center.dy),
      Paint()
        ..color = const Color(0x99F4F1D5)
        ..strokeWidth = 1,
    );
    final roof = Rect.fromLTRB(
      lot.left + 51,
      lot.top + 6,
      lot.right - 7,
      lot.bottom - 10,
    );
    _paintRoof(canvas, roof, const Color(0xFFC48E5D));
    _paintWindows(
      canvas,
      roof,
      columns: 5,
      rows: 3,
      color: const Color(0xFFDBDFBF),
    );
    canvas.drawRect(
      Rect.fromLTRB(
        roof.left + 6,
        roof.top + 7,
        roof.right - 6,
        roof.bottom - 7,
      ),
      Paint()..color = const Color(0xFFD9AF78),
    );
    canvas.drawRect(
      Rect.fromLTWH(roof.center.dx - 4, roof.bottom, 8, 8),
      Paint()..color = const Color(0xFFE2D8BD),
    );
    _paintTree(canvas, Offset(lot.left + 45, lot.top + 10), 4);
    _paintTree(canvas, Offset(lot.left + 45, lot.bottom - 10), 4);
  }

  void _paintHospital(Canvas canvas, Rect lot) {
    _paintLot(canvas, lot, paved: true);
    final roof = lot.deflate(10);
    _paintRoof(canvas, roof, const Color(0xFFE3E8DE), radius: 4);
    _paintWindows(
      canvas,
      roof,
      columns: 6,
      rows: 5,
      color: const Color(0xFF99B7B4),
    );
    canvas.drawRect(roof.deflate(10), Paint()..color = const Color(0xFFF4F3E9));
    final cross = Paint()..color = const Color(0xFFD5796C);
    canvas.drawRect(const Rect.fromLTWH(-5, -17, 10, 34), cross);
    canvas.drawRect(const Rect.fromLTWH(-17, -5, 34, 10), cross);
    _roundRect(
      canvas,
      Rect.fromLTWH(-11, roof.bottom - 3, 22, 8),
      const Color(0xFF8DACA8),
    );
  }

  void _paintPark(Canvas canvas, Rect lot) {
    _roundRect(canvas, lot.deflate(1), const Color(0xFFBBD79C), radius: 9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot.deflate(2), const Radius.circular(8)),
      Paint()
        ..color = const Color(0xFF9ABF7E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final path = Path()
      ..moveTo(lot.left, lot.bottom - 12)
      ..quadraticBezierTo(-5, lot.bottom - 12, -7, 0)
      ..quadraticBezierTo(-12, lot.top + 12, lot.right, lot.top + 12);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE4D7B2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromLTWH(lot.right - 40, lot.bottom - 37, 28, 22),
      Paint()..color = const Color(0xFF8BBBC0),
    );
    canvas.drawArc(
      Rect.fromLTWH(lot.right - 36, lot.bottom - 33, 18, 10),
      0.1,
      2.2,
      false,
      Paint()
        ..color = const Color(0xFFB7D5D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    _paintTree(canvas, Offset(lot.left + 19, lot.top + 19), 12);
    _paintTree(canvas, Offset(lot.left + 42, lot.top + 31), 9);
    _paintTree(canvas, Offset(lot.right - 19, lot.top + 33), 10);
    _paintTree(canvas, Offset(lot.left + 23, lot.bottom - 24), 9);
    _roundRect(
      canvas,
      Rect.fromLTWH(5, lot.top + 25, 14, 4),
      const Color(0xFFAD8B58),
      radius: 1,
    );
  }

  void _paintTree(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center + const Offset(2, 3),
      radius,
      Paint()..color = const Color(0x28546638),
    );
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF6F9D60));
    canvas.drawCircle(
      center + Offset(-radius * 0.18, -radius * 0.2),
      radius * 0.75,
      Paint()..color = const Color(0xFF8AB574),
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.24, -radius * 0.3),
      radius * 0.34,
      Paint()..color = const Color(0xFFA1C587),
    );
  }

  void _paintWindows(
    Canvas canvas,
    Rect rect, {
    required int columns,
    required int rows,
    required Color color,
  }) {
    final paint = Paint()..color = color;
    for (var x = 0; x < columns; x++) {
      final left = rect.left + 4 + x * (rect.width - 8) / columns;
      canvas.drawRect(Rect.fromLTWH(left, rect.top + 2, 4, 4), paint);
      canvas.drawRect(Rect.fromLTWH(left, rect.bottom - 6, 4, 4), paint);
    }
    for (var y = 0; y < rows; y++) {
      final top = rect.top + 8 + y * (rect.height - 16) / rows;
      canvas.drawRect(Rect.fromLTWH(rect.left + 2, top, 4, 4), paint);
      canvas.drawRect(Rect.fromLTWH(rect.right - 6, top, 4, 4), paint);
    }
  }

  void _paintBuildingSelection(Canvas canvas, CityBuilding building) {
    canvas.save();
    canvas.translate(building.x, building.y);
    canvas.rotate(building.quarterTurns * math.pi / 2);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: building.size.width + 8,
      height: building.size.height + 8,
    );
    _drawDashedPath(
      canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(5))),
      Paint()
        ..color = _selectionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      dash: 5,
      gap: 3,
    );
    canvas.restore();
  }

  void _paintRoadSelection(Canvas canvas, CityRoad road) {
    if (road.points.length < 2) return;
    _drawDashedPath(
      canvas,
      polylinePath(road.points),
      Paint()
        ..color = const Color(0xFF72D1E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
      dash: 8,
      gap: 5,
    );
    for (final point in road.points) {
      _paintHandle(canvas, point);
    }
  }

  void _paintHandle(Canvas canvas, Offset point) {
    canvas.drawCircle(point, 4.5, Paint()..color = const Color(0xFFF9FCF4));
    canvas.drawCircle(
      point,
      4.5,
      Paint()
        ..color = _selectionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
  }

  void _paintName(Canvas canvas, CityBuilding building) {
    final painter = TextPainter(
      text: TextSpan(
        text: building.name,
        style: const TextStyle(
          color: Color(0xFF344B3A),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          backgroundColor: Color(0xDAEEF3E8),
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(96.0, building.bounds.width + 24));
    painter.paint(
      canvas,
      Offset(building.x - painter.width / 2, building.bounds.bottom + 4),
    );
  }

  void _roundRect(Canvas canvas, Rect rect, Color color, {double radius = 2}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
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

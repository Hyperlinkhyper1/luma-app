import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'map_maker_geometry.dart';
import 'map_maker_models.dart';

const kTransitPaper = Color(0xFFF7F3E8);
const kTransitInk = Color(0xFF1C1914);
const kTransitRiverFill = Color(0xFFB7D4EA);
const kTransitRiverStroke = Color(0xFF7EADC8);

class TransitMapPainter extends CustomPainter {
  TransitMapPainter({
    required this.map,
    required this.revision,
    required this.showGrid,
    this.selectedStationId,
    this.selectedLineId,
    this.selectedRiverId,
    this.connectingFromStationId,
    this.draftRiver = const [],
    this.hover,
    this.scale = 1,
  });

  final TransitMap map;
  final int revision;
  final bool showGrid;
  final String? selectedStationId;
  final String? selectedLineId;
  final String? selectedRiverId;
  final String? connectingFromStationId;
  final List<Offset> draftRiver;
  final Offset? hover;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kTransitPaper);
    if (showGrid) _paintGrid(canvas, size);

    for (final river in map.rivers) {
      _paintRiver(canvas, river.points, river.closed, selected: river.id == selectedRiverId);
    }
    if (draftRiver.length >= 2) {
      _paintRiver(canvas, draftRiver, false, selected: true);
    } else if (draftRiver.length == 1 && hover != null) {
      _paintRiver(
        canvas,
        octilinearPath(draftRiver.first, hover!),
        false,
        selected: true,
      );
    }

    for (final line in map.lines) {
      _paintLine(canvas, line, selected: line.id == selectedLineId);
    }

    if (connectingFromStationId != null && hover != null) {
      final st = map.stationById(connectingFromStationId!);
      if (st != null) {
        final activeLine = selectedLineId != null ? map.lineById(selectedLineId!) : null;
        final lineColor = activeLine != null ? Color(activeLine.color) : const Color(0xFF3B82F6);
        final run = octilinearPath(st.position, snapToTransitGrid(hover!));
        final path = polylinePath(run);
        canvas.drawPath(
          path,
          Paint()
            ..color = lineColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    for (final station in map.stations) {
      _paintStation(canvas, station, selected: station.id == selectedStationId);
    }
    for (final station in map.stations) {
      _paintLabel(canvas, station);
    }

    if (hover != null) {
      final snapped = snapToTransitGrid(hover!);
      canvas.drawCircle(
        snapped,
        3.5,
        Paint()
          ..color = const Color(0x661C1914)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14221E18)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += kTransitGrid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += kTransitGrid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintRiver(
    Canvas canvas,
    List<Offset> points,
    bool closed, {
    required bool selected,
  }) {
    if (points.length < 2) return;
    final path = polylinePath(points, close: closed);
    if (closed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = kTransitRiverFill.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? const Color(0xFF3D7EA6) : kTransitRiverStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = kTransitRiverFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintLine(Canvas canvas, TransitLine line, {required bool selected}) {
    final poly = map.linePolyline(line);
    if (poly.length < 2) return;
    final path = polylinePath(poly);
    final color = Color(line.color);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 14 : 11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (line.stationIds.length >= 2) {
      final last = map.stationById(line.stationIds.last);
      final prev = map.stationById(line.stationIds[line.stationIds.length - 2]);
      if (last != null && prev != null) {
        _paintTerminusTick(canvas, prev.position, last.position, color);
      }
      final first = map.stationById(line.stationIds.first);
      final next = map.stationById(line.stationIds[1]);
      if (first != null && next != null) {
        _paintTerminusTick(canvas, next.position, first.position, color);
      }
    }
  }

  void _paintTerminusTick(Canvas canvas, Offset from, Offset at, Color color) {
    final delta = at - from;
    final length = delta.distance;
    if (length < 1) return;
    final dir = delta / length;
    final normal = Offset(-dir.dy, dir.dx);
    const tick = 11.0;
    canvas.drawLine(
      at + normal * tick,
      at - normal * tick,
      Paint()
        ..color = color
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.square,
    );
  }

  void _paintStation(
    Canvas canvas,
    TransitStation station, {
    required bool selected,
  }) {
    final interchange = map.isInterchange(station);
    final airport = station.kind == TransitStationKind.airport;
    final radius = interchange || airport ? 9.0 : 6.2;
    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = selected ? const Color(0xFF3B82F6) : kTransitInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = interchange ? 3.4 : 2.4;
    canvas.drawCircle(station.position, radius, fill);
    canvas.drawCircle(station.position, radius, ring);
    if (interchange) {
      canvas.drawCircle(
        station.position,
        radius - 4,
        Paint()
          ..color = kTransitInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    if (airport) {
      _paintPlane(canvas, station.position + const Offset(14, -12));
    }
    if (selected) {
      canvas.drawCircle(
        station.position,
        radius + 5,
        Paint()
          ..color = const Color(0x663B82F6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintPlane(Canvas canvas, Offset at) {
    final path = Path()
      ..moveTo(at.dx, at.dy - 7)
      ..lineTo(at.dx + 5, at.dy + 6)
      ..lineTo(at.dx, at.dy + 3)
      ..lineTo(at.dx - 5, at.dy + 6)
      ..close();
    canvas.drawPath(path, Paint()..color = kTransitInk);
  }

  void _paintLabel(Canvas canvas, TransitStation station) {
    if (station.name.trim().isEmpty) return;
    final fontSize = (11.5 / math.max(0.55, scale.clamp(0.5, 2.2))).clamp(9.0, 14.0);
    final painter = TextPainter(
      text: TextSpan(
        text: station.name,
        style: TextStyle(
          color: kTransitInk,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final origin = station.position + Offset(station.labelDx, station.labelDy);
    final rect = origin & painter.size;
    canvas.drawRRect(
      RRect.fromRectXY(rect.inflate(2.5), 3, 3),
      Paint()..color = kTransitPaper.withValues(alpha: 0.86),
    );
    painter.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant TransitMapPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.map != map ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.selectedStationId != selectedStationId ||
        oldDelegate.selectedLineId != selectedLineId ||
        oldDelegate.selectedRiverId != selectedRiverId ||
        oldDelegate.connectingFromStationId != connectingFromStationId ||
        oldDelegate.draftRiver != draftRiver ||
        oldDelegate.hover != hover ||
        oldDelegate.scale != scale;
  }
}

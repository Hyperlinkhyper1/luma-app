import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'city_map_models.dart';

class CityMeasurePainter extends CustomPainter {
  CityMeasurePainter({
    required this.start,
    required this.end,
    required this.transform,
    required this.label,
    required this.textDirection,
    this.fontFamily,
  });

  final Offset start;
  final Offset end;
  final Matrix4 transform;
  final String label;
  final TextDirection textDirection;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final a = MatrixUtils.transformPoint(transform, start);
    final b = MatrixUtils.transformPoint(transform, end);
    const ink = Color(0xFF07839B);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = ink
        ..strokeWidth = 2,
    );
    for (final point in [a, b]) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: textDirection,
    )..layout(maxWidth: math.max(1, size.width - 32));
    final center = (a + b) / 2;
    final labelWidth = text.width + 20;
    final position = Offset(
      (center.dx - labelWidth / 2).clamp(
        8,
        math.max(8, size.width - labelWidth - 8),
      ),
      (center.dy - text.height - 20).clamp(
        8,
        math.max(8, size.height - text.height - 20),
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        position & Size(labelWidth, text.height + 12),
        const Radius.circular(8),
      ),
      Paint()..color = ink,
    );
    text.paint(canvas, position + const Offset(10, 6));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CityMeasurePainter oldDelegate) => true;
}

class CityMapNavigator extends StatelessWidget {
  const CityMapNavigator({
    super.key,
    required this.map,
    required this.viewport,
    required this.onNavigate,
    this.showRoads = true,
    this.showBuildings = true,
  });

  final CityMap map;
  final Rect viewport;
  final ValueChanged<Offset> onNavigate;
  final bool showRoads;
  final bool showBuildings;

  @override
  Widget build(BuildContext context) {
    final bounds = (map.contentBounds ?? viewport).expandToInclude(viewport);
    final world = bounds.inflate(math.max(bounds.longestSide * .08, 48));
    const size = Size(176, 118);
    final frame = _NavigatorFrame(world, size);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        border: Border.all(color: const Color(0xFFB9C8C2)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                onNavigate(frame.toWorld(details.localPosition)),
            child: CustomPaint(
              size: size,
              painter: _NavigatorPainter(
                map: map,
                viewport: viewport,
                frame: frame,
                showRoads: showRoads,
                showBuildings: showBuildings,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigatorFrame {
  _NavigatorFrame(this.world, Size size)
    : scale = math.min(
        size.width / math.max(world.width, 1),
        size.height / math.max(world.height, 1),
      ),
      center = size.center(Offset.zero);

  final Rect world;
  final double scale;
  final Offset center;

  Offset toScreen(Offset point) => center + (point - world.center) * scale;
  Offset toWorld(Offset point) => world.center + (point - center) / scale;
}

class _NavigatorPainter extends CustomPainter {
  _NavigatorPainter({
    required this.map,
    required this.viewport,
    required this.frame,
    required this.showRoads,
    required this.showBuildings,
  });

  final CityMap map;
  final Rect viewport;
  final _NavigatorFrame frame;
  final bool showRoads;
  final bool showBuildings;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF5F5F0), BlendMode.src);
    if (showBuildings) {
      for (final building in map.buildings) {
        final path = Path();
        for (var index = 0; index < building.footprint.length; index++) {
          final point = frame.toScreen(building.footprint[index]);
          index == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = switch (building.kind) {
              CityBuildingKind.park ||
              CityBuildingKind.tree => const Color(0xFF7BA280),
              _ => const Color(0xFFB9A995),
            },
        );
      }
    }
    if (showRoads) {
      for (final road in map.roads) {
        final points = road.centerline;
        if (points.length < 2) continue;
        final path = Path();
        for (var index = 0; index < points.length; index++) {
          final point = frame.toScreen(points[index]);
          index == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF889994)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, road.kind.width * frame.scale)
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    final visible = Rect.fromPoints(
      frame.toScreen(viewport.topLeft),
      frame.toScreen(viewport.bottomRight),
    );
    canvas.drawRect(visible, Paint()..color = const Color(0x1807839B));
    canvas.drawRect(
      visible,
      Paint()
        ..color = const Color(0xFF07839B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      frame.toScreen(viewport.center),
      2.5,
      Paint()..color = const Color(0xFF07839B),
    );
  }

  @override
  bool shouldRepaint(covariant _NavigatorPainter oldDelegate) => true;
}

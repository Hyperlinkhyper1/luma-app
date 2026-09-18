import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../account/travel/world_map_data.dart';
import '../../../../../theme/luma_theme.dart';
import '../airline_tycoon_repository.dart';
import '../data/airport_catalog.dart';
import '../sim/geo.dart';

/// The route network on a world map.
///
/// Reuses the bundled country outline behind Account -> Stats rather than
/// shipping a second one, which also means airports must be projected with
/// the *same* Miller projection into the same unit square — otherwise the
/// dots sit next to their countries instead of on them.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.repository,
    required this.onSelect,
    this.selected,
  });

  final AirlineTycoonRepository repository;
  final ValueChanged<Airport> onSelect;
  final Airport? selected;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _controller = TransformationController();
  Future<WorldMap>? _world;

  @override
  void initState() {
    super.initState();
    _world = WorldMap.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return FutureBuilder<WorldMap>(
      future: _world,
      builder: (context, snapshot) {
        final world = snapshot.data;
        if (world == null) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            // The projection is 2.04:1, so fit the map to the pane without
            // squashing it rather than stretching to fill.
            final width = constraints.maxWidth;
            final height =
                math.min(constraints.maxHeight, width / MillerProjection.aspectRatio);
            final size = Size(width, height);

            return ClipRect(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 12,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _handleTap(details.localPosition, size),
                    child: CustomPaint(
                      size: size,
                      painter: _RouteMapPainter(
                        world: world,
                        repository: widget.repository,
                        selected: widget.selected,
                        land: luma.surfaceHover,
                        landBorder: luma.border,
                        hub: luma.accent,
                        served: luma.success,
                        idle: luma.textMuted,
                        route: luma.accent,
                        label: luma.textPrimary,
                        labelBackdrop: luma.surface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleTap(Offset position, Size size) {
    final catalog = widget.repository.catalog;
    if (catalog == null) return;

    Airport? nearest;
    var bestDistance = double.infinity;
    for (final airport in catalog.airports) {
      final point = _project(airport, size);
      final distance = (point - position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = airport;
      }
    }
    // A generous radius: at world zoom the dots are a few pixels across, and
    // demanding a pixel-perfect tap on one would be unusable on a phone.
    final scale = _controller.value.getMaxScaleOnAxis();
    if (nearest != null && bestDistance <= 22 / scale) {
      widget.onSelect(nearest);
    }
  }

  static Offset _project(Airport airport, Size size) {
    final unit = MillerProjection.project(airport.lon, airport.lat);
    return Offset(unit.dx * size.width, unit.dy * size.height);
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.world,
    required this.repository,
    required this.selected,
    required this.land,
    required this.landBorder,
    required this.hub,
    required this.served,
    required this.idle,
    required this.route,
    required this.label,
    required this.labelBackdrop,
  });

  final WorldMap world;
  final AirlineTycoonRepository repository;
  final Airport? selected;
  final Color land;
  final Color landBorder;
  final Color hub;
  final Color served;
  final Color idle;
  final Color route;
  final Color label;
  final Color labelBackdrop;

  static Offset _project(double lat, double lon, Size size) {
    final unit = MillerProjection.project(lon, lat);
    return Offset(unit.dx * size.width, unit.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final catalog = repository.catalog;
    if (catalog == null || size.isEmpty) return;

    // Land first.
    final paths = world.pathsFor(size);
    final landPaint = Paint()..color = land;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = landBorder;
    for (final path in paths.values) {
      canvas.drawPath(path, landPaint);
      canvas.drawPath(path, borderPaint);
    }

    final state = repository.state;
    final hubAirport = repository.hubAirport;

    // Every airport as a small dot, so the world reads as somewhere you
    // could fly rather than an empty map.
    final idlePaint = Paint()..color = idle.withValues(alpha: 0.5);
    for (final airport in catalog.airports) {
      canvas.drawCircle(
        _project(airport.lat, airport.lon, size),
        1.6,
        idlePaint,
      );
    }

    if (hubAirport == null) return;

    // Routes as great-circle arcs.
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = route.withValues(alpha: 0.85);
    for (final airlineRoute in state.routes) {
      final dest = catalog.byIata(airlineRoute.destIata);
      if (dest == null) continue;
      _drawArc(canvas, size, hubAirport, dest, routePaint);
    }

    // Destinations on top of the arcs.
    final servedPaint = Paint()..color = served;
    for (final airlineRoute in state.routes) {
      final dest = catalog.byIata(airlineRoute.destIata);
      if (dest == null) continue;
      canvas.drawCircle(_project(dest.lat, dest.lon, size), 3.4, servedPaint);
    }

    // The hub itself, unmistakably.
    final hubPoint = _project(hubAirport.lat, hubAirport.lon, size);
    canvas.drawCircle(hubPoint, 6, Paint()..color = hub.withValues(alpha: 0.3));
    canvas.drawCircle(hubPoint, 3.6, Paint()..color = hub);

    final chosen = selected;
    if (chosen != null) {
      final point = _project(chosen.lat, chosen.lon, size);
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = hub,
      );
      _drawLabel(canvas, point, chosen.label, size);
    }
    _drawLabel(canvas, hubPoint, hubAirport.label, size);
  }

  /// Draws a great-circle arc, split wherever it crosses the antimeridian so
  /// a Tokyo-Los Angeles route does not draw a straight line back across the
  /// entire map.
  void _drawArc(
    Canvas canvas,
    Size size,
    Airport from,
    Airport to,
    Paint paint,
  ) {
    const samples = 32;
    Path? path;
    Offset? previous;

    for (var i = 0; i <= samples; i++) {
      final point = Geo.interpolate(
        from.lat,
        from.lon,
        to.lat,
        to.lon,
        i / samples,
      );
      final screen = _project(point.lat, point.lon, size);
      if (previous != null &&
          (screen.dx - previous.dx).abs() > size.width * 0.5) {
        if (path != null) canvas.drawPath(path, paint);
        path = null;
      }
      if (path == null) {
        path = Path()..moveTo(screen.dx, screen.dy);
      } else {
        path.lineTo(screen.dx, screen.dy);
      }
      previous = screen;
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Offset anchor, String text, Size size) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: 10,
      textAlign: TextAlign.left,
    ))
      ..pushStyle(ui.TextStyle(color: label))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 160));

    // Flip the label to the other side when it would run off the edge.
    final wide = anchor.dx + paragraph.longestLine + 14 > size.width;
    final origin = Offset(
      wide ? anchor.dx - paragraph.longestLine - 10 : anchor.dx + 8,
      anchor.dy - paragraph.height / 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          origin.dx - 3,
          origin.dy - 1,
          paragraph.longestLine + 6,
          paragraph.height + 2,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = labelBackdrop.withValues(alpha: 0.82),
    );
    canvas.drawParagraph(paragraph, origin);
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) =>
      old.world != world ||
      old.selected != selected ||
      old.repository.state.hubRevision != repository.state.hubRevision ||
      old.repository.state.routes.length != repository.state.routes.length ||
      old.land != land;
}

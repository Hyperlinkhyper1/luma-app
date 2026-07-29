import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import 'world_map_data.dart';

/// The world, painted from [WorldMap] and coloured by which countries have
/// been visited. Pan and pinch/scroll to zoom, tap a country to toggle it.
class WorldMapView extends StatefulWidget {
  const WorldMapView({
    super.key,
    required this.map,
    required this.visited,
    required this.onToggle,
    this.controller,
  });

  final WorldMap map;

  /// Country codes marked as visited.
  final Set<String> visited;
  final ValueChanged<WorldCountry> onToggle;

  /// Optional external handle on the pan/zoom transform, so a parent can
  /// offer "reset view" or focus a country.
  final TransformationController? controller;

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView> {
  WorldCountry? _hovered;

  /// Turns a pointer position on the canvas into unit-space map coordinates.
  /// [local] is already in the unscaled child's own coordinates, so the
  /// current pan/zoom doesn't come into it.
  WorldCountry? _countryAt(Offset local, Size canvas) {
    if (canvas.isEmpty) return null;
    return widget.map
        .countryAt(Offset(local.dx / canvas.width, local.dy / canvas.height));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the whole world inside the viewport at rest; zooming from
        // there is the InteractiveViewer's job.
        final size = Size(
          constraints.maxWidth,
          constraints.maxWidth / MillerProjection.aspectRatio,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: size.width,
            height: size.height,
            color: luma.background,
            child: InteractiveViewer(
              transformationController: widget.controller,
              minScale: 1,
              maxScale: 12,
              child: MouseRegion(
                onHover: (event) {
                  final country = _countryAt(event.localPosition, size);
                  if (country != _hovered) setState(() => _hovered = country);
                },
                onExit: (_) => setState(() => _hovered = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final country = _countryAt(details.localPosition, size);
                    if (country != null) widget.onToggle(country);
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _WorldMapPainter(
                      map: widget.map,
                      visited: widget.visited,
                      hovered: _hovered,
                      luma: luma,
                      label: _hovered == null
                          ? null
                          : _labelFor(_hovered!, luma, context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ui.Paragraph _labelFor(
    WorldCountry country,
    LumaPalette luma,
    BuildContext context,
  ) {
    final visited = widget.visited.contains(country.code);
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      textDirection: Directionality.of(context),
    ))
      ..pushStyle(ui.TextStyle(color: luma.textPrimary))
      ..addText(country.name);
    if (visited) {
      builder
        ..pop()
        ..pushStyle(ui.TextStyle(color: luma.accent))
        ..addText('  ✓');
    }
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: 240));
  }
}

class _WorldMapPainter extends CustomPainter {
  _WorldMapPainter({
    required this.map,
    required this.visited,
    required this.hovered,
    required this.luma,
    required this.label,
  });

  final WorldMap map;
  final Set<String> visited;
  final WorldCountry? hovered;
  final LumaPalette luma;
  final ui.Paragraph? label;

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = luma.surfaceHover;
    final visitedFill = Paint()..color = luma.accent;
    final hoverFill = Paint()..color = luma.accent.withValues(alpha: 0.45);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = luma.background.withValues(alpha: 0.9);

    // Largest first so enclaves keep their own colour on top.
    for (final country in map.byDescendingSize) {
      final path = _pathFor(country, size);
      final isVisited = visited.contains(country.code);
      canvas.drawPath(
        path,
        isVisited
            ? visitedFill
            : (identical(country, hovered) ? hoverFill : land),
      );
      canvas.drawPath(path, stroke);
    }

    final hoveredCountry = hovered;
    if (hoveredCountry != null) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = visited.contains(hoveredCountry.code)
            ? luma.onAccent.withValues(alpha: 0.8)
            : luma.accent;
      canvas.drawPath(_pathFor(hoveredCountry, size), outline);
      _paintLabel(canvas, size, hoveredCountry);
    }
  }

  Path _pathFor(WorldCountry country, Size size) {
    final path = Path();
    for (final ring in country.rings) {
      _addRing(path, ring, size);
    }
    return path;
  }

  static void _addRing(Path path, Float32List ring, Size size) {
    path.moveTo(ring[0] * size.width, ring[1] * size.height);
    for (var i = 2; i < ring.length; i += 2) {
      path.lineTo(ring[i] * size.width, ring[i + 1] * size.height);
    }
    path.close();
  }

  /// Name chip pinned just above the hovered country, nudged to stay on
  /// canvas at the edges of the map.
  void _paintLabel(Canvas canvas, Size size, WorldCountry country) {
    final text = label;
    if (text == null) return;

    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
    final chip = Size(
      text.maxIntrinsicWidth + padding.horizontal,
      text.height + padding.vertical,
    );
    final anchor = country.bounds;
    var left = anchor.center.dx * size.width - chip.width / 2;
    var top = anchor.top * size.height - chip.height - 6;
    left = left.clamp(4.0, (size.width - chip.width - 4).clamp(4.0, size.width));
    if (top < 4) top = (anchor.bottom * size.height + 6).clamp(4.0, size.height);

    final rect = Rect.fromLTWH(left, top, chip.width, chip.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = luma.surface.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = luma.border,
    );
    canvas.drawParagraph(text, rect.topLeft + Offset(padding.left, padding.top));
  }

  @override
  bool shouldRepaint(_WorldMapPainter old) =>
      old.map != map ||
      old.hovered != hovered ||
      old.luma != luma ||
      !setEquals(old.visited, visited);
}

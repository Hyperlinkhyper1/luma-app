import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/buildings.dart';
import '../sim/hub.dart';
import '../sim/iso.dart';

/// Theme colours the hub is drawn in, resolved from `LumaPalette` by the
/// view. Kept as a value object so the painter never reaches for a
/// `BuildContext` and the geometry can be built off-frame.
@immutable
class HubPalette {
  const HubPalette({
    required this.ground,
    required this.groundEdge,
    required this.asphalt,
    required this.concrete,
    required this.glass,
    required this.metal,
    required this.grid,
  });

  final Color ground;
  final Color groundEdge;
  final Color asphalt;
  final Color concrete;
  final Color glass;
  final Color metal;
  final Color grid;

  Color forMaterial(BuildingMaterial material) => switch (material) {
        BuildingMaterial.asphalt => asphalt,
        BuildingMaterial.concrete => concrete,
        BuildingMaterial.glass => glass,
        BuildingMaterial.metal => metal,
        BuildingMaterial.grass => ground,
      };

  @override
  bool operator ==(Object other) =>
      other is HubPalette &&
      other.ground == ground &&
      other.groundEdge == groundEdge &&
      other.asphalt == asphalt &&
      other.concrete == concrete &&
      other.glass == glass &&
      other.metal == metal &&
      other.grid == grid;

  @override
  int get hashCode =>
      Object.hash(ground, groundEdge, asphalt, concrete, glass, metal, grid);
}

/// The triangles that make up the field, rebuilt only when the layout,
/// camera or theme actually changes.
///
/// This object is owned by the widget's State, never by the painter: a new
/// painter is constructed on every frame of a drag, and reallocating these
/// buffers each time would dominate the frame. Same reason the schematic
/// voxel viewer keeps its scratch buffers on the geometry.
class HubGeometry {
  Float32List _positions = Float32List(0);
  Int32List _colors = Int32List(0);
  int _count = 0;
  ui.Vertices? _vertices;

  /// Bumped on every rebuild so the painter can compare cheaply instead of
  /// deep-comparing the building list.
  int generation = 0;

  bool get isEmpty => _count == 0;
  ui.Vertices? get vertices => _vertices;

  /// Face shading, borrowed from the schematic viewer: a flat multiplier per
  /// face direction, which is enough to read as lit without a light model.
  static const double _topShade = 1.0;
  static const double _xShade = 0.80;
  static const double _yShade = 0.60;

  static const List<int> _quadOrder = [0, 1, 2, 0, 2, 3];

  void _ensure(int vertexCount) {
    if (_positions.length >= vertexCount * 2) return;
    // Grow generously; the buffer is reused across every later frame.
    final size = vertexCount * 2 * 2;
    _positions = Float32List(size);
    _colors = Int32List(size ~/ 2);
  }

  static int _shade(Color base, double factor) {
    final argb = base.toARGB32();
    final a = (argb >> 24) & 0xff;
    int channel(int shift) =>
        ((((argb >> shift) & 0xff) * factor).round()).clamp(0, 255);
    return (a << 24) |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }

  void _quad(Offset a, Offset b, Offset c, Offset d, int argb) {
    final corners = [a, b, c, d];
    for (final index in _quadOrder) {
      final point = corners[index];
      _positions[_count * 2] = point.dx;
      _positions[_count * 2 + 1] = point.dy;
      _colors[_count] = argb;
      _count++;
    }
  }

  /// Rebuilds the whole field. Cheap enough to do on any change: a full
  /// 24x24 grid is a few thousand triangles.
  void rebuild({
    required int gridSize,
    required List<PlacedBuilding> buildings,
    required IsoCamera camera,
    required HubPalette palette,
  }) {
    // Ground is one quad per tile; each building contributes a top and two
    // visible side faces.
    final maxVertices = (gridSize * gridSize + buildings.length * 3) * 6;
    _ensure(maxVertices);
    _count = 0;

    final groundArgb = _shade(palette.ground, _topShade);
    final groundAltArgb = _shade(palette.groundEdge, _topShade);
    for (var x = 0; x < gridSize; x++) {
      for (var y = 0; y < gridSize; y++) {
        final corners = camera.tileDiamond(x, y);
        // A faint checker makes the grid readable without drawing lines over
        // every tile, which at this scale would be visual noise.
        final argb = (x + y).isEven ? groundArgb : groundAltArgb;
        _quad(corners[0], corners[1], corners[2], corners[3], argb);
      }
    }

    // Painter's algorithm: emit far to near. drawVertices rasterises
    // triangles in array order, so emitting in depth order *is* the sort.
    final ordered = [...buildings]..sort((a, b) {
        final byDepth = IsoCamera.depthKey(a.x, a.y)
            .compareTo(IsoCamera.depthKey(b.x, b.y));
        if (byDepth != 0) return byDepth;
        return a.def.levels.compareTo(b.def.levels);
      });

    for (final building in ordered) {
      final def = building.def;
      final size = building.size;
      final base = palette.forMaterial(def.material);
      final h = def.levels;

      final x0 = building.x.toDouble();
      final y0 = building.y.toDouble();
      final x1 = x0 + size.width;
      final y1 = y0 + size.depth;

      // Top face.
      _quad(
        camera.project(x0, y0, h),
        camera.project(x1, y0, h),
        camera.project(x1, y1, h),
        camera.project(x0, y1, h),
        _shade(base, _topShade),
      );

      // Only the two faces pointing at the camera are ever visible, and with
      // a fixed camera that is known at compile time rather than per frame.
      _quad(
        camera.project(x1, y0, h),
        camera.project(x1, y1, h),
        camera.project(x1, y1),
        camera.project(x1, y0),
        _shade(base, _xShade),
      );
      _quad(
        camera.project(x0, y1, h),
        camera.project(x1, y1, h),
        camera.project(x1, y1),
        camera.project(x0, y1),
        _shade(base, _yShade),
      );
    }

    _vertices = _count == 0
        ? null
        : ui.Vertices.raw(
            ui.VertexMode.triangles,
            Float32List.sublistView(_positions, 0, _count * 2),
            colors: Int32List.sublistView(_colors, 0, _count),
          );
    generation++;
  }
}

/// Draws the field, plus the hover highlight and placement ghost on top.
class HubPainter extends CustomPainter {
  HubPainter({
    required this.geometry,
    required this.generation,
    required this.camera,
    required this.gridSize,
    required this.hoverTile,
    required this.ghost,
    required this.ghostValid,
    required this.ghostColor,
    required this.blockedColor,
    required this.hoverColor,
    required this.selection,
  });

  final HubGeometry geometry;

  /// Snapshotted so `shouldRepaint` compares an int rather than an object
  /// whose contents changed in place.
  final int generation;

  final IsoCamera camera;
  final int gridSize;
  final ({int x, int y})? hoverTile;
  final PlacedBuilding? ghost;
  final bool ghostValid;
  final Color ghostColor;
  final Color blockedColor;
  final Color hoverColor;
  final PlacedBuilding? selection;

  /// Modulating against opaque white passes the vertex colours through
  /// untouched. Built once here rather than inside `paint`, because a Paint
  /// made in `paint` would be gone by the time the frame is rasterised.
  static final Paint _neutral = Paint()..color = const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final vertices = geometry.vertices;
    if (vertices != null) {
      canvas.drawVertices(vertices, BlendMode.modulate, _neutral);
    }

    if (hoverTile != null && ghost == null) {
      _fillTiles(canvas, [hoverTile!], hoverColor.withValues(alpha: 0.35));
    }

    final selected = selection;
    if (selected != null) {
      _outline(canvas, selected, hoverColor);
    }

    final placing = ghost;
    if (placing != null) {
      final colour = ghostValid ? ghostColor : blockedColor;
      _fillTiles(canvas, placing.tiles.toList(), colour.withValues(alpha: 0.42));
      _outline(canvas, placing, colour);
    }
  }

  void _fillTiles(Canvas canvas, List<({int x, int y})> tiles, Color colour) {
    final paint = Paint()..color = colour;
    for (final tile in tiles) {
      final corners = camera.tileDiamond(tile.x, tile.y);
      canvas.drawPath(_pathOf(corners), paint);
    }
  }

  void _outline(Canvas canvas, PlacedBuilding building, Color colour) {
    final size = building.size;
    final h = building.def.levels;
    final x0 = building.x.toDouble();
    final y0 = building.y.toDouble();
    final x1 = x0 + size.width;
    final y1 = y0 + size.depth;

    final top = _pathOf([
      camera.project(x0, y0, h),
      camera.project(x1, y0, h),
      camera.project(x1, y1, h),
      camera.project(x0, y1, h),
    ]);
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colour,
    );
  }

  static Path _pathOf(List<Offset> corners) {
    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (var i = 1; i < corners.length; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(HubPainter old) =>
      old.generation != generation ||
      old.camera.origin != camera.origin ||
      old.gridSize != gridSize ||
      old.hoverTile != hoverTile ||
      old.ghost?.kind != ghost?.kind ||
      old.ghost?.x != ghost?.x ||
      old.ghost?.y != ghost?.y ||
      old.ghost?.rotation != ghost?.rotation ||
      old.ghostValid != ghostValid ||
      old.selection != selection;
}

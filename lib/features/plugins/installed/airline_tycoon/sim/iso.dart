import 'dart:ui' show Offset, Size;

/// The isometric camera for the hub builder.
///
/// This is the same shape of projection the schematic voxel viewer uses
/// (`lib/features/converter/tools/schematic_viewer.dart`): orthographic, with
/// no perspective divide, so screen position is *linear* in the world
/// coordinates and the whole camera collapses to a handful of coefficients.
/// Fixing the yaw at 45° and the pitch at the classic 2:1 ratio reduces those
/// coefficients to the two tile dimensions below, which in turn makes the
/// inverse a closed-form solve rather than a raycast.
///
/// Grid coordinates are continuous: tile (x, y) covers the unit square from
/// (x, y) to (x + 1, y + 1). `z` is elevation in levels, growing upward.
class IsoCamera {
  const IsoCamera({
    this.tileWidth = 64,
    this.tileHeight = 32,
    this.levelHeight = 26,
    this.origin = Offset.zero,
  });

  /// Screen width of one tile's diamond.
  final double tileWidth;

  /// Screen height of one tile's diamond. Half [tileWidth] gives the 2:1
  /// ratio that reads as isometric.
  final double tileHeight;

  /// Screen height of one storey of extrusion.
  final double levelHeight;

  final Offset origin;

  IsoCamera withOrigin(Offset value) => IsoCamera(
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        levelHeight: levelHeight,
        origin: value,
      );

  /// Projects a grid point to screen space.
  Offset project(double x, double y, [double z = 0]) => Offset(
        (x - y) * (tileWidth / 2) + origin.dx,
        (x + y) * (tileHeight / 2) - z * levelHeight + origin.dy,
      );

  /// The inverse of [project] on the ground plane (z = 0), in continuous grid
  /// coordinates. Because the projection is linear and the plane is fixed,
  /// this is an exact 2x2 solve — no search, no tolerance.
  ({double x, double y}) screenToGround(Offset screen) {
    final a = (screen.dx - origin.dx) / (tileWidth / 2); // == x - y
    final b = (screen.dy - origin.dy) / (tileHeight / 2); // == x + y
    return (x: (a + b) / 2, y: (b - a) / 2);
  }

  /// The tile under [screen], or null if it falls outside a [gridSize] grid.
  ({int x, int y})? tileAt(Offset screen, int gridSize) {
    final ground = screenToGround(screen);
    final x = ground.x.floor();
    final y = ground.y.floor();
    if (x < 0 || y < 0 || x >= gridSize || y >= gridSize) return null;
    return (x: x, y: y);
  }

  /// The four screen corners of tile (x, y) at elevation [z], clockwise from
  /// the north (top) corner.
  List<Offset> tileDiamond(int x, int y, [double z = 0]) => [
        project(x.toDouble(), y.toDouble(), z),
        project(x + 1.0, y.toDouble(), z),
        project(x + 1.0, y + 1.0, z),
        project(x.toDouble(), y + 1.0, z),
      ];

  /// Canvas size needed to hold a [gridSize] grid whose tallest building is
  /// [maxLevels] high, and the origin that centres it in that canvas.
  ///
  /// The grid's screen bounding box runs from -gridSize * tileWidth / 2 to
  /// +gridSize * tileWidth / 2 horizontally, so the origin has to be pushed
  /// right by half the width; vertically it is pushed down by the headroom
  /// the tallest extrusion needs.
  static ({Size size, Offset origin}) layout(
    int gridSize, {
    double tileWidth = 64,
    double tileHeight = 32,
    double levelHeight = 26,
    double maxLevels = 4,
    double padding = 48,
  }) {
    final width = gridSize * tileWidth + padding * 2;
    final headroom = maxLevels * levelHeight;
    final height = gridSize * tileHeight + headroom + padding * 2;
    return (
      size: Size(width, height),
      origin: Offset(width / 2, padding + headroom),
    );
  }

  /// Painter's-algorithm sort key for a footprint whose minimum corner is
  /// (x, y): smaller is further from the camera and must be drawn first.
  ///
  /// Exact for equal-sized footprints, which is everything here except
  /// runways — and those are nearly flat, so the occlusion they lose at their
  /// near end is not visible.
  static int depthKey(int x, int y) => x + y;
}

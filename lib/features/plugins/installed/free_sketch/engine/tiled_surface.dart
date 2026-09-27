import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

/// A canvas-sized bitmap that is edited one tile at a time.
///
/// A live stroke touches a small part of a large canvas every frame.
/// Re-rasterising the whole canvas to add a few dabs would cost a full-size
/// texture per frame; here only the tiles the new dabs overlap are rebuilt,
/// each from its previous content plus the new paint. The surface optionally
/// starts from a [base] image (the layer being smudged); tiles that were
/// never touched keep showing it.
class TiledSurface {
  TiledSurface({
    required this.width,
    required this.height,
    this.base,
    this.tileSize = 256,
  });

  final int width;
  final int height;
  final ui.Image? base;
  final int tileSize;

  final _tiles = <int, ui.Image>{};

  /// Tile images replaced during the current [edit] batch. Kept alive until
  /// the batch ends, because a snapshot taken at its start may still draw
  /// them.
  final _retired = <ui.Image>[];

  int get _columns => (width + tileSize - 1) ~/ tileSize;

  Rect get bounds => Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  bool get isEmpty => base == null && _tiles.isEmpty;

  bool get hasTiles => _tiles.isNotEmpty;

  /// Paints [painter] into every tile [dirty] overlaps. [painter] draws in
  /// surface coordinates and may be called once per tile, so it must be
  /// deterministic and not depend on how often it runs.
  void paintRegion(Rect dirty, void Function(Canvas canvas) painter) {
    final region = dirty.intersect(bounds);
    if (region.isEmpty || region.width <= 0 || region.height <= 0) return;
    final c0 = math.max(0, region.left ~/ tileSize);
    final c1 = math.min(_columns - 1, (region.right - 0.0001) ~/ tileSize);
    final r0 = math.max(0, region.top ~/ tileSize);
    final r1 = math.min((height + tileSize - 1) ~/ tileSize - 1, (region.bottom - 0.0001) ~/ tileSize);
    for (var row = r0; row <= r1; row++) {
      for (var col = c0; col <= c1; col++) {
        _repaintTile(col, row, painter);
      }
    }
  }

  /// Paints [items] tile by tile: each tile is rebuilt once, handed only the
  /// items whose bounds overlap it. Radial symmetry scatters dabs across the
  /// whole canvas, and this keeps the untouched tiles between them untouched.
  void paintItems<T>(
    List<T> items,
    Rect Function(T item) boundsOf,
    void Function(Canvas canvas, List<T> items) painter,
  ) {
    final byTile = <int, List<T>>{};
    final rows = (height + tileSize - 1) ~/ tileSize;
    for (final item in items) {
      final region = boundsOf(item).intersect(bounds);
      if (region.isEmpty || region.width <= 0 || region.height <= 0) continue;
      final c0 = math.max(0, region.left ~/ tileSize);
      final c1 = math.min(_columns - 1, (region.right - 0.0001) ~/ tileSize);
      final r0 = math.max(0, region.top ~/ tileSize);
      final r1 = math.min(rows - 1, (region.bottom - 0.0001) ~/ tileSize);
      for (var row = r0; row <= r1; row++) {
        for (var col = c0; col <= c1; col++) {
          (byTile[row * _columns + col] ??= <T>[]).add(item);
        }
      }
    }
    for (final entry in byTile.entries) {
      final col = entry.key % _columns;
      final row = entry.key ~/ _columns;
      _repaintTile(col, row, (canvas) => painter(canvas, entry.value));
    }
  }

  void _repaintTile(int col, int row, void Function(Canvas canvas) painter) {
    final key = row * _columns + col;
    final left = col * tileSize;
    final top = row * tileSize;
    final w = math.min(tileSize, width - left);
    final h = math.min(tileSize, height - top);
    final tileRect = Rect.fromLTWH(left.toDouble(), top.toDouble(), w.toDouble(), h.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.translate(-left.toDouble(), -top.toDouble());
    canvas.clipRect(tileRect);
    final existing = _tiles[key];
    if (existing != null) {
      canvas.drawImage(existing, tileRect.topLeft, Paint());
    } else if (base != null) {
      canvas.drawImageRect(base!, tileRect, tileRect, Paint());
    }
    painter(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    if (existing != null) _retired.add(existing);
    _tiles[key] = image;
  }

  /// Ends a batch of [paintRegion] calls, releasing the tiles they replaced.
  void endBatch() {
    for (final image in _retired) {
      image.dispose();
    }
    _retired.clear();
  }

  /// Draws the surface at the origin. The base is clipped away under every
  /// tile — a tile already holds the base pixels it started from — and edges
  /// are not antialiased, so neighbouring tiles meet without a seam.
  void draw(Canvas canvas, {FilterQuality quality = FilterQuality.low}) {
    final paint = Paint()
      ..filterQuality = quality
      ..isAntiAlias = false;
    final b = base;
    if (b != null) {
      if (_tiles.isEmpty) {
        canvas.drawImage(b, Offset.zero, paint);
        return;
      }
      final uncovered = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds);
      for (final key in _tiles.keys) {
        uncovered.addRect(_rectOf(key));
      }
      canvas.save();
      canvas.clipPath(uncovered, doAntiAlias: false);
      canvas.drawImage(b, Offset.zero, paint);
      canvas.restore();
    }
    for (final entry in _tiles.entries) {
      final rect = _rectOf(entry.key);
      canvas.drawImage(entry.value, rect.topLeft, paint);
    }
  }

  /// Draws the part of the surface under [src] into [dst].
  void drawRegion(Canvas canvas, Rect src, Rect dst, {Paint? paint}) {
    final p = paint ?? Paint();
    final sx = dst.width / src.width;
    final sy = dst.height / src.height;
    canvas.save();
    canvas.clipRect(dst);
    canvas.translate(dst.left, dst.top);
    canvas.scale(sx, sy);
    canvas.translate(-src.left, -src.top);
    canvas.saveLayer(src, p);
    draw(canvas);
    canvas.restore();
    canvas.restore();
  }

  Rect _rectOf(int key) {
    final col = key % _columns;
    final row = key ~/ _columns;
    final left = col * tileSize;
    final top = row * tileSize;
    return Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      math.min(tileSize, width - left).toDouble(),
      math.min(tileSize, height - top).toDouble(),
    );
  }

  /// The whole surface as one image. Null when nothing was ever drawn.
  ui.Image? flatten() {
    if (isEmpty) return null;
    if (_tiles.isEmpty) return base!.clone();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    draw(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  void dispose() {
    endBatch();
    for (final image in _tiles.values) {
      image.dispose();
    }
    _tiles.clear();
  }
}

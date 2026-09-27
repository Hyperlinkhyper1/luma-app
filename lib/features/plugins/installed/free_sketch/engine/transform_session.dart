import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

/// Moving, scaling, rotating or flipping a layer — or just the selected part
/// of it.
///
/// On begin the pixels are lifted off the layer: [floating] holds what moves,
/// [remainder] what stays behind (null when the whole layer moves). The
/// preview draws both; applying rasterises the same drawing once, with
/// high-quality resampling, so repeated nudges before applying never soften
/// the image.
class TransformSession {
  TransformSession({
    required this.layerId,
    required this.floating,
    required this.remainder,
    required this.width,
    required this.height,
    required this._box,
    this.selection,
  });

  final int layerId;
  final ui.Image floating;
  final ui.Image? remainder;
  final int width;
  final int height;
  final Path? selection;
  Rect _box;

  Offset translation = Offset.zero;
  double scaleX = 1;
  double scaleY = 1;
  double rotation = 0;
  bool flipX = false;
  bool flipY = false;

  /// The untransformed content bounds, in canvas space.
  Rect get box => _box;

  /// Tightens the box once the pixel bounds have been read back.
  set box(Rect value) {
    if (translation == Offset.zero && scaleX == 1 && scaleY == 1 && rotation == 0) {
      _box = value;
    }
  }

  bool get isIdentity =>
      translation == Offset.zero && scaleX == 1 && scaleY == 1 && rotation == 0 && !flipX && !flipY;

  Offset get center => _box.center + translation;

  Float64List get matrix {
    final c = _box.center;
    final m = _Affine.translate(c.dx + translation.dx, c.dy + translation.dy)
        .times(_Affine.rotate(rotation))
        .times(_Affine.scale(flipX ? -scaleX : scaleX, flipY ? -scaleY : scaleY))
        .times(_Affine.translate(-c.dx, -c.dy));
    return m.storage;
  }

  Offset map(Offset p) {
    final c = _box.center;
    var q = p - c;
    q = Offset(q.dx * (flipX ? -scaleX : scaleX), q.dy * (flipY ? -scaleY : scaleY));
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    q = Offset(q.dx * cos - q.dy * sin, q.dx * sin + q.dy * cos);
    return q + c + translation;
  }

  /// Box corners after the transform: top-left, top-right, bottom-right,
  /// bottom-left.
  List<Offset> get corners => [
        map(_box.topLeft),
        map(_box.topRight),
        map(_box.bottomRight),
        map(_box.bottomLeft),
      ];

  void reset() {
    translation = Offset.zero;
    scaleX = 1;
    scaleY = 1;
    rotation = 0;
    flipX = false;
    flipY = false;
  }

  void paint(Canvas canvas, {FilterQuality quality = FilterQuality.medium}) {
    final rest = remainder;
    if (rest != null) canvas.drawImage(rest, Offset.zero, Paint()..filterQuality = quality);
    canvas.save();
    canvas.transform(matrix);
    canvas.drawImage(floating, Offset.zero, Paint()..filterQuality = quality);
    canvas.restore();
  }

  ui.Image commit() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    paint(canvas, quality: FilterQuality.high);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  Path? transformedSelection() => selection?.transform(matrix);

  void dispose() {
    floating.dispose();
    remainder?.dispose();
  }
}

/// A 2D affine transform as a column-major 4×4, the layout Canvas expects.
class _Affine {
  const _Affine(this.a, this.b, this.c, this.d, this.tx, this.ty);

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;

  factory _Affine.translate(double x, double y) => _Affine(1, 0, 0, 1, x, y);
  factory _Affine.scale(double x, double y) => _Affine(x, 0, 0, y, 0, 0);
  factory _Affine.rotate(double r) {
    final cos = math.cos(r);
    final sin = math.sin(r);
    return _Affine(cos, sin, -sin, cos, 0, 0);
  }

  _Affine times(_Affine o) => _Affine(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.tx + c * o.ty + tx,
        b * o.tx + d * o.ty + ty,
      );

  Float64List get storage => Float64List.fromList(<double>[
        a, b, 0, 0, //
        c, d, 0, 0, //
        0, 0, 1, 0, //
        tx, ty, 0, 1, //
      ]);
}

import 'dart:ui' as ui;
import 'dart:ui';

import 'sketch_document.dart';

/// Draws a layer's pixels at the canvas origin, in place of its stored image —
/// how a live stroke or a transform preview is shown before it is committed.
typedef LayerContent = void Function(Canvas canvas);

/// Flattens a [SketchSnapshot] onto a canvas: the screen, an export, a
/// thumbnail and the colour picker all go through here, so what you see is
/// exactly what you save.
class SketchCompositor {
  const SketchCompositor._();

  static void paint(
    Canvas canvas,
    SketchSnapshot state,
    Rect bounds, {
    Map<int, LayerContent> overrides = const {},
    FilterQuality quality = FilterQuality.low,
    bool includeBackground = true,
    Set<int> only = const {},
  }) {
    canvas.saveLayer(bounds, Paint());
    if (includeBackground && state.showBackground) {
      canvas.drawRect(bounds, Paint()..color = state.background);
    }
    final layers = state.layers;
    var i = 0;
    while (i < layers.length) {
      var j = i + 1;
      while (j < layers.length && layers[j].clipped) {
        j++;
      }
      final base = layers[i];
      final clipped = layers.sublist(i + 1, j);
      if (only.isEmpty || only.contains(base.id) || clipped.any((l) => only.contains(l.id))) {
        _group(canvas, bounds, base, clipped, overrides, quality, only);
      }
      i = j;
    }
    canvas.restore();
  }

  static LayerContent? _content(
    SketchLayer layer,
    Map<int, LayerContent> overrides,
    FilterQuality quality,
  ) {
    final override = overrides[layer.id];
    if (override != null) return override;
    final image = layer.image;
    if (image == null) return null;
    return (canvas) => canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
  }

  static Paint _layerPaint(SketchLayer layer, FilterQuality quality) => Paint()
    ..blendMode = layer.blend.mode
    ..color = Color.fromRGBO(0, 0, 0, layer.opacity.clamp(0.0, 1.0))
    ..filterQuality = quality;

  static void _group(
    Canvas canvas,
    Rect bounds,
    SketchLayer base,
    List<SketchLayer> clipped,
    Map<int, LayerContent> overrides,
    FilterQuality quality,
    Set<int> only,
  ) {
    if (!base.visible) return;
    final baseContent = _content(base, overrides, quality);
    if (baseContent == null) return;
    final children = [
      for (final layer in clipped)
        if (layer.visible && (only.isEmpty || only.contains(layer.id)))
          if (_content(layer, overrides, quality) case final content?) (layer, content),
    ];
    final drawBase = only.isEmpty || only.contains(base.id);

    if (children.isEmpty) {
      if (!drawBase) return;
      final image = base.image;
      if (!overrides.containsKey(base.id) && image != null) {
        canvas.drawImage(image, Offset.zero, _layerPaint(base, quality));
      } else {
        canvas.saveLayer(bounds, _layerPaint(base, quality));
        baseContent(canvas);
        canvas.restore();
      }
      return;
    }

    canvas.saveLayer(bounds, _layerPaint(base, quality));
    if (drawBase) baseContent(canvas);
    for (final (layer, content) in children) {
      canvas.saveLayer(bounds, _layerPaint(layer, quality));
      content(canvas);
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
      baseContent(canvas);
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  /// The composite as an image, synchronously and GPU-resident.
  static ui.Image flatten(
    SketchSnapshot state,
    int width,
    int height, {
    bool includeBackground = true,
    Map<int, LayerContent> overrides = const {},
  }) {
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    paint(canvas, state, bounds, includeBackground: includeBackground, overrides: overrides);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  /// A downscaled composite, for library thumbnails.
  static Future<ui.Image> thumbnail(
    SketchSnapshot state,
    int width,
    int height, {
    int maxSide = 480,
  }) {
    final scale = maxSide / (width > height ? width : height);
    final s = scale > 1 ? 1.0 : scale;
    final w = (width * s).round().clamp(1, maxSide);
    final h = (height * s).round().clamp(1, maxSide);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.scale(s);
    paint(canvas, state, bounds, quality: FilterQuality.medium);
    final picture = recorder.endRecording();
    return picture.toImage(w, h).whenComplete(picture.dispose);
  }

  /// The colour at one canvas pixel, composited as shown or from one layer.
  static Future<Color?> sample(
    SketchSnapshot state,
    Offset point, {
    int? layerId,
    bool includeBackground = true,
  }) async {
    final x = point.dx.floorToDouble();
    final y = point.dy.floorToDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1, 1));
    canvas.translate(-x, -y);
    final bounds = Rect.fromLTWH(x, y, 1, 1);
    if (layerId != null) {
      final layer = state.layerById(layerId);
      final image = layer?.image;
      if (image == null) return null;
      canvas.drawImage(image, Offset.zero, Paint());
    } else {
      paint(canvas, state, bounds, includeBackground: includeBackground);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) return null;
      final a = data.getUint8(3);
      if (a == 0) return null;
      return Color.fromARGB(a, data.getUint8(0), data.getUint8(1), data.getUint8(2));
    } finally {
      image.dispose();
    }
  }
}

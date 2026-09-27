import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import '../model/brush.dart';
import 'brush_textures.dart';
import 'dab_renderer.dart';
import 'sketch_document.dart';
import 'stroke_engine.dart';
import 'symmetry.dart';
import 'tiled_surface.dart';

enum StrokeMode { paint, erase, smudge, blur }

/// One stroke in progress, from pen-down to commit.
///
/// Paint and erase strokes accumulate their dabs in a separate buffer and
/// only meet the layer when it is drawn — with the brush's opacity as a cap,
/// its blend mode, and the paper grain pressed through. That is what lets a
/// low-flow brush build up inside a stroke without ever passing the stroke's
/// opacity, and it is the same code that produces the committed pixels, so
/// what shows while drawing is what lands.
///
/// Smudge and blur have to read the layer, so they work on a tiled copy of
/// it instead.
class StrokeSession {
  StrokeSession({
    required this.layer,
    required this.width,
    required this.height,
    required this.brush,
    required this.mode,
    required Color color,
    required this.renderer,
    this.symmetry = const SymmetrySettings(),
    this.selection,
    double pressureGamma = 1,
    int? seed,
  })  : engine = StrokeEngine(
          brush: brush,
          color: color,
          pressureGamma: pressureGamma,
          seed: seed,
        ),
        surface = TiledSurface(
          width: width,
          height: height,
          base: mode == StrokeMode.smudge || mode == StrokeMode.blur ? layer.image : null,
        );

  final SketchLayer layer;
  final int width;
  final int height;
  final BrushPreset brush;
  final StrokeMode mode;
  final DabRenderer renderer;
  final SymmetrySettings symmetry;
  final Path? selection;
  final StrokeEngine engine;
  final TiledSurface surface;

  final _pending = <Dab>[];
  ui.Image? _carry;
  bool _finished = false;
  bool _touched = false;

  Size get _size => Size(width.toDouble(), height.toDouble());
  Rect get bounds => Offset.zero & _size;

  bool get needsFlush => _pending.isNotEmpty;

  /// Whether any dab has landed — a stroke that never did is dropped rather
  /// than recorded as an empty undo step.
  bool get touched => _touched || _pending.isNotEmpty || engine.provisional.isNotEmpty;

  void add(StrokeInput input) => _queue(engine.add(input));

  void dwell(double seconds) => _queue(engine.dwell(seconds));

  void finish() {
    if (_finished) return;
    _finished = true;
    _queue(engine.finish());
    flush();
  }

  void _queue(List<Dab> dabs) {
    if (dabs.isEmpty) return;
    _pending.addAll(symmetry.expand(dabs, _size));
  }

  List<Dab> get _provisional =>
      mode == StrokeMode.paint || mode == StrokeMode.erase
          ? symmetry.expand(engine.provisional, _size)
          : const [];

  /// Rasterises everything queued since the last flush. Called once per
  /// frame, not once per pointer event.
  void flush() {
    if (_pending.isEmpty) return;
    final dabs = List<Dab>.of(_pending);
    _pending.clear();
    _touched = true;
    switch (mode) {
      case StrokeMode.paint:
      case StrokeMode.erase:
        surface.paintItems<Dab>(dabs, (dab) => dab.bounds, (canvas, items) {
          renderer.paintAll(canvas, items, brush);
        });
      case StrokeMode.smudge:
        _smudge(dabs);
      case StrokeMode.blur:
        _blur(dabs);
    }
    surface.endBatch();
  }

  BlendMode get _strokeBlend {
    if (mode == StrokeMode.erase) return BlendMode.dstOut;
    if (layer.alphaLocked) return BlendMode.srcATop;
    return switch (brush.strokeBlend) {
      StrokeBlend.normal => BlendMode.srcOver,
      StrokeBlend.multiply => BlendMode.multiply,
      StrokeBlend.glow => BlendMode.plus,
    };
  }

  /// Draws the layer as it looks with this stroke applied, at the origin.
  void paintLayer(Canvas canvas, {FilterQuality quality = FilterQuality.low}) {
    if (mode == StrokeMode.smudge || mode == StrokeMode.blur) {
      surface.draw(canvas, quality: quality);
      return;
    }
    final image = layer.image;
    if (image != null) {
      canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
    }
    canvas.save();
    final clip = selection;
    if (clip != null) canvas.clipPath(clip);
    canvas.saveLayer(
      bounds,
      Paint()
        ..blendMode = _strokeBlend
        ..color = Color.fromRGBO(0, 0, 0, brush.opacity.clamp(0.0, 1.0)),
    );
    final wet = mode == StrokeMode.paint ? brush.wetEdges.clamp(0.0, 1.0) : 0.0;
    if (wet > 0) {
      _wetStroke(canvas, quality, wet);
    } else {
      _strokeContent(canvas, quality);
    }
    _grain(canvas);
    canvas.restore();
    canvas.restore();
  }

  void _strokeContent(Canvas canvas, FilterQuality quality) {
    surface.draw(canvas, quality: quality);
    renderer.paintAll(canvas, _provisional, brush);
  }

  /// Watercolour edge darkening, at the level of the whole stroke rather
  /// than each dab — per-dab rings read as a string of bubbles.
  ///
  /// The stroke is drawn twice: a lighter body, then an edge layer made of
  /// the stroke minus a blurred, alpha-boosted copy of itself. Deep inside
  /// the wash the blurred copy is as dense as the stroke and cancels it; at
  /// the outline it is thinner, so the stroke survives there and pools.
  void _wetStroke(Canvas canvas, FilterQuality quality, double wet) {
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - 0.5 * wet));
    _strokeContent(canvas, quality);
    canvas.restore();

    final sigma = math.max(1.5, brush.size * 0.1);
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, wet));
    _strokeContent(canvas, quality);
    canvas.saveLayer(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..imageFilter = ui.ImageFilter.compose(
          outer: const ColorFilter.matrix(<double>[
            1, 0, 0, 0, 0, //
            0, 1, 0, 0, 0, //
            0, 0, 1, 0, 0, //
            0, 0, 0, 1.15, 0, //
          ]),
          inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        ),
    );
    _strokeContent(canvas, quality);
    canvas.restore();
    canvas.restore();
  }

  void _grain(Canvas canvas) {
    if (brush.grain == BrushGrain.none || brush.grainStrength <= 0) return;
    final texture = renderer.textures.grain(brush.grain);
    if (texture == null) return;
    final scale = BrushTextures.grainScale(brush.grain);
    final matrix = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[15] = 1;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ImageShader(texture, TileMode.repeated, TileMode.repeated, matrix)
        ..blendMode = BlendMode.dstOut
        ..color = Color.fromRGBO(0, 0, 0, brush.grainStrength.clamp(0.0, 1.0)),
    );
  }

  /// The layer's new pixels. Only valid after [finish].
  ui.Image? commit() {
    assert(_finished, 'commit() before finish()');
    if (mode == StrokeMode.smudge || mode == StrokeMode.blur) {
      return surface.flatten();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    paintLayer(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  // -------------------------------------------------------------- smudge

  /// Each dab lays down the paint it is carrying, then picks up a little of
  /// what is under it. Pick-ups read the surface as it was at the start of
  /// this frame; within one frame the carried paint already holds what the
  /// previous dab deposited, so the difference does not show.
  void _smudge(List<Dab> dabs) {
    final persistence = brush.strength.clamp(0.05, 0.98);
    final deposits = <(Dab, ui.Image, Rect)>[];
    for (final dab in dabs) {
      final rect = _dabRect(dab);
      final picked = _capture(rect);
      final carry = _carry;
      if (carry == null) {
        _carry = picked;
        continue;
      }
      deposits.add((dab, carry, rect));
      _carry = _mix(carry, picked, rect, persistence);
      picked.dispose();
    }
    if (deposits.isEmpty) return;
    final amount = 0.5 + 0.5 * persistence;
    _deposit(deposits, amount, replace: false);
    for (final (_, image, _) in deposits) {
      image.dispose();
    }
  }

  void _blur(List<Dab> dabs) {
    final deposits = <(Dab, ui.Image, Rect)>[];
    for (final dab in dabs) {
      final rect = _dabRect(dab);
      final sigma = math.max(0.6, dab.size * 0.08);
      deposits.add((dab, _capture(rect, blurSigma: sigma), rect));
    }
    _deposit(deposits, brush.strength.clamp(0.05, 1.0), replace: true);
    for (final (_, image, _) in deposits) {
      image.dispose();
    }
  }

  /// Lays each dab's image down through the tip, weighted by
  /// `tip alpha × amount`.
  ///
  /// With [replace] the old pixels are first faded by that weight
  /// (`dstOut`) and the image added back at the same weight (`plus`) — a true
  /// blend, which blur needs so a soft edge can actually lose alpha. Without
  /// it the image goes on with `srcOver`, which never lowers alpha: smudge
  /// starting on empty canvas then picks paint up as it goes rather than
  /// dragging a trail of transparency through everything it touches.
  ///
  /// The tip is drawn into the layer first and the image masked to it with
  /// `srcIn`; masking the other way round (`dstIn` with the tip) leaves the
  /// image's corners outside the tip untouched.
  void _deposit(List<(Dab, ui.Image, Rect)> deposits, double amount, {required bool replace}) {
    surface.paintItems<(Dab, ui.Image, Rect)>(deposits, (d) => d.$3, (canvas, items) {
      final clip = selection;
      if (clip != null) {
        canvas.save();
        canvas.clipPath(clip);
      }
      for (final (dab, image, rect) in items) {
        final m = (dab.alpha * amount).clamp(0.0, 1.0);
        if (m <= 0) continue;
        if (replace) renderer.mask(canvas, dab, brush, m, BlendMode.dstOut);
        canvas.saveLayer(rect, Paint()..blendMode = replace ? BlendMode.plus : BlendMode.srcOver);
        renderer.mask(canvas, dab, brush, m, BlendMode.srcOver);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          rect,
          Paint()
            ..blendMode = BlendMode.srcIn
            ..filterQuality = FilterQuality.low,
        );
        canvas.restore();
      }
      if (clip != null) canvas.restore();
    });
  }

  Rect _dabRect(Dab dab) {
    final side = math.max(2.0, dab.size.ceilToDouble() + 2);
    return Rect.fromCenter(center: dab.center, width: side, height: side);
  }

  ui.Image _capture(Rect rect, {double? blurSigma}) {
    final w = math.max(1, rect.width.round());
    final h = math.max(1, rect.height.round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.translate(-rect.left, -rect.top);
    if (blurSigma != null) {
      canvas.saveLayer(
        rect.inflate(blurSigma * 3),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      );
      surface.draw(canvas);
      canvas.restore();
    } else {
      surface.draw(canvas);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  /// `carry × persistence + picked × (1 − persistence)`, premultiplied, so
  /// transparency is carried along like any colour.
  ui.Image _mix(ui.Image carry, ui.Image picked, Rect rect, double persistence) {
    final w = picked.width;
    final h = picked.height;
    final dst = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, dst);
    canvas.drawImageRect(
      carry,
      Rect.fromLTWH(0, 0, carry.width.toDouble(), carry.height.toDouble()),
      dst,
      Paint()..color = Color.fromRGBO(0, 0, 0, persistence),
    );
    canvas.drawImage(
      picked,
      Offset.zero,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Color.fromRGBO(0, 0, 0, 1 - persistence),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  void dispose() {
    _carry?.dispose();
    _carry = null;
    surface.dispose();
  }
}

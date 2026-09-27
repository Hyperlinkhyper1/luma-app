import 'dart:async';
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

enum StrokeMode { paint, erase, smudge, blur }

/// A smudge or blur dab: where it lands, and where it takes its pixels from.
class _Op {
  const _Op(this.dab, this.source);
  final Dab dab;
  final Offset source;
}

/// One stroke in progress, from pen-down to commit.
///
/// Paint and erase strokes accumulate their dabs in a buffer of their own and
/// only meet the layer when drawn — with the brush's opacity as a cap, its
/// blend mode and the paper grain. That lets a low-flow brush build up inside
/// a stroke without passing the stroke's opacity, and it is the same code
/// that produces the committed pixels, so what shows while drawing lands.
///
/// **Why nothing here uses `toImageSync`.** On the Skia renderer (Windows) a
/// `toImageSync` image keeps the whole recording it was made from alive for
/// as long as it lives — including every image drawn into that recording.
/// Re-rendering a buffer from last frame's buffer every frame therefore
/// builds a chain in which no frame's texture is ever freed, and GPU memory
/// grows until the engine crashes. Instead the stroke is kept as a list of
/// dabs drawn as vectors, and every so often the list is flattened into
/// [_baked] with the asynchronous `Picture.toImage`, whose result references
/// nothing. Smudge and blur read only from [_baked] for the same reason.
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
        _base = layer.image?.clone() {
    if (_readsLayer) _baked = _base?.clone();
  }

  final SketchLayer layer;
  final int width;
  final int height;
  final BrushPreset brush;
  final StrokeMode mode;
  final DabRenderer renderer;
  final SymmetrySettings symmetry;
  final Path? selection;
  final StrokeEngine engine;

  /// This session's own handle on the layer's pixels, so the document can
  /// swap or release its copy while the stroke is still going.
  final ui.Image? _base;

  /// Everything flattened so far: the stroke buffer for paint and erase, the
  /// working copy of the layer for smudge and blur.
  ui.Image? _baked;

  final _dabs = <Dab>[];
  final _ops = <_Op>[];
  final _trail = <Dab>[];
  Future<void>? _bake;
  DateTime _lastBake = DateTime.now();
  bool _finished = false;
  bool _disposed = false;
  bool _touched = false;

  bool get _readsLayer => mode == StrokeMode.smudge || mode == StrokeMode.blur;

  Size get _size => Size(width.toDouble(), height.toDouble());
  Rect get bounds => Offset.zero & _size;

  bool get needsFlush => _dabs.isNotEmpty || _ops.isNotEmpty;

  /// Whether any dab has landed — a stroke that never did is dropped rather
  /// than recorded as an empty undo step.
  bool get touched => _touched || _dabs.isNotEmpty || _ops.isNotEmpty || engine.provisional.isNotEmpty;

  /// Completes once no flatten is in flight; for tests.
  Future<void> get settled => _bake ?? Future<void>.value();

  void add(StrokeInput input) => _queue(engine.add(input));

  void dwell(double seconds) => _queue(engine.dwell(seconds));

  void finish() {
    if (_finished) return;
    _queue(engine.finish());
    _finished = true;
  }

  void _queue(List<Dab> dabs) {
    if (dabs.isEmpty) return;
    _touched = true;
    final expanded = symmetry.expand(dabs, _size);
    if (!_readsLayer) {
      _dabs.addAll(expanded);
      return;
    }
    // Each smudge dab copies what sat half a brush behind it; symmetric
    // copies take their source through the same mirror.
    for (final dab in dabs) {
      _trail.add(dab);
      final lag = dab.size * 0.5;
      var source = _trail.first.center;
      for (var i = _trail.length - 1; i >= 0; i--) {
        if (dab.distance - _trail[i].distance >= lag) {
          source = _trail[i].center;
          break;
        }
      }
      while (_trail.length > 2 && dab.distance - _trail[1].distance > lag) {
        _trail.removeAt(0);
      }
      // expand() emits copies in a fixed order, so expanding the source
      // point the same way pairs every copy with its mirrored source.
      final copies = symmetry.expand([dab], _size);
      final sources = symmetry.expand([dab.copyWith(center: source)], _size);
      for (var i = 0; i < copies.length; i++) {
        _ops.add(_Op(copies[i], sources[i].center));
      }
    }
  }

  List<Dab> get _provisional => _readsLayer ? const [] : symmetry.expand(engine.provisional, _size);

  /// Called once per frame. Starts a flatten when enough has piled up and
  /// none is already running.
  void flush() {
    if (_disposed || _bake != null) return;
    final pending = _readsLayer ? _ops.length : _dabs.length;
    if (pending == 0) return;
    final age = DateTime.now().difference(_lastBake).inMilliseconds;
    // Smudge reads from the flattened copy, so it wants a fresh one every
    // frame; paint only needs flattening to keep per-frame drawing cheap.
    if (!_readsLayer && pending < 160 && age < 200) return;
    _startBake();
  }

  void _startBake() {
    final count = _readsLayer ? _ops.length : _dabs.length;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    _drawBuffer(canvas, count);
    final picture = recorder.endRecording();
    _lastBake = DateTime.now();
    _bake = picture.toImage(width, height).then((image) {
      picture.dispose();
      if (_disposed) {
        image.dispose();
        return;
      }
      final old = _baked;
      _baked = image;
      old?.dispose();
      if (_readsLayer) {
        _ops.removeRange(0, count);
      } else {
        _dabs.removeRange(0, count);
      }
    }).whenComplete(() {
      _bake = null;
    });
  }

  /// The flattened buffer plus the first [count] pending dabs (all of them
  /// when null).
  void _drawBuffer(Canvas canvas, [int? count, FilterQuality quality = FilterQuality.low]) {
    final baked = _baked;
    if (baked != null) canvas.drawImage(baked, Offset.zero, Paint()..filterQuality = quality);
    if (_readsLayer) {
      final ops = count == null ? _ops : _ops.take(count);
      if (baked == null) return;
      final clip = selection;
      if (clip != null) {
        canvas.save();
        canvas.clipPath(clip);
      }
      for (final op in ops) {
        mode == StrokeMode.smudge ? _smudgeOp(canvas, op, baked) : _blurOp(canvas, op, baked);
      }
      if (clip != null) canvas.restore();
    } else {
      renderer.paintAll(canvas, count == null ? _dabs : _dabs.take(count), brush);
    }
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
    if (_readsLayer) {
      if (_baked == null) {
        final base = _base;
        if (base != null) canvas.drawImage(base, Offset.zero, Paint()..filterQuality = quality);
        return;
      }
      _drawBuffer(canvas, null, quality);
      return;
    }
    final base = _base;
    if (base != null) {
      canvas.drawImage(base, Offset.zero, Paint()..filterQuality = quality);
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
    _drawBuffer(canvas, null, quality);
    renderer.paintAll(canvas, _provisional, brush);
  }

  /// Watercolour edge darkening, at the level of the whole stroke rather
  /// than each dab — per-dab rings read as a string of bubbles.
  ///
  /// The stroke is drawn twice: a lighter body, then an edge layer made of
  /// the stroke minus a blurred copy of itself. Deep inside the wash the
  /// blurred copy is as dense as the stroke and cancels it; at the outline it
  /// is thinner, so the stroke survives there and pools.
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
  ///
  /// This one does use `toImageSync` — the document needs the pixels now —
  /// but what it records only references [_baked] and the layer, both plain
  /// images, and the document flattens the result again in the background.
  ui.Image? commit() {
    assert(_finished, 'commit() before finish()');
    if (_readsLayer && _baked == null) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    paintLayer(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  // ------------------------------------------------------------ smudge, blur

  Rect _dabRect(Dab dab) {
    final side = math.max(2.0, dab.size.ceilToDouble() + 2);
    return Rect.fromCenter(center: dab.center, width: side, height: side);
  }

  /// Per-dab deposit. About `1 / spacing` dabs overlap any one spot, and each
  /// reads the same flattened copy, so the per-dab share is chosen for the
  /// overlaps to add up to the intended total rather than to near-opaque —
  /// otherwise the first colour touched is dragged the whole stroke long.
  double get _amount {
    final total = mode == StrokeMode.smudge
        ? 0.3 + 0.45 * brush.strength.clamp(0.05, 0.98)
        : brush.strength.clamp(0.05, 1.0);
    final overlaps = brush.spacing.clamp(0.02, 1.0);
    return 1 - math.pow(1 - total.clamp(0.0, 0.99), overlaps).toDouble();
  }

  /// Paint from half a brush behind is laid over this spot through the tip.
  /// `srcOver`, never a replace: dragging from empty canvas into paint
  /// should pick paint up, not smear transparency through it.
  void _smudgeOp(Canvas canvas, _Op op, ui.Image source) {
    final dab = op.dab;
    final m = (dab.alpha * _amount).clamp(0.0, 1.0);
    if (m <= 0) return;
    final rect = _dabRect(dab);
    final from = rect.shift(op.source - dab.center);
    canvas.saveLayer(rect, Paint());
    renderer.mask(canvas, dab, brush, m, BlendMode.srcOver);
    canvas.drawImageRect(
      source,
      from,
      rect,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  /// A true blend towards the blurred pixels (fade the old by the tip, then
  /// add the blurred at the same weight), so a soft edge can actually lose
  /// alpha instead of only ever gaining it.
  void _blurOp(Canvas canvas, _Op op, ui.Image source) {
    final dab = op.dab;
    final m = (dab.alpha * _amount).clamp(0.0, 1.0);
    if (m <= 0) return;
    final rect = _dabRect(dab);
    final sigma = math.max(0.6, dab.size * 0.08);
    renderer.mask(canvas, dab, brush, m, BlendMode.dstOut);
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.plus);
    renderer.mask(canvas, dab, brush, m, BlendMode.srcOver);
    canvas.saveLayer(
      rect.inflate(sigma * 3),
      Paint()
        ..blendMode = BlendMode.srcIn
        ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    canvas.drawImage(source, Offset.zero, Paint());
    canvas.restore();
    canvas.restore();
  }

  void dispose() {
    _disposed = true;
    _baked?.dispose();
    _baked = null;
    _base?.dispose();
  }
}

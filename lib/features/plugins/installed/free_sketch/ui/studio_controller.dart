import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../../l10n/current_l.dart';
import '../engine/adjustments.dart';
import '../engine/brush_textures.dart';
import '../engine/compositor.dart';
import '../engine/dab_renderer.dart';
import '../engine/flood_fill.dart';
import '../engine/sketch_document.dart';
import '../engine/stroke_engine.dart';
import '../engine/stroke_session.dart';
import '../engine/symmetry.dart';
import '../engine/transform_session.dart';
import '../free_sketch_repository.dart';
import '../io/sketch_export.dart';
import '../model/brush.dart';
import '../model/sketch_limits.dart';
import '../model/sketch_meta.dart';
import '../model/sketch_tool.dart';
import 'sketch_view.dart';

/// Repaints only the canvas: a stroke in progress ticks this every frame,
/// and nothing else listens to it.
class _Pulse extends ChangeNotifier {
  void pulse() => notifyListeners();
}

/// Everything the studio does, independent of any widget.
///
/// The canvas turns pointer events into calls here; the panels read and set
/// state here; the document and its history live in [document]. Autosave
/// watches the document's revision and writes changed layers a few seconds
/// after the artist stops.
class StudioController extends ChangeNotifier {
  StudioController._({
    required this.repository,
    required SketchMeta meta,
    required this.document,
    required this.textures,
    required Map<String, Object?> prefs,
  })  : _meta = meta,
        renderer = DabRenderer(textures),
        view = SketchView(document.size) {
    _readPrefs(prefs);
    for (final layer in document.state.layers) {
      _savedImages[layer.id] = layer.image;
      _savedFiles[layer.id] = meta.layers.where((l) => l.id == layer.id).firstOrNull?.file;
    }
    _savedRevision = document.revision;
    document.addListener(_onDocumentChanged);
    document.onImageReplaced = (old, fresh) {
      for (final entry in _savedImages.entries.toList()) {
        if (identical(entry.value, old)) _savedImages[entry.key] = fresh;
      }
    };
  }

  static Future<StudioController> open(FreeSketchRepository repository, String id) async {
    final stored = await repository.load(id);
    final textures = await BrushTextures.load();
    final prefs = await repository.loadPrefs();
    final meta = stored.meta;
    final layers = <SketchLayer>[];
    for (final layerMeta in meta.layers) {
      final bytes = stored.layers[layerMeta.id];
      layers.add(SketchLayer(
        id: layerMeta.id,
        name: layerMeta.name,
        image: bytes == null ? null : await decodeToCanvas(bytes, meta.width, meta.height),
        opacity: layerMeta.opacity,
        blend: layerMeta.blend,
        visible: layerMeta.visible,
        locked: layerMeta.locked,
        alphaLocked: layerMeta.alphaLocked,
        clipped: layerMeta.clipped,
      ));
    }
    if (layers.isEmpty) layers.add(SketchLayer(id: 1, name: currentL.freeSketchStudioDefaultLayerName(1)));
    final activeId = layers.any((l) => l.id == meta.activeLayerId) ? meta.activeLayerId! : layers.last.id;
    final document = SketchDocument(
      width: meta.width,
      height: meta.height,
      memoryBudget: SketchLimits.historyBytes,
      baker: bake,
      initial: SketchSnapshot(
        layers: layers,
        activeLayerId: activeId,
        background: Color(meta.background),
        showBackground: meta.showBackground,
      ),
    );
    return StudioController._(
      repository: repository,
      meta: meta,
      document: document,
      textures: textures,
      prefs: prefs,
    );
  }

  /// A standalone copy of [image]: rendered through the asynchronous
  /// `Picture.toImage`, whose result — unlike a `toImageSync` image — keeps
  /// no reference to what it was drawn from. See [SketchDocument].
  static Future<ui.Image> bake(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(image.width, image.height);
    } finally {
      picture.dispose();
    }
  }

  /// The pixel size of an encoded image, read from its header.
  static Future<ui.Size> imageSize(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  /// Decodes an image file into a canvas-sized image. A layer file is already
  /// canvas-sized; anything else is scaled down to fit and centred.
  static Future<ui.Image> decodeToCanvas(Uint8List bytes, int width, int height, {bool fit = true}) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    if (image.width == width && image.height == height) return image;
    final scale = fit ? math.min(1.0, math.min(width / image.width, height / image.height)) : 1.0;
    final w = image.width * scale;
    final h = image.height * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH((width - w) / 2, (height - h) / 2, w, h),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final out = picture.toImageSync(width, height);
    picture.dispose();
    image.dispose();
    return out;
  }

  final FreeSketchRepository repository;
  final SketchDocument document;
  final BrushTextures textures;
  final DabRenderer renderer;
  final SketchView view;
  final _live = _Pulse();

  /// Shown to the artist as a snackbar.
  void Function(String message)? onMessage;

  SketchMeta _meta;
  SketchMeta get meta => _meta;
  String get title => _meta.title;
  int get width => document.width;
  int get height => document.height;
  SketchSnapshot get state => document.state;
  Listenable get live => _live;
  Rect get bounds => document.bounds;

  bool _disposed = false;

  // ------------------------------------------------------------------ tools

  SketchTool _tool = SketchTool.brush;
  SketchTool get tool => _tool;

  final _brushIds = <SketchTool, String>{
    SketchTool.brush: BrushLibrary.defaultBrush,
    SketchTool.eraser: BrushLibrary.defaultEraser,
    SketchTool.smudge: BrushLibrary.defaultSmudge,
  };
  final _overrides = <String, Map<String, double>>{};

  void setTool(SketchTool tool) {
    if (tool == _tool) return;
    if (_transform != null) applyTransform();
    cancelDrafts();
    _tool = tool;
    notifyListeners();
    if (tool == SketchTool.transform) beginTransform();
  }

  /// The tool whose brush the brush panel is editing.
  SketchTool get brushTool => _tool.usesBrush ? _tool : SketchTool.brush;

  BrushPreset brushFor(SketchTool tool) {
    final id = _brushIds[tool.usesBrush ? tool : SketchTool.brush]!;
    return BrushLibrary.byId(id).withOverrides(_overrides[id]);
  }

  BrushPreset get brush => brushFor(brushTool);

  /// A library brush with the artist's saved tweaks applied.
  BrushPreset effectiveBrush(String id) => BrushLibrary.byId(id).withOverrides(_overrides[id]);

  void selectBrush(String id) {
    _brushIds[brushTool] = id;
    _prefsChanged();
    notifyListeners();
  }

  bool hasOverrides(String id) => _overrides[id]?.isNotEmpty ?? false;

  void setBrushParam(BrushParam param, double value) {
    final id = brush.id;
    final base = BrushLibrary.byId(id);
    final clamped = value.clamp(param.min, param == BrushParam.size ? base.maxSize : param.max).toDouble();
    final map = _overrides.putIfAbsent(id, () => {});
    if ((base.get(param) - clamped).abs() < 1e-6) {
      map.remove(param.name);
    } else {
      map[param.name] = clamped;
    }
    _prefsChanged();
    notifyListeners();
  }

  void resetBrush() {
    _overrides.remove(brush.id);
    _prefsChanged();
    notifyListeners();
  }

  /// `[` and `]`: size steps that feel even at 2 px and at 400 px.
  void nudgeSize(int direction) {
    final size = brush.size;
    final step = math.max(0.5, size * 0.12);
    setBrushParam(BrushParam.size, size + step * direction);
  }

  // ----------------------------------------------------------------- colour

  Color _color = const Color(0xFF2B2440);
  Color _secondary = const Color(0xFFFFFFFF);
  final _recent = <Color>[];
  final _palette = <Color>[];

  Color get color => _color;
  Color get secondary => _secondary;
  List<Color> get recentColors => List.unmodifiable(_recent);
  List<Color> get palette => List.unmodifiable(_palette);

  void setColor(Color color) {
    final opaque = color.withValues(alpha: 1);
    if (opaque == _color) return;
    _color = opaque;
    _prefsChanged();
    notifyListeners();
  }

  void swapColors() {
    final c = _color;
    _color = _secondary;
    _secondary = c;
    _prefsChanged();
    notifyListeners();
  }

  void _remember(Color color) {
    _recent.removeWhere((c) => c.toARGB32() == color.toARGB32());
    _recent.insert(0, color);
    if (_recent.length > 16) _recent.removeRange(16, _recent.length);
    _prefsChanged();
  }

  void addToPalette(Color color) {
    if (_palette.any((c) => c.toARGB32() == color.toARGB32())) return;
    _palette.add(color);
    _prefsChanged();
    notifyListeners();
  }

  void removeFromPalette(Color color) {
    _palette.removeWhere((c) => c.toARGB32() == color.toARGB32());
    _prefsChanged();
    notifyListeners();
  }

  // ---------------------------------------------------------------- options

  double _pressureGamma = 1;
  bool _stylusOnly = false;
  SymmetrySettings _symmetry = const SymmetrySettings();
  double fillTolerance = 0.12;
  bool fillAllLayers = true;
  int fillGrow = 1;
  ShapeKind shapeKind = ShapeKind.line;
  bool shapeFill = false;
  int polygonSides = 5;
  SelectionShape selectionShape = SelectionShape.lasso;
  SelectionCombine selectionCombine = SelectionCombine.replace;
  GradientKind gradientKind = GradientKind.linear;
  bool gradientToSecondary = false;
  bool eyedropperAllLayers = true;
  bool uniformScale = true;

  double get pressureGamma => _pressureGamma;
  bool get stylusOnly => _stylusOnly;
  SymmetrySettings get symmetry => _symmetry;

  set pressureGamma(double value) {
    _pressureGamma = value.clamp(0.25, 4.0);
    _prefsChanged();
    notifyListeners();
  }

  set stylusOnly(bool value) {
    _stylusOnly = value;
    _prefsChanged();
    notifyListeners();
  }

  set symmetry(SymmetrySettings value) {
    _symmetry = value;
    _prefsChanged();
    notifyListeners();
    _live.pulse();
  }

  /// Rebuilds panels after a plain field above was changed.
  void touch() {
    _prefsChanged();
    notifyListeners();
  }

  // ------------------------------------------------------------ live stroke

  StrokeSession? _stroke;
  bool get stroking => _stroke != null;
  Offset? _lastStrokeEnd;
  Offset? get lastStrokeEnd => _lastStrokeEnd;

  bool _editable(SketchLayer layer) {
    if (layer.locked) {
      onMessage?.call(currentL.freeSketchLayerLocked(layer.name));
      return false;
    }
    if (!layer.visible) {
      onMessage?.call(currentL.freeSketchLayerHidden(layer.name));
      return false;
    }
    return true;
  }

  StrokeMode _modeFor(SketchTool tool, BrushPreset brush) {
    if (tool == SketchTool.eraser) return StrokeMode.erase;
    if (tool == SketchTool.smudge) {
      return brush.engine == BrushEngine.blur ? StrokeMode.blur : StrokeMode.smudge;
    }
    return switch (brush.engine) {
      BrushEngine.paint => StrokeMode.paint,
      BrushEngine.smudge => StrokeMode.smudge,
      BrushEngine.blur => StrokeMode.blur,
    };
  }

  /// Starts a stroke with the current brush tool, or with the eraser when
  /// the stylus is flipped over. Returns false if the layer refuses it.
  bool beginStroke(Offset point, double pressure, {bool eraser = false}) {
    final layer = state.active;
    if (!_editable(layer)) return false;
    final tool = eraser ? SketchTool.eraser : brushTool;
    final b = brushFor(tool);
    _stroke = StrokeSession(
      layer: layer,
      width: width,
      height: height,
      brush: b,
      mode: _modeFor(tool, b),
      color: _color,
      renderer: renderer,
      symmetry: _symmetry,
      selection: state.selection,
      pressureGamma: _pressureGamma,
    )..add(StrokeInput(point, pressure: pressure));
    _live.pulse();
    return true;
  }

  void strokeTo(Offset point, double pressure) {
    _stroke?.add(StrokeInput(point, pressure: pressure));
  }

  /// Once per frame while a stroke is live: airbrush build-up, then
  /// rasterising what arrived since the last frame.
  void tick(double seconds, {required bool stationary}) {
    final stroke = _stroke;
    if (stroke == null) return;
    if (stationary) stroke.dwell(seconds);
    stroke.flush();
    _live.pulse();
  }

  void endStroke() {
    final stroke = _stroke;
    if (stroke == null) return;
    _stroke = null;
    stroke.finish();
    _lastStrokeEnd = stroke.engine.head;
    if (!stroke.touched) {
      stroke.dispose();
      _live.pulse();
      return;
    }
    final image = stroke.commit();
    final label = switch (stroke.mode) {
      StrokeMode.paint => stroke.brush.name,
      StrokeMode.erase => currentL.freeSketchStrokeModeErase,
      StrokeMode.smudge => currentL.freeSketchStrokeModeSmudge,
      StrokeMode.blur => currentL.freeSketchStrokeModeBlur,
    };
    stroke.dispose();
    if (image == null) {
      _live.pulse();
      return;
    }
    final layer = state.layerById(stroke.layer.id);
    if (layer == null) {
      image.dispose();
      return;
    }
    document.commit(state.replaceLayer(layer.copyWith(image: image)), label);
    if (stroke.mode == StrokeMode.paint) _remember(_color);
  }

  void cancelStroke() {
    _stroke?.dispose();
    _stroke = null;
    _live.pulse();
  }

  /// Shift-click: a straight stroke from the end of the last one.
  void strokeLine(Offset from, Offset to, double pressure) {
    if (!beginStroke(from, pressure)) return;
    final distance = (to - from).distance;
    final steps = math.max(1, (distance / 2).ceil());
    for (var i = 1; i <= steps; i++) {
      strokeTo(Offset.lerp(from, to, i / steps)!, pressure);
    }
    endStroke();
  }

  // ----------------------------------------------------------------- shapes

  Offset? _shapeStart;
  Offset? _shapeEnd;
  bool _shapeConstrain = false;

  void shapeBegin(Offset point) {
    _shapeStart = point;
    _shapeEnd = point;
    _live.pulse();
  }

  void shapeUpdate(Offset point, {bool constrain = false}) {
    _shapeEnd = point;
    _shapeConstrain = constrain;
    _live.pulse();
  }

  Path? get shapePreview {
    final a = _shapeStart;
    final b = _shapeEnd;
    if (a == null || b == null || (a - b).distance < 1) return null;
    return shapePath(shapeKind, a, b, constrain: _shapeConstrain, sides: polygonSides);
  }

  static Path shapePath(ShapeKind kind, Offset a, Offset b, {bool constrain = false, int sides = 5}) {
    var end = b;
    if (constrain) {
      final d = b - a;
      if (kind == ShapeKind.line) {
        const step = math.pi / 12;
        final angle = (d.direction / step).round() * step;
        end = a + Offset.fromDirection(angle, d.distance);
      } else {
        final side = math.max(d.dx.abs(), d.dy.abs());
        end = a + Offset(side * d.dx.sign, side * d.dy.sign);
      }
    }
    final rect = Rect.fromPoints(a, end);
    switch (kind) {
      case ShapeKind.line:
        return Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(end.dx, end.dy);
      case ShapeKind.rectangle:
        return Path()..addRect(rect);
      case ShapeKind.ellipse:
        return Path()..addOval(rect);
      case ShapeKind.polygon:
        final n = sides.clamp(3, 12);
        final path = Path();
        for (var i = 0; i < n; i++) {
          final t = -math.pi / 2 + 2 * math.pi * i / n;
          final p = rect.center + Offset(math.cos(t) * rect.width / 2, math.sin(t) * rect.height / 2);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path..close();
    }
  }

  void shapeCommit() {
    final path = shapePreview;
    _shapeStart = null;
    _shapeEnd = null;
    _live.pulse();
    if (path == null) return;
    final layer = state.active;
    if (!_editable(layer)) return;
    if (shapeFill && shapeKind != ShapeKind.line) {
      final image = _renderOnto(layer, (canvas) {
        canvas.drawPath(path, Paint()..color = _color.withValues(alpha: brushFor(SketchTool.brush).opacity));
      });
      document.commit(state.replaceLayer(layer.copyWith(image: image)), shapeKind.label);
      _remember(_color);
      return;
    }
    final closed = shapeKind != ShapeKind.line;
    var b = brushFor(SketchTool.brush).copyWithParam(BrushParam.streamline, 0);
    if (closed) {
      b = b.copyWithParam(BrushParam.taperStart, 0).copyWithParam(BrushParam.taperEnd, 0);
    }
    final stroke = StrokeSession(
      layer: layer,
      width: width,
      height: height,
      brush: b,
      mode: StrokeMode.paint,
      color: _color,
      renderer: renderer,
      symmetry: _symmetry,
      selection: state.selection,
    );
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      final steps = math.max(2, (length / 1.5).ceil());
      for (var i = 0; i <= steps; i++) {
        final tangent = metric.getTangentForOffset(length * i / steps);
        if (tangent != null) stroke.add(StrokeInput(tangent.position));
      }
    }
    stroke.finish();
    final image = stroke.commit();
    stroke.dispose();
    if (image == null) return;
    document.commit(state.replaceLayer(layer.copyWith(image: image)), shapeKind.label);
    _remember(_color);
  }

  // --------------------------------------------------------------- gradient

  Offset? _gradientStart;
  Offset? _gradientEnd;
  (Offset, Offset)? get gradientLine =>
      _gradientStart == null || _gradientEnd == null ? null : (_gradientStart!, _gradientEnd!);

  void gradientBegin(Offset point) {
    if (!_editable(state.active)) return;
    _gradientStart = point;
    _gradientEnd = point;
    _live.pulse();
  }

  void gradientUpdate(Offset point) {
    if (_gradientStart == null) return;
    _gradientEnd = point;
    _live.pulse();
  }

  void _paintGradient(Canvas canvas, SketchLayer layer, Offset a, Offset b, FilterQuality quality) {
    final image = layer.image;
    if (image != null) canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
    final end = gradientToSecondary ? _secondary : _color.withValues(alpha: 0);
    final shader = switch (gradientKind) {
      GradientKind.linear => ui.Gradient.linear(a, b, [_color, end]),
      GradientKind.radial => ui.Gradient.radial(a, math.max(1, (b - a).distance), [_color, end]),
    };
    canvas.save();
    final clip = state.selection;
    if (clip != null) canvas.clipPath(clip);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = shader
        ..blendMode = layer.alphaLocked ? BlendMode.srcATop : BlendMode.srcOver,
    );
    canvas.restore();
  }

  void gradientCommit() {
    final a = _gradientStart;
    final b = _gradientEnd;
    _gradientStart = null;
    _gradientEnd = null;
    _live.pulse();
    if (a == null || b == null || (a - b).distance < 2) return;
    final layer = state.active;
    final image = _record((canvas) => _paintGradient(canvas, layer, a, b, FilterQuality.low));
    document.commit(state.replaceLayer(layer.copyWith(image: image)), currentL.freeSketchUndoGradient);
    _remember(_color);
  }

  // -------------------------------------------------------------- selection

  List<Offset>? _lasso;
  Offset? _selectStart;
  Offset? _selectEnd;

  /// The selection being dragged out, not yet applied.
  Path? get selectionDraft {
    final lasso = _lasso;
    if (lasso != null && lasso.length > 1) return Path()..addPolygon(lasso, true);
    final a = _selectStart;
    final b = _selectEnd;
    if (a == null || b == null) return null;
    final rect = Rect.fromPoints(a, b);
    return switch (selectionShape) {
      SelectionShape.ellipse => Path()..addOval(rect),
      _ => Path()..addRect(rect),
    };
  }

  void selectBegin(Offset point) {
    if (selectionShape == SelectionShape.lasso) {
      _lasso = [point];
    } else {
      _selectStart = point;
      _selectEnd = point;
    }
    _live.pulse();
  }

  void selectUpdate(Offset point, {bool constrain = false}) {
    final lasso = _lasso;
    if (lasso != null) {
      if ((lasso.last - point).distance > 1.5 / view.zoom) lasso.add(point);
    } else if (_selectStart != null) {
      var end = point;
      if (constrain) {
        final d = point - _selectStart!;
        final side = math.max(d.dx.abs(), d.dy.abs());
        end = _selectStart! + Offset(side * d.dx.sign, side * d.dy.sign);
      }
      _selectEnd = end;
    }
    _live.pulse();
  }

  void selectCommit({SelectionCombine? combine}) {
    final draft = selectionDraft;
    final tooSmall = draft == null || draft.getBounds().width < 2 || draft.getBounds().height < 2;
    _lasso = null;
    _selectStart = null;
    _selectEnd = null;
    _live.pulse();
    if (tooSmall) {
      // A tap outside any drag clears the selection, like every editor.
      if (state.selection != null && (combine ?? selectionCombine) == SelectionCombine.replace) {
        deselect();
      }
      return;
    }
    final mode = combine ?? selectionCombine;
    final existing = state.selection;
    final canvasRect = Path()..addRect(bounds);
    Path next;
    if (existing == null || mode == SelectionCombine.replace) {
      next = Path.combine(PathOperation.intersect, draft, canvasRect);
    } else if (mode == SelectionCombine.add) {
      next = Path.combine(PathOperation.union, existing, draft);
    } else {
      next = Path.combine(PathOperation.difference, existing, draft);
    }
    document.commit(state.copyWith(selection: next), currentL.freeSketchUndoSelect);
  }

  void selectAll() {
    document.commit(state.copyWith(selection: Path()..addRect(bounds)), currentL.freeSketchUndoSelectAll);
  }

  void deselect() {
    if (state.selection == null) return;
    document.commit(state.copyWith(clearSelection: true), currentL.freeSketchDeselect);
  }

  void invertSelection() {
    final current = state.selection;
    final all = Path()..addRect(bounds);
    final next = current == null ? all : Path.combine(PathOperation.difference, all, current);
    document.commit(state.copyWith(selection: next), currentL.freeSketchUndoInvertSelection);
  }

  // -------------------------------------------------------------- clipboard

  ui.Image? _clipboard;
  bool get hasClipboard => _clipboard != null;

  void copy() {
    final image = state.active.image;
    if (image == null) {
      onMessage?.call(currentL.freeSketchNothingToCopy);
      return;
    }
    final clip = state.selection;
    _clipboard?.dispose();
    final copied = _record((canvas) {
      if (clip != null) canvas.clipPath(clip);
      canvas.drawImage(image, Offset.zero, Paint());
    });
    _clipboard = copied;
    // Flatten it so the clipboard does not pin the layer it was cut from.
    unawaited(bake(copied).then((flat) {
      if (identical(_clipboard, copied) && !_disposed) {
        _clipboard = flat;
        copied.dispose();
      } else {
        flat.dispose();
      }
    }));
    onMessage?.call(clip == null ? currentL.freeSketchLayerCopied : currentL.freeSketchSelectionCopied);
    notifyListeners();
  }

  void cut() {
    if (!_editable(state.active)) return;
    copy();
    clearLayer(label: currentL.freeSketchUndoCut);
  }

  void paste() {
    final clip = _clipboard;
    if (clip == null) return;
    final before = state.layers.length;
    addLayer(name: currentL.freeSketchLayerPasted, image: clip.clone());
    if (state.layers.length > before) _transformActive();
  }

  /// Switches to the transform tool on the active layer, so pasted or
  /// imported pixels can be placed straight away.
  void _transformActive() {
    if (_transform != null) applyTransform();
    cancelDrafts();
    _tool = SketchTool.transform;
    notifyListeners();
    beginTransform();
  }

  // -------------------------------------------------------------- transform

  TransformSession? _transform;
  TransformSession? get transform => _transform;

  void beginTransform() {
    final layer = state.active;
    final image = layer.image;
    if (image == null) {
      onMessage?.call(currentL.freeSketchLayerEmptyTransform);
      _tool = SketchTool.brush;
      notifyListeners();
      return;
    }
    if (!_editable(layer)) {
      _tool = SketchTool.brush;
      notifyListeners();
      return;
    }
    final selection = state.selection;
    ui.Image floating;
    ui.Image? remainder;
    Rect box;
    if (selection != null) {
      floating = _record((canvas) {
        canvas.clipPath(selection);
        canvas.drawImage(image, Offset.zero, Paint());
      });
      remainder = _record((canvas) {
        canvas.drawImage(image, Offset.zero, Paint());
        canvas.drawPath(selection, Paint()..blendMode = BlendMode.clear);
      });
      box = selection.getBounds().intersect(bounds);
    } else {
      floating = image.clone();
      box = bounds;
    }
    final session = TransformSession(
      layerId: layer.id,
      floating: floating,
      remainder: remainder,
      width: width,
      height: height,
      box: box,
      selection: selection,
    );
    _transform = session;
    notifyListeners();
    _live.pulse();
    unawaited(_tightenTransformBox(session));
  }

  Future<void> _tightenTransformBox(TransformSession session) async {
    final clone = session.floating.clone();
    try {
      final rgba = await SketchExporter.rgbaOf(clone);
      final w = width;
      final h = height;
      final found = await Isolate.run(() => opaqueBounds(rgba, w, h));
      if (found == null || _transform != session) return;
      session.box = Rect.fromLTRB(
        found.left.toDouble(),
        found.top.toDouble(),
        found.right.toDouble(),
        found.bottom.toDouble(),
      );
      _live.pulse();
      notifyListeners();
    } on Object {
      // Keep the coarse box.
    } finally {
      clone.dispose();
    }
  }

  void transformChanged() {
    _live.pulse();
    notifyListeners();
  }

  void applyTransform() {
    final session = _transform;
    if (session == null) return;
    _transform = null;
    if (session.isIdentity) {
      session.dispose();
      notifyListeners();
      _live.pulse();
      return;
    }
    final layer = state.layerById(session.layerId);
    if (layer == null) {
      session.dispose();
      return;
    }
    final image = session.commit();
    final selection = session.transformedSelection();
    session.dispose();
    var next = state.replaceLayer(layer.copyWith(image: image));
    if (selection != null) next = next.copyWith(selection: selection);
    document.commit(next, currentL.freeSketchUndoTransform);
  }

  /// Applies the transform and goes back to painting — the Apply button
  /// and Enter.
  void finishTransform() {
    applyTransform();
    if (_tool == SketchTool.transform) {
      _tool = SketchTool.brush;
      notifyListeners();
    }
  }

  void cancelTransform() {
    _transform?.dispose();
    _transform = null;
    if (_tool == SketchTool.transform) _tool = SketchTool.brush;
    notifyListeners();
    _live.pulse();
  }

  // ----------------------------------------------------------- adjustments

  AdjustmentKind? _adjustment;
  Map<String, double> _adjustValues = const {};
  AdjustmentKind? get adjustment => _adjustment;
  Map<String, double> get adjustValues => _adjustValues;

  bool beginAdjustment(AdjustmentKind kind) {
    final layer = state.active;
    if (layer.image == null) {
      onMessage?.call(currentL.freeSketchLayerEmptyAdjust);
      return false;
    }
    if (!_editable(layer)) return false;
    if (_transform != null) applyTransform();
    _adjustment = kind;
    _adjustValues = kind.defaults;
    notifyListeners();
    _live.pulse();
    return true;
  }

  void setAdjustValue(String key, double value) {
    _adjustValues = {..._adjustValues, key: value};
    _live.pulse();
    notifyListeners();
  }

  void _paintAdjusted(Canvas canvas, SketchLayer layer, AdjustmentKind kind, FilterQuality quality) {
    final image = layer.image;
    if (image == null) return;
    final clip = state.selection;
    final paint = kind.paint(_adjustValues)..filterQuality = quality;
    if (clip == null) {
      canvas.saveLayer(bounds, paint);
      canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
      canvas.restore();
      return;
    }
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawRect(bounds, Paint()..blendMode = BlendMode.clear);
    canvas.saveLayer(bounds, paint);
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
    canvas.restore();
    canvas.restore();
  }

  void applyAdjustment() {
    final kind = _adjustment;
    _adjustment = null;
    notifyListeners();
    if (kind == null) return;
    final layer = state.active;
    final image = _record((canvas) => _paintAdjusted(canvas, layer, kind, FilterQuality.low));
    if (kind == AdjustmentKind.blur) {
      // A blur spreads colour past the layer's old alpha; with alpha lock on
      // that is exactly what the artist asked not to happen.
      if (layer.alphaLocked && layer.image != null) {
        final locked = _record((canvas) {
          canvas.drawImage(layer.image!, Offset.zero, Paint());
          canvas.drawImage(image, Offset.zero, Paint()..blendMode = BlendMode.srcIn);
        });
        image.dispose();
        document.commit(state.replaceLayer(layer.copyWith(image: locked)), kind.label(currentL));
        return;
      }
    }
    document.commit(state.replaceLayer(layer.copyWith(image: image)), kind.label(currentL));
  }

  void cancelAdjustment() {
    _adjustment = null;
    notifyListeners();
    _live.pulse();
  }

  // ------------------------------------------------------------------ fill

  bool _busy = false;
  bool get busy => _busy;

  Future<void> fillAt(Offset point) async {
    if (_busy) return;
    final layer = state.active;
    if (!_editable(layer)) return;
    final x = point.dx.floor();
    final y = point.dy.floor();
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    _busy = true;
    notifyListeners();
    ui.Image? source;
    try {
      source = fillAllLayers
          ? SketchCompositor.flatten(state, width, height, includeBackground: false)
          : (layer.image?.clone() ?? _record((_) {}));
      final rgba = await SketchExporter.rgbaOf(source);
      final w = width;
      final h = height;
      final tolerance = fillTolerance;
      final grow = fillGrow;
      final maskRgba = await Isolate.run(() {
        final mask = floodFillMask(rgba, w, h, x, y, tolerance: tolerance, grow: grow);
        return maskToRgba(mask);
      });
      final maskImage = await _decodeRgba(maskRgba, w, h);
      final current = state.layerById(layer.id);
      if (current == null) {
        maskImage.dispose();
        return;
      }
      final image = _renderOnto(current, (canvas) {
        canvas.drawImage(
          maskImage,
          Offset.zero,
          Paint()..colorFilter = ColorFilter.mode(_color, BlendMode.srcIn),
        );
      });
      maskImage.dispose();
      document.commit(state.replaceLayer(current.copyWith(image: image)), currentL.freeSketchUndoFill);
      _remember(_color);
    } on Object catch (error) {
      onMessage?.call(currentL.freeSketchFillFailed('$error'));
    } finally {
      source?.dispose();
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  static Future<ui.Image> _decodeRgba(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  // -------------------------------------------------------------- eyedropper

  Color? _loupe;
  Offset? _loupeAt;
  Color? get loupeColor => _loupe;
  Offset? get loupeAt => _loupeAt;

  Future<void> pickAt(Offset point, {bool show = true}) async {
    final color = await SketchCompositor.sample(
      state,
      point,
      layerId: eyedropperAllLayers ? null : state.activeLayerId,
    );
    if (_disposed) return;
    if (show) {
      _loupe = color;
      _loupeAt = point;
      _live.pulse();
    }
    if (color != null) setColor(color);
  }

  void endPick() {
    _loupe = null;
    _loupeAt = null;
    _live.pulse();
  }

  // ------------------------------------------------------------------ layers

  int get maxLayers => SketchLimits.maxLayers(width, height);

  void selectLayer(int id) {
    if (id == state.activeLayerId) return;
    if (_transform != null) applyTransform();
    document.setQuietly(state.copyWith(activeLayerId: id));
  }

  String _nextLayerName() {
    var n = 1;
    final names = state.layers.map((l) => l.name).toSet();
    while (names.contains(currentL.freeSketchStudioDefaultLayerName(n))) {
      n++;
    }
    return currentL.freeSketchStudioDefaultLayerName(n);
  }

  void addLayer({String? name, ui.Image? image}) {
    if (state.layers.length >= maxLayers) {
      image?.dispose();
      onMessage?.call(currentL.freeSketchLayerLimit(maxLayers));
      return;
    }
    final id = document.takeLayerId();
    final layers = [...state.layers]..insert(state.activeIndex + 1, SketchLayer(id: id, name: name ?? _nextLayerName(), image: image));
    document.commit(state.copyWith(layers: layers, activeLayerId: id), currentL.freeSketchLayerNew);
  }

  void duplicateLayer([int? id]) {
    if (state.layers.length >= maxLayers) {
      onMessage?.call(currentL.freeSketchLayerLimit(maxLayers));
      return;
    }
    final source = state.layerById(id ?? state.activeLayerId);
    if (source == null) return;
    final index = state.layers.indexOf(source);
    final copyId = document.takeLayerId();
    final copy = SketchLayer(
      id: copyId,
      name: currentL.freeSketchLayerCopyName(source.name),
      image: source.image,
      opacity: source.opacity,
      blend: source.blend,
      visible: source.visible,
      alphaLocked: source.alphaLocked,
      clipped: source.clipped,
    );
    final layers = [...state.layers]..insert(index + 1, copy);
    document.commit(state.copyWith(layers: layers, activeLayerId: copyId), currentL.freeSketchUndoDuplicateLayer);
  }

  void deleteLayer([int? id]) {
    final target = state.layerById(id ?? state.activeLayerId);
    if (target == null) return;
    if (state.layers.length == 1) {
      document.commit(
        state.copyWith(layers: [SketchLayer(id: target.id, name: target.name)]),
        currentL.freeSketchLayerDelete,
      );
      return;
    }
    final index = state.layers.indexOf(target);
    final layers = [...state.layers]..removeAt(index);
    final active = target.id == state.activeLayerId
        ? layers[math.min(index, layers.length - 1)].id
        : state.activeLayerId;
    document.commit(state.copyWith(layers: layers, activeLayerId: active), currentL.freeSketchLayerDelete);
  }

  bool canMergeDown([int? id]) {
    final target = state.layerById(id ?? state.activeLayerId);
    if (target == null) return false;
    final index = state.layers.indexOf(target);
    return index > 0 && !state.layers[index - 1].locked;
  }

  void mergeDown([int? id]) {
    final top = state.layerById(id ?? state.activeLayerId);
    if (top == null) return;
    final index = state.layers.indexOf(top);
    if (index <= 0) return;
    final below = state.layers[index - 1];
    if (below.locked) {
      onMessage?.call(currentL.freeSketchLayerLocked(below.name));
      return;
    }
    final image = _record((canvas) {
      final b = below.image;
      if (b != null) canvas.drawImage(b, Offset.zero, Paint());
      final t = top.image;
      if (t == null || !top.visible) return;
      canvas.saveLayer(
        bounds,
        Paint()
          ..blendMode = top.blend.mode
          ..color = Color.fromRGBO(0, 0, 0, top.opacity),
      );
      canvas.drawImage(t, Offset.zero, Paint());
      if (top.clipped && b != null) {
        canvas.drawImage(b, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
      }
      canvas.restore();
    });
    final layers = [...state.layers]
      ..removeAt(index)
      ..[index - 1] = below.copyWith(image: image);
    document.commit(state.copyWith(layers: layers, activeLayerId: below.id), currentL.freeSketchUndoMergeDown);
  }

  void flatten() {
    final image = SketchCompositor.flatten(state, width, height, includeBackground: false);
    final id = document.takeLayerId();
    document.commit(
      state.copyWith(layers: [SketchLayer(id: id, name: currentL.freeSketchLayerFlattened, image: image)], activeLayerId: id),
      currentL.freeSketchUndoFlatten,
    );
  }

  void moveLayer(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final layers = [...state.layers];
    final layer = layers.removeAt(fromIndex);
    layers.insert(toIndex.clamp(0, layers.length), layer);
    document.commit(state.copyWith(layers: layers), currentL.freeSketchUndoReorderLayers);
  }

  void updateLayer(int id, SketchLayer Function(SketchLayer layer) change, String label) {
    final layer = state.layerById(id);
    if (layer == null) return;
    document.commit(state.replaceLayer(change(layer)), label);
  }

  SketchSnapshot? _opacityBefore;

  void previewOpacity(int id, double opacity) {
    _opacityBefore ??= state;
    final layer = state.layerById(id);
    if (layer == null) return;
    document.preview(state.replaceLayer(layer.copyWith(opacity: opacity.clamp(0.0, 1.0))));
  }

  void commitOpacity() {
    final before = _opacityBefore;
    _opacityBefore = null;
    if (before != null) document.commitFrom(before, currentL.freeSketchUndoLayerOpacity);
  }

  /// Clears the active layer, or only the selected part of it.
  void clearLayer({String? label}) {
    final layer = state.active;
    if (!_editable(layer) || layer.image == null) return;
    final clip = state.selection;
    final undo = label ?? currentL.commonClear;
    if (clip == null) {
      document.commit(state.replaceLayer(layer.copyWith(clearImage: true)), undo);
      return;
    }
    final image = _record((canvas) {
      canvas.drawImage(layer.image!, Offset.zero, Paint());
      canvas.drawPath(clip, Paint()..blendMode = BlendMode.clear);
    });
    document.commit(state.replaceLayer(layer.copyWith(image: image)), undo);
  }

  /// Fills the active layer (or the selection) with the current colour.
  void fillLayer() {
    final layer = state.active;
    if (!_editable(layer)) return;
    final image = _renderOnto(layer, (canvas) => canvas.drawRect(bounds, Paint()..color = _color));
    document.commit(state.replaceLayer(layer.copyWith(image: image)), currentL.freeSketchUndoFillLayer);
  }

  // ------------------------------------------------------------------ canvas

  void flipCanvas({required bool horizontal}) {
    final m = Float64List.fromList(<double>[
      horizontal ? -1 : 1, 0, 0, 0, //
      0, horizontal ? 1 : -1, 0, 0, //
      0, 0, 1, 0, //
      horizontal ? width.toDouble() : 0, horizontal ? 0 : height.toDouble(), 0, 1, //
    ]);
    final layers = [
      for (final layer in state.layers)
        if (layer.image == null)
          layer
        else
          layer.copyWith(
            image: _record((canvas) {
              canvas.transform(m);
              canvas.drawImage(layer.image!, Offset.zero, Paint());
            }),
          ),
    ];
    document.commit(
      state.copyWith(layers: layers, selection: state.selection?.transform(m)),
      horizontal ? currentL.freeSketchCanvasFlipH : currentL.freeSketchCanvasFlipV,
    );
  }

  void setBackground(Color color) {
    document.commit(state.copyWith(background: color.withValues(alpha: 1), showBackground: true), currentL.freeSketchBackgroundColour);
  }

  void toggleBackground() {
    document.commit(state.copyWith(showBackground: !state.showBackground), currentL.freeSketchBackground);
  }

  // ------------------------------------------------------------------ import

  Future<void> importImage(Uint8List bytes, String name) async {
    try {
      final image = await decodeToCanvas(bytes, width, height);
      final before = state.layers.length;
      addLayer(name: name, image: image);
      if (state.layers.length > before) _transformActive();
    } on Object catch (error) {
      onMessage?.call(currentL.freeSketchImageOpenFailed('$error'));
    }
  }

  // ------------------------------------------------------------------- undo

  void undo() {
    if (_stroke != null) return;
    if (_transform != null) {
      cancelTransform();
      return;
    }
    if (_adjustment != null) {
      cancelAdjustment();
      return;
    }
    if (document.undo()) _live.pulse();
  }

  void redo() {
    if (_stroke != null || _transform != null) return;
    if (document.redo()) _live.pulse();
  }

  // ---------------------------------------------------------------- overrides

  /// What the compositor should draw instead of stored pixels right now.
  Map<int, LayerContent> overrides(FilterQuality quality) {
    final stroke = _stroke;
    if (stroke != null) {
      return {stroke.layer.id: (canvas) => stroke.paintLayer(canvas, quality: quality)};
    }
    final session = _transform;
    if (session != null) {
      return {session.layerId: (canvas) => session.paint(canvas, quality: quality)};
    }
    final kind = _adjustment;
    if (kind != null) {
      final layer = state.active;
      return {layer.id: (canvas) => _paintAdjusted(canvas, layer, kind, quality)};
    }
    final a = _gradientStart;
    final b = _gradientEnd;
    if (a != null && b != null && (a - b).distance >= 2) {
      final layer = state.active;
      return {layer.id: (canvas) => _paintGradient(canvas, layer, a, b, quality)};
    }
    return const {};
  }

  void cancelDrafts() {
    _shapeStart = null;
    _shapeEnd = null;
    _gradientStart = null;
    _gradientEnd = null;
    _lasso = null;
    _selectStart = null;
    _selectEnd = null;
    if (_adjustment != null) _adjustment = null;
    _live.pulse();
  }

  // ----------------------------------------------------------------- helpers

  ui.Image _record(void Function(Canvas canvas) paint) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  /// The layer with [paint] drawn over it, inside the selection and under
  /// the layer's alpha lock.
  ui.Image _renderOnto(SketchLayer layer, void Function(Canvas canvas) paint) {
    return _record((canvas) {
      final image = layer.image;
      if (image != null) canvas.drawImage(image, Offset.zero, Paint());
      canvas.save();
      final clip = state.selection;
      if (clip != null) canvas.clipPath(clip);
      canvas.saveLayer(bounds, Paint()..blendMode = layer.alphaLocked ? BlendMode.srcATop : BlendMode.srcOver);
      paint(canvas);
      canvas.restore();
      canvas.restore();
    });
  }

  // ----------------------------------------------------------- brush preview

  final _previews = <String, ui.Image>{};

  /// A sample stroke of [preset] in [ink], for the brush library.
  ui.Image brushPreview(BrushPreset preset, Color ink, {int width = 220, int height = 52}) {
    final key = '${preset.id}|${ink.toARGB32()}|$width|$height|${_overrides[preset.id]}';
    final cached = _previews[key];
    if (cached != null) return cached;
    final blending = preset.engine != BrushEngine.paint;
    ui.Image? base;
    if (blending) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const colors = [Color(0xFFE5484D), Color(0xFFF5A524), Color(0xFF30A46C), Color(0xFF3E63DD), Color(0xFF8E4EC6)];
      final band = width / colors.length;
      for (var i = 0; i < colors.length; i++) {
        canvas.drawRect(Rect.fromLTWH(i * band, height * 0.22, band + 1, height * 0.56), Paint()..color = colors[i]);
      }
      final picture = recorder.endRecording();
      base = picture.toImageSync(width, height);
      picture.dispose();
    }
    final size = math.min(preset.size, height * 0.42);
    final b = preset.copyWithParam(BrushParam.size, math.max(size, 1.5)).copyWithParam(BrushParam.streamline, 0);
    final session = StrokeSession(
      layer: SketchLayer(id: 0, name: '', image: base),
      width: width,
      height: height,
      brush: b,
      mode: preset.engine == BrushEngine.smudge
          ? StrokeMode.smudge
          : preset.engine == BrushEngine.blur
              ? StrokeMode.blur
              : StrokeMode.paint,
      color: ink,
      renderer: renderer,
      seed: 3,
    );
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      session.add(StrokeInput(
        Offset(12 + t * (width - 24), height / 2 + math.sin(t * math.pi * 2) * height * 0.18),
        pressure: 0.25 + 0.75 * math.sin(t * math.pi),
      ));
    }
    session.finish();
    final image = session.commit() ?? _record((_) {});
    session.dispose();
    base?.dispose();
    _previews[key] = image;
    return image;
  }

  // -------------------------------------------------------------- persistence

  final _savedImages = <int, ui.Image?>{};
  final _savedFiles = <int, String?>{};
  int _savedRevision = 0;
  bool _saving = false;
  bool _saveAgain = false;
  Timer? _saveTimer;

  bool get dirty => document.revision != _savedRevision;
  bool get saving => _saving;

  void _onDocumentChanged() {
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave([Duration delay = const Duration(seconds: 3)]) {
    _saveTimer?.cancel();
    if (_disposed) return;
    _saveTimer = Timer(delay, () => unawaited(save()));
  }

  Future<void> save() async {
    if (_saving) {
      _saveAgain = true;
      return;
    }
    if (_stroke != null) {
      _scheduleSave(const Duration(seconds: 1));
      return;
    }
    final revision = document.revision;
    if (revision == _savedRevision) return;
    _saving = true;
    if (!_disposed) notifyListeners();
    final snapshot = state;
    final clones = <int, ui.Image?>{};
    ui.Image? thumb;
    try {
      for (final layer in snapshot.layers) {
        final saved = _savedImages[layer.id];
        if (_savedImages.containsKey(layer.id) && identical(saved, layer.image)) continue;
        clones[layer.id] = layer.image?.clone();
      }
      final thumbFuture = SketchCompositor.thumbnail(snapshot, width, height);
      final changed = <int, Uint8List?>{};
      for (final entry in clones.entries) {
        final image = entry.value;
        changed[entry.key] = image == null ? null : await SketchExporter.pngOf(image);
      }
      thumb = await thumbFuture;
      final thumbPng = await SketchExporter.pngOf(thumb);
      final meta = _meta.copyWith(
        background: snapshot.background.toARGB32(),
        showBackground: snapshot.showBackground,
        activeLayerId: snapshot.activeLayerId,
        layers: [
          for (final layer in snapshot.layers)
            SketchLayerMeta(
              id: layer.id,
              name: layer.name,
              file: _savedFiles[layer.id],
              opacity: layer.opacity,
              blend: layer.blend,
              visible: layer.visible,
              locked: layer.locked,
              alphaLocked: layer.alphaLocked,
              clipped: layer.clipped,
            ),
        ],
      );
      final written = await repository.save(meta, changed: changed, thumbnail: thumbPng);
      _meta = written;
      _savedFiles
        ..clear()
        ..addEntries(written.layers.map((l) => MapEntry(l.id, l.file)));
      _savedImages
        ..clear()
        ..addEntries(snapshot.layers.map((l) => MapEntry(l.id, l.image)));
      _savedRevision = revision;
    } on Object catch (error) {
      onMessage?.call(currentL.freeSketchSaveFailed('$error'));
    } finally {
      for (final image in clones.values) {
        image?.dispose();
      }
      thumb?.dispose();
      _saving = false;
      if (!_disposed) {
        notifyListeners();
        if (_saveAgain || dirty) {
          _saveAgain = false;
          _scheduleSave(const Duration(seconds: 1));
        }
      }
    }
  }

  Future<void> rename(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == _meta.title) return;
    _meta = _meta.copyWith(title: trimmed);
    notifyListeners();
    await repository.rename(_meta.id, trimmed);
  }

  /// Writes any unsaved work, then releases every image. Safe to await from
  /// a page's close handler.
  Future<void> close() async {
    _saveTimer?.cancel();
    if (_stroke != null) endStroke();
    if (_transform != null) applyTransform();
    while (_saving) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (dirty) await save();
  }

  // ------------------------------------------------------------------- prefs

  Timer? _prefsTimer;

  void _prefsChanged() {
    _prefsTimer?.cancel();
    _prefsTimer = Timer(const Duration(milliseconds: 800), () => unawaited(_writePrefs()));
  }

  Map<String, Object?> _prefsJson() => {
        'brushes': {for (final e in _brushIds.entries) e.key.name: e.value},
        'overrides': _overrides,
        'color': _color.toARGB32(),
        'secondary': _secondary.toARGB32(),
        'recent': [for (final c in _recent) c.toARGB32()],
        'palette': [for (final c in _palette) c.toARGB32()],
        'pressureGamma': _pressureGamma,
        'stylusOnly': _stylusOnly,
        'fill': {'tolerance': fillTolerance, 'allLayers': fillAllLayers, 'grow': fillGrow},
        'symmetry': _symmetry.toJson(),
      };

  Future<void> _writePrefs() async {
    try {
      await repository.savePrefs(_prefsJson());
    } on Object {
      // Preferences are a convenience; losing one write is harmless.
    }
  }

  void _readPrefs(Map<String, Object?> prefs) {
    final brushes = prefs['brushes'];
    if (brushes is Map) {
      for (final tool in _brushIds.keys.toList()) {
        final id = brushes[tool.name];
        if (id is String && BrushLibrary.contains(id)) _brushIds[tool] = id;
      }
    }
    final overrides = prefs['overrides'];
    if (overrides is Map) {
      for (final entry in overrides.entries) {
        final values = entry.value;
        if (entry.key is! String || values is! Map) continue;
        _overrides[entry.key as String] = {
          for (final v in values.entries)
            if (v.key is String && v.value is num) v.key as String: (v.value as num).toDouble(),
        };
      }
    }
    Color? colorOf(Object? value) => value is int ? Color(value) : null;
    _color = colorOf(prefs['color']) ?? _color;
    _secondary = colorOf(prefs['secondary']) ?? _secondary;
    for (final list in [(prefs['recent'], _recent), (prefs['palette'], _palette)]) {
      final raw = list.$1;
      if (raw is List) {
        list.$2.addAll(raw.whereType<int>().map(Color.new));
      }
    }
    final gamma = prefs['pressureGamma'];
    if (gamma is num) _pressureGamma = gamma.toDouble().clamp(0.25, 4.0);
    _stylusOnly = prefs['stylusOnly'] == true;
    final fill = prefs['fill'];
    if (fill is Map) {
      final tolerance = fill['tolerance'];
      if (tolerance is num) fillTolerance = tolerance.toDouble().clamp(0.0, 1.0);
      fillAllLayers = fill['allLayers'] != false;
      final grow = fill['grow'];
      if (grow is num) fillGrow = grow.toInt().clamp(0, 6);
    }
    _symmetry = SymmetrySettings.fromJson(prefs['symmetry']);
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _prefsTimer?.cancel();
    unawaited(_writePrefs());
    document.removeListener(_onDocumentChanged);
    _stroke?.dispose();
    _transform?.dispose();
    _clipboard?.dispose();
    for (final image in _previews.values) {
      image.dispose();
    }
    _previews.clear();
    document.dispose();
    view.dispose();
    _live.dispose();
    super.dispose();
  }
}

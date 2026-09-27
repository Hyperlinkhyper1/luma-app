import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/luma_theme.dart';
import '../engine/compositor.dart';
import '../engine/transform_session.dart';
import '../model/sketch_tool.dart';
import 'sketch_view.dart';
import 'studio_controller.dart';

enum _Mode { none, tool, pan, rotate, pinch, done }

enum _Handle { move, rotate, corner, side }

/// The drawing surface: turns raw pointer input into studio actions and
/// paints the document with its live overlays.
///
/// Raw [Listener] events rather than gesture recognisers, because painting
/// needs every sample with its pressure, from the very first one, and has to
/// tell a pen from a finger from a mouse button. Touch works the way tablet
/// painting apps have trained everyone: one finger draws, two pinch, pan and
/// rotate, a two-finger tap undoes and a three-finger tap redoes.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({super.key, required this.controller});

  final StudioController controller;

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas> with SingleTickerProviderStateMixin {
  StudioController get c => widget.controller;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  DateTime _lastMove = DateTime.now();

  _Mode _mode = _Mode.none;
  int? _toolPointer;
  bool _toolIsTouch = false;
  DateTime _toolStarted = DateTime.now();
  double _toolTravel = 0;
  bool _picking = false;
  bool _pickPending = false;

  final _touches = <int, Offset>{};
  PinchAnchor? _pinch;
  DateTime _tapStarted = DateTime.now();
  int _tapPointers = 0;
  bool _tapMoved = false;
  Offset _tapOrigin = Offset.zero;
  bool _sawStylus = false;

  Offset? _rotateLast;
  final _hover = ValueNotifier<Offset?>(null);

  _Handle? _handle;
  int _handleIndex = 0;
  Offset _dragStartDoc = Offset.zero;
  Offset _startTranslation = Offset.zero;
  double _startScaleX = 1;
  double _startScaleY = 1;
  double _startRotation = 0;

  double _panZoomScale = 1;
  double _panZoomRotation = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hover.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  static bool _isPen(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  double _pressure(PointerEvent e) {
    if (!_isPen(e)) return 1;
    final min = e.pressureMin;
    final max = e.pressureMax;
    if (max <= min) return 1;
    return ((e.pressure - min) / (max - min)).clamp(0.0, 1.0);
  }

  bool _keyDown(LogicalKeyboardKey key) => HardwareKeyboard.instance.logicalKeysPressed.contains(key);
  bool get _space => _keyDown(LogicalKeyboardKey.space);
  bool get _shift => HardwareKeyboard.instance.isShiftPressed;
  bool get _alt => HardwareKeyboard.instance.isAltPressed;

  // ---------------------------------------------------------------- pointer

  void _onDown(PointerDownEvent e) {
    if (_isPen(e)) _sawStylus = true;
    final touch = e.kind == PointerDeviceKind.touch;

    if (touch) {
      _touches[e.pointer] = e.localPosition;
      if (_touches.length == 1) {
        _tapStarted = DateTime.now();
        _tapPointers = 1;
        _tapMoved = false;
        _tapOrigin = e.localPosition;
      } else {
        _tapPointers = math.max(_tapPointers, _touches.length);
      }
      if (_touches.length >= 2) {
        if (_mode == _Mode.tool && _toolIsTouch) {
          final young = DateTime.now().difference(_toolStarted).inMilliseconds < 300 && _toolTravel < 48;
          if (!young) return;
          _abandonTool();
        }
        if (_mode == _Mode.none || _mode == _Mode.pan || _mode == _Mode.done) {
          final points = _touches.values.take(2).toList();
          _pinch = c.view.beginPinch(points[0], points[1]);
          _mode = _Mode.pinch;
        }
        return;
      }
      if (c.stylusOnly && _sawStylus) {
        _mode = _Mode.pan;
        return;
      }
    }

    if (_mode != _Mode.none && _mode != _Mode.done) return;

    if (e.kind == PointerDeviceKind.mouse &&
        (e.buttons & (kMiddleMouseButton | kSecondaryMouseButton)) != 0) {
      _mode = _Mode.pan;
      return;
    }
    if (_space) {
      _mode = _Mode.pan;
      return;
    }
    if (_keyDown(LogicalKeyboardKey.keyR)) {
      _mode = _Mode.rotate;
      _rotateLast = e.localPosition;
      return;
    }

    _mode = _Mode.tool;
    _toolPointer = e.pointer;
    _toolIsTouch = touch;
    _toolStarted = DateTime.now();
    _toolTravel = 0;
    _toolDown(e);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.kind == PointerDeviceKind.touch && _touches.containsKey(e.pointer)) {
      _touches[e.pointer] = e.localPosition;
      if ((e.localPosition - _tapOrigin).distance > 12) _tapMoved = true;
    }
    switch (_mode) {
      case _Mode.pinch:
        final anchor = _pinch;
        if (anchor != null && _touches.length >= 2) {
          final points = _touches.values.take(2).toList();
          c.view.updatePinch(anchor, points[0], points[1]);
        }
      case _Mode.pan:
        c.view.panBy(e.localDelta);
      case _Mode.rotate:
        final last = _rotateLast;
        if (last != null) {
          final center = Offset(c.view.viewport.width / 2, c.view.viewport.height / 2);
          final angle = (e.localPosition - center).direction - (last - center).direction;
          c.view.rotateBy(angle, center);
        }
        _rotateLast = e.localPosition;
      case _Mode.tool:
        if (e.pointer != _toolPointer) return;
        _toolTravel += e.localDelta.distance;
        _lastMove = DateTime.now();
        _toolMove(e);
      case _Mode.none:
      case _Mode.done:
        break;
    }
  }

  void _onUp(PointerEvent e, {bool cancelled = false}) {
    final touch = e.kind == PointerDeviceKind.touch;
    if (touch) {
      _touches.remove(e.pointer);
      if (_touches.isEmpty) {
        final quick = DateTime.now().difference(_tapStarted).inMilliseconds < 320;
        if (!cancelled && quick && !_tapMoved && _tapPointers >= 2) {
          if (_tapPointers == 2) c.undo();
          if (_tapPointers >= 3) c.redo();
        }
      }
    }
    switch (_mode) {
      case _Mode.pinch:
        if (_touches.length < 2) {
          _pinch = null;
          c.view.settleRotation();
          _mode = _touches.isEmpty ? _Mode.none : _Mode.done;
        }
      case _Mode.tool:
        if (e.pointer != _toolPointer) return;
        if (cancelled) {
          _abandonTool();
        } else {
          _toolUp(e);
        }
        _mode = _Mode.none;
        _toolPointer = null;
      case _Mode.pan:
      case _Mode.rotate:
        if (!touch || _touches.isEmpty) _mode = _Mode.none;
        if (_mode == _Mode.none) c.view.settleRotation();
      case _Mode.done:
        if (_touches.isEmpty) _mode = _Mode.none;
      case _Mode.none:
        break;
    }
    if (touch && _touches.isEmpty && _mode == _Mode.done) _mode = _Mode.none;
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final dy = e.scrollDelta.dy;
      if (dy == 0) return;
      if (_shift && !HardwareKeyboard.instance.isControlPressed) {
        c.view.rotateBy(dy.sign * math.pi / 36, e.localPosition);
        return;
      }
      c.view.zoomBy(math.pow(1.0018, -dy).toDouble(), e.localPosition);
    } else if (e is PointerScaleEvent) {
      c.view.zoomBy(e.scale, e.localPosition);
    }
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    _panZoomScale = 1;
    _panZoomRotation = 0;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    if (e.panDelta != Offset.zero) c.view.panBy(e.localPanDelta);
    if (e.scale != _panZoomScale && e.scale > 0) {
      c.view.zoomBy(e.scale / _panZoomScale, e.localPosition);
      _panZoomScale = e.scale;
    }
    if (e.rotation != _panZoomRotation) {
      c.view.rotateBy(e.rotation - _panZoomRotation, e.localPosition);
      _panZoomRotation = e.rotation;
    }
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent e) => c.view.settleRotation();

  // ------------------------------------------------------------------ tools

  void _toolDown(PointerDownEvent e) {
    final doc = c.view.toDoc(e.localPosition);
    if (_alt && c.tool != SketchTool.eyedropper) {
      _picking = true;
      unawaited(_pick(doc));
      return;
    }
    switch (c.tool) {
      case SketchTool.brush:
      case SketchTool.eraser:
      case SketchTool.smudge:
        final eraser = e.kind == PointerDeviceKind.invertedStylus;
        final last = c.lastStrokeEnd;
        if (_shift && last != null && !eraser) {
          c.strokeLine(last, doc, _pressure(e));
          _mode = _Mode.done;
          return;
        }
        if (c.beginStroke(doc, _pressure(e), eraser: eraser)) {
          _lastTick = Duration.zero;
          if (!_ticker.isActive) unawaited(_ticker.start());
        } else {
          _mode = _Mode.done;
        }
      case SketchTool.fill:
        unawaited(c.fillAt(doc));
        _mode = _Mode.done;
      case SketchTool.gradient:
        c.gradientBegin(doc);
      case SketchTool.shape:
        c.shapeBegin(doc);
      case SketchTool.select:
        c.selectBegin(doc);
      case SketchTool.transform:
        _transformDown(e.localPosition);
      case SketchTool.eyedropper:
        _picking = true;
        unawaited(_pick(doc));
    }
  }

  void _toolMove(PointerMoveEvent e) {
    final doc = c.view.toDoc(e.localPosition);
    if (_picking) {
      unawaited(_pick(doc));
      return;
    }
    switch (c.tool) {
      case SketchTool.brush:
      case SketchTool.eraser:
      case SketchTool.smudge:
        c.strokeTo(doc, _pressure(e));
      case SketchTool.gradient:
        c.gradientUpdate(doc);
      case SketchTool.shape:
        c.shapeUpdate(doc, constrain: _shift);
      case SketchTool.select:
        c.selectUpdate(doc, constrain: _shift);
      case SketchTool.transform:
        _transformMove(e.localPosition);
      case SketchTool.fill:
      case SketchTool.eyedropper:
        break;
    }
  }

  void _toolUp(PointerEvent e) {
    if (_picking) {
      _picking = false;
      c.endPick();
      return;
    }
    switch (c.tool) {
      case SketchTool.brush:
      case SketchTool.eraser:
      case SketchTool.smudge:
        c.endStroke();
        _ticker.stop();
      case SketchTool.gradient:
        c.gradientCommit();
      case SketchTool.shape:
        c.shapeCommit();
      case SketchTool.select:
        final combine = _shift
            ? SelectionCombine.add
            : _alt
                ? SelectionCombine.subtract
                : null;
        c.selectCommit(combine: combine);
      case SketchTool.transform:
        _handle = null;
      case SketchTool.fill:
      case SketchTool.eyedropper:
        break;
    }
  }

  /// A second finger arrived just after the first: that was the start of a
  /// pinch, not a mark, so throw away whatever the first finger began.
  void _abandonTool() {
    if (_picking) {
      _picking = false;
      c.endPick();
    }
    switch (c.tool) {
      case SketchTool.brush:
      case SketchTool.eraser:
      case SketchTool.smudge:
        c.cancelStroke();
        _ticker.stop();
      case SketchTool.gradient:
      case SketchTool.shape:
      case SketchTool.select:
        c.cancelDrafts();
      case SketchTool.transform:
      case SketchTool.fill:
      case SketchTool.eyedropper:
        break;
    }
    _mode = _Mode.none;
    _toolPointer = null;
  }

  Future<void> _pick(Offset doc) async {
    if (_pickPending) return;
    _pickPending = true;
    try {
      await c.pickAt(doc);
    } finally {
      _pickPending = false;
    }
  }

  void _onTick(Duration elapsed) {
    if (!c.stroking) {
      _ticker.stop();
      return;
    }
    final dt = _lastTick == Duration.zero ? 0.016 : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final stationary = DateTime.now().difference(_lastMove).inMilliseconds > 40;
    c.tick(dt.clamp(0.0, 0.1), stationary: stationary);
  }

  // -------------------------------------------------------------- transform

  List<Offset> _screenCorners(TransformSession t) => [for (final p in t.corners) c.view.toScreen(p)];

  Offset _rotateHandle(List<Offset> corners) {
    final topMid = (corners[0] + corners[1]) / 2;
    final bottomMid = (corners[3] + corners[2]) / 2;
    final dir = topMid - bottomMid;
    final len = dir.distance;
    if (len < 1e-3) return topMid - const Offset(0, 32);
    return topMid + dir / len * 32;
  }

  void _transformDown(Offset screen) {
    final t = c.transform;
    if (t == null) {
      c.beginTransform();
      _mode = _Mode.done;
      return;
    }
    final corners = _screenCorners(t);
    final doc = c.view.toDoc(screen);
    _dragStartDoc = doc;
    _startTranslation = t.translation;
    _startScaleX = t.scaleX;
    _startScaleY = t.scaleY;
    _startRotation = t.rotation;
    final hit = _touches.isNotEmpty ? 26.0 : 14.0;
    if ((_rotateHandle(corners) - screen).distance < hit + 4) {
      _handle = _Handle.rotate;
      return;
    }
    for (var i = 0; i < 4; i++) {
      if ((corners[i] - screen).distance < hit) {
        _handle = _Handle.corner;
        _handleIndex = i;
        return;
      }
    }
    for (var i = 0; i < 4; i++) {
      final mid = (corners[i] + corners[(i + 1) % 4]) / 2;
      if ((mid - screen).distance < hit) {
        _handle = _Handle.side;
        _handleIndex = i;
        return;
      }
    }
    _handle = _inside(corners, screen) ? _Handle.move : _Handle.rotate;
  }

  static bool _inside(List<Offset> polygon, Offset p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  Offset _unrotate(Offset v, double angle) {
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    return Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
  }

  void _transformMove(Offset screen) {
    final t = c.transform;
    final handle = _handle;
    if (t == null || handle == null) return;
    final doc = c.view.toDoc(screen);
    final center = t.box.center + _startTranslation;
    switch (handle) {
      case _Handle.move:
        t.translation = _startTranslation + (doc - _dragStartDoc);
      case _Handle.rotate:
        var angle = _startRotation + (doc - center).direction - (_dragStartDoc - center).direction;
        if (_shift) {
          const step = math.pi / 12;
          angle = (angle / step).round() * step;
        }
        t.rotation = angle;
      case _Handle.corner:
      case _Handle.side:
        final v0 = _unrotate(_dragStartDoc - center, _startRotation);
        final v = _unrotate(doc - center, _startRotation);
        final side = handle == _Handle.side;
        final horizontal = _handleIndex == 1 || _handleIndex == 3;
        if (!side && c.uniformScale != _shift) {
          final denominator = v0.dx * v0.dx + v0.dy * v0.dy;
          if (denominator < 1e-6) return;
          final factor = (v.dx * v0.dx + v.dy * v0.dy) / denominator;
          t.scaleX = _safeScale(_startScaleX * factor);
          t.scaleY = _safeScale(_startScaleY * factor);
        } else {
          if ((!side || horizontal) && v0.dx.abs() > 1e-3) {
            t.scaleX = _safeScale(_startScaleX * v.dx / v0.dx);
          }
          if ((!side || !horizontal) && v0.dy.abs() > 1e-3) {
            t.scaleY = _safeScale(_startScaleY * v.dy / v0.dy);
          }
        }
    }
    c.transformChanged();
  }

  static double _safeScale(double s) {
    if (s.abs() < 0.01) return s.isNegative ? -0.01 : 0.01;
    return s.clamp(-50.0, 50.0);
  }

  // ------------------------------------------------------------------ build

  MouseCursor get _cursor {
    if (_mode == _Mode.pan) return SystemMouseCursors.grabbing;
    return switch (c.tool) {
      SketchTool.brush || SketchTool.eraser || SketchTool.smudge => SystemMouseCursors.none,
      SketchTool.transform => SystemMouseCursors.move,
      _ => SystemMouseCursors.precise,
    };
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        c.view.setViewport(constraints.biggest);
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => MouseRegion(
            cursor: _cursor,
            onHover: (e) => _hover.value = e.localPosition,
            onExit: (_) => _hover.value = null,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onDown,
              onPointerMove: (e) {
                _hover.value = e.kind == PointerDeviceKind.touch ? null : e.localPosition;
                _onMove(e);
              },
              onPointerUp: _onUp,
              onPointerCancel: (e) => _onUp(e, cancelled: true),
              onPointerSignal: _onSignal,
              onPointerPanZoomStart: _onPanZoomStart,
              onPointerPanZoomUpdate: _onPanZoomUpdate,
              onPointerPanZoomEnd: _onPanZoomEnd,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _CanvasPainter(
                    controller: c,
                    hover: _hover,
                    accent: luma.accent,
                    workspace: luma.background,
                    rotateHandle: _rotateHandle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.controller,
    required this.hover,
    required this.accent,
    required this.workspace,
    required this.rotateHandle,
  }) : super(
          repaint: Listenable.merge([
            controller,
            controller.document,
            controller.view,
            controller.live,
            hover,
          ]),
        );

  final StudioController controller;
  final ValueNotifier<Offset?> hover;
  final Color accent;
  final Color workspace;
  final Offset Function(List<Offset> corners) rotateHandle;

  static ui.Image? _checker;

  static ui.Image _checkerImage() {
    final existing = _checker;
    if (existing != null) return existing;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = const Color(0xFFFFFFFF));
    final grey = Paint()..color = const Color(0xFFDCDCE2);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 8), grey);
    canvas.drawRect(const Rect.fromLTWH(8, 8, 8, 8), grey);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(16, 16);
    picture.dispose();
    return _checker = image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final view = c.view;
    final zoom = view.zoom;
    final state = c.state;
    final docRect = c.bounds;

    // Zoomed in, the document is far larger than the viewport; without this
    // it would paint straight over the tool rail and layer panel.
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = workspace);

    canvas.save();
    canvas.transform(view.matrix.storage);
    canvas.drawRect(
      docRect,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 / zoom),
    );
    if (!state.showBackground) {
      final s = 1 / zoom;
      canvas.drawRect(
        docRect,
        Paint()
          ..shader = ImageShader(
            _checkerImage(),
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.diagonal3Values(s, s, 1).storage,
          ),
      );
    }
    canvas.save();
    canvas.clipRect(docRect);
    final quality = zoom < 1
        ? FilterQuality.medium
        : zoom >= 3
            ? FilterQuality.none
            : FilterQuality.low;
    SketchCompositor.paint(canvas, state, docRect, overrides: c.overrides(quality), quality: quality);
    canvas.restore();
    canvas.restore();

    _symmetryGuides(canvas);
    final selection = state.selection;
    if (selection != null && c.transform == null) _ants(canvas, selection);
    final draft = c.selectionDraft;
    if (draft != null) _ants(canvas, draft);
    final shape = c.shapePreview;
    if (shape != null) _outline(canvas, shape);
    final gradient = c.gradientLine;
    if (gradient != null) _gradientGuide(canvas, gradient.$1, gradient.$2);
    final transform = c.transform;
    if (transform != null) _transformBox(canvas, transform);
    _brushCursor(canvas);
    _loupe(canvas);
  }

  Path _toScreen(Path doc) => doc.transform(controller.view.matrix.storage);

  void _ants(Canvas canvas, Path doc) {
    final path = _toScreen(doc);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFFFFF),
    );
    canvas.drawPath(
      _dashed(path, 5, 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF111111),
    );
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      var guard = 0;
      while (d < metric.length && guard++ < 20000) {
        out.addPath(metric.extractPath(d, math.min(d + dash, metric.length)), Offset.zero);
        d += dash + gap;
      }
    }
    return out;
  }

  void _outline(Canvas canvas, Path doc) {
    final path = _toScreen(doc);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x88FFFFFF),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent,
    );
  }

  void _symmetryGuides(Canvas canvas) {
    final c = controller;
    final guides = c.symmetry.guides(c.document.size);
    if (guides.isEmpty) return;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas.save();
    final docPath = Path()..addRect(c.bounds);
    canvas.clipPath(_toScreen(docPath));
    for (final (a, b) in guides) {
      canvas.drawLine(c.view.toScreen(a), c.view.toScreen(b), paint);
    }
    canvas.restore();
    final center = c.view.toScreen(c.symmetry.centerFor(c.document.size));
    canvas.drawCircle(center, 4, Paint()..color = accent);
  }

  void _gradientGuide(Canvas canvas, Offset a, Offset b) {
    final view = controller.view;
    final sa = view.toScreen(a);
    final sb = view.toScreen(b);
    final line = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3;
    canvas.drawLine(sa, sb, line);
    canvas.drawLine(sa, sb, Paint()
      ..color = accent
      ..strokeWidth = 1.5);
    for (final p in [sa, sb]) {
      canvas.drawCircle(p, 6, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(p, 4, Paint()..color = accent);
    }
  }

  void _transformBox(Canvas canvas, TransformSession t) {
    final view = controller.view;
    final corners = [for (final p in t.corners) view.toScreen(p)];
    final outline = Path()..addPolygon(corners, true);
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x66000000));
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = accent);
    final rotate = rotateHandle(corners);
    final topMid = (corners[0] + corners[1]) / 2;
    canvas.drawLine(topMid, rotate, Paint()
      ..color = accent
      ..strokeWidth = 1.3);
    void knob(Offset p, {bool round = false}) {
      final fill = Paint()..color = const Color(0xFFFFFFFF);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent;
      if (round) {
        canvas.drawCircle(p, 7, fill);
        canvas.drawCircle(p, 7, ring);
      } else {
        final r = Rect.fromCenter(center: p, width: 11, height: 11);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, ring);
      }
    }

    for (final p in corners) {
      knob(p);
    }
    for (var i = 0; i < 4; i++) {
      knob((corners[i] + corners[(i + 1) % 4]) / 2);
    }
    knob(rotate, round: true);
  }

  void _brushCursor(Canvas canvas) {
    final position = hover.value;
    final c = controller;
    if (position == null || !c.tool.usesBrush) return;
    final brush = c.brush;
    final radius = math.max(1.5, brush.size * c.view.zoom / 2);
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xCC000000);
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xCCFFFFFF);
    if (radius > 3) {
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(brush.angle * math.pi / 180 + c.view.rotation);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 2 * brush.roundness.clamp(0.05, 1.0),
      );
      canvas.drawOval(rect.inflate(1), light);
      canvas.drawOval(rect, dark);
      canvas.restore();
    }
    canvas.drawCircle(position, 1.5, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(position, 0.8, Paint()..color = const Color(0xFF000000));
  }

  void _loupe(Canvas canvas) {
    final c = controller;
    final at = c.loupeAt;
    final color = c.loupeColor;
    if (at == null) return;
    final center = c.view.toScreen(at) + const Offset(0, -64);
    canvas.drawCircle(center, 30, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(center, 27, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(center, 23, Paint()..color = color ?? const Color(0x00000000));
    if (color == null) {
      canvas.drawLine(
        center + const Offset(-14, 14),
        center + const Offset(14, -14),
        Paint()
          ..color = const Color(0xFFE5484D)
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(center, 30, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent);
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.controller != controller || old.accent != accent || old.workspace != workspace;
}

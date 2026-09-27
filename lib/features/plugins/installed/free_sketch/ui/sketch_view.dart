import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Where the canvas sits in the viewport: pan, zoom, rotation and mirroring.
///
/// Kept apart from the document so panning never rebuilds the panels, and
/// mirroring is a view-only flip — the artist's classic check for a lopsided
/// drawing — that never touches the pixels.
class SketchView extends ChangeNotifier {
  SketchView(this.document);

  final Size document;
  Size _viewport = Size.zero;

  /// Offset of the canvas centre from the viewport centre, in screen pixels.
  Offset _pan = Offset.zero;
  double _zoom = 1;
  double _rotation = 0;
  bool _mirrored = false;
  bool _fitted = false;

  static const minZoom = 0.02;
  static const maxZoom = 64.0;

  Size get viewport => _viewport;
  double get zoom => _zoom;
  double get rotation => _rotation;
  bool get mirrored => _mirrored;

  Offset get _center => Offset(_viewport.width / 2, _viewport.height / 2) + _pan;

  /// Called on every layout. Fits the canvas the first time there is room;
  /// after that the pan is relative to the viewport centre, so a resize keeps
  /// the same part of the drawing in the middle.
  void setViewport(Size size) {
    if (size == _viewport) return;
    _viewport = size;
    if (!_fitted && !size.isEmpty) {
      _fitted = true;
      fit(notify: false);
      // This runs during layout, where listeners may not rebuild; tell them
      // (the zoom readout) once the frame is done.
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Matrix4 get matrix {
    final c = _center;
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(_rotation)
      ..scaleByDouble(_mirrored ? -_zoom : _zoom, _zoom, 1, 1)
      ..translateByDouble(-document.width / 2, -document.height / 2, 0, 1);
  }

  Offset toScreen(Offset doc) {
    var p = doc - Offset(document.width / 2, document.height / 2);
    if (_mirrored) p = Offset(-p.dx, p.dy);
    p *= _zoom;
    final cos = math.cos(_rotation);
    final sin = math.sin(_rotation);
    p = Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos);
    return p + _center;
  }

  Offset toDoc(Offset screen) {
    var p = screen - _center;
    final cos = math.cos(-_rotation);
    final sin = math.sin(-_rotation);
    p = Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos);
    p /= _zoom;
    if (_mirrored) p = Offset(-p.dx, p.dy);
    return p + Offset(document.width / 2, document.height / 2);
  }

  /// Screen-space length of [docLength] canvas pixels.
  double scaleLength(double docLength) => docLength * _zoom;

  void fit({bool notify = true}) {
    if (_viewport.isEmpty) return;
    final sx = (_viewport.width - 48) / document.width;
    final sy = (_viewport.height - 48) / document.height;
    _zoom = math.max(minZoom, math.min(sx, sy));
    _pan = Offset.zero;
    _rotation = 0;
    if (notify) notifyListeners();
  }

  void actualPixels() {
    final focal = Offset(_viewport.width / 2, _viewport.height / 2);
    _setZoomAround(focal, 1);
    notifyListeners();
  }

  void zoomBy(double factor, Offset focal) {
    _setZoomAround(focal, (_zoom * factor).clamp(minZoom, maxZoom));
    notifyListeners();
  }

  void _setZoomAround(Offset focal, double zoom) {
    final anchor = toDoc(focal);
    _zoom = zoom;
    _pan += focal - toScreen(anchor);
  }

  void panBy(Offset delta) {
    _pan += delta;
    notifyListeners();
  }

  void rotateBy(double radians, Offset focal) {
    final anchor = toDoc(focal);
    _rotation = _normalize(_rotation + radians);
    _pan += focal - toScreen(anchor);
    notifyListeners();
  }

  void resetRotation() {
    final focal = Offset(_viewport.width / 2, _viewport.height / 2);
    final anchor = toDoc(focal);
    _rotation = 0;
    _pan += focal - toScreen(anchor);
    notifyListeners();
  }

  void toggleMirror() {
    final focal = Offset(_viewport.width / 2, _viewport.height / 2);
    final anchor = toDoc(focal);
    final mirroredAnchor = Offset(document.width - anchor.dx, anchor.dy);
    _mirrored = !_mirrored;
    _pan += focal - toScreen(mirroredAnchor);
    notifyListeners();
  }

  /// Two-finger gesture: the canvas points first touched stay under the
  /// fingers, whatever they do.
  PinchAnchor beginPinch(Offset a, Offset b) =>
      PinchAnchor(toDoc(a), toDoc(b), a, b, _zoom, _rotation);

  void updatePinch(PinchAnchor anchor, Offset a, Offset b) {
    final startSpan = (anchor.screenB - anchor.screenA).distance;
    final span = (b - a).distance;
    if (startSpan > 1 && span > 1) {
      _zoom = (anchor.zoom * span / startSpan).clamp(minZoom, maxZoom);
    }
    final startAngle = (anchor.screenB - anchor.screenA).direction;
    final angle = (b - a).direction;
    _rotation = _normalize(anchor.rotation + angle - startAngle);
    final docMid = (anchor.docA + anchor.docB) / 2;
    final screenMid = (a + b) / 2;
    _pan += screenMid - toScreen(docMid);
    notifyListeners();
  }

  /// Snaps a near-upright canvas back to exactly upright when a rotation
  /// gesture ends.
  void settleRotation() {
    const snap = 5 * math.pi / 180;
    for (final target in const [0.0, math.pi / 2, math.pi, -math.pi / 2, -math.pi]) {
      if ((_rotation - target).abs() < snap && _rotation != target) {
        final focal = Offset(_viewport.width / 2, _viewport.height / 2);
        final anchor = toDoc(focal);
        _rotation = target == -math.pi ? math.pi : target;
        _pan += focal - toScreen(anchor);
        notifyListeners();
        return;
      }
    }
  }

  static double _normalize(double radians) {
    var r = radians;
    while (r > math.pi) {
      r -= 2 * math.pi;
    }
    while (r <= -math.pi) {
      r += 2 * math.pi;
    }
    return r;
  }
}

class PinchAnchor {
  const PinchAnchor(this.docA, this.docB, this.screenA, this.screenB, this.zoom, this.rotation);

  final Offset docA;
  final Offset docB;
  final Offset screenA;
  final Offset screenB;
  final double zoom;
  final double rotation;
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

import '../model/brush.dart';

/// One pointer sample, in canvas pixels.
class StrokeInput {
  const StrokeInput(this.position, {this.pressure = 1});

  final Offset position;

  /// 0..1. Mice and fingers report 1.
  final double pressure;
}

/// One stamp of the brush tip.
class Dab {
  const Dab({
    required this.center,
    required this.size,
    required this.alpha,
    required this.angle,
    required this.color,
    this.distance = 0,
  });

  final Offset center;

  /// Diameter in canvas pixels.
  final double size;

  /// 0..1, before the stroke's opacity cap.
  final double alpha;

  /// Radians.
  final double angle;
  final Color color;

  /// Arc length along the stroke where this dab sits. End taper is measured
  /// back from the last one.
  final double distance;

  Rect get bounds => Rect.fromCircle(center: center, radius: size * 0.75 + 1);

  Dab copyWith({Offset? center, double? size, double? alpha, double? angle}) =>
      Dab(
        center: center ?? this.center,
        size: size ?? this.size,
        alpha: alpha ?? this.alpha,
        angle: angle ?? this.angle,
        color: color,
        distance: distance,
      );
}

/// Turns a stream of pointer samples into dabs.
///
/// Three stages, in order:
///
/// 1. **StreamLine** — an exponential pull towards the pen that irons out
///    hand wobble. Stronger settings lag more and give smoother curves.
/// 2. **Curve fitting** — the smoothed points are joined with quadratic
///    curves through their midpoints, so a fast flick is a curve rather than
///    a polyline with visible corners.
/// 3. **Dab walk** — the curve is walked in arc length and a dab is dropped
///    every `spacing × diameter`, with the diameter, flow and angle worked
///    out from pressure, taper and jitter at that spot.
///
/// End taper cannot be known until the pen lifts, so the last `taperEnd`
/// worth of dabs is held back as [provisional]: the canvas draws them each
/// frame, and [finish] returns them shrunk into the taper.
class StrokeEngine {
  StrokeEngine({
    required this.brush,
    required this.color,
    this.pressureGamma = 1,
    int? seed,
  }) : _random = math.Random(seed ?? DateTime.now().microsecondsSinceEpoch);

  final BrushPreset brush;
  final Color color;

  /// Pressure curve exponent: below 1 is a soft pen (light touch goes far),
  /// above 1 a firm one.
  final double pressureGamma;

  final math.Random _random;

  Offset? _smoothed;
  double _smoothedPressure = 1;
  Offset? _raw;
  double _rawPressure = 1;

  final _points = <_Point>[];

  /// Where the curve currently ends: the midpoint of the last two points.
  _Point? _curveEnd;

  double _travelled = 0;
  double _toNextDab = 0;
  bool _placedFirst = false;
  Offset? _lastDabCenter;
  double _direction = 0;

  final _tail = <Dab>[];
  bool _finished = false;

  /// Dabs that are laid down but may still shrink into the end taper.
  List<Dab> get provisional => List.unmodifiable(_tail);

  /// Total arc length walked so far.
  double get length => _travelled;

  /// Where the stroke currently ends, after smoothing.
  Offset? get head => _curveEnd?.position ?? _smoothed;

  double get _taperStartLength => brush.taperStart * math.max(brush.size, 3) * 2.5;
  double get _taperEndLength => brush.taperEnd * math.max(brush.size, 3) * 2.5;

  /// Feeds one sample and returns the dabs that are now final.
  List<Dab> add(StrokeInput input) {
    assert(!_finished, 'add() after finish()');
    final pressure = _curve(input.pressure);
    _raw = input.position;
    _rawPressure = pressure;
    final out = <Dab>[];

    final smoothed = _smoothed;
    if (smoothed == null) {
      _smoothed = input.position;
      _smoothedPressure = pressure;
      final point = _Point(input.position, pressure);
      _points.add(point);
      _curveEnd = point;
      _emitAt(point.position, point.pressure, out);
      return _release(out);
    }

    final pull = _pull;
    final next = smoothed + (input.position - smoothed) * pull;
    _smoothedPressure += (pressure - _smoothedPressure) * math.min(1, pull * 1.5);
    if ((next - _points.last.position).distance < 0.35) {
      _smoothed = next;
      return const [];
    }
    _smoothed = next;
    _pushPoint(_Point(next, _smoothedPressure), out);
    return _release(out);
  }

  /// Ends the stroke: lets the smoothing catch up with the pen, then returns
  /// every remaining dab with the end taper applied.
  List<Dab> finish() {
    if (_finished) return const [];
    _finished = true;
    final out = <Dab>[];
    final raw = _raw;
    if (raw != null && _points.isNotEmpty) {
      final from = _points.last.position;
      final gap = (raw - from).distance;
      if (gap > 0.5) {
        final steps = math.max(1, (gap / 4).ceil());
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          _pushPoint(
            _Point(
              Offset.lerp(from, raw, t)!,
              _smoothedPressure + (_rawPressure - _smoothedPressure) * t,
            ),
            out,
          );
        }
      }
      final end = _curveEnd;
      final last = _points.last;
      if (end != null && (last.position - end.position).distance > 0.01) {
        _walkLine(end, last, out);
        _curveEnd = last;
      }
    }
    out.addAll(_tail);
    _tail.clear();

    // A tap with no travel is a dot. Both tapers would otherwise shrink it to
    // a speck, since its one dab sits at distance zero from each end.
    if (_travelled < 1 && (brush.taperStart > 0 || brush.taperEnd > 0)) {
      final at = head;
      if (at != null) {
        out.clear();
        _stamp(at, _smoothedPressure, 0, 1, out);
      }
      return out;
    }

    final taper = _taperEndLength;
    if (taper <= 0) return out;
    final total = _travelled;
    return [
      for (final dab in out)
        if (total - dab.distance >= taper)
          dab
        else
          _tapered(dab, (total - dab.distance) / taper),
    ];
  }

  /// Airbrush build-up: while the pen rests, keep stamping at the head.
  List<Dab> dwell(double seconds) {
    if (!brush.airbrush || _finished) return const [];
    final at = head;
    if (at == null) return const [];
    final count = (seconds * 40).floor().clamp(0, 8);
    final out = <Dab>[];
    for (var i = 0; i < count; i++) {
      _stamp(at, _smoothedPressure, _travelled, 1, out);
    }
    return out;
  }

  double get _pull {
    final s = brush.streamline.clamp(0.0, 1.0);
    return math.max(0.06, 1 - s * 0.93);
  }

  double _curve(double pressure) {
    final p = pressure.isNaN ? 1.0 : pressure.clamp(0.0, 1.0);
    if (pressureGamma == 1) return p;
    return math.pow(p, pressureGamma).toDouble();
  }

  void _pushPoint(_Point point, List<Dab> out) {
    _points.add(point);
    if (_points.length > 3) _points.removeAt(0);
    final n = _points.length;
    if (n < 2) return;
    final prev = _points[n - 2];
    final mid = _Point(
      Offset.lerp(prev.position, point.position, 0.5)!,
      (prev.pressure + point.pressure) / 2,
    );
    final start = _curveEnd ?? prev;
    _walkQuad(start, prev, mid, out);
    _curveEnd = mid;
  }

  void _walkQuad(_Point a, _Point control, _Point b, List<Dab> out) {
    final approx = (control.position - a.position).distance +
        (b.position - control.position).distance;
    final pieces = math.max(1, (approx / 2).ceil());
    var previous = a;
    for (var i = 1; i <= pieces; i++) {
      final t = i / pieces;
      final u = 1 - t;
      final position = a.position * (u * u) +
          control.position * (2 * u * t) +
          b.position * (t * t);
      final pressure = a.pressure * (u * u) +
          control.pressure * (2 * u * t) +
          b.pressure * (t * t);
      final next = _Point(position, pressure);
      _walkLine(previous, next, out);
      previous = next;
    }
  }

  void _walkLine(_Point a, _Point b, List<Dab> out) {
    final delta = b.position - a.position;
    final length = delta.distance;
    if (length <= 0) return;
    _direction = math.atan2(delta.dy, delta.dx);
    var walked = 0.0;
    while (walked + _toNextDab <= length) {
      walked += _toNextDab;
      final t = walked / length;
      final position = a.position + delta * t;
      final pressure = a.pressure + (b.pressure - a.pressure) * t;
      _travelled += _toNextDab;
      _emitAt(position, pressure, out);
    }
    final rest = length - walked;
    _toNextDab -= rest;
    _travelled += rest;
  }

  void _emitAt(Offset position, double pressure, List<Dab> out) {
    final taperStart = _taperStartLength;
    final taper = taperStart > 0 ? _taperCurve(_travelled / taperStart) : 1.0;
    final base = _stamp(position, pressure, _travelled, taper, out);
    final spacing = brush.spacing * base;
    _toNextDab = math.max(0.4, spacing);
    _placedFirst = true;
  }

  /// Stamps [BrushPreset.count] dabs at [position] and returns the unjittered
  /// diameter, which sets the distance to the next stamp.
  double _stamp(
    Offset position,
    double pressure,
    double distance,
    double taper,
    List<Dab> out,
  ) {
    final sizeFactor = 1 - brush.sizePressure * (1 - pressure);
    final flowFactor = 1 - brush.flowPressure * (1 - pressure);
    final diameter = math.max(0.3, brush.size * sizeFactor * taper);
    final alpha = (brush.flow * flowFactor * (0.35 + 0.65 * taper)).clamp(0.0, 1.0);

    final count = math.max(1, brush.count);
    for (var i = 0; i < count; i++) {
      var size = diameter;
      if (brush.sizeJitter > 0) {
        size *= 1 - brush.sizeJitter * _random.nextDouble();
      }
      var center = position;
      if (brush.scatter > 0) {
        final theta = _random.nextDouble() * math.pi * 2;
        final r = math.sqrt(_random.nextDouble()) * brush.scatter * diameter;
        center += Offset(math.cos(theta) * r, math.sin(theta) * r);
      }
      var angle = brush.angle * math.pi / 180;
      switch (brush.angleMode) {
        case BrushAngleMode.fixed:
          break;
        case BrushAngleMode.direction:
          angle += _direction;
        case BrushAngleMode.random:
          angle += _random.nextDouble() * math.pi * 2;
      }
      if (brush.angleJitter > 0) {
        angle += (_random.nextDouble() - 0.5) * math.pi * 2 * brush.angleJitter;
      }
      out.add(
        Dab(
          center: center,
          size: math.max(0.3, size),
          alpha: alpha,
          angle: angle,
          color: brush.colorJitter > 0 ? _jitter(color) : color,
          distance: distance,
        ),
      );
    }
    _lastDabCenter = position;
    return diameter;
  }

  Color _jitter(Color base) {
    final hsv = HSVColor.fromColor(base);
    final amount = brush.colorJitter;
    final hue = (hsv.hue + (_random.nextDouble() - 0.5) * 60 * amount) % 360;
    final value =
        (hsv.value + (_random.nextDouble() - 0.5) * 0.6 * amount).clamp(0.0, 1.0);
    final saturation =
        (hsv.saturation + (_random.nextDouble() - 0.5) * 0.3 * amount).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(hsv.alpha, hue, saturation, value).toColor();
  }

  /// Moves final dabs out of the tail once they are further than the end
  /// taper from the head; they can no longer be affected by it.
  List<Dab> _release(List<Dab> fresh) {
    final taper = _taperEndLength;
    if (taper <= 0) return fresh;
    _tail.addAll(fresh);
    final cut = _travelled - taper;
    var released = 0;
    while (released < _tail.length && _tail[released].distance < cut) {
      released++;
    }
    if (released == 0) return const [];
    final out = _tail.sublist(0, released);
    _tail.removeRange(0, released);
    return out;
  }

  Dab _tapered(Dab dab, double t) {
    final f = _taperCurve(t);
    return dab.copyWith(size: math.max(0.3, dab.size * f), alpha: dab.alpha * (0.35 + 0.65 * f));
  }

  static double _taperCurve(double t) {
    if (t >= 1) return 1;
    if (t <= 0) return 0.08;
    return 0.08 + 0.92 * math.sin(t * math.pi / 2);
  }

  /// Whether a dab has been placed yet; a click with no movement still gets
  /// one, which is what makes a dot.
  bool get hasDabs => _placedFirst;

  Offset? get lastDabCenter => _lastDabCenter;
}

class _Point {
  const _Point(this.position, this.pressure);
  final Offset position;
  final double pressure;
}


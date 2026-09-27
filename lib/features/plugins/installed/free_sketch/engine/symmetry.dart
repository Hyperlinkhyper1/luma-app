import 'dart:math' as math;
import 'dart:ui';

import 'stroke_engine.dart';

enum SymmetryMode {
  off('Off'),
  vertical('Vertical'),
  horizontal('Horizontal'),
  quadrant('Quadrant'),
  radial('Radial');

  const SymmetryMode(this.label);
  final String label;
}

/// Drawing guide that repeats every dab across mirror lines or around a
/// centre. It works on dabs rather than on input points, so textured and
/// rotated tips come out properly mirrored instead of merely repositioned.
class SymmetrySettings {
  const SymmetrySettings({
    this.mode = SymmetryMode.off,
    this.segments = 6,
    this.mirrorRadial = false,
    this.center,
  });

  final SymmetryMode mode;

  /// Copies around the centre in [SymmetryMode.radial].
  final int segments;

  /// Radial mode also mirrors each copy, kaleidoscope style.
  final bool mirrorRadial;

  /// Canvas-space centre; null means the middle of the canvas.
  final Offset? center;

  bool get enabled => mode != SymmetryMode.off;

  SymmetrySettings copyWith({
    SymmetryMode? mode,
    int? segments,
    bool? mirrorRadial,
    Offset? center,
    bool resetCenter = false,
  }) =>
      SymmetrySettings(
        mode: mode ?? this.mode,
        segments: segments ?? this.segments,
        mirrorRadial: mirrorRadial ?? this.mirrorRadial,
        center: resetCenter ? null : (center ?? this.center),
      );

  Offset centerFor(Size canvas) => center ?? Offset(canvas.width / 2, canvas.height / 2);

  /// [dabs] plus every mirrored copy.
  List<Dab> expand(Iterable<Dab> dabs, Size canvas) {
    if (!enabled) return dabs.toList();
    final c = centerFor(canvas);
    final out = <Dab>[];
    for (final dab in dabs) {
      out.add(dab);
      switch (mode) {
        case SymmetryMode.off:
          break;
        case SymmetryMode.vertical:
          out.add(_mirrorX(dab, c));
        case SymmetryMode.horizontal:
          out.add(_mirrorY(dab, c));
        case SymmetryMode.quadrant:
          out.add(_mirrorX(dab, c));
          out.add(_mirrorY(dab, c));
          out.add(_mirrorY(_mirrorX(dab, c), c));
        case SymmetryMode.radial:
          final n = segments.clamp(2, 32);
          for (var k = 0; k < n; k++) {
            final theta = 2 * math.pi * k / n;
            if (k > 0) out.add(_rotate(dab, c, theta));
            if (mirrorRadial) out.add(_rotate(_mirrorX(dab, c), c, theta));
          }
      }
    }
    return out;
  }

  /// Guide lines to draw over the canvas, in canvas space.
  List<(Offset, Offset)> guides(Size canvas) {
    final c = centerFor(canvas);
    final reach = canvas.longestSide * 1.5;
    switch (mode) {
      case SymmetryMode.off:
        return const [];
      case SymmetryMode.vertical:
        return [(Offset(c.dx, -reach), Offset(c.dx, reach))];
      case SymmetryMode.horizontal:
        return [(Offset(-reach, c.dy), Offset(reach, c.dy))];
      case SymmetryMode.quadrant:
        return [
          (Offset(c.dx, -reach), Offset(c.dx, reach)),
          (Offset(-reach, c.dy), Offset(reach, c.dy)),
        ];
      case SymmetryMode.radial:
        final n = segments.clamp(2, 32);
        return [
          for (var k = 0; k < n; k++)
            (
              c,
              c +
                  Offset(
                    math.sin(2 * math.pi * k / n),
                    -math.cos(2 * math.pi * k / n),
                  ) *
                      reach,
            ),
        ];
    }
  }

  static Dab _mirrorX(Dab dab, Offset c) => dab.copyWith(
        center: Offset(2 * c.dx - dab.center.dx, dab.center.dy),
        angle: math.pi - dab.angle,
      );

  static Dab _mirrorY(Dab dab, Offset c) => dab.copyWith(
        center: Offset(dab.center.dx, 2 * c.dy - dab.center.dy),
        angle: -dab.angle,
      );

  static Dab _rotate(Dab dab, Offset c, double theta) {
    final d = dab.center - c;
    final cos = math.cos(theta);
    final sin = math.sin(theta);
    return dab.copyWith(
      center: c + Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos),
      angle: dab.angle + theta,
    );
  }

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'segments': segments,
        'mirrorRadial': mirrorRadial,
      };

  static SymmetrySettings fromJson(Object? json) {
    if (json is! Map) return const SymmetrySettings();
    return SymmetrySettings(
      mode: SymmetryMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => SymmetryMode.off,
      ),
      segments: (json['segments'] as num?)?.toInt() ?? 6,
      mirrorRadial: json['mirrorRadial'] == true,
    );
  }
}

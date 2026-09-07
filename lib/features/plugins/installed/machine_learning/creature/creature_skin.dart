import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'creature_model.dart';
import 'creature_physics.dart';

/// Sticks the drawn outline onto the bones so the creature that walks is the
/// creature that was drawn, not an abstract stick figure.
///
/// Every outline point is pinned to the bone it sat closest to in the drawn
/// pose — how far along it, and how far off to the side. Replaying that
/// binding against the live bone positions carries the drawing with the body.
class CreatureSkin {
  CreatureSkin._(this._strokes);

  final List<_BoundStroke> _strokes;

  static CreatureSkin bind(CreatureShape shape) {
    final strokes = <_BoundStroke>[];
    for (final outline in shape.outline) {
      final count = outline.length ~/ 2;
      if (count < 2) continue;
      final bone = Int32List(count);
      final along = Float64List(count);
      final offset = Float64List(count);
      for (var i = 0; i < count; i++) {
        final px = outline[i * 2];
        final py = outline[i * 2 + 1];
        var bestBone = 0;
        var bestDistance = double.infinity;
        var bestAlong = 0.0;
        var bestOffset = 0.0;
        for (var b = 0; b < shape.boneCount; b++) {
          final ax = shape.nodeX[shape.boneA[b]];
          final ay = shape.nodeY[shape.boneA[b]];
          final bx = shape.nodeX[shape.boneB[b]];
          final by = shape.nodeY[shape.boneB[b]];
          final dx = bx - ax;
          final dy = by - ay;
          final lengthSquared = dx * dx + dy * dy;
          if (lengthSquared < 1e-12) continue;
          final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared)
              .clamp(0.0, 1.0);
          final cx = ax + dx * t;
          final cy = ay + dy * t;
          final distance = (px - cx) * (px - cx) + (py - cy) * (py - cy);
          if (distance >= bestDistance) continue;
          bestDistance = distance;
          bestBone = b;
          bestAlong = t;
          final length = math.sqrt(lengthSquared);
          bestOffset = ((px - cx) * -dy + (py - cy) * dx) / length;
        }
        bone[i] = bestBone;
        along[i] = bestAlong;
        offset[i] = bestOffset;
      }
      strokes.add(_BoundStroke(bone, along, offset));
    }
    return CreatureSkin._(strokes);
  }

  /// The outline where it is right now, in world metres.
  List<List<Offset>> pose(CreatureShape shape, CreatureSim sim) {
    final out = <List<Offset>>[];
    for (final stroke in _strokes) {
      final points = <Offset>[];
      for (var i = 0; i < stroke.bone.length; i++) {
        final b = stroke.bone[i];
        final ax = sim.x[shape.boneA[b]];
        final ay = sim.y[shape.boneA[b]];
        final dx = sim.x[shape.boneB[b]] - ax;
        final dy = sim.y[shape.boneB[b]] - ay;
        final length = math.sqrt(dx * dx + dy * dy);
        if (length < 1e-9) {
          points.add(Offset(ax, ay));
          continue;
        }
        final t = stroke.along[i];
        final o = stroke.offset[i] / length;
        points.add(
          Offset(ax + dx * t - dy * o, ay + dy * t + dx * o),
        );
      }
      out.add(points);
    }
    return out;
  }
}

class _BoundStroke {
  const _BoundStroke(this.bone, this.along, this.offset);
  final Int32List bone;
  final Float64List along;
  final Float64List offset;
}

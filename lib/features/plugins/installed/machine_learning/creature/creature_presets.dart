import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Ready-made bodies, so someone who does not feel like drawing can still see
/// the thing learn to walk. Coordinates are 0..1 across the drawing board with
/// y pointing down, exactly like a hand-drawn stroke.
class CreaturePreset {
  const CreaturePreset(this.name, this.strokes);

  final String name;
  final List<List<Offset>> strokes;

  static List<Offset> _arc(
    double cx,
    double cy,
    double rx,
    double ry, {
    int steps = 28,
  }) =>
      [
        for (var i = 0; i < steps; i++)
          Offset(
            cx + math.cos(i / steps * math.pi * 2) * rx,
            cy + math.sin(i / steps * math.pi * 2) * ry,
          ),
      ];

  static List<CreaturePreset> get all => [
        CreaturePreset('Blob', [_arc(0.5, 0.55, 0.28, 0.2)]),
        const CreaturePreset('Person', [
          [Offset(0.5, 0.2), Offset(0.5, 0.55)],
          [Offset(0.5, 0.3), Offset(0.32, 0.46)],
          [Offset(0.5, 0.3), Offset(0.68, 0.46)],
          [Offset(0.5, 0.55), Offset(0.38, 0.85)],
          [Offset(0.5, 0.55), Offset(0.62, 0.85)],
        ]),
        const CreaturePreset('Letter A', [
          [Offset(0.28, 0.85), Offset(0.5, 0.18), Offset(0.72, 0.85)],
          [Offset(0.37, 0.58), Offset(0.63, 0.58)],
        ]),
        CreaturePreset('Spider', [
          _arc(0.5, 0.45, 0.12, 0.09, steps: 20),
          [const Offset(0.4, 0.48), const Offset(0.2, 0.6), const Offset(0.16, 0.84)],
          [const Offset(0.44, 0.52), const Offset(0.3, 0.7), const Offset(0.3, 0.86)],
          [const Offset(0.56, 0.52), const Offset(0.7, 0.7), const Offset(0.7, 0.86)],
          [const Offset(0.6, 0.48), const Offset(0.8, 0.6), const Offset(0.84, 0.84)],
        ]),
        const CreaturePreset('Dog', [
          [Offset(0.24, 0.45), Offset(0.72, 0.45)],
          [Offset(0.72, 0.45), Offset(0.8, 0.3)],
          [Offset(0.8, 0.3), Offset(0.88, 0.36)],
          [Offset(0.24, 0.45), Offset(0.16, 0.32)],
          [Offset(0.3, 0.45), Offset(0.3, 0.84)],
          [Offset(0.42, 0.45), Offset(0.42, 0.84)],
          [Offset(0.6, 0.45), Offset(0.6, 0.84)],
          [Offset(0.7, 0.45), Offset(0.7, 0.84)],
        ]),
        CreaturePreset('Worm', [
          [
            for (var i = 0; i <= 24; i++)
              Offset(0.14 + i / 24 * 0.72, 0.55 + math.sin(i / 24 * math.pi * 3) * 0.1),
          ],
        ]),
      ];
}

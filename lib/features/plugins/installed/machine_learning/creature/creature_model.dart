import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

/// A creature's body, in metres, with the ground at y = 0 and y pointing up.
///
/// Everything here is plain numeric data so a whole shape can be handed to a
/// background isolate without any conversion step — see
/// `evolution.dart`, which evaluates a population off the UI thread.
///
/// The body is a graph: [nodeX]/[nodeY] are the joint positions, bones connect
/// two nodes each, and a joint is a *pair* of bones that share a node. The
/// joints form a tree rooted at the bone nearest the body's centre, so every
/// joint knows exactly which part of the body swings when it rotates
/// ([jointSubtree]) and which part pushes back ([jointAnchor]).
class CreatureShape {
  CreatureShape({
    required this.nodeX,
    required this.nodeY,
    required this.nodeRadius,
    required this.nodeMass,
    required this.boneA,
    required this.boneB,
    required this.boneThickness,
    required this.jointParentBone,
    required this.jointChildBone,
    required this.jointPivot,
    required this.jointRestAngle,
    required this.jointSubtree,
    required this.jointAnchor,
    required this.jointSubtreeMassFraction,
    required this.headNode,
    required this.outline,
    required this.drawingScale,
    required this.drawingCentreX,
    required this.drawingBaseY,
  });

  final Float64List nodeX;
  final Float64List nodeY;

  /// Half the thickness of the fattest bone meeting at this node — the radius
  /// the node collides with the ground at.
  final Float64List nodeRadius;

  /// Mass of the node, spread from the bones that meet at it — a thick torso
  /// node is heavy, a fingertip is not.
  final Float64List nodeMass;

  final Int32List boneA;
  final Int32List boneB;
  final Float64List boneThickness;

  final Int32List jointParentBone;
  final Int32List jointChildBone;
  final Int32List jointPivot;

  /// Angle between parent and child bone in the drawn pose. Motors steer
  /// relative to this, so a creature starts each trial already relaxed.
  final Float64List jointRestAngle;

  /// Nodes that rotate with the child bone, pivot excluded.
  final List<Int32List> jointSubtree;

  /// The rest of the body, which takes the equal and opposite rotation.
  final List<Int32List> jointAnchor;

  /// How much of the body's mass hangs off the child side. A light limb swings
  /// against a heavy body; two halves of equal weight both move.
  final Float64List jointSubtreeMassFraction;

  /// Topmost node in the drawn pose. Used for the head-down penalty, so a
  /// creature that face-plants and shuffles forward does not win.
  final int headNode;

  /// The drawn strokes in world coordinates, flat x,y pairs, kept only to
  /// paint the creature's skin over the bones.
  final List<Float64List> outline;

  /// Metres per unit of the drawing board, plus the board point that maps to
  /// world (0, 0). Together they let the lab paint the extracted skeleton
  /// back over the sketch it came from, exactly aligned.
  final double drawingScale;
  final double drawingCentreX;
  final double drawingBaseY;

  /// The board point that this world position was built from.
  Offset toDrawing(double worldX, double worldY) => Offset(
        worldX / drawingScale + drawingCentreX,
        drawingBaseY - worldY / drawingScale,
      );

  int get nodeCount => nodeX.length;
  int get boneCount => boneA.length;
  int get jointCount => jointPivot.length;

  /// One gene for the gait's frequency, then amplitude / phase / centre for
  /// every joint.
  int get geneCount => 1 + 3 * jointCount;

  double get height {
    var top = 0.0;
    for (final y in nodeY) {
      if (y > top) top = y;
    }
    return top;
  }
}

/// Decodes a genome — all genes live in 0..1 so mutation and crossover never
/// have to know what a gene means — into the numbers the motors run on.
class Gait {
  Gait(this.genes, int jointCount)
      : frequency = 0.6 + genes[0] * 3.4,
        amplitude = Float64List(jointCount),
        phase = Float64List(jointCount),
        centre = Float64List(jointCount) {
    for (var j = 0; j < jointCount; j++) {
      amplitude[j] = genes[1 + j * 3] * 1.5;
      phase[j] = genes[2 + j * 3] * math.pi * 2;
      centre[j] = (genes[3 + j * 3] * 2 - 1) * 0.9;
    }
  }

  final Float64List genes;

  /// Steps per second of the whole body, shared by every joint so limbs stay
  /// in step with each other instead of drifting into noise.
  final double frequency;

  final Float64List amplitude;
  final Float64List phase;
  final Float64List centre;

  double targetAngle(int joint, double restAngle, double time) =>
      restAngle +
      centre[joint] +
      amplitude[joint] *
          math.sin(math.pi * 2 * frequency * time + phase[joint]);
}

/// Fresh random genes in 0..1.
Float64List randomGenes(int count, math.Random rng) {
  final genes = Float64List(count);
  for (var i = 0; i < count; i++) {
    genes[i] = rng.nextDouble();
  }
  return genes;
}

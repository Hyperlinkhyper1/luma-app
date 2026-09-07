import 'dart:math' as math;
import 'dart:typed_data';

import 'creature_model.dart';

/// The rules of the walking trial. Identical on the UI thread and in the
/// background workers, so a replay traces the exact run that scored.
class TrialConfig {
  const TrialConfig({
    this.seconds = 25,
    this.goalMetres = 50,
    this.stepsPerSecond = 100,
    this.gravity = 9.81,
    this.friction = 0.9,
    this.motorStiffness = 320,
    this.motorDamping = 34,
    this.maxAngularAccel = 130,
    this.constraintPasses = 3,
  });

  final double seconds;
  final double goalMetres;
  final int stepsPerSecond;
  final double gravity;

  /// How much of a foot's sideways speed the ground eats on contact. Enough
  /// grip to push off, not so much that sliding is impossible.
  final double friction;

  /// A joint is a spring-damper chasing its target angle, not a hand that
  /// puts the limb where it wants. [motorStiffness] is how hard it pulls,
  /// [motorDamping] stops it oscillating, and [maxAngularAccel] is the muscle
  /// it has to do it with — without that ceiling a creature could fling
  /// itself the length of the course in one frame.
  final double motorStiffness;
  final double motorDamping;
  final double maxAngularAccel;

  final int constraintPasses;

  double get dt => 1 / stepsPerSecond;
  int get totalSteps => (seconds * stepsPerSecond).round();
}

/// What one creature managed in one trial.
class TrialOutcome {
  const TrialOutcome({
    required this.distance,
    required this.headDownSeconds,
    required this.finishSeconds,
    required this.fitness,
  });

  /// Metres the centre of mass moved forward.
  final double distance;

  /// Seconds spent with the head on the floor. Penalised, so face-planting
  /// and shuffling never beats walking.
  final double headDownSeconds;

  /// When the creature crossed the goal line, or -1 if it never did.
  final double finishSeconds;

  final double fitness;

  bool get finished => finishSeconds >= 0;
}

/// A creature, mid-walk. Rigid bones held by distance constraints, driven by
/// one sine-wave motor per joint, integrated with Verlet.
///
/// Every step is deterministic: the same shape and the same genes always walk
/// the same walk, which is what lets the viewport replay any generation's
/// champion exactly as it was scored.
class CreatureSim {
  CreatureSim(this.shape, Float64List genes, {this.config = const TrialConfig()})
      : gait = Gait(genes, shape.jointCount),
        _x = Float64List.fromList(shape.nodeX),
        _y = Float64List.fromList(shape.nodeY),
        _px = Float64List.fromList(shape.nodeX),
        _py = Float64List.fromList(shape.nodeY),
        _invMass = Float64List(shape.nodeCount),
        _restLength = Float64List(shape.boneCount),
        _lastAngle = Float64List(shape.jointCount),
        _deformX = Float64List(shape.nodeCount),
        _deformY = Float64List(shape.nodeCount) {
    for (var i = 0; i < shape.nodeCount; i++) {
      _invMass[i] = 1 / shape.nodeMass[i];
    }
    for (var b = 0; b < shape.boneCount; b++) {
      final a = shape.boneA[b];
      final c = shape.boneB[b];
      _restLength[b] = math.sqrt(
        _sq(shape.nodeX[a] - shape.nodeX[c]) +
            _sq(shape.nodeY[a] - shape.nodeY[c]),
      );
    }
    _startX = centreOfMassX;
    _headStartY = shape.nodeY[shape.headNode];
  }

  final CreatureShape shape;
  final Gait gait;
  final TrialConfig config;

  final Float64List _x;
  final Float64List _y;
  final Float64List _px;
  final Float64List _py;
  final Float64List _invMass;
  final Float64List _restLength;
  final Float64List _lastAngle;
  final Float64List _deformX;
  final Float64List _deformY;
  bool _angleKnown = false;

  late final double _startX;
  late final double _headStartY;

  double time = 0;
  double headDownSeconds = 0;
  double finishSeconds = -1;
  bool _broken = false;

  /// Live node positions, for painting. Read only.
  Float64List get x => _x;
  Float64List get y => _y;

  double get centreOfMassX {
    var sum = 0.0;
    var mass = 0.0;
    for (var i = 0; i < shape.nodeCount; i++) {
      sum += _x[i] * shape.nodeMass[i];
      mass += shape.nodeMass[i];
    }
    return sum / mass;
  }

  double get _centreOfMassY {
    var sum = 0.0;
    var mass = 0.0;
    for (var i = 0; i < shape.nodeCount; i++) {
      sum += _y[i] * shape.nodeMass[i];
      mass += shape.nodeMass[i];
    }
    return sum / mass;
  }

  double get distance => centreOfMassX - _startX;

  bool get done =>
      _broken || finishSeconds >= 0 || time >= config.seconds - 1e-9;

  /// Advances one fixed step. Motors first, then the bones are made rigid
  /// again, then the ground gets its say.
  void step() {
    if (done) return;
    final dt = config.dt;
    _integrate(dt);
    _driveMotors();
    for (var pass = 0; pass < config.constraintPasses; pass++) {
      _solveBones();
    }
    _collideGround();
    time += dt;

    if (_y[shape.headNode] < _headStartY * 0.4) headDownSeconds += dt;
    if (!_broken && distance >= config.goalMetres) finishSeconds = time;
    if (!_x[0].isFinite || !_y[0].isFinite) _broken = true;
  }

  /// Verlet, with a speed limit that only applies to how fast the body may
  /// deform. Clamping each node outright would quietly move the whole
  /// creature — the limiter measures every node against the body's own
  /// velocity instead, so it can never invent travel.
  void _integrate(double dt) {
    const damping = 0.999;
    const maxDeform = 0.1;
    const maxTravel = 0.3;
    final fall = config.gravity * dt * dt;

    var bodyVx = 0.0;
    var bodyVy = 0.0;
    var mass = 0.0;
    for (var i = 0; i < _x.length; i++) {
      final m = shape.nodeMass[i];
      bodyVx += (_x[i] - _px[i]) * m;
      bodyVy += (_y[i] - _py[i]) * m;
      mass += m;
    }
    bodyVx = (bodyVx / mass) * damping;
    bodyVy = (bodyVy / mass) * damping;
    bodyVx = bodyVx.clamp(-maxTravel, maxTravel);
    bodyVy = bodyVy.clamp(-maxTravel, maxTravel);

    // Clamping is lopsided, so whatever momentum it shaved off is taken back
    // out of the average before it is applied.
    var driftX = 0.0;
    var driftY = 0.0;
    for (var i = 0; i < _x.length; i++) {
      _deformX[i] =
          ((_x[i] - _px[i]) * damping - bodyVx).clamp(-maxDeform, maxDeform);
      _deformY[i] =
          ((_y[i] - _py[i]) * damping - bodyVy).clamp(-maxDeform, maxDeform);
      driftX += _deformX[i] * shape.nodeMass[i];
      driftY += _deformY[i] * shape.nodeMass[i];
    }
    driftX /= mass;
    driftY /= mass;

    for (var i = 0; i < _x.length; i++) {
      _px[i] = _x[i];
      _py[i] = _y[i];
      _x[i] += bodyVx + _deformX[i] - driftX;
      _y[i] += bodyVy + _deformY[i] - driftY - fall;
    }
  }

  /// Each joint steers the angle between its two bones towards
  /// `rest + centre + amplitude * sin(...)`. The limb swings one way and the
  /// rest of the body takes the recoil, split by mass — that reaction is what
  /// actually pushes the creature along the ground.
  ///
  /// The motor works in angular *acceleration*, capped, so a joint has finite
  /// strength: a gait has to be found, it cannot be teleported into.
  void _driveMotors() {
    final dt = config.dt;
    final beforeX = centreOfMassX;
    final beforeY = _centreOfMassY;
    for (var j = 0; j < shape.jointCount; j++) {
      final pivot = shape.jointPivot[j];
      final parent = shape.jointParentBone[j];
      final child = shape.jointChildBone[j];
      final parentFar =
          shape.boneA[parent] == pivot ? shape.boneB[parent] : shape.boneA[parent];
      final childFar =
          shape.boneA[child] == pivot ? shape.boneB[child] : shape.boneA[child];

      final ux = _x[parentFar] - _x[pivot];
      final uy = _y[parentFar] - _y[pivot];
      final vx = _x[childFar] - _x[pivot];
      final vy = _y[childFar] - _y[pivot];
      final current = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
      final target = gait.targetAngle(j, shape.jointRestAngle[j], time);

      final error = _wrapAngle(target - current);
      final velocity = _angleKnown ? _wrapAngle(current - _lastAngle[j]) / dt : 0.0;
      _lastAngle[j] = current;

      var accel =
          config.motorStiffness * error - config.motorDamping * velocity;
      if (accel > config.maxAngularAccel) accel = config.maxAngularAccel;
      if (accel < -config.maxAngularAccel) accel = -config.maxAngularAccel;

      // Verlet turns an acceleration into a position nudge of a*dt^2, and a
      // rigid turn of that many radians is exactly that nudge for every node
      // in the limb.
      final turn = accel * dt * dt;
      if (turn.abs() < 1e-9) continue;

      final fraction = shape.jointSubtreeMassFraction[j];
      _rotate(shape.jointSubtree[j], pivot, turn * (1 - fraction));
      _rotate(shape.jointAnchor[j], pivot, -turn * fraction);
    }
    _angleKnown = true;

    // Rotating a limb about a joint shifts the body's centre of mass, and
    // nothing a creature does to itself is allowed to do that — otherwise it
    // can swim through empty air, which is the first thing evolution finds.
    // Putting the centre of mass back leaves only the ground to push against.
    final shiftX = centreOfMassX - beforeX;
    final shiftY = _centreOfMassY - beforeY;
    if (shiftX == 0 && shiftY == 0) return;
    for (var i = 0; i < _x.length; i++) {
      _x[i] -= shiftX;
      _y[i] -= shiftY;
    }
  }

  static double _wrapAngle(double angle) {
    var a = angle % (math.pi * 2);
    if (a > math.pi) a -= math.pi * 2;
    if (a < -math.pi) a += math.pi * 2;
    return a;
  }

  void _rotate(Int32List nodes, int pivot, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final ox = _x[pivot];
    final oy = _y[pivot];
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final dx = _x[n] - ox;
      final dy = _y[n] - oy;
      _x[n] = ox + dx * cos - dy * sin;
      _y[n] = oy + dx * sin + dy * cos;
    }
  }

  void _solveBones() {
    for (var b = 0; b < shape.boneCount; b++) {
      final a = shape.boneA[b];
      final c = shape.boneB[b];
      final dx = _x[c] - _x[a];
      final dy = _y[c] - _y[a];
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1e-9) continue;
      final w = _invMass[a] + _invMass[c];
      final correction = (d - _restLength[b]) / d / w;
      _x[a] += dx * correction * _invMass[a];
      _y[a] += dy * correction * _invMass[a];
      _x[c] -= dx * correction * _invMass[c];
      _y[c] -= dy * correction * _invMass[c];
    }
  }

  /// Coulomb friction: the ground can only hold a foot as hard as that foot
  /// presses down. Without the normal-force cap a feather-light limb grips
  /// like a boot, and evolution finds that exploit immediately instead of
  /// learning to walk.
  void _collideGround() {
    final dt = config.dt;
    final gravityStep = config.gravity * dt * dt;
    for (var i = 0; i < _x.length; i++) {
      final floor = shape.nodeRadius[i];
      if (_y[i] >= floor) continue;
      final penetration = floor - _y[i];
      _y[i] = floor;
      if (_py[i] < _y[i]) _py[i] = _y[i];
      final vx = _x[i] - _px[i];
      if (vx == 0) continue;
      final grip = config.friction * (penetration + gravityStep);
      final slow = math.min(vx.abs(), grip);
      _px[i] = _x[i] - (vx - (vx.isNegative ? -slow : slow));
    }
  }

  static double _sq(double v) => v * v;
}

/// Runs one creature's whole trial and scores it.
///
/// Fitness is metres walked, docked for time spent head-down, with a bonus
/// for every second saved once the goal line is crossed — so evolution keeps
/// improving after a creature first makes the distance.
TrialOutcome runTrial(
  CreatureShape shape,
  Float64List genes, {
  TrialConfig config = const TrialConfig(),
}) {
  final sim = CreatureSim(shape, genes, config: config);
  final steps = config.totalSteps;
  for (var i = 0; i < steps && !sim.done; i++) {
    sim.step();
  }
  final distance = sim.distance;
  if (!distance.isFinite) {
    return const TrialOutcome(
      distance: 0,
      headDownSeconds: 0,
      finishSeconds: -1,
      fitness: -10,
    );
  }
  final capped = distance.clamp(-5.0, config.goalMetres);
  var fitness = capped - sim.headDownSeconds * 0.6;
  if (sim.finishSeconds >= 0) {
    fitness += (config.seconds - sim.finishSeconds) * 2;
  }
  return TrialOutcome(
    distance: distance,
    headDownSeconds: sim.headDownSeconds,
    finishSeconds: sim.finishSeconds,
    fitness: fitness,
  );
}

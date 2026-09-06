import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/machine_learning/creature/creature_model.dart';
import 'package:luma/features/plugins/installed/machine_learning/creature/creature_physics.dart';
import 'package:luma/features/plugins/installed/machine_learning/creature/evolution.dart';
import 'package:luma/features/plugins/installed/machine_learning/creature/shape_skeleton.dart';

/// A two-legged stick figure: a spine with two legs, drawn the way a user
/// would draw it.
List<List<Offset>> _stickFigure() => [
      [const Offset(100, 20), const Offset(100, 110)],
      [const Offset(100, 110), const Offset(60, 190)],
      [const Offset(100, 110), const Offset(140, 190)],
    ];

/// A filled blob, to prove a closed shape gets a skeleton too.
List<List<Offset>> _blob() {
  final points = <Offset>[];
  for (var i = 0; i < 40; i++) {
    final a = i / 40 * math.pi * 2;
    points.add(Offset(120 + math.cos(a) * 80, 100 + math.sin(a) * 35));
  }
  return [points];
}

CreatureShape _buildStickFigure() {
  final shape = ShapeSkeleton.build(_stickFigure());
  expect(shape, isNotNull);
  return shape!;
}

/// The same body, floating well above the floor. Used with zero gravity it
/// isolates the creature's own motion: with nothing to push against, the
/// centre of mass must not move at all.
CreatureShape _liftClearOfTheGround(CreatureShape shape) => CreatureShape(
      nodeX: shape.nodeX,
      nodeY: Float64List.fromList([for (final y in shape.nodeY) y + 5]),
      nodeRadius: shape.nodeRadius,
      nodeMass: shape.nodeMass,
      boneA: shape.boneA,
      boneB: shape.boneB,
      boneThickness: shape.boneThickness,
      jointParentBone: shape.jointParentBone,
      jointChildBone: shape.jointChildBone,
      jointPivot: shape.jointPivot,
      jointRestAngle: shape.jointRestAngle,
      jointSubtree: shape.jointSubtree,
      jointAnchor: shape.jointAnchor,
      jointSubtreeMassFraction: shape.jointSubtreeMassFraction,
      headNode: shape.headNode,
      outline: shape.outline,
      drawingScale: shape.drawingScale,
      drawingCentreX: shape.drawingCentreX,
      drawingBaseY: shape.drawingBaseY,
    );

void main() {
  group('skeleton extraction', () {
    test('a stick figure becomes a jointed body', () {
      final shape = _buildStickFigure();
      expect(shape.boneCount, greaterThanOrEqualTo(3));
      expect(shape.jointCount, greaterThanOrEqualTo(2));
      expect(shape.nodeCount, greaterThanOrEqualTo(4));
    });

    test('a filled blob still yields at least one joint to drive', () {
      final shape = ShapeSkeleton.build(_blob());
      expect(shape, isNotNull);
      expect(shape!.boneCount, greaterThanOrEqualTo(2));
      expect(shape.jointCount, greaterThanOrEqualTo(1));
    });

    test('scribbles too small to be a creature are refused', () {
      expect(ShapeSkeleton.build([]), isNull);
      expect(ShapeSkeleton.build([[const Offset(5, 5)]]), isNull);
    });

    test('the body stands on the ground, scaled to a walkable size', () {
      final shape = _buildStickFigure();
      for (var i = 0; i < shape.nodeCount; i++) {
        expect(shape.nodeY[i] - shape.nodeRadius[i], greaterThanOrEqualTo(-1e-9));
      }
      expect(shape.height, greaterThan(0.2));
      expect(shape.height, lessThan(ShapeSkeleton.targetSize + 0.3));
    });

    test('the head is the highest node in the drawn pose', () {
      final shape = _buildStickFigure();
      for (var i = 0; i < shape.nodeCount; i++) {
        expect(shape.nodeY[shape.headNode], greaterThanOrEqualTo(shape.nodeY[i]));
      }
    });

    test('every joint splits the body into a swinging half and an anchor', () {
      final shape = _buildStickFigure();
      for (var j = 0; j < shape.jointCount; j++) {
        final pivot = shape.jointPivot[j];
        final swing = shape.jointSubtree[j];
        final anchor = shape.jointAnchor[j];
        expect(swing, isNotEmpty);
        expect(anchor, isNotEmpty);
        expect(swing.contains(pivot), isFalse);
        expect(anchor.contains(pivot), isFalse);
        for (final n in swing) {
          expect(anchor.contains(n), isFalse);
        }
        expect(swing.length + anchor.length + 1, shape.nodeCount);
      }
      expect(shape.geneCount, 1 + 3 * shape.jointCount);
    });

    test('bone count stays inside the search budget', () {
      final messy = [
        for (var i = 0; i < 12; i++)
          [
            const Offset(120, 120),
            Offset(120 + math.cos(i * 0.52) * 90, 120 + math.sin(i * 0.52) * 90),
          ],
      ];
      final shape = ShapeSkeleton.build(messy);
      expect(shape, isNotNull);
      expect(shape!.boneCount, lessThanOrEqualTo(ShapeSkeleton.maxBones));
    });
  });

  group('walking trial', () {
    const quick = TrialConfig(seconds: 3);

    test('the same genes always walk the same walk', () {
      final shape = _buildStickFigure();
      final genes = randomGenes(shape.geneCount, math.Random(7));
      final first = runTrial(shape, genes, config: quick);
      final second = runTrial(shape, genes, config: quick);
      expect(first.distance, second.distance);
      expect(first.fitness, second.fitness);
    });

    test('a creature that never moves its joints barely travels', () {
      final shape = _buildStickFigure();
      final still = Float64List(shape.geneCount);
      for (var i = 0; i < still.length; i++) {
        still[i] = 0.5;
      }
      still[0] = 0;
      for (var j = 0; j < shape.jointCount; j++) {
        still[1 + j * 3] = 0;
      }
      final outcome = runTrial(shape, still, config: quick);
      expect(outcome.distance.abs(), lessThan(1.0));
      expect(outcome.fitness.isFinite, isTrue);
    });

    test('the simulation never blows up into infinities', () {
      final shape = _buildStickFigure();
      final rng = math.Random(3);
      for (var i = 0; i < 12; i++) {
        final outcome = runTrial(
          shape,
          randomGenes(shape.geneCount, rng),
          config: quick,
        );
        expect(outcome.distance.isFinite, isTrue);
        expect(outcome.fitness.isFinite, isTrue);
        expect(outcome.distance.abs(), lessThan(quick.goalMetres + 1));
      }
    });

    test('nothing a creature does to itself moves it through the air', () {
      final shape = _liftClearOfTheGround(_buildStickFigure());
      final sim = CreatureSim(
        shape,
        randomGenes(shape.geneCount, math.Random(9)),
        config: const TrialConfig(seconds: 4, gravity: 0),
      );
      final start = sim.centreOfMassX;
      while (!sim.done) {
        sim.step();
      }
      expect(sim.centreOfMassX, closeTo(start, 1e-9));
    });

    test('a trial stops at the goal line and records when it got there', () {
      final shape = _buildStickFigure();
      final sim = CreatureSim(
        shape,
        randomGenes(shape.geneCount, math.Random(1)),
        config: const TrialConfig(seconds: 2, goalMetres: 0.0001),
      );
      while (!sim.done) {
        sim.step();
      }
      expect(sim.time, lessThanOrEqualTo(2.0 + 1e-9));
    });
  });

  group('evolution', () {
    test('breeding keeps the population size and the best genome', () {
      final rng = math.Random(11);
      const config = EvolutionConfig(population: 20, elite: 3);
      final population = seedPopulation(20, 7, rng);
      final fitness = [for (var i = 0; i < 20; i++) i.toDouble()];
      final next = breed(population, fitness, config, rng);
      expect(next.length, 20);
      expect(next.first, population[19]);
      for (final genome in next) {
        for (final gene in genome) {
          expect(gene, inInclusiveRange(0, 1));
        }
      }
    });

    test('generations get better at walking, not worse', () {
      final shape = _buildStickFigure();
      const config = EvolutionConfig(
        population: 16,
        elite: 2,
        immigrants: 1,
        trial: TrialConfig(seconds: 2),
      );
      final rng = math.Random(5);
      var population = seedPopulation(config.population, shape.geneCount, rng);
      var firstBest = double.negativeInfinity;
      var lastBest = double.negativeInfinity;
      for (var generation = 0; generation < 12; generation++) {
        final fitness = [
          for (final genes in population)
            runTrial(shape, genes, config: config.trial).fitness,
        ];
        lastBest = fitness.reduce(math.max);
        if (generation == 0) firstBest = lastBest;
        population = breed(population, fitness, config, rng);
      }
      expect(lastBest, greaterThanOrEqualTo(firstBest));
    });
  });
}

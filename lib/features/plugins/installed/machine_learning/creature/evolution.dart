import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'creature_model.dart';
import 'creature_physics.dart';

/// How the search is run: how many creatures are tried at once, how many
/// survive, and how hard their children are shaken up.
class EvolutionConfig {
  const EvolutionConfig({
    this.population = 60,
    this.elite = 4,
    this.immigrants = 5,
    this.tournament = 3,
    this.mutationRate = 0.3,
    this.mutationSigma = 0.25,
    this.crossoverRate = 0.75,
    this.trial = const TrialConfig(),
  });

  final int population;

  /// Best genomes carried into the next generation untouched, so a good walk
  /// is never lost to a bad roll.
  final int elite;

  /// Fresh random genomes each generation. Cheap insurance against the whole
  /// population converging on one mediocre hop.
  final int immigrants;

  final int tournament;
  final double mutationRate;
  final double mutationSigma;
  final double crossoverRate;
  final TrialConfig trial;
}

/// What one generation came to.
class GenerationResult {
  const GenerationResult({
    required this.index,
    required this.best,
    required this.mean,
    required this.championGenes,
    required this.champion,
  });

  final int index;
  final double best;
  final double mean;
  final Float64List championGenes;
  final TrialOutcome champion;
}

/// Population seeded with pure noise. Generation zero is meant to be bad.
List<Float64List> seedPopulation(int size, int geneCount, math.Random rng) =>
    [for (var i = 0; i < size; i++) randomGenes(geneCount, rng)];

/// Tournament selection, uniform crossover, gaussian mutation — the plain
/// recipe, kept synchronous and pure so it can be tested without a sim.
List<Float64List> breed(
  List<Float64List> population,
  List<double> fitness,
  EvolutionConfig config,
  math.Random rng,
) {
  final ranked = List<int>.generate(population.length, (i) => i)
    ..sort((a, b) => fitness[b].compareTo(fitness[a]));
  final geneCount = population.first.length;
  final next = <Float64List>[];

  for (var i = 0; i < config.elite && i < ranked.length; i++) {
    next.add(Float64List.fromList(population[ranked[i]]));
  }
  for (var i = 0; i < config.immigrants; i++) {
    if (next.length >= config.population) break;
    next.add(randomGenes(geneCount, rng));
  }

  int pick() {
    var best = rng.nextInt(population.length);
    for (var i = 1; i < config.tournament; i++) {
      final challenger = rng.nextInt(population.length);
      if (fitness[challenger] > fitness[best]) best = challenger;
    }
    return best;
  }

  while (next.length < config.population) {
    final mother = population[pick()];
    final child = Float64List.fromList(mother);
    if (rng.nextDouble() < config.crossoverRate) {
      final father = population[pick()];
      for (var g = 0; g < geneCount; g++) {
        if (rng.nextBool()) child[g] = father[g];
      }
    }
    for (var g = 0; g < geneCount; g++) {
      if (rng.nextDouble() >= config.mutationRate) continue;
      child[g] = _clampGene(child[g] + _gaussian(rng) * config.mutationSigma);
    }
    next.add(child);
  }
  return next;
}

/// Genes live in 0..1; a mutation that overshoots folds back inside instead of
/// piling up on the boundary.
double _clampGene(double value) {
  var v = value;
  if (v < 0) v = -v;
  if (v > 1) v = 2 - v;
  return v.clamp(0.0, 1.0);
}

double _gaussian(math.Random rng) {
  final u = 1 - rng.nextDouble();
  final v = rng.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
}

// ─── Off-thread evaluation ──────────────────────────────────────────────────

class _EvalRequest {
  const _EvalRequest(this.shape, this.genomes, this.config);
  final CreatureShape shape;
  final List<Float64List> genomes;
  final TrialConfig config;
}

List<TrialOutcome> _evaluateChunk(_EvalRequest request) => [
      for (final genes in request.genomes)
        runTrial(request.shape, genes, config: request.config),
    ];

/// Walks every creature in the population, spread over a few background
/// isolates so a generation lands without the UI dropping a frame.
Future<List<TrialOutcome>> evaluatePopulation(
  CreatureShape shape,
  List<Float64List> genomes,
  TrialConfig config, {
  int? workers,
}) async {
  final count = workers ?? defaultWorkerCount;
  if (count <= 1 || genomes.length <= 4) {
    return _evaluateChunk(_EvalRequest(shape, genomes, config));
  }
  final size = (genomes.length / count).ceil();
  final futures = <Future<List<TrialOutcome>>>[];
  for (var start = 0; start < genomes.length; start += size) {
    final end = math.min(start + size, genomes.length);
    futures.add(
      compute(
        _evaluateChunk,
        _EvalRequest(shape, genomes.sublist(start, end), config),
      ),
    );
  }
  final chunks = await Future.wait(futures);
  return [for (final chunk in chunks) ...chunk];
}

int get defaultWorkerCount => Platform.numberOfProcessors.clamp(1, 6);

/// Never more workers than the machine has cores — past that they only take
/// turns on the same cores while costing an isolate each.
int get maxWorkerCount => Platform.numberOfProcessors.clamp(1, 12);

// ─── The run itself ─────────────────────────────────────────────────────────

/// Owns one creature's whole training run: the live population, the history
/// every generation left behind, and the loop that keeps it going.
class EvolutionSession extends ChangeNotifier {
  EvolutionSession({
    required this.shape,
    this.config = const EvolutionConfig(),
    int seed = 1,
  })  : _rng = math.Random(seed),
        _workers = defaultWorkerCount {
    _population =
        seedPopulation(config.population, shape.geneCount, _rng);
  }

  final CreatureShape shape;
  final EvolutionConfig config;
  final math.Random _rng;
  int _workers;

  late List<Float64List> _population;
  final List<GenerationResult> history = [];

  bool _running = false;
  bool _busy = false;
  bool _disposed = false;
  bool _stoppedAtLimit = false;
  int? _generationLimit;
  DateTime? _lastGenerationAt;
  double _generationsPerSecond = 0;

  bool get running => _running;
  int get generation => history.length;
  GenerationResult? get latest => history.isEmpty ? null : history.last;
  double get generationsPerSecond => _generationsPerSecond;
  int get workerCount => _workers;

  /// How many background isolates score a generation. Takes effect on the next
  /// one, so the run does not have to be restarted to turn the heat down.
  set workerCount(int value) {
    final clamped = value.clamp(1, maxWorkerCount);
    if (clamped == _workers) return;
    _workers = clamped;
    notifyListeners();
  }

  /// Stop after this many generations, or null to keep going. A long run costs
  /// real battery, and past a few hundred generations most creatures are only
  /// polishing what they already found.
  int? get generationLimit => _generationLimit;

  set generationLimit(int? value) {
    _generationLimit = value;
    if (_stoppedAtLimit && !atLimit) {
      _stoppedAtLimit = false;
      start();
      return;
    }
    notifyListeners();
  }

  bool get atLimit =>
      _generationLimit != null && history.length >= _generationLimit!;

  /// True when the run stopped itself because it hit [generationLimit], as
  /// opposed to the user pausing it.
  bool get stoppedAtLimit => _stoppedAtLimit;

  GenerationResult? get bestEver {
    GenerationResult? best;
    for (final g in history) {
      if (best == null || g.best > best.best) best = g;
    }
    return best;
  }

  void start() {
    if (_running || _disposed || atLimit) return;
    _running = true;
    _stoppedAtLimit = false;
    _lastGenerationAt = null;
    notifyListeners();
    unawaited(_loop());
  }

  void pause() {
    if (!_running) return;
    _running = false;
    _stoppedAtLimit = false;
    notifyListeners();
  }

  void toggle() => _running ? pause() : start();

  Future<void> _loop() async {
    while (_running && !_disposed) {
      if (atLimit) {
        _running = false;
        _stoppedAtLimit = true;
        notifyListeners();
        return;
      }
      if (_busy) return;
      _busy = true;
      List<TrialOutcome> outcomes;
      try {
        outcomes = await evaluatePopulation(
          shape,
          _population,
          config.trial,
          workers: _workers,
        );
      } finally {
        _busy = false;
      }
      if (_disposed || !_running) return;

      var bestIndex = 0;
      var total = 0.0;
      for (var i = 0; i < outcomes.length; i++) {
        total += outcomes[i].fitness;
        if (outcomes[i].fitness > outcomes[bestIndex].fitness) bestIndex = i;
      }
      history.add(
        GenerationResult(
          index: history.length,
          best: outcomes[bestIndex].fitness,
          mean: total / outcomes.length,
          championGenes: Float64List.fromList(_population[bestIndex]),
          champion: outcomes[bestIndex],
        ),
      );

      final now = DateTime.now();
      final previous = _lastGenerationAt;
      if (previous != null) {
        final seconds = now.difference(previous).inMicroseconds / 1e6;
        if (seconds > 0) {
          final rate = 1 / seconds;
          _generationsPerSecond = _generationsPerSecond == 0
              ? rate
              : _generationsPerSecond * 0.7 + rate * 0.3;
        }
      }
      _lastGenerationAt = now;

      _population = breed(
        _population,
        [for (final o in outcomes) o.fitness],
        config,
        _rng,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _running = false;
    super.dispose();
  }
}

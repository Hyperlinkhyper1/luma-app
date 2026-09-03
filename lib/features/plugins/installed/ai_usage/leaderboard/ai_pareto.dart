import 'ai_leaderboard_metric.dart';
import 'ai_model.dart';

/// One point on the price-vs-performance chart.
typedef AiFrontierPoint = ({AiModel model, double cost, double score});

/// The Pareto frontier of [points]: the models that nothing else beats on both
/// axes at once.
///
/// A model is on the frontier when no other model is **both** at least as
/// cheap and at least as good. That is the useful reading of "efficient" —
/// everything below the line is a model you would never pick, because
/// something else on the line costs no more and scores no worse.
///
/// Returned cheapest-first so the caller can stroke a line straight through
/// it. Ties on cost keep only the best-scoring model, so the line never
/// doubles back on itself.
List<AiFrontierPoint> paretoFrontier(List<AiFrontierPoint> points) {
  if (points.isEmpty) return const [];

  final sorted = [...points]..sort((a, b) {
      final byCost = a.cost.compareTo(b.cost);
      // Cheapest first; at equal cost the better model leads, so the weaker
      // one is dominated on the very next comparison.
      return byCost != 0 ? byCost : b.score.compareTo(a.score);
    });

  final frontier = <AiFrontierPoint>[];
  var best = double.negativeInfinity;
  for (final point in sorted) {
    // Walking cheapest-first, a point is on the frontier exactly when it
    // scores higher than everything cheaper than it.
    if (point.score > best) {
      frontier.add(point);
      best = point.score;
    }
  }
  return frontier;
}

/// The frontier for [models] plotted as [costMetric] against [scoreMetric],
/// skipping any model missing either value.
List<AiFrontierPoint> frontierOf(
  List<AiModel> models, {
  AiMetric costMetric = AiMetric.blendedPrice,
  AiMetric scoreMetric = AiMetric.llmStats,
}) =>
    paretoFrontier([
      for (final m in models)
        if (costMetric.valueOf(m) case final cost?)
          if (scoreMetric.valueOf(m) case final score?)
            // A free model would sit at the origin of a log cost axis and
            // anchor the whole frontier to a price nobody is billed.
            if (cost > 0) (model: m, cost: cost, score: score),
    ]);

/// The single best model for one metric, or null when nothing has a value.
/// Respects [AiMetric.higherIsBetter], so "best price" means cheapest.
AiModel? bestAt(List<AiModel> models, AiMetric metric) {
  AiModel? winner;
  double? winning;
  for (final model in models) {
    final value = metric.valueOf(model);
    if (value == null) continue;
    // A free-tier zero is not the "cheapest frontier model", it is a model
    // that isn't billed through this catalogue at all.
    if (!metric.higherIsBetter && value <= 0) continue;
    if (winning == null ||
        (metric.higherIsBetter ? value > winning : value < winning)) {
      winner = model;
      winning = value;
    }
  }
  return winner;
}

import 'ai_leaderboard_format.dart';
import 'ai_model.dart';

/// A quantity a model can be plotted or ranked on.
///
/// One list drives the graph's two axis pickers, the insights page's
/// "best at" tiles and the compare view's rows, so a metric added here shows
/// up everywhere at once and can never mean two different things in two
/// places.
enum AiMetric {
  llmStats('LLM Stats Index', unit: ''),
  reasoning('Reasoning Index', unit: ''),
  coding('Coding Index', unit: ''),
  agent('Agent Index', unit: ''),
  math('Math Index', unit: ''),
  codeArena('Code Arena', unit: 'Elo'),
  blendedPrice('Blended Price 8:1', unit: r'$/M', higherIsBetter: false),
  avgPrice('Average Price', unit: r'$/M', higherIsBetter: false),
  inputPrice('Input Price', unit: r'$/M', higherIsBetter: false),
  outputPrice('Output Price', unit: r'$/M', higherIsBetter: false),
  parameters('Parameters', unit: 'B'),
  context('Context Length', unit: 'tokens'),
  speed('Speed', unit: 'tok/s'),
  latency('Time to First Token', unit: 'ms', higherIsBetter: false);

  const AiMetric(this.label, {required this.unit, this.higherIsBetter = true});

  final String label;
  final String unit;

  /// Which direction is "good". Drives the Pareto frontier and the "best at"
  /// tiles — for price and latency, less is more.
  final bool higherIsBetter;

  String get axisLabel => unit.isEmpty ? label : '$label ($unit)';

  /// This model's value, or null when nothing measured it. Nulls are dropped
  /// from plots rather than drawn at zero, which would put every unmeasured
  /// model in the bottom-left corner and invent a cluster that isn't there.
  double? valueOf(AiModel m) => switch (this) {
        AiMetric.llmStats => m.llmStatsIndex,
        AiMetric.reasoning => m.reasoningIndex,
        AiMetric.coding => m.codingIndex,
        AiMetric.agent => m.agentIndex,
        AiMetric.math => m.mathIndex,
        AiMetric.codeArena => m.codeArena,
        AiMetric.blendedPrice => m.blendedPricePerM,
        AiMetric.avgPrice => m.avgPricePerM,
        AiMetric.inputPrice => m.inputPricePerM,
        AiMetric.outputPrice => m.outputPricePerM,
        AiMetric.parameters => m.parametersB,
        AiMetric.context => m.contextTokens?.toDouble(),
        AiMetric.speed => m.speedTokensPerSec,
        AiMetric.latency => m.latencyMs,
      };

  /// Renders a value the way this metric is normally written.
  String format(double value) => switch (this) {
        AiMetric.blendedPrice ||
        AiMetric.avgPrice ||
        AiMetric.inputPrice ||
        AiMetric.outputPrice =>
          formatPrice(value) ?? '–',
        AiMetric.context => formatTokens(value.round()) ?? '–',
        AiMetric.codeArena => value.round().toString(),
        AiMetric.parameters =>
          '${value.toStringAsFixed(value >= 100 ? 0 : 1)}B',
        AiMetric.speed => '${value.round()} tok/s',
        AiMetric.latency => '${(value / 1000).toStringAsFixed(2)}s',
        _ => value.toStringAsFixed(1),
      };

  /// A short form for a cramped axis tick.
  String formatTick(double value) => switch (this) {
        AiMetric.blendedPrice ||
        AiMetric.avgPrice ||
        AiMetric.inputPrice ||
        AiMetric.outputPrice =>
          formatPrice(value) ?? '',
        AiMetric.context => formatTokens(value.round()) ?? '',
        AiMetric.latency => '${(value / 1000).toStringAsFixed(1)}s',
        AiMetric.parameters => '${value.round()}B',
        _ => value >= 1000
            ? '${(value / 1000).toStringAsFixed(1)}k'
            : value.toStringAsFixed(value < 10 ? 1 : 0),
      };

  /// Whether a log scale is meaningful here. Prices, parameter counts and
  /// context windows span three or four orders of magnitude and are unreadable
  /// linearly; the 0–100 indices are not.
  bool get logUseful => switch (this) {
        AiMetric.blendedPrice ||
        AiMetric.avgPrice ||
        AiMetric.inputPrice ||
        AiMetric.outputPrice ||
        AiMetric.parameters ||
        AiMetric.context ||
        AiMetric.latency =>
          true,
        _ => false,
      };
}

/// Every model that has a value for both axes, as plottable points.
///
/// A point needs both coordinates: a model measured on one axis and not the
/// other cannot be placed, and guessing the missing half would put it
/// somewhere it has not earned.
List<({AiModel model, double x, double y})> pointsFor(
  List<AiModel> models,
  AiMetric x,
  AiMetric y, {
  bool logX = false,
  bool logY = false,
}) =>
    [
      for (final m in models)
        if (x.valueOf(m) case final xv?)
          if (y.valueOf(m) case final yv?)
            // A log axis cannot place a zero or a negative, so those models
            // drop out of the plot for as long as the toggle is on.
            if (!(logX && xv <= 0) && !(logY && yv <= 0))
              (model: m, x: xv, y: yv),
    ];

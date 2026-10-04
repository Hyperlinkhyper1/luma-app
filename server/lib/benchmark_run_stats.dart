/// What generating one benchmark scene cost: tokens spent and wall-clock time.
///
/// Runs started from the admin dashboard's "Add benchmark" record the real
/// numbers. Scenes that were uploaded by hand, or added before runs were
/// recorded, have none, so [estimateBenchmarkRun] works out a plausible pair
/// from the scene's size and the model's name. It is deterministic: the same
/// scene always gets the same numbers.
typedef BenchmarkRunStats = ({int tokens, int durationSec});

/// The prompts sent with a benchmark request run to a couple of thousand
/// tokens (the task text plus the output contract).
const _promptTokens = 2300;

/// Source code runs about 3.4 bytes per token.
const _bytesPerToken = 3.4;

/// Binary `.glb` models say nothing about the effort behind them, so they get
/// a flat figure instead of one derived from file size.
const _glbBaseTokens = 38000;

BenchmarkRunStats estimateBenchmarkRun({
  required String id,
  required String kind,
  required String model,
  required int sizeBytes,
}) {
  final name = '$id ${model.toLowerCase()}'.toLowerCase();
  final visible = kind == 'cathedral'
      ? _glbBaseTokens
      : (sizeBytes / _bytesPerToken).round();

  final tokens = (((visible * _thinkingFactor(name)) *
                      (0.85 + 0.3 * _unit(id, 1)) +
                  _promptTokens) /
              100)
          .round() *
      100;

  final seconds = tokens / _tokensPerSecond(model.toLowerCase()) *
          (0.8 + 0.4 * _unit(id, 2)) +
      8;
  // A live run is cut off at 90 minutes, so no scene reads longer than that.
  return (tokens: tokens, durationSec: seconds.round().clamp(20, 4800));
}

/// How many tokens a model thinks per token it writes, read off the effort
/// word in its name (`xhigh`, `max`, `low`, …).
double _thinkingFactor(String name) {
  bool has(String word) => RegExp('(^|[^a-z])$word([^a-z]|\$)').hasMatch(name);
  if (has('xhigh') || has('max') || has('ultra') || has('ultracode')) {
    return 4.8;
  }
  if (has('high')) return 3.2;
  if (has('medium')) return 2.2;
  if (has('low')) return 1.4;
  if (has('minimal') || has('none') || has('instant')) return 1.05;
  return 1.6;
}

/// Output speed in tokens per second, by model family.
double _tokensPerSecond(String model) {
  const fast = ['mini', 'flash', 'haiku', 'nano', 'lite', 'spark', 'turbo'];
  const slow = ['opus', 'deepseek', 'kimi', 'glm', 'qwen', 'sol', 'astra'];
  if (fast.any(model.contains)) return 130;
  if (slow.any(model.contains)) return 45;
  return 75;
}

/// A stable pseudo-random number in [0, 1) for [id] and [salt] (FNV-1a).
double _unit(String id, int salt) {
  var hash = 0x811c9dc5 ^ salt;
  for (final unit in id.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  hash ^= hash >> 15;
  hash = (hash * 0x2c1b3c6d) & 0xffffffff;
  hash ^= hash >> 12;
  return (hash & 0xffffff) / 0x1000000;
}

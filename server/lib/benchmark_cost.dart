/// What one "Add benchmark" run is likely to cost, before it starts.
///
/// A run is one request: the test's prompt in, one HTML page (plus whatever
/// the model thinks first) out. The page's length is read off the scenes
/// already on the roster for that test, and the thinking on top of it is a
/// multiple of the page that grows with the reasoning effort.
///
/// Calibrated on real pagoda runs (prompt ≈ 1.35k tokens, median page ≈ 11k):
/// Gemini Argon 4 used 25k output tokens at low and 40k at xhigh; MiMo V2.5,
/// Solar 4 Pro and Muse Wonder used 48k, 46k and 33k at xhigh. Models that
/// don't reason (Nova Micro, Mercury 2.5) wrote 1–6k. The steps between low
/// and xhigh follow Artificial Analysis's per-effort reasoning-token counts
/// (Opus 5: 7k / 15k / 25k / 35k), squeezed to fit the pagoda runs, since a
/// page-writing task spends a larger share on the answer than their evals do.
library;

/// Prompt characters per input token. The pagoda prompt is 4,764
/// characters and was billed as 1.3–1.4k tokens.
const double kBenchmarkPromptCharsPerToken = 3.5;

/// Page bytes per output token (HTML, CSS and JavaScript).
const double kBenchmarkPageBytesPerToken = 3.4;

/// The page a test is assumed to need when it has no scenes yet: the median
/// across every test on the roster, give or take.
const int kBenchmarkDefaultPageTokens = 11500;

/// Thinking tokens per page token, by reasoning effort. `''` is the model's
/// own default and is resolved before this table is read.
const Map<String, double> kBenchmarkThinkingPerPageToken = {
  'none': 0.05,
  'minimal': 0.35,
  'low': 1.0,
  'medium': 1.6,
  'high': 2.2,
  'xhigh': 2.6,
  'max': 2.9,
};

/// Models that don't reason write a shorter page than the roster's median
/// and nothing before it.
const double kBenchmarkPlainPageScale = 0.6;

/// Input tokens for a prompt of [promptChars] characters.
int benchmarkPromptTokens(int promptChars) =>
    (promptChars / kBenchmarkPromptCharsPerToken).round();

/// The median page, in tokens, of scenes [sizes] bytes long, or
/// [kBenchmarkDefaultPageTokens] when there are none.
int benchmarkMedianPageTokens(Iterable<int> sizes) {
  final sorted = sizes.where((s) => s > 0).toList()..sort();
  if (sorted.isEmpty) return kBenchmarkDefaultPageTokens;
  final mid = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[mid].toDouble()
      : (sorted[mid - 1] + sorted[mid]) / 2;
  return (median / kBenchmarkPageBytesPerToken).round();
}

/// Output tokens one run is expected to use. [effort] is the dialog's
/// choice (`''` for the model's default); [reasons] is false only for a
/// model known not to think, where effort changes nothing. The figure never
/// exceeds [maxTokens], since the run is cut off there.
int estimateBenchmarkOutputTokens({
  required int pageTokens,
  required String effort,
  bool reasons = true,
  String? defaultEffort,
  int? maxTokens,
}) {
  double out;
  if (!reasons) {
    out = pageTokens * kBenchmarkPlainPageScale;
  } else {
    final resolved = effort.isEmpty ? (defaultEffort ?? 'medium') : effort;
    final think = kBenchmarkThinkingPerPageToken[resolved] ??
        kBenchmarkThinkingPerPageToken['medium']!;
    out = pageTokens * (1 + think);
  }
  final tokens = (out / 100).round() * 100;
  return maxTokens != null && maxTokens > 0 && tokens > maxTokens
      ? maxTokens
      : tokens;
}

/// US dollars for [inputTokens] and [outputTokens] at per-million prices.
double benchmarkCostUsd(int inputTokens, int outputTokens,
        {required double inputPerM, required double outputPerM}) =>
    (inputTokens * inputPerM + outputTokens * outputPerM) / 1e6;

/// The constants above, for the dashboard script that redoes the sum live
/// as the admin changes model, effort and test.
Map<String, Object> benchmarkCostModelJson() => {
      'promptCharsPerToken': kBenchmarkPromptCharsPerToken,
      'thinking': kBenchmarkThinkingPerPageToken,
      'plainPageScale': kBenchmarkPlainPageScale,
    };

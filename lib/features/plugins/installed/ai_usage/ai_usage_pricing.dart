/// Static Anthropic API pricing, ported from the reference `claude-usage`
/// CLI tool's dashboard (per-model $/MTok). This is a manually maintained
/// snapshot, not a live fetch — it needs updating by hand when Anthropic
/// changes prices. Costs are API prices; a Max/Pro subscriber's actual cost
/// structure is subscription-based, not per-token.
class AiPricingRates {
  const AiPricingRates({
    required this.input,
    required this.output,
    required this.cacheWrite,
    required this.cacheRead,
  });

  /// All rates are USD per million tokens.
  final double input;
  final double output;
  final double cacheWrite;
  final double cacheRead;
}

const Map<String, AiPricingRates> kAiPricing = {
  // Fable / Mythos — Anthropic's most capable class, priced at 2x Opus.
  'claude-fable-5': AiPricingRates(input: 10.00, output: 50.00, cacheWrite: 12.50, cacheRead: 1.00),
  'claude-mythos-5': AiPricingRates(input: 10.00, output: 50.00, cacheWrite: 12.50, cacheRead: 1.00),
  'claude-opus-4-8': AiPricingRates(input: 5.00, output: 25.00, cacheWrite: 6.25, cacheRead: 0.50),
  'claude-opus-4-7': AiPricingRates(input: 5.00, output: 25.00, cacheWrite: 6.25, cacheRead: 0.50),
  'claude-opus-4-6': AiPricingRates(input: 5.00, output: 25.00, cacheWrite: 6.25, cacheRead: 0.50),
  'claude-opus-4-5': AiPricingRates(input: 5.00, output: 25.00, cacheWrite: 6.25, cacheRead: 0.50),
  'claude-sonnet-4-7': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.75, cacheRead: 0.30),
  'claude-sonnet-4-6': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.75, cacheRead: 0.30),
  'claude-sonnet-4-5': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.75, cacheRead: 0.30),
  'claude-haiku-4-7': AiPricingRates(input: 1.00, output: 5.00, cacheWrite: 1.25, cacheRead: 0.10),
  'claude-haiku-4-6': AiPricingRates(input: 1.00, output: 5.00, cacheWrite: 1.25, cacheRead: 0.10),
  'claude-haiku-4-5': AiPricingRates(input: 1.00, output: 5.00, cacheWrite: 1.25, cacheRead: 0.10),
};

/// Whether [model] is one of Anthropic's billable model families. Anything
/// else (a local model, a proxy pointed at a different provider, ...) is
/// grouped as "Other providers" in the UI, with cost shown as n/a.
bool isBillableModel(String? model) {
  if (model == null) return false;
  final m = model.toLowerCase();
  return m.contains('fable') ||
      m.contains('mythos') ||
      m.contains('opus') ||
      m.contains('sonnet') ||
      m.contains('haiku');
}

/// Resolves [model] to its pricing rates: exact match first, then prefix
/// match (handles dated suffixes like `claude-opus-4-8-20260315`), then a
/// same-family fallback to the newest known rate. Null if [model] isn't a
/// recognized Anthropic family at all.
AiPricingRates? pricingFor(String? model) {
  if (model == null) return null;
  final exact = kAiPricing[model];
  if (exact != null) return exact;
  for (final entry in kAiPricing.entries) {
    if (model.startsWith(entry.key)) return entry.value;
  }
  final m = model.toLowerCase();
  if (m.contains('fable') || m.contains('mythos')) return kAiPricing['claude-fable-5'];
  if (m.contains('opus')) return kAiPricing['claude-opus-4-8'];
  if (m.contains('sonnet')) return kAiPricing['claude-sonnet-4-6'];
  if (m.contains('haiku')) return kAiPricing['claude-haiku-4-5'];
  return null;
}

/// Estimated USD cost of one turn's token usage, or 0 for a non-billable /
/// unrecognized model.
double costForTurn(
  String? model,
  int inputTokens,
  int outputTokens,
  int cacheReadTokens,
  int cacheCreationTokens,
) {
  if (!isBillableModel(model)) return 0;
  final rates = pricingFor(model);
  if (rates == null) return 0;
  return inputTokens * rates.input / 1e6 +
      outputTokens * rates.output / 1e6 +
      cacheReadTokens * rates.cacheRead / 1e6 +
      cacheCreationTokens * rates.cacheWrite / 1e6;
}

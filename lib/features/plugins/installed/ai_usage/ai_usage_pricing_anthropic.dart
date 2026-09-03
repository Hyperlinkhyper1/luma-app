import 'ai_usage_pricing_rates.dart';

/// Static Anthropic API pricing, ported from the reference `claude-usage`
/// CLI tool's dashboard (per-model $/MTok). This is a manually maintained
/// snapshot, not a live fetch — it needs updating by hand when Anthropic
/// changes prices. Costs are API prices; a Max/Pro subscriber's actual cost
/// structure is subscription-based, not per-token.
const Map<String, AiPricingRates> kAnthropicPricing = {
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
/// grouped as "Other" in the UI, with cost shown as n/a.
bool isAnthropicBillableModel(String? model) {
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
AiPricingRates? anthropicPricingFor(String? model) {
  if (model == null) return null;
  final exact = kAnthropicPricing[model];
  if (exact != null) return exact;
  for (final entry in kAnthropicPricing.entries) {
    if (model.startsWith(entry.key)) return entry.value;
  }
  final m = model.toLowerCase();
  if (m.contains('fable') || m.contains('mythos')) return kAnthropicPricing['claude-fable-5'];
  if (m.contains('opus')) return kAnthropicPricing['claude-opus-4-8'];
  if (m.contains('sonnet')) return kAnthropicPricing['claude-sonnet-4-6'];
  if (m.contains('haiku')) return kAnthropicPricing['claude-haiku-4-5'];
  return null;
}

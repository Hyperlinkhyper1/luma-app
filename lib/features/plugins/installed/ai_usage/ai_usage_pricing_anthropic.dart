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
  'claude-opus-5': AiPricingRates(input: 5.00, output: 25.00, cacheWrite: 6.25, cacheRead: 0.50),
  // Sonnet 5 launched Jun 30 2026 at an introductory $2/$10 due to rise Sep 1;
  // Anthropic made that permanent (~Aug 10 2026), so $2/$10 is the rate.
  'claude-sonnet-5': AiPricingRates(input: 2.00, output: 10.00, cacheWrite: 2.50, cacheRead: 0.20),
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
  if (m.contains('opus')) return kAnthropicPricing['claude-opus-5'];
  // Sonnet 5's $2/$10 rate was made permanent (Aug 2026), but it is the
  // exception, not the tier: 4.5/4.6 and any unknown future Sonnet price at
  // the $3/$15 standard, so only route an actual 5 there — slug or prose.
  if (m.contains('sonnet-5') || m.contains('sonnet 5')) {
    return kAnthropicPricing['claude-sonnet-5'];
  }
  if (m.contains('sonnet')) return kAnthropicPricing['claude-sonnet-4-6'];
  if (m.contains('haiku')) return kAnthropicPricing['claude-haiku-4-5'];
  return null;
}

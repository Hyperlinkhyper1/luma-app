import 'ai_usage_pricing_rates.dart';

/// Static OpenAI API pricing for the models Codex CLI actually reports
/// (per-model $/MTok). Manually maintained, not a live fetch — needs
/// updating by hand as OpenAI changes prices. `gpt-5.6` is an inferred
/// flagship-tier name by analogy with the 5.4/5.5 naming pattern, not
/// directly confirmed. A 272K+-input-token long-context surcharge tier
/// exists in OpenAI's real pricing but is intentionally not modeled here,
/// same simplification as the Anthropic table ignoring promotions/tiering.
/// None of these models charge separately for cache writes, so `cacheWrite`
/// is unused (always 0) for every entry.
const Map<String, AiPricingRates> kOpenAiPricing = {
  'gpt-5.5-pro': AiPricingRates(input: 30.00, output: 180.00, cacheWrite: 0, cacheRead: 30.00),
  'gpt-5.5': AiPricingRates(input: 5.00, output: 30.00, cacheWrite: 0, cacheRead: 0.50),
  'gpt-5.4-mini': AiPricingRates(input: 0.75, output: 4.50, cacheWrite: 0, cacheRead: 0.075),
  'gpt-5.4-nano': AiPricingRates(input: 0.20, output: 1.25, cacheWrite: 0, cacheRead: 0.02),
  'gpt-5.4': AiPricingRates(input: 2.50, output: 15.00, cacheWrite: 0, cacheRead: 0.25),
  'gpt-5.3-codex': AiPricingRates(input: 1.75, output: 14.00, cacheWrite: 0, cacheRead: 0.175),
  'gpt-5.6': AiPricingRates(input: 5.00, output: 30.00, cacheWrite: 0, cacheRead: 0.50),
};

/// Version substrings checked, in order, when a model doesn't match
/// [kOpenAiPricing] at all — lets an unlisted suffix of a known generation
/// (e.g. a hypothetical `gpt-5.6-mini`) still get that generation's
/// flagship rate instead of falling through to "unrecognized".
const List<String> _kOpenAiVersionFallbackOrder = ['5.6', '5.5', '5.4', '5.3'];

/// Whether [model] is an OpenAI model Codex CLI reports usage for.
bool isOpenAiBillableModel(String? model) {
  if (model == null) return false;
  return model.toLowerCase().contains('gpt-');
}

/// Resolves [model] to its pricing rates: exact match first, then prefix
/// match — checked longest-key-first so a specific variant like
/// `gpt-5.4-mini` is never shadowed by the shorter `gpt-5.4` prefix it also
/// satisfies — then a same-generation fallback to that generation's
/// flagship rate. Null if [model] isn't a recognized OpenAI model at all.
AiPricingRates? openAiPricingFor(String? model) {
  if (model == null) return null;
  final exact = kOpenAiPricing[model];
  if (exact != null) return exact;

  final keysByLengthDesc = kOpenAiPricing.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keysByLengthDesc) {
    if (model.startsWith(key)) return kOpenAiPricing[key];
  }

  for (final version in _kOpenAiVersionFallbackOrder) {
    if (!model.contains(version)) continue;
    final rates = kOpenAiPricing['gpt-$version'];
    // Not every version in the fallback list has a bare "gpt-<version>"
    // entry (e.g. 5.3 only ships as the codex-specific SKU) — skip rather
    // than guess at an unrelated variant's rate.
    if (rates != null) return rates;
  }
  return null;
}

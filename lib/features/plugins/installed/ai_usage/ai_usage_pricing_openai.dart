import 'ai_usage_pricing_rates.dart';

/// Static OpenAI API pricing for the models Codex CLI actually reports
/// (per-model $/MTok). Manually maintained, not a live fetch — needs
/// updating by hand as OpenAI changes prices. Effective Sep 2026:
/// - `gpt-6-astra` is the Sep 3 2026 flagship ($10/$50 Standard).
/// - `gpt-5.6` is an alias for Sol (OpenAI's own docs: a bare `gpt-5.6`
///   call routes to Sol), priced here at Sol's promotional $4/$20 rate,
///   which runs at least through Nov 21 2026 — after that it likely
///   reverts to the $5/$30 list, so revisit this table then.
/// - `gpt-5.6-terra`/`gpt-5.6-luna` are the permanent Jul 30 2026 cuts
///   ($2/$12 and $0.20/$1.20). Luna previously had no entry and
///   prefix-matched the `gpt-5.6` flagship rate, overstating its cost ~25x.
/// A 272K+-input-token long-context surcharge tier exists in OpenAI's real
/// pricing but is intentionally not modeled here, same simplification as
/// the Anthropic table ignoring promotions/tiering. None of these models
/// charge separately for cache writes in a way Codex CLI surfaces (its
/// scanner always records 0 cache writes), so `cacheWrite` is unused
/// (always 0) for every entry.
const Map<String, AiPricingRates> kOpenAiPricing = {
  'gpt-6-astra': AiPricingRates(input: 10.00, output: 50.00, cacheWrite: 0, cacheRead: 1.00),
  'gpt-6': AiPricingRates(input: 10.00, output: 50.00, cacheWrite: 0, cacheRead: 1.00),
  'gpt-5.6-sol': AiPricingRates(input: 4.00, output: 20.00, cacheWrite: 0, cacheRead: 0.40),
  'gpt-5.6-terra': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),
  'gpt-5.6-luna': AiPricingRates(input: 0.20, output: 1.20, cacheWrite: 0, cacheRead: 0.02),
  'gpt-5.5-pro': AiPricingRates(input: 30.00, output: 180.00, cacheWrite: 0, cacheRead: 30.00),
  'gpt-5.5': AiPricingRates(input: 5.00, output: 30.00, cacheWrite: 0, cacheRead: 0.50),
  'gpt-5.4-mini': AiPricingRates(input: 0.75, output: 4.50, cacheWrite: 0, cacheRead: 0.075),
  'gpt-5.4-nano': AiPricingRates(input: 0.20, output: 1.25, cacheWrite: 0, cacheRead: 0.02),
  'gpt-5.4': AiPricingRates(input: 2.50, output: 15.00, cacheWrite: 0, cacheRead: 0.25),
  'gpt-5.3-codex': AiPricingRates(input: 1.75, output: 14.00, cacheWrite: 0, cacheRead: 0.175),
  'gpt-5.6': AiPricingRates(input: 4.00, output: 20.00, cacheWrite: 0, cacheRead: 0.40),
};

/// Version substrings checked, in order, when a model doesn't match
/// [kOpenAiPricing] at all — lets an unlisted suffix of a known generation
/// (e.g. a hypothetical `gpt-5.6-mini`) still get that generation's
/// flagship rate instead of falling through to "unrecognized". Deliberately
/// no bare `'6'`: any `gpt-6*` model already prefix-matches the `gpt-6`
/// entry above, and a single-digit `contains('6')` check would misroute
/// dated snapshots of older generations (e.g. `gpt-5.5-0613`). A future
/// `gpt-7*` family is covered by the flagship fallback in
/// [openAiPricingFor] instead.
const List<String> _kOpenAiVersionFallbackOrder = ['5.6', '5.5', '5.4', '5.3'];

/// The newest flagship rate — the last-resort estimate for anything
/// [isOpenAiBillableModel] recognizes but [kOpenAiPricing] (plus the
/// version fallbacks) can't place. Pricing an unknown future model at
/// flagship is deliberately conservative: the old behavior returned null
/// here while still calling the model billable, which surfaced as a
/// misleading $0.00 (e.g. `gpt-6-astra` before it had an entry).
final AiPricingRates kOpenAiFlagshipFallback = kOpenAiPricing['gpt-6-astra']!;

/// Whether [model] is a model Codex CLI reports usage for: a `gpt-` model,
/// or a Codex-internal alias such as the sandbox auto-reviewer's
/// `codex-auto-review` (its sessions are retained under `~/.codex/sessions`
/// like any other, with real token usage attached).
bool isOpenAiBillableModel(String? model) {
  if (model == null) return false;
  final m = model.toLowerCase();
  return m.contains('gpt-') || m.contains('codex-');
}

/// Resolves [model] to its pricing rates: exact match first, then prefix
/// match — checked longest-key-first so a specific variant like
/// `gpt-5.4-mini` is never shadowed by the shorter `gpt-5.4` prefix it also
/// satisfies — then a same-generation fallback to that generation's
/// flagship rate, then the newest flagship for anything else billable
/// (a future generation, or a Codex-internal alias like
/// `codex-auto-review` whose backing model OpenAI never published a rate
/// for). Null only if [model] isn't a recognized OpenAI/Codex model at all.
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
  if (isOpenAiBillableModel(model)) return kOpenAiFlagshipFallback;
  return null;
}

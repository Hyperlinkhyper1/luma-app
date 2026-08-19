import 'ai_usage_pricing_rates.dart';

/// Static Gemini API pricing, used for Antigravity turns whose detected
/// model is a Gemini family. Manually maintained snapshot, effective ~Aug
/// 2026 — needs updating by hand as Google changes prices. Two known gaps:
/// Gemini 3.1 Pro's 200K+-input long-context tier (4.00 / — / 18.00) is
/// intentionally not modeled, same simplification as the Anthropic/OpenAI
/// tables ignoring their own tiering; and 3.5 Flash's cached rate/exact
/// current price is the least certain number here (a recent ~Aug 13 2026
/// price cut was reported, with older sources still showing 1.50/9.00).
///
/// Unlike the other two tables, keys here are **human-readable display
/// names** (`"Gemini 3.1 Pro"`), not raw API model IDs — Antigravity only
/// ever surfaces the model it used as prose in its own UI, never a slug.
const Map<String, AiPricingRates> kGeminiPricing = {
  'Gemini 3.1 Pro': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),
  'Gemini 3.5 Flash': AiPricingRates(input: 0.75, output: 3.75, cacheWrite: 0, cacheRead: 0.075),
  'Gemini 3.5 Flash-Lite':
      AiPricingRates(input: 0.30, output: 2.50, cacheWrite: 0, cacheRead: 0.03),
  'Gemini 3 Flash': AiPricingRates(input: 0.50, output: 3.00, cacheWrite: 0, cacheRead: 0.05),
  'Gemini 3.7 Flash': AiPricingRates(input: 0.75, output: 3.75, cacheWrite: 0, cacheRead: 0.075),
};

/// Whether [model] (already stripped of any trailing reasoning-effort
/// suffix — see [stripReasoningEffortSuffix]) resolves to a known Gemini
/// price. Deliberately tied 1:1 to [geminiPricingFor] succeeding, unlike
/// OpenAI's broader "looks like a gpt- name" check — Gemini has no
/// generation-fallback list to fall back to safely, so this avoids ever
/// calling something billable while silently pricing it at $0.
bool isGeminiBillableModel(String? model) => geminiPricingFor(model) != null;

/// Resolves [model] to its Gemini pricing rates: exact match first, then
/// prefix match — checked longest-key-first so `"Gemini 3.5 Flash-Lite"` is
/// never shadowed by the shorter `"Gemini 3.5 Flash"` it also starts with.
/// Null if [model] isn't a recognized Gemini family at all.
AiPricingRates? geminiPricingFor(String? model) {
  if (model == null) return null;
  final exact = kGeminiPricing[model];
  if (exact != null) return exact;

  final keysByLengthDesc = kGeminiPricing.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keysByLengthDesc) {
    if (model.startsWith(key)) return kGeminiPricing[key];
  }
  return null;
}

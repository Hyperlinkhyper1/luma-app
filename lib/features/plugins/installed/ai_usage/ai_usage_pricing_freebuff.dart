import 'ai_usage_pricing_rates.dart';

/// Splits a Freebuff turn's stored model into a `(providerID, modelID)` pair
/// when it was routed through Freebuff's own native multi-provider catalog
/// (e.g. `"z-ai/glm-5.3-flash"` -> `("z-ai", "glm-5.3-flash")`), or null when
/// it's a bare slug from an embedded Claude Code/Codex CLI thread instead
/// (e.g. `"claude-opus-4-8"`, which those tools' own pricing tables already
/// handle) — see `freebuff_scanner.dart`.
(String provider, String modelId)? splitFreebuffModel(String model) {
  final slash = model.indexOf('/');
  if (slash < 0) return null;
  return (model.substring(0, slash), model.substring(slash + 1));
}

/// Coarse, **provider-level** (not per-model) estimated rate for every
/// Freebuff-native provider other than `anthropic`/`openai` (which route to
/// this app's own exact tables instead — see `ai_usage_pricing.dart`).
/// Pinned to roughly that provider/family's typical tier, the same standard
/// `kOpencodeProviderPricing` uses for opencode's equivalent open-ended
/// provider catalog: every turn prices as real, paid usage rather than
/// trusting a promo/contributor tier's $0, or reading "n/a" for a provider
/// this app just hasn't been told about individually.
const Map<String, AiPricingRates> kFreebuffProviderPricing = {
  // Zhipu AI's GLM family — the default Freebuff harness as of this table.
  'z-ai': AiPricingRates(input: 0.60, output: 2.20, cacheWrite: 0.60, cacheRead: 0.06),
  'deepseek': AiPricingRates(input: 0.28, output: 0.42, cacheWrite: 0.28, cacheRead: 0.028),
  // Moonshot AI's Kimi family, reached through a third-party proxy.
  'crof': AiPricingRates(input: 0.60, output: 2.50, cacheWrite: 0.60, cacheRead: 0.06),
  'meta': AiPricingRates(input: 0.30, output: 1.20, cacheWrite: 0.30, cacheRead: 0.03),
  'mistral': AiPricingRates(input: 2.00, output: 6.00, cacheWrite: 2.00, cacheRead: 0.20),
  'xai': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.00, cacheRead: 0.30),
  'google': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),
  'openrouter': AiPricingRates(input: 1.00, output: 3.00, cacheWrite: 1.00, cacheRead: 0.10),
};

/// Rate for a Freebuff-native provider not named in [kFreebuffProviderPricing]
/// — most likely a catalog rotation this table hasn't been updated for yet.
/// Pinned to a generic mid-tier rate so "any provider Freebuff can route
/// through" still prices as real usage instead of falling back to $0 or
/// "n/a".
const AiPricingRates kFreebuffGenericProviderFallback =
    AiPricingRates(input: 1.00, output: 3.00, cacheWrite: 1.00, cacheRead: 0.10);

/// Resolves a Freebuff-native `providerID` (other than `'anthropic'` or
/// `'openai'`, which have their own exact tables) to a rate. Always
/// non-null.
AiPricingRates freebuffProviderPricingFor(String provider) =>
    kFreebuffProviderPricing[provider] ?? kFreebuffGenericProviderFallback;

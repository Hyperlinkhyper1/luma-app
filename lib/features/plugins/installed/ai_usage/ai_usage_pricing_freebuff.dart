import 'ai_usage_pricing_rates.dart';

/// Every model id in Freebuff's own built-in catalog (its
/// `SUPPORTED_FREEBUFF_MODELS` plus the per-model id constants), used only to
/// turn a hosted-model key back into a real id — see [resolveFreebuffModel].
/// A model missing here still records and prices; it just keeps showing its
/// opaque `m-…` key until it's added.
const List<String> kFreebuffCatalogModelIds = [
  'anthropic/claude-fable-5.1',
  'anthropic/claude-opus-5.5',
  'anthropic/claude-opus-5',
  'anthropic/claude-opus-4.8',
  'anthropic/claude-sonnet-5',
  'anthropic/claude-sonnet-4.6',
  'fbc/claude-haiku-5.5',
  'openai/gpt-6-astra',
  'openai/gpt-6-astra-pro',
  'openai/gpt-6-sol',
  'openai/gpt-6-sol-pro',
  'openai/gpt-6-luna',
  'openai/gpt-6-luna-pro',
  'openai/gpt-6.1-sol',
  'openai/gpt-5.6-sol',
  'openai/gpt-5.6-sol-pro',
  'openai/gpt-5.6-terra',
  'openai/gpt-5.6-terra-pro',
  'openai/gpt-5.6-luna',
  'openai/gpt-5.6-luna-pro',
  'openai/gpt-5.6-luna-es',
  'openai/gpt-5.5',
  'openai/gpt-5.5-pro',
  'openai/gpt-5.4-pro',
  'openai/o3-pro',
  'google/gemini-4-argon',
  'google/gemini-3.8-flash',
  'google/gemini-3.7-flash',
  'google/gemini-3.6-flash',
  'google/gemini-3.5-flash',
  'google/gemini-3.1-pro-preview',
  'z-ai/glm-5.3',
  'z-ai/glm-5.3-prime',
  'z-ai/glm-5.3-flash',
  'z-ai/glm-5.3-flashx',
  'z-ai/glm-5.2',
  'z-ai/glm-5-turbo',
  'deepseek/deepseek-v4-pro',
  'deepseek/deepseek-v4-flash',
  'deepseek/deepseek-v4-flash-fast',
  'deepseek/deepseek-v4.1-flash',
  'mimo/mimo-v2.5',
  'mimo/mimo-v2.5-pro',
  'mimo/mimo-v2.6-pro',
  'upstage/solar-pro4',
  'upstage/solar-mini4',
  'moonshotai/kimi-k3',
  'crof/kimi-k3-eco',
  'minimax/minimax-m3',
  'qwen/qwen3.8-max-prime',
  'qwen/qwen3.8-max-0902',
  'qwen/qwen3.8-flash',
  'qwen/qwen3.8-27b',
  'qwen/qwen3.7-max',
  'qwen/qwen3.7-plus',
  'qwen/qwen3.6-max-preview',
  'qwen/qwen3.6-plus',
  'x-ai/grok-4.7',
  'x-ai/grok-4.6',
  'x-ai/grok-4.5',
  'x-ai/grok-4.20',
  'meta/muse-spark-1.3-contributor',
  'meta/muse-spark-1.2-contributor',
  'meta-llama/llama-4-maverick',
  'mistralai/mistral-large',
  'mistralai/codestral-2508',
  'stealth/space-bunny-alpha',
  'stealth/ox-alpha',
];

/// Freebuff's `freebuffLegacyModelDigest`: two 32-bit FNV-style hashes over
/// `freebuff-legacy-model:<input>`, hex-joined.
String _freebuffLegacyDigest(String input) {
  var h1 = 2166136261;
  var h2 = 1523705862;
  for (final c in 'freebuff-legacy-model:$input'.codeUnits) {
    h1 = ((h1 ^ c) * 16777619) & 0xffffffff;
    h2 = ((h2 ^ c) * 1540483477) & 0xffffffff;
  }
  return h1.toRadixString(16).padLeft(8, '0') + h2.toRadixString(16).padLeft(8, '0');
}

final Map<String, String> _hostedKeyToModel = {
  for (final id in kFreebuffCatalogModelIds)
    'm-${_freebuffLegacyDigest('key:$id').substring(0, 10)}': id,
};

/// A thread on Freebuff's hosted catalog stores its model as an opaque key
/// (`m-` plus the first ten hex digits of the digest of `key:<model id>`,
/// e.g. `"m-cb71f819fe"` for `"mimo/mimo-v2.6-pro"`) rather than the id
/// itself. Maps such a key back to the catalog id; anything else, including
/// a key for a model [kFreebuffCatalogModelIds] doesn't list, comes back
/// unchanged.
String resolveFreebuffModel(String model) => _hostedKeyToModel[model] ?? model;

/// Splits a Freebuff turn's stored model into a `(providerID, modelID)` pair
/// when it was routed through Freebuff's own native multi-provider catalog
/// (e.g. `"z-ai/glm-5.3-flash"` -> `("z-ai", "glm-5.3-flash")`), or null when
/// it's a bare slug from an embedded Claude Code/Codex CLI thread instead
/// (e.g. `"claude-opus-4-8"`, which those tools' own pricing tables already
/// handle) — see `freebuff_scanner.dart`. A hosted-model key is resolved
/// first, see [resolveFreebuffModel].
(String provider, String modelId)? splitFreebuffModel(String model) {
  final resolved = resolveFreebuffModel(model);
  final slash = resolved.indexOf('/');
  if (slash < 0) return null;
  return (resolved.substring(0, slash), resolved.substring(slash + 1));
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
  'moonshotai': AiPricingRates(input: 0.60, output: 2.50, cacheWrite: 0.60, cacheRead: 0.06),
  'meta': AiPricingRates(input: 0.30, output: 1.20, cacheWrite: 0.30, cacheRead: 0.03),
  'meta-llama': AiPricingRates(input: 0.30, output: 1.20, cacheWrite: 0.30, cacheRead: 0.03),
  'mistral': AiPricingRates(input: 2.00, output: 6.00, cacheWrite: 2.00, cacheRead: 0.20),
  'mistralai': AiPricingRates(input: 2.00, output: 6.00, cacheWrite: 2.00, cacheRead: 0.20),
  'xai': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.00, cacheRead: 0.30),
  'x-ai': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.00, cacheRead: 0.30),
  'google': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),
  'openrouter': AiPricingRates(input: 1.00, output: 3.00, cacheWrite: 1.00, cacheRead: 0.10),
  // Xiaomi's MiMo family.
  'mimo': AiPricingRates(input: 0.40, output: 2.00, cacheWrite: 0.40, cacheRead: 0.04),
  // Upstage's Solar family.
  'upstage': AiPricingRates(input: 0.30, output: 0.90, cacheWrite: 0.30, cacheRead: 0.03),
  // Alibaba's Qwen family.
  'qwen': AiPricingRates(input: 0.80, output: 3.20, cacheWrite: 0.80, cacheRead: 0.08),
  'minimax': AiPricingRates(input: 0.30, output: 1.20, cacheWrite: 0.30, cacheRead: 0.03),
};

/// Rate for a Freebuff-native provider not named in [kFreebuffProviderPricing]
/// — most likely a catalog rotation this table hasn't been updated for yet,
/// or one of the anonymous `stealth/` models. Pinned to a generic mid-tier
/// rate so "any provider Freebuff can route through" still prices as real
/// usage instead of falling back to $0 or "n/a".
const AiPricingRates kFreebuffGenericProviderFallback =
    AiPricingRates(input: 1.00, output: 3.00, cacheWrite: 1.00, cacheRead: 0.10);

/// Resolves a Freebuff-native `providerID` (other than `'anthropic'` or
/// `'openai'`, which have their own exact tables) to a rate. Always
/// non-null.
AiPricingRates freebuffProviderPricingFor(String provider) =>
    kFreebuffProviderPricing[provider] ?? kFreebuffGenericProviderFallback;

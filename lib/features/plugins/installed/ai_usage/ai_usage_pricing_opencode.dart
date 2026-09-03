import 'ai_usage_pricing_rates.dart';

/// Assumed per-token rates for OpenCode's own "Zen" gateway models —
/// `providerID == 'opencode'` in the stored `"<providerID>/<modelID>"` model
/// string (see `opencode_scanner.dart`). OpenCode reports `cost: 0` for
/// these turns because Zen grants free/contributor access to them, but that
/// is an access-tier discount, not evidence the underlying model has no
/// real cost — priced here as if reached with a normal paid API key instead
/// of trusting the tool's own $0 figure. `costForRow` in ai_usage_stats.dart
/// prefers this app's own pricing over the tool's reported cost for exactly
/// this reason.
///
/// These are OpenCode's own catalog names, not published anywhere else, so
/// there is no official rate to source from — the numbers below are an
/// estimate pinned to the nearest comparable tier already in this app's
/// other pricing tables (a fast/small preview model ~ Anthropic's Haiku
/// tier; the lighter "Spark"-class model ~ OpenAI's nano tier). Update by
/// hand if OpenCode Zen ever publishes real rates, or when its rotating
/// catalog adds new free models.
const Map<String, AiPricingRates> kOpencodeZenPricing = {
  'x-preview-f-free':
      AiPricingRates(input: 1.00, output: 5.00, cacheWrite: 1.25, cacheRead: 0.10),
  'muse-spark-1.2-contributor-free':
      AiPricingRates(input: 0.20, output: 1.25, cacheWrite: 0.25, cacheRead: 0.02),
};

/// Rate for an `opencode/*` model not named in [kOpencodeZenPricing] — most
/// likely a future Zen catalog rotation. Pinned to the same "small preview"
/// tier as `x-preview-f-free` so a still-unnamed free model still prices as
/// real usage instead of falling back to $0 or "n/a".
const AiPricingRates kOpencodeZenFallback =
    AiPricingRates(input: 1.00, output: 5.00, cacheWrite: 1.25, cacheRead: 0.10);

/// Resolves an OpenCode Zen model id to its assumed rate — always
/// non-null, since every `opencode/*` turn should be billed by normal
/// standards rather than accepted as free.
AiPricingRates opencodeZenPricingFor(String modelId) =>
    kOpencodeZenPricing[modelId] ?? kOpencodeZenFallback;

/// Coarse, **provider-level** (not per-model) estimated rate for every other
/// third-party provider OpenCode can route a turn through. OpenCode's
/// provider catalog is open-ended — new providers and models are added to
/// it constantly, community-configured providers exist that this app will
/// never have heard of — so per-model precision the way the Anthropic/OpenAI
/// tables have it isn't reachable here. One representative rate per
/// provider (roughly pinned to that provider's typical/flagship tier) is
/// the tractable version of "measured by normal standards": every turn
/// prices as real, paid usage instead of trusting whatever the provider (or
/// OpenCode itself) reports, or showing "n/a" for a provider this app just
/// hasn't been told about individually.
///
/// Provider ids are OpenCode's own `providerID` strings, matched exactly —
/// case as OpenCode itself uses them. A provider not listed here still
/// prices, via [kOpencodeGenericProviderFallback] in [opencodeProviderPricingFor].
const Map<String, AiPricingRates> kOpencodeProviderPricing = {
  // Already-seen in real usage: OpenCode's own MiniMax integration.
  'minimax': AiPricingRates(input: 0.30, output: 1.20, cacheWrite: 0.30, cacheRead: 0.03),

  // Budget-tier frontier labs commonly reachable through OpenCode.
  'deepseek': AiPricingRates(input: 0.28, output: 0.42, cacheWrite: 0.28, cacheRead: 0.028),
  'moonshotai': AiPricingRates(input: 0.60, output: 2.50, cacheWrite: 0.60, cacheRead: 0.06),
  'zhipuai': AiPricingRates(input: 0.60, output: 2.20, cacheWrite: 0.60, cacheRead: 0.06),
  'alibaba': AiPricingRates(input: 0.40, output: 1.20, cacheWrite: 0.40, cacheRead: 0.04),
  'qwen': AiPricingRates(input: 0.40, output: 1.20, cacheWrite: 0.40, cacheRead: 0.04),

  // Mid/frontier-tier labs.
  'mistral': AiPricingRates(input: 2.00, output: 6.00, cacheWrite: 2.00, cacheRead: 0.20),
  'xai': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.00, cacheRead: 0.30),
  'perplexity': AiPricingRates(input: 1.00, output: 1.00, cacheWrite: 1.00, cacheRead: 0.10),

  // Open-weight hosts — priced per token like any other API, even though
  // the model itself is open source; you're still paying the host to run it.
  'groq': AiPricingRates(input: 0.10, output: 0.10, cacheWrite: 0.10, cacheRead: 0.01),
  'cerebras': AiPricingRates(input: 0.10, output: 0.10, cacheWrite: 0.10, cacheRead: 0.01),
  'together': AiPricingRates(input: 0.20, output: 0.20, cacheWrite: 0.20, cacheRead: 0.02),
  'fireworks': AiPricingRates(input: 0.20, output: 0.20, cacheWrite: 0.20, cacheRead: 0.02),
  'huggingface': AiPricingRates(input: 0.50, output: 1.50, cacheWrite: 0.50, cacheRead: 0.05),

  // Aggregators/proxies — routes to many underlying models at roughly
  // market rate, so priced at a blended middle-of-the-road estimate.
  'openrouter': AiPricingRates(input: 1.00, output: 3.00, cacheWrite: 1.00, cacheRead: 0.10),

  // Cloud reseller routes for models this app already prices exactly under
  // their native provider — mirrored to the comparable flagship tier
  // (Azure ~ GPT-5.4, Bedrock/Vertex ~ a frontier Claude/Gemini rate) since
  // the reseller markup/discount varies by account and can't be known here.
  'azure': AiPricingRates(input: 2.50, output: 15.00, cacheWrite: 0, cacheRead: 0.25),
  'amazon-bedrock': AiPricingRates(input: 2.00, output: 10.00, cacheWrite: 2.00, cacheRead: 0.20),
  'bedrock': AiPricingRates(input: 2.00, output: 10.00, cacheWrite: 2.00, cacheRead: 0.20),
  'google-vertex': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),
  'vertex': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),
  'google': AiPricingRates(input: 2.00, output: 12.00, cacheWrite: 0, cacheRead: 0.20),

  // Priced as if paid per-token via a normal API key, per the same "as if
  // you use it via api key" standard as everything else here — even though
  // OpenCode's actual Copilot integration draws on an existing GitHub
  // Copilot subscription rather than billing per token.
  'github-copilot': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.00, cacheRead: 0.30),
  'copilot': AiPricingRates(input: 3.00, output: 15.00, cacheWrite: 3.00, cacheRead: 0.30),
};

/// Providers that run entirely on the user's own hardware — there is no API
/// bill to estimate because there is no API call. A real $0.00, not a
/// discount or a missing rate, so these turns still read as "known cost"
/// (see [rowHasKnownCost] in ai_usage_stats.dart) rather than "n/a".
const Set<String> kOpencodeLocalProviders = {
  'ollama',
  'llama.cpp',
  'llamacpp',
  'lmstudio',
  'lm-studio',
  'local',
};

const AiPricingRates _kOpencodeLocalRate =
    AiPricingRates(input: 0, output: 0, cacheWrite: 0, cacheRead: 0);

/// Rate for a provider that is neither OpenCode's own Zen catalog, a
/// provider this app prices exactly (Anthropic, OpenAI), a locally-run
/// runtime, nor one of the named entries in [kOpencodeProviderPricing] —
/// i.e. a provider OpenCode added support for after this table was last
/// updated, or a community/custom one. Pinned to a generic mid-tier rate so
/// "all models OpenCode can provide" holds even for a provider this app has
/// literally never heard of, rather than falling through to "n/a".
const AiPricingRates kOpencodeGenericProviderFallback =
    AiPricingRates(input: 1.00, output: 3.00, cacheWrite: 1.00, cacheRead: 0.10);

/// Resolves any OpenCode `providerID` (other than `'opencode'` itself,
/// `'anthropic'`, or `'openai'` — those have their own exact tables) to a
/// rate. Always non-null: a local runtime prices at a real $0, a named
/// third-party provider at its estimated rate, and anything else at
/// [kOpencodeGenericProviderFallback].
AiPricingRates opencodeProviderPricingFor(String provider) {
  if (kOpencodeLocalProviders.contains(provider)) return _kOpencodeLocalRate;
  return kOpencodeProviderPricing[provider] ?? kOpencodeGenericProviderFallback;
}

import 'ai_usage_pricing_anthropic.dart';
import 'ai_usage_pricing_gemini.dart';
import 'ai_usage_pricing_openai.dart';
import 'ai_usage_pricing_rates.dart';
import 'ai_usage_source.dart';

export 'ai_usage_pricing_anthropic.dart';
export 'ai_usage_pricing_gemini.dart';
export 'ai_usage_pricing_openai.dart';
export 'ai_usage_pricing_rates.dart';

/// Antigravity's own UI names the model in prose (e.g. `"Gemini 3.1 Pro
/// (High)"`, `"Claude Opus 4.6 (Thinking)"`) rather than a raw API slug.
/// Tries Gemini first, then falls back to Anthropic's family-word matching
/// for Claude-named turns — which only ever resolves via that table's
/// family fallback (never its exact/dated-prefix tiers, since those expect
/// slugs like `"claude-opus-4-6"`, not this prose form), so a detected
/// "Claude Opus 4.6" always prices as whatever's currently the newest known
/// Opus rate rather than a version-specific one. Accepted: this is already
/// an estimate stacked on an estimate (Antigravity's token counts
/// themselves are derived from message length, not metered).
AiPricingRates? _antigravityPricingFor(String? model) {
  if (model == null) return null;
  final stripped = stripReasoningEffortSuffix(model);
  final gemini = geminiPricingFor(stripped);
  if (gemini != null) return gemini;
  if (isAnthropicBillableModel(stripped)) return anthropicPricingFor(stripped);
  return null;
}

/// opencode's scanner stores each turn's model as `"<providerID>/<modelID>"`
/// (see `opencode_scanner.dart`) since a single turn can go through any
/// provider the user configured. Routes to that provider's own pricing
/// table when it's one this app already prices exactly (raw API model IDs,
/// same as Claude Code/Codex's own turns); everything else — opencode's own
/// gateway/free models, OpenRouter, Groq, etc. — is unpriced rather than
/// guessed at.
AiPricingRates? _opencodePricingFor(String model) {
  final slash = model.indexOf('/');
  if (slash < 0) return null;
  final provider = model.substring(0, slash);
  final modelId = model.substring(slash + 1);
  return switch (provider) {
    'anthropic' => anthropicPricingFor(modelId),
    'openai' => openAiPricingFor(modelId),
    _ => null,
  };
}

/// Whether [model] is a recognized, priced model for [source]. Anything else
/// is grouped as "Other" in the UI, with cost shown as n/a. For Antigravity,
/// "recognized" means its detected model matched a known Gemini or Claude
/// family (see [_antigravityPricingFor]) — its cost is always shown more
/// tentatively than Claude Code/Codex's exact figures, since the token
/// counts feeding into it are themselves estimated from message length, not
/// metered.
bool isBillableModel(AiUsageSource source, String? model) => switch (source) {
      AiUsageSource.claudeCode => isAnthropicBillableModel(model),
      AiUsageSource.codexCli => isOpenAiBillableModel(model),
      AiUsageSource.antigravity => _antigravityPricingFor(model) != null,
      AiUsageSource.opencode => model != null && _opencodePricingFor(model) != null,
    };

/// Resolves [model]'s pricing rates for [source], or null if unrecognized.
AiPricingRates? pricingFor(AiUsageSource source, String? model) => switch (source) {
      AiUsageSource.claudeCode => anthropicPricingFor(model),
      AiUsageSource.codexCli => openAiPricingFor(model),
      AiUsageSource.antigravity => _antigravityPricingFor(model),
      AiUsageSource.opencode => model == null ? null : _opencodePricingFor(model),
    };

/// Estimated USD cost of one turn's token usage, or 0 for a non-billable /
/// unrecognized model.
double costForTurn(
  AiUsageSource source,
  String? model,
  int inputTokens,
  int outputTokens,
  int cacheReadTokens,
  int cacheCreationTokens,
) {
  if (!isBillableModel(source, model)) return 0;
  final rates = pricingFor(source, model);
  if (rates == null) return 0;
  return inputTokens * rates.input / 1e6 +
      outputTokens * rates.output / 1e6 +
      cacheReadTokens * rates.cacheRead / 1e6 +
      cacheCreationTokens * rates.cacheWrite / 1e6;
}

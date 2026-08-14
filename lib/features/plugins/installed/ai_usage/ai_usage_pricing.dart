import 'ai_usage_pricing_anthropic.dart';
import 'ai_usage_pricing_openai.dart';
import 'ai_usage_pricing_rates.dart';
import 'ai_usage_source.dart';

export 'ai_usage_pricing_anthropic.dart';
export 'ai_usage_pricing_openai.dart';
export 'ai_usage_pricing_rates.dart';

/// Whether [model] is a recognized, priced model for [source]. Anything else
/// is grouped as "Other" in the UI, with cost shown as n/a.
bool isBillableModel(AiUsageSource source, String? model) => switch (source) {
      AiUsageSource.claudeCode => isAnthropicBillableModel(model),
      AiUsageSource.codexCli => isOpenAiBillableModel(model),
    };

/// Resolves [model]'s pricing rates for [source], or null if unrecognized.
AiPricingRates? pricingFor(AiUsageSource source, String? model) => switch (source) {
      AiUsageSource.claudeCode => anthropicPricingFor(model),
      AiUsageSource.codexCli => openAiPricingFor(model),
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

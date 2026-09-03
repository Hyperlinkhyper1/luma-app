import 'ai_modes.dart';
import 'ai_providers.dart';

/// A trackable "model" the assistant can send a message through — one entry
/// per provider, split further for Luma AI since its three Gemini tiers
/// have meaningfully different cost/capability (unlike Mistral/Anthropic/
/// OpenAI, which are each a single model).
class ModelUsageEntry {
  const ModelUsageEntry(this.key, this.label, this.weight);

  /// Matches what [modelUsageKeyFor] produces, and what's stored in
  /// `SettingsController.modelUsage`.
  final String key;
  final String label;

  /// Relative cost per message vs the cheapest model (weight 1). Based on
  /// published Gemini API pricing — blended input/output per 1M tokens,
  /// roughly: flash-lite $0.25, flash $1.40, pro $5.60+ — rounded down to
  /// keep the numbers readable. Non-Gemini models don't have a comparable
  /// tier, so they're left at 1x like the cheapest tier.
  final int weight;
}

const List<ModelUsageEntry> kModelUsageEntries = [
  ModelUsageEntry('google:normal', 'Luma Aurora 1.0', 1),
  ModelUsageEntry('google:smarter', 'Luma Nebula 1.0', 5),
  ModelUsageEntry('google:smartest', 'Luma Pulsar 1.0', 20),
  ModelUsageEntry('mistral', 'Luma Assistant 1.0', 1),
  ModelUsageEntry('anthropic', 'Anthropic Claude', 1),
  ModelUsageEntry('openai', 'OpenAI', 1),
];

/// The usage-tracking key for whichever model [providerId] (+ [mode], for
/// Luma AI) currently resolves to — matches a [ModelUsageEntry.key].
String modelUsageKeyFor(String providerId, {AiMode? mode}) {
  if (providerId == AiProviderId.google.name) {
    return 'google:${(mode ?? AiMode.normal).name}';
  }
  return providerId;
}

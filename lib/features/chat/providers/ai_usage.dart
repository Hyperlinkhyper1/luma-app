import 'ai_modes.dart';
import 'ai_providers.dart';

/// A trackable "model" the assistant can send a message through — one entry
/// per provider, split further for Luma AI since its three Gemini tiers
/// have different capabilities (unlike Anthropic/OpenAI, which are each a
/// single model here).
class ModelUsageEntry {
  const ModelUsageEntry(this.key, this.label);

  /// Matches what [modelUsageKeyFor] produces, and what's stored in
  /// `SettingsController.modelUsage`.
  final String key;
  final String label;

  String labelFor(Map<String, String> modeVersions) {
    if (!key.startsWith('google:')) return label;
    final mode = aiModeById(key.substring('google:'.length));
    return 'Luma ${mode.displayNameFor(modeVersions[mode.name])}';
  }
}

const List<ModelUsageEntry> kModelUsageEntries = [
  ModelUsageEntry('google:normal', 'Luma Aurora 1.0'),
  ModelUsageEntry('google:smarter', 'Luma Nebula 1.0'),
  ModelUsageEntry('google:smartest', 'Luma Pulsar 1.0'),
  ModelUsageEntry('local', 'Luma Assistant (on-device Qwen)'),
  ModelUsageEntry('anthropic', 'Anthropic Claude'),
  ModelUsageEntry('openai', 'OpenAI'),
];

/// The usage-tracking key for whichever model [providerId] (+ [mode], for
/// Luma AI) currently resolves to — matches a [ModelUsageEntry.key].
String modelUsageKeyFor(String providerId, {AiMode? mode}) {
  if (providerId == AiProviderId.google.name) {
    return 'google:${(mode ?? AiMode.normal).name}';
  }
  return providerId;
}

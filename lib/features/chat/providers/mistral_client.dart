import 'openai_compatible_client.dart';

/// Talks to Mistral's La Plateforme API (OpenAI-compatible chat completions)
/// directly from the device using the user's own API key.
///
/// Shown to the user in the provider picker as "Luma" with a moon icon —
/// see `providers/ai_providers.dart` — that's a UI label only; the wire
/// protocol underneath is Mistral's.
class MistralClient extends OpenAiCompatibleClient {
  MistralClient()
      : super(
          baseUrl: 'https://api.mistral.ai/v1/chat/completions',
          defaultModel: 'mistral-small-latest',
          providerLabel: 'Mistral',
          agentsBaseUrl: 'https://api.mistral.ai/v1/agents/completions',
        );
}

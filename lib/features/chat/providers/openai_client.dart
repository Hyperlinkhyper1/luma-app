import 'openai_compatible_client.dart';

/// Talks to OpenAI's Chat Completions API directly from the device using the
/// user's own API key.
class OpenAiClient extends OpenAiCompatibleClient {
  OpenAiClient()
      : super(
          baseUrl: 'https://api.openai.com/v1/chat/completions',
          defaultModel: 'gpt-4o-mini',
          providerLabel: 'OpenAI',
        );
}

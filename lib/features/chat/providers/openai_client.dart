import 'openai_compatible_client.dart';

/// Talks to OpenAI's Chat Completions API directly from the device using the
/// user's own API key.
///
/// Sends `max_completion_tokens` rather than `max_tokens`: OpenAI's
/// reasoning models (the whole GPT-5 line) reject the older field outright.
class OpenAiClient extends OpenAiCompatibleClient {
  OpenAiClient({String model = defaultModelId})
    : super(
        baseUrl: 'https://api.openai.com/v1/chat/completions',
        defaultModel: model,
        providerLabel: 'OpenAI',
        disableResponseStorage: true,
        maxOutputTokens: 8192,
        maxTokensField: 'max_completion_tokens',
      );

  static const defaultModelId = 'gpt-5.4-mini';
}

/// Talks to OpenRouter's OpenAI-compatible endpoint with the user's own
/// OpenRouter key. The model is any OpenRouter slug (`vendor/model`);
/// `openrouter/auto` lets OpenRouter pick one per request.
class OpenRouterClient extends OpenAiCompatibleClient {
  OpenRouterClient({String model = defaultModelId})
    : super(
        baseUrl: 'https://openrouter.ai/api/v1/chat/completions',
        defaultModel: model,
        providerLabel: 'OpenRouter',
        maxOutputTokens: 8192,
        extraHeaders: const {'X-Title': 'luma'},
      );

  static const defaultModelId = 'openrouter/auto';
}

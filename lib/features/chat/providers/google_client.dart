import '../assistant_effort.dart';
import 'ai_modes.dart';
import 'openai_compatible_client.dart';

/// Talks to Google AI Studio's OpenAI-compatible endpoint directly from the
/// device using the user's own API key. Presented in the app as "Luma AI"
/// with three modes (see [AiMode]); the wire protocol underneath is
/// Gemini's OpenAI-compat layer.
class GoogleClient extends OpenAiCompatibleClient {
  GoogleClient({
    AiMode mode = AiMode.normal,
    AssistantEffort effort = AssistantEffort.medium,
  }) : super(
         baseUrl:
             'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
         defaultModel: mode.geminiModel,
         providerLabel: 'Luma AI',
         reasoningEffort: effort.reasoningEffortFor(mode.reasoningEffort),
         maxOutputTokens: effort.maxOutputTokens,
         timeout: effort.timeout,
       );
}

/// Google Gemini with the user's own AI Studio key, picked from the API
/// screen. Unlike [GoogleClient] it is not wearing luma branding and the
/// user chooses the model.
class GeminiClient extends OpenAiCompatibleClient {
  GeminiClient({String model = defaultModelId})
    : super(
        baseUrl:
            'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
        defaultModel: model,
        providerLabel: 'Google Gemini',
        maxOutputTokens: 8192,
      );

  static const defaultModelId = 'gemini-flash-latest';
}

/// Talks to Google through the sync server's proxy (POST
/// /api/v1/ai/google/chat) when the user relies on the server's shared key
/// — the mirror image of [MistralProxyClient]. Sends the *mode name*
/// ("normal"/"smarter"/"smartest") as the model; the server maps it to a
/// real Gemini model and meters the user's token budget.
///
/// As with the Mistral proxy, the "apiKey" callers pass to [chat] is the
/// sync bearer token, not a Google key.
class GoogleProxyClient extends OpenAiCompatibleClient {
  GoogleProxyClient({
    required String serverUrl,
    AiMode mode = AiMode.normal,
    this.effort = AssistantEffort.medium,
  }) : super(
         baseUrl: _proxyUrl(serverUrl),
         defaultModel: mode.name,
         providerLabel: 'Luma AI',
         // Only the level is sent. The server decides the reasoning
         // setting and output budget for it and charges the usage, so
         // nothing here can make a turn cheaper than it is. The raw
         // reasoning_effort is for servers from before effort levels; newer
         // ones replace it with their own.
         reasoningEffort: effort.reasoningEffortFor(mode.reasoningEffort),
         maxOutputTokens: effort.maxOutputTokens,
         timeout: effort.timeout,
         extraBody: {'luma_effort': effort.name},
         viaLumaServer: true,
       );

  final AssistantEffort effort;

  static String _proxyUrl(String serverUrl) {
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return '$url/api/v1/ai/google/chat';
  }
}

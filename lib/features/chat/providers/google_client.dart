import 'ai_modes.dart';
import 'openai_compatible_client.dart';

/// Talks to Google AI Studio's OpenAI-compatible endpoint directly from the
/// device using the user's own API key. Presented in the app as "Luma AI"
/// with three modes (see [AiMode]); the wire protocol underneath is
/// Gemini's OpenAI-compat layer.
class GoogleClient extends OpenAiCompatibleClient {
  GoogleClient({AiMode mode = AiMode.normal})
      : super(
          baseUrl:
              'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
          defaultModel: mode.geminiModel,
          providerLabel: 'Luma AI',
          reasoningEffort: mode.reasoningEffort,
        );
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
  GoogleProxyClient({required String serverUrl, AiMode mode = AiMode.normal})
      : super(
          baseUrl: _proxyUrl(serverUrl),
          defaultModel: mode.name,
          providerLabel: 'Luma AI',
          // The server forwards whatever's in the request body (beyond the
          // model/max_tokens it overrides itself) straight to Google, so
          // sending this here is enough — no server-side mode→effort
          // mapping needed alongside its existing mode→model one.
          reasoningEffort: mode.reasoningEffort,
        );

  static String _proxyUrl(String serverUrl) {
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return '$url/api/v1/ai/google/chat';
  }
}

import 'openai_compatible_client.dart';

/// Talks to Mistral through the sync server's proxy (POST
/// /api/v1/ai/mistral/chat) instead of directly, when the user is relying on
/// the server's shared key rather than one of their own — see
/// SyncService.mistralKeyConfiguredOnServer and ChatController.
///
/// The "apiKey" passed to [chat] by callers is actually the sync bearer
/// token, not a Mistral key — reusing [OpenAiCompatibleClient]'s single
/// credential slot. The server attaches the real Mistral key itself
/// (Api._mistralChatProxy); this client never sees or sends it.
class MistralProxyClient extends OpenAiCompatibleClient {
  MistralProxyClient({required String serverUrl})
      : super(
          baseUrl: _proxyUrl(serverUrl),
          agentsBaseUrl: _proxyUrl(serverUrl),
          defaultModel: 'mistral-small-latest',
          providerLabel: 'Luma',
        );

  static String _proxyUrl(String serverUrl) {
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return '$url/api/v1/ai/mistral/chat';
  }
}

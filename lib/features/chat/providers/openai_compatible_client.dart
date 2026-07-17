import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Shared implementation for providers that speak the OpenAI-style
/// `/chat/completions` wire format (OpenAI itself, Mistral's La Plateforme,
/// and others that copy the same shape). Only the base URL and default model
/// differ between them — see [OpenAiClient] / [MistralClient].
class OpenAiCompatibleClient implements AiClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.defaultModel,
    required this.providerLabel,
    this.agentsBaseUrl,
    this.maxOutputTokens = 1024,
    this.reasoningEffort,
  });

  final String baseUrl;
  final String defaultModel;

  /// Used only in error messages, e.g. "OpenAI rejected the API key.".
  final String providerLabel;
  final int maxOutputTokens;

  /// Endpoint for hosted-agent requests (e.g. Mistral's
  /// `/v1/agents/completions`), if this provider supports them. When null,
  /// an [agentId] passed to [chat] is ignored.
  final String? agentsBaseUrl;

  /// Sent as `reasoning_effort` ("low"/"medium"/"high") on every request,
  /// for providers/models that support a thinking-effort knob (currently
  /// only Gemini, via [GoogleClient]'s Pulsar mode). Omitted from the
  /// request body entirely when null, so providers that don't recognize
  /// the field never see it.
  final String? reasoningEffort;

  static const _maxToolHops = 5;

  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
    String? agentId,
  }) async {
    final useAgent = agentId != null && agentsBaseUrl != null;
    final messages = <Map<String, dynamic>>[
      if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
      for (final t in history) {'role': t.role, 'content': t.text},
    ];
    final toolSchemas = [
      for (final t in tools)
        {
          'type': 'function',
          'function': {
            'name': t.name,
            'description': t.description,
            'parameters': t.parameters,
          },
        },
    ];

    var hops = 0;
    String? metadataJson;
    while (true) {
      final message = await _send(
        apiKey,
        messages,
        toolSchemas,
        useAgent ? agentId : null,
      );
      final toolCalls =
          (message['tool_calls'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];

      if (toolCalls.isEmpty) {
        final text = (message['content'] as String?)?.trim() ?? '';
        return AiChatResult(
          text: text.isEmpty ? "I couldn't come up with a reply for that." : text,
          metadataJson: metadataJson,
        );
      }

      hops++;
      if (hops > _maxToolHops) {
        return AiChatResult(
          text: "I couldn't finish that — too many tool steps.",
          metadataJson: metadataJson,
        );
      }

      messages.add({
        'role': 'assistant',
        'content': message['content'],
        'tool_calls': toolCalls,
      });
      for (final call in toolCalls) {
        final fn = call['function'] as Map<String, dynamic>;
        final name = fn['name'] as String;
        final args = _decodeArgs(fn['arguments']);
        final result = await executeTool(name, args);
        metadataJson ??= metadataFor(name, result);
        messages.add({
          'role': 'tool',
          'tool_call_id': call['id'],
          'content': jsonEncode(result),
        });
      }
    }
  }

  /// Extracts a human-readable error message from an error response body —
  /// either the OpenAI shape `{"error": {"message": ...}}`, the sync
  /// server's `{"error": code, "message": ...}`, or Google's OpenAI-compat
  /// endpoint, which wraps that same object shape in a top-level JSON
  /// array (`[{"error": {...}}]`) — easy to miss since every other
  /// provider here returns a bare object.
  static String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      final obj =
          decoded is List && decoded.isNotEmpty ? decoded.first : decoded;
      if (obj is Map) {
        final err = obj['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (obj['message'] is String) return obj['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeArgs(Object? raw) {
    if (raw is String) {
      try {
        return (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        return {};
      }
    }
    if (raw is Map) return raw.cast<String, dynamic>();
    return {};
  }

  Future<Map<String, dynamic>> _send(
    String apiKey,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    String? agentId,
  ) async {
    final body = <String, dynamic>{
      if (agentId != null) 'agent_id': agentId else 'model': defaultModel,
      'messages': messages,
      'max_tokens': maxOutputTokens,
      if (tools.isNotEmpty) 'tools': tools,
      if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
    };
    final url = agentId != null ? agentsBaseUrl! : baseUrl;

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiNetworkError(
          "Couldn't reach $providerLabel — check your connection.\n($e)");
    }

    if (res.statusCode == 401) {
      throw AiAuthError('$providerLabel rejected the API key. Check it in Settings.');
    }
    if (res.statusCode == 429) {
      // Surface the server's own wording when it explains the limit (e.g.
      // the sync server's usage budgets) instead of a generic message.
      throw AiRateLimitError(_messageFromBody(res.body) ??
          'Too many requests — try again shortly.');
    }
    if (res.statusCode != 200) {
      throw AiApiError(_messageFromBody(res.body) ??
          '$providerLabel returned an error (${res.statusCode}).');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List;
    return (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
  }
}

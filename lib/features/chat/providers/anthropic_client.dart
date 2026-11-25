import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../l10n/current_l.dart';
import 'ai_client.dart';

class _RawResponse {
  const _RawResponse({
    required this.text,
    required this.toolUses,
    required this.rawContent,
    this.usage,
  });
  final String text;
  final List<Map<String, dynamic>> toolUses;
  final List<Map<String, dynamic>> rawContent;
  final AiTokenUsage? usage;
}

/// Talks to Anthropic's Messages API directly from the device using the
/// user's own API key — never proxied through any luma server.
class AnthropicClient implements AiClient {
  AnthropicClient({this.model = defaultModel});

  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  /// Used when the user hasn't picked a model on the API screen.
  static const defaultModel = 'claude-opus-5-5';

  /// Current models think before answering, and that thinking counts
  /// against this cap, so it has to leave room for both.
  static const _maxOutputTokens = 16000;
  static const _maxToolHops = 24;

  /// Models that accept the server-side fallback for refused requests.
  static const _fallbackModels = {
    'claude-fable-5-2',
    'claude-fable-5-1',
    'claude-opus-5-5',
    'claude-opus-5',
    'claude-sonnet-5-5',
  };

  final String model;

  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
    AiTextProgress? onText,
  }) async {
    final messages = <Map<String, dynamic>>[
      for (final t in history)
        {
          'role': t.role,
          'content': [
            {'type': 'text', 'text': t.text},
            for (final image in t.images)
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': image.mimeType,
                  'data': image.data,
                },
              },
          ],
        },
    ];
    final toolSchemas = [
      for (final t in tools)
        {
          'name': t.name,
          'description': t.description,
          'input_schema': t.parameters,
        },
    ];

    var hops = 0;
    String? metadataJson;
    AiTokenUsage? usage;
    while (true) {
      final res = await _send(
        apiKey: apiKey,
        messages: messages,
        systemPrompt: systemPrompt,
        tools: toolSchemas,
      );
      usage = addAiUsage(usage, res.usage);

      if (res.toolUses.isEmpty) {
        final text = res.text.isEmpty ? currentL.aiClientNoReply : res.text;
        return AiChatResult(
          text: text,
          metadataJson: metadataJson,
          usage: usage,
        );
      }

      hops++;
      if (hops > _maxToolHops) {
        return AiChatResult(
          text: res.text.isEmpty ? currentL.aiClientTooManySteps : res.text,
          metadataJson: metadataJson,
          usage: usage,
        );
      }

      messages.add({'role': 'assistant', 'content': res.rawContent});
      final toolResults = <Map<String, dynamic>>[];
      for (final toolUse in res.toolUses) {
        final name = toolUse['name'] as String;
        final input = (toolUse['input'] as Map?)?.cast<String, dynamic>() ?? {};
        final result = await executeTool(name, input);
        metadataJson ??= metadataFor(name, result);
        toolResults.add({
          'type': 'tool_result',
          'tool_use_id': toolUse['id'],
          'content': jsonEncode(result),
        });
      }
      messages.add({'role': 'user', 'content': toolResults});
    }
  }

  Future<_RawResponse> _send({
    required String apiKey,
    required List<Map<String, dynamic>> messages,
    required String systemPrompt,
    required List<Map<String, dynamic>> tools,
  }) async {
    final fallback = _fallbackModels.contains(model);
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': _maxOutputTokens,
      if (fallback) 'fallbacks': 'default',
      'messages': messages,
      if (systemPrompt.isNotEmpty) 'system': systemPrompt,
      if (tools.isNotEmpty) 'tools': tools,
    };

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': _apiVersion,
              if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 3));
    } catch (e) {
      throw AiNetworkError(currentL.aiClientUnreachable('Anthropic', '$e'));
    }

    if (res.statusCode == 401) {
      throw AiAuthError(currentL.aiClientKeyRejected('Anthropic'));
    }
    if (res.statusCode == 429) {
      throw AiRateLimitError(currentL.aiClientRateLimited);
    }
    if (res.statusCode != 200) {
      String message = currentL.aiClientApiError('Anthropic', res.statusCode);
      try {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final err = decoded['error'] as Map<String, dynamic>?;
        if (err?['message'] is String) message = err!['message'] as String;
      } catch (_) {
        // Keep the generic message above.
      }
      throw AiApiError(message);
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (decoded['content'] as List).cast<Map<String, dynamic>>();

    final textParts = <String>[];
    final toolUses = <Map<String, dynamic>>[];
    for (final block in content) {
      switch (block['type']) {
        case 'text':
          textParts.add(block['text'] as String? ?? '');
        case 'tool_use':
          toolUses.add(block);
      }
    }

    return _RawResponse(
      text: textParts.join('\n').trim(),
      toolUses: toolUses,
      rawContent: content,
      usage: _usageFrom(decoded),
    );
  }

  AiTokenUsage? _usageFrom(Map<String, dynamic> decoded) {
    final usage = decoded['usage'];
    if (usage is! Map) return null;
    int count(String key) => (usage[key] as num?)?.toInt() ?? 0;
    final reported = decoded['model'];
    return AiTokenUsage(
      model: reported is String && reported.isNotEmpty ? reported : model,
      inputTokens: count('input_tokens'),
      outputTokens: count('output_tokens'),
      cacheReadTokens: count('cache_read_input_tokens'),
      cacheWriteTokens: count('cache_creation_input_tokens'),
    );
  }
}

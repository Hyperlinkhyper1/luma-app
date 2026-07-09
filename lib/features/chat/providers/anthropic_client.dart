import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';

class _RawResponse {
  const _RawResponse({
    required this.text,
    required this.toolUses,
    required this.rawContent,
  });
  final String text;
  final List<Map<String, dynamic>> toolUses;
  final List<Map<String, dynamic>> rawContent;
}

/// Talks to Anthropic's Messages API directly from the device using the
/// user's own API key — never proxied through any luma server.
class AnthropicClient implements AiClient {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  /// Easy to bump to a more capable model later.
  static const defaultModel = 'claude-3-5-haiku-20241022';
  static const _maxOutputTokens = 1024;
  static const _maxToolHops = 5;

  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
    String? agentId, // Not supported by Anthropic — ignored.
  }) async {
    final messages = <Map<String, dynamic>>[
      for (final t in history)
        {
          'role': t.role,
          'content': [
            {'type': 'text', 'text': t.text},
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
    while (true) {
      final res =
          await _send(apiKey: apiKey, messages: messages, systemPrompt: systemPrompt, tools: toolSchemas);

      if (res.toolUses.isEmpty) {
        final text = res.text.isEmpty
            ? "I couldn't come up with a reply for that."
            : res.text;
        return AiChatResult(text: text, metadataJson: metadataJson);
      }

      hops++;
      if (hops > _maxToolHops) {
        return AiChatResult(
          text: res.text.isEmpty
              ? "I couldn't finish that — too many tool steps."
              : res.text,
          metadataJson: metadataJson,
        );
      }

      messages.add({'role': 'assistant', 'content': res.rawContent});
      final toolResults = <Map<String, dynamic>>[];
      for (final toolUse in res.toolUses) {
        final name = toolUse['name'] as String;
        final input =
            (toolUse['input'] as Map?)?.cast<String, dynamic>() ?? {};
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
    final body = <String, dynamic>{
      'model': defaultModel,
      'max_tokens': _maxOutputTokens,
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
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiNetworkError(
          "Couldn't reach Anthropic — check your connection.\n($e)");
    }

    if (res.statusCode == 401) {
      throw AiAuthError(
          'Anthropic rejected the API key. Check it in Settings.');
    }
    if (res.statusCode == 429) {
      throw AiRateLimitError('Too many requests — try again shortly.');
    }
    if (res.statusCode != 200) {
      String message = 'Anthropic returned an error (${res.statusCode}).';
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
    );
  }
}

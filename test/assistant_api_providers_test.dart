import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/providers/ai_providers.dart';

Future<http.Request> _send(AiClient client, Map<String, dynamic> reply) async {
  late http.Request sent;
  final mock = MockClient((request) async {
    sent = request;
    return http.Response(jsonEncode(reply), 200);
  });
  await http.runWithClient(
    () => client.chat(
      apiKey: 'key',
      history: const [AiTurn(role: 'user', text: 'Hi')],
      systemPrompt: '',
      tools: const [],
      executeTool: (_, _) async => const {},
      metadataFor: (_, _) => null,
    ),
    () => mock,
  );
  return sent;
}

const _openAiReply = {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': 'Hello'},
    },
  ],
};

void main() {
  test('the API screen lists Claude, OpenAI, OpenRouter and Google', () {
    expect(kApiKeyProviders.map((p) => p.id), [
      AiProviderId.anthropic,
      AiProviderId.openai,
      AiProviderId.openrouter,
      AiProviderId.gemini,
    ]);
    for (final p in kApiKeyProviders) {
      expect(p.defaultModel, isNotEmpty, reason: p.id.name);
      expect(p.keyUrl, startsWith('https://'), reason: p.id.name);
    }
  });

  test('Claude sends the chosen model with room to think', () async {
    final request = await _send(
      aiClientFor('anthropic', model: 'claude-sonnet-5-5'),
      {
        'model': 'claude-sonnet-5-5',
        'content': [
          {'type': 'thinking', 'thinking': ''},
          {'type': 'text', 'text': 'Hello'},
        ],
      },
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.url.host, 'api.anthropic.com');
    expect(request.headers['x-api-key'], 'key');
    expect(body['model'], 'claude-sonnet-5-5');
    expect(body['max_tokens'], greaterThanOrEqualTo(16000));
    expect(body['fallbacks'], 'default');
  });

  test('Claude falls back to its default model', () async {
    final request = await _send(aiClientFor('anthropic', model: '  '), {
      'content': [
        {'type': 'text', 'text': 'Hello'},
      ],
    });
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['model'], aiProviderById('anthropic').defaultModel);
  });

  test('OpenAI uses max_completion_tokens', () async {
    final request = await _send(
      aiClientFor('openai', model: 'gpt-5.4-nano'),
      _openAiReply,
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.url.host, 'api.openai.com');
    expect(body['model'], 'gpt-5.4-nano');
    expect(body.containsKey('max_tokens'), isFalse);
    expect(body['max_completion_tokens'], greaterThan(1024));
  });

  test('OpenRouter talks to openrouter.ai with the chosen slug', () async {
    final request = await _send(
      aiClientFor('openrouter', model: 'anthropic/claude-sonnet-5-5'),
      _openAiReply,
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(
      request.url.toString(),
      'https://openrouter.ai/api/v1/chat/completions',
    );
    expect(request.headers['Authorization'], 'Bearer key');
    expect(body['model'], 'anthropic/claude-sonnet-5-5');
    expect(body['max_tokens'], greaterThan(1024));
  });

  test('Google Gemini uses the user key against AI Studio', () async {
    final request = await _send(aiClientFor('gemini'), _openAiReply);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.url.host, 'generativelanguage.googleapis.com');
    expect(body['model'], aiProviderById('gemini').defaultModel);
  });
}

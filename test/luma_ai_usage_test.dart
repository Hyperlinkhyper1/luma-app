import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/providers/anthropic_client.dart';
import 'package:luma/features/chat/providers/openai_client.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_format.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_pricing.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_stats.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

Future<AiChatResult> _chat(AiClient client, {List<AiToolDefinition> tools = const []}) =>
    client.chat(
      apiKey: 'key',
      history: const [AiTurn(role: 'user', text: 'Hi')],
      systemPrompt: '',
      tools: tools,
      executeTool: (_, _) async => const {'ok': true},
      metadataFor: (_, _) => null,
    );

const _tool = AiToolDefinition(
  name: 'ping',
  description: 'ping',
  parameters: {'type': 'object'},
);

void main() {
  group('client usage', () {
    test('OpenAI-shape usage splits cached input and sums tool hops', () async {
      var call = 0;
      final mock = MockClient((request) async {
        call++;
        final message = call == 1
            ? {
                'role': 'assistant',
                'content': null,
                'tool_calls': [
                  {
                    'id': 't1',
                    'type': 'function',
                    'function': {'name': 'ping', 'arguments': '{}'},
                  },
                ],
              }
            : {'role': 'assistant', 'content': 'Done'};
        return http.Response(
          jsonEncode({
            'model': 'gpt-4o-mini-2024-07-18',
            'choices': [
              {'message': message},
            ],
            'usage': {
              'prompt_tokens': 100,
              'completion_tokens': 20,
              'total_tokens': 120,
              'prompt_tokens_details': {'cached_tokens': 40},
            },
          }),
          200,
        );
      });

      final result = await http.runWithClient(
        () => _chat(OpenAiClient(), tools: const [_tool]),
        () => mock,
      );

      expect(result.text, 'Done');
      final usage = result.usage!;
      expect(usage.model, 'gpt-4o-mini-2024-07-18');
      expect(usage.requests, 2);
      expect(usage.inputTokens, 120);
      expect(usage.cacheReadTokens, 80);
      expect(usage.outputTokens, 40);
    });

    test('Gemini thinking tokens left out of completion count as output', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'model': 'gemini-flash-latest',
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'Hi'},
                },
              ],
              'usage': {
                'prompt_tokens': 10,
                'completion_tokens': 5,
                'total_tokens': 65,
              },
            }),
            200,
          ));

      final result = await http.runWithClient(() => _chat(OpenAiClient()), () => mock);

      expect(result.usage!.outputTokens, 55);
      expect(result.usage!.totalTokens, 65);
    });

    test('a response without usage reports none', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'Hi'},
                },
              ],
            }),
            200,
          ));

      final result = await http.runWithClient(() => _chat(OpenAiClient()), () => mock);

      expect(result.usage, isNull);
    });

    test('Anthropic usage keeps cache reads and writes apart', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'model': 'claude-3-5-haiku-20241022',
              'content': [
                {'type': 'text', 'text': 'Hi'},
              ],
              'usage': {
                'input_tokens': 12,
                'output_tokens': 7,
                'cache_read_input_tokens': 3,
                'cache_creation_input_tokens': 4,
              },
            }),
            200,
          ));

      final result = await http.runWithClient(() => _chat(AnthropicClient()), () => mock);

      final usage = result.usage!;
      expect(usage.model, 'claude-3-5-haiku-20241022');
      expect(usage.inputTokens, 12);
      expect(usage.outputTokens, 7);
      expect(usage.cacheReadTokens, 3);
      expect(usage.cacheWriteTokens, 4);
    });
  });

  group('luma pricing', () {
    test('every provider the Assistant can use is priced', () {
      for (final model in [
        'anthropic/claude-3-5-haiku-20241022',
        'openai/gpt-4o-mini',
        'mistral/mistral-small-latest',
        'google/gemini-flash-lite-latest',
        'google/gemini-flash-latest',
      ]) {
        expect(isBillableModel(AiUsageSource.luma, model), isTrue, reason: model);
      }
    });

    test('gpt-4o-mini prices at its own rate, not the flagship fallback', () {
      expect(pricingFor(AiUsageSource.luma, 'openai/gpt-4o-mini-2024-07-18')!.input, 0.15);
    });

    test('Gemini slugs map onto the Gemini table', () {
      expect(geminiDisplayNameForSlug('gemini-3.5-flash-lite'), 'Gemini 3.5 Flash-Lite');
      expect(geminiDisplayNameForSlug('models/gemini-3.1-pro-preview'), 'Gemini 3.1 Pro');
      expect(geminiDisplayNameForSlug('gemini-flash-latest'), 'Gemini 3.5 Flash');
      expect(geminiDisplayNameForSlug('gpt-4o'), isNull);
    });

    test('an unknown Mistral model prices as Mistral Small', () {
      expect(mistralPricingFor('some-agent-model'), kMistralPricing['mistral-small']);
      expect(mistralPricingFor('magistral-small-2509'), kMistralPricing['magistral-small']);
    });

    test('a model with no provider prefix is not billable', () {
      expect(isBillableModel(AiUsageSource.luma, 'gpt-4o-mini'), isFalse);
    });

    test('display names and companies follow the provider', () {
      expect(displayName(AiUsageSource.luma, 'openai/gpt-4o-mini'), 'Luma · GPT 4o mini');
      expect(displayName(AiUsageSource.luma, 'anthropic/claude-3-5-haiku-20241022'),
          'Luma · Haiku 3.5');
      expect(companyForModel(AiUsageSource.luma, 'google/gemini-flash-latest'), 'Google');
      expect(companyForModel(AiUsageSource.luma, 'mistral/mistral-small-latest'), 'Mistral');
    });
  });

  group('recordLumaCall', () {
    late AiUsageDatabase db;
    late AiUsageRepository repo;

    setUp(() {
      db = AiUsageDatabase(NativeDatabase.memory());
      repo = AiUsageRepository(db);
    });

    tearDown(() => db.close());

    test('stores a priced, dated turn and opens the page', () async {
      expect(repo.anyDirFound, isNull);
      final at = DateTime.utc(2026, 9, 23, 12);

      await repo.recordLumaCall(
        providerId: 'openai',
        usage: const AiTokenUsage(
          model: 'gpt-4o-mini',
          inputTokens: 1000000,
          outputTokens: 1000000,
        ),
        feature: 'Assistant',
        sessionId: 'luma:chat:7',
        at: at,
      );

      final rows = await db.select(db.aiUsageTurns).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.source, AiUsageSource.luma);
      expect(row.model, 'openai/gpt-4o-mini');
      expect(row.timestamp.toUtc(), at);
      expect(row.project, 'Assistant');
      expect(row.sessionId, 'luma:chat:7');
      expect(row.deviceId, isNull);
      expect(costForRow(row), closeTo(0.75, 1e-9));
      expect(repo.anyDirFound, isTrue);
    });

    test("strips Gemini's models/ prefix", () async {
      await repo.recordLumaCall(
        providerId: 'google',
        usage: const AiTokenUsage(model: 'models/gemini-flash-latest', inputTokens: 5),
        feature: 'Mind Map',
      );

      final row = (await db.select(db.aiUsageTurns).get()).single;
      expect(row.model, 'google/gemini-flash-latest');
      expect(row.sessionId, 'luma:Mind Map');
    });
  });
}

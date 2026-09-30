import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/chat_usage.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/providers/luma_image_client.dart';

/// Answers the lead with [questions], each agent with "notes on <q>", and
/// the final write-up with every note it was given. Records how many calls
/// were in flight at once.
class _FakeResearchClient extends AiClient {
  _FakeResearchClient(this.questions);

  final String questions;
  final calls = <List<AiTurn>>[];
  final systemPrompts = <String>[];
  int inFlight = 0;
  int maxInFlight = 0;

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
    calls.add(history);
    systemPrompts.add(systemPrompt);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    final last = history.last.text;
    final String text;
    if (last.contains('<research_notes>')) {
      text = 'FINAL ${last.substring(last.indexOf('<research_notes>'))}';
      onText?.call(text);
    } else if (last.contains('Your sub-question:')) {
      text = 'notes on ${last.split('Your sub-question: ').last}';
    } else {
      text = questions;
    }
    return AiChatResult(
      text: text,
      usage: const AiTokenUsage(model: 'm', inputTokens: 10, outputTokens: 5),
    );
  }
}

void main() {
  group('parseResearchQuestions', () {
    test('reads a JSON array, even wrapped in prose', () {
      expect(
        parseResearchQuestions(
          'Sure:\n["a?", "b?", "a?", "c?"]\nDone',
          max: 3,
          fallback: 'q',
        ),
        ['a?', 'b?', 'c?'],
      );
    });

    test('falls back to numbered or bulleted lines', () {
      expect(
        parseResearchQuestions(
          '1. first\n2) second\n- third',
          max: 5,
          fallback: 'q',
        ),
        ['first', 'second', 'third'],
      );
    });

    test('uses the question itself when nothing parses', () {
      expect(parseResearchQuestions('hmm', max: 3, fallback: 'q'), ['q']);
    });
  });

  test('deep research runs only on Nebula, Pulsar and Luma Assistant', () {
    expect(deepResearchAvailable('google', 'smarter'), isTrue);
    expect(deepResearchAvailable('google', 'smartest'), isTrue);
    expect(deepResearchAvailable('google', 'normal'), isFalse);
    expect(deepResearchAvailable('local', 'normal'), isTrue);
    expect(deepResearchAvailable('anthropic', 'smarter'), isFalse);
    expect(deepResearchRunsInParallel('google'), isTrue);
    expect(deepResearchRunsInParallel('local'), isFalse);
  });

  test('compose modes are Nova only', () {
    expect(composeModesUnlocked('nova'), isTrue);
    expect(composeModesUnlocked('orbit'), isFalse);
    expect(composeModesUnlocked('core'), isFalse);
  });

  Future<(AiChatResult, _FakeResearchClient, List<AssistantActivity>)>
  research({required bool parallel}) async {
    final client = _FakeResearchClient('["one?", "two?", "three?"]');
    final activity = <AssistantActivity>[];
    final result = await DeepResearch(
      client: client,
      apiKey: 'k',
      parallel: parallel,
      systemPrompt: 'base',
      onActivity: activity.add,
    ).run(const [
      AiTurn(role: 'user', text: 'earlier'),
      AiTurn(role: 'assistant', text: 'reply'),
      AiTurn(role: 'user', text: 'big question'),
    ]);
    return (result, client, activity);
  }

  test('parallel research runs the agents at once and writes up all notes',
      () async {
    final (result, client, activity) = await research(parallel: true);
    expect(client.calls, hasLength(5));
    expect(client.maxInFlight, 3);
    for (final q in ['one?', 'two?', 'three?']) {
      expect(result.text, contains('notes on $q'));
    }
    expect(result.usage!.requests, 5);
    expect(result.usage!.inputTokens, 50);
    expect(client.calls.last.first.text, 'earlier');
    expect(client.systemPrompts.every((p) => p.startsWith('base')), isTrue);
    expect(activity.first.questions, isEmpty);
    expect(activity.last.writing, isTrue);
    expect(activity.last.done, {0, 1, 2});
  });

  test('on-device research runs the agents one after another', () async {
    final (result, client, _) = await research(parallel: false);
    expect(client.maxInFlight, 1);
    expect(result.text, contains('notes on three?'));
  });

  test('compose mode and picture path round-trip through metadata', () {
    final withUsage = chatMetadataWithUsage(
      null,
      const AiTokenUsage(model: 'm', inputTokens: 1, outputTokens: 2),
    );
    final tagged = chatMetadataWithComposeMode(
      withUsage,
      AssistantComposeMode.deepResearch,
    );
    expect(chatComposeModeOf(tagged), AssistantComposeMode.deepResearch);
    expect(jsonDecode(tagged!)['usage'], isNotNull);
    expect(
      chatMetadataWithComposeMode(withUsage, AssistantComposeMode.chat),
      withUsage,
    );
    expect(chatImagePathOf(jsonEncode({'imagePath': '/a.png'})), '/a.png');
    expect(chatImagePathOf(null), isNull);
    expect(chatComposeModeOf('not json'), isNull);
  });

  group('LumaImageClient', () {
    test('decodes the picture and sends the prompt and mode', () async {
      late Map<String, dynamic> sent;
      final client = LumaImageClient(
        serverUrl: 'https://luma.example/',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/ai/image');
          expect(request.headers['Authorization'], 'Bearer tok');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'image': base64Encode([1, 2, 3]),
              'mimeType': 'image/jpeg',
              'text': 'A cat',
            }),
            200,
          );
        }),
      );
      final image = await client.generate(
        authToken: 'tok',
        prompt: 'a cat',
        mode: 'smarter',
      );
      expect(sent, {'prompt': 'a cat', 'mode': 'smarter'});
      expect(image.bytes, [1, 2, 3]);
      expect(image.extension, 'jpg');
      expect(image.text, 'A cat');
    });

    test('surfaces the server usage-limit message', () async {
      final client = LumaImageClient(
        serverUrl: 'https://luma.example',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'usage_limit', 'message': 'No room left'}),
            429,
          ),
        ),
      );
      expect(
        client.generate(authToken: 't', prompt: 'p', mode: 'normal'),
        throwsA(
          isA<AiRateLimitError>().having(
            (e) => e.message,
            'message',
            'No room left',
          ),
        ),
      );
    });
  });
}

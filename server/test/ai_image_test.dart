import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_image.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:test/test.dart';

void main() {
  test('picture costs a flat weekly share on Orbit and Nova only', () {
    expect(aiImageWeeklyPercentForPlan('orbit'), 7);
    expect(aiImageWeeklyPercentForPlan('nova'), 3);
    expect(aiImageWeeklyPercentForPlan('core'), isNull);
    expect(aiImageWeeklyPercentForPlan(null), isNull);
  });

  test('google requests go to the images endpoint as b64', () {
    const route = AiModeRoute(AiUpstream.google, 'imagen-4.0-generate-001');
    expect(aiImageEndpoint(route.upstream).path, endsWith('/images/generations'));
    final body = aiImageRequestBody(route, 'a cat');
    expect(body['prompt'], 'a cat');
    expect(body['response_format'], 'b64_json');
  });

  test('openrouter requests ask chat completions for an image', () {
    const route =
        AiModeRoute(AiUpstream.openrouter, 'google/gemini-2.5-flash-image');
    expect(aiImageEndpoint(route.upstream).toString(),
        AiUpstream.openrouter.endpoint);
    final body = aiImageRequestBody(route, 'a cat');
    expect(body['modalities'], ['image', 'text']);
    expect((body['messages'] as List).single['content'], 'a cat');
  });

  test('parses the images endpoint shape', () {
    final result = parseAiImageResponse(jsonEncode({
      'data': [
        {'b64_json': '/9j/AAAA'}
      ]
    }));
    expect(result!.base64, '/9j/AAAA');
    expect(result.mimeType, 'image/jpeg');
  });

  test('parses the openrouter data URL shape with its caption', () {
    final result = parseAiImageResponse(jsonEncode({
      'choices': [
        {
          'message': {
            'content': 'Here you go',
            'images': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,iVBORw0K'}
              }
            ],
          }
        }
      ]
    }));
    expect(result!.base64, 'iVBORw0K');
    expect(result.mimeType, 'image/png');
    expect(result.text, 'Here you go');
  });

  test('a reply without a picture parses to null', () {
    expect(
        parseAiImageResponse(jsonEncode({
          'choices': [
            {
              'message': {'content': 'I cannot draw that'}
            }
          ]
        })),
        isNull);
    expect(parseAiImageResponse('not json'), isNull);
  });

  test('store falls back to a configured upstream and persists a pick',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai_image_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = AiImageConfigStore(dir.path);
    expect(store.resolve({}), isNull);
    expect(store.resolve({AiUpstream.mistral}), isNull);
    expect(store.resolve({AiUpstream.openrouter})!.model,
        kDefaultAiImageModels[AiUpstream.openrouter]);

    await store.save(const AiModeRoute(AiUpstream.google, 'my-imagen'));
    final reopened = AiImageConfigStore(dir.path);
    expect(reopened.resolve({AiUpstream.google})!.model, 'my-imagen');
    expect(reopened.resolve({AiUpstream.openrouter})!.upstream,
        AiUpstream.openrouter);
  });
}

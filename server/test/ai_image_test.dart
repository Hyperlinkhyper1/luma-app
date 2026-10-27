import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_image.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:test/test.dart';

void main() {
  test('picture costs a flat weekly share on every plan', () {
    expect(aiImageWeeklyPercentForPlan('orbit'), 7);
    expect(aiImageWeeklyPercentForPlan('nova'), 3);
    expect(aiImageWeeklyPercentForPlan('core'), 10);
    expect(aiImageWeeklyPercentForPlan(null), 10);
  });

  test('the pro picture model costs more than the standard one', () {
    for (final plan in ['core', 'orbit', 'nova']) {
      expect(
          aiImageWeeklyPercentForPlan(plan, selector: kAiImageProSelector),
          greaterThan(aiImageWeeklyPercentForPlan(plan)));
    }
    expect(aiImageSelectorForTier('pro'), kAiImageProSelector);
    expect(aiImageSelectorForTier('standard'), kAiImageSelector);
    expect(aiImageSelectorForTier(null), kAiImageSelector);
  });

  test('google requests go to the images endpoint as b64', () {
    const route = AiModeRoute(AiUpstream.google, 'imagen-4.0-generate-001');
    expect(aiImageEndpoint(route.upstream).path, endsWith('/images/generations'));
    final body = aiImageRequestBody(route, 'a cat');
    expect(body['prompt'], 'a cat');
    expect(body['response_format'], 'b64_json');
  });

  test('openrouter requests go to its unified images endpoint', () {
    const route = AiModeRoute(
        AiUpstream.openrouter, 'inclusionai/ming-image-0.1-design');
    expect(aiImageEndpoint(route.upstream).toString(),
        'https://openrouter.ai/api/v1/images');
    final body = aiImageRequestBody(route, 'a cat');
    expect(body['model'], route.model);
    expect(body['prompt'], 'a cat');
    expect(body.containsKey('messages'), isFalse);
  });

  test('parses the openrouter images shape with its media type', () {
    final result = parseAiImageResponse(jsonEncode({
      'data': [
        {'b64_json': 'UklGRAAA', 'media_type': 'image/webp'}
      ],
      'usage': {'cost': 0.01},
    }));
    expect(result!.base64, 'UklGRAAA');
    expect(result.mimeType, 'image/webp');
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

  test('the pro model is stored apart from the standard one', () async {
    final dir = await Directory.systemTemp.createTemp('ai_image_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = AiImageConfigStore(dir.path);
    expect(store.resolve({AiUpstream.openrouter}, kAiImageProSelector)!.model,
        kDefaultAiImageProModels[AiUpstream.openrouter]);

    await store.save(const AiModeRoute(AiUpstream.google, 'my-imagen'));
    await store.save(const AiModeRoute(AiUpstream.openrouter, 'my-pro'),
        kAiImageProSelector);
    final reopened = AiImageConfigStore(dir.path);
    expect(reopened.stored()!.model, 'my-imagen');
    expect(reopened.stored(kAiImageProSelector)!.model, 'my-pro');

    await reopened.save(null, kAiImageProSelector);
    final cleared = AiImageConfigStore(dir.path);
    expect(cleared.stored(kAiImageProSelector), isNull);
    expect(cleared.stored()!.model, 'my-imagen');
  });
}

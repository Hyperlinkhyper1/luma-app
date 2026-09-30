import 'dart:io';

import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_model_sources.dart';
import 'package:luma_sync_server/ai_price_guard.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('luma_ai_guard'));
  tearDown(() => dir.deleteSync(recursive: true));

  const route = AiModeRoute(AiUpstream.openrouter, 'z-ai/glm-5.3-flash');

  test('price refresh recognizes a new vendor without a leaderboard row',
      () async {
    final catalog = await AiModelCatalogStore.open(dir.path);
    const ling =
        AiModeRoute(AiUpstream.openrouter, 'inclusionai/ling-3.0-flash-vl');
    final model = parseOpenRouterModel({
      'id': ling.model,
      'pricing': {'prompt': '0.000000021', 'completion': '0.0000000616'},
    }, nowMs: 1)!;
    await catalog.updatePrices([model]);
    expect(priceFor(catalog, ling)?.input, closeTo(0.021, 1e-9));
    expect(priceFor(catalog, ling)?.output, closeTo(0.0616, 1e-9));
    expect(catalog.byId(ling.model), isNull);
    final reopened = await AiModelCatalogStore.open(dir.path);
    expect(priceFor(reopened, ling)?.input, closeTo(0.021, 1e-9));
    final guard = AiPriceGuardStore(dir.path);
    await guard.evaluate('smartest', ling, priceFor(reopened, ling));
    await reopened.updatePrices([
      model.mergedWith(AiModel(
        id: ling.model,
        slug: model.slug,
        name: model.name,
        vendor: model.vendor,
        vendorName: model.vendorName,
        updatedAtMs: 2,
        inputPricePerM: 0.1,
        outputPricePerM: 0.2,
      ))
    ]);
    expect(await guard.evaluate('smartest', ling, priceFor(reopened, ling)),
        isTrue);
    expect(reopened.toJson(), isNot(contains('routingModels')));
    await reopened.updatePrices([]);
    expect(priceFor(reopened, ling)?.input, 0.1);
  });

  test('routing variants keep their own price and survive a restart', () async {
    final catalog = await AiModelCatalogStore.open(dir.path);
    const free = AiModeRoute(AiUpstream.openrouter, 'other/model:free');
    final model = parseOpenRouterModel({
      'id': free.model,
      'pricing': {'prompt': '0', 'completion': '0'},
    }, nowMs: 1, forRouting: true)!;
    await catalog.updatePrices([model]);
    expect(priceFor(catalog, free)?.input, 0);
    final reopened = await AiModelCatalogStore.open(dir.path);
    expect(reopened.routingModels.single.id, free.model);
    expect(priceFor(reopened, free)?.output, 0);
    expect(parseOpenRouterModel({'id': free.model}, nowMs: 1), isNull);
  });

  group('openrouter provider discounts', () {
    const deepInfra = AiEndpointPrice('DeepInfra', 0.075, 0.25, discount: 0.5);
    const fireworks = AiEndpointPrice('Fireworks', 0.15, 0.5);

    test('parses endpoint prices from the endpoints API', () {
      final parsed = parseOpenRouterEndpoints({
        'data': {
          'endpoints': [
            {
              'provider_name': 'DeepInfra',
              'status': 0,
              'pricing': {
                'prompt': '0.000000075',
                'completion': '0.00000025',
                'discount': 0.5
              },
            },
            {
              'provider_name': 'Down',
              'status': -2,
              'pricing': {'prompt': '0.00000001', 'completion': '0.00000001'},
            },
          ]
        }
      });
      expect(parsed.first.input, closeTo(0.075, 1e-9));
      expect(parsed.first.discount, 0.5);
      expect(parsed.last.up, isFalse);
      expect(cheapestEndpoint(parsed)!.provider, 'DeepInfra');
    });

    test('the discount ending pauses the mode though the list price stays',
        () async {
      final guard = AiPriceGuardStore(dir.path);
      expect(await guard.recordPaid('smartest', route, 'DeepInfra',
              const AiPrice(0.075, 0.25)),
          isFalse);
      expect(guard.maxPrice('smartest', route)!.input, 0.075);
      expect(
          await guard.evaluateEndpoints('smartest', route, [deepInfra, fireworks]),
          isFalse);
      const ended = AiEndpointPrice('DeepInfra', 0.15, 0.5);
      expect(await guard.evaluateEndpoints('smartest', route, [ended, fireworks]),
          isTrue);
      expect(AiPriceGuardStore(dir.path).isDisabled('smartest'), isTrue);
    });

    test('being served by a pricier provider pauses the mode', () async {
      final guard = AiPriceGuardStore(dir.path);
      await guard.recordPaid(
          'smartest', route, 'DeepInfra', const AiPrice(0.075, 0.25));
      expect(await guard.recordPaid(
              'smartest', route, 'Fireworks', const AiPrice(0.15, 0.5)),
          isTrue);
    });

    test('an old list-price baseline is dropped for the endpoint one',
        () async {
      final guard = AiPriceGuardStore(dir.path);
      await guard.evaluate('smartest', route, const AiPrice(0.15, 0.5));
      await guard.evaluateEndpoints('smartest', route, [deepInfra, fireworks]);
      expect(guard.entry('smartest').baseline, isNull);
      expect(guard.maxPrice('smartest', route), isNull);
      await guard.setAutoDisable('smartest', false);
      await guard.recordPaid(
          'smartest', route, 'DeepInfra', const AiPrice(0.075, 0.25));
      expect(guard.maxPrice('smartest', route), isNull,
          reason: 'no price cap is sent while the guard is off');
    });
  });

  test('the detector and picture selectors are guarded and persisted',
      () async {
    const picture =
        AiModeRoute(AiUpstream.openrouter, 'google/gemini-2.5-flash-image');
    final guard = AiPriceGuardStore(dir.path);
    await guard.recordPaid(
        'picture', picture, 'Google', const AiPrice(0.3, 2.5));
    await guard.recordPaid('detector', route, 'DeepInfra',
        const AiPrice(0.075, 0.25));
    expect(
        await guard.evaluateEndpoints('picture', picture,
            [const AiEndpointPrice('Google', 0.3, 30)]),
        isTrue);
    final reopened = AiPriceGuardStore(dir.path);
    expect(reopened.isDisabled('picture'), isTrue);
    expect(reopened.maxPrice('detector', route)!.input, 0.075);
    expect(kAiGuardedSelectors, containsAll(['detector', 'picture']));
  });

  test('a picture model pauses when only its image price rises', () async {
    const picture =
        AiModeRoute(AiUpstream.openrouter, 'google/gemini-2.5-flash-image');
    final guard = AiPriceGuardStore(dir.path);
    const before = AiEndpointPrice('Google', 0.3, 2.5, imageOutput: 30);
    await guard.recordPaid('picture', picture, 'Google', AiPrice.ofEndpoint(before));
    expect(await guard.evaluateEndpoints('picture', picture, [before]), isFalse);
    const after = AiEndpointPrice('Google', 0.3, 2.5, imageOutput: 45);
    expect(await guard.evaluateEndpoints('picture', picture, [after]), isTrue);
    expect(AiPriceGuardStore(dir.path).entry('picture').baseline!.image, 30);
  });

  test('first sighting sets the baseline and does not disable', () async {
    final guard = AiPriceGuardStore(dir.path);
    expect(await guard.evaluate('smartest', route, const AiPrice(0.1, 0.3)),
        isFalse);
    expect(guard.entry('smartest').baseline!.input, 0.1);
  });

  test('a rise disables until accepted, and survives a restart', () async {
    final guard = AiPriceGuardStore(dir.path);
    await guard.evaluate('smartest', route, const AiPrice(0.1, 0.3));
    expect(await guard.evaluate('smartest', route, const AiPrice(0.1, 0.5)),
        isTrue);
    expect(await guard.evaluate('smartest', route, const AiPrice(0.1, 0.3)),
        isTrue,
        reason: 'a price drop must not re-enable on its own');
    expect(AiPriceGuardStore(dir.path).isDisabled('smartest'), isTrue);

    await guard.accept('smartest', route, const AiPrice(0.1, 0.5));
    expect(guard.isDisabled('smartest'), isFalse);
    expect(await guard.evaluate('smartest', route, const AiPrice(0.1, 0.5)),
        isFalse);
  });

  test('a lower price and an off guard never disable', () async {
    final guard = AiPriceGuardStore(dir.path);
    await guard.evaluate('normal', route, const AiPrice(0.1, 0.3));
    expect(await guard.evaluate('normal', route, const AiPrice(0.05, 0.2)),
        isFalse);
    await guard.setAutoDisable('normal', false);
    expect(await guard.evaluate('normal', route, const AiPrice(9, 9)), isFalse);
  });

  test('picking another model starts a fresh baseline', () async {
    final guard = AiPriceGuardStore(dir.path);
    await guard.evaluate('normal', route, const AiPrice(0.1, 0.3));
    await guard.evaluate('normal', route, const AiPrice(1, 1));
    expect(guard.isDisabled('normal'), isTrue);
    const other = AiModeRoute(AiUpstream.openrouter, 'other/model');
    expect(await guard.evaluate('normal', other, const AiPrice(2, 2)), isFalse);
  });
}

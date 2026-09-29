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

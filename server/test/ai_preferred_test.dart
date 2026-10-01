import 'dart:io';

import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/ai_preferred.dart';
import 'package:luma_sync_server/ai_price_guard.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('luma_ai_preferred'));
  tearDown(() => dir.deleteSync(recursive: true));

  const main = AiModeRoute(AiUpstream.google, 'gemini-flash-latest');
  const preferred = AiModeRoute(AiUpstream.openrouter, 'z-ai/glm-5.3-flash');

  test('the preferred model goes first, then the main one', () {
    final order = aiRouteCandidates('smarter',
        preferred: preferred,
        preferredPaused: false,
        main: main,
        mainPaused: false);
    expect(order.map((c) => c.key), ['smarter.preferred', 'smarter']);
    expect(order.first.route, preferred);
  });

  test('a paused or unset preferred model leaves only the main one', () {
    for (final (route, paused) in [(preferred, true), (null, false)]) {
      final order = aiRouteCandidates('normal',
          preferred: route,
          preferredPaused: paused,
          main: main,
          mainPaused: false);
      expect(order.single.key, 'normal');
    }
  });

  test('a paused main model still lets the preferred one answer', () {
    final order = aiRouteCandidates('picture',
        preferred: preferred,
        preferredPaused: false,
        main: main,
        mainPaused: true);
    expect(order.single.key, 'picture.preferred');
    expect(
        aiRouteCandidates('picture',
            preferred: preferred,
            preferredPaused: true,
            main: main,
            mainPaused: true),
        isEmpty);
  });

  test('a preferred model identical to the main one is tried once', () {
    final order = aiRouteCandidates('detector',
        preferred: main,
        preferredPaused: false,
        main: main,
        mainPaused: false);
    expect(order.single.key, 'detector.preferred');
  });

  test('picks survive a restart and need a key to resolve', () async {
    final store = AiPreferredStore(dir.path);
    await store.save('smartest', preferred);
    await store.save('picture',
        const AiModeRoute(AiUpstream.openrouter, 'black-forest-labs/flux'));
    final reopened = AiPreferredStore(dir.path);
    expect(reopened.stored('smartest')?.model, preferred.model);
    expect(reopened.resolve('smartest', {AiUpstream.google}), isNull);
    expect(reopened.resolve('smartest', {AiUpstream.openrouter})?.model,
        preferred.model);
    await reopened.save('smartest', null);
    expect(AiPreferredStore(dir.path).stored('smartest'), isNull);
    expect(AiPreferredStore(dir.path).stored('picture'), isNotNull);
  });

  test('a picture pick on a provider that cannot draw is dropped', () async {
    File('${dir.path}/ai_preferred_models.json').writeAsStringSync(
        '{"picture":{"upstream":"mistral","model":"mistral-small-latest"}}');
    expect(AiPreferredStore(dir.path).stored('picture'), isNull);
  });

  test('preferred models have their own price guard entry', () async {
    expect(kAiGuardedSelectors,
        containsAll(['normal.preferred', 'detector.preferred', 'picture']));
    final guard = AiPriceGuardStore(dir.path);
    await guard.evaluate(
        'normal.preferred', preferred, const AiPrice(0.1, 0.2));
    expect(
        await guard.evaluate(
            'normal.preferred', preferred, const AiPrice(0.2, 0.2)),
        isTrue);
    expect(guard.isDisabled('normal'), isFalse);
    expect(AiPriceGuardStore(dir.path).isDisabled('normal.preferred'), isTrue);
  });
}

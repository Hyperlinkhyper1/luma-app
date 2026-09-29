import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('luma_ai_routes'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('defaults follow whichever upstream has a key', () {
    final routes = AiModeRoutingStore(dir.path);
    expect(routes.resolve('normal', {}), isNull);
    expect(routes.resolve('smarter', {AiUpstream.google})!.model,
        'gemini-flash-latest');
    final viaOpenRouter = routes.resolve('smarter', {AiUpstream.openrouter})!;
    expect(viaOpenRouter.upstream, AiUpstream.openrouter);
    expect(viaOpenRouter.model, 'google/gemini-2.5-flash');
  });

  test('saved choices persist and fall back when their key is gone', () async {
    await AiModeRoutingStore(dir.path).save({
      'smartest': const AiModeRoute(
          AiUpstream.openrouter, 'anthropic/claude-sonnet-5',
          reasoningEffort: 'medium'),
    });
    final reloaded = AiModeRoutingStore(dir.path);
    final both = {AiUpstream.google, AiUpstream.openrouter};
    final pulsar = reloaded.resolve('smartest', both)!;
    expect(pulsar.model, 'anthropic/claude-sonnet-5');
    expect(pulsar.reasoningEffort, 'medium');
    expect(reloaded.resolve('normal', both)!.upstream, AiUpstream.google);

    final googleOnly = reloaded.resolve('smartest', {AiUpstream.google})!;
    expect(googleOnly.upstream, AiUpstream.google);
    expect(googleOnly.model, 'gemini-flash-latest');
  });

  test('unknown modes resolve like Aurora', () {
    final routes = AiModeRoutingStore(dir.path);
    expect(routes.resolve('bogus', {AiUpstream.google})!.model,
        'gemini-flash-lite-latest');
  });

  test('mistral is a usable upstream for the modes too', () {
    final routes = AiModeRoutingStore(dir.path);
    final route = routes.resolve('normal', {AiUpstream.mistral})!;
    expect(route.upstream, AiUpstream.mistral);
    expect(route.model, 'mistral-small-latest');
  });

  test('model ids are validated', () {
    expect(isValidAiModelId('openai/gpt-5.1:free'), isTrue);
    expect(isValidAiModelId('bad id'), isFalse);
    expect(isValidAiModelId('<script>'), isFalse);
  });

  test('only changed modes advance and unchanged saves keep versions',
      () async {
    final store = AiModeRoutingStore(dir.path);
    expect(store.displayName('normal'), 'Aurora 1.0');
    const aurora = AiModeRoute(AiUpstream.google, 'model-a');
    const nebula = AiModeRoute(AiUpstream.google, 'model-b');
    await store.save({'normal': aurora, 'smarter': nebula});
    expect(
        store.versions, {'normal': '1.1', 'smarter': '1.1', 'smartest': '1.0'});
    await store.save({'normal': aurora, 'smarter': nebula});
    expect(store.version('normal'), '1.1');
    await store.save({
      'normal': const AiModeRoute(AiUpstream.openrouter, 'model-c',
          reasoningEffort: 'high'),
      'smarter': nebula,
    });
    expect(store.version('normal'), '1.2');
    expect(store.version('smarter'), '1.1');
    await store.save({
      'normal': const AiModeRoute(AiUpstream.openrouter, 'model-c',
          reasoningEffort: 'medium'),
      'smarter': nebula,
    });
    expect(store.version('normal'), '1.3');
    await store.save({'smarter': nebula});
    expect(store.version('normal'), '1.4');
    expect(store.stored('normal'), isNull);
    final reloaded = AiModeRoutingStore(dir.path);
    expect(reloaded.version('normal'), '1.4');
    await reloaded.save({'smarter': nebula});
    expect(reloaded.version('normal'), '1.4');
  });

  test('versions roll over and survive restarts', () async {
    var store = AiModeRoutingStore(dir.path);
    for (var revision = 1; revision <= 11; revision++) {
      await store.save({
        'normal': AiModeRoute(AiUpstream.google, 'model-$revision'),
      });
      store = AiModeRoutingStore(dir.path);
      if (revision == 9) expect(store.displayName('normal'), 'Aurora 1.9');
      if (revision == 10) expect(store.displayName('normal'), 'Aurora 2.0');
    }
    expect(store.displayName('normal'), 'Aurora 2.1');
    expect(store.displayName('smartest'), 'Pulsar 1.0');
  });

  test('legacy routes start at 1.0 without losing the saved model', () async {
    const route = AiModeRoute(AiUpstream.mistral, 'mistral-small-latest');
    File('${dir.path}/ai_mode_routes.json')
        .writeAsStringSync(jsonEncode({'normal': route.toJson()}));
    final store = AiModeRoutingStore(dir.path);
    expect(store.version('normal'), '1.0');
    expect(store.stored('normal')!.model, route.model);
    await store.save({'normal': route});
    expect(AiModeRoutingStore(dir.path).version('normal'), '1.0');
  });

  test('concurrent saves preserve every version increment', () async {
    final store = AiModeRoutingStore(dir.path);
    await Future.wait([
      store.save({'normal': const AiModeRoute(AiUpstream.google, 'model-a')}),
      store.save({'normal': const AiModeRoute(AiUpstream.google, 'model-b')}),
    ]);
    final reloaded = AiModeRoutingStore(dir.path);
    expect(reloaded.version('normal'), '1.2');
    expect(reloaded.stored('normal')!.model, 'model-b');
  });
}

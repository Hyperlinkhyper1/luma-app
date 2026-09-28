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

  test('model ids are validated', () {
    expect(isValidAiModelId('openai/gpt-5.1:free'), isTrue);
    expect(isValidAiModelId('bad id'), isFalse);
    expect(isValidAiModelId('<script>'), isFalse);
  });
}

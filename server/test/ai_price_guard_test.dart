import 'dart:io';

import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/ai_price_guard.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('luma_ai_guard'));
  tearDown(() => dir.deleteSync(recursive: true));

  const route = AiModeRoute(AiUpstream.openrouter, 'z-ai/glm-5.3-flash');

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
        isTrue, reason: 'a price drop must not re-enable on its own');
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

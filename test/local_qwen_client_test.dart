import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/providers/local_qwen_client.dart';

void main() {
  group('LocalQwenClient.stripThinking', () {
    test('drops the empty think block Qwen3.5 opens replies with', () {
      expect(
        LocalQwenClient.stripThinking('<think>\n\n</think>\n\nHello there!'),
        'Hello there!',
      );
    });

    test('drops reasoning inside a closed think block', () {
      expect(
        LocalQwenClient.stripThinking(
          '<think>The user wants a greeting.</think> Hi!',
        ),
        'Hi!',
      );
    });

    test('drops an unclosed think block cut off by the output budget', () {
      expect(
        LocalQwenClient.stripThinking('<think>Let me consider this at len'),
        '',
      );
    });

    test('leaves a plain reply untouched', () {
      expect(LocalQwenClient.stripThinking('  Plain reply. '), 'Plain reply.');
    });
  });
}

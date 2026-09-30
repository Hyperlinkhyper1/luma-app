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

  group('LocalQwenClient.performanceCoreCount', () {
    test('leaves out the efficiency cores of a 6 + 2 Snapdragon 695', () {
      expect(
        LocalQwenClient.performanceCoreCount([
          440, 440, 440, 440, 440, 440, 1024, 1024,
        ]),
        2,
      );
    });

    test('keeps prime and big cores on a 4 + 3 + 1 layout', () {
      expect(
        LocalQwenClient.performanceCoreCount([
          1804800, 1804800, 1804800, 1804800, 2419200, 2419200, 2419200,
          2841600,
        ]),
        4,
      );
    });

    test('uses every core when they are all alike, up to eight', () {
      expect(LocalQwenClient.performanceCoreCount([1000, 1000, 1000, 1000]), 4);
      expect(LocalQwenClient.performanceCoreCount(List.filled(12, 1000)), 8);
    });

    test('has no answer when the kernel lists no cores', () {
      expect(LocalQwenClient.performanceCoreCount([]), isNull);
    });
  });
}

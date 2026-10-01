import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/mail_store.dart';

void main() {
  test('mail state round-trips', () {
    const state = MailState(open: 600, letters: [12, 30], hand: 17, vault: 240);
    final back = MailState.fromJson(state.toJson());
    expect(back.toJson(), state.toJson());
  });

  test('mail state from the page is cleaned up', () {
    final state = MailState.fromJson({
      'open': -5,
      'letters': [20.7, 0, -3, 'x', 15, 11, 12, 13, 14, 16, 17, 18, 19],
      'hand': 'lots',
      'vault': 99.9,
    });
    expect(state.open, 0);
    expect(state.letters, [20, 15, 11, 12, 13, 14]);
    expect(state.hand, 0);
    expect(state.vault, 99);
  });

  test('nothing saved reads as an empty post', () {
    expect(MailState.fromJson(null).toJson(), const MailState().toJson());
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/sync_service.dart';

void main() {
  group('SyncService.accountSetupPromptDismissed', () {
    test('starts false, so a fresh device would see the first-run prompt',
        () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      expect(sync.accountSetupPromptDismissed, isFalse);
    });

    test('dismissAccountSetupPrompt flips the flag and persists without '
        'throwing', () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      expect(sync.accountSetupPromptDismissed, isFalse);

      await sync.dismissAccountSetupPrompt();
      expect(sync.accountSetupPromptDismissed, isTrue);
    });

    test('setting up a local account does not itself dismiss the prompt',
        () async {
      // Completing setup is reported to the caller (via the dialog's return
      // value in the real UI) rather than inferred from state, precisely so
      // "cancelled" and "completed" can't be confused. dismissing is the
      // caller's job when setup was NOT completed.
      final sync = SyncService(collections: const []);
      await sync.init();
      await sync.setLocalAccount(
          email: 'me@example.com', password: 'a-long-local-password');
      expect(sync.accountSetupPromptDismissed, isFalse);
    });

    test('dismissing twice is a harmless no-op', () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      await sync.dismissAccountSetupPrompt();
      await sync.dismissAccountSetupPrompt();
      expect(sync.accountSetupPromptDismissed, isTrue);
    });
  });
}

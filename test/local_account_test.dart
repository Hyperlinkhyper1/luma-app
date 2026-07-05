import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/sync_service.dart';

void main() {
  group('SyncService local (serverless) account', () {
    test('setLocalAccount enables P2P readiness without any server', () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      expect(sync.p2pReady, isFalse);
      expect(sync.peerHandshakeToken(), isNull);

      await sync.setLocalAccount(
          email: 'Alex@Example.com', password: 'correct horse battery');
      expect(sync.p2pReady, isTrue);
      expect(sync.isLocalOnly, isTrue);
      expect(sync.signedIn, isFalse); // no server, no token — not "cloud"
      expect(sync.peerHandshakeToken(), isNotNull);
    });

    test('same email+password on two devices derive the same handshake token',
        () async {
      final deviceA = SyncService(collections: const []);
      final deviceB = SyncService(collections: const []);
      await deviceA.init();
      await deviceB.init();

      await deviceA.setLocalAccount(
          email: 'pair@example.com', password: 'shared-secret-99');
      // Case/whitespace should normalize the same way on both devices.
      await deviceB.setLocalAccount(
          email: '  PAIR@Example.com  ', password: 'shared-secret-99');

      expect(deviceA.peerHandshakeToken(), deviceB.peerHandshakeToken());
    });

    test('a different password derives a different handshake token', () async {
      final deviceA = SyncService(collections: const []);
      final deviceB = SyncService(collections: const []);
      await deviceA.init();
      await deviceB.init();

      await deviceA.setLocalAccount(
          email: 'pair@example.com', password: 'shared-secret-99');
      await deviceB.setLocalAccount(
          email: 'pair@example.com', password: 'different-secret');

      expect(deviceA.peerHandshakeToken(),
          isNot(equals(deviceB.peerHandshakeToken())));
    });

    test('re-entering the wrong password on the same device is rejected',
        () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      await sync.setLocalAccount(
          email: 'me@example.com', password: 'right-password-1');
      final token = sync.peerHandshakeToken();

      await expectLater(
        sync.setLocalAccount(
            email: 'me@example.com', password: 'wrong-password-1'),
        throwsStateError,
      );
      // The existing identity must be untouched by the failed attempt.
      expect(sync.peerHandshakeToken(), token);
    });

    test('clearLocalAccount reverts to no identity, re-derivable later',
        () async {
      final sync = SyncService(collections: const []);
      await sync.init();
      await sync.setLocalAccount(
          email: 'me@example.com', password: 'right-password-1');
      final token = sync.peerHandshakeToken();

      await sync.clearLocalAccount();
      expect(sync.p2pReady, isFalse);
      expect(sync.isLocalOnly, isFalse);
      expect(sync.peerHandshakeToken(), isNull);

      // Re-deriving with the same credentials reproduces the same identity.
      await sync.setLocalAccount(
          email: 'me@example.com', password: 'right-password-1');
      expect(sync.peerHandshakeToken(), token);
    });
  });
}

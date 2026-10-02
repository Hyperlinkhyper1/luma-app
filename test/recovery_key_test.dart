import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/recovery_key.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_crypto.dart';

void main() {
  group('RecoveryKey', () {
    test('formats as eight groups of four and reads back', () {
      for (var i = 0; i < 50; i++) {
        final key = RecoveryKey.generate();
        final text = RecoveryKey.format(key);
        expect(
          text,
          matches(
            RegExp(r'^([0-9A-HJKMNP-TV-Z]{4}-){7}[0-9A-HJKMNP-TV-Z]{4}$'),
          ),
        );
        expect(RecoveryKey.parse(text), key);
      }
    });

    test('forgives case, spacing and look-alike characters', () {
      final key = Uint8List.fromList(List<int>.generate(20, (i) => i * 13));
      final text = RecoveryKey.format(key);
      final sloppy = text
          .toLowerCase()
          .replaceAll('-', ' ')
          .replaceAll('0', 'o')
          .replaceAll('1', 'l');
      expect(RecoveryKey.parse(sloppy), key);
    });

    test('refuses a key that is cut short or has stray characters', () {
      final text = RecoveryKey.format(RecoveryKey.generate());
      expect(RecoveryKey.parse(text.substring(0, text.length - 1)), isNull);
      expect(RecoveryKey.parse('${text.substring(0, 38)}U'), isNull);
      expect(RecoveryKey.parse(''), isNull);
    });

    test('the envelope opens to the encryption key, only with its key', () {
      final recovery = RecoveryKey.generate();
      final encryptionKey = SyncCrypto.randomBytes(32);
      final pair = RecoveryKey.seal(
        recoveryKey: recovery,
        encryptionKey: encryptionKey,
      );

      expect(RecoveryKey.openEnvelope(pair.envelope, recovery), encryptionKey);
      expect(
        () => RecoveryKey.openEnvelope(pair.envelope, RecoveryKey.generate()),
        throwsA(isA<SyncCryptoException>()),
      );
    });

    test('the key box gives the recovery key back to a signed-in device', () {
      final recovery = RecoveryKey.generate();
      final encryptionKey = SyncCrypto.randomBytes(32);
      final pair = RecoveryKey.seal(
        recoveryKey: recovery,
        encryptionKey: encryptionKey,
      );

      expect(RecoveryKey.openKeyBox(pair.keyBox, encryptionKey), recovery);
      expect(
        () => RecoveryKey.openKeyBox(pair.keyBox, SyncCrypto.randomBytes(32)),
        throwsA(isA<SyncCryptoException>()),
      );
    });

    test('envelope and key box are not interchangeable', () {
      final recovery = RecoveryKey.generate();
      final encryptionKey = SyncCrypto.randomBytes(32);
      final pair = RecoveryKey.seal(
        recoveryKey: recovery,
        encryptionKey: encryptionKey,
      );
      expect(
        () => RecoveryKey.openEnvelope(pair.keyBox, recovery),
        throwsA(isA<SyncCryptoException>()),
      );
    });

    test('fits what the server stores', () {
      final pair = RecoveryKey.seal(
        recoveryKey: RecoveryKey.generate(),
        encryptionKey: SyncCrypto.randomBytes(32),
      );
      for (final value in pair.toJson().values) {
        expect(value.length, lessThanOrEqualTo(512));
      }
      expect(pair.envelope.length, inInclusiveRange(32, 256));
      expect(pair.keyBox.length, inInclusiveRange(32, 256));
    });
  });

  test('the recovery envelope is part of the signed-out handshake', () {
    expect(
      ServerAccessGate.accountSetupPaths,
      contains('/api/v1/auth/recovery-envelope'),
    );
  });
}

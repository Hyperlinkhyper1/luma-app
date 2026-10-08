import 'dart:convert';
import 'dart:typed_data';

import '../l10n/current_l.dart';
import 'sync_api.dart';
import 'sync_crypto.dart';

/// The key that lets a forgotten password be reset without losing the
/// synced data.
///
/// Sync is zero-knowledge: the encryption key comes from the password, so a
/// new password alone cannot read anything sealed under the old one. A
/// recovery key is a second, random way to reach that encryption key. The
/// server keeps two sealed blobs it cannot open:
///
/// ```
/// envelope = seal(encryption key, under the recovery key)
/// key box  = seal(recovery key,   under the encryption key)
/// ```
///
/// A reset opens the envelope with the recovery key the user typed, gets the
/// old encryption key back and re-seals every snapshot under the new one. The
/// key box lets a signed-in device re-seal the envelope whenever the password
/// changes, without asking for the recovery key again.
///
/// The key itself is 20 random bytes, shown as eight groups of four
/// Crockford base32 characters — no I, L, O or U, so it survives being
/// written down and read back.
class RecoveryKey {
  RecoveryKey._();

  static const _byteLength = 20;
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// A fresh recovery key, raw.
  static Uint8List generate() => SyncCrypto.randomBytes(_byteLength);

  /// [key] as the user sees it: `XXXX-XXXX-…`, eight groups.
  static String format(Uint8List key) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in key) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    final text = out.toString();
    return [
      for (var i = 0; i < text.length; i += 4)
        text.substring(i, i + 4 > text.length ? text.length : i + 4),
    ].join('-');
  }

  /// Reads back what [format] produced, forgiving case, spaces, dashes and
  /// the look-alikes O/0 and I/L/1. Null when it is not a whole key.
  static Uint8List? parse(String text) {
    final clean = text
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp('[IL]'), '1');
    if (clean.length != _byteLength * 8 ~/ 5) return null;
    final out = BytesBuilder();
    var buffer = 0;
    var bits = 0;
    for (final char in clean.split('')) {
      final value = _alphabet.indexOf(char);
      if (value < 0) return null;
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((buffer >> bits) & 0xff);
      }
    }
    return out.toBytes();
  }

  /// Both sealed blobs for [recoveryKey] and [encryptionKey].
  static RecoveryPair seal({
    required Uint8List recoveryKey,
    required Uint8List encryptionKey,
  }) => RecoveryPair(
    envelope: SyncCrypto.sealRaw(encryptionKey, _wrapKey(recoveryKey)),
    keyBox: SyncCrypto.sealRaw(recoveryKey, _boxKey(encryptionKey)),
  );

  /// The encryption key inside [envelope]. Throws [SyncCryptoException]
  /// when [recoveryKey] is not the one it was sealed with.
  static Uint8List openEnvelope(Uint8List envelope, Uint8List recoveryKey) {
    final key = SyncCrypto.openRaw(envelope, _wrapKey(recoveryKey));
    if (key.length != 32) {
      throw SyncCryptoException(currentL.syncCryptoCorruptedRecoveryEnvelope);
    }
    return key;
  }

  /// The recovery key inside [keyBox]. Throws [SyncCryptoException] when
  /// [encryptionKey] is not the one it was sealed with.
  static Uint8List openKeyBox(Uint8List keyBox, Uint8List encryptionKey) {
    final key = SyncCrypto.openRaw(keyBox, _boxKey(encryptionKey));
    if (key.length != _byteLength) {
      throw SyncCryptoException(currentL.syncCryptoCorruptedRecoveryKeyBox);
    }
    return key;
  }

  static Uint8List _wrapKey(Uint8List recoveryKey) =>
      hkdfExpand(recoveryKey, utf8.encode('luma-sync recovery wrap v1'), 32);

  static Uint8List _boxKey(Uint8List encryptionKey) =>
      hkdfExpand(encryptionKey, utf8.encode('luma-sync recovery box v1'), 32);
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Versioned AES-256-GCM envelopes. The caller supplies a domain-specific key
/// and context identifying the object. Unknown versions fail closed.
class AuthenticatedCipher {
  static final _aes = DartAesGcm.with256bits();
  static const _header = [0x4c, 0x41, 0x01];

  static Uint8List seal(List<int> clear, List<int> key, String context) {
    _validateKey(key);
    final box = _aes.encryptSync(
      clear,
      secretKeyData: SecretKeyData(key),
      nonce: _aes.newNonce(),
      aad: [..._header, ...utf8.encode(context)],
    );
    return Uint8List.fromList([
      ..._header,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  static Uint8List open(List<int> envelope, List<int> key, String context) {
    _validateKey(key);
    if (envelope.length < 31 ||
        envelope[0] != _header[0] ||
        envelope[1] != _header[1] ||
        envelope[2] != _header[2]) {
      throw const FormatException('Unsupported encrypted data.');
    }
    final box = SecretBox(
      envelope.sublist(15, envelope.length - 16),
      nonce: envelope.sublist(3, 15),
      mac: Mac(envelope.sublist(envelope.length - 16)),
    );
    return Uint8List.fromList(
      _aes.decryptSync(
        box,
        secretKeyData: SecretKeyData(key),
        aad: [..._header, ...utf8.encode(context)],
      ),
    );
  }

  static void _validateKey(List<int> key) {
    if (key.length != 32) {
      throw const FormatException('Invalid encryption key length.');
    }
  }
}

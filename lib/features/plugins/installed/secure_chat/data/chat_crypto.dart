import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// End-to-end encryption for the Chat plugin: an anonymous "sealed box"
/// scheme built from well-known primitives (X25519 for key agreement,
/// HKDF-SHA256 to derive a symmetric key, AES-256-GCM to seal the message),
/// all via the `cryptography` package.
///
/// Every user has a long-term X25519 keypair generated on-device; only the
/// public half is ever uploaded to the server (see chat_repository.dart /
/// chat_api.dart). To send a message, the sender generates a fresh, one-time
/// *ephemeral* keypair, derives a shared secret with the recipient's public
/// key, and seals the plaintext under that. The ephemeral public key rides
/// along with the ciphertext (it's meaningless without the recipient's
/// private key), so the server only ever stores/relays opaque bytes it has
/// no way to decrypt.
///
/// Wire format (all concatenated, then base64-encoded):
///   ephemeralPublicKey (32 bytes) | nonce (12 bytes) | ciphertext | mac (16 bytes)
class ChatCrypto {
  ChatCrypto._();

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static const _hkdfInfo = 'luma-chat sealed-box v1';

  /// Generates a new long-term identity keypair for this device.
  static Future<SimpleKeyPair> generateIdentity() => _x25519.newKeyPair();

  static Future<String> encodePublicKey(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  static SimplePublicKey decodePublicKey(String base64Key) =>
      SimplePublicKey(base64Decode(base64Key), type: KeyPairType.x25519);

  /// Encrypts [plaintext] so only the holder of the private key matching
  /// [recipientPublicKey] can read it.
  static Future<String> seal(
      String plaintext, SimplePublicKey recipientPublicKey) async {
    final ephemeral = await _x25519.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: recipientPublicKey,
    );
    final derivedKey = await _deriveKey(sharedSecret);

    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: derivedKey,
    );

    final out = BytesBuilder(copy: false)
      ..add(ephemeralPublic.bytes)
      ..add(secretBox.nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);
    return base64Encode(out.takeBytes());
  }

  /// Reverses [seal] using this device's long-term private key. Throws
  /// [ChatCryptoException] if the blob is malformed or was sealed for a
  /// different key.
  static Future<String> open(String blobBase64, SimpleKeyPair ownIdentity) async {
    late final Uint8List blob;
    try {
      blob = base64Decode(blobBase64);
    } catch (_) {
      throw const ChatCryptoException('Corrupted message.');
    }
    const pubLen = 32, nonceLen = 12, macLen = 16;
    if (blob.length < pubLen + nonceLen + macLen) {
      throw const ChatCryptoException('Corrupted message.');
    }
    final ephemeralPublicBytes = blob.sublist(0, pubLen);
    final nonce = blob.sublist(pubLen, pubLen + nonceLen);
    final cipherText = blob.sublist(pubLen + nonceLen, blob.length - macLen);
    final mac = blob.sublist(blob.length - macLen);

    final ephemeralPublic =
        SimplePublicKey(ephemeralPublicBytes, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ownIdentity,
      remotePublicKey: ephemeralPublic,
    );
    final derivedKey = await _deriveKey(sharedSecret);

    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: derivedKey,
      );
      return utf8.decode(clear);
    } catch (_) {
      throw const ChatCryptoException(
          'Could not decrypt — this message was not sealed for you.');
    }
  }

  static Future<SecretKey> _deriveKey(SecretKey sharedSecret) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode(_hkdfInfo),
    );
  }
}

class ChatCryptoException implements Exception {
  const ChatCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}

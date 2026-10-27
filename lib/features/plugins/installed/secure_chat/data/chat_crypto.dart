import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../../../l10n/current_l.dart';

/// A decrypted message and whether its sender was proven.
class OpenedMessage {
  const OpenedMessage(this.text, {required this.authenticated});

  final String text;

  /// True for v2 messages, which only the holder of the expected sender's
  /// private key could have sealed. False for v1 messages from older app
  /// versions: anyone — the server included — could have written those.
  final bool authenticated;
}

/// End-to-end encryption for the Chat plugin, built from well-known
/// primitives (X25519 key agreement, HKDF-SHA256, AES-256-GCM) via the
/// `cryptography` package.
///
/// Every user has a long-term X25519 keypair generated on-device; only the
/// public half is ever uploaded to the server (see chat_repository.dart /
/// chat_api.dart).
///
/// **v2 (current), authenticated.** The sender generates a one-time
/// *ephemeral* keypair and derives the message key from two agreements:
/// ephemeral × recipient, and sender's long-term key × recipient. The second
/// one means only the real sender can produce a message that opens under
/// their key, so the server can relay messages but not forge them, and the
/// ephemeral half keeps every message's key fresh. HKDF's info binds both
/// long-term keys and the ephemeral key, so a message can't be replayed
/// as coming from someone else. Wire format: `v2.` + base64 of
///   ephemeralPublicKey (32) | nonce (12) | ciphertext | mac (16)
///
/// **v1 (legacy), anonymous.** The same bytes with no `v2.` prefix and the
/// key from the ephemeral agreement alone. Still opened, for history and for
/// peers on an older app, but reported as unauthenticated.
///
/// Authenticating the sender only helps if the sender's key is the right
/// one; chat_repository.dart pins each peer's key on first use and refuses
/// to send when it changes until the user has compared [safetyNumber]s.
class ChatCrypto {
  ChatCrypto._();

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static const _v1Info = 'luma-chat sealed-box v1';
  static const _v2Info = 'luma-chat authenticated v2';
  static const _v2Prefix = 'v2.';

  /// Generates a new long-term identity keypair for this device.
  static Future<SimpleKeyPair> generateIdentity() => _x25519.newKeyPair();

  static Future<String> encodePublicKey(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  static SimplePublicKey decodePublicKey(String base64Key) =>
      SimplePublicKey(base64Decode(base64Key), type: KeyPairType.x25519);

  /// Encrypts [plaintext] so only the holder of the private key matching
  /// [recipientPublicKey] can read it, and only as a message from [sender].
  static Future<String> seal(String plaintext,
      SimplePublicKey recipientPublicKey, SimpleKeyPair sender) async {
    final ephemeral = await _x25519.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final senderPublic = await sender.extractPublicKey();
    final es = await _x25519.sharedSecretKey(
        keyPair: ephemeral, remotePublicKey: recipientPublicKey);
    final ss = await _x25519.sharedSecretKey(
        keyPair: sender, remotePublicKey: recipientPublicKey);
    final key = await _deriveV2Key(es, ss,
        ephemeral: ephemeralPublic.bytes,
        sender: senderPublic.bytes,
        recipient: recipientPublicKey.bytes);

    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    final out = BytesBuilder(copy: false)
      ..add(ephemeralPublic.bytes)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return '$_v2Prefix${base64Encode(out.takeBytes())}';
  }

  /// Reverses [seal] with this device's long-term private key. A v2 message
  /// only opens if [expectedSender] sealed it. Throws [ChatCryptoException]
  /// if the blob is malformed, was sealed for a different key, or (v2) did
  /// not come from [expectedSender].
  static Future<OpenedMessage> open(String blob, SimpleKeyPair ownIdentity,
      {required SimplePublicKey expectedSender}) async {
    final v2 = blob.startsWith(_v2Prefix);
    late final Uint8List bytes;
    try {
      bytes = base64Decode(v2 ? blob.substring(_v2Prefix.length) : blob);
    } catch (_) {
      throw ChatCryptoException(currentL.secureChatCouldNotDecrypt);
    }
    const pubLen = 32, nonceLen = 12, macLen = 16;
    if (bytes.length < pubLen + nonceLen + macLen) {
      throw ChatCryptoException(currentL.secureChatCouldNotDecrypt);
    }
    final ephemeralBytes = bytes.sublist(0, pubLen);
    final nonce = bytes.sublist(pubLen, pubLen + nonceLen);
    final cipherText = bytes.sublist(pubLen + nonceLen, bytes.length - macLen);
    final mac = bytes.sublist(bytes.length - macLen);
    final ephemeralPublic =
        SimplePublicKey(ephemeralBytes, type: KeyPairType.x25519);

    final es = await _x25519.sharedSecretKey(
        keyPair: ownIdentity, remotePublicKey: ephemeralPublic);
    final SecretKey key;
    if (v2) {
      final ownPublic = await ownIdentity.extractPublicKey();
      final ss = await _x25519.sharedSecretKey(
          keyPair: ownIdentity, remotePublicKey: expectedSender);
      key = await _deriveV2Key(es, ss,
          ephemeral: ephemeralBytes,
          sender: expectedSender.bytes,
          recipient: ownPublic.bytes);
    } else {
      key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32)
          .deriveKey(secretKey: es, info: utf8.encode(_v1Info));
    }

    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return OpenedMessage(utf8.decode(clear), authenticated: v2);
    } catch (_) {
      throw ChatCryptoException(currentL.secureChatCouldNotDecrypt);
    }
  }

  static Future<SecretKey> _deriveV2Key(SecretKey es, SecretKey ss,
      {required List<int> ephemeral,
      required List<int> sender,
      required List<int> recipient}) async {
    final material = [
      ...await es.extractBytes(),
      ...await ss.extractBytes(),
    ];
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(material),
      info: [...utf8.encode(_v2Info), ...ephemeral, ...sender, ...recipient],
    );
  }

  /// 60 digits, in 12 groups of 5, that both people in a conversation see
  /// identically when — and only when — each holds the other's real key.
  /// Comparing them in person or on a call rules out a key the server
  /// swapped in.
  static Future<String> safetyNumber(String publicKeyA, String publicKeyB) async {
    final keys = [base64Decode(publicKeyA), base64Decode(publicKeyB)]
      ..sort((a, b) {
        for (var i = 0; i < a.length && i < b.length; i++) {
          if (a[i] != b[i]) return a[i] - b[i];
        }
        return a.length - b.length;
      });
    final digest = await Sha512().hash([
      ...utf8.encode('luma-chat safety number v1'),
      ...keys[0],
      ...keys[1],
    ]);
    final bytes = digest.bytes;
    return [
      for (var g = 0; g < 12; g++)
        (((bytes[g * 5] << 32) |
                    (bytes[g * 5 + 1] << 24) |
                    (bytes[g * 5 + 2] << 16) |
                    (bytes[g * 5 + 3] << 8) |
                    bytes[g * 5 + 4]) %
                100000)
            .toString()
            .padLeft(5, '0'),
    ].join(' ');
  }
}

class ChatCryptoException implements Exception {
  const ChatCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}

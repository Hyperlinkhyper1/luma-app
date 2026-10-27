import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/secure_chat/data/chat_crypto.dart';

/// Chat messages are authenticated: only the real sender's key can produce
/// one that opens, so a server relaying them cannot forge or re-attribute.
void main() {
  late SimpleKeyPair alice;
  late SimpleKeyPair bob;
  late SimpleKeyPair mallory;
  late SimplePublicKey alicePub;
  late SimplePublicKey bobPub;

  setUp(() async {
    alice = await ChatCrypto.generateIdentity();
    bob = await ChatCrypto.generateIdentity();
    mallory = await ChatCrypto.generateIdentity();
    alicePub = await alice.extractPublicKey();
    bobPub = await bob.extractPublicKey();
  });

  test('a message opens for its recipient as coming from its sender',
      () async {
    final blob = await ChatCrypto.seal('hi bob', bobPub, alice);
    expect(blob, startsWith('v2.'));
    final opened = await ChatCrypto.open(blob, bob, expectedSender: alicePub);
    expect(opened.text, 'hi bob');
    expect(opened.authenticated, isTrue);
  });

  test('a message sealed by someone else does not open as the sender\'s',
      () async {
    final forged = await ChatCrypto.seal('send money', bobPub, mallory);
    expect(
        () => ChatCrypto.open(forged, bob, expectedSender: alicePub),
        throwsA(isA<ChatCryptoException>()));
  });

  test('a message for someone else does not open', () async {
    final blob = await ChatCrypto.seal('for bob', bobPub, alice);
    expect(() => ChatCrypto.open(blob, mallory, expectedSender: alicePub),
        throwsA(isA<ChatCryptoException>()));
  });

  test('legacy v1 messages still open, marked unauthenticated', () async {
    // The old anonymous sealed box: ephemeral × recipient only.
    final x25519 = X25519();
    final ephemeral = await x25519.newKeyPair();
    final shared = await x25519.sharedSecretKey(
        keyPair: ephemeral, remotePublicKey: bobPub);
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: shared, info: utf8.encode('luma-chat sealed-box v1'));
    final box = await AesGcm.with256bits()
        .encrypt(utf8.encode('old message'), secretKey: key);
    final blob = base64Encode([
      ...(await ephemeral.extractPublicKey()).bytes,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    final opened = await ChatCrypto.open(blob, bob, expectedSender: alicePub);
    expect(opened.text, 'old message');
    expect(opened.authenticated, isFalse);
  });

  test('both sides see the same safety number, and it depends on the keys',
      () async {
    final a = base64Encode(alicePub.bytes);
    final b = base64Encode(bobPub.bytes);
    final m = base64Encode((await mallory.extractPublicKey()).bytes);
    final ab = await ChatCrypto.safetyNumber(a, b);
    expect(await ChatCrypto.safetyNumber(b, a), ab);
    expect(RegExp(r'^(\d{5} ){11}\d{5}$').hasMatch(ab), isTrue);
    expect(await ChatCrypto.safetyNumber(a, m), isNot(ab));
  });
}

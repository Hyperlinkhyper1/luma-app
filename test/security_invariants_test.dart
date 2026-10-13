import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/p2p/peer_crypto.dart';
import 'package:luma/p2p/peer_protocol.dart';

/// Properties that must hold no matter how the code around them changes.
///
/// A stale-tree commit once reverted the P2P v2 handshake together with
/// p2p_test.dart, and CI stayed green because the tests left with the code.
/// These checks are deliberately small and separate, so losing the fix means
/// failing here too.
void main() {
  const accountKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('the cleartext peer hello carries no account secret', () {
    final hello = PeerHello(
      deviceId: 'device-a',
      deviceName: 'Office laptop',
      platform: 'windows',
      nonce: newPeerNonce(),
      collections: const {},
    ).withPublicKey(base64Encode(List<int>.filled(32, 7)));

    final json = hello.helloJson();
    expect(json.keys.toSet(), {'type', 'v', 'deviceId', 'nonce', 'epk'});
    expect(json.containsKey('token'), isFalse);
    final wire = jsonEncode(json);
    expect(wire.contains(accountKey.substring(0, 16)), isFalse);
  });

  test('the discovery tag does not reveal the account key', () {
    final tag = peerDiscoveryTag(accountKey);
    expect(tag, hasLength(16));
    expect(accountKey.contains(tag), isFalse);
  });

  test('every connection gets a fresh nonce', () {
    final a = newPeerNonce();
    final b = newPeerNonce();
    expect(isValidPeerNonce(a), isTrue);
    expect(a, isNot(b));
  });
}

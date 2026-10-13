import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pc;
import 'package:cryptography/cryptography.dart';

import '../security/record_cipher_pool.dart';

/// The security layer under LAN peer sync.
///
/// Two devices on the same account already share a secret — the handshake
/// key derived from the account's encryption key (see
/// `SyncService.peerHandshakeToken`) — so unlike the SFTP plugin's Host tab
/// (host_crypto.dart, which this mirrors) there is no password to type.
///
/// ```
/// each side -> other : hello { nonce, epk = one-time X25519 public key, … }
/// each side -> other : proof
/// then                 every frame sealed with ChaCha20-Poly1305
/// ```
///
/// with
///
/// ```
/// shared     = X25519(own ephemeral, peer ephemeral)
/// transcript = SHA256(label ‖ initiator hello ‖ responder hello)
/// master     = HKDF-SHA256(shared ‖ account key, salt: transcript, 104)
/// proof      = HMAC(auth key from master, role)
/// ```
///
/// What that buys:
///
/// * **Nothing to steal by listening or connecting.** The account key never
///   crosses the wire, and a proof only verifies against the one transcript
///   it was made for.
/// * **No impersonation, no relay.** Only a holder of the account key can
///   make a proof, and the hellos are hashed exactly as sent, so altering
///   either one — its keys, nonce, device id or advertised collections —
///   breaks both proofs.
/// * **Confidentiality and integrity after the handshake.** Shared-folder
///   files and every control message are sealed. Nonces are a per-direction
///   prefix plus a counter that is never transmitted, so a dropped, replayed,
///   reordered or altered frame fails to open and ends the connection.
/// * **Forward secrecy.** The X25519 keys exist for one connection. Learning
///   the account key later does not open a recording of an earlier session.

/// Bumped when the handshake changes incompatibly. Version 2 replaced the
/// plaintext token with nonce, one-time keys and proofs, and sealed every
/// frame after it.
const int kPeerProtocolVersion = 2;

/// Bytes [PeerSecureChannel.seal] adds to a record.
const int kPeerSealOverhead = RecordCipherPool.macLength;

const String _label = 'luma-p2p-v$kPeerProtocolVersion';

final X25519 _x25519 = X25519();

/// A fresh 32-byte challenge for one connection, hex-encoded.
String newPeerNonce() {
  final rng = Random.secure();
  return _hex(List<int>.generate(32, (_) => rng.nextInt(256)));
}

/// Whether [nonce] has the shape [newPeerNonce] produces.
bool isValidPeerNonce(String nonce) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(nonce);

/// The short same-account tag advertised over mDNS. Derived from [key]
/// rather than a slice of it, so broadcasting it reveals nothing about the
/// key the handshake proves.
String peerDiscoveryTag(String key) => _hex(pc.Hmac(pc.sha256, utf8.encode(key))
        .convert(utf8.encode('luma-p2p-discovery'))
        .bytes)
    .substring(0, 16);

/// [base64] as a 32-byte X25519 public key, or null when it is not one.
Uint8List? decodePeerPublicKey(String base64) {
  try {
    final bytes = base64Decode(base64);
    return bytes.length == 32 ? bytes : null;
  } on FormatException {
    return null;
  }
}

/// One connection's one-time X25519 key pair. Never stored.
class PeerKeyPair {
  PeerKeyPair._(this._pair, this.publicKey);

  final SimpleKeyPair _pair;

  /// The public half, base64, for the hello.
  final String publicKey;

  static Future<PeerKeyPair> generate() async {
    final pair = await _x25519.newKeyPair();
    final public = await pair.extractPublicKey();
    return PeerKeyPair._(pair, base64Encode(public.bytes));
  }
}

/// What both sides derive from one handshake.
class PeerSession {
  const PeerSession._(this.channel, this.ownProof, this.expectedPeerProof);

  /// Seals and opens every frame after the handshake.
  final PeerSecureChannel channel;

  /// What this side sends as its `proof`.
  final String ownProof;

  /// What the peer's `proof` must be for it to hold the account key.
  final String expectedPeerProof;
}

/// Runs the key schedule for one side of a connection.
///
/// [initiatorHello] and [responderHello] are the two hello payloads exactly
/// as they crossed the wire — re-encoding them could reorder a map and make
/// two honest devices disagree.
Future<PeerSession> derivePeerSession({
  required String key,
  required bool isInitiator,
  required PeerKeyPair ownKeyPair,
  required Uint8List peerPublicKey,
  required List<int> initiatorHello,
  required List<int> responderHello,
}) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: ownKeyPair._pair,
    remotePublicKey: SimplePublicKey(peerPublicKey, type: KeyPairType.x25519),
  );
  final sharedBytes = await shared.extractBytes();
  // A low-order public key forces an all-zero result whatever our private
  // key is. The account key would still keep an outsider out, but such a
  // key is never honest, and accepting it would quietly cost forward secrecy.
  if (sharedBytes.every((b) => b == 0)) {
    throw StateError('Degenerate key exchange.');
  }

  final transcript = _transcriptHash(initiatorHello, responderHello);
  final master = await Hkdf(hmac: Hmac.sha256(), outputLength: 104).deriveKey(
    secretKey: SecretKey([...sharedBytes, ...utf8.encode(key)]),
    nonce: transcript,
    info: utf8.encode(_label),
  );
  final bytes = Uint8List.fromList(await master.extractBytes());
  Uint8List slice(int start, int end) =>
      Uint8List.fromList(Uint8List.sublistView(bytes, start, end));

  final initiatorToResponder = slice(0, 32);
  final responderToInitiator = slice(32, 64);
  final authKey = slice(64, 96);
  final initiatorPrefix = slice(96, 100);
  final responderPrefix = slice(100, 104);

  String proof(String role) =>
      _hex(pc.Hmac(pc.sha256, authKey).convert(utf8.encode('$role proof')).bytes);
  final initiatorProof = proof('initiator');
  final responderProof = proof('responder');

  return PeerSession._(
    isInitiator
        ? PeerSecureChannel._(initiatorToResponder, responderToInitiator,
            initiatorPrefix, responderPrefix)
        : PeerSecureChannel._(responderToInitiator, initiatorToResponder,
            responderPrefix, initiatorPrefix),
    isInitiator ? initiatorProof : responderProof,
    isInitiator ? responderProof : initiatorProof,
  );
}

/// Every part length-prefixed, so a byte moved from the end of one field to
/// the start of the next cannot leave the hash unchanged.
Uint8List _transcriptHash(List<int> initiatorHello, List<int> responderHello) {
  final sink = <int>[];
  void put(List<int> part) {
    final n = part.length;
    sink.addAll([(n >> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff]);
    sink.addAll(part);
  }

  put(utf8.encode(_label));
  put(initiatorHello);
  put(responderHello);
  return Uint8List.fromList(pc.sha256.convert(sink).bytes);
}

/// The keys one connection uses after its handshake, and the counters that
/// keep its nonces unique. Only [derivePeerSession] makes one.
class PeerSecureChannel {
  PeerSecureChannel._(
    this._sendKey,
    this._receiveKey,
    this._sendNoncePrefix,
    this._receiveNoncePrefix,
  );

  final Uint8List _sendKey;
  final Uint8List _receiveKey;
  final Uint8List _sendNoncePrefix;
  final Uint8List _receiveNoncePrefix;

  int _sendCounter = 0;
  int _receiveCounter = 0;

  /// Seals one record. The counter is taken when this is called, not when the
  /// work finishes, so seals may overlap as long as the caller puts their
  /// results on the wire in the order it called this.
  Future<Uint8List> seal(List<int> plaintext) => RecordCipherPool.instance.seal(
        _sendKey,
        _nonce(_sendNoncePrefix, _sendCounter++),
        plaintext is Uint8List ? plaintext : Uint8List.fromList(plaintext),
      );

  /// Opens one record; records must be passed in arrival order. Any failure
  /// throws, and the connection must end there: carrying on would let a peer
  /// resynchronise the counter and replay traffic.
  Future<Uint8List> open(Uint8List record) async {
    // Taken before the first await, so still in call order.
    final nonce = _nonce(_receiveNoncePrefix, _receiveCounter++);
    if (record.length < kPeerSealOverhead) {
      throw StateError('Record too short to be authentic.');
    }
    return RecordCipherPool.instance.open(_receiveKey, nonce, record);
  }

  /// 12 bytes: the 4-byte per-direction prefix, then an 8-byte counter.
  static Uint8List _nonce(Uint8List prefix, int counter) {
    final nonce = Uint8List(12)..setAll(0, prefix);
    for (var i = 0; i < 8; i++) {
      nonce[11 - i] = (counter >> (8 * i)) & 0xff;
    }
    return nonce;
  }
}

/// Compares two strings without stopping at the first difference.
bool constantTimeStringEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

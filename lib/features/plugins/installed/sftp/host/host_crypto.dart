import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pc;
import 'package:cryptography/cryptography.dart';

import 'host_protocol.dart';

/// The security layer under the hosting protocol.
///
/// ## What it does
///
/// The two devices run an X25519 key exchange whose transcript is
/// authenticated with a key derived from the host's pairing password. Neither
/// side sends the password, and neither side accepts the other until both
/// have proved they derived the same key:
///
/// ```
/// host   -> client : version, host name, salt, hostEphemeralPublic
/// client -> host   : clientEphemeralPublic, device name, clientProof
/// host   -> client : serverProof            (or a refusal)
/// ```
///
/// with
///
/// ```
/// shared   = X25519(clientEphemeral, hostEphemeral)
/// pwKey    = PBKDF2-HMAC-SHA256(password, salt, 120 000, 32)
/// script   = SHA256(hello ‖ clientEphemeralPublic ‖ deviceName)
/// master   = HKDF-SHA256(shared ‖ pwKey, salt: salt, info: label ‖ script, 104)
/// ```
///
/// `master` is split into a key per direction, an authentication key, and a
/// nonce prefix per direction. `clientProof` and `serverProof` are HMACs
/// under the authentication key over distinct labels.
///
/// ## What that buys
///
/// * **Confidentiality.** Every frame after the handshake is sealed with
///   AES-256-GCM under a key that only exists on the two devices. Someone
///   recording the network sees file sizes and timing, never content or
///   names.
/// * **No impersonation.** The proofs are over the transcript, which includes
///   both ephemeral public keys. A machine in the middle would have to
///   produce a proof under a key it cannot derive without the password, so it
///   cannot relay the two halves of a connection to each other.
/// * **Forward secrecy.** The ephemeral keys are generated per connection and
///   never stored. Recovering the pairing password later does not decrypt a
///   recording of an earlier session.
/// * **No nonce reuse.** Nonces are a per-direction prefix plus a counter, and
///   the counter is never transmitted — a peer cannot steer it. Frames must
///   therefore arrive in order and exactly once; a replayed, reordered or
///   altered frame fails to decrypt and the connection is dropped.
///
/// ## What it does not buy
///
/// This is not a PAKE. Someone who records a handshake can mount an *offline*
/// guessing attack on the pairing password, at PBKDF2 cost per guess. That is
/// why [generatePairingPassword] produces around 100 bits of entropy and why
/// the host regenerates it every time hosting starts: guessing it offline is
/// not a realistic attack. A password the user types themselves is only as
/// good as they make it, which is what [describePasswordStrength] is for.
class HostCrypto {
  const HostCrypto._();

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();

  /// Bound into the key derivation, so keys from this protocol can never
  /// collide with keys derived for anything else in the app.
  static const _label = 'luma-sftp-host v1';

  static const _pbkdf2Iterations = 120000;
  static const saltLength = 16;
  static const publicKeyLength = 32;
  static const proofLength = 32;
}

/// The characters a generated pairing password is drawn from: Crockford-style
/// base32 with the glyphs that get misread by a person copying them by hand
/// (`I`, `L`, `O`, `U`, `0`, `1`) left out.
const String _passwordAlphabet = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';

/// A fresh pairing password: 20 characters from a 30-symbol alphabet, so
/// a little over 98 bits of entropy, drawn from the platform CSPRNG.
///
/// Grouped in fours (`ABCD-EFGH-…`) because it is meant to be read off one
/// screen and typed into another.
String generatePairingPassword() {
  final random = Random.secure();
  final chars = List<String>.generate(
    20,
    (_) => _passwordAlphabet[random.nextInt(_passwordAlphabet.length)],
  );
  final groups = <String>[];
  for (var i = 0; i < chars.length; i += 4) {
    groups.add(chars.sublist(i, i + 4).join());
  }
  return groups.join('-');
}

/// How much protection a user-chosen password offers, for the warning under
/// the field. Generated passwords always land on [PasswordStrength.strong].
enum PasswordStrength { tooShort, weak, fair, strong }

/// Rates [password] by rough entropy: how many distinct kinds of character it
/// uses, times how long it is. Deliberately blunt — it exists to stop someone
/// hosting their files behind `password`, not to score a passphrase precisely.
PasswordStrength describePasswordStrength(String password) {
  if (password.length < 8) return PasswordStrength.tooShort;
  var classes = 0;
  if (RegExp(r'[a-z]').hasMatch(password)) classes++;
  if (RegExp(r'[A-Z]').hasMatch(password)) classes++;
  if (RegExp(r'[0-9]').hasMatch(password)) classes++;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) classes++;
  final bits = password.length * (classes <= 1 ? 2 : (classes == 2 ? 3.5 : 5));
  if (bits >= 90) return PasswordStrength.strong;
  if (bits >= 55) return PasswordStrength.fair;
  return PasswordStrength.weak;
}

/// The shortest password the host will accept. Anything below this is
/// refused outright rather than warned about.
const int kMinPairingPasswordLength = 8;

/// Raised when a handshake cannot complete. The message is written for the
/// person looking at the screen; it never distinguishes "wrong password" from
/// "wrong device" in a way that would help someone guessing.
class HostAuthException implements Exception {
  const HostAuthException(this.message, {this.isAuthFailure = false});

  final String message;

  /// True when the pairing password was the problem, so the client can ask
  /// for it again instead of sending the user back a screen.
  final bool isAuthFailure;

  @override
  String toString() => message;
}

/// The keys one connection uses, and the counters that keep its nonces
/// unique. Created by [HostHandshake]; there is no other way to get one.
class HostSecureChannel {
  HostSecureChannel._(
    this._sendKey,
    this._receiveKey,
    this._sendNoncePrefix,
    this._receiveNoncePrefix,
  );

  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  final Uint8List _sendNoncePrefix;
  final Uint8List _receiveNoncePrefix;

  int _sendCounter = 0;
  int _receiveCounter = 0;

  /// Seals one record. The nonce is derived from the counter rather than
  /// transmitted, so the peer has no influence over it.
  Future<Uint8List> seal(Uint8List plaintext) async {
    final box = await HostCrypto._aes.encrypt(
      plaintext,
      secretKey: _sendKey,
      nonce: _nonce(_sendNoncePrefix, _sendCounter++),
    );
    final out = Uint8List(box.cipherText.length + 16)
      ..setAll(0, box.cipherText)
      ..setAll(box.cipherText.length, box.mac.bytes);
    return out;
  }

  /// Opens one record, in the order it was sealed.
  ///
  /// Any failure — a tampered byte, a dropped frame, a replayed one — throws,
  /// and callers treat that as fatal to the connection rather than skipping
  /// the record. Continuing after a failed open would let a peer resynchronise
  /// the counter and replay traffic.
  Future<Uint8List> open(Uint8List record) async {
    if (record.length < 16) {
      throw const HostProtocolException('Record too short to be authentic.');
    }
    final cipherText = Uint8List.sublistView(record, 0, record.length - 16);
    final mac = Uint8List.sublistView(record, record.length - 16);
    try {
      final clear = await HostCrypto._aes.decrypt(
        SecretBox(
          cipherText,
          nonce: _nonce(_receiveNoncePrefix, _receiveCounter),
          mac: Mac(mac),
        ),
        secretKey: _receiveKey,
      );
      _receiveCounter++;
      return Uint8List.fromList(clear);
    } catch (_) {
      throw const HostProtocolException(
        'A frame failed its authenticity check; the connection was closed.',
      );
    }
  }

  /// 12 bytes: a 4-byte per-direction prefix and an 8-byte counter. Unique
  /// for the life of the key because the counter only ever increases and the
  /// keys are per-connection and per-direction.
  static Uint8List _nonce(Uint8List prefix, int counter) {
    final nonce = Uint8List(12)..setAll(0, prefix);
    for (var i = 0; i < 8; i++) {
      nonce[11 - i] = (counter >> (8 * i)) & 0xff;
    }
    return nonce;
  }
}

/// What the host tells a client about itself before either side has proved
/// anything. It is sent in the clear, so it holds nothing sensitive: a
/// version, a display name, a random salt and a one-time public key.
class HostHello {
  const HostHello({
    required this.version,
    required this.hostName,
    required this.salt,
    required this.publicKey,
    required this.rootName,
    required this.readOnly,
  });

  final int version;
  final String hostName;
  final Uint8List salt;
  final Uint8List publicKey;

  /// The display name of the folder being shared — never its real path, which
  /// would tell an unauthenticated caller the user's account name.
  final String rootName;

  final bool readOnly;

  Map<String, dynamic> toJson() => {
        'v': version,
        'host': hostName,
        'salt': base64Encode(salt),
        'epk': base64Encode(publicKey),
        'root': rootName,
        'ro': readOnly,
      };

  static HostHello fromJson(Map<String, dynamic> json) {
    final salt = _decodeFixed(json['salt'], HostCrypto.saltLength, 'salt');
    final epk = _decodeFixed(json['epk'], HostCrypto.publicKeyLength, 'key');
    return HostHello(
      version: (json['v'] as num?)?.toInt() ?? 0,
      hostName: json['host']?.toString() ?? 'luma device',
      salt: salt,
      publicKey: epk,
      rootName: json['root']?.toString() ?? 'Shared',
      readOnly: json['ro'] == true,
    );
  }
}

/// Runs the handshake for either side and hands back the channel it produced.
class HostHandshake {
  const HostHandshake._();

  /// The host half: send [hello], read the client's answer, check its proof,
  /// and return the channel plus the name the client gave itself.
  ///
  /// [readFrame] and [writeFrame] are the raw framed transport — the caller
  /// owns the socket, so this stays testable over a pair of in-memory pipes.
  static Future<({HostSecureChannel channel, String deviceName})> acceptAsHost({
    required String password,
    required HostHello hello,
    required Uint8List hostPrivateSeed,
    required Future<Map<String, dynamic>> Function() readControl,
    required Future<void> Function(Map<String, dynamic> message) writeControl,
  }) async {
    final keyPair = await HostCrypto._x25519.newKeyPairFromSeed(hostPrivateSeed);
    await writeControl(hello.toJson());

    final answer = await readControl();
    final clientVersion = (answer['v'] as num?)?.toInt() ?? 0;
    if (clientVersion != kHostProtocolVersion) {
      await writeControl({
        'ok': false,
        'e': 'That device runs a different version of luma. Update both to '
            'the same version and try again.',
      });
      throw const HostAuthException('The other device speaks a different version.');
    }

    final clientPublic =
        _decodeFixed(answer['epk'], HostCrypto.publicKeyLength, 'key');
    final deviceName = _sanitizeName(answer['device']?.toString());
    final proof = _decodeFixed(answer['proof'], HostCrypto.proofLength, 'proof');

    final keys = await _derive(
      password: password,
      salt: hello.salt,
      ownKeyPair: keyPair,
      remotePublicKey: clientPublic,
      transcript: _transcript(hello, clientPublic, deviceName),
    );

    if (!_constantTimeEquals(proof, keys.clientProof)) {
      // Deliberately the same wording whichever way it failed: a caller
      // guessing must not learn whether it got closer.
      await writeControl({
        'ok': false,
        'e': 'That pairing password is not the one this device is showing.',
        'auth': true,
      });
      throw const HostAuthException(
        'A device tried to connect with the wrong pairing password.',
        isAuthFailure: true,
      );
    }

    await writeControl({'ok': true, 'proof': base64Encode(keys.serverProof)});

    return (
      channel: HostSecureChannel._(
        SecretKey(keys.serverToClient),
        SecretKey(keys.clientToServer),
        keys.serverNoncePrefix,
        keys.clientNoncePrefix,
      ),
      deviceName: deviceName,
    );
  }

  /// The client half: read the host's hello, answer it with a proof, and
  /// verify the host's proof before treating the connection as usable.
  static Future<({HostSecureChannel channel, HostHello hello})> connectAsClient({
    required String password,
    required String deviceName,
    required Future<Map<String, dynamic>> Function() readControl,
    required Future<void> Function(Map<String, dynamic> message) writeControl,
  }) async {
    final helloJson = await readControl();
    final hello = HostHello.fromJson(helloJson);
    if (hello.version != kHostProtocolVersion) {
      throw const HostAuthException(
        'That device runs a different version of luma. Update both to the '
        'same version and try again.',
      );
    }

    final keyPair = await HostCrypto._x25519.newKeyPair();
    final ownPublic = await keyPair.extractPublicKey();
    final ownPublicBytes = Uint8List.fromList(ownPublic.bytes);
    final name = _sanitizeName(deviceName);

    final keys = await _derive(
      password: password,
      salt: hello.salt,
      ownKeyPair: keyPair,
      remotePublicKey: hello.publicKey,
      transcript: _transcript(hello, ownPublicBytes, name),
    );

    await writeControl({
      'v': kHostProtocolVersion,
      'epk': base64Encode(ownPublicBytes),
      'device': name,
      'proof': base64Encode(keys.clientProof),
    });

    final verdict = await readControl();
    if (verdict['ok'] != true) {
      throw HostAuthException(
        verdict['e']?.toString() ?? 'That device refused the connection.',
        isAuthFailure: verdict['auth'] == true,
      );
    }

    final serverProof =
        _decodeFixed(verdict['proof'], HostCrypto.proofLength, 'proof');
    if (!_constantTimeEquals(serverProof, keys.serverProof)) {
      // The host could not prove it holds the password, so it is not the
      // device whose screen the user read the password off.
      throw const HostAuthException(
        'That device could not prove it is the one showing this pairing '
        'password. Nothing was sent to it.',
      );
    }

    return (
      channel: HostSecureChannel._(
        SecretKey(keys.clientToServer),
        SecretKey(keys.serverToClient),
        keys.clientNoncePrefix,
        keys.serverNoncePrefix,
      ),
      hello: hello,
    );
  }

  /// Everything both sides derive from the exchange, in one place so the two
  /// halves above cannot drift apart.
  static Future<_DerivedKeys> _derive({
    required String password,
    required Uint8List salt,
    required SimpleKeyPair ownKeyPair,
    required Uint8List remotePublicKey,
    required Uint8List transcript,
  }) async {
    final shared = await HostCrypto._x25519.sharedSecretKey(
      keyPair: ownKeyPair,
      remotePublicKey:
          SimplePublicKey(remotePublicKey, type: KeyPairType.x25519),
    );
    final sharedBytes = Uint8List.fromList(await shared.extractBytes());
    final passwordKey = await derivePasswordKey(password, salt);

    final ikm = Uint8List(sharedBytes.length + passwordKey.length)
      ..setAll(0, sharedBytes)
      ..setAll(sharedBytes.length, passwordKey);

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 104);
    final master = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt,
      info: <int>[...utf8.encode(HostCrypto._label), ...transcript],
    );
    final bytes = Uint8List.fromList(await master.extractBytes());

    final authKey = Uint8List.sublistView(bytes, 64, 96);
    return _DerivedKeys(
      clientToServer: Uint8List.fromList(Uint8List.sublistView(bytes, 0, 32)),
      serverToClient: Uint8List.fromList(Uint8List.sublistView(bytes, 32, 64)),
      clientNoncePrefix:
          Uint8List.fromList(Uint8List.sublistView(bytes, 96, 100)),
      serverNoncePrefix:
          Uint8List.fromList(Uint8List.sublistView(bytes, 100, 104)),
      clientProof: _proof(authKey, 'client'),
      serverProof: _proof(authKey, 'server'),
    );
  }

  /// Binds both ephemeral public keys and the host's advertised identity into
  /// one hash, so a relay cannot pair two separate handshakes.
  ///
  /// Every part is length-prefixed: without that, moving a byte from the end
  /// of one field to the start of the next would leave the hash unchanged.
  static Uint8List _transcript(
    HostHello hello,
    Uint8List clientPublicKey,
    String deviceName,
  ) {
    final sink = <int>[];
    void put(List<int> part) {
      final length = part.length;
      sink.addAll([
        (length >> 24) & 0xff,
        (length >> 16) & 0xff,
        (length >> 8) & 0xff,
        length & 0xff,
      ]);
      sink.addAll(part);
    }

    put(utf8.encode(jsonEncode(hello.toJson())));
    put(clientPublicKey);
    put(utf8.encode(deviceName));
    return Uint8List.fromList(pc.sha256.convert(sink).bytes);
  }

  static Uint8List _proof(Uint8List authKey, String role) => Uint8List.fromList(
        pc.Hmac(pc.sha256, authKey).convert(utf8.encode('$role proof')).bytes,
      );
}

class _DerivedKeys {
  const _DerivedKeys({
    required this.clientToServer,
    required this.serverToClient,
    required this.clientNoncePrefix,
    required this.serverNoncePrefix,
    required this.clientProof,
    required this.serverProof,
  });

  final Uint8List clientToServer;
  final Uint8List serverToClient;
  final Uint8List clientNoncePrefix;
  final Uint8List serverNoncePrefix;
  final Uint8List clientProof;
  final Uint8List serverProof;
}

/// PBKDF2-HMAC-SHA256 over the pairing password.
///
/// It runs on a separate isolate: 120 000 iterations is deliberately slow, and
/// on the host that cost is paid on every connection attempt — doing it on the
/// UI isolate would freeze the pane the user is looking at while a device
/// connects.
Future<Uint8List> derivePasswordKey(String password, Uint8List salt) =>
    Isolate.run(() => _pbkdf2(password, salt));

/// Deliberately a plain implementation over `package:crypto`, which is the
/// same HMAC the rest of the plugin already trusts.
Uint8List _pbkdf2(String password, Uint8List salt) {
  final hmac = pc.Hmac(pc.sha256, utf8.encode(password));
  // One 32-byte output block, so the block index is always 1.
  var block = Uint8List.fromList(
    hmac.convert(<int>[...salt, 0, 0, 0, 1]).bytes,
  );
  final result = Uint8List.fromList(block);
  for (var i = 1; i < HostCrypto._pbkdf2Iterations; i++) {
    block = Uint8List.fromList(hmac.convert(block).bytes);
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return result;
}

/// The X25519 public key belonging to [seed].
///
/// The host generates its ephemeral key as a raw seed so it can put the
/// public half into the hello it has to build before the handshake runs, and
/// still hand the same seed to [HostHandshake.acceptAsHost] — the two must
/// agree or the client's proof will never verify.
Future<Uint8List> publicKeyForSeed(Uint8List seed) async {
  final pair = await HostCrypto._x25519.newKeyPairFromSeed(seed);
  final public = await pair.extractPublicKey();
  return Uint8List.fromList(public.bytes);
}

/// Random bytes from the platform CSPRNG.
Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

/// Compares two byte strings without leaking where they first differ.
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Device names travel between machines and end up in the host's connection
/// list, so they are clamped to something printable and short rather than
/// rendered as sent.
String _sanitizeName(String? raw) {
  final cleaned = (raw ?? '')
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
      .trim();
  if (cleaned.isEmpty) return 'A luma device';
  return cleaned.length <= 40 ? cleaned : cleaned.substring(0, 40);
}

Uint8List _decodeFixed(Object? value, int length, String what) {
  if (value is! String) {
    throw HostProtocolException('The handshake was missing its $what.');
  }
  final Uint8List bytes;
  try {
    bytes = base64Decode(value);
  } catch (_) {
    throw HostProtocolException('The handshake $what was malformed.');
  }
  if (bytes.length != length) {
    throw HostProtocolException('The handshake $what was the wrong size.');
  }
  return bytes;
}

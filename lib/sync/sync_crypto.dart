import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../security/authenticated_cipher.dart';

/// Client-side snapshot encryption. New envelopes use AES-256-GCM; LS1
/// custom-cipher envelopes remain readable for migration. Account PBKDF2
/// and HKDF derivation is unchanged for existing account compatibility.
/// Password strength and endpoint integrity remain essential: the server
/// can test password guesses against the authentication verifier.
class SyncCrypto {
  SyncCrypto._();

  /// PBKDF2-HMAC-SHA256 iterations for new accounts. Stored per account so
  /// it can be raised later without breaking existing users.
  static const int defaultKdfIterations = 200000;

  static const _magic = [0x4C, 0x53, 0x31]; // "LS1"
  static const _nonceLength = 12;
  static const _macLength = 32;

  static Uint8List randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// Derives the auth key (sent to the server) and encryption key (kept
  /// local) from the account password. Runs in a background isolate on
  /// native platforms because PBKDF2 is deliberately slow.
  static Future<DerivedKeys> deriveKeys({
    required String password,
    required Uint8List kdfSalt,
    required int iterations,
  }) async {
    final result = await compute(_deriveKeysWorker, <String, Object>{
      'password': password,
      'salt': kdfSalt,
      'iterations': iterations,
    });
    return DerivedKeys(authKey: result['auth']!, encryptionKey: result['enc']!);
  }

  static Map<String, Uint8List> _deriveKeysWorker(Map<String, Object> args) {
    final master = pbkdf2Sha256(
      utf8.encode(args['password'] as String),
      args['salt'] as Uint8List,
      args['iterations'] as int,
      32,
    );
    return {
      'auth': hkdfExpand(master, utf8.encode('luma-sync auth v1'), 32),
      'enc': hkdfExpand(master, utf8.encode('luma-sync enc v1'), 32),
    };
  }

  /// Seals JSON as gzip inside a versioned AES-256-GCM envelope.
  static Future<Uint8List> sealPayload(
    Object payload,
    Uint8List encryptionKey,
  ) async {
    final clear = Uint8List.fromList(
      const GZipEncoder().encodeBytes(utf8.encode(jsonEncode(payload))),
    );
    return sealRaw(clear, encryptionKey);
  }

  /// Reverses [sealPayload]. Throws [SyncCryptoException] when the blob is
  /// malformed or was encrypted under a different key (wrong password).
  static Future<Object?> openPayload(
    Uint8List blob,
    Uint8List encryptionKey,
  ) async {
    final clear = openRaw(blob, encryptionKey);
    try {
      return jsonDecode(utf8.decode(const GZipDecoder().decodeBytes(clear)));
    } catch (_) {
      throw const SyncCryptoException('Corrupted snapshot.');
    }
  }

  /// Seals opaque bytes (no gzip/JSON) — used for file chunks. Runs in a
  /// background isolate so encrypting large chunks never freezes the UI.
  static Future<Uint8List> sealBytes(Uint8List data, Uint8List key) =>
      compute(_sealWorker, (data, key));

  /// Reverses [sealBytes] in a background isolate.
  static Future<Uint8List> openBytes(Uint8List blob, Uint8List key) =>
      compute(_openWorker, (blob, key));

  static Uint8List _sealWorker((Uint8List, Uint8List) args) =>
      sealRaw(args.$1, args.$2);
  static Uint8List _openWorker((Uint8List, Uint8List) args) =>
      openRaw(args.$1, args.$2);

  /// Authenticated encryption shared by payload and raw-byte sealing.
  static Uint8List sealRaw(Uint8List clear, Uint8List key) {
    return AuthenticatedCipher.seal(
      clear,
      hkdfExpand(key, utf8.encode('luma-sync aes-gcm v2'), 32),
      'luma-sync-v2',
    );
  }

  /// Verifies and decrypts a [sealRaw] blob, returning the plaintext bytes.
  /// Throws [SyncCryptoException] on a bad format, wrong key, or tampering.
  static Uint8List openRaw(Uint8List blob, Uint8List key) {
    if (blob.length >= 2 && blob[0] == 0x4c && blob[1] == 0x41) {
      try {
        return AuthenticatedCipher.open(
          blob,
          hkdfExpand(key, utf8.encode('luma-sync aes-gcm v2'), 32),
          'luma-sync-v2',
        );
      } catch (_) {
        throw const SyncCryptoException(
          'Encrypted data failed authentication.',
        );
      }
    }
    if (blob.length < _magic.length + _nonceLength + _macLength ||
        blob[0] != _magic[0] ||
        blob[1] != _magic[1] ||
        blob[2] != _magic[2]) {
      throw const SyncCryptoException('Unrecognized encrypted data.');
    }
    final nonce = blob.sublist(_magic.length, _magic.length + _nonceLength);
    final cipher = blob.sublist(
      _magic.length + _nonceLength,
      blob.length - _macLength,
    );
    final mac = blob.sublist(blob.length - _macLength);

    final macKey = hkdfExpand(key, _macInfo, 32);
    if (!_constantTimeEquals(mac, _mac(macKey, nonce, cipher))) {
      throw const SyncCryptoException(
        'Could not decrypt — it was encrypted with a different password.',
      );
    }
    final cipherKey = hkdfExpand(key, _cipherInfo, 32);
    return _xorKeystream(cipher, cipherKey, nonce);
  }

  static final Uint8List _cipherInfo = Uint8List.fromList(
    utf8.encode('luma-sync cipher'),
  );
  static final Uint8List _macInfo = Uint8List.fromList(
    utf8.encode('luma-sync mac'),
  );

  /// XORs [data] with an HMAC-SHA256 keystream in counter mode.
  static Uint8List _xorKeystream(
    List<int> data,
    Uint8List key,
    List<int> nonce,
  ) {
    final out = Uint8List(data.length);
    final hmac = Hmac(sha256, key);
    var counter = 0;
    var offset = 0;
    while (offset < data.length) {
      final block = hmac.convert([...nonce, ..._int32be(counter)]).bytes;
      for (var i = 0; i < block.length && offset < data.length; i++, offset++) {
        out[offset] = data[offset] ^ block[i];
      }
      counter++;
    }
    return out;
  }

  static Uint8List _mac(Uint8List key, List<int> nonce, List<int> cipher) =>
      Uint8List.fromList(
        Hmac(sha256, key).convert([...nonce, ...cipher]).bytes,
      );

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// PBKDF2-HMAC-SHA256 (RFC 2898). Top-level so it can run inside a
/// `compute` isolate.
Uint8List pbkdf2Sha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int dkLen,
) {
  final hmac = Hmac(sha256, password);
  final out = BytesBuilder();
  var block = 1;
  while (out.length < dkLen) {
    var u = Uint8List.fromList(
      hmac.convert([...salt, ..._int32be(block)]).bytes,
    );
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
    block++;
  }
  return Uint8List.fromList(out.takeBytes().sublist(0, dkLen));
}

/// HKDF-Expand (RFC 5869) with SHA-256. [prk] must already be a pseudo-random
/// key (our inputs are PBKDF2 or HKDF outputs, so extraction is not needed).
Uint8List hkdfExpand(List<int> prk, List<int> info, int length) {
  final hmac = Hmac(sha256, prk);
  final out = BytesBuilder();
  List<int> prev = const [];
  var counter = 1;
  while (out.length < length) {
    prev = hmac.convert([...prev, ...info, counter]).bytes;
    out.add(prev);
    counter++;
  }
  return Uint8List.fromList(out.takeBytes().sublist(0, length));
}

Uint8List _int32be(int value) {
  final b = ByteData(4)..setUint32(0, value, Endian.big);
  return b.buffer.asUint8List();
}

class DerivedKeys {
  const DerivedKeys({required this.authKey, required this.encryptionKey});

  /// Sent to the server as the login secret (password-equivalent, but the
  /// real password cannot be recovered from it).
  final Uint8List authKey;

  /// Encrypts all synced data. Never leaves the device.
  final Uint8List encryptionKey;
}

class SyncCryptoException implements Exception {
  const SyncCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../security/secure_secret_store.dart';

/// Encrypts the passwords and key passphrases the SFTP plugin remembers, so
/// `luma_sftp_sites.json` never holds a readable credential.
///
/// The historical HMAC stream-cipher format remains in use here. Its key
/// now lives in OS secure storage; malformed or missing keys are never
/// replaced when encrypted data exists. This is not a master-password vault.
class SftpSecretCrypto {
  SftpSecretCrypto._(this._key);

  final Uint8List _key;

  static const _keyFileName = 'luma_sftp.key';
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _versionByte = 0x01;

  static SftpSecretCrypto? _instance;

  /// Loads the key from disk, creating it on first run.
  static Future<SftpSecretCrypto> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_keyFileName');

    final key = await SecureSecretStore.instance.loadKey(
      'sftp.key',
      file,
      encryptedDataExists: await File(
        '${dir.path}/luma_sftp_sites.json',
      ).exists(),
    );
    return _instance = SftpSecretCrypto._(key);
  }

  /// Builds an instance over a caller-supplied key. Only used by tests, which
  /// must not touch the real key file.
  static SftpSecretCrypto forTesting(Uint8List key) => SftpSecretCrypto._(key);

  /// Returns a base64 token of `version || nonce || ciphertext || mac`, the
  /// MAC bound to [siteId] and [field].
  String encrypt(
    String plaintext, {
    required String siteId,
    required String field,
  }) {
    final nonce = _randomBytes(_nonceLength);
    final cipher = _xorKeystream(
      Uint8List.fromList(utf8.encode(plaintext)),
      nonce,
    );
    final mac = _mac(_context(siteId, field), nonce, cipher);
    final out = Uint8List(1 + nonce.length + cipher.length + mac.length)
      ..[0] = _versionByte
      ..setAll(1, nonce)
      ..setAll(1 + nonce.length, cipher)
      ..setAll(1 + nonce.length + cipher.length, mac);
    return base64Encode(out);
  }

  /// Reverses [encrypt]. Returns null when the token is malformed, was
  /// written under a different key, or belongs to another site or field —
  /// callers must treat that as "no saved secret", never as an empty one.
  String? decrypt(
    String token, {
    required String siteId,
    required String field,
  }) {
    try {
      final raw = base64Decode(token);
      if (raw.isEmpty || raw[0] != _versionByte) return null;
      final body = raw.sublist(1);
      if (body.length < _nonceLength + _macLength) return null;
      final nonce = body.sublist(0, _nonceLength);
      final cipher = body.sublist(_nonceLength, body.length - _macLength);
      final mac = body.sublist(body.length - _macLength);
      if (!_constantTimeEquals(
        mac,
        _mac(_context(siteId, field), nonce, cipher),
      )) {
        return null;
      }
      return utf8.decode(_xorKeystream(cipher, nonce));
    } catch (_) {
      return null;
    }
  }

  static Uint8List _context(String siteId, String field) =>
      Uint8List.fromList(utf8.encode('luma-sftp-site|id:$siteId|field:$field'));

  /// XORs [data] with a keystream derived from [nonce] in counter mode.
  Uint8List _xorKeystream(Uint8List data, Uint8List nonce) {
    final out = Uint8List(data.length);
    var counter = 0;
    var offset = 0;
    while (offset < data.length) {
      final block = Hmac(
        sha256,
        _key,
      ).convert([...nonce, ..._uint32be(counter)]).bytes;
      final take = min(block.length, data.length - offset);
      for (var i = 0; i < take; i++) {
        out[offset + i] = data[offset + i] ^ block[i];
      }
      offset += take;
      counter++;
    }
    return out;
  }

  Uint8List _mac(Uint8List context, Uint8List nonce, Uint8List cipher) {
    final digest = Hmac(
      sha256,
      _key,
    ).convert([..._uint32be(context.length), ...context, ...nonce, ...cipher]);
    return Uint8List.fromList(digest.bytes.sublist(0, _macLength));
  }

  static List<int> _uint32be(int value) => [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }
}

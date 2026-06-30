import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Encrypts password secrets at rest so they are not readable in the raw
/// database file.
///
/// We deliberately avoid a heavyweight cipher dependency: this is an
/// encrypt-then-MAC stream cipher built on HMAC-SHA256 (used as a PRF in
/// counter mode), which the `crypto` package already provides. A random 32-byte
/// key is generated once and stored next to the database in the app's local
/// support directory. This protects secrets against anyone reading the SQLite
/// file directly without also holding the key file; it is not a substitute for
/// a master-password vault.
class PasswordCrypto {
  PasswordCrypto._(this._key);

  final Uint8List _key;

  static const _keyFileName = 'luma_pw.key';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static PasswordCrypto? _instance;

  /// Loads the key from disk (creating it on first run) and returns a shared
  /// instance.
  static Future<PasswordCrypto> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_keyFileName');

    Uint8List key;
    if (await file.exists()) {
      key = base64Decode((await file.readAsString()).trim());
    } else {
      key = _randomBytes(32);
      await file.writeAsString(base64Encode(key), flush: true);
    }
    return _instance = PasswordCrypto._(key);
  }

  /// Returns a base64 token of `nonce || ciphertext || mac`.
  String encrypt(String plaintext) {
    final nonce = _randomBytes(_nonceLength);
    final data = utf8.encode(plaintext);
    final cipher = _xorKeystream(data, nonce);
    final mac = _mac(nonce, cipher);
    final out = Uint8List(nonce.length + cipher.length + mac.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, cipher)
      ..setAll(nonce.length + cipher.length, mac);
    return base64Encode(out);
  }

  /// Reverses [encrypt]. Returns an empty string if the token is malformed or
  /// fails integrity verification (e.g. produced under a different key).
  String decrypt(String token) {
    try {
      final raw = base64Decode(token);
      if (raw.length < _nonceLength + _macLength) return '';
      final nonce = raw.sublist(0, _nonceLength);
      final cipher = raw.sublist(_nonceLength, raw.length - _macLength);
      final mac = raw.sublist(raw.length - _macLength);
      final expected = _mac(nonce, cipher);
      if (!_constantTimeEquals(mac, expected)) return '';
      return utf8.decode(_xorKeystream(cipher, nonce));
    } catch (_) {
      return '';
    }
  }

  /// XORs [data] with a keystream derived from [nonce] in counter mode.
  Uint8List _xorKeystream(List<int> data, List<int> nonce) {
    final out = Uint8List(data.length);
    final hmac = Hmac(sha256, _key);
    var counter = 0;
    var offset = 0;
    while (offset < data.length) {
      final block = hmac.convert([...nonce, ..._counterBytes(counter)]).bytes;
      for (var i = 0; i < block.length && offset < data.length; i++, offset++) {
        out[offset] = data[offset] ^ block[i];
      }
      counter++;
    }
    return out;
  }

  Uint8List _mac(List<int> nonce, List<int> cipher) {
    final tag = Hmac(sha256, _key).convert([...nonce, ...cipher]).bytes;
    return Uint8List.fromList(tag.sublist(0, _macLength));
  }

  static Uint8List _counterBytes(int counter) {
    final b = ByteData(4)..setUint32(0, counter, Endian.big);
    return b.buffer.asUint8List();
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rng.nextInt(256)));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

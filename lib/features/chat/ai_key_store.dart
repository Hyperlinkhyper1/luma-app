import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Stores the user's own AI provider API keys locally, encrypted at rest —
/// one file per provider (Anthropic, OpenAI, Mistral/"Luma", ...), keyed by
/// `AiProviderInfo.id.name`.
///
/// This mirrors `PasswordCrypto` (same HMAC-SHA256 encrypt-then-MAC stream
/// cipher) but uses its own key file so compromising one secret doesn't
/// compromise the other. This is obfuscation-at-rest, not a hardware-backed
/// secret store: anyone with filesystem access to the app's support
/// directory could decrypt the key. That's an acceptable tradeoff because
/// each key is the user's own revocable provider credential, not a master
/// secret — it is never compiled into the app binary and never sent
/// anywhere except directly to that provider's API from this device.
class AiKeyStore {
  AiKeyStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_ai.key';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static AiKeyStore? _instance;

  static Future<AiKeyStore> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final keyFile = File('${dir.path}${Platform.pathSeparator}$_keyFileName');

    Uint8List key;
    if (await keyFile.exists()) {
      key = base64Decode((await keyFile.readAsString()).trim());
    } else {
      key = _randomBytes(32);
      await keyFile.writeAsString(base64Encode(key), flush: true);
    }
    return _instance = AiKeyStore._(key, dir.path);
  }

  File _fileFor(String providerId) => File(
      '$_dirPath${Platform.pathSeparator}luma_ai_apikey_$providerId.dat');

  /// Returns the saved API key for [providerId], or null if none has been
  /// saved.
  Future<String?> readKey(String providerId) async {
    final file = _fileFor(providerId);
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    if (token.isEmpty) return null;
    final decrypted = _decrypt(token);
    return decrypted.isEmpty ? null : decrypted;
  }

  Future<void> saveKey(String providerId, String apiKey) async {
    await _fileFor(providerId).writeAsString(_encrypt(apiKey), flush: true);
  }

  Future<void> clearKey(String providerId) async {
    final file = _fileFor(providerId);
    if (await file.exists()) await file.delete();
  }

  String _encrypt(String plaintext) {
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

  String _decrypt(String token) {
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

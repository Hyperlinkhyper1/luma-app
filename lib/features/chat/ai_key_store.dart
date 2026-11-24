import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../security/secure_secret_store.dart';
import '../../security/authenticated_cipher.dart';

/// Provider-bound AES-256-GCM for new API key records. The independent key
/// lives in OS secure storage; legacy ciphertext remains readable. Provider
/// credentials are passed only to the chosen provider or configured proxy.
class AiKeyStore {
  AiKeyStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_ai.key';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static AiKeyStore? _instance;

  /// Bumped whenever a key is saved or removed, so an open chat can notice
  /// a key added from the API screen without being reopened.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static Future<AiKeyStore> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final keyFile = File('${dir.path}${Platform.pathSeparator}$_keyFileName');

    final data = await dir
        .list()
        .where(
          (entry) =>
              entry is File &&
              entry.path.contains('luma_ai_apikey_') &&
              entry.path.endsWith('.dat'),
        )
        .cast<File>()
        .toList();
    final key = await SecureSecretStore.instance.loadKey(
      'ai.key',
      legacyFile: keyFile,
      encryptedData: data,
    );
    final store = AiKeyStore._(key, dir.path);
    await store._moveLegacyGoogleKey();
    return _instance = store;
  }

  /// A Google key used to be saved under Luma AI's `google` id, where it
  /// silently replaced the server's Luma AI. It now belongs to the Google
  /// Gemini entry on the API screen, the one place keys are managed.
  Future<void> _moveLegacyGoogleKey() async {
    try {
      final legacy = await readKey('google');
      if (legacy == null) return;
      if (await readKey('gemini') == null) await saveKey('gemini', legacy);
      await clearKey('google');
    } catch (_) {}
  }

  File _fileFor(String providerId) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(providerId)) {
      throw const FormatException('Invalid provider identifier.');
    }
    return File(
      '$_dirPath${Platform.pathSeparator}luma_ai_apikey_$providerId.dat',
    );
  }

  /// Returns the saved API key for [providerId], or null if none has been
  /// saved.
  Future<String?> readKey(String providerId) async {
    final file = _fileFor(providerId);
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    if (token.isEmpty) return null;
    final decrypted = token.startsWith('ai2:')
        ? utf8.decode(
            AuthenticatedCipher.open(
              base64Decode(token.substring(4)),
              _key,
              'luma-ai:$providerId',
            ),
          )
        : _decrypt(token);
    return decrypted.isEmpty ? null : decrypted;
  }

  Future<void> saveKey(String providerId, String apiKey) async {
    final token =
        'ai2:${base64Encode(AuthenticatedCipher.seal(utf8.encode(apiKey), _key, 'luma-ai:$providerId'))}';
    await _fileFor(providerId).writeAsString(token, flush: true);
    changes.value++;
  }

  Future<void> clearKey(String providerId) async {
    final file = _fileFor(providerId);
    if (await file.exists()) await file.delete();
    changes.value++;
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

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

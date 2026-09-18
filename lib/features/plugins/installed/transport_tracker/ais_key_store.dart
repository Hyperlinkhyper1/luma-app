import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../security/secure_secret_store.dart';

/// Stores this integration's credential using its historical authenticated
/// cipher format. The independent encryption key is migrated to OS secure
/// storage with verification before removing the legacy adjacent key file.
/// Payload-cipher replacement remains a separate migration.
class AisKeyStore {
  AisKeyStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_ais.key';
  static const _dataFileName = 'luma_ais_apikey.dat';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static AisKeyStore? _instance;

  static Future<AisKeyStore> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final keyFile = File('${dir.path}${Platform.pathSeparator}$_keyFileName');

    final key = await SecureSecretStore.instance.loadKey(
      'ais.key',
      keyFile,
      encryptedDataExists: await File('${dir.path}/$_dataFileName').exists(),
    );
    return _instance = AisKeyStore._(key, dir.path);
  }

  File get _dataFile =>
      File('$_dirPath${Platform.pathSeparator}$_dataFileName');

  Future<String?> readKey() async {
    final file = _dataFile;
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    if (token.isEmpty) return null;
    final decrypted = _decrypt(token);
    return decrypted.isEmpty ? null : decrypted;
  }

  Future<void> saveKey(String apiKey) async {
    await _dataFile.writeAsString(_encrypt(apiKey), flush: true);
  }

  Future<void> clearKey() async {
    final file = _dataFile;
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
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
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

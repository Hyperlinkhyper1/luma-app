import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// The pair that identifies a Steam account to the Web API.
class SteamCredentials {
  const SteamCredentials({required this.apiKey, required this.steamId});

  final String apiKey;

  /// The 64-bit account id, as a decimal string.
  final String steamId;

  bool get isComplete => apiKey.isNotEmpty && steamId.isNotEmpty;

  /// The key with everything but its last four characters masked, for
  /// showing that a key is saved without putting it back on screen.
  String get maskedKey {
    if (apiKey.length <= 4) return '\u2022' * apiKey.length;
    return '${'\u2022' * (apiKey.length - 4)}${apiKey.substring(apiKey.length - 4)}';
  }
}

/// Stores the user's Steam Web API key and account id locally, encrypted at
/// rest.
///
/// Mirrors `AisKeyStore` and `AiKeyStore` (same HMAC-SHA256 encrypt-then-MAC
/// stream cipher) with its own key file, since it is an unrelated
/// credential. This is obfuscation-at-rest, not a hardware-backed secret
/// store — an acceptable tradeoff because it is the user's own free,
/// revocable API key, sent only from this device directly to Steam.
class SteamCredentialStore {
  SteamCredentialStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_steam.key';
  static const _dataFileName = 'luma_steam_account.dat';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static SteamCredentialStore? _instance;

  static Future<SteamCredentialStore> load() async {
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
    return _instance = SteamCredentialStore._(key, dir.path);
  }

  File get _dataFile => File('$_dirPath${Platform.pathSeparator}$_dataFileName');

  Future<SteamCredentials?> read() async {
    final file = _dataFile;
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    if (token.isEmpty) return null;
    final decrypted = _decrypt(token);
    if (decrypted.isEmpty) return null;
    try {
      final json = jsonDecode(decrypted);
      if (json is! Map) return null;
      final apiKey = json['apiKey'];
      final steamId = json['steamId'];
      if (apiKey is! String || steamId is! String) return null;
      if (apiKey.isEmpty || steamId.isEmpty) return null;
      return SteamCredentials(apiKey: apiKey, steamId: steamId);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SteamCredentials credentials) async {
    final payload = jsonEncode({
      'apiKey': credentials.apiKey,
      'steamId': credentials.steamId,
    });
    await _dataFile.writeAsString(_encrypt(payload), flush: true);
  }

  Future<void> clear() async {
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

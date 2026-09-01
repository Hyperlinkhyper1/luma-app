import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Everything luma needs to keep a YouTube channel connected: the user's own
/// Google Cloud OAuth client, and the tokens that client obtained.
///
/// Unlike GitHub's single pasted token, there is no long-lived secret to
/// paste for YouTube — the client id/secret are the user's own OAuth client,
/// and the access/refresh tokens are what that client's consent flow handed
/// back. The client secret is kept alongside them because Google requires it
/// again for every refresh-token exchange.
class YoutubeCredentials {
  const YoutubeCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.channelId,
    this.channelTitle,
  });

  final String clientId;
  final String clientSecret;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// Resolved from the channel itself on connect, never typed.
  final String? channelId;
  final String? channelTitle;

  bool get isComplete =>
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      accessToken.isNotEmpty &&
      refreshToken.isNotEmpty;

  /// A minute of slack so a call started just before expiry does not race it.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  YoutubeCredentials copyWith({
    String? accessToken,
    DateTime? expiresAt,
    String? channelId,
    String? channelTitle,
  }) =>
      YoutubeCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        channelId: channelId ?? this.channelId,
        channelTitle: channelTitle ?? this.channelTitle,
      );
}

/// Stores the YouTube OAuth credentials locally, encrypted at rest.
///
/// Byte-for-byte the same encrypt-then-MAC HMAC-SHA256 stream cipher as
/// `GithubCredentialStore`, with its own key file since it is an unrelated
/// credential. This is obfuscation-at-rest rather than a hardware-backed
/// secret store, the same tradeoff the other key stores make: it is the
/// user's own revocable grant, sent only from this device straight to
/// Google and never to a luma server.
class YoutubeCredentialStore {
  YoutubeCredentialStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_youtube.key';
  static const _dataFileName = 'luma_youtube_account.dat';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static YoutubeCredentialStore? _instance;

  static Future<YoutubeCredentialStore> load() async {
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
    return _instance = YoutubeCredentialStore._(key, dir.path);
  }

  File get _dataFile =>
      File('$_dirPath${Platform.pathSeparator}$_dataFileName');

  Future<YoutubeCredentials?> read() async {
    final file = _dataFile;
    if (!await file.exists()) return null;
    final stored = (await file.readAsString()).trim();
    if (stored.isEmpty) return null;
    final decrypted = _decrypt(stored);
    if (decrypted.isEmpty) return null;
    try {
      final json = jsonDecode(decrypted);
      if (json is! Map) return null;
      final clientId = json['clientId'];
      final clientSecret = json['clientSecret'];
      final accessToken = json['accessToken'];
      final refreshToken = json['refreshToken'];
      final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
      if (clientId is! String ||
          clientSecret is! String ||
          accessToken is! String ||
          refreshToken is! String ||
          expiresAt == null) {
        return null;
      }
      if (clientId.isEmpty ||
          clientSecret.isEmpty ||
          accessToken.isEmpty ||
          refreshToken.isEmpty) {
        return null;
      }
      return YoutubeCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        channelId: json['channelId'] as String?,
        channelTitle: json['channelTitle'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(YoutubeCredentials credentials) async {
    final payload = jsonEncode({
      'clientId': credentials.clientId,
      'clientSecret': credentials.clientSecret,
      'accessToken': credentials.accessToken,
      'refreshToken': credentials.refreshToken,
      'expiresAt': credentials.expiresAt.toIso8601String(),
      if (credentials.channelId != null) 'channelId': credentials.channelId,
      if (credentials.channelTitle != null)
        'channelTitle': credentials.channelTitle,
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

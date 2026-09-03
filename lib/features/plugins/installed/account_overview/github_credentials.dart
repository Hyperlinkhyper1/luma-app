import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Everything the plugin needs to talk to GitHub as the user, plus the
/// allowance figures it cannot always read back.
///
/// GitHub's billing API reports what has been *used* but does not always
/// report what is *included* — the legacy `settings/billing/actions`
/// endpoint has returned zeroed allowances for many personal accounts, and
/// the enhanced usage endpoint reports consumption only. Rather than baking
/// in a plan table that silently rots every time GitHub restructures its
/// plans, the allowances are the user's own numbers, read off their billing
/// page once. A meter with no denominator shows the raw usage instead of
/// inventing one.
class GithubCredentials {
  const GithubCredentials({
    required this.token,
    required this.login,
    this.copilotAllowance,
    this.storageAllowanceGb,
    this.minutesAllowance,
  });

  /// A personal access token. Classic tokens want `repo`, `read:user` and
  /// `user` (the last one is what unlocks the billing endpoints);
  /// fine-grained tokens want the equivalent read-only permissions plus
  /// "Plan".
  final String token;

  /// The account the token belongs to. Resolved from `/user` on connect
  /// rather than typed, so it can never disagree with the token.
  final String login;

  /// Monthly Copilot allowance, in whichever unit GitHub currently bills
  /// (AI credits, premium requests). Null means "do not draw a bar".
  final double? copilotAllowance;

  /// Included Packages/Actions storage, in GB.
  final double? storageAllowanceGb;

  /// Included Actions compute, in minutes.
  final double? minutesAllowance;

  bool get isComplete => token.isNotEmpty && login.isNotEmpty;

  /// The token with everything but its last four characters masked, so the
  /// UI can show that one is saved without putting it back on screen.
  String get maskedToken {
    if (token.length <= 4) return '•' * token.length;
    return '${'•' * (token.length - 4)}${token.substring(token.length - 4)}';
  }

  GithubCredentials copyWith({
    String? token,
    String? login,
    double? copilotAllowance,
    double? storageAllowanceGb,
    double? minutesAllowance,
    bool clearAllowances = false,
  }) =>
      GithubCredentials(
        token: token ?? this.token,
        login: login ?? this.login,
        copilotAllowance: clearAllowances
            ? null
            : (copilotAllowance ?? this.copilotAllowance),
        storageAllowanceGb: clearAllowances
            ? null
            : (storageAllowanceGb ?? this.storageAllowanceGb),
        minutesAllowance: clearAllowances
            ? null
            : (minutesAllowance ?? this.minutesAllowance),
      );
}

/// Stores the GitHub token locally, encrypted at rest.
///
/// Mirrors `SteamCredentialStore` and `AiKeyStore` — the same
/// encrypt-then-MAC HMAC-SHA256 stream cipher, with its own key file since
/// it is an unrelated credential. This is obfuscation-at-rest rather than a
/// hardware-backed secret store, the same tradeoff the other key stores
/// make: it is the user's own revocable token, sent only from this device
/// straight to api.github.com and never to a luma server.
class GithubCredentialStore {
  GithubCredentialStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_github.key';
  static const _dataFileName = 'luma_github_account.dat';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static GithubCredentialStore? _instance;

  static Future<GithubCredentialStore> load() async {
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
    return _instance = GithubCredentialStore._(key, dir.path);
  }

  File get _dataFile => File('$_dirPath${Platform.pathSeparator}$_dataFileName');

  Future<GithubCredentials?> read() async {
    final file = _dataFile;
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    if (token.isEmpty) return null;
    final decrypted = _decrypt(token);
    if (decrypted.isEmpty) return null;
    try {
      final json = jsonDecode(decrypted);
      if (json is! Map) return null;
      final accessToken = json['token'];
      final login = json['login'];
      if (accessToken is! String || login is! String) return null;
      if (accessToken.isEmpty || login.isEmpty) return null;
      return GithubCredentials(
        token: accessToken,
        login: login,
        copilotAllowance: (json['copilotAllowance'] as num?)?.toDouble(),
        storageAllowanceGb: (json['storageAllowanceGb'] as num?)?.toDouble(),
        minutesAllowance: (json['minutesAllowance'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GithubCredentials credentials) async {
    final payload = jsonEncode({
      'token': credentials.token,
      'login': credentials.login,
      if (credentials.copilotAllowance != null)
        'copilotAllowance': credentials.copilotAllowance,
      if (credentials.storageAllowanceGb != null)
        'storageAllowanceGb': credentials.storageAllowanceGb,
      if (credentials.minutesAllowance != null)
        'minutesAllowance': credentials.minutesAllowance,
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

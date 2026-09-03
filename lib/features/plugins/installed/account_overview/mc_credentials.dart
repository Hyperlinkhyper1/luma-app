import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// What MC Content needs to identify the user on each platform.
///
/// Every field is optional on purpose: Modrinth and Planet Minecraft need
/// only a username, so the tab is useful before any key is pasted, and
/// CurseForge sits in a "needs a key" state rather than blocking the rest.
class McCredentials {
  const McCredentials({
    this.curseforgeApiKey,
    this.curseforgeAuthorId,
    this.curseforgeProjectIds = const [],
    this.modrinthUsername,
    this.modrinthToken,
    this.pmcUsername,
  });

  /// An eternal API key from the CurseForge for Studios console. Required —
  /// CurseForge serves nothing at all without one.
  final String? curseforgeApiKey;

  /// The numeric author id. CurseForge's search filters by id and offers no
  /// username lookup, so this cannot be derived from a name.
  final String? curseforgeAuthorId;

  /// Individually tracked CurseForge projects, for people who cannot find
  /// their author id — the same "add what you care about" escape hatch the
  /// Steam price tracker offers.
  final List<String> curseforgeProjectIds;

  final String? modrinthUsername;

  /// Optional Modrinth personal access token. Only needed for the analytics
  /// endpoint that backfills real download history; totals are public.
  final String? modrinthToken;

  final String? pmcUsername;

  bool get hasCurseforge =>
      (curseforgeApiKey ?? '').isNotEmpty &&
      ((curseforgeAuthorId ?? '').isNotEmpty || curseforgeProjectIds.isNotEmpty);

  bool get hasModrinth => (modrinthUsername ?? '').isNotEmpty;

  bool get hasPmc => (pmcUsername ?? '').isNotEmpty;

  bool get hasAny => hasCurseforge || hasModrinth || hasPmc;

  /// True when a key was given but there is still nothing to look up with it.
  bool get curseforgeNeedsTarget =>
      (curseforgeApiKey ?? '').isNotEmpty && !hasCurseforge;

  String get maskedCurseforgeKey {
    final key = curseforgeApiKey ?? '';
    if (key.length <= 4) return '•' * key.length;
    return '${'•' * (key.length - 4)}${key.substring(key.length - 4)}';
  }

  McCredentials copyWith({
    String? curseforgeApiKey,
    String? curseforgeAuthorId,
    List<String>? curseforgeProjectIds,
    String? modrinthUsername,
    String? modrinthToken,
    String? pmcUsername,
  }) =>
      McCredentials(
        curseforgeApiKey: curseforgeApiKey ?? this.curseforgeApiKey,
        curseforgeAuthorId: curseforgeAuthorId ?? this.curseforgeAuthorId,
        curseforgeProjectIds: curseforgeProjectIds ?? this.curseforgeProjectIds,
        modrinthUsername: modrinthUsername ?? this.modrinthUsername,
        modrinthToken: modrinthToken ?? this.modrinthToken,
        pmcUsername: pmcUsername ?? this.pmcUsername,
      );

  Map<String, dynamic> toJson() => {
        if ((curseforgeApiKey ?? '').isNotEmpty)
          'curseforgeApiKey': curseforgeApiKey,
        if ((curseforgeAuthorId ?? '').isNotEmpty)
          'curseforgeAuthorId': curseforgeAuthorId,
        if (curseforgeProjectIds.isNotEmpty)
          'curseforgeProjectIds': curseforgeProjectIds,
        if ((modrinthUsername ?? '').isNotEmpty)
          'modrinthUsername': modrinthUsername,
        if ((modrinthToken ?? '').isNotEmpty) 'modrinthToken': modrinthToken,
        if ((pmcUsername ?? '').isNotEmpty) 'pmcUsername': pmcUsername,
      };

  factory McCredentials.fromJson(Map<String, dynamic> j) => McCredentials(
        curseforgeApiKey: j['curseforgeApiKey'] as String?,
        curseforgeAuthorId: j['curseforgeAuthorId'] as String?,
        curseforgeProjectIds: [
          for (final id in (j['curseforgeProjectIds'] as List<dynamic>? ?? []))
            id.toString(),
        ],
        modrinthUsername: j['modrinthUsername'] as String?,
        modrinthToken: j['modrinthToken'] as String?,
        pmcUsername: j['pmcUsername'] as String?,
      );
}

/// Stores the MC Content credentials locally, encrypted at rest.
///
/// Same encrypt-then-MAC HMAC-SHA256 stream cipher as the GitHub and Steam
/// key stores, with its own key file. The CurseForge key and Modrinth token
/// are the user's own revocable credentials and go only to their respective
/// APIs — never to a luma server.
class McCredentialStore {
  McCredentialStore._(this._key, this._dirPath);

  final Uint8List _key;
  final String _dirPath;

  static const _keyFileName = 'luma_mc.key';
  static const _dataFileName = 'luma_mc_accounts.dat';
  static const _nonceLength = 12;
  static const _macLength = 16;

  static McCredentialStore? _instance;

  static Future<McCredentialStore> load() async {
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
    return _instance = McCredentialStore._(key, dir.path);
  }

  File get _dataFile => File('$_dirPath${Platform.pathSeparator}$_dataFileName');

  Future<McCredentials?> read() async {
    final file = _dataFile;
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    if (token.isEmpty) return null;
    final decrypted = _decrypt(token);
    if (decrypted.isEmpty) return null;
    try {
      final json = jsonDecode(decrypted);
      if (json is! Map<String, dynamic>) return null;
      return McCredentials.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(McCredentials credentials) async {
    await _dataFile.writeAsString(
      _encrypt(jsonEncode(credentials.toJson())),
      flush: true,
    );
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
      if (!_constantTimeEquals(mac, _mac(nonce, cipher))) return '';
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

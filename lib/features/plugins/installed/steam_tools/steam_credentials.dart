import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../security/encrypted_credential_file.dart';
import '../../../../security/secure_secret_store.dart';

/// The pair that identifies a Steam account to the Web API.
///
/// This is the only credential the plugin ever asks for. Price history's
/// IsThereAnyDeal key lives on the luma server instead (see ItadApi), so
/// there is nothing to store for it here.
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

/// Stores Steam credentials with an OS-protected encryption key.
class SteamCredentialStore {
  SteamCredentialStore._(this._file);

  final EncryptedCredentialFile _file;
  static Future<SteamCredentialStore>? _instance;

  static Future<SteamCredentialStore> load({
    Directory? storageDir,
    SecureSecretStore? secretStore,
  }) {
    Future<SteamCredentialStore> open() async {
      final dir = storageDir ?? await getApplicationSupportDirectory();
      final file = await EncryptedCredentialFile.load(
        directory: dir,
        keyName: 'luma_steam.key',
        fileName: 'luma_steam_account.dat',
        context: 'luma-steam-credentials',
        secretStore: secretStore,
        recoverCorruptLegacy: true,
      );
      return SteamCredentialStore._(file);
    }

    if (storageDir != null || secretStore != null) return open();
    return _instance ??= open().catchError((Object error, StackTrace stack) {
      _instance = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<SteamCredentials?> read() async {
    final payload = await _file.read();
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload);
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

  Future<void> save(SteamCredentials credentials) => _file.write(
    jsonEncode({'apiKey': credentials.apiKey, 'steamId': credentials.steamId}),
  );

  Future<void> clear() => _file.clear();
}

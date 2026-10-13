import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../security/encrypted_credential_file.dart';
import '../../../../security/secure_secret_store.dart';

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
      ((curseforgeAuthorId ?? '').isNotEmpty ||
          curseforgeProjectIds.isNotEmpty);

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
  }) => McCredentials(
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

/// Stores MC Content credentials with an OS-protected encryption key.
class McCredentialStore {
  McCredentialStore._(this._file);

  final EncryptedCredentialFile _file;
  static Future<McCredentialStore>? _instance;

  static Future<McCredentialStore> load({
    Directory? storageDir,
    SecureSecretStore? secretStore,
  }) {
    Future<McCredentialStore> open() async {
      final dir = storageDir ?? await getApplicationSupportDirectory();
      final file = await EncryptedCredentialFile.load(
        directory: dir,
        keyName: 'luma_mc.key',
        fileName: 'luma_mc_accounts.dat',
        context: 'luma-mc-content-credentials',
        secretStore: secretStore,
        recoverCorruptLegacy: true,
      );
      return McCredentialStore._(file);
    }

    if (storageDir != null || secretStore != null) return open();
    return _instance ??= open().catchError((Object error, StackTrace stack) {
      _instance = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<McCredentials?> read() async {
    final payload = await _file.read();
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) return null;
      return McCredentials.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(McCredentials credentials) =>
      _file.write(jsonEncode(credentials.toJson()));

  Future<void> clear() => _file.clear();
}

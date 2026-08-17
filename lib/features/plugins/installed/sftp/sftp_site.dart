import 'dart:math';

/// How a site proves who it is to the server.
enum SftpAuthMode {
  /// Username + password, typed or remembered.
  password,

  /// An OpenSSH / PEM private key file, optionally passphrase-protected.
  key,
}

/// One saved server, as shown in the Site Manager. The secret (password, or
/// the private key's passphrase) is never held here in the clear — it lives
/// in [secretToken] as a ciphertext produced by `SftpSecretCrypto`, and only
/// when the user ticked "save password" for this site.
class SftpSite {
  const SftpSite({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.authMode = SftpAuthMode.password,
    this.keyPath,
    this.saveSecret = false,
    this.secretToken,
    this.remoteDirectory = '',
    this.localDirectory = '',
    this.lastUsed,
  });

  final String id;

  /// Display name in the Site Manager. Falls back to the host when blank.
  final String name;

  final String host;
  final int port;
  final String username;

  final SftpAuthMode authMode;

  /// Absolute path to the private key file when [authMode] is
  /// [SftpAuthMode.key].
  final String? keyPath;

  /// Whether the password (or key passphrase) may be remembered for this
  /// site. When false, [secretToken] is always null and the user is asked
  /// on every connect.
  final bool saveSecret;

  /// Encrypted password / passphrase. Null when nothing is remembered.
  final String? secretToken;

  /// Directory to open on the server after connecting. Empty means whatever
  /// the server drops us in (usually the home directory).
  final String remoteDirectory;

  /// Directory to open in the local pane. Empty means the platform default.
  final String localDirectory;

  final DateTime? lastUsed;

  /// What the Site Manager shows as the site's title.
  String get displayName => name.trim().isEmpty ? host : name.trim();

  /// `user@host:port`, the subtitle under [displayName].
  String get endpointLabel =>
      '${username.isEmpty ? '' : '$username@'}$host${port == 22 ? '' : ':$port'}';

  SftpSite copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    SftpAuthMode? authMode,
    String? keyPath,
    bool? saveSecret,
    String? secretToken,
    bool clearSecretToken = false,
    String? remoteDirectory,
    String? localDirectory,
    DateTime? lastUsed,
  }) =>
      SftpSite(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        authMode: authMode ?? this.authMode,
        keyPath: keyPath ?? this.keyPath,
        saveSecret: saveSecret ?? this.saveSecret,
        secretToken: clearSecretToken ? null : (secretToken ?? this.secretToken),
        remoteDirectory: remoteDirectory ?? this.remoteDirectory,
        localDirectory: localDirectory ?? this.localDirectory,
        lastUsed: lastUsed ?? this.lastUsed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'authMode': authMode.name,
        'keyPath': keyPath,
        'saveSecret': saveSecret,
        'secret': secretToken,
        'remoteDirectory': remoteDirectory,
        'localDirectory': localDirectory,
        'lastUsed': lastUsed?.toIso8601String(),
      };

  factory SftpSite.fromJson(Map<String, dynamic> json) => SftpSite(
        id: json['id']?.toString() ?? newSftpSiteId(),
        name: json['name']?.toString() ?? '',
        host: json['host']?.toString() ?? '',
        port: (json['port'] as num?)?.toInt() ?? 22,
        username: json['username']?.toString() ?? '',
        authMode: SftpAuthMode.values.firstWhere(
          (m) => m.name == json['authMode'],
          orElse: () => SftpAuthMode.password,
        ),
        keyPath: json['keyPath']?.toString(),
        saveSecret: json['saveSecret'] == true,
        secretToken: json['secret']?.toString(),
        remoteDirectory: json['remoteDirectory']?.toString() ?? '',
        localDirectory: json['localDirectory']?.toString() ?? '',
        lastUsed: DateTime.tryParse(json['lastUsed']?.toString() ?? ''),
      );
}

final _rand = Random();

/// Collision-resistant enough for a list a person types by hand.
String newSftpSiteId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_rand.nextInt(0x7fffffff).toRadixString(36)}';

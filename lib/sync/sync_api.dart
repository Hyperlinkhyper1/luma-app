import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The one luma sync server. Fixed so no UI ever needs to ask for it.
const kDefaultSyncServerUrl = 'https://sync.luma-app.cc';

/// Metadata the server keeps for one synced collection.
class RemoteCollectionMeta {
  const RemoteCollectionMeta({
    required this.name,
    required this.version,
    required this.size,
    required this.payloadSavedAt,
    required this.updatedAt,
  });

  final String name;
  final int version;
  final int size;
  final DateTime payloadSavedAt;
  final DateTime updatedAt;

  factory RemoteCollectionMeta.fromJson(Map<String, dynamic> j) =>
      RemoteCollectionMeta(
        name: j['name'] as String,
        version: j['version'] as int,
        size: j['size'] as int,
        payloadSavedAt: DateTime.fromMillisecondsSinceEpoch(
            j['payloadSavedAtMs'] as int? ?? 0),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(j['updatedAtMs'] as int? ?? 0),
      );
}

/// The /account response: identity, storage usage and per-collection state.
class RemoteAccount {
  const RemoteAccount({
    required this.email,
    required this.usedBytes,
    required this.quotaBytes,
    required this.collections,
  });

  final String email;
  final int usedBytes;
  final int quotaBytes;
  final Map<String, RemoteCollectionMeta> collections;

  factory RemoteAccount.fromJson(Map<String, dynamic> j) {
    final collections = <String, RemoteCollectionMeta>{};
    for (final raw in (j['collections'] as List<dynamic>? ?? const [])) {
      final meta = RemoteCollectionMeta.fromJson(raw as Map<String, dynamic>);
      collections[meta.name] = meta;
    }
    return RemoteAccount(
      email: j['email'] as String? ?? '',
      usedBytes: j['usedBytes'] as int? ?? 0,
      quotaBytes: j['quotaBytes'] as int? ?? 0,
      collections: collections,
    );
  }
}

class RemoteBlob {
  const RemoteBlob({
    required this.bytes,
    required this.version,
    required this.payloadSavedAt,
  });

  final Uint8List bytes;
  final int version;
  final DateTime payloadSavedAt;
}

/// Raised for every non-successful server response, with the machine-readable
/// [code] the server includes (e.g. `version_conflict`, `quota_exceeded`).
class SyncApiException implements Exception {
  const SyncApiException(this.status, this.code, this.message, {this.extra});

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic>? extra;

  bool get isConflict => code == 'version_conflict';
  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

/// Thin typed HTTP client for the luma sync server.
class SyncApi {
  SyncApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _client;

  static const _jsonTimeout = Duration(seconds: 30);
  static const _blobTimeout = Duration(minutes: 5);

  /// Trims whitespace/trailing slashes so paths join predictably.
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Sync servers must use HTTPS; plain HTTP is only tolerated for
  /// localhost and private-LAN addresses (home server setups).
  static String? validateServerUrl(String raw) {
    final uri = Uri.tryParse(normalizeBaseUrl(raw));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter the full server address, e.g. https://sync.example.com';
    }
    if (uri.scheme == 'https') return null;
    if (uri.scheme != 'http') return 'Only http(s) addresses are supported.';
    final host = uri.host;
    final isPrivate = host == 'localhost' ||
        host.endsWith('.local') ||
        RegExp(r'^127\.').hasMatch(host) ||
        RegExp(r'^10\.').hasMatch(host) ||
        RegExp(r'^192\.168\.').hasMatch(host) ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
    return isPrivate
        ? null
        : 'Plain http is only allowed for local/home-network servers. '
            'Use https:// for servers on the internet.';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  Map<String, String> get _authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  // ---- Auth ----------------------------------------------------------------

  Future<({Uint8List kdfSalt, int kdfIterations})> authParams(
      String email) async {
    final body = await _postJson('/auth/params', {'email': email});
    return (
      kdfSalt: Uint8List.fromList(base64Decode(body['kdfSalt'] as String)),
      kdfIterations: body['kdfIterations'] as int,
    );
  }

  /// Registers a new account. The server either signs the account in
  /// immediately (`token` set) or, when it requires email verification
  /// first, comes back with no token and a human-readable [message] instead
  /// — in that case [pendingVerification] is true and the caller must not
  /// treat this as a successful sign-in.
  Future<({String? token, bool pendingVerification, String? message})>
      register({
    required String email,
    required Uint8List authKey,
    required Uint8List kdfSalt,
    required int kdfIterations,
  }) async {
    final body = await _postJson('/auth/register', {
      'email': email,
      'authKey': base64Encode(authKey),
      'kdfSalt': base64Encode(kdfSalt),
      'kdfIterations': kdfIterations,
    });
    final token = body['token'] as String?;
    if (token == null) {
      return (
        token: null,
        pendingVerification: true,
        message: body['message'] as String? ??
            'Check your email to verify your account before signing in.',
      );
    }
    return (token: token, pendingVerification: false, message: null);
  }

  Future<String> login(
      {required String email, required Uint8List authKey}) async {
    final body = await _postJson('/auth/login', {
      'email': email,
      'authKey': base64Encode(authKey),
    });
    return body['token'] as String;
  }

  Future<void> logout() async {
    await _postJson('/auth/logout', const {});
  }

  Future<void> changePassword({
    required Uint8List currentAuthKey,
    required Uint8List newAuthKey,
    required Uint8List newKdfSalt,
    required int newKdfIterations,
  }) async {
    await _postJson('/auth/change', {
      'currentAuthKey': base64Encode(currentAuthKey),
      'newAuthKey': base64Encode(newAuthKey),
      'newKdfSalt': base64Encode(newKdfSalt),
      'newKdfIterations': newKdfIterations,
    });
  }

  Future<void> deleteAccount({required Uint8List authKey}) async {
    await _postJson('/account/delete', {'authKey': base64Encode(authKey)});
  }

  // ---- Account & blobs -------------------------------------------------------

  Future<RemoteAccount> account() async {
    final response = await _client
        .get(_uri('/account'), headers: _authHeaders)
        .timeout(_jsonTimeout);
    return RemoteAccount.fromJson(_decodeOrThrow(response));
  }

  /// Returns null when the server has no snapshot for this collection.
  Future<RemoteBlob?> getBlob(String collection) async {
    final response = await _client
        .get(_uri('/sync/$collection'), headers: _authHeaders)
        .timeout(_blobTimeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }
    return RemoteBlob(
      bytes: response.bodyBytes,
      version: int.tryParse(response.headers['x-version'] ?? '') ?? 0,
      payloadSavedAt: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(response.headers['x-payload-saved-at'] ?? '') ?? 0),
    );
  }

  /// Uploads a snapshot. [baseVersion] is the version this upload was based
  /// on (0 = none); the server rejects the write with `version_conflict` if
  /// someone else uploaded in between.
  Future<int> putBlob(
    String collection,
    Uint8List bytes, {
    required int baseVersion,
    required DateTime payloadSavedAt,
  }) async {
    final response = await _client
        .put(
          _uri('/sync/$collection'),
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/octet-stream',
            'X-Base-Version': '$baseVersion',
            'X-Payload-Saved-At': '${payloadSavedAt.millisecondsSinceEpoch}',
          },
          body: bytes,
        )
        .timeout(_blobTimeout);
    final body = _decodeOrThrow(response);
    return body['version'] as int;
  }

  Future<void> deleteBlob(String collection) async {
    final response = await _client
        .delete(_uri('/sync/$collection'), headers: _authHeaders)
        .timeout(_jsonTimeout);
    _decodeOrThrow(response);
  }

  // ---- Internals -------------------------------------------------------------

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _uri(path),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_jsonTimeout);
    return _decodeOrThrow(response);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const {};
    }
    throw _errorFrom(response, decoded: decoded);
  }

  SyncApiException _errorFrom(http.Response response,
      {Map<String, dynamic>? decoded}) {
    decoded ??= () {
      try {
        final raw = jsonDecode(utf8.decode(response.bodyBytes));
        return raw is Map<String, dynamic> ? raw : null;
      } catch (_) {
        return null;
      }
    }();
    return SyncApiException(
      response.statusCode,
      decoded?['error'] as String? ?? 'http_${response.statusCode}',
      decoded?['message'] as String? ??
          'Server error (${response.statusCode}).',
      extra: decoded,
    );
  }

  void close() => _client.close();
}

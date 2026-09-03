import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'server_access.dart';

/// The one luma sync server. Fixed so no UI ever needs to ask for it.
const kDefaultSyncServerUrl = 'https://sync.luma-app.cc';

/// How the server approves a newly created account — mirrors `ApprovalMode`
/// in server/lib/api.dart, and comes back on the register response.
enum ServerApprovalMode {
  /// The operator approves each account by hand from the admin dashboard.
  /// Nothing is emailed, so there is nothing for the user to resend.
  manual,

  /// The user approves their own account from a link emailed to them.
  email,

  /// No approval step at all — registering signs you straight in.
  open;

  static ServerApprovalMode parse(String? raw) => switch (raw) {
        'email' => ServerApprovalMode.email,
        'open' => ServerApprovalMode.open,
        _ => ServerApprovalMode.manual,
      };
}

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
    this.planId,
    this.status = 'active',
    this.linkedProviders = const [],
  });

  final String email;
  final int usedBytes;
  final int quotaBytes;
  final Map<String, RemoteCollectionMeta> collections;

  /// The account's approval state on the server: `active` once it has been
  /// approved (email verified, or approved from the admin dashboard),
  /// `pending` while it is still waiting. Servers older than this field omit
  /// it; they only ever hand a token to an approved account, so treating a
  /// missing value as `active` matches what the token already proves.
  final String status;

  /// Whether the server considers this account approved to use it.
  bool get approved => status == 'active';

  /// The plan tier the server has on file for this account — granted by an
  /// admin via the dashboard (see Api._adminSetPlan). Null when the server
  /// is older than the planId field and didn't include it.
  final String? planId;

  /// Provider ids ('google', 'github') that can sign in to this account
  /// besides the password. Empty until the first such sign-in links one.
  final List<String> linkedProviders;

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
      planId: j['planId'] as String?,
      status: j['status'] as String? ?? 'active',
      linkedProviders: (j['linkedProviders'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      collections: collections,
    );
  }
}

/// A sign-in provider this server is configured for, as returned by
/// GET /auth/oauth/providers.
class OAuthProviderInfo {
  const OAuthProviderInfo({required this.id, required this.name});

  /// 'google' or 'github'.
  final String id;

  /// Display name for the button ("Continue with Google").
  final String name;

  factory OAuthProviderInfo.fromJson(Map<String, dynamic> j) =>
      OAuthProviderInfo(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
      );
}

/// Where a browser sign-in has got to.
class OAuthPollResult {
  const OAuthPollResult({
    required this.status,
    this.email,
    this.displayName,
    this.existingAccount = false,
    this.kdfSalt,
    this.kdfIterations,
    this.message,
  });

  /// `pending` while the user is still in their browser, `ready` once the
  /// provider has vouched for [email], `error` when it went wrong or the
  /// attempt timed out.
  final String status;

  bool get isPending => status == 'pending';
  bool get isReady => status == 'ready';
  bool get isError => status == 'error';

  /// The provider-verified address. Only set once [isReady].
  final String? email;
  final String? displayName;

  /// Whether that address already has an account here — which is what
  /// decides between asking for the existing passphrase and having the user
  /// choose a new one. True for an account originally made with an email and
  /// password too: matching addresses is exactly what links the two.
  final bool existingAccount;

  /// The existing account's KDF parameters, so the passphrase derives the
  /// same keys it would on a password sign-in. Null for a new account.
  final Uint8List? kdfSalt;
  final int? kdfIterations;

  /// Set when [isError]; already user-facing.
  final String? message;

  factory OAuthPollResult.fromJson(Map<String, dynamic> j) {
    final salt = j['kdfSalt'] as String?;
    return OAuthPollResult(
      status: j['status'] as String? ?? 'pending',
      email: j['email'] as String?,
      displayName: j['displayName'] as String?,
      existingAccount: j['existingAccount'] as bool? ?? false,
      kdfSalt: salt == null ? null : Uint8List.fromList(base64Decode(salt)),
      kdfIterations: j['kdfIterations'] as int?,
      message: j['message'] as String?,
    );
  }
}

/// One active cloud session, as returned by GET /auth/sessions.
class RemoteSession {
  const RemoteSession({
    required this.id,
    required this.deviceLabel,
    required this.createdAt,
    required this.expiresAt,
    required this.isCurrent,
  });

  final String id;
  final String? deviceLabel;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isCurrent;

  factory RemoteSession.fromJson(Map<String, dynamic> j) => RemoteSession(
        id: j['id'] as String,
        deviceLabel: j['deviceLabel'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            j['createdAtMs'] as int? ?? 0),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
            j['expiresAtMs'] as int? ?? 0),
        isCurrent: j['isCurrent'] as bool? ?? false,
      );
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

  /// The account exists and the token is valid, but the server has it
  /// waiting for approval — everything server-backed has to stop until it
  /// is approved.
  bool get isNotApproved => code == 'account_not_approved';

  @override
  String toString() => message;
}

/// Thin typed HTTP client for the luma sync server.
///
/// Every request goes through a [GatedServerClient], so while this device
/// has no approved account the only calls that can leave it are the account
/// handshake ones ([ServerAccessGate.accountSetupPaths]) — everything else
/// throws [ServerAccessDeniedException] before a socket is opened.
class SyncApi {
  SyncApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = normalizeBaseUrl(baseUrl),
        _client = GatedServerClient(
          inner: client,
          allowBeforeApproval: ServerAccessGate.accountSetupPaths,
        );

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
  /// immediately (`token` set) or, when the account has to be approved
  /// first, comes back with no token and a human-readable [message] instead
  /// — in that case [pendingApproval] is true and the caller must not treat
  /// this as a successful sign-in.
  ///
  /// [approvalMode] says who does the approving: `manual` (the operator, from
  /// the admin dashboard — the default) or `email` (the user, by opening a
  /// link). It decides whether offering to resend anything makes sense.
  Future<
      ({
        String? token,
        bool pendingApproval,
        String? message,
        ServerApprovalMode approvalMode
      })> register({
    required String email,
    required Uint8List authKey,
    required Uint8List kdfSalt,
    required int kdfIterations,
    String? deviceLabel,
  }) async {
    final body = await _postJson('/auth/register', {
      'email': email,
      'authKey': base64Encode(authKey),
      'kdfSalt': base64Encode(kdfSalt),
      'kdfIterations': kdfIterations,
      if (deviceLabel != null) 'deviceLabel': deviceLabel,
    });
    final mode = ServerApprovalMode.parse(body['approval'] as String?);
    final token = body['token'] as String?;
    if (token == null) {
      return (
        token: null,
        pendingApproval: true,
        approvalMode: mode,
        message: body['message'] as String? ??
            'Your account has to be approved before you can sign in.',
      );
    }
    return (
      token: token,
      pendingApproval: false,
      approvalMode: mode,
      message: null,
    );
  }

  Future<String> login(
      {required String email,
      required Uint8List authKey,
      String? deviceLabel}) async {
    final body = await _postJson('/auth/login', {
      'email': email,
      'authKey': base64Encode(authKey),
      if (deviceLabel != null) 'deviceLabel': deviceLabel,
    });
    return body['token'] as String;
  }

  // ---- Sign in with Google / GitHub ---------------------------------------

  /// Which providers this server has credentials for. An older server has no
  /// such endpoint and a self-hosted one may have configured none, so the
  /// empty list is the normal answer, not an error — callers hide the
  /// buttons and carry on with email and password.
  Future<List<OAuthProviderInfo>> oauthProviders() async {
    final response = await _client
        .get(_uri('/auth/oauth/providers'))
        .timeout(_jsonTimeout);
    if (response.statusCode == 404) return const [];
    final body = _decodeOrThrow(response);
    return (body['providers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OAuthProviderInfo.fromJson)
        .toList();
  }

  /// Opens a browser sign-in. Returns the provider URL to send the user to
  /// and the private ticket every later step is keyed by.
  Future<({String ticket, String authUrl})> oauthStart(
      String providerId) async {
    final body = await _postJson('/auth/oauth/start', {'provider': providerId});
    return (
      ticket: body['ticket'] as String,
      authUrl: body['authUrl'] as String,
    );
  }

  /// Asks whether the browser half has finished. Keeps returning
  /// [OAuthPollResult.pending] until the user comes back from the provider.
  Future<OAuthPollResult> oauthPoll(String ticket) async {
    final body = await _postJson('/auth/oauth/poll', {'ticket': ticket});
    return OAuthPollResult.fromJson(body);
  }

  /// Finishes a browser sign-in with the key derived from the passphrase.
  ///
  /// [kdfSalt] and [kdfIterations] are only read when the account is new —
  /// they become its KDF parameters. For an account that already exists the
  /// server checks [authKey] against what it has on file, so a wrong
  /// passphrase fails here exactly as it would on a password sign-in.
  Future<
      ({
        String? token,
        bool pendingApproval,
        String? message,
        String? email
      })> oauthComplete({
    required String ticket,
    required Uint8List authKey,
    required Uint8List kdfSalt,
    required int kdfIterations,
    String? deviceLabel,
  }) async {
    final body = await _postJson('/auth/oauth/complete', {
      'ticket': ticket,
      'authKey': base64Encode(authKey),
      'kdfSalt': base64Encode(kdfSalt),
      'kdfIterations': kdfIterations,
      if (deviceLabel != null) 'deviceLabel': deviceLabel,
    });
    final token = body['token'] as String?;
    return (
      token: token,
      pendingApproval: token == null,
      email: body['email'] as String?,
      message: body['message'] as String?,
    );
  }

  /// Asks the server to send the approval (verification) mail again for an
  /// account that is still waiting. The response is deliberately generic —
  /// it never reveals whether the address has an account — so the returned
  /// message is safe to show as-is.
  Future<String> resendVerification(String email) async {
    final body = await _postJson('/auth/resend-verification', {'email': email});
    return body['message'] as String? ??
        'If that email has an account waiting for approval, we just sent a '
            'new link.';
  }

  Future<void> logout() async {
    await _postJson('/auth/logout', const {});
  }

  /// Lists every active session on this account (across all signed-in
  /// devices), newest first.
  Future<List<RemoteSession>> listSessions() async {
    final response = await _client
        .get(_uri('/auth/sessions'), headers: _authHeaders)
        .timeout(_jsonTimeout);
    final body = _decodeOrThrow(response);
    return (body['sessions'] as List<dynamic>? ?? const [])
        .map((j) => RemoteSession.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Revokes another device's session by [id] (from [RemoteSession.id]).
  /// The server rejects revoking the caller's own current session.
  Future<void> revokeSession(String id) async {
    await _postJson('/auth/sessions/$id/revoke', const {});
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

  // ---- AI ------------------------------------------------------------------

  /// Whether the operator has configured a shared Mistral ("Luma") API key
  /// (LUMA_MISTRAL_API_KEY) — status only. The key itself never reaches this
  /// client; chat requests instead go through POST /api/v1/ai/mistral/chat
  /// (see [MistralProxyClient]), which uses the key server-side.
  Future<bool> mistralKeyConfigured() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/v1/ai/mistral-key-configured'),
            headers: _authHeaders)
        .timeout(_jsonTimeout);
    final body = _decodeOrThrow(response);
    return body['configured'] == true;
  }

  /// Which shared AI keys the operator configured plus this account's usage
  /// — usage arrives only as percentages / message counts (the server keeps
  /// the raw token budgets to itself). See Api._aiStatus server-side.
  Future<Map<String, dynamic>> aiStatus() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/v1/ai/status'), headers: _authHeaders)
        .timeout(_jsonTimeout);
    return _decodeOrThrow(response);
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

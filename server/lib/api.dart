import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'chat_store.dart';
import 'family_store.dart';
import 'mail.dart';
import 'metrics.dart';
import 'rate_limit.dart';
import 'store.dart';
import 'util.dart';

/// Server configuration, read from environment variables (see .env.example).
class ServerConfig {
  ServerConfig({
    required this.port,
    required this.dataDir,
    required this.allowRegistration,
    required this.maxBlobBytes,
    required this.tokenTtl,
    required this.corsOrigin,
    required this.trustProxy,
    required this.verificationTtl,
    required this.requireEmailVerification,
    required this.adminKey,
    required this.mistralApiKey,
    required this.groceriesUrl,
    required this.groceriesAdminKey,
  });

  final int port;
  final String dataDir;
  final bool allowRegistration;
  final int maxBlobBytes;
  final Duration tokenTtl;
  final String corsOrigin;
  final bool trustProxy;

  /// How long an email-verification link stays valid.
  final Duration verificationTtl;

  /// Whether new accounts must verify their email before they can log in.
  /// On by default; can be disabled for closed/trusted deployments that
  /// don't want to configure SMTP.
  final bool requireEmailVerification;

  /// Shared secret for the /admin/* endpoints. When unset, the admin
  /// dashboard is disabled entirely rather than left open.
  final String? adminKey;

  bool get adminEnabled => adminKey != null && adminKey!.isNotEmpty;

  /// A Mistral ("Luma" in the app's UI) API key configured once by the
  /// operator, so individual users don't each have to paste their own — see
  /// Api._mistralKey. Optional; when unset, the app falls back to its
  /// existing per-device key entry.
  final String? mistralApiKey;

  bool get mistralKeyConfigured =>
      mistralApiKey != null && mistralApiKey!.isNotEmpty;

  /// Where the supermarket-db API lives (see supermarket-db/ at the repo
  /// root) and its admin key, so the dashboard's Control panel tab can
  /// trigger database syncs by proxy — the groceries key never reaches the
  /// browser, only this server's own admin key does.
  final String groceriesUrl;
  final String? groceriesAdminKey;

  bool get groceriesAdminEnabled =>
      groceriesAdminKey != null && groceriesAdminKey!.isNotEmpty;

  /// Whether new accounts may be created. Open by default; set
  /// LUMA_ALLOW_REGISTRATION=false to close it (existing accounts keep working).
  bool get registrationEnabled => allowRegistration;

  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    int intOf(String key, int fallback) =>
        int.tryParse(env[key] ?? '') ?? fallback;
    return ServerConfig(
      port: intOf('LUMA_PORT', 8080),
      dataDir: env['LUMA_DATA_DIR'] ?? 'data',
      // Registration is open unless explicitly disabled.
      allowRegistration:
          (env['LUMA_ALLOW_REGISTRATION'] ?? 'true').toLowerCase() != 'false',
      // A single collection snapshot may not exceed this (protects disk/RAM).
      maxBlobBytes: intOf('LUMA_MAX_BLOB_BYTES', 256 * 1024 * 1024),
      tokenTtl: Duration(days: intOf('LUMA_TOKEN_TTL_DAYS', 90)),
      corsOrigin: env['LUMA_CORS_ORIGIN'] ?? '*',
      trustProxy: env['LUMA_TRUST_PROXY'] == 'true',
      verificationTtl:
          Duration(hours: intOf('LUMA_VERIFICATION_TTL_HOURS', 24)),
      requireEmailVerification:
          (env['LUMA_REQUIRE_EMAIL_VERIFICATION'] ?? 'true').toLowerCase() !=
              'false',
      adminKey: env['LUMA_ADMIN_KEY'],
      mistralApiKey: env['LUMA_MISTRAL_API_KEY'],
      groceriesUrl:
          env['LUMA_GROCERIES_URL'] ?? 'https://groceries.luma-app.cc',
      groceriesAdminKey: env['LUMA_GROCERIES_ADMIN_KEY'],
    );
  }
}

/// Iterations for the *server-side* hash of the client's auth key. The auth
/// key is already a 256-bit output of a slow client-side KDF, so this only
/// needs to make a leaked database non-trivially reusable, not resist
/// password guessing.
const int _serverHashIterations = 20000;

/// Default KDF params advertised for unknown emails so the params endpoint
/// looks identical for existing and non-existing accounts.
const int _defaultClientIterations = 200000;

const int _maxJsonBody = 64 * 1024;

class Api {
  Api(this.store, this.config, this.mailer, this.familyStore, this.chatStore)
      : _authLimiter = RateLimiter(
            maxRequests: 15, window: const Duration(minutes: 10)),
        _generalLimiter = RateLimiter(
            maxRequests: 300, window: const Duration(minutes: 1)),
        _resendLimiter = RateLimiter(
            maxRequests: 3, window: const Duration(minutes: 15));

  final Store store;
  final ServerConfig config;
  final Mailer mailer;
  final FamilyStore familyStore;
  final ChatStore chatStore;
  final RateLimiter _authLimiter;
  final RateLimiter _generalLimiter;

  /// Extra, per-email limit on top of [_authLimiter] so someone can't spam
  /// verification mail to one address from many IPs.
  final RateLimiter _resendLimiter;

  Handler get handler {
    final router = Router()
      ..get('/', _root)
      ..get('/health', _health)
      ..post('/api/v1/auth/params', _authParams)
      ..post('/api/v1/auth/register', _register)
      ..get('/api/v1/auth/verify', _verify)
      ..post('/api/v1/auth/resend-verification', _resendVerification)
      ..post('/api/v1/auth/login', _login)
      ..post('/api/v1/auth/logout', _requireAuth(_logout))
      ..post('/api/v1/auth/change', _requireAuth(_changePassword))
      ..get('/api/v1/account', _requireAuth(_accountInfo))
      ..post('/api/v1/account/delete', _requireAuth(_deleteAccount))
      ..get('/api/v1/ai/mistral-key-configured', _requireAuth(_mistralKeyStatus))
      ..post('/api/v1/ai/mistral/chat', _requireAuth(_mistralChatProxy))
      ..get('/api/v1/sync/<collection>', _requireAuth(_getBlob))
      ..put('/api/v1/sync/<collection>', _requireAuth(_putBlob))
      ..delete('/api/v1/sync/<collection>', _requireAuth(_deleteBlobHandler))
      ..post('/api/v1/family', _requireAuth(_createFamily))
      ..get('/api/v1/family', _requireAuth(_getMyFamily))
      ..post('/api/v1/family/<id>/invite', _requireAuth(_inviteFamilyMember))
      ..get('/api/v1/family/invites', _requireAuth(_listMyInvites))
      ..post('/api/v1/family/invites/<inviteId>/accept',
          _requireAuth(_acceptFamilyInvite))
      ..post('/api/v1/family/invites/<inviteId>/decline',
          _requireAuth(_declineFamilyInvite))
      ..post('/api/v1/family/<id>/members/<userId>/remove',
          _requireAuth(_removeFamilyMember))
      ..post('/api/v1/family/<id>/delete', _requireAuth(_deleteFamily))
      ..post('/api/v1/family/<id>/events', _requireAuth(_addSharedEvent))
      ..get('/api/v1/family/<id>/events', _requireAuth(_listSharedEvents))
      ..put('/api/v1/family/<id>/events/<eventId>',
          _requireAuth(_updateSharedEvent))
      ..delete('/api/v1/family/<id>/events/<eventId>',
          _requireAuth(_deleteSharedEvent))
      ..put('/api/v1/chat/key', _requireAuth(_putChatKey))
      ..get('/api/v1/chat/key/<userId>', _requireAuth(_getChatKey))
      ..post('/api/v1/chat/invite', _requireAuth(_sendChatInvite))
      ..get('/api/v1/chat/invites', _requireAuth(_listChatInvites))
      ..post('/api/v1/chat/invites/<inviteId>/accept',
          _requireAuth(_acceptChatInvite))
      ..post('/api/v1/chat/invites/<inviteId>/decline',
          _requireAuth(_declineChatInvite))
      ..get('/api/v1/chat/conversations', _requireAuth(_listChatConversations))
      ..get('/api/v1/chat/conversations/<id>/messages',
          _requireAuth(_listChatMessages))
      ..post('/api/v1/chat/conversations/<id>/messages',
          _requireAuth(_sendChatMessage))
      ..get('/admin', _requireAdmin(_adminDashboard))
      ..get('/admin/users', _requireAdmin(_adminUsers))
      ..get('/admin/stats', _requireAdmin(_adminStats))
      ..get('/admin/metrics', _requireAdmin(_adminMetrics))
      ..get('/admin/metrics/history', _requireAdmin(_adminMetricsHistory))
      ..get('/admin/activity', _requireAdmin(_adminActivity))
      ..post('/admin/verify', _requireAdmin(_adminVerifyUser))
      ..post('/admin/plan', _requireAdmin(_adminSetPlan))
      ..post('/admin/groceries/sync', _requireAdmin(_adminGroceriesSync))
      ..get('/admin/groceries/status', _requireAdmin(_adminGroceriesStatus))
      ..post('/admin/deploy', _requireAdmin(_adminDeploy))
      ..get('/admin/deploy/status', _requireAdmin(_adminDeployStatus));

    return const Pipeline()
        .addMiddleware(_recover)
        .addMiddleware(_cors)
        .addMiddleware(_rateLimit)
        .addHandler(router.call);
  }

  // ---- Middleware ---------------------------------------------------------

  /// Turns unexpected exceptions into a clean 500 without leaking internals.
  Handler _recover(Handler inner) => (request) async {
        try {
          return await inner(request);
        } on FormatException {
          return _error(400, 'bad_request', 'Malformed request.');
        } catch (e, st) {
          stderr.writeln('[luma] unhandled error: $e\n$st');
          return _error(500, 'internal', 'Internal server error.');
        }
      };

  Handler _cors(Handler inner) => (request) async {
        final headers = {
          'Access-Control-Allow-Origin': config.corsOrigin,
          'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
          'Access-Control-Allow-Headers':
              'Authorization, Content-Type, X-Base-Version, X-Payload-Saved-At',
          'Access-Control-Expose-Headers': 'X-Version, X-Payload-Saved-At',
          'X-Content-Type-Options': 'nosniff',
        };
        if (request.method == 'OPTIONS') {
          return Response(204, headers: headers);
        }
        final response = await inner(request);
        return response.change(headers: headers);
      };

  Handler _rateLimit(Handler inner) => (request) async {
        final key = _clientKey(request);
        final isAuthRoute = request.url.path.startsWith('api/v1/auth/') &&
            !request.url.path.endsWith('/logout');
        final limiter = isAuthRoute ? _authLimiter : _generalLimiter;
        if (!limiter.allow('${isAuthRoute ? 'a' : 'g'}:$key')) {
          return _error(429, 'rate_limited', 'Too many requests. Slow down.');
        }
        return inner(request);
      };

  String _clientKey(Request request) {
    if (config.trustProxy) {
      final forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null && forwarded.isNotEmpty) {
        return forwarded.split(',').first.trim();
      }
    }
    final conn = request.context['shelf.io.connection_info'];
    if (conn is HttpConnectionInfo) return conn.remoteAddress.address;
    return 'unknown';
  }

  /// Wraps a handler so it only runs with a valid bearer token; the session's
  /// user is passed along. Also slides the token expiry forward.
  Handler _requireAuth(
      FutureOr<Response> Function(Request, StoredUser) handler) {
    return (request) async {
      final auth = request.headers['authorization'] ?? '';
      if (!auth.startsWith('Bearer ') || auth.length < 20) {
        return _error(401, 'unauthorized', 'Missing or invalid token.');
      }
      final token = auth.substring(7).trim();
      final tokenHash = c.sha256.convert(utf8.encode(token)).toString();
      final session = store.sessionsByTokenHash[tokenHash];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (session == null || session.expiresAtMs <= now) {
        return _error(401, 'unauthorized', 'Session expired. Sign in again.');
      }
      final user = store.usersById[session.userId];
      if (user == null) {
        return _error(401, 'unauthorized', 'Account no longer exists.');
      }
      // Sliding expiry: refresh when past the halfway point.
      final half = config.tokenTtl.inMilliseconds ~/ 2;
      if (session.expiresAtMs - now < half) {
        await store.lock.synchronized(() async {
          session.expiresAtMs = now + config.tokenTtl.inMilliseconds;
          await store.saveSessions();
        });
      }
      return handler(request, user);
    };
  }

  /// Wraps a handler so it only runs with a valid admin key. If no admin key
  /// is configured, the route behaves as if it doesn't exist (404) rather
  /// than being left open. Accepts the key via the `X-Admin-Key` header (all
  /// endpoints) or a `?key=` query parameter (so the HTML dashboard is
  /// reachable from a plain browser, which cannot set custom headers).
  Handler _requireAdmin(FutureOr<Response> Function(Request) handler) {
    return (request) async {
      if (!config.adminEnabled) {
        return _error(404, 'not_found', 'Not found.');
      }
      final provided = request.headers['x-admin-key'] ??
          request.url.queryParameters['key'] ??
          '';
      final expected = config.adminKey!;
      final match = constantTimeEquals(
          utf8.encode(provided), utf8.encode(expected));
      if (!match) {
        return _error(401, 'unauthorized', 'Invalid or missing admin key.');
      }
      return handler(request);
    };
  }

  // ---- Handlers: misc -----------------------------------------------------

  /// A friendly landing page. This server is an API, not a website — there is
  /// nothing to browse here; the luma app connects to it directly.
  Response _root(Request request) => Response.ok(
        '<!doctype html><html><head><meta charset="utf-8">'
        '<title>luma sync server</title>'
        '<style>body{background:#161320;color:#e8e4f3;font-family:system-ui,'
        'sans-serif;display:flex;min-height:100vh;margin:0;align-items:center;'
        'justify-content:center}main{max-width:420px;padding:32px;text-align:'
        'center}h1{font-size:20px;margin:0 0 8px}p{color:#a49fb8;line-height:'
        '1.5;font-size:14px}code{background:#241f33;padding:2px 6px;border-radius'
        ':6px}</style></head><body><main>'
        '<h1>luma sync server</h1>'
        '<p>It\'s running. This is an API for the luma app, not a website — '
        'open luma and add <code>${_originHint(request)}</code> as your server '
        'address under <b>Settings &rarr; Sync &amp; account</b>.</p>'
        '<p>Status: <code>/health</code></p>'
        '</main></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );

  /// Best-effort reconstruction of the URL the user reached us on, for the
  /// landing page hint.
  static String _originHint(Request request) {
    final host = request.headers['host'];
    if (host == null || host.isEmpty) return 'http://localhost:8080';
    // Behind Caddy the original scheme arrives here; default to http locally.
    final scheme = request.headers['x-forwarded-proto'] ??
        (host.startsWith('localhost') || host.startsWith('127.')
            ? 'http'
            : 'https');
    return '$scheme://$host';
  }

  Response _health(Request request) => _json(200, {
        'ok': true,
        'name': 'luma-sync-server',
        'registration': config.registrationEnabled ? 'open' : 'closed',
      });

  // ---- Handlers: auth -----------------------------------------------------

  /// Returns the client-side KDF parameters for an email. For unknown emails
  /// a stable fake salt is fabricated so accounts cannot be enumerated.
  Future<Response> _authParams(Request request) async {
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return _error(400, 'bad_email', 'Invalid email.');

    final userId = store.userIdByEmail[email];
    final user = userId == null ? null : store.usersById[userId];
    if (user != null) {
      return _json(200, {
        'kdfSalt': user.kdfSalt,
        'kdfIterations': user.kdfIterations,
      });
    }
    final fake = c.Hmac(c.sha256, store.serverSecret)
        .convert(utf8.encode('kdf-salt:$email'))
        .bytes
        .sublist(0, 16);
    return _json(200, {
      'kdfSalt': base64Encode(fake),
      'kdfIterations': _defaultClientIterations,
    });
  }

  Future<Response> _register(Request request) async {
    if (!config.registrationEnabled) {
      return _error(403, 'registration_closed',
          'This server does not accept new accounts.');
    }
    final body = await _readJson(request);

    final email = _normalizeEmail(body['email']);
    if (email == null) return _error(400, 'bad_email', 'Invalid email.');

    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    if (authKey == null) {
      return _error(400, 'bad_auth_key', 'Invalid auth key.');
    }
    final kdfSalt = _decodeB64(body['kdfSalt'], minLen: 16, maxLen: 64);
    if (kdfSalt == null) {
      return _error(400, 'bad_kdf_salt', 'Invalid KDF salt.');
    }
    final iterations = body['kdfIterations'];
    if (iterations is! int || iterations < 50000 || iterations > 5000000) {
      return _error(400, 'bad_kdf_iterations', 'Invalid KDF iterations.');
    }

    return store.lock.synchronized(() async {
      if (store.userIdByEmail.containsKey(email)) {
        return _error(409, 'email_taken', 'An account already exists for this email.');
      }
      final authSalt = randomBytes(16);
      final authHash = await _hashAuthKey(authKey, authSalt);
      final requireVerification = config.requireEmailVerification;
      final user = StoredUser(
        id: base64UrlEncode(randomBytes(12)).replaceAll('=', ''),
        email: email,
        authHash: base64Encode(authHash),
        authSalt: base64Encode(authSalt),
        kdfSalt: base64Encode(kdfSalt),
        kdfIterations: iterations,
        // New accounts start on the free 'core' plan; quota comes from the
        // plan map, not LUMA_QUOTA_BYTES — see kPlanQuotaBytes.
        quotaBytes: kPlanQuotaBytes[kDefaultPlanId]!,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: requireVerification ? 'pending' : 'active',
      );
      store.usersById[user.id] = user;
      store.userIdByEmail[email] = user.id;

      if (!requireVerification) {
        await store.saveUsers();
        await store.logActivity('account_registered', '$email registered');
        final token = await _createSession(user);
        return _json(201, {
          'token': token.$1,
          'expiresAtMs': token.$2,
          'quotaBytes': user.quotaBytes,
        });
      }

      final verificationToken = await _issueVerificationToken(user);
      await store.saveUsers();
      await store.logActivity(
          'account_registered', '$email registered (pending verification)');
      await _sendVerificationEmail(user, verificationToken);
      return _json(201, {
        'status': 'pending_verification',
        'message':
            'Check your email to verify your account before signing in.',
      });
    });
  }

  Future<Response> _login(Request request) async {
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    if (email == null || authKey == null) {
      return _error(400, 'bad_request', 'Invalid email or auth key.');
    }

    final userId = store.userIdByEmail[email];
    final user = userId == null ? null : store.usersById[userId];

    // Always burn the same hashing work so response timing does not reveal
    // whether the account exists.
    final salt = user != null
        ? Uint8List.fromList(base64Decode(user.authSalt))
        : randomBytes(16);
    final hash = await _hashAuthKey(authKey, salt);

    if (user == null ||
        !constantTimeEquals(hash, base64Decode(user.authHash))) {
      return _error(401, 'invalid_credentials', 'Wrong email or password.');
    }

    if (user.isPending) {
      return _error(403, 'email_not_verified',
          'Please verify your email address before signing in.');
    }

    return store.lock.synchronized(() async {
      final token = await _createSession(user);
      user.lastLoginAtMs = DateTime.now().millisecondsSinceEpoch;
      await store.saveUsers();
      await store.logActivity('login', '${user.email} logged in');
      return _json(200, {
        'token': token.$1,
        'expiresAtMs': token.$2,
        'quotaBytes': user.quotaBytes,
      });
    });
  }

  /// Confirms a pending account from the link sent by [_sendVerificationEmail].
  /// Returns a small HTML page (the user opens this in a browser from their
  /// email client, not the app) mirroring the style of [_root].
  Future<Response> _verify(Request request) async {
    final token = request.url.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return _verifyPage(400, 'Missing verification token.');
    }
    final tokenHash = c.sha256.convert(utf8.encode(token)).toString();

    return store.lock.synchronized(() async {
      StoredUser? user;
      for (final u in store.usersById.values) {
        if (u.verificationTokenHash == tokenHash) {
          user = u;
          break;
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (user == null) {
        return _verifyPage(
            400, 'This verification link is invalid or has already been used.');
      }
      if ((user.verificationExpiresAtMs ?? 0) <= now) {
        return _verifyPage(400,
            'This verification link has expired. Request a new one from the app.');
      }
      user.status = 'active';
      user.verificationTokenHash = null;
      user.verificationExpiresAtMs = null;
      await store.saveUsers();
      await store.logActivity('account_verified', '${user.email} verified their email');
      return _verifyPage(
          200, 'Your email is verified. You can return to the app and sign in.');
    });
  }

  /// Re-sends the verification email. Responds identically whether or not
  /// the address is registered, so this cannot be used to enumerate accounts.
  Future<Response> _resendVerification(Request request) async {
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return _error(400, 'bad_email', 'Invalid email.');

    if (!_resendLimiter.allow(email)) {
      return _error(429, 'rate_limited',
          'Too many verification requests for this address. Try again later.');
    }

    const genericResponse = {
      'status': 'pending_verification',
      'message':
          'If that email has an unverified account, we just sent a new '
              'verification link.',
    };

    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null || !user.isPending) {
        return _json(200, genericResponse);
      }
      final verificationToken = await _issueVerificationToken(user);
      await store.saveUsers();
      await _sendVerificationEmail(user, verificationToken);
      return _json(200, genericResponse);
    });
  }

  Response _verifyPage(int status, String message) => Response(
        status,
        body: '<!doctype html><html><head><meta charset="utf-8">'
            '<title>luma sync server</title>'
            '<style>body{background:#161320;color:#e8e4f3;font-family:system-ui,'
            'sans-serif;display:flex;min-height:100vh;margin:0;align-items:center;'
            'justify-content:center}main{max-width:420px;padding:32px;text-align:'
            'center}h1{font-size:20px;margin:0 0 8px}p{color:#a49fb8;line-height:'
            '1.5;font-size:14px}</style></head><body><main>'
            '<h1>luma sync server</h1>'
            '<p>${_htmlEscape(message)}</p>'
            '</main></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );

  static String _htmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  Future<Response> _logout(Request request, StoredUser user) async {
    final auth = request.headers['authorization']!;
    final tokenHash =
        c.sha256.convert(utf8.encode(auth.substring(7).trim())).toString();
    return store.lock.synchronized(() async {
      store.sessionsByTokenHash.remove(tokenHash);
      await store.saveSessions();
      return _json(200, {'ok': true});
    });
  }

  /// Rotates the account credentials. The client is expected to re-upload
  /// its blobs afterwards (they are encrypted under a key derived from the
  /// old password). All other sessions are revoked.
  Future<Response> _changePassword(Request request, StoredUser user) async {
    final body = await _readJson(request);
    final current = _decodeB64(body['currentAuthKey'], minLen: 32, maxLen: 64);
    final next = _decodeB64(body['newAuthKey'], minLen: 32, maxLen: 64);
    final newSalt = _decodeB64(body['newKdfSalt'], minLen: 16, maxLen: 64);
    final iterations = body['newKdfIterations'];
    if (current == null ||
        next == null ||
        newSalt == null ||
        iterations is! int ||
        iterations < 50000 ||
        iterations > 5000000) {
      return _error(400, 'bad_request', 'Invalid change-password payload.');
    }

    final currentHash =
        await _hashAuthKey(current, Uint8List.fromList(base64Decode(user.authSalt)));
    if (!constantTimeEquals(currentHash, base64Decode(user.authHash))) {
      return _error(401, 'invalid_credentials', 'Current password is wrong.');
    }

    final auth = request.headers['authorization']!;
    final keepTokenHash =
        c.sha256.convert(utf8.encode(auth.substring(7).trim())).toString();

    return store.lock.synchronized(() async {
      final authSalt = randomBytes(16);
      user.authSalt = base64Encode(authSalt);
      user.authHash = base64Encode(await _hashAuthKey(next, authSalt));
      user.kdfSalt = base64Encode(newSalt);
      user.kdfIterations = iterations;
      store.sessionsByTokenHash.removeWhere(
          (hash, s) => s.userId == user.id && hash != keepTokenHash);
      await store.saveUsers();
      await store.saveSessions();
      return _json(200, {'ok': true});
    });
  }

  Future<Response> _deleteAccount(Request request, StoredUser user) async {
    final body = await _readJson(request);
    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    if (authKey == null) {
      return _error(400, 'bad_request', 'Auth key required to delete account.');
    }
    final hash = await _hashAuthKey(
        authKey, Uint8List.fromList(base64Decode(user.authSalt)));
    if (!constantTimeEquals(hash, base64Decode(user.authHash))) {
      return _error(401, 'invalid_credentials', 'Wrong password.');
    }
    return store.lock.synchronized(() async {
      final email = user.email;
      store.usersById.remove(user.id);
      store.userIdByEmail.remove(user.email.toLowerCase());
      store.sessionsByTokenHash.removeWhere((_, s) => s.userId == user.id);
      store.collectionsByUser.remove(user.id);
      await store.deleteUserData(user.id);
      await store.saveUsers();
      await store.saveSessions();
      await store.saveCollections();
      await store.logActivity('account_deleted', '$email deleted their account');
      return _json(200, {'ok': true});
    });
  }

  // ---- Handlers: AI ---------------------------------------------------------

  /// Whether the operator has configured a shared Mistral key
  /// (LUMA_MISTRAL_API_KEY) — status only, never the key itself. Lets the
  /// app show "a key is available" in Settings without exposing the secret;
  /// the actual key is only ever used server-side, by [_mistralChatProxy].
  Response _mistralKeyStatus(Request request, StoredUser user) =>
      _json(200, {'configured': config.mistralKeyConfigured});

  /// Proxies a chat-completion request to Mistral using the
  /// operator-configured LUMA_MISTRAL_API_KEY, so signed-in users can chat
  /// through the shared key without it ever being sent to any client — only
  /// the caller's own bearer token (already required by [_requireAuth])
  /// leaves their device. The request body is forwarded to Mistral almost
  /// unchanged (same shape [OpenAiCompatibleClient] sends for a direct call:
  /// `model`/`agent_id`, `messages`, `max_tokens`, `tools`); only
  /// `max_tokens` is clamped, since callers no longer hold the key that
  /// would otherwise cap their own spend.
  Future<Response> _mistralChatProxy(Request request, StoredUser user) async {
    if (!config.mistralKeyConfigured) {
      return _error(404, 'not_configured',
          'No server-wide Mistral API key is configured.');
    }
    Map<String, dynamic> body;
    try {
      body = await _readJson(request);
    } on FormatException {
      return _error(400, 'bad_request', 'Malformed request.');
    }
    if (body['messages'] is! List) {
      return _error(400, 'bad_request', 'messages is required.');
    }
    final maxTokensRaw = body['max_tokens'];
    final upstreamBody = {
      ...body,
      'max_tokens': (maxTokensRaw is int ? maxTokensRaw : 1024).clamp(1, 4096),
    };
    final url = body['agent_id'] is String
        ? 'https://api.mistral.ai/v1/agents/completions'
        : 'https://api.mistral.ai/v1/chat/completions';

    final httpClient = HttpClient();
    try {
      final upstreamRequest = await httpClient.postUrl(Uri.parse(url));
      upstreamRequest.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer ${config.mistralApiKey}');
      upstreamRequest.headers.contentType = ContentType.json;
      upstreamRequest.write(jsonEncode(upstreamBody));
      final upstreamResponse =
          await upstreamRequest.close().timeout(const Duration(seconds: 30));
      final responseBody =
          await upstreamResponse.transform(utf8.decoder).join();
      return Response(upstreamResponse.statusCode,
          body: responseBody, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _error(502, 'upstream_error', 'Could not reach Mistral.');
    } finally {
      httpClient.close();
    }
  }

  // ---- Handlers: account & sync -------------------------------------------

  Response _accountInfo(Request request, StoredUser user) {
    final collections = store.collectionsByUser[user.id] ?? const {};
    return _json(200, {
      'email': user.email,
      'usedBytes': store.usedBytes(user.id),
      'quotaBytes': user.quotaBytes,
      'collections': collections.values.map((m) => m.toJson()).toList(),
    });
  }

  Future<Response> _getBlob(Request request, StoredUser user) async {
    final name = request.params['collection']!;
    if (!collectionPattern.hasMatch(name)) {
      return _error(400, 'bad_collection', 'Invalid collection name.');
    }
    final meta = store.collectionsByUser[user.id]?[name];
    final bytes = meta == null ? null : await store.readBlob(user.id, name);
    if (meta == null || bytes == null) {
      return _error(404, 'not_found', 'No data for this collection.');
    }
    return Response(200, body: bytes, headers: {
      'Content-Type': 'application/octet-stream',
      'X-Version': '${meta.version}',
      'X-Payload-Saved-At': '${meta.payloadSavedAtMs}',
    });
  }

  Future<Response> _putBlob(Request request, StoredUser user) async {
    final name = request.params['collection']!;
    if (!collectionPattern.hasMatch(name)) {
      return _error(400, 'bad_collection', 'Invalid collection name.');
    }
    final baseVersion =
        int.tryParse(request.headers['x-base-version'] ?? '') ?? -1;
    final savedAtMs =
        int.tryParse(request.headers['x-payload-saved-at'] ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
    if (baseVersion < 0) {
      return _error(400, 'bad_version', 'X-Base-Version header required.');
    }

    // Read the body with a hard cap so oversized uploads cannot exhaust RAM.
    final declared = request.contentLength ?? -1;
    if (declared > config.maxBlobBytes) {
      return _error(413, 'blob_too_large',
          'Snapshot exceeds the per-upload limit of ${config.maxBlobBytes} bytes.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > config.maxBlobBytes) {
        return _error(413, 'blob_too_large',
            'Snapshot exceeds the per-upload limit of ${config.maxBlobBytes} bytes.');
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      return _error(400, 'empty_body', 'Empty snapshot rejected.');
    }

    return store.lock.synchronized(() async {
      final perUser =
          store.collectionsByUser.putIfAbsent(user.id, () => {});
      final existing = perUser[name];
      final currentVersion = existing?.version ?? 0;

      if (baseVersion != currentVersion) {
        return _error(409, 'version_conflict', 'Server has a newer snapshot.',
            extra: {
              'version': currentVersion,
              'payloadSavedAtMs': existing?.payloadSavedAtMs ?? 0,
            });
      }

      final newUsed =
          store.usedBytes(user.id) - (existing?.size ?? 0) + bytes.length;
      if (newUsed > user.quotaBytes) {
        return _error(413, 'quota_exceeded',
            'Storage quota exceeded (${user.quotaBytes} bytes).',
            extra: {
              'usedBytes': store.usedBytes(user.id),
              'quotaBytes': user.quotaBytes,
            });
      }

      await store.writeBlob(user.id, name, bytes);
      final now = DateTime.now().millisecondsSinceEpoch;
      final meta = existing ??
          CollectionMeta(
              name: name,
              version: 0,
              size: 0,
              payloadSavedAtMs: 0,
              updatedAtMs: 0);
      meta
        ..version = currentVersion + 1
        ..size = bytes.length
        ..payloadSavedAtMs = savedAtMs
        ..updatedAtMs = now;
      perUser[name] = meta;
      await store.saveCollections();

      return _json(200, {
        'version': meta.version,
        'usedBytes': store.usedBytes(user.id),
        'quotaBytes': user.quotaBytes,
      });
    });
  }

  Future<Response> _deleteBlobHandler(Request request, StoredUser user) async {
    final name = request.params['collection']!;
    if (!collectionPattern.hasMatch(name)) {
      return _error(400, 'bad_collection', 'Invalid collection name.');
    }
    return store.lock.synchronized(() async {
      store.collectionsByUser[user.id]?.remove(name);
      await store.deleteBlob(user.id, name);
      await store.saveCollections();
      return _json(200, {
        'ok': true,
        'usedBytes': store.usedBytes(user.id),
        'quotaBytes': user.quotaBytes,
      });
    });
  }

  // ---- Handlers: family -----------------------------------------------------
  //
  // Unlike /api/v1/sync/<collection>, this data is deliberately readable by
  // the server in the clear — sharing across accounts is incompatible with
  // the per-account zero-knowledge key derivation used for everything else,
  // and the user chose plain server-side storage (secured the same way the
  // rest of the API is: bearer-token auth + explicit membership checks) over
  // building a per-family encryption/key-distribution scheme. Every handler
  // below must verify the caller is a current member before returning or
  // mutating anything for a family.

  static const _familyInviteTtl = Duration(days: 7);

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  String _genId() => base64UrlEncode(randomBytes(12)).replaceAll('=', '');

  int _familyMemberLimitFor(StoredUser owner) =>
      kFamilyMemberLimit[owner.planId] ?? kFamilyMemberLimit[kDefaultPlanId]!;

  Map<String, dynamic> _familyJson(Family family, StoredUser requester,
      {required bool includeInvites}) {
    final owner = store.usersById[family.ownerUserId];
    final members = familyStore.membersOf(family.id);
    final now = _nowMs;
    final json = {
      'id': family.id,
      'name': family.name,
      'ownerUserId': family.ownerUserId,
      'createdAtMs': family.createdAtMs,
      'slotLimit': owner == null ? null : _familyMemberLimitFor(owner),
      'slotsUsed': familyStore.slotsUsed(family.id, now),
      'members': members
          .map((m) => {
                'userId': m.userId,
                'email': store.usersById[m.userId]?.email ?? '',
                'role': m.role,
                'joinedAtMs': m.joinedAtMs,
              })
          .toList(),
    };
    if (includeInvites && requester.id == family.ownerUserId) {
      json['pendingInvites'] = familyStore
          .pendingInvitesForFamily(family.id, now)
          .map((i) => {
                'id': i.id,
                'email': i.inviteeEmail,
                'createdAtMs': i.createdAtMs,
                'expiresAtMs': i.expiresAtMs,
              })
          .toList();
    }
    return json;
  }

  Map<String, dynamic> _sharedEventJson(FamilySharedEvent e) => {
        'id': e.id,
        'familyId': e.familyId,
        'authorUserId': e.authorUserId,
        'title': e.title,
        'description': e.description,
        'location': e.location,
        'startMs': e.startMs,
        'endMs': e.endMs,
        'allDay': e.allDay,
        'color': e.color,
        'recurrence': e.recurrence,
        'recurrenceEndMs': e.recurrenceEndMs,
        'reminderMinutes': e.reminderMinutes,
        'visibility': e.visibility,
        'visibleMemberUserIds': e.visibleMemberUserIds,
        'createdAtMs': e.createdAtMs,
        'updatedAtMs': e.updatedAtMs,
      };

  Future<Response> _createFamily(Request request, StoredUser user) async {
    if (familyStore.familyIdByUserId.containsKey(user.id)) {
      return _error(409, 'already_in_family',
          'You already belong to a family. Leave it before creating another.');
    }
    final body = await _readJson(request);
    final name = (body['name'] as String?)?.trim() ?? '';
    if (name.isEmpty || name.length > 60) {
      return _error(400, 'bad_name', 'Family name must be 1–60 characters.');
    }

    return store.lock.synchronized(() async {
      if (familyStore.familyIdByUserId.containsKey(user.id)) {
        return _error(409, 'already_in_family',
            'You already belong to a family. Leave it before creating another.');
      }
      final now = _nowMs;
      final family =
          Family(id: _genId(), name: name, ownerUserId: user.id, createdAtMs: now);
      familyStore.familiesById[family.id] = family;
      familyStore.membersByFamilyId[family.id] = {
        user.id: FamilyMember(
            familyId: family.id,
            userId: user.id,
            role: 'owner',
            joinedAtMs: now),
      };
      familyStore.familyIdByUserId[user.id] = family.id;
      await familyStore.saveFamilies();
      await familyStore.saveMembers();
      return _json(
          201, _familyJson(family, user, includeInvites: true));
    });
  }

  Response _getMyFamily(Request request, StoredUser user) {
    final family = familyStore.familyForUser(user.id);
    if (family == null) {
      return _error(404, 'no_family', 'You are not in a family yet.');
    }
    return _json(200, _familyJson(family, user, includeInvites: true));
  }

  Future<Response> _inviteFamilyMember(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return _error(404, 'not_found', 'Family not found.');
    if (family.ownerUserId != user.id) {
      return _error(403, 'forbidden', 'Only the family owner can invite members.');
    }
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return _error(400, 'bad_email', 'Invalid email.');

    return store.lock.synchronized(() async {
      final now = _nowMs;
      final existingUserId = store.userIdByEmail[email];
      if (existingUserId != null && familyStore.isMember(familyId, existingUserId)) {
        return _error(409, 'already_member', 'That person is already in the family.');
      }
      final alreadyPending = familyStore.invitesById.values.any((i) =>
          i.familyId == familyId && i.inviteeEmail == email && i.isPendingAt(now));
      if (alreadyPending) {
        return _error(409, 'invite_pending', 'An invite is already pending for that email.');
      }

      final owner = store.usersById[user.id]!;
      final limit = _familyMemberLimitFor(owner);
      if (familyStore.slotsUsed(familyId, now) >= limit) {
        return _error(403, 'family_limit_exceeded',
            'Your plan allows up to $limit family members. Upgrade your plan to invite more.');
      }

      final invite = FamilyInvite(
        id: _genId(),
        familyId: familyId,
        inviteeEmail: email,
        invitedByUserId: user.id,
        createdAtMs: now,
        expiresAtMs: now + _familyInviteTtl.inMilliseconds,
      );
      familyStore.invitesById[invite.id] = invite;
      await familyStore.saveInvites();
      await _sendFamilyInviteEmail(
          toEmail: email, inviterEmail: user.email, familyName: family.name);
      return _json(201, {
        'id': invite.id,
        'email': invite.inviteeEmail,
        'expiresAtMs': invite.expiresAtMs,
      });
    });
  }

  Response _listMyInvites(Request request, StoredUser user) {
    final now = _nowMs;
    final invites =
        familyStore.pendingInvitesForEmail(user.email.toLowerCase(), now);
    return _json(200, {
      'invites': invites.map((i) {
        final family = familyStore.familiesById[i.familyId];
        final inviter = store.usersById[i.invitedByUserId];
        return {
          'id': i.id,
          'familyId': i.familyId,
          'familyName': family?.name ?? 'Family',
          'inviterEmail': inviter?.email ?? '',
          'createdAtMs': i.createdAtMs,
          'expiresAtMs': i.expiresAtMs,
        };
      }).toList(),
    });
  }

  Future<Response> _acceptFamilyInvite(Request request, StoredUser user) async {
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = familyStore.invitesById[inviteId];
      if (invite == null || invite.inviteeEmail != user.email.toLowerCase()) {
        return _error(404, 'not_found', 'Invite not found.');
      }
      if (!invite.isPendingAt(now)) {
        return _error(410, 'invite_not_pending', 'This invite is no longer available.');
      }
      final family = familyStore.familiesById[invite.familyId];
      if (family == null) {
        return _error(404, 'not_found', 'This family no longer exists.');
      }
      if (familyStore.familyIdByUserId.containsKey(user.id)) {
        return _error(409, 'already_in_family',
            'You already belong to a family. Leave it before accepting a new invite.');
      }
      final owner = store.usersById[family.ownerUserId];
      final limit = owner == null
          ? kFamilyMemberLimit[kDefaultPlanId]!
          : _familyMemberLimitFor(owner);
      if (familyStore.membersOf(family.id).length >= limit) {
        return _error(403, 'family_limit_exceeded',
            'This family is full.');
      }

      familyStore.membersByFamilyId.putIfAbsent(family.id, () => {})[user.id] =
          FamilyMember(
              familyId: family.id,
              userId: user.id,
              role: 'member',
              joinedAtMs: now);
      familyStore.familyIdByUserId[user.id] = family.id;
      invite.status = 'accepted';
      invite.respondedAtMs = now;
      await familyStore.saveMembers();
      await familyStore.saveInvites();
      return _json(200, _familyJson(family, user, includeInvites: false));
    });
  }

  Future<Response> _declineFamilyInvite(Request request, StoredUser user) async {
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = familyStore.invitesById[inviteId];
      if (invite == null || invite.inviteeEmail != user.email.toLowerCase()) {
        return _error(404, 'not_found', 'Invite not found.');
      }
      if (!invite.isPendingAt(now)) {
        return _error(410, 'invite_not_pending', 'This invite is no longer available.');
      }
      invite.status = 'declined';
      invite.respondedAtMs = now;
      await familyStore.saveInvites();
      return _json(200, {'ok': true});
    });
  }

  Future<Response> _removeFamilyMember(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final targetUserId = request.params['userId']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return _error(404, 'not_found', 'Family not found.');
    final isOwner = family.ownerUserId == user.id;
    final isSelf = targetUserId == user.id;
    if (!isOwner && !isSelf) {
      return _error(403, 'forbidden', 'Only the family owner can remove other members.');
    }
    if (targetUserId == family.ownerUserId) {
      return _error(409, 'owner_cannot_leave',
          'The owner cannot leave the family. Delete the family instead.');
    }
    return store.lock.synchronized(() async {
      familyStore.membersByFamilyId[familyId]?.remove(targetUserId);
      if (familyStore.familyIdByUserId[targetUserId] == familyId) {
        familyStore.familyIdByUserId.remove(targetUserId);
      }
      await familyStore.saveMembers();
      return _json(200, {'ok': true});
    });
  }

  Future<Response> _deleteFamily(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return _error(404, 'not_found', 'Family not found.');
    if (family.ownerUserId != user.id) {
      return _error(403, 'forbidden', 'Only the family owner can delete the family.');
    }
    return store.lock.synchronized(() async {
      familyStore.deleteFamilyData(familyId);
      await familyStore.saveFamilies();
      await familyStore.saveMembers();
      await familyStore.saveInvites();
      await familyStore.saveEvents();
      return _json(200, {'ok': true});
    });
  }

  Future<Response> _addSharedEvent(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return _error(404, 'not_found', 'Family not found.');
    if (!familyStore.isMember(familyId, user.id)) {
      return _error(403, 'forbidden', 'You are not a member of this family.');
    }
    final body = await _readJson(request);
    final parsed = _parseSharedEventBody(body, familyId);
    if (parsed is _ParseError) {
      return _error(400, parsed.code, parsed.message);
    }
    final fields = parsed as _ParsedSharedEvent;
    if (fields.visibility == 'subset') {
      for (final id in fields.visibleMemberUserIds) {
        if (!familyStore.isMember(familyId, id)) {
          return _error(400, 'bad_member', 'One of the chosen members is not in this family.');
        }
      }
    }

    return store.lock.synchronized(() async {
      final now = _nowMs;
      final event = FamilySharedEvent(
        id: _genId(),
        familyId: familyId,
        authorUserId: user.id,
        title: fields.title,
        description: fields.description,
        location: fields.location,
        startMs: fields.startMs,
        endMs: fields.endMs,
        allDay: fields.allDay,
        color: fields.color,
        recurrence: fields.recurrence,
        recurrenceEndMs: fields.recurrenceEndMs,
        reminderMinutes: fields.reminderMinutes,
        visibility: fields.visibility,
        visibleMemberUserIds: fields.visibleMemberUserIds,
        createdAtMs: now,
        updatedAtMs: now,
      );
      familyStore.sharedEventsByFamilyId
          .putIfAbsent(familyId, () => {})[event.id] = event;
      await familyStore.saveEvents();
      return _json(201, _sharedEventJson(event));
    });
  }

  Response _listSharedEvents(Request request, StoredUser user) {
    final familyId = request.params['id']!;
    if (familyStore.familiesById[familyId] == null) {
      return _error(404, 'not_found', 'Family not found.');
    }
    if (!familyStore.isMember(familyId, user.id)) {
      return _error(403, 'forbidden', 'You are not a member of this family.');
    }
    final events = familyStore.visibleEvents(familyId, user.id);
    return _json(200, {'events': events.map(_sharedEventJson).toList()});
  }

  Future<Response> _updateSharedEvent(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final eventId = request.params['eventId']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return _error(404, 'not_found', 'Family not found.');
    final event = familyStore.sharedEventsByFamilyId[familyId]?[eventId];
    if (event == null) return _error(404, 'not_found', 'Event not found.');
    if (event.authorUserId != user.id && family.ownerUserId != user.id) {
      return _error(403, 'forbidden', 'Only the author or family owner can edit this event.');
    }
    final body = await _readJson(request);
    final parsed = _parseSharedEventBody(body, familyId);
    if (parsed is _ParseError) {
      return _error(400, parsed.code, parsed.message);
    }
    final fields = parsed as _ParsedSharedEvent;
    if (fields.visibility == 'subset') {
      for (final id in fields.visibleMemberUserIds) {
        if (!familyStore.isMember(familyId, id)) {
          return _error(400, 'bad_member', 'One of the chosen members is not in this family.');
        }
      }
    }

    return store.lock.synchronized(() async {
      event
        ..title = fields.title
        ..description = fields.description
        ..location = fields.location
        ..startMs = fields.startMs
        ..endMs = fields.endMs
        ..allDay = fields.allDay
        ..color = fields.color
        ..recurrence = fields.recurrence
        ..recurrenceEndMs = fields.recurrenceEndMs
        ..reminderMinutes = fields.reminderMinutes
        ..visibility = fields.visibility
        ..visibleMemberUserIds = fields.visibleMemberUserIds
        ..updatedAtMs = _nowMs;
      await familyStore.saveEvents();
      return _json(200, _sharedEventJson(event));
    });
  }

  Future<Response> _deleteSharedEvent(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final eventId = request.params['eventId']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return _error(404, 'not_found', 'Family not found.');
    final event = familyStore.sharedEventsByFamilyId[familyId]?[eventId];
    if (event == null) return _error(404, 'not_found', 'Event not found.');
    if (event.authorUserId != user.id && family.ownerUserId != user.id) {
      return _error(403, 'forbidden', 'Only the author or family owner can delete this event.');
    }
    return store.lock.synchronized(() async {
      familyStore.sharedEventsByFamilyId[familyId]?.remove(eventId);
      await familyStore.saveEvents();
      return _json(200, {'ok': true});
    });
  }

  Object _parseSharedEventBody(Map<String, dynamic> body, String familyId) {
    final title = (body['title'] as String?)?.trim() ?? '';
    if (title.isEmpty || title.length > 200) {
      return const _ParseError('bad_title', 'Title must be 1–200 characters.');
    }
    final startMs = body['startMs'];
    final endMs = body['endMs'];
    if (startMs is! int || endMs is! int) {
      return const _ParseError('bad_dates', 'startMs and endMs are required.');
    }
    final visibility = body['visibility'] as String? ?? 'all';
    if (visibility != 'all' && visibility != 'subset') {
      return const _ParseError('bad_visibility', "visibility must be 'all' or 'subset'.");
    }
    final memberIds = (body['memberUserIds'] as List?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    if (visibility == 'subset' && memberIds.isEmpty) {
      return const _ParseError(
          'bad_members', 'Choose at least one member when sharing with specific people.');
    }
    return _ParsedSharedEvent(
      title: title,
      description: _nullIfBlank(body['description'] as String?),
      location: _nullIfBlank(body['location'] as String?),
      startMs: startMs,
      endMs: endMs,
      allDay: body['allDay'] as bool? ?? false,
      color: body['color'] as int? ?? 0xFF7C5AD9,
      recurrence: body['recurrence'] as String? ?? 'none',
      recurrenceEndMs: body['recurrenceEndMs'] as int?,
      reminderMinutes: body['reminderMinutes'] as int?,
      visibility: visibility,
      visibleMemberUserIds: visibility == 'subset' ? memberIds : const [],
    );
  }

  /// Best-effort send; a mail outage should not block invites outright since
  /// the invite still shows up in-app the next time the invitee's client
  /// polls /api/v1/family/invites.
  Future<void> _sendFamilyInviteEmail({
    required String toEmail,
    required String inviterEmail,
    required String familyName,
  }) async {
    try {
      await mailer.sendFamilyInviteEmail(
          toEmail: toEmail, inviterEmail: inviterEmail, familyName: familyName);
    } catch (e) {
      stderr.writeln('[luma] could not send family invite email to $toEmail: $e');
    }
  }

  // ---- Handlers: chat --------------------------------------------------------
  //
  // The server here is a dumb, opaque relay: it stores each user's X25519
  // public key (needed so others can encrypt *to* them) and, once two users
  // are connected, opaque ciphertext blobs per message. It never sees a
  // plaintext message, a private key, or has any way to decrypt what it
  // stores — see chat_crypto.dart on the client for the sealed-box scheme.

  static const _chatInviteTtl = Duration(days: 14);
  // A message body carries *two* blobs (one sealed to the recipient, one to
  // the sender) plus JSON overhead, and the whole request must still fit
  // under `_maxJsonBody` (64KB) — so each blob gets well under half of that.
  static const _maxChatBlobLength = 28000; // base64 chars (~20KB plaintext)

  Future<Response> _putChatKey(Request request, StoredUser user) async {
    final body = await _readJson(request);
    final key = body['publicKey'];
    if (key is! String || key.isEmpty || key.length > 200) {
      return _error(400, 'bad_key', 'Invalid public key.');
    }
    return store.lock.synchronized(() async {
      chatStore.publicKeyByUserId[user.id] = key;
      await chatStore.saveKeys();
      return _json(200, {'ok': true});
    });
  }

  Response _getChatKey(Request request, StoredUser user) {
    final userId = request.params['userId']!;
    final key = chatStore.publicKeyByUserId[userId];
    if (key == null) return _error(404, 'not_found', 'No public key for that user.');
    return _json(200, {'userId': userId, 'publicKey': key});
  }

  Future<Response> _sendChatInvite(Request request, StoredUser user) async {
    if (!chatStore.publicKeyByUserId.containsKey(user.id)) {
      return _error(400, 'no_key',
          'Set up chat encryption on this device first.');
    }
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return _error(400, 'bad_email', 'Invalid email.');
    if (email == user.email.toLowerCase()) {
      return _error(400, 'bad_email', 'You cannot invite yourself.');
    }

    return store.lock.synchronized(() async {
      final now = _nowMs;
      final existingUserId = store.userIdByEmail[email];
      if (existingUserId != null &&
          chatStore.conversationBetween(user.id, existingUserId) != null) {
        return _error(409, 'already_chatting', 'You already have a chat with that person.');
      }
      final alreadyPending = chatStore.invitesById.values.any((i) =>
          i.fromUserId == user.id && i.toEmail == email && i.isPendingAt(now));
      if (alreadyPending) {
        return _error(409, 'invite_pending', 'An invite is already pending for that email.');
      }

      final invite = ChatInvite(
        id: _genId(),
        fromUserId: user.id,
        toEmail: email,
        createdAtMs: now,
        expiresAtMs: now + _chatInviteTtl.inMilliseconds,
      );
      chatStore.invitesById[invite.id] = invite;
      await chatStore.saveInvites();
      await _sendChatInviteEmail(toEmail: email, inviterEmail: user.email);
      return _json(201, {
        'id': invite.id,
        'email': invite.toEmail,
        'expiresAtMs': invite.expiresAtMs,
      });
    });
  }

  Response _listChatInvites(Request request, StoredUser user) {
    final now = _nowMs;
    final invites = chatStore.pendingInvitesForEmail(user.email.toLowerCase(), now);
    return _json(200, {
      'invites': invites.map((i) {
        final inviter = store.usersById[i.fromUserId];
        return {
          'id': i.id,
          'inviterEmail': inviter?.email ?? '',
          'createdAtMs': i.createdAtMs,
          'expiresAtMs': i.expiresAtMs,
        };
      }).toList(),
    });
  }

  Future<Response> _acceptChatInvite(Request request, StoredUser user) async {
    if (!chatStore.publicKeyByUserId.containsKey(user.id)) {
      return _error(400, 'no_key',
          'Set up chat encryption on this device first.');
    }
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = chatStore.invitesById[inviteId];
      if (invite == null || invite.toEmail != user.email.toLowerCase()) {
        return _error(404, 'not_found', 'Invite not found.');
      }
      if (!invite.isPendingAt(now)) {
        return _error(410, 'invite_not_pending', 'This invite is no longer available.');
      }

      var conversation = chatStore.conversationBetween(invite.fromUserId, user.id);
      conversation ??= ChatConversation(
        id: _genId(),
        userAId: invite.fromUserId,
        userBId: user.id,
        createdAtMs: now,
      );
      chatStore.conversationsById[conversation.id] = conversation;
      invite.status = 'accepted';
      invite.respondedAtMs = now;
      await chatStore.saveConversations();
      await chatStore.saveInvites();

      final peer = store.usersById[invite.fromUserId];
      return _json(200, _conversationJson(conversation, user.id, peer));
    });
  }

  Future<Response> _declineChatInvite(Request request, StoredUser user) async {
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = chatStore.invitesById[inviteId];
      if (invite == null || invite.toEmail != user.email.toLowerCase()) {
        return _error(404, 'not_found', 'Invite not found.');
      }
      invite.status = 'declined';
      invite.respondedAtMs = now;
      await chatStore.saveInvites();
      return _json(200, {'ok': true});
    });
  }

  Map<String, dynamic> _conversationJson(
      ChatConversation c, String meUserId, StoredUser? peer) {
    final peerId = c.otherUser(meUserId);
    return {
      'id': c.id,
      'peerUserId': peerId,
      'peerEmail': peer?.email ?? '',
      'peerPublicKey': chatStore.publicKeyByUserId[peerId],
      'createdAtMs': c.createdAtMs,
    };
  }

  Response _listChatConversations(Request request, StoredUser user) {
    final conversations = chatStore.conversationsForUser(user.id);
    return _json(200, {
      'conversations': conversations.map((c) {
        final peer = store.usersById[c.otherUser(user.id)];
        return _conversationJson(c, user.id, peer);
      }).toList(),
    });
  }

  Response _listChatMessages(Request request, StoredUser user) {
    final conversationId = request.params['id']!;
    final conversation = chatStore.conversationsById[conversationId];
    if (conversation == null || !conversation.hasUser(user.id)) {
      return _error(404, 'not_found', 'Conversation not found.');
    }
    final sinceMs = int.tryParse(request.url.queryParameters['since'] ?? '');
    final messages = chatStore.messagesFor(conversationId, sinceMs: sinceMs);
    return _json(200, {
      'messages': messages.map((m) => {
            'id': m.id,
            'senderUserId': m.senderUserId,
            'createdAtMs': m.createdAtMs,
            'blob': m.senderUserId == user.id ? m.blobForSender : m.blobForRecipient,
          }).toList(),
    });
  }

  Future<Response> _sendChatMessage(Request request, StoredUser user) async {
    final conversationId = request.params['id']!;
    final conversation = chatStore.conversationsById[conversationId];
    if (conversation == null || !conversation.hasUser(user.id)) {
      return _error(404, 'not_found', 'Conversation not found.');
    }
    final body = await _readJson(request);
    final forRecipient = body['blobForRecipient'];
    final forSender = body['blobForSender'];
    if (forRecipient is! String ||
        forSender is! String ||
        forRecipient.isEmpty ||
        forSender.isEmpty ||
        forRecipient.length > _maxChatBlobLength ||
        forSender.length > _maxChatBlobLength) {
      return _error(400, 'bad_message', 'Invalid message payload.');
    }

    return store.lock.synchronized(() async {
      final message = ChatMessage(
        id: _genId(),
        conversationId: conversationId,
        senderUserId: user.id,
        createdAtMs: _nowMs,
        blobForRecipient: forRecipient,
        blobForSender: forSender,
      );
      chatStore.messagesByConversationId
          .putIfAbsent(conversationId, () => [])
          .add(message);
      await chatStore.saveMessages();
      return _json(201, {'id': message.id, 'createdAtMs': message.createdAtMs});
    });
  }

  /// Best-effort send; a mail outage should not block invites outright since
  /// the invite still shows up in-app the next time the invitee's client
  /// polls /api/v1/chat/invites.
  Future<void> _sendChatInviteEmail({
    required String toEmail,
    required String inviterEmail,
  }) async {
    try {
      await mailer.sendChatInviteEmail(toEmail: toEmail, inviterEmail: inviterEmail);
    } catch (e) {
      stderr.writeln('[luma] could not send chat invite email to $toEmail: $e');
    }
  }

  // ---- Handlers: admin ------------------------------------------------------

  /// Metadata-only view of one account for the admin endpoints. Never
  /// includes anything that could help decrypt a user's blobs (authHash,
  /// authSalt, kdfSalt, session tokens, etc. are all withheld).
  Map<String, dynamic> _adminUserJson(StoredUser user) => {
        'email': user.email,
        'status': user.status,
        'planId': user.planId,
        'createdAtMs': user.createdAtMs,
        'usedBytes': store.usedBytes(user.id),
        'quotaBytes': user.quotaBytes,
        'lastLoginAtMs': user.lastLoginAtMs,
      };

  Response _adminUsers(Request request) {
    final users = store.usersById.values.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return _json(200, {'users': users.map(_adminUserJson).toList()});
  }

  Map<String, dynamic> _adminStatsJson() {
    final users = store.usersById.values;
    var active = 0;
    var pending = 0;
    var usedTotal = 0;
    var quotaTotal = 0;
    final planCounts = <String, int>{for (final id in kPlanQuotaBytes.keys) id: 0};
    for (final u in users) {
      if (u.isPending) {
        pending++;
      } else {
        active++;
      }
      usedTotal += store.usedBytes(u.id);
      quotaTotal += u.quotaBytes;
      planCounts[u.planId] = (planCounts[u.planId] ?? 0) + 1;
    }
    return {
      'totalAccounts': users.length,
      'activeAccounts': active,
      'pendingAccounts': pending,
      'usedBytesTotal': usedTotal,
      'quotaBytesTotal': quotaTotal,
      'planCounts': planCounts,
    };
  }

  Response _adminStats(Request request) => _json(200, _adminStatsJson());

  Future<Response> _adminMetrics(Request request) async {
    final metrics = await SystemMetrics.sample();
    await store.metricsHistory.addSample(metrics);
    return _json(200, metrics.toJson());
  }

  /// Persisted graph history for the admin dashboard's range selector —
  /// range is one of 'minute' / 'hour' / 'day' / 'week' (default 'minute').
  /// Backed by [MetricsHistory], which downsamples raw /admin/metrics
  /// samples into minute/hour buckets so this survives page reloads and
  /// server restarts, unlike the old client-only rolling window.
  Response _adminMetricsHistory(Request request) {
    final range = request.url.queryParameters['range'] ?? 'minute';
    final points = store.metricsHistory.pointsForRange(range);
    return _json(200, {
      'range': range,
      'points': points.map((p) => p.toJson()).toList(),
    });
  }

  /// Persisted activity feed (see Store.logActivity), filtered to the last
  /// [hours] (default 24) and newest first — unlike /admin/metrics this
  /// survives a server restart.
  Response _adminActivity(Request request) {
    final hours =
        int.tryParse(request.url.queryParameters['hours'] ?? '') ?? 24;
    final cutoff = DateTime.now().millisecondsSinceEpoch -
        Duration(hours: hours).inMilliseconds;
    final events = store.activity.where((a) => a.createdAtMs >= cutoff).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return _json(200, {'events': events.map((e) => e.toJson()).toList()});
  }

  /// Manually activates a pending account, bypassing email verification —
  /// the escape hatch for self-hosted servers where SMTP isn't configured
  /// (or mail just didn't arrive) and the operator needs to unblock a
  /// legitimate sign-up with no other way to receive the link.
  Future<Response> _adminVerifyUser(Request request) async {
    final raw = await request.readAsString();
    String? email;
    try {
      email = Uri.splitQueryString(raw)['email'];
    } catch (_) {}
    email = email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return _error(400, 'bad_request', 'email is required.');
    }
    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null) {
        return _error(404, 'not_found', 'No account with that email.');
      }
      user.status = 'active';
      user.verificationTokenHash = null;
      user.verificationExpiresAtMs = null;
      await store.saveUsers();
      await store.logActivity(
          'admin_verified', '$email was manually verified by an admin');
      final key = request.url.queryParameters['key'];
      if (key != null) {
        return Response.found('/admin?key=${Uri.encodeQueryComponent(key)}');
      }
      return _json(200, {'ok': true});
    });
  }

  /// Grants (or revokes, by setting planId='core') a plan for an account —
  /// the "Products" tab on the dashboard. Storage quota is updated to match
  /// the plan immediately (see kPlanQuotaBytes).
  Future<Response> _adminSetPlan(Request request) async {
    final raw = await request.readAsString();
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(raw);
    } catch (_) {}
    final email = form['email']?.trim().toLowerCase();
    final planId = form['planId'];
    if (email == null || email.isEmpty) {
      return _error(400, 'bad_request', 'email is required.');
    }
    if (planId == null || !kPlanQuotaBytes.containsKey(planId)) {
      return _error(400, 'bad_plan',
          'planId must be one of: ${kPlanQuotaBytes.keys.join(', ')}.');
    }
    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null) {
        return _error(404, 'not_found', 'No account with that email.');
      }
      user.planId = planId;
      user.quotaBytes = kPlanQuotaBytes[planId]!;
      await store.saveUsers();
      await store.logActivity(
          'plan_granted', '$email was granted the $planId plan');
      final key = request.url.queryParameters['key'];
      if (key != null) {
        return Response.found(
            '/admin?key=${Uri.encodeQueryComponent(key)}#products');
      }
      return _json(
          200, {'ok': true, 'planId': planId, 'quotaBytes': user.quotaBytes});
    });
  }

  /// Proxies a "reload the groceries database" click to the supermarket-db
  /// API's own admin endpoint. Keeping this server in the middle means the
  /// groceries admin key stays in this process's environment — the dashboard
  /// page only ever carries this server's admin key.
  Future<Response> _adminGroceriesSync(Request request) async {
    if (!config.groceriesAdminEnabled) {
      return _error(404, 'not_configured',
          'LUMA_GROCERIES_ADMIN_KEY is not set on this server.');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final market = form['market'];

    final httpClient = HttpClient();
    try {
      final upstream = await httpClient
          .postUrl(Uri.parse('${config.groceriesUrl}/admin/sync'));
      upstream.headers.set('x-admin-key', config.groceriesAdminKey!);
      upstream.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      if (market != null && market.isNotEmpty) {
        upstream.write('market=${Uri.encodeQueryComponent(market)}');
      }
      final response =
          await upstream.close().timeout(const Duration(seconds: 30));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        return Response(response.statusCode,
            body: body, headers: {'Content-Type': 'application/json'});
      }
      final key = request.url.queryParameters['key'];
      if (key != null) {
        return Response.found(
            '/admin?key=${Uri.encodeQueryComponent(key)}#control');
      }
      return Response(200,
          body: body, headers: {'Content-Type': 'application/json'});
    } catch (_) {
      return _error(
          502, 'upstream_error', 'Could not reach the groceries server.');
    } finally {
      httpClient.close();
    }
  }

  /// Fetches the groceries server's sync status (product counts + recent
  /// sync runs) for the Control panel tab, again by proxy so the key stays
  /// server-side. Reports `configured: false` instead of erroring when the
  /// operator hasn't wired the groceries server up.
  Future<Response> _adminGroceriesStatus(Request request) async {
    if (!config.groceriesAdminEnabled) {
      return _json(200, {'configured': false});
    }
    final httpClient = HttpClient();
    try {
      final upstream = await httpClient
          .getUrl(Uri.parse('${config.groceriesUrl}/admin/sync/status'));
      upstream.headers.set('x-admin-key', config.groceriesAdminKey!);
      final response =
          await upstream.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return _error(502, 'upstream_error',
            'Groceries server returned ${response.statusCode}.');
      }
      return Response(200,
          body: '{"configured":true,"status":$body}',
          headers: {'Content-Type': 'application/json'});
    } catch (_) {
      return _error(
          502, 'upstream_error', 'Could not reach the groceries server.');
    } finally {
      httpClient.close();
    }
  }

  /// Triggers a full server update: git pull → pub get → recompile →
  /// systemctl restart. The command runs in a fully detached process
  /// (`setsid`) so it survives the service stop that kills *this* process.
  /// Output is written to `deploy.log` in the data dir; the PID is tracked
  /// in `deploy.pid` so the status endpoint can tell whether it's still
  /// running. The endpoint returns immediately with `{"started": true}`.
  Future<Response> _adminDeploy(Request request) async {
    final logFile = File('${config.dataDir}/deploy.log');
    final pidFile = File('${config.dataDir}/deploy.pid');

    if (await pidFile.exists()) {
      final pid = int.tryParse((await pidFile.readAsString()).trim());
      if (pid != null && _isProcessAlive(pid)) {
        return _error(409, 'deploy_running',
            'A deploy is already in progress. Wait for it to finish.');
      }
    }

    await logFile.parent.create(recursive: true);

    const deployCmd = 'cd ~/luma-app && git pull && cd server && '
        'dart pub get && sudo systemctl stop luma-sync && '
        'dart compile exe bin/luma_server.dart -o luma_server && '
        'sudo systemctl start luma-sync && '
        'sudo systemctl status luma-sync';

    final script = 'echo \$\$ > "${pidFile.path}" && '
        '{ $deployCmd; } > "${logFile.path}" 2>&1; '
        'rm -f "${pidFile.path}"';

    try {
      await Process.start(
        'setsid',
        ['bash', '-c', script],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      return _error(500, 'deploy_failed',
          'Could not start the deploy process: $e');
    }

    return _json(200, {'started': true});
  }

  /// Returns the current deploy log contents and whether the deploy process
  /// is still running. Polled by the Control panel's deploy button JS.
  Future<Response> _adminDeployStatus(Request request) async {
    final logFile = File('${config.dataDir}/deploy.log');
    final pidFile = File('${config.dataDir}/deploy.pid');

    int? pid;
    if (await pidFile.exists()) {
      pid = int.tryParse((await pidFile.readAsString()).trim());
    }
    final running = pid != null && _isProcessAlive(pid);

    String log = '';
    if (await logFile.exists()) {
      try {
        log = await logFile.readAsString();
      } catch (_) {}
    }

    return _json(200, {'running': running, 'log': log});
  }

  /// Best-effort check whether a process is still alive (POSIX `kill -0`).
  bool _isProcessAlive(int pid) {
    try {
      final result = Process.runSync('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Response _adminDashboard(Request request) {
    final stats = _adminStatsJson();
    final users = store.usersById.values.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    final key = request.url.queryParameters['key'] ?? '';

    String fmtBytes(int bytes) {
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      var value = bytes.toDouble();
      var unit = 0;
      while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
      }
      return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
    }

    String fmtDate(int? ms) {
      if (ms == null) return '—';
      final d = DateTime.fromMillisecondsSinceEpoch(ms).toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)} UTC';
    }

    const planLabels = {
      'core': 'Core (Free)',
      'orbit': 'Orbit (\$2/mo)',
      'nova': 'Nova (\$5/mo)',
    };

    final rows = users.map((u) {
      final used = store.usedBytes(u.id);
      final pct = u.quotaBytes > 0
          ? (used / u.quotaBytes * 100).clamp(0, 100)
          : 0.0;
      final statusColor = u.status == 'active' ? '#7ee08a' : '#e0c87e';
      final action = u.isPending
          ? '<form method="post" action="/admin/verify?key=${Uri.encodeQueryComponent(key)}" '
              'style="margin:0" onsubmit="return confirm(\'Manually verify '
              '${_htmlEscape(u.email)}? This skips email verification.\')">'
              '<input type="hidden" name="email" value="${_htmlEscape(u.email)}">'
              '<button type="submit" style="background:#8a7ee0;color:#161320;'
              'border:none;border-radius:6px;padding:4px 10px;font-size:12px;'
              'font-weight:600;cursor:pointer">Verify</button>'
              '</form>'
          : '';
      return '<tr>'
          '<td>${_htmlEscape(u.email)}</td>'
          '<td><span style="color:$statusColor">${_htmlEscape(u.status)}</span></td>'
          '<td>${_htmlEscape(planLabels[u.planId] ?? u.planId)}</td>'
          '<td>'
          '<div style="background:#241f33;border-radius:4px;overflow:hidden;width:120px;height:8px;display:inline-block;vertical-align:middle;margin-right:8px">'
          '<div style="background:#8a7ee0;height:100%;width:${pct.toStringAsFixed(0)}%"></div>'
          '</div>'
          '<span style="font-size:12px;color:#a49fb8">${fmtBytes(used)} / ${fmtBytes(u.quotaBytes)} (${pct.toStringAsFixed(0)}%)</span>'
          '</td>'
          '<td>${fmtDate(u.createdAtMs)}</td>'
          '<td>${fmtDate(u.lastLoginAtMs)}</td>'
          '<td>$action</td>'
          '</tr>';
    }).join();

    final subscriptionRows = users.where((u) => u.planId != kDefaultPlanId).map((u) {
      final label = planLabels[u.planId] ?? u.planId;
      return '<tr>'
          '<td>${_htmlEscape(u.email)}</td>'
          '<td>${_htmlEscape(label)}</td>'
          '<td><form method="post" action="/admin/plan?key=${Uri.encodeQueryComponent(key)}" '
          'style="margin:0" onsubmit="return confirm(\'Remove '
          '${_htmlEscape(u.email)}\\\'s $label plan? They revert to Core.\')">'
          '<input type="hidden" name="email" value="${_htmlEscape(u.email)}">'
          '<input type="hidden" name="planId" value="$kDefaultPlanId">'
          '<button type="submit" style="background:transparent;color:#e07e7e;'
          'border:1px solid #402c2c;border-radius:6px;padding:4px 10px;'
          'font-size:12px;cursor:pointer">Remove</button>'
          '</form></td>'
          '</tr>';
    }).join();

    final planOptions = kPlanQuotaBytes.keys.map((id) {
      final selected = id == 'orbit' ? ' selected' : '';
      return '<option value="$id"$selected>${_htmlEscape(planLabels[id] ?? id)}</option>';
    }).join();

    final activityCutoff = DateTime.now().millisecondsSinceEpoch -
        const Duration(hours: 24).inMilliseconds;
    final recentActivity = store.activity
        .where((a) => a.createdAtMs >= activityCutoff)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    const activityLabels = {
      'account_registered': 'Registered',
      'account_verified': 'Verified',
      'login': 'Login',
      'account_deleted': 'Account deleted',
      'admin_verified': 'Admin verified',
      'plan_granted': 'Plan granted',
    };

    final activityRows = recentActivity.map((a) {
      return '<tr>'
          '<td>${fmtDate(a.createdAtMs)}</td>'
          '<td>${_htmlEscape(activityLabels[a.type] ?? a.type)}</td>'
          '<td>${_htmlEscape(a.message)}</td>'
          '</tr>';
    }).join();

    final body = '<!doctype html><html><head><meta charset="utf-8">'
        '<title>luma admin</title>'
        '<style>body{background:#161320;color:#e8e4f3;font-family:system-ui,'
        'sans-serif;margin:0;padding:32px}h1{font-size:20px;margin:0 0 24px}'
        'h2{font-size:15px;margin:0 0 16px;color:#e8e4f3}'
        '.stats{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:28px}'
        '.stat{background:#1e1a2b;border-radius:8px;padding:16px 20px;min-width:140px}'
        '.stat .n{font-size:22px;font-weight:600}.stat .l{font-size:12px;'
        'color:#a49fb8;margin-top:4px}table{border-collapse:collapse;width:100%;'
        'font-size:13px}th{text-align:left;color:#a49fb8;font-weight:500;'
        'padding:8px 12px;border-bottom:1px solid #2c2640}'
        'td{padding:8px 12px;border-bottom:1px solid #201c2c}'
        '.tabs{display:flex;gap:8px;margin-bottom:24px}'
        '.tab-btn{background:#1e1a2b;color:#a49fb8;border:1px solid #2c2640;'
        'border-radius:8px;padding:8px 16px;font-size:13px;cursor:pointer;'
        'font-family:inherit}'
        '.tab-btn.active{background:#8a7ee0;color:#161320;border-color:#8a7ee0;'
        'font-weight:600}'
        '.tab-panel{display:none}.tab-panel.active{display:block}'
        '.product-form{display:flex;gap:10px;flex-wrap:wrap;align-items:center;'
        'margin-bottom:28px}'
        '.product-form select,.product-form input{background:#1e1a2b;'
        'color:#e8e4f3;border:1px solid #2c2640;border-radius:8px;'
        'padding:8px 12px;font-size:13px;font-family:inherit}'
        '.product-form button{background:#8a7ee0;color:#161320;border:none;'
        'border-radius:8px;padding:8px 16px;font-size:13px;font-weight:600;'
        'cursor:pointer}'
        '.range-tabs{display:flex;gap:8px;margin-bottom:16px}'
        '.range-btn{background:#1e1a2b;color:#a49fb8;border:1px solid #2c2640;'
        'border-radius:8px;padding:6px 14px;font-size:13px;cursor:pointer;'
        'font-family:inherit}'
        '.range-btn.active{background:#8a7ee0;color:#161320;border-color:#8a7ee0;'
        'font-weight:600}'
        '.metrics-grid{display:flex;gap:16px;flex-wrap:wrap}'
        '.metric-card{background:#1e1a2b;border-radius:8px;padding:16px 20px;'
        'min-width:240px;flex:1}'
        '.metric-title{font-size:12px;color:#a49fb8;margin-bottom:8px}'
        '.metric-value{font-size:16px;font-weight:600;margin-top:8px}'
        'canvas{display:block;width:100%;height:120px}</style>'
        '</head><body>'
        '<h1>luma admin</h1>'
        '<div class="stats">'
        '<div class="stat"><div class="n">${stats['totalAccounts']}</div><div class="l">Total accounts</div></div>'
        '<div class="stat"><div class="n">${stats['activeAccounts']}</div><div class="l">Active</div></div>'
        '<div class="stat"><div class="n">${stats['pendingAccounts']}</div><div class="l">Pending</div></div>'
        '<div class="stat"><div class="n">${fmtBytes(stats['usedBytesTotal'] as int)}</div><div class="l">Storage used</div></div>'
        '<div class="stat"><div class="n">${fmtBytes(stats['quotaBytesTotal'] as int)}</div><div class="l">Storage capacity</div></div>'
        '<div class="stat"><div class="n">${recentActivity.length}</div><div class="l">Activity (24h)</div></div>'
        '</div>'
        '<div class="tabs">'
        '<button class="tab-btn" data-tab="users">Users</button>'
        '<button class="tab-btn" data-tab="products">Products</button>'
        '<button class="tab-btn" data-tab="activity">Activity</button>'
        '<button class="tab-btn" data-tab="metrics">Metrics</button>'
        '<button class="tab-btn" data-tab="control">Control panel</button>'
        '</div>'
        '<div class="tab-panel" id="panel-users">'
        '<table><thead><tr><th>Email</th><th>Status</th><th>Plan</th>'
        '<th>Storage</th><th>Created</th><th>Last login</th><th></th></tr></thead>'
        '<tbody>$rows</tbody></table>'
        '</div>'
        '<div class="tab-panel" id="panel-products">'
        '<h2>Grant a plan</h2>'
        '<form class="product-form" method="post" action="/admin/plan?key=${Uri.encodeQueryComponent(key)}">'
        '<select name="planId">$planOptions</select>'
        '<input type="email" name="email" placeholder="user@example.com" required>'
        '<button type="submit">Grant</button>'
        '</form>'
        '<h2>Active subscriptions</h2>'
        '<table><thead><tr><th>Email</th><th>Plan</th><th></th></tr></thead>'
        '<tbody>${subscriptionRows.isEmpty ? '<tr><td colspan="3" style="color:#a49fb8">No paid subscriptions yet.</td></tr>' : subscriptionRows}</tbody></table>'
        '</div>'
        '<div class="tab-panel" id="panel-activity">'
        '<h2>Last 24 hours</h2>'
        '<table><thead><tr><th>Time</th><th>Type</th><th>Detail</th></tr></thead>'
        '<tbody>${activityRows.isEmpty ? '<tr><td colspan="3" style="color:#a49fb8">No activity in the last 24 hours.</td></tr>' : activityRows}</tbody></table>'
        '</div>'
        '<div class="tab-panel" id="panel-metrics">'
        '<div id="metricsUnsupported" style="display:none;color:#a49fb8;'
        'font-size:13px">Live metrics aren\'t available on this server\'s '
        'OS/platform.</div>'
        '<div class="range-tabs" id="rangeTabs">'
        '<button class="range-btn" data-range="minute">1 minute</button>'
        '<button class="range-btn" data-range="hour">1 hour</button>'
        '<button class="range-btn" data-range="day">24 hours</button>'
        '<button class="range-btn" data-range="week">1 week</button>'
        '</div>'
        '<div class="metrics-grid" id="metricsGrid">'
        '<div class="metric-card"><div class="metric-title">CPU</div>'
        '<canvas id="cpuGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="cpuValue">–</div></div>'
        '<div class="metric-card"><div class="metric-title">RAM</div>'
        '<canvas id="ramGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="ramValue">–</div></div>'
        '<div class="metric-card"><div class="metric-title">Network '
        '(<span style="color:#8a7ee0">&#8595; down</span> / '
        '<span style="color:#7ee08a">&#8593; up</span>)</div>'
        '<canvas id="netGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="netValue">–</div></div>'
        '<div class="metric-card"><div class="metric-title">SSD '
        '(<span style="color:#8a7ee0">&#8595; read</span> / '
        '<span style="color:#7ee08a">&#8593; write</span>)</div>'
        '<canvas id="diskGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="diskValue">–</div></div>'
        '</div>'
        '</div>'
        '<div class="tab-panel" id="panel-control">'
        '<h2>Groceries database</h2>'
        '<div class="product-form">'
        '<form method="post" action="/admin/groceries/sync?key=${Uri.encodeQueryComponent(key)}" style="margin:0">'
        '<button type="submit">Sync all markets</button></form>'
        '<form method="post" action="/admin/groceries/sync?key=${Uri.encodeQueryComponent(key)}" style="margin:0">'
        '<input type="hidden" name="market" value="jumbo">'
        '<button type="submit" style="background:#1e1a2b;color:#a49fb8;border:1px solid #2c2640;font-weight:500">Sync Jumbo</button></form>'
        '<form method="post" action="/admin/groceries/sync?key=${Uri.encodeQueryComponent(key)}" style="margin:0">'
        '<input type="hidden" name="market" value="ah">'
        '<button type="submit" style="background:#1e1a2b;color:#a49fb8;border:1px solid #2c2640;font-weight:500">Sync Albert Heijn</button></form>'
        '<form method="post" action="/admin/groceries/sync?key=${Uri.encodeQueryComponent(key)}" style="margin:0">'
        '<input type="hidden" name="market" value="lidl">'
        '<button type="submit" style="background:#1e1a2b;color:#a49fb8;border:1px solid #2c2640;font-weight:500">Sync Lidl</button></form>'
        '</div>'
        '<div id="groceriesSummary" style="color:#a49fb8;font-size:13px;'
        'margin-bottom:16px">Loading groceries status…</div>'
        '<h2>Recent syncs</h2>'
        '<table><thead><tr><th>Market</th><th>Status</th><th>Started</th>'
        '<th>Finished</th><th>Checked</th><th>Added</th><th>Updated</th>'
        '<th>Failed</th><th>Error</th></tr></thead>'
        '<tbody id="groceriesSyncRows">'
        '<tr><td colspan="9" style="color:#a49fb8">Loading…</td></tr>'
        '</tbody></table>'
        '<h2>Server update</h2>'
        '<div class="product-form">'
        '<button id="deployBtn" type="button" style="background:#8a7ee0;'
        'color:#161320;border:none;border-radius:8px;padding:8px 16px;'
        'font-size:13px;font-weight:600;cursor:pointer">'
        'Update &amp; restart server</button>'
        '</div>'
        '<div id="deployStatus" style="color:#a49fb8;font-size:13px;'
        'margin-bottom:12px"></div>'
        '<pre id="deployLog" style="background:#1e1a2b;border-radius:8px;'
        'padding:16px;font-size:12px;max-height:400px;overflow:auto;'
        'white-space:pre-wrap;word-break:break-all;display:none"></pre>'
        '</div>'
        '<script>$_adminTabScript</script>'
        '<script>$_adminMetricsScript</script>'
        '<script>$_adminGroceriesScript</script>'
        '<script>$_adminDeployScript</script>'
        '</body></html>';

    return Response(200,
        body: body, headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  /// Tiny vanilla-JS tab switcher for the Users / Products / Metrics panels,
  /// keeping the selected tab in the URL hash so it survives a form POST's
  /// redirect back to the page (see _adminSetPlan/_adminVerifyUser).
  static const _adminTabScript = r'''
(function () {
  const buttons = document.querySelectorAll('.tab-btn');
  const panels = {
    users: document.getElementById('panel-users'),
    products: document.getElementById('panel-products'),
    activity: document.getElementById('panel-activity'),
    metrics: document.getElementById('panel-metrics'),
    control: document.getElementById('panel-control'),
  };
  function activate(tab) {
    if (!panels[tab]) tab = 'users';
    buttons.forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    Object.entries(panels).forEach(([k, el]) => el.classList.toggle('active', k === tab));
  }
  buttons.forEach((b) => b.addEventListener('click', () => {
    activate(b.dataset.tab);
    history.replaceState(null, '', '#' + b.dataset.tab);
  }));
  activate((location.hash || '#users').slice(1));
})();
''';

  /// Control panel tab: loads the groceries server's sync status through
  /// this server's /admin/groceries/status proxy and renders it; refreshes
  /// every 3 seconds while a sync is running so the counters fill in live.
  static const _adminGroceriesScript = r'''
(function () {
  const key = new URLSearchParams(location.search).get('key') || '';
  const summary = document.getElementById('groceriesSummary');
  const rows = document.getElementById('groceriesSyncRows');
  if (!summary || !rows) return;

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  function render(data) {
    if (data.error) {
      summary.textContent = 'Could not reach the groceries server ('
        + (data.message || data.error) + ')';
      rows.innerHTML = '<tr><td colspan="9" style="color:#a49fb8">—</td></tr>';
      return false;
    }
    if (!data.configured) {
      summary.textContent = 'Not connected: set LUMA_GROCERIES_ADMIN_KEY '
        + '(and optionally LUMA_GROCERIES_URL) in this server\'s .env, '
        + 'then restart.';
      rows.innerHTML = '<tr><td colspan="9" style="color:#a49fb8">—</td></tr>';
      return false;
    }
    const s = data.status;
    summary.innerHTML = '<strong>' + s.products.total + '</strong> products ('
      + s.products.available + ' available), '
      + s.priceSnapshots + ' price snapshots'
      + (s.running ? ' — <strong>sync running…</strong>' : '');
    rows.innerHTML = s.syncs.length === 0
      ? '<tr><td colspan="9" style="color:#a49fb8">No syncs yet.</td></tr>'
      : s.syncs.map((r) => {
          const color = r.status === 'success' ? '#7ee08a'
            : r.status === 'running' ? '#e0c87e' : '#e07e7e';
          return '<tr><td>' + esc(r.marketName) + '</td>'
            + '<td><span style="color:' + color + '">' + esc(r.status) + '</span></td>'
            + '<td>' + esc(r.startedAt) + '</td>'
            + '<td>' + esc(r.finishedAt || '—') + '</td>'
            + '<td>' + r.checked + '</td><td>' + r.added + '</td>'
            + '<td>' + r.updated + '</td><td>' + r.failed + '</td>'
            + '<td>' + esc(r.error) + '</td></tr>';
        }).join('');
    return s.running;
  }

  let timer = null;
  function load() {
    fetch('/admin/groceries/status?key=' + encodeURIComponent(key))
      .then((r) => r.json())
      .then((data) => {
        const running = render(data);
        clearTimeout(timer);
        if (running) timer = setTimeout(load, 3000);
      })
      .catch(() => {
        summary.textContent = 'Could not reach the groceries server.';
      });
  }
  load();
})();
''';

  /// Control panel tab: the "Update & restart server" button POSTs to
  /// /admin/deploy, then polls /admin/deploy/status every 2s to stream the
  /// deploy log into the <pre> below the button. The poll keeps going even
  /// after the server restarts (the fetch will fail mid-restart and resume
  /// once the new process is up), so the operator sees the final
  /// `systemctl status` output without manually refreshing.
  static const _adminDeployScript = r'''
(function () {
  const key = new URLSearchParams(location.search).get('key') || '';
  const btn = document.getElementById('deployBtn');
  const status = document.getElementById('deployStatus');
  const log = document.getElementById('deployLog');
  if (!btn || !status || !log) return;

  var timer = null;
  var sawRunning = false;

  function setStatus(text, color) {
    status.textContent = text;
    status.style.color = color || '#a49fb8';
  }

  function poll() {
    fetch('/admin/deploy/status?key=' + encodeURIComponent(key))
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.log) {
          log.style.display = 'block';
          log.textContent = data.log;
          log.scrollTop = log.scrollHeight;
        }
        if (data.running) {
          sawRunning = true;
          btn.disabled = true;
          btn.style.opacity = '0.5';
          btn.style.cursor = 'not-allowed';
          setStatus('Deploying… (the server will restart briefly)', '#e0c87e');
          timer = setTimeout(poll, 2000);
        } else if (sawRunning) {
          btn.disabled = false;
          btn.style.opacity = '';
          btn.style.cursor = '';
          var hasLog = !!data.log;
          var success = hasLog && /Active: active \(running\)/.test(data.log);
          setStatus(
            success ? 'Deploy complete — server is running.' :
            hasLog ? 'Deploy finished — check the log above.' :
                     'Deploy process ended.',
            success ? '#7ee08a' : '#a49fb8');
        }
      })
      .catch(function () {
        if (sawRunning) {
          setStatus('Server restarting… waiting for it to come back.', '#e0c87e');
          timer = setTimeout(poll, 2000);
        }
      });
  }

  btn.addEventListener('click', function () {
    if (btn.disabled) return;
    if (!confirm('This will git pull, recompile, and restart the luma-sync '
        + 'service. The server will be briefly unavailable. Continue?')) return;
    log.style.display = 'block';
    log.textContent = '';
    setStatus('Starting deploy…', '#e0c87e');
    btn.disabled = true;
    btn.style.opacity = '0.5';
    btn.style.cursor = 'not-allowed';
    fetch('/admin/deploy?key=' + encodeURIComponent(key), { method: 'POST' })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.error) {
          btn.disabled = false;
          btn.style.opacity = '';
          btn.style.cursor = '';
          setStatus(data.message || data.error, '#e07e7e');
          return;
        }
        sawRunning = true;
        poll();
      })
      .catch(function () {
        btn.disabled = false;
        btn.style.opacity = '';
        btn.style.cursor = '';
        setStatus('Could not start the deploy.', '#e07e7e');
      });
  });

  poll();
})();
''';

  /// Vanilla JS (no external deps, per the self-contained-dashboard style):
  /// polls /admin/metrics every 2s for a live reading, and separately loads
  /// persisted history from /admin/metrics/history for whichever range is
  /// selected (1 minute / 1 hour / 24 hours / 1 week) so the graphs survive
  /// a page reload or server restart instead of starting blank every time.
  static const _adminMetricsScript = r'''
(function () {
  const key = new URLSearchParams(location.search).get('key') || '';
  const RANGE_CAPS = { minute: 45, hour: 60, day: 24, week: 24 * 7 };
  let currentRange = 'minute';
  let cap = RANGE_CAPS[currentRange];
  const history = { cpu: [], ram: [], rx: [], tx: [], diskRead: [], diskWrite: [] };

  function push(arr, v) {
    arr.push(v);
    if (arr.length > cap) arr.shift();
  }

  function fmtBytes(v) {
    if (v == null) return '–';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let i = 0, val = v;
    while (val >= 1024 && i < units.length - 1) { val /= 1024; i++; }
    return val.toFixed(val >= 10 || i === 0 ? 0 : 1) + ' ' + units[i];
  }

  function fmtRate(v) {
    return v == null ? '–' : fmtBytes(v) + '/s';
  }

  // Backs each canvas with a devicePixelRatio-scaled bitmap (drawn in CSS
  // pixel coordinates via ctx.scale) so lines stay crisp instead of being
  // upscaled/blurred by the browser. Returns null while the canvas isn't
  // visible (e.g. its tab isn't active — panels start display:none, but
  // polling runs in the background regardless): getBoundingClientRect is
  // 0×0 there, and there's no CSS size to size the bitmap to yet. Skipping
  // the draw in that case (rather than falling back to some other size) is
  // what makes this self-correcting — the very first draw AFTER the tab
  // becomes visible sizes the bitmap correctly, once, with no stale cache
  // or compounding resize to work around.
  function ensureHiDPI(canvas) {
    const rect = canvas.getBoundingClientRect();
    if (rect.width < 1 || rect.height < 1) return null;
    if (canvas._ctx && canvas._cssW === rect.width && canvas._cssH === rect.height) {
      return canvas._ctx;
    }
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);
    canvas._cssW = rect.width;
    canvas._cssH = rect.height;
    canvas._ctx = ctx;
    return ctx;
  }

  function drawGraph(canvas, series, maxValue) {
    if (!canvas) return;
    const ctx = ensureHiDPI(canvas);
    if (!ctx) return; // hidden right now — history keeps accumulating either way
    const w = canvas._cssW, h = canvas._cssH;
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = '#2c2640';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let i = 1; i <= 3; i++) {
      const y = Math.round(h * i / 4) + 0.5;
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
    }
    ctx.stroke();

    let max = maxValue;
    if (max == null) {
      max = 1;
      for (const s of series) {
        for (const v of s.values) max = Math.max(max, v);
      }
    }

    for (const s of series) {
      const values = s.values;
      if (values.length < 2) continue;
      const pts = values.map((v, i) => ({
        x: (w * i) / (values.length - 1),
        y: h - (Math.min(v, max) / max) * h,
      }));
      ctx.strokeStyle = s.color;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      // Smooth the polyline into a curve by drawing a quadratic segment
      // through the midpoint of each pair of points — avoids the jagged,
      // "low-res" look of a raw point-to-point line with no extra libs.
      for (let i = 1; i < pts.length - 1; i++) {
        const mx = (pts[i].x + pts[i + 1].x) / 2;
        const my = (pts[i].y + pts[i + 1].y) / 2;
        ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
      }
      ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
      ctx.stroke();
    }
  }

  function redrawAll() {
    drawGraph(document.getElementById('cpuGraph'),
        [{ values: history.cpu, color: '#8a7ee0' }], 100);
    drawGraph(document.getElementById('ramGraph'),
        [{ values: history.ram, color: '#8a7ee0' }], 100);
    drawGraph(document.getElementById('netGraph'), [
      { values: history.rx, color: '#8a7ee0' },
      { values: history.tx, color: '#7ee08a' },
    ], null);
    drawGraph(document.getElementById('diskGraph'), [
      { values: history.diskRead, color: '#8a7ee0' },
      { values: history.diskWrite, color: '#7ee08a' },
    ], null);
  }

  // Rebuilds the `history` arrays (as drawn on the graphs) from a server
  // history payload — same derived fields poll() computes per live sample
  // (RAM as a percentage, etc.), just applied to a whole point list at once.
  function seedHistory(points) {
    history.cpu = points.map((p) => p.cpuPercent).filter((v) => v != null);
    history.ram = points
        .filter((p) => p.ramUsedBytes != null && p.ramTotalBytes)
        .map((p) => (p.ramUsedBytes / p.ramTotalBytes) * 100);
    history.rx = points.map((p) => p.netRxBytesPerSec).filter((v) => v != null);
    history.tx = points.map((p) => p.netTxBytesPerSec).filter((v) => v != null);
    history.diskRead =
        points.map((p) => p.diskReadBytesPerSec).filter((v) => v != null);
    history.diskWrite =
        points.map((p) => p.diskWriteBytesPerSec).filter((v) => v != null);
  }

  async function loadRange(range) {
    currentRange = range;
    cap = RANGE_CAPS[range];
    document.querySelectorAll('.range-btn').forEach((b) =>
        b.classList.toggle('active', b.dataset.range === range));
    try {
      const res = await fetch('/admin/metrics/history?range=' + range +
          '&key=' + encodeURIComponent(key));
      if (res.ok) {
        const data = await res.json();
        seedHistory(data.points || []);
        redrawAll();
      }
    } catch (e) {}
  }

  document.querySelectorAll('.range-btn').forEach((b) =>
      b.addEventListener('click', () => loadRange(b.dataset.range)));

  async function poll() {
    let res;
    try {
      res = await fetch('/admin/metrics?key=' + encodeURIComponent(key));
    } catch (e) {
      return;
    }
    if (!res.ok) return;
    const m = await res.json();

    if (!m.platformSupported) {
      document.getElementById('metricsUnsupported').style.display = 'block';
      document.getElementById('metricsGrid').style.display = 'none';
      return;
    }

    if (m.cpuPercent != null) {
      document.getElementById('cpuValue').textContent = m.cpuPercent.toFixed(1) + '%';
    }
    if (m.ramUsedBytes != null && m.ramTotalBytes) {
      document.getElementById('ramValue').textContent =
          fmtBytes(m.ramUsedBytes) + ' / ' + fmtBytes(m.ramTotalBytes);
    }
    if (m.netRxBytesPerSec != null && m.netTxBytesPerSec != null) {
      document.getElementById('netValue').textContent =
          '↓ ' + fmtRate(m.netRxBytesPerSec) + '   ↑ ' + fmtRate(m.netTxBytesPerSec);
    }
    document.getElementById('diskValue').textContent =
        (m.diskReadBytesPerSec != null && m.diskWriteBytesPerSec != null)
            ? '↓ ' + fmtRate(m.diskReadBytesPerSec) + '   ↑ ' + fmtRate(m.diskWriteBytesPerSec)
            : 'Not available on this host';

    // The server records this same poll into its own history (see
    // Api._adminMetrics), so the finest ("1 minute") view can just append
    // the live reading locally. Coarser ranges are re-fetched wholesale
    // instead, since a single new sample barely moves a minute/hour bucket.
    if (currentRange === 'minute') {
      if (m.cpuPercent != null) push(history.cpu, m.cpuPercent);
      if (m.ramUsedBytes != null && m.ramTotalBytes) {
        push(history.ram, (m.ramUsedBytes / m.ramTotalBytes) * 100);
      }
      if (m.netRxBytesPerSec != null && m.netTxBytesPerSec != null) {
        push(history.rx, m.netRxBytesPerSec);
        push(history.tx, m.netTxBytesPerSec);
      }
      if (m.diskReadBytesPerSec != null && m.diskWriteBytesPerSec != null) {
        push(history.diskRead, m.diskReadBytesPerSec);
        push(history.diskWrite, m.diskWriteBytesPerSec);
      }
      redrawAll();
    }
  }

  loadRange('minute');
  poll();
  setInterval(poll, 2000);
  setInterval(() => {
    if (currentRange !== 'minute') loadRange(currentRange);
  }, 30000);
})();
''';

  // ---- Helpers -------------------------------------------------------------

  /// PBKDF2 over the client's already-derived auth key. Kept `async` so the
  /// call sites stay unchanged; the work itself is fast (20k iterations).
  Future<Uint8List> _hashAuthKey(Uint8List authKey, Uint8List salt) async =>
      pbkdf2Sha256(authKey, salt, _serverHashIterations, 32);

  /// Creates a session and returns (token, expiresAtMs). Caller holds the lock.
  Future<(String, int)> _createSession(StoredUser user) async {
    final token = base64UrlEncode(randomBytes(32)).replaceAll('=', '');
    final tokenHash = c.sha256.convert(utf8.encode(token)).toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + config.tokenTtl.inMilliseconds;
    store.pruneSessions();
    store.sessionsByTokenHash[tokenHash] = StoredSession(
      tokenHash: tokenHash,
      userId: user.id,
      createdAtMs: now,
      expiresAtMs: expires,
    );
    await store.saveSessions();
    return (token, expires);
  }

  /// Generates a fresh verification token, stores only its hash against the
  /// user (mirroring how session tokens are handled), and returns the raw
  /// token to send by email. Caller holds the store lock.
  Future<String> _issueVerificationToken(StoredUser user) async {
    final token = base64UrlEncode(randomBytes(32)).replaceAll('=', '');
    user.verificationTokenHash =
        c.sha256.convert(utf8.encode(token)).toString();
    user.verificationExpiresAtMs =
        DateTime.now().millisecondsSinceEpoch + config.verificationTtl.inMilliseconds;
    return token;
  }

  /// Best-effort send; a mail outage should not make registration fail
  /// outright since the user can always request a fresh link.
  Future<void> _sendVerificationEmail(StoredUser user, String token) async {
    try {
      await mailer.sendVerificationEmail(toEmail: user.email, token: token);
    } catch (e) {
      stderr.writeln(
          '[luma] could not send verification email to ${user.email}: $e');
    }
  }

  static String? _nullIfBlank(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String? _normalizeEmail(Object? raw) {
    if (raw is! String) return null;
    final email = raw.trim().toLowerCase();
    if (email.length > 254 || !emailPattern.hasMatch(email)) return null;
    return email;
  }

  static Uint8List? _decodeB64(Object? raw,
      {required int minLen, required int maxLen}) {
    if (raw is! String || raw.length > 512) return null;
    try {
      final bytes = base64Decode(raw);
      if (bytes.length < minLen || bytes.length > maxLen) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _readJson(Request request) async {
    final declared = request.contentLength ?? -1;
    if (declared > _maxJsonBody) {
      throw const FormatException('body too large');
    }
    final body = await request
        .readAsString()
        .timeout(const Duration(seconds: 15), onTimeout: () => '');
    if (body.length > _maxJsonBody) throw const FormatException('body too large');
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected JSON object');
    }
    return decoded;
  }

  static Response _json(int status, Map<String, dynamic> body) =>
      Response(status,
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});

  static Response _error(int status, String code, String message,
          {Map<String, dynamic>? extra}) =>
      _json(status, {'error': code, 'message': message, ...?extra});
}

/// Result type for [Api._parseSharedEventBody]: either a validated set of
/// fields or a single validation error to surface to the client.
class _ParsedSharedEvent {
  const _ParsedSharedEvent({
    required this.title,
    required this.description,
    required this.location,
    required this.startMs,
    required this.endMs,
    required this.allDay,
    required this.color,
    required this.recurrence,
    required this.recurrenceEndMs,
    required this.reminderMinutes,
    required this.visibility,
    required this.visibleMemberUserIds,
  });

  final String title;
  final String? description;
  final String? location;
  final int startMs;
  final int endMs;
  final bool allDay;
  final int color;
  final String recurrence;
  final int? recurrenceEndMs;
  final int? reminderMinutes;
  final String visibility;
  final List<String> visibleMemberUserIds;
}

class _ParseError {
  const _ParseError(this.code, this.message);
  final String code;
  final String message;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

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
  Api(this.store, this.config, this.mailer)
      : _authLimiter = RateLimiter(
            maxRequests: 15, window: const Duration(minutes: 10)),
        _generalLimiter = RateLimiter(
            maxRequests: 300, window: const Duration(minutes: 1)),
        _resendLimiter = RateLimiter(
            maxRequests: 3, window: const Duration(minutes: 15));

  final Store store;
  final ServerConfig config;
  final Mailer mailer;
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
      ..get('/api/v1/sync/<collection>', _requireAuth(_getBlob))
      ..put('/api/v1/sync/<collection>', _requireAuth(_putBlob))
      ..delete('/api/v1/sync/<collection>', _requireAuth(_deleteBlobHandler))
      ..get('/admin', _requireAdmin(_adminDashboard))
      ..get('/admin/users', _requireAdmin(_adminUsers))
      ..get('/admin/stats', _requireAdmin(_adminStats))
      ..get('/admin/metrics', _requireAdmin(_adminMetrics))
      ..post('/admin/verify', _requireAdmin(_adminVerifyUser))
      ..post('/admin/plan', _requireAdmin(_adminSetPlan));

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
        final token = await _createSession(user);
        return _json(201, {
          'token': token.$1,
          'expiresAtMs': token.$2,
          'quotaBytes': user.quotaBytes,
        });
      }

      final verificationToken = await _issueVerificationToken(user);
      await store.saveUsers();
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
      store.usersById.remove(user.id);
      store.userIdByEmail.remove(user.email.toLowerCase());
      store.sessionsByTokenHash.removeWhere((_, s) => s.userId == user.id);
      store.collectionsByUser.remove(user.id);
      await store.deleteUserData(user.id);
      await store.saveUsers();
      await store.saveSessions();
      await store.saveCollections();
      return _json(200, {'ok': true});
    });
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
    return _json(200, metrics.toJson());
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
      final key = request.url.queryParameters['key'];
      if (key != null) {
        return Response.found(
            '/admin?key=${Uri.encodeQueryComponent(key)}#products');
      }
      return _json(
          200, {'ok': true, 'planId': planId, 'quotaBytes': user.quotaBytes});
    });
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
        '</div>'
        '<div class="tabs">'
        '<button class="tab-btn" data-tab="users">Users</button>'
        '<button class="tab-btn" data-tab="products">Products</button>'
        '<button class="tab-btn" data-tab="metrics">Metrics</button>'
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
        '<div class="tab-panel" id="panel-metrics">'
        '<div id="metricsUnsupported" style="display:none;color:#a49fb8;'
        'font-size:13px">Live metrics aren\'t available on this server\'s '
        'OS/platform.</div>'
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
        '<script>$_adminTabScript</script>'
        '<script>$_adminMetricsScript</script>'
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
    metrics: document.getElementById('panel-metrics'),
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

  /// Vanilla JS (no external deps, per the self-contained-dashboard style):
  /// polls /admin/metrics every 2s and draws rolling line graphs on plain
  /// <canvas> elements.
  static const _adminMetricsScript = r'''
(function () {
  const key = new URLSearchParams(location.search).get('key') || '';
  const MAX_POINTS = 30;
  const history = { cpu: [], ram: [], rx: [], tx: [], diskRead: [], diskWrite: [] };

  function push(arr, v) {
    arr.push(v);
    if (arr.length > MAX_POINTS) arr.shift();
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
        x: (w * i) / (MAX_POINTS - 1),
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
      push(history.cpu, m.cpuPercent);
      document.getElementById('cpuValue').textContent = m.cpuPercent.toFixed(1) + '%';
      drawGraph(document.getElementById('cpuGraph'),
          [{ values: history.cpu, color: '#8a7ee0' }], 100);
    }

    if (m.ramUsedBytes != null && m.ramTotalBytes) {
      const pct = (m.ramUsedBytes / m.ramTotalBytes) * 100;
      push(history.ram, pct);
      document.getElementById('ramValue').textContent =
          fmtBytes(m.ramUsedBytes) + ' / ' + fmtBytes(m.ramTotalBytes);
      drawGraph(document.getElementById('ramGraph'),
          [{ values: history.ram, color: '#8a7ee0' }], 100);
    }

    if (m.netRxBytesPerSec != null && m.netTxBytesPerSec != null) {
      push(history.rx, m.netRxBytesPerSec);
      push(history.tx, m.netTxBytesPerSec);
      document.getElementById('netValue').textContent =
          '↓ ' + fmtRate(m.netRxBytesPerSec) + '   ↑ ' + fmtRate(m.netTxBytesPerSec);
      drawGraph(document.getElementById('netGraph'), [
        { values: history.rx, color: '#8a7ee0' },
        { values: history.tx, color: '#7ee08a' },
      ], null);
    }

    if (m.diskReadBytesPerSec != null && m.diskWriteBytesPerSec != null) {
      push(history.diskRead, m.diskReadBytesPerSec);
      push(history.diskWrite, m.diskWriteBytesPerSec);
      document.getElementById('diskValue').textContent =
          '↓ ' + fmtRate(m.diskReadBytesPerSec) + '   ↑ ' + fmtRate(m.diskWriteBytesPerSec);
      drawGraph(document.getElementById('diskGraph'), [
        { values: history.diskRead, color: '#8a7ee0' },
        { values: history.diskWrite, color: '#7ee08a' },
      ], null);
    } else {
      document.getElementById('diskValue').textContent = 'Not available on this host';
    }
  }

  poll();
  setInterval(poll, 2000);
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

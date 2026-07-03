import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'rate_limit.dart';
import 'store.dart';
import 'util.dart';

/// Server configuration, read from environment variables (see .env.example).
class ServerConfig {
  ServerConfig({
    required this.port,
    required this.dataDir,
    required this.allowRegistration,
    required this.quotaBytes,
    required this.maxBlobBytes,
    required this.tokenTtl,
    required this.corsOrigin,
    required this.trustProxy,
  });

  final int port;
  final String dataDir;
  final bool allowRegistration;
  final int quotaBytes;
  final int maxBlobBytes;
  final Duration tokenTtl;
  final String corsOrigin;
  final bool trustProxy;

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
      // 3 GiB per account by default.
      quotaBytes: intOf('LUMA_QUOTA_BYTES', 3 * 1024 * 1024 * 1024),
      // A single collection snapshot may not exceed this (protects disk/RAM).
      maxBlobBytes: intOf('LUMA_MAX_BLOB_BYTES', 256 * 1024 * 1024),
      tokenTtl: Duration(days: intOf('LUMA_TOKEN_TTL_DAYS', 90)),
      corsOrigin: env['LUMA_CORS_ORIGIN'] ?? '*',
      trustProxy: env['LUMA_TRUST_PROXY'] == 'true',
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
  Api(this.store, this.config)
      : _authLimiter = RateLimiter(
            maxRequests: 15, window: const Duration(minutes: 10)),
        _generalLimiter = RateLimiter(
            maxRequests: 300, window: const Duration(minutes: 1));

  final Store store;
  final ServerConfig config;
  final RateLimiter _authLimiter;
  final RateLimiter _generalLimiter;

  Handler get handler {
    final router = Router()
      ..get('/', _root)
      ..get('/health', _health)
      ..post('/api/v1/auth/params', _authParams)
      ..post('/api/v1/auth/register', _register)
      ..post('/api/v1/auth/login', _login)
      ..post('/api/v1/auth/logout', _requireAuth(_logout))
      ..post('/api/v1/auth/change', _requireAuth(_changePassword))
      ..get('/api/v1/account', _requireAuth(_accountInfo))
      ..post('/api/v1/account/delete', _requireAuth(_deleteAccount))
      ..get('/api/v1/sync/<collection>', _requireAuth(_getBlob))
      ..put('/api/v1/sync/<collection>', _requireAuth(_putBlob))
      ..delete('/api/v1/sync/<collection>', _requireAuth(_deleteBlobHandler));

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
      final user = StoredUser(
        id: base64UrlEncode(randomBytes(12)).replaceAll('=', ''),
        email: email,
        authHash: base64Encode(authHash),
        authSalt: base64Encode(authSalt),
        kdfSalt: base64Encode(kdfSalt),
        kdfIterations: iterations,
        quotaBytes: config.quotaBytes,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      store.usersById[user.id] = user;
      store.userIdByEmail[email] = user.id;
      await store.saveUsers();
      final token = await _createSession(user);
      return _json(201, {
        'token': token.$1,
        'expiresAtMs': token.$2,
        'quotaBytes': user.quotaBytes,
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

    return store.lock.synchronized(() async {
      final token = await _createSession(user);
      return _json(200, {
        'token': token.$1,
        'expiresAtMs': token.$2,
        'quotaBytes': user.quotaBytes,
      });
    });
  }

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

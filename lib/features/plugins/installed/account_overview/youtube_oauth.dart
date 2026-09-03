import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Raised when Google's OAuth endpoints answer with something the UI needs
/// to explain rather than swallow.
class YoutubeOAuthException implements Exception {
  YoutubeOAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class YoutubeTokenResult {
  const YoutubeTokenResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;

  /// Null on a refresh-grant response — Google does not reissue the refresh
  /// token itself when exchanging it for a new access token.
  final String? refreshToken;
  final DateTime expiresAt;
}

/// Drives Google's Authorization Code + PKCE flow for a "Desktop app" OAuth
/// client, entirely from this device.
///
/// luma has no backend of its own to catch Google's redirect, unlike the
/// app's own account sign-in (`lib/sync/sync_service.dart`), which polls a
/// luma-owned server instead of catching one directly. Google's "Desktop
/// app" client type allows any loopback port without pre-registering it, so
/// this binds an ephemeral one, waits for the single redirect request, and
/// tears the listener down immediately after.
class YoutubeOAuth {
  YoutubeOAuth({http.Client? client, Future<void> Function(String url)? openBrowser})
      : _client = client ?? http.Client(),
        _openBrowser = openBrowser ?? _defaultOpenInBrowser;

  final http.Client _client;

  /// Opens the consent URL. Injectable so a test can stand in for the system
  /// browser and drive the loopback listener itself, the same way
  /// `GithubApi`/`McContentRepository` inject their HTTP clients.
  final Future<void> Function(String url) _openBrowser;

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  /// Read-only channel data and read-only analytics — no monetary/revenue
  /// scope, which Google gates far more heavily than these two even for a
  /// personal-use app in Testing mode.
  static const scopes = [
    'https://www.googleapis.com/auth/youtube.readonly',
    'https://www.googleapis.com/auth/yt-analytics.readonly',
  ];

  void dispose() => _client.close();

  /// Runs the whole interactive flow: opens the consent screen in the
  /// system browser, catches the redirect on a loopback listener, and
  /// exchanges the resulting code for tokens.
  Future<YoutubeTokenResult> authorize({
    required String clientId,
    required String clientSecret,
  }) async {
    final verifier = _randomUrlSafe(64);
    final challenge = base64UrlEncode(
        sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final state = _randomUrlSafe(24);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://127.0.0.1:${server.port}/callback';
      final authUri = Uri.parse(_authEndpoint).replace(queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'access_type': 'offline',
        // Forces Google to hand back a refresh token even on a repeat
        // connect, which a bare `consent`-less request only does the first
        // time a scope is granted.
        'prompt': 'consent',
      });

      await _openBrowser(authUri.toString());
      final code = await _awaitRedirect(server, expectedState: state);
      return _exchangeCode(
        code: code,
        clientId: clientId,
        clientSecret: clientSecret,
        verifier: verifier,
        redirectUri: redirectUri,
      );
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> _awaitRedirect(
    HttpServer server, {
    required String expectedState,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final request = await server.first.timeout(
      timeout,
      onTimeout: () => throw YoutubeOAuthException(
        'Timed out waiting for Google to redirect back. Try connecting '
        'again.',
      ),
    );
    final params = request.uri.queryParameters;
    final code = params['code'];
    final state = params['state'];
    final error = params['error'];

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_landingPage(error == null && code != null));
    await request.response.close();

    if (error != null) {
      throw YoutubeOAuthException('Google declined the request: $error');
    }
    if (state != expectedState) {
      throw YoutubeOAuthException(
          "Google's response did not match this request.");
    }
    if (code == null || code.isEmpty) {
      throw YoutubeOAuthException(
          'Google did not return an authorization code.');
    }
    return code;
  }

  String _landingPage(bool success) => '''
<!doctype html><html><head><meta charset="utf-8"><title>luma</title>
<style>body{font-family:sans-serif;background:#0d0f14;color:#e6e8ee;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
div{text-align:center;padding:0 24px}</style></head><body><div>
<h2>${success ? "You're connected" : 'Something went wrong'}</h2>
<p>You can close this tab and go back to luma.</p></div></body></html>''';

  Future<YoutubeTokenResult> _exchangeCode({
    required String code,
    required String clientId,
    required String clientSecret,
    required String verifier,
    required String redirectUri,
  }) async {
    final response = await _client.post(
      Uri.parse(_tokenEndpoint),
      body: {
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    ).timeout(const Duration(seconds: 30));
    return _parseTokenResponse(response, requireRefreshToken: true);
  }

  /// Exchanges a refresh token for a new access token.
  Future<YoutubeTokenResult> refresh({
    required String clientId,
    required String clientSecret,
    required String refreshToken,
  }) async {
    final response = await _client.post(
      Uri.parse(_tokenEndpoint),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    ).timeout(const Duration(seconds: 30));
    return _parseTokenResponse(response, requireRefreshToken: false);
  }

  YoutubeTokenResult _parseTokenResponse(
    http.Response response, {
    required bool requireRefreshToken,
  }) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode != 200 || body == null) {
      final description = body?['error_description'] ?? body?['error'];
      throw YoutubeOAuthException(
        description != null
            ? 'Google rejected the request: $description'
            : 'Google returned HTTP ${response.statusCode}.',
      );
    }

    final accessToken = body['access_token'] as String?;
    final refreshToken = body['refresh_token'] as String?;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    if (accessToken == null || accessToken.isEmpty) {
      throw YoutubeOAuthException('Google did not return an access token.');
    }
    if (requireRefreshToken && (refreshToken == null || refreshToken.isEmpty)) {
      throw YoutubeOAuthException(
        "Google did not return a refresh token. Remove luma's access at "
        'myaccount.google.com/permissions and try connecting again.',
      );
    }
    return YoutubeTokenResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Best-effort revoke, called on disconnect. Failures are swallowed — the
  /// credential is being deleted locally regardless, and Google's own token
  /// expiry is the backstop.
  Future<void> revoke(String token) async {
    try {
      await _client
          .post(Uri.parse(_revokeEndpoint), body: {'token': token})
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Mirrors `ui/account_shared.dart`'s `openExternal` exactly, duplicated
  /// rather than imported: this file sits below the UI layer and a service
  /// reaching up into `ui/` to open a browser tab would invert that.
  static Future<void> _defaultOpenInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static String _randomUrlSafe(int length) {
    final rng = Random.secure();
    final bytes =
        Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

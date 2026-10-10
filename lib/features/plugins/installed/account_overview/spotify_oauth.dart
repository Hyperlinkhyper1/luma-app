import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/current_l.dart';

class SpotifyOAuthException implements Exception {
  const SpotifyOAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SpotifyTokens {
  const SpotifyTokens(this.accessToken, this.refreshToken, this.expiresAt);
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
}

class SpotifyOAuth {
  SpotifyOAuth({http.Client? client, Future<void> Function(Uri)? openBrowser})
    : _client = client ?? http.Client(),
      _openBrowser = openBrowser ?? _openExternal;

  final http.Client _client;
  final Future<void> Function(Uri) _openBrowser;

  static const scopes = [
    'user-top-read',
    'user-read-recently-played',
    'user-library-read',
    'playlist-read-private',
  ];

  void dispose() => _client.close();

  Future<SpotifyTokens> authorize(String clientId) async {
    final verifier = _random(64);
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    final state = _random(24);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8888);
    try {
      final redirect = 'http://127.0.0.1:${server.port}/callback';
      final uri = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirect,
        'scope': scopes.join(' '),
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'state': state,
      });
      await _openBrowser(uri);
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw SpotifyOAuthException(
          currentL.accountOverviewSpotifyOAuthTimedOut,
        ),
      );
      final params = request.uri.queryParameters;
      final valid =
          request.uri.path == '/callback' &&
          params['state'] == state &&
          params['code']?.isNotEmpty == true &&
          params['error'] == null;
      request.response
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><title>luma</title><p>${valid ? currentL.accountOverviewSpotifyConnectedPage : currentL.accountOverviewSpotifyFailedPage}</p>',
        );
      await request.response.close();
      if (params['error'] != null) {
        throw SpotifyOAuthException(
          currentL.accountOverviewSpotifyDeclined('${params['error']}'),
        );
      }
      if (!valid) {
        throw SpotifyOAuthException(
          currentL.accountOverviewSpotifyInvalidResponse,
        );
      }
      return _token({
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': params['code']!,
        'redirect_uri': redirect,
        'code_verifier': verifier,
      });
    } finally {
      await server.close(force: true);
    }
  }

  Future<SpotifyTokens> refresh(String clientId, String refreshToken) =>
      _token({
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      });

  Future<SpotifyTokens> _token(Map<String, String> body) async {
    final response = await _client
        .post(Uri.https('accounts.spotify.com', '/api/token'), body: body)
        .timeout(const Duration(seconds: 30));
    Map<String, dynamic> json;
    try {
      json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw SpotifyOAuthException(
        currentL.accountOverviewSpotifyHttpError('${response.statusCode}'),
      );
    }
    if (response.statusCode != 200) {
      throw SpotifyOAuthException(
        json['error_description'] as String? ??
            json['error'] as String? ??
            currentL.accountOverviewSpotifyHttpError('${response.statusCode}'),
      );
    }
    final access = json['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw SpotifyOAuthException(
        currentL.accountOverviewSpotifyNoAccessToken,
      );
    }
    return SpotifyTokens(
      access,
      json['refresh_token'] as String?,
      DateTime.now().add(
        Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600),
      ),
    );
  }

  static Future<void> _openExternal(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw SpotifyOAuthException(
        currentL.accountOverviewSpotifyCouldNotOpenPage,
      );
    }
  }

  static String _random(int length) {
    final rng = Random.secure();
    return base64UrlEncode(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    ).replaceAll('=', '');
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_oauth.dart';

/// Drives the client half of Google's Authorization Code + PKCE flow against
/// a real loopback listener bound by [YoutubeOAuth] itself — nothing here
/// reaches Google or a real browser. `openBrowser` stands in for the system
/// browser, the way `test/oauth_login_test.dart`'s `_FakeOAuthServer` stands
/// in for a real luma server; here it's the other way around, since
/// `YoutubeOAuth` is the one running the server and the test is the "browser"
/// following the redirect.
void main() {
  group('YoutubeOAuth.authorize', () {
    test('opens the consent URL with PKCE, catches the redirect, and '
        'exchanges the code', () async {
      final tokenRequests = <Map<String, String>>[];
      final client = MockClient((request) async {
        expect(request.url.path, '/token');
        tokenRequests.add(Uri.splitQueryString(request.body));
        return http.Response(
          jsonEncode({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'expires_in': 3600,
          }),
          200,
        );
      });

      final oauth = YoutubeOAuth(
        client: client,
        openBrowser: (url) async {
          final uri = Uri.parse(url);
          expect(uri.host, 'accounts.google.com');
          expect(uri.queryParameters['client_id'], 'client-id');
          expect(uri.queryParameters['code_challenge_method'], 'S256');
          expect(uri.queryParameters['access_type'], 'offline');
          expect(
            uri.queryParameters['scope'],
            'https://www.googleapis.com/auth/youtube.readonly '
            'https://www.googleapis.com/auth/yt-analytics.readonly',
          );

          final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
          final state = uri.queryParameters['state']!;
          // The browser completing consent and following Google's redirect
          // back to the loopback listener luma bound.
          unawaited(http.get(redirectUri.replace(queryParameters: {
            'code': 'auth-code-1',
            'state': state,
          })));
        },
      );

      final result =
          await oauth.authorize(clientId: 'client-id', clientSecret: 'secret');

      expect(result.accessToken, 'access-1');
      expect(result.refreshToken, 'refresh-1');
      expect(tokenRequests, hasLength(1));
      expect(tokenRequests.single['code'], 'auth-code-1');
      expect(tokenRequests.single['grant_type'], 'authorization_code');
      expect(tokenRequests.single['client_secret'], 'secret');
      expect(tokenRequests.single['code_verifier'], isNotEmpty);
    });

    test('rejects a redirect whose state does not match', () async {
      final oauth = YoutubeOAuth(
        client: MockClient((_) async => http.Response('{}', 200)),
        openBrowser: (url) async {
          final redirectUri =
              Uri.parse(Uri.parse(url).queryParameters['redirect_uri']!);
          unawaited(http.get(redirectUri.replace(queryParameters: {
            'code': 'auth-code-1',
            'state': 'not-the-right-state',
          })));
        },
      );

      await expectLater(
        oauth.authorize(clientId: 'client-id', clientSecret: 'secret'),
        throwsA(isA<YoutubeOAuthException>()),
      );
    });

    test('surfaces the error Google reports when consent is declined',
        () async {
      final oauth = YoutubeOAuth(
        client: MockClient((_) async => http.Response('{}', 200)),
        openBrowser: (url) async {
          final uri = Uri.parse(url);
          final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
          unawaited(http.get(redirectUri.replace(queryParameters: {
            'error': 'access_denied',
            'state': uri.queryParameters['state']!,
          })));
        },
      );

      await expectLater(
        oauth.authorize(clientId: 'client-id', clientSecret: 'secret'),
        throwsA(isA<YoutubeOAuthException>()),
      );
    });

    test('a token response missing a refresh token is rejected', () async {
      final oauth = YoutubeOAuth(
        client: MockClient((_) async => http.Response(
              jsonEncode({'access_token': 'access-1', 'expires_in': 3600}),
              200,
            )),
        openBrowser: (url) async {
          final uri = Uri.parse(url);
          final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
          unawaited(http.get(redirectUri.replace(queryParameters: {
            'code': 'auth-code-1',
            'state': uri.queryParameters['state']!,
          })));
        },
      );

      await expectLater(
        oauth.authorize(clientId: 'client-id', clientSecret: 'secret'),
        throwsA(isA<YoutubeOAuthException>()),
      );
    });
  });

  group('YoutubeOAuth.refresh', () {
    test('exchanges a refresh token for a new access token', () async {
      final oauth = YoutubeOAuth(
        client: MockClient((request) async {
          final body = Uri.splitQueryString(request.body);
          expect(body['grant_type'], 'refresh_token');
          expect(body['refresh_token'], 'refresh-1');
          return http.Response(
            jsonEncode({'access_token': 'access-2', 'expires_in': 1800}),
            200,
          );
        }),
      );

      final result = await oauth.refresh(
        clientId: 'client-id',
        clientSecret: 'secret',
        refreshToken: 'refresh-1',
      );
      expect(result.accessToken, 'access-2');
      expect(result.refreshToken, isNull);
    });

    test('a rejected refresh token surfaces as an exception', () async {
      final oauth = YoutubeOAuth(
        client: MockClient((_) async => http.Response(
              jsonEncode({'error': 'invalid_grant'}),
              400,
            )),
      );

      await expectLater(
        oauth.refresh(
            clientId: 'id', clientSecret: 'secret', refreshToken: 'dead'),
        throwsA(isA<YoutubeOAuthException>()),
      );
    });
  });
}

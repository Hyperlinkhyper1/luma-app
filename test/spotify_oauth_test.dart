import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_oauth.dart';

void main() {
  test(
    'sign-in succeeds when callback port 8888 is already occupied',
    () async {
      final occupied = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        8888,
      );
      addTearDown(occupied.close);
      final browser = http.Client();
      addTearDown(browser.close);
      Uri? consent;
      Future<http.Response>? callback;
      final oauth = SpotifyOAuth(
        client: MockClient((request) async {
          final body = Uri.splitQueryString(request.body);
          expect(
            request.url.toString(),
            'https://accounts.spotify.com/api/token',
          );
          expect(body['client_id'], 'client-id');
          expect(body['code'], 'test-code');
          expect(body['grant_type'], 'authorization_code');
          expect(
            body['redirect_uri'],
            consent!.queryParameters['redirect_uri'],
          );
          expect(
            base64UrlEncode(
              sha256.convert(utf8.encode(body['code_verifier']!)).bytes,
            ).replaceAll('=', ''),
            consent!.queryParameters['code_challenge'],
          );
          return http.Response(
            jsonEncode({
              'access_token': 'test-access',
              'refresh_token': 'test-refresh',
              'expires_in': 3600,
            }),
            200,
          );
        }),
        openBrowser: (uri) async {
          consent = uri;
          expect(uri.host, 'accounts.spotify.com');
          expect(uri.queryParameters['code_challenge_method'], 'S256');
          final redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
          expect(redirect.host, '127.0.0.1');
          expect(redirect.path, '/callback');
          expect(redirect.port, isNot(8888));
          callback = browser.get(
            redirect.replace(
              queryParameters: {
                'code': 'test-code',
                'state': uri.queryParameters['state']!,
              },
            ),
          );
        },
      );
      addTearDown(oauth.dispose);

      final tokens = await oauth.authorize('client-id');

      expect(tokens.accessToken, 'test-access');
      expect(tokens.refreshToken, 'test-refresh');
      expect((await callback!).statusCode, HttpStatus.ok);
    },
  );

  test(
    'cancelling sign-in releases its listener and allows retry on 8888',
    () async {
      final browser = http.Client();
      addTearDown(browser.close);
      final opened = Completer<Uri>();
      var retry = false;
      Future<http.Response>? callback;
      final oauth = SpotifyOAuth(
        client: _tokenClient(),
        openBrowser: (uri) async {
          final redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
          expect(redirect.port, 8888);
          if (!retry) {
            opened.complete(redirect);
          } else {
            callback = browser.get(
              redirect.replace(
                queryParameters: {
                  'code': 'test-code',
                  'state': uri.queryParameters['state']!,
                },
              ),
            );
          }
        },
      );
      addTearDown(oauth.dispose);
      final cancelled = expectLater(
        oauth.authorize('client-id'),
        throwsA(isA<SpotifyOAuthException>()),
      );
      final redirect = await opened.future;

      await oauth.cancelAuthorization();
      await cancelled;
      final released = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        redirect.port,
      );
      await released.close();

      retry = true;
      expect((await oauth.authorize('client-id')).accessToken, 'test-access');
      expect((await callback!).statusCode, HttpStatus.ok);
    },
  );

  test('a new sign-in cancels the previous attempt before binding', () async {
    final opened = Completer<void>();
    final browser = http.Client();
    addTearDown(browser.close);
    Future<http.Response>? callback;
    final oauth = SpotifyOAuth(
      client: _tokenClient(),
      openBrowser: (uri) async {
        if (!opened.isCompleted) {
          opened.complete();
          return;
        }
        expect(uri.queryParameters['client_id'], 'second-client');
        final redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
        expect(redirect.port, 8888);
        callback = browser.get(
          redirect.replace(
            queryParameters: {
              'code': 'test-code',
              'state': uri.queryParameters['state']!,
            },
          ),
        );
      },
    );
    addTearDown(oauth.dispose);
    final cancelled = expectLater(
      oauth.authorize('first-client'),
      throwsA(isA<SpotifyOAuthException>()),
    );
    await opened.future;

    final tokens = await oauth.authorize('second-client');

    await cancelled;
    expect(tokens.accessToken, 'test-access');
    expect((await callback!).statusCode, HttpStatus.ok);
  });

  test('cancellation during browser launch closes the listener', () async {
    final opened = Completer<Uri>();
    final launch = Completer<void>();
    final oauth = SpotifyOAuth(
      client: _tokenClient(),
      openBrowser: (uri) {
        opened.complete(Uri.parse(uri.queryParameters['redirect_uri']!));
        return launch.future;
      },
    );
    addTearDown(oauth.dispose);
    final cancelled = expectLater(
      oauth.authorize('client-id'),
      throwsA(isA<SpotifyOAuthException>()),
    );
    final redirect = await opened.future;

    await oauth.cancelAuthorization();
    await cancelled;
    final released = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      redirect.port,
    );
    await released.close();
    launch.complete();
  });

  test(
    'invalid state cannot exchange a code and releases the listener',
    () async {
      final browser = http.Client();
      addTearDown(browser.close);
      Uri? redirect;
      Future<http.Response>? callback;
      final oauth = SpotifyOAuth(
        client: MockClient((_) async {
          fail('Invalid callback must not exchange a code');
        }),
        openBrowser: (uri) async {
          redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
          callback = browser.get(
            redirect!.replace(
              queryParameters: {
                'code': 'test-code',
                'state': 'incorrect-state',
              },
            ),
          );
        },
      );
      addTearDown(oauth.dispose);

      await expectLater(
        oauth.authorize('client-id'),
        throwsA(isA<SpotifyOAuthException>()),
      );
      await callback;
      final released = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        redirect!.port,
      );
      await released.close();
    },
  );

  test('browser launch failure releases the callback listener', () async {
    Uri? redirect;
    final oauth = SpotifyOAuth(
      client: _tokenClient(),
      openBrowser: (uri) async {
        redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
        throw const SpotifyOAuthException('Browser unavailable');
      },
    );
    addTearDown(oauth.dispose);

    await expectLater(
      oauth.authorize('client-id'),
      throwsA(isA<SpotifyOAuthException>()),
    );
    final released = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      redirect!.port,
    );
    await released.close();
  });
}

http.Client _tokenClient() => MockClient(
  (_) async => http.Response(
    jsonEncode({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'expires_in': 3600,
    }),
    200,
  ),
);

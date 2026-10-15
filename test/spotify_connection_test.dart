import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_api.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_oauth.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_repository.dart';
import 'package:luma/security/secure_secret_store.dart';

void main() {
  test(
    'cancelling while fetching the profile cannot save a connection',
    () async {
      final profileStarted = Completer<void>();
      final profile = Completer<http.Response>();
      final secrets = _MemorySecrets();
      final repository = SpotifyRepository(
        secrets: secrets,
        oauth: _AuthorizedOAuth(),
        api: SpotifyApi(
          client: MockClient((_) {
            profileStarted.complete();
            return profile.future;
          }),
        ),
      );
      addTearDown(repository.dispose);
      final cancelled = expectLater(
        repository.connect('client-id'),
        throwsA(isA<SpotifyOAuthException>()),
      );
      await profileStarted.future;

      await repository.cancelConnect();
      profile.complete(http.Response('{"id":"test-user"}', 200));
      await cancelled;

      expect(repository.connected, isFalse);
      expect(await repository.exportConnection(), isNull);
    },
  );

  test(
    'an old token refresh cannot overwrite a newly connected account',
    () async {
      final secrets = _MemorySecrets();
      secrets.values['account_overview.spotify'] = jsonEncode(
        SpotifyCredentials(
          clientId: 'previous-client',
          accessToken: 'previous-access',
          refreshToken: 'previous-refresh',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          displayName: 'Previous account',
          accountId: 'previous-user',
        ).toJson(),
      );
      final oauth = _PendingRefreshOAuth();
      final repository = SpotifyRepository(
        secrets: secrets,
        oauth: oauth,
        api: SpotifyApi(
          client: MockClient(
            (request) async => http.Response(
              request.url.path == '/v1/me'
                  ? '{"id":"new-user"}'
                  : '{"items":[],"total":0}',
              200,
            ),
          ),
        ),
      );
      addTearDown(repository.dispose);
      await repository.load();
      await oauth.started.future;
      final writing = Completer<void>();
      final releaseWrite = Completer<void>();
      secrets.onWrite = () async {
        if (!writing.isCompleted) {
          writing.complete();
          await releaseWrite.future;
        }
      };
      final connected = repository.connect('new-client');
      await writing.future;

      oauth.result.complete(
        SpotifyTokens(
          'renewed-old-access',
          null,
          DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      releaseWrite.complete();
      await connected;

      expect(repository.credentials?.clientId, 'new-client');
      expect((await repository.exportConnection())?['clientId'], 'new-client');
    },
  );

  for (final wasConnected in [false, true]) {
    test(
      'cancelling during credential storage restores '
      '${wasConnected ? 'the previous connection' : 'the disconnected state'}',
      () async {
        final secrets = _MemorySecrets();
        final previous = SpotifyCredentials(
          clientId: 'previous-client',
          accessToken: 'previous-access',
          refreshToken: 'previous-refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          displayName: 'Previous account',
          accountId: 'previous-user',
        );
        if (wasConnected) {
          secrets.values['account_overview.spotify'] = jsonEncode(
            previous.toJson(),
          );
        }
        final repository = SpotifyRepository(
          secrets: secrets,
          oauth: _AuthorizedOAuth(),
          api: SpotifyApi(
            client: MockClient(
              (request) async => http.Response(
                request.url.path == '/v1/me'
                    ? '{"id":"new-user"}'
                    : '{"items":[],"total":0}',
                200,
              ),
            ),
          ),
        );
        addTearDown(repository.dispose);
        await repository.load();
        await repository.refresh();
        final writing = Completer<void>();
        final releaseWrite = Completer<void>();
        secrets.onWrite = () async {
          writing.complete();
          await releaseWrite.future;
        };
        final cancelled = expectLater(
          repository.connect('new-client'),
          throwsA(isA<SpotifyOAuthException>()),
        );
        await writing.future;

        await repository.cancelConnect();
        secrets.onWrite = null;
        releaseWrite.complete();
        await cancelled;

        expect(
          repository.credentials?.accountId,
          wasConnected ? 'previous-user' : null,
        );
        expect(
          await repository.exportConnection(),
          wasConnected ? previous.toJson() : null,
        );
      },
    );
  }
}

class _AuthorizedOAuth extends SpotifyOAuth {
  _AuthorizedOAuth()
    : super(client: MockClient((_) async => http.Response('{}', 500)));

  @override
  Future<SpotifyTokens> authorize(String clientId) async => SpotifyTokens(
    'test-access',
    'test-refresh',
    DateTime.now().add(const Duration(hours: 1)),
  );
}

class _PendingRefreshOAuth extends _AuthorizedOAuth {
  final started = Completer<void>();
  final result = Completer<SpotifyTokens>();

  @override
  Future<SpotifyTokens> refresh(String clientId, String refreshToken) {
    started.complete();
    return result.future;
  }
}

class _MemorySecrets extends SecureSecretStore {
  final values = <String, String>{};
  Future<void> Function()? onWrite;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async {
    await onWrite?.call();
    values[name] = value;
  }

  @override
  Future<void> delete(String name) async => values.remove(name);
}

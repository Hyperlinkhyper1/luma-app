import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_credentials.dart';

/// `YoutubeCredentialStore`'s disk round-trip is not covered here, the same
/// way `GithubCredentialStore`'s and `PasswordCrypto`'s are not: all three
/// go through `path_provider`, which nothing in this suite mocks. What is
/// pure and worth locking down is the plain data logic — completeness and
/// expiry — that the repository's connect/refresh flow leans on directly.
void main() {
  group('YoutubeCredentials.isComplete', () {
    test('is false while the client id is empty', () {
      final credentials = YoutubeCredentials(
        clientId: '',
        clientSecret: 'secret',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now(),
      );
      expect(credentials.isComplete, isFalse);
    });

    test('is true once every field is filled', () {
      final credentials = YoutubeCredentials(
        clientId: 'id',
        clientSecret: 'secret',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now(),
      );
      expect(credentials.isComplete, isTrue);
    });

    test('a missing refresh token is incomplete even with everything else set',
        () {
      final credentials = YoutubeCredentials(
        clientId: 'id',
        clientSecret: 'secret',
        accessToken: 'access',
        refreshToken: '',
        expiresAt: DateTime.now(),
      );
      expect(credentials.isComplete, isFalse);
    });
  });

  group('YoutubeCredentials.isExpired', () {
    test('is false with plenty of time left', () {
      final credentials = YoutubeCredentials(
        clientId: 'id',
        clientSecret: 'secret',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(credentials.isExpired, isFalse);
    });

    test('is true once past expiry', () {
      final credentials = YoutubeCredentials(
        clientId: 'id',
        clientSecret: 'secret',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(credentials.isExpired, isTrue);
    });

    test('a minute of slack treats an about-to-expire token as expired '
        'already, so a call in flight cannot race the real expiry', () {
      final credentials = YoutubeCredentials(
        clientId: 'id',
        clientSecret: 'secret',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(credentials.isExpired, isTrue);
    });
  });

  group('YoutubeCredentials.copyWith', () {
    test('keeps the client id/secret and refresh token, which never change '
        'on a token refresh', () {
      final original = YoutubeCredentials(
        clientId: 'id',
        clientSecret: 'secret',
        accessToken: 'old-access',
        refreshToken: 'refresh',
        expiresAt: DateTime(2026, 1, 1),
        channelId: 'UC1',
        channelTitle: 'Old Title',
      );
      final refreshed = original.copyWith(
        accessToken: 'new-access',
        expiresAt: DateTime(2026, 2, 1),
      );

      expect(refreshed.clientId, 'id');
      expect(refreshed.clientSecret, 'secret');
      expect(refreshed.refreshToken, 'refresh');
      expect(refreshed.accessToken, 'new-access');
      expect(refreshed.expiresAt, DateTime(2026, 2, 1));
      expect(refreshed.channelId, 'UC1');
      expect(refreshed.channelTitle, 'Old Title');
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_api.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_oauth.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/ui/spotify_connect_dialog.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/security/secure_secret_store.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  late _PendingSpotifyOAuth oauth;
  late _MemorySecretStore secrets;
  late SpotifyRepository repository;

  setUp(() {
    oauth = _PendingSpotifyOAuth();
    secrets = _MemorySecretStore();
    repository = SpotifyRepository(
      oauth: oauth,
      secrets: secrets,
      api: SpotifyApi(
        client: MockClient((_) async {
          fail('A dismissed sign-in must not request Spotify account data');
        }),
      ),
    );
  });

  tearDown(() => repository.dispose());

  testWidgets('Cancel stays enabled during sign-in and cancels authorization', (
    tester,
  ) async {
    final closed = await _openPendingSignIn(tester, repository);
    expect(oauth.authorizing, isTrue);
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);

    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(closed.isCompleted, isTrue);
    expect(oauth.cancelledAttempts, 1);
    expect(oauth.authorizing, isFalse);
    expect(repository.connected, isFalse);
    expect(secrets.values, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the barrier cancels pending authorization', (
    tester,
  ) async {
    final closed = await _openPendingSignIn(tester, repository);
    expect(oauth.authorizing, isTrue);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(closed.isCompleted, isTrue);
    expect(oauth.cancelledAttempts, 1);
    expect(
      oauth.authorizing,
      isFalse,
      reason: 'Closing the dialog must not leave the OAuth listener active',
    );
    expect(repository.connected, isFalse);
    expect(secrets.values, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<Completer<void>> _openPendingSignIn(
  WidgetTester tester,
  SpotifyRepository repository,
) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final closed = Completer<void>();
  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('en'),
      home: SpotifyScope(
        repository: repository,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showSpotifyConnectDialog(context);
                closed.complete();
              },
              child: const Text('Open Spotify'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Spotify'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'test-client-id');
  await tester.tap(find.text('Sign in with Spotify'));
  await tester.pump();
  return closed;
}

class _PendingSpotifyOAuth extends SpotifyOAuth {
  Completer<SpotifyTokens>? _pending;
  int cancelledAttempts = 0;
  bool get authorizing => _pending != null;

  @override
  Future<SpotifyTokens> authorize(String clientId) {
    expect(clientId, 'test-client-id');
    final pending = Completer<SpotifyTokens>();
    _pending = pending;
    return pending.future.whenComplete(() {
      _pending = null;
    });
  }

  @override
  Future<void> cancelAuthorization() async {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    cancelledAttempts++;
    pending.completeError(const SpotifyOAuthException('Sign-in cancelled'));
  }
}

class _MemorySecretStore extends SecureSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }

  @override
  Future<void> delete(String name) async {
    values.remove(name);
  }
}

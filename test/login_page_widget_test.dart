import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/account/login_page.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/sync/server_access.dart';
import 'package:luma/sync/sync_api.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';

/// The sign-in screen's own behaviour: which way in it offers, how it adapts
/// to a phone-width window, and that it refuses bad input before anything
/// leaves the device. The provider handshake itself is covered end to end in
/// oauth_login_test.dart.
void main() {
  setUp(() => ServerAccessGate.instance.setApproved(false));
  tearDown(() => ServerAccessGate.instance.setApproved(false));

  const bothProviders = [
    OAuthProviderInfo(id: 'google', name: 'Google'),
    OAuthProviderInfo(id: 'github', name: 'GitHub'),
  ];

  /// Pumps the screen with a fixed provider list. `pumpAndSettle` is avoided
  /// on purpose — the panel's entry transition would keep it spinning.
  Future<SyncService> pumpLogin(
    WidgetTester tester, {
    List<OAuthProviderInfo> providers = bothProviders,
    Size size = const Size(1200, 800),
    int initialMode = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sync = SyncService(collections: const []);
    // init() reaches for the app support directory, which resolves off the
    // fake clock — inside testWidgets that only completes under runAsync.
    await tester.runAsync(sync.init);
    addTearDown(sync.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: LoginPage(
        sync: sync,
        initialMode: initialMode,
        providerLookup: (_) async => providers,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return sync;
  }

  testWidgets('both ways in are offered side by side', (tester) async {
    await pumpLogin(tester, initialMode: 0);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with GitHub'), findsOneWidget);
    expect(find.text('or with your email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    // The brand panel is only worth the width on a desktop-sized window.
    expect(find.text('Everything you keep here,\non every device you use.'),
        findsOneWidget);
  });

  testWidgets('a server with no providers configured shows no buttons — and '
      'still shows the email form', (tester) async {
    await pumpLogin(tester, providers: const []);

    expect(find.textContaining('Continue with'), findsNothing);
    expect(find.text('or with your email'), findsNothing);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Confirm password'), findsOneWidget);
  });

  testWidgets('the create/sign-in tabs swap the form, not the buttons',
      (tester) async {
    await pumpLogin(tester, initialMode: 1);
    expect(find.widgetWithText(TextField, 'Confirm password'), findsOneWidget);

    await tester.tap(find.text('Sign in').first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(TextField, 'Confirm password'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('local-only sync drops the server and its buttons',
      (tester) async {
    await pumpLogin(tester);

    // The form scrolls once both provider buttons and a confirm field are in
    // it, so reach the link the way a user would.
    await tester.ensureVisible(find.text('Use local-only sync'));
    await tester.pump();
    await tester.tap(find.text('Use local-only sync'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Set up local-only sync'), findsOneWidget);
    expect(find.textContaining('Continue with'), findsNothing);
    expect(find.text('Use a luma account instead'), findsOneWidget);
  });

  testWidgets('a too-short password is refused before anything is sent',
      (tester) async {
    final sync = await pumpLogin(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'alice@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'short');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.textContaining('at least 10 characters'), findsOneWidget);
    expect(sync.signedIn, isFalse);
    expect(ServerAccessGate.instance.approved, isFalse);
  });

  testWidgets('mismatched passwords are refused', (tester) async {
    final sync = await pumpLogin(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'alice@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'),
        'a-long-enough-password');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'something-else');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(sync.signedIn, isFalse);
  });

  testWidgets('"Forgot password?" is offered on sign-in, not on create',
      (tester) async {
    await pumpLogin(tester, initialMode: 1);
    expect(find.text('Forgot password?'), findsNothing);

    await tester.tap(find.text('Sign in').first);
    await tester.pump();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('the forgot-password step refuses a bad email before sending',
      (tester) async {
    final sync = await pumpLogin(tester, initialMode: 0);

    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Forgot your password?'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'not-an-email');
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Choose a new password'), findsNothing);
    expect(sync.signedIn, isFalse);

    await tester.tap(find.text('Back to sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('the emailed code ends on "account created", not signed in',
      (tester) async {
    // testWidgets answers every real HTTP request with a 400; this test
    // talks to its own loopback server instead.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);

    // A server holding accounts for approval after the email is verified.
    final paths = <String>[];
    final server = (await tester.runAsync(() async {
      final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      s.listen((request) async {
        paths.add(request.uri.path);
        await utf8.decodeStream(request);
        final verify = request.uri.path.endsWith('/auth/verify-code');
        request.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(verify
              ? {'status': 'awaiting_approval', 'message': 'Verified.'}
              : {'status': 'pending_approval', 'approval': 'email'}));
        await request.response.close();
      });
      return s;
    }))!;
    addTearDown(() => server.close(force: true));

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sync = SyncService(collections: const []);
    await tester.runAsync(() async {
      await sync.init();
      await sync.register(
        serverUrl: 'http://127.0.0.1:${server.port}',
        email: 'bob@example.com',
        password: 'a-long-enough-password',
      );
    });
    addTearDown(() async {
      await tester.runAsync(sync.cancelPendingApproval);
      sync.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: LoginPage(
        sync: sync,
        initialMode: 0,
        providerLookup: (_) async => const [],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Resumes on code entry, and the code no longer needs the password.
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.runAsync(() async {
      await tester.tap(find.text('Verify email'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Account created'), findsOneWidget);
    expect(sync.pendingEmailVerified, isTrue);
    expect(sync.serverReady, isFalse);
    expect(ServerAccessGate.instance.approved, isFalse);
    expect(paths.last, '/api/v1/auth/verify-code');
    expect(paths.where((p) => p.endsWith('/auth/login')), isEmpty);
  });

  testWidgets('the narrow layout keeps everything but the brand panel',
      (tester) async {
    await pumpLogin(tester, size: const Size(420, 900));

    expect(find.text('Everything you keep here,\non every device you use.'),
        findsNothing);
    expect(find.text('Make your account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
  });
}

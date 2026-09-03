import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/account/login_page.dart';
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

  testWidgets('the narrow layout keeps everything but the brand panel',
      (tester) async {
    await pumpLogin(tester, size: const Size(420, 900));

    expect(find.text('Everything you keep here,\non every device you use.'),
        findsNothing);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
  });
}

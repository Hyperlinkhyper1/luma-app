import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_scope.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/steam_account_dialog.dart';
import 'package:luma/theme/luma_theme.dart';

/// Covers the thing this file exists to guard: connecting a Steam account is
/// a settings dialog reachable from anywhere in the plugin, not a page that
/// has to be filled in before anything else can render — and its own field
/// validation still holds without ever touching the network or disk.
///
/// [SteamRepository.connect] itself isn't exercised here: it reaches
/// `SteamCredentialStore`, which needs a real `path_provider` platform
/// channel this project has no test double for yet (nothing else in the
/// repo mocks one either). Everything up to the point of calling it —
/// field validation, opening the dialog — needs none of that.
void main() {
  late SteamDatabase db;

  setUp(() {
    db = SteamDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // SteamScope wraps the whole app, above the Navigator — same as in
  // main.dart — because showDialog inserts into the root Navigator's
  // overlay, which needs the scope as an ancestor too, not just the page
  // content.
  Widget app(Widget child) => SteamScope(
        repository: SteamRepository(db),
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('showSteamAccountDialog opens SteamAccountDialog',
      (tester) async {
    await tester.pumpWidget(app(Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showSteamAccountDialog(context),
          child: const Text('open'),
        ),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(SteamAccountDialog), findsOneWidget);
    expect(find.text('Steam Web API key'), findsOneWidget);
    expect(find.text('Steam ID or profile URL'), findsOneWidget);
  });

  group('SteamAccountDialog', () {
    testWidgets('offers a way to get a key, and no connected status when '
        'nothing is connected yet', (tester) async {
      await tester.pumpWidget(app(const SteamAccountDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Get a key from Steam'), findsOneWidget);
      expect(find.textContaining('Connected'), findsNothing);
      // Nothing to disconnect from yet.
      expect(find.text('Disconnect'), findsNothing);
    });

    testWidgets('flags both empty fields without touching the network',
        (tester) async {
      await tester.pumpWidget(app(const SteamAccountDialog()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(find.text('Paste your Steam Web API key.'), findsOneWidget);
      expect(
        find.text('Enter your Steam ID or profile URL.'),
        findsOneWidget,
      );
    });

    testWidgets('clears a field error as soon as the field gets input',
        (tester) async {
      await tester.pumpWidget(app(const SteamAccountDialog()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.text('Paste your Steam Web API key.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 8A0F2C…'),
        'some-key',
      );
      await tester.pump();

      expect(find.text('Paste your Steam Web API key.'), findsNothing);
      // The id field was never touched, so its error still stands — errors
      // clear per field, not all at once.
      expect(
        find.text('Enter your Steam ID or profile URL.'),
        findsOneWidget,
      );
    });

    testWidgets('Close pops the dialog without validating anything',
        (tester) async {
      await tester.pumpWidget(app(Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showSteamAccountDialog(context),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SteamAccountDialog), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(SteamAccountDialog), findsNothing);
      expect(find.text('Paste your Steam Web API key.'), findsNothing);
    });
  });
}

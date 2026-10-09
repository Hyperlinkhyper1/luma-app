import 'package:luma/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/small_games/small_games_page.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('game picker opens BINGO and draws a number', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.light,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: const Scaffold(body: SmallGamesPage()),
      ),
    );

    expect(find.text('Choose a game to play.'), findsOneWidget);
    await tester.tap(find.byTooltip('Open BINGO'));
    await tester.pumpAndSettle();
    expect(find.text('The draw cage'), findsOneWidget);
    expect(find.text('0 / 75 called'), findsOneWidget);
    await tester.ensureVisible(find.text('Draw next ball'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draw next ball'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 75 called'), findsOneWidget);
  });

  testWidgets('card table offers three playable games at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.light,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: const Scaffold(body: SmallGamesPage()),
      ),
    );
    await tester.tap(find.byTooltip('Open Card Games'));
    await tester.pumpAndSettle();
    expect(find.text('What will you play?'), findsOneWidget);
    expect(find.text('YOU • SEAT 1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('open_blackjack')));
    await tester.tap(find.byKey(const ValueKey('open_blackjack')));
    await tester.pumpAndSettle();
    expect(find.text('Blackjack'), findsOneWidget);
    expect(find.text('Hit'), findsOneWidget);
    await tester.tap(find.text('Stand'));
    await tester.pumpAndSettle();
    expect(find.text('Deal again'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Back to card table'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to card table'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open_poker')));
    await tester.tap(find.byKey(const ValueKey('open_poker')));
    await tester.pumpAndSettle();
    expect(find.text('Draw cards'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('poker_card_0')));
    await tester.tap(find.text('Draw cards'));
    await tester.pumpAndSettle();
    expect(find.text('Deal again'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Back to card table'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to card table'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open_patience')));
    await tester.tap(find.byKey(const ValueKey('open_patience')));
    await tester.pumpAndSettle();
    expect(find.text('PATIENCE • DRAW ONE'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('patience_Stock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('patience_Stock')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tap the drawn card, then a tableau column or foundation.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/small_games/small_games_page.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('game picker opens BINGO and draws a number', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: LumaTheme.light,
      home: const Scaffold(body: SmallGamesPage()),
    ));

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
}

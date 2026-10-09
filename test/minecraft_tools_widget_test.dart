import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/schematic/textures/block_atlas.dart';
import 'package:luma/features/plugins/installed/game_tools/game_tools_page.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_shots.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_tool_catalog.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/ui/mc_showcase.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/minecraft_tools_page.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? LumaTheme.light,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: child),
);

/// The hub's own scroll view, not the tab bar's.
final _page = find.descendant(
  of: find.byType(CustomScrollView),
  matching: find.byType(Scrollable),
).first;

/// Runs a hub transition to the end: a frame to start it, its length, and a
/// frame for the outgoing screen to be dropped.
Future<void> _transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void _size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    // The 3D previews would otherwise go looking for a Minecraft install on
    // the machine running the tests.
    BlockAtlas.autoLoad = false;
    BlockAtlas.resetForTesting();
  });

  tearDown(() {
    BlockAtlas.resetForTesting();
    BlockAtlas.autoLoad = true;
  });

  testWidgets('Game Tools opens the Minecraft hub instead of "coming soon"', (tester) async {
    _size(tester, 1400, 900);
    await tester.pumpWidget(_app(const GameToolsPage(initialSection: GameToolsSection.minecraft)));
    await tester.pump();

    expect(find.text('Minecraft tools for builders and creators'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsNothing);
  });

  testWidgets('the hub has three sub-tabs with their tools', (tester) async {
    _size(tester, 1400, 1000);
    await tester.pumpWidget(_app(const MinecraftToolsPage()));
    await tester.pump();

    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Admins'), findsOneWidget);
    expect(find.text('Developers'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Enchant Optimizer'), 300, scrollable: _page);
    expect(find.text('Enchant Optimizer'), findsWidgets);
    expect(find.text('Flat World Generator'), findsNothing);

    await tester.scrollUntilVisible(find.text('Admins'), -300, scrollable: _page);
    await tester.tap(find.text('Admins'));
    await tester.pump();
    // In the spotlight straight away.
    expect(find.text('Flat World Generator'), findsWidgets);
    expect(find.text('Enchant Optimizer'), findsNothing);

    await tester.tap(find.text('Developers'));
    await tester.pump();
    expect(find.text('Recipe Generator'), findsWidgets);
    expect(find.text('Asset Library'), findsWidgets);
  });

  testWidgets('the spotlight turns over by itself and on the arrows', (tester) async {
    _size(tester, 1400, 1000);
    await tester.pumpWidget(_app(const MinecraftToolsPage()));
    await tester.pump();

    final spotlight = find.byType(McSpotlight);
    // Players open on the first build tool, large, with the next two beside.
    expect(find.descendant(of: spotlight, matching: find.text('Shape Generator')), findsOneWidget);

    // After its dwell it moves on by one: the shape generator scrolls out.
    await tester.pump(const Duration(seconds: 6));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.descendant(of: spotlight, matching: find.text('Shape Generator')), findsNothing);

    await tester.tap(find.byTooltip('Previous page'));
    await _transition(tester);
    expect(find.descendant(of: spotlight, matching: find.text('Shape Generator')), findsOneWidget);
  });

  testWidgets('the spotlight holds still when motion is reduced', (tester) async {
    _size(tester, 1400, 1000);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true, size: Size(1400, 1000)),
        child: _app(const MinecraftToolsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    expect(
      find.descendant(
        of: find.byType(McSpotlight),
        matching: find.text('Shape Generator'),
      ),
      findsOneWidget,
    );
  });

  test('every tool has a banner for every background', () {
    for (final variant in McShotVariant.values) {
      for (final tool in McTool.values) {
        expect(
          File(mcShotAsset(tool, variant)).existsSync(),
          isTrue,
          reason: '${mcShotAsset(tool, variant)} is missing — run '
              'test/mc_tool_screenshots_test.dart with MC_SHOTS=true',
        );
      }
    }
  });

  testWidgets('search finds tools across every sub-tab', (tester) async {
    _size(tester, 1400, 1000);
    await tester.pumpWidget(_app(const MinecraftToolsPage()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'potion');
    await tester.pump();
    expect(find.text('Potion Guide'), findsOneWidget);
    expect(find.text('Custom Potions'), findsOneWidget);
  });

  testWidgets('a tool card opens its tool and the back link returns', (tester) async {
    _size(tester, 1400, 1000);
    await tester.pumpWidget(_app(const MinecraftToolsPage()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Enchant Optimizer'), 300, scrollable: _page);
    await tester.pump();
    await tester.tap(find.text('Enchant Optimizer'));
    await _transition(tester);
    expect(find.text('All tools'), findsOneWidget);
    expect(find.text('Sharpness'), findsOneWidget);

    await tester.tap(find.text('All tools'));
    await _transition(tester);
    // Back on the hub, scrolled to where the user left it.
    expect(find.text('All tools'), findsNothing);
    expect(find.text('Enchant Optimizer'), findsOneWidget);
  });

  // Every tool screen must build on a desktop window and a phone, in both
  // themes, without throwing or overflowing. The asset library and the
  // schematic organizer go to disk on open, so they only get the desktop
  // pass.
  for (final tool in McTool.values) {
    for (final (label, width, height, dark) in const [
      ('desktop', 1400.0, 1000.0, false),
      ('phone', 390.0, 844.0, true),
    ]) {
      if (label == 'phone' &&
          (tool == McTool.assetLibrary || tool == McTool.schematicOrganizer)) {
        continue;
      }
      testWidgets('${tool.name} builds on $label', (tester) async {
        _size(tester, width, height);
        await tester.pumpWidget(
          _app(
            MinecraftToolsPage(initialTool: tool),
            theme: dark ? LumaTheme.dark : LumaTheme.light,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.text('All tools'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

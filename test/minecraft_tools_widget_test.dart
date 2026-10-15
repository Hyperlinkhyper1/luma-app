import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Finder _audienceButton(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Future<Color> _pixelAt(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('hub-paint')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
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

  for (final width in [320.0, 720.0, 900.0, 1100.0, 1400.0]) {
    testWidgets('audience tabs stay fully visible at width $width', (
      tester,
    ) async {
      _size(tester, width, 1000);
      await tester.pumpWidget(_app(const MinecraftToolsPage()));
      await tester.pump();

      final developers = _audienceButton('Developers');
      final horizontalScrolls = find.ancestor(
        of: developers,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
        ),
      );
      for (final scroll in horizontalScrolls.evaluate()) {
        final state = (scroll as StatefulElement).state as ScrollableState;
        expect(
          state.position.maxScrollExtent,
          0,
          reason: 'The audience bar must fit without cropping its right edge.',
        );
      }
      expect(tester.getRect(developers).right, lessThanOrEqualTo(width));
      await tester.tap(developers);
      await tester.pump();
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: developers,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.selected != null,
              ),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (name, theme) in [
    ('light', LumaTheme.light),
    ('dark', LumaTheme.dark),
  ]) {
    testWidgets(
      'audience selection keeps its fill during clicks in $name mode',
      (tester) async {
        _size(tester, 1400, 1000);
        await tester.pumpWidget(
          _app(
            const RepaintBoundary(
              key: ValueKey('hub-paint'),
              child: MinecraftToolsPage(),
            ),
            theme: theme,
          ),
        );
        await tester.pump();
        final palette = theme.extension<LumaPalette>()!;
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        for (final label in ['Developers', 'Players', 'Admins']) {
          final button = _audienceButton(label);
          final center = tester.getCenter(button);
          await mouse.moveTo(center);
          await tester.pump(const Duration(milliseconds: 200));
          await mouse.down(center);
          await tester.pump(const Duration(milliseconds: 100));
          await mouse.up();
          await tester.pump();
          for (final elapsed in [0, 16, 80, 160, 320]) {
            await tester.pump(Duration(milliseconds: elapsed));
            final rect = tester.getRect(button);
            final fill = await _pixelAt(
              tester,
              Offset(rect.center.dx, rect.top + 4),
            );
            expect(
              fill,
              palette.accent,
              reason:
                  '$label must keep its accent behind the selected text '
                  'throughout the click ($elapsed ms).',
            );
          }
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

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

  testWidgets('map art switches views, map sizes and zoom levels', (tester) async {
    _size(tester, 1400, 1000);
    await tester.pumpWidget(_app(const MinecraftToolsPage(initialTool: McTool.mapArtGenerator)));
    await tester.pump();

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('3D build'), findsOneWidget);
    expect(find.text('128 × 128 blocks · 1 map'), findsOneWidget);

    await tester.tap(find.text('1:2'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('256 × 256 blocks · 1 map · 1:2'), findsOneWidget);

    // Four maps across at 1:1, then zoomed out to 1:8: only two fit.
    await tester.tap(find.text('1:1'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('512 × 128 blocks · 4 maps'), findsOneWidget);
    await tester.tap(find.text('1:8'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('2048 × 1024 blocks · 2 maps · 1:8'), findsOneWidget);

    await tester.tap(find.text('Guide'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('How to build it'), findsOneWidget);
    expect(find.textContaining('out 3×'), findsOneWidget);

    await tester.tap(find.text('Free size'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('WIDTH'), findsOneWidget);
    expect(find.text('128 × 128 blocks'), findsOneWidget);
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

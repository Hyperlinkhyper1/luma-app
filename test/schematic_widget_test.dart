import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/converter_page.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/converter/schematic/schematic_model.dart';
import 'package:luma/features/converter/schematic/textures/block_atlas.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_source_io.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_types.dart';
import 'package:luma/features/converter/tools/schematic_converter_view.dart';
import 'package:luma/features/converter/tools/schematic_viewer.dart';
import 'package:luma/theme/luma_theme.dart';

/// A flat-colour 16x16 PNG standing in for a block texture.
Uint8List _solidPng(int r, int g, int b) {
  final image = img.Image(width: 16, height: 16, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _app(Widget child) => MaterialApp(
      theme: LumaTheme.dark,
      home: Scaffold(body: child),
    );

/// A small hollow box, so the viewer has both exposed and buried voxels to
/// deal with.
Schematic _sample({int width = 6, int height = 5, int length = 7}) {
  final builder = PaletteBuilder();
  final stone = builder.add(BlockState('minecraft:stone'));
  final glass = builder.add(BlockState('minecraft:glass'));

  final blocks = Uint16List(width * height * length);
  for (var y = 0; y < height; y++) {
    for (var z = 0; z < length; z++) {
      for (var x = 0; x < width; x++) {
        final onShell = x == 0 ||
            y == 0 ||
            z == 0 ||
            x == width - 1 ||
            y == height - 1 ||
            z == length - 1;
        if (!onShell) continue;
        blocks[x + z * width + y * width * length] =
            y == height - 1 ? glass : stone;
      }
    }
  }

  return Schematic(
    width: width,
    height: height,
    length: length,
    palette: builder.build(),
    blocks: blocks,
    name: 'Hollow box',
  );
}

/// The Other tile is the last one on the hub, so it sits below the fold in the
/// default test viewport.
Future<void> _openOtherCategory(WidgetTester tester) async {
  final tile = find.text('Other');
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Otherwise the preview would go looking for whatever Minecraft happens
    // to be installed on the machine running the tests.
    BlockAtlas.autoLoad = false;
    BlockAtlas.resetForTesting();
  });

  tearDown(() {
    BlockAtlas.resetForTesting();
    BlockAtlas.autoLoad = true;
  });

  group('converter hub', () {
    testWidgets('has an Other tile that opens the Other category',
        (tester) async {
      await tester.pumpWidget(_app(const ConverterPage()));

      expect(find.text('Other'), findsOneWidget);
      await _openOtherCategory(tester);

      expect(find.text('Minecraft schematics'), findsOneWidget);
      expect(
        find.text('Format tools beyond audio, images and video'),
        findsOneWidget,
      );
    });

    testWidgets('Other opens the schematic converter and comes back',
        (tester) async {
      await tester.pumpWidget(_app(const ConverterPage()));
      await _openOtherCategory(tester);

      await tester.tap(find.text('Minecraft schematics'));
      await tester.pumpAndSettle();

      expect(find.text('Click to choose a build'), findsOneWidget);
      expect(
        find.text('SCHEM · LITEMATIC · SCHEMATIC · NBT · MCSTRUCTURE'),
        findsWidgets,
      );

      // Back to the Other hub, then back to the main hub.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Audio converter'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Audio converter'), findsOneWidget);
    });

    testWidgets('the schematic converter shows its empty state', (tester) async {
      await tester.pumpWidget(
        _app(SchematicConverterView(onBack: () {})),
      );
      expect(find.text('Click to choose a build'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('3D viewer', () {
    testWidgets('paints a build without throwing', (tester) async {
      await tester.pumpWidget(_app(SchematicViewer(schematic: _sample())));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Layers'), findsOneWidget);
      expect(find.byIcon(Icons.rotate_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
    });

    testWidgets('orbits on drag and stays painted', (tester) async {
      await tester.pumpWidget(_app(SchematicViewer(schematic: _sample())));
      await tester.pumpAndSettle();

      final viewport = find.byType(CustomPaint).first;
      await tester.drag(viewport, const Offset(80, 30));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // A full turn through every camera octant exercises each of the eight
      // back-to-front traversal orders.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byIcon(Icons.rotate_right_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('zoom and reset keep it painting', (tester) async {
      await tester.pumpWidget(_app(SchematicViewer(schematic: _sample())));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byIcon(Icons.zoom_out_rounded));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('slicing the layer range repaints without throwing',
        (tester) async {
      await tester.pumpWidget(_app(SchematicViewer(schematic: _sample())));
      await tester.pumpAndSettle();

      final slider = find.byType(RangeSlider);
      expect(slider, findsOneWidget);

      // Drag the upper thumb inward to cut the top off the build.
      final box = tester.getRect(slider);
      await tester.dragFrom(
        Offset(box.right - 12, box.center.dy),
        Offset(-box.width / 3, 0),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Layers'), findsOneWidget);
    });

    testWidgets('says so when a build is empty', (tester) async {
      final empty = Schematic(
        width: 3,
        height: 3,
        length: 3,
        palette: [BlockState.air],
        blocks: Uint16List(27),
      );
      await tester.pumpWidget(_app(SchematicViewer(schematic: empty)));
      await tester.pumpAndSettle();

      expect(find.textContaining('all air'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws blocks in their own colour, not a flat silhouette',
        (tester) async {
      // Rendering goes through drawVertices with per-vertex colours, which is
      // easy to get subtly wrong — a bad blend mode paints the whole build
      // black or white without throwing. So check the actual pixels.
      final builder = PaletteBuilder();
      final gold = builder.add(BlockState('minecraft:gold_block'));
      final blocks = Uint16List(4 * 4 * 4);
      for (var i = 0; i < blocks.length; i++) {
        blocks[i] = gold;
      }
      final schematic = Schematic(
        width: 4,
        height: 4,
        length: 4,
        palette: builder.build(),
        blocks: blocks,
      );

      await tester.pumpWidget(_app(SchematicViewer(schematic: schematic)));
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).last,
      );

      late ByteData pixels;
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });

      var goldish = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        final r = pixels.getUint8(i);
        final g = pixels.getUint8(i + 1);
        final b = pixels.getUint8(i + 2);
        // Gold blocks shade to between (250,238,77) and (162,155,50): red and
        // green high and close together, blue clearly lower.
        if (r > 140 && g > 130 && b < r - 60 && (r - g).abs() < 40) goldish++;
      }
      image.dispose();

      final total = pixels.lengthInBytes ~/ 4;
      expect(
        goldish,
        greaterThan(total ~/ 50),
        reason: 'the build should be drawn in gold, not a flat silhouette',
      );
    });

    testWidgets('says it is on flat colours when no textures were found',
        (tester) async {
      await tester.pumpWidget(_app(SchematicViewer(schematic: _sample())));
      await tester.pumpAndSettle();

      expect(find.textContaining('flat block colours'), findsOneWidget);
      expect(find.text('Choose Minecraft .jar'), findsOneWidget);
    });

    testWidgets('draws real block textures when an atlas is available',
        (tester) async {
      // The textured path is where the interesting mistakes live: a wrong UV
      // corner mirrors the texture, a wrong blend mode loses it entirely, and
      // a wrong face index paints the top texture down the sides. So give it
      // a block whose top and sides are unmistakably different colours and
      // check both actually land on screen.
      final bitmap = buildAtlas(
        RawTextureData(
          textures: {
            'block/test_top': _solidPng(20, 230, 40),
            'block/test_side': _solidPng(230, 20, 40),
          },
          blockstates: {
            'test_block': '{"variants":{"":'
                '{"model":"minecraft:block/test_block"}}}',
          },
          models: {
            'block/test_block': '{"textures":{'
                '"up":"minecraft:block/test_top",'
                '"down":"minecraft:block/test_side",'
                '"north":"minecraft:block/test_side",'
                '"south":"minecraft:block/test_side",'
                '"east":"minecraft:block/test_side",'
                '"west":"minecraft:block/test_side"}}',
          },
          label: 'Test pack',
        ),
      );

      late BlockAtlas atlas;
      await tester.runAsync(() async {
        atlas = await BlockAtlas.fromBitmap(bitmap);
      });
      BlockAtlas.installForTesting(atlas);

      final builder = PaletteBuilder();
      final block = builder.add(BlockState('minecraft:test_block'));
      final blocks = Uint16List(4 * 4 * 4);
      for (var i = 0; i < blocks.length; i++) {
        blocks[i] = block;
      }
      final schematic = Schematic(
        width: 4,
        height: 4,
        length: 4,
        palette: builder.build(),
        blocks: blocks,
      );

      await tester.pumpWidget(_app(SchematicViewer(schematic: schematic)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Textures from Test pack'), findsOneWidget);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).last,
      );
      late ByteData pixels;
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });

      var greenTop = 0;
      var redSide = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        final r = pixels.getUint8(i);
        final g = pixels.getUint8(i + 1);
        final b = pixels.getUint8(i + 2);
        if (g > 90 && g > r * 2 && g > b * 2) greenTop++;
        if (r > 90 && r > g * 2 && r > b * 2) redSide++;
      }
      image.dispose();

      // Green only appears if the camera is actually above the build. Getting
      // the pitch sign wrong draws every block from underneath, which a
      // single-colour check cannot see but this one can.
      expect(greenTop, greaterThan(200),
          reason: 'the top face should be drawn, and wear the top texture');
      expect(redSide, greaterThan(200),
          reason: 'the side faces should wear the side texture');
    });

    testWidgets('simplifies a build too large to draw block-for-block',
        (tester) async {
      // Comfortably past the viewer's voxel budget, so the preview has to
      // downsample and say that it did.
      final big = _sample(width: 90, height: 60, length: 90);
      await tester.pumpWidget(_app(SchematicViewer(schematic: big)));
      await tester.pumpAndSettle();

      expect(find.textContaining('simplified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

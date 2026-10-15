import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/converter/schematic/schematic_model.dart';
import 'package:luma/features/converter/schematic/textures/block_atlas.dart';
import 'package:luma/features/converter/schematic/textures/block_model_resolver.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_source_io.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_types.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_tool_catalog.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_tool_host.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/minecraft_tools_page.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Uint8List _striped(int left, int right) {
  final image = img.Image(width: 16, height: 16, numChannels: 4);
  for (var y = 0; y < 16; y++) {
    for (var x = 0; x < 16; x++) {
      final color = x < 8 ? left : right;
      image.setPixelRgba(
        x,
        y,
        (color >> 16) & 255,
        (color >> 8) & 255,
        color & 255,
        (color >> 24) & 255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

RawTextureData _pack() => RawTextureData(
  label: 'Preview test pack',
  textures: {
    'block/dirt': _striped(0xFFFF0000, 0xFF0000FF),
    'block/bedrock': _striped(0xFF808080, 0xFF404040),
    'block/grass_block_side': _striped(0xFFFFFF00, 0xFF00FFFF),
    'block/grass_block_top': _striped(0xFFFF00FF, 0xFFFF00FF),
    'block/water_still': _striped(0xFF00FF00, 0xFFFFFFFF),
    'item/firework_rocket': _striped(0xFFFF00FF, 0xFF00FF00),
    for (var i = 0; i < 8; i++)
      'particle/spark_$i': _striped(0xFFFFFFFF, 0xFF00FF00),
  },
  blockstates: const {
    'grass_block':
        '{"variants":{'
        '"snowy=false":{"model":"minecraft:block/grass_block"},'
        '"snowy=true":{"model":"minecraft:block/grass_block_snow"}}}',
  },
  models: {
    'block/grass_block': jsonEncode({
      'textures': {
        'side': 'minecraft:block/grass_block_side',
        'top': 'minecraft:block/grass_block_top',
      },
    }),
  },
);

Future<void> _open(
  WidgetTester tester,
  McTool tool, {
  double width = 1400,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: buildMcTool(McToolHost(tool: tool, onBack: () {})),
      ),
    ),
  );
  await tester.pump();
}

/// Replays the actual tool painter selected by its widget, so assertions
/// check rendered texture pixels rather than the presence of an atlas field.
Future<img.Image> _pixels(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  final widget = tester.widget<CustomPaint>(finder);
  final size = tester.getSize(finder);
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    widget.painter!.paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: bytes!.buffer,
      numChannels: 4,
    );
    image.dispose();
    picture.dispose();
    return result;
  }))!;
}

int _rgb(img.Pixel pixel) =>
    (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();

void main() {
  setUp(() {
    BlockAtlas.autoLoad = false;
    BlockAtlas.resetForTesting();
  });
  tearDown(() {
    BlockAtlas.resetForTesting();
    BlockAtlas.autoLoad = true;
  });

  Future<void> install(WidgetTester tester) async {
    final atlas = await tester.runAsync(
      () => BlockAtlas.fromBitmap(buildAtlas(_pack())),
    );
    BlockAtlas.installForTesting(atlas);
    addTearDown(() => atlas?.image.dispose());
  }

  testWidgets('flat cross-section repeats square side textures per block', (
    tester,
  ) async {
    await install(tester);
    await _open(tester, McTool.flatPreset);
    final image = await _pixels(tester, 'mc-flat-cross-section');
    final dirtY = image.height - 60;
    expect(_rgb(image.getPixel(6, dirtY)), 0xFF0000);
    expect(_rgb(image.getPixel(18, dirtY)), 0x0000FF);
    expect(_rgb(image.getPixel(30, dirtY)), 0xFF0000);
    final grassY = image.height - 84;
    expect(_rgb(image.getPixel(6, grassY)), 0xFFFF00);
    expect(_rgb(image.getPixel(18, grassY)), 0x00FFFF);
    expect(find.textContaining('Preview test pack'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flat layers update texture when the block changes', (
    tester,
  ) async {
    await install(tester);
    await _open(tester, McTool.flatPreset);
    await tester.tap(find.text('Desert'));
    await tester.pump();
    final image = await _pixels(tester, 'mc-flat-cross-section');
    // Sand is absent from the fixture pack, so it must fall back instead of
    // keeping the grass or dirt texture from the previous preset.
    final colors = {for (var x = 2; x < 70; x++) _rgb(image.getPixel(x, 3))};
    expect(colors.length, 1);
    expect(colors, isNot(contains(0xFFFF00)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('water world uses the tinted fluid texture', (tester) async {
    await install(tester);
    await _open(tester, McTool.flatPreset);
    await tester.tap(find.text('Water World'));
    await tester.pump();
    final image = await _pixels(tester, 'mc-flat-cross-section');
    expect(_rgb(image.getPixel(2, 3)), 0x007600);
    expect(_rgb(image.getPixel(6, 3)), 0x3F76E4);
  });

  testWidgets('firework launch uses the rocket item texture', (tester) async {
    await install(tester);
    await _open(tester, McTool.fireworkMaker);
    await tester.pump(const Duration(milliseconds: 300));
    final image = await _pixels(tester, 'mc-firework-preview');
    expect(image.any((p) => _rgb(p) == 0xFF00FF), isTrue);
    expect(image.any((p) => _rgb(p) == 0x00FF00), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('firework burst and trails use tinted particle textures', (
    tester,
  ) async {
    await install(tester);
    await _open(tester, McTool.fireworkMaker);
    await tester.pump(const Duration(milliseconds: 1600));
    final image = await _pixels(tester, 'mc-firework-preview');
    expect(image.any((p) => p.g > 100 && p.r < 5 && p.b < 5), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final tool in [McTool.flatPreset, McTool.fireworkMaker]) {
    testWidgets(
      '${tool.name} stays usable without assets and offers a source',
      (tester) async {
        await _open(tester, tool);
        expect(
          find.widgetWithText(TextButton, 'Download textures'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${tool.name} texture controls fit a narrow window', (
      tester,
    ) async {
      await _open(tester, tool, width: 320);
      expect(tester.takeException(), isNull);
    });
  }

  test('jar reader includes firework sprites without importing every item', () {
    final temp = Directory.systemTemp.createTempSync('mc_preview_textures');
    addTearDown(() => temp.deleteSync(recursive: true));
    final archive = Archive();
    for (final name in [..._pack().textures.keys, 'item/diamond']) {
      archive.addFile(
        ArchiveFile.bytes(
          'assets/minecraft/textures/$name.png',
          _striped(0xFFFFFFFF, 0xFF808080),
        ),
      );
    }
    final file = File('${temp.path}/test.jar')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    final data = readTexturePack(file.path);
    expect(data.textures.keys, containsAll(_pack().textures.keys));
    expect(data.textures.keys, isNot(contains('item/diamond')));
    expect(buildAtlas(data).tiles.keys, contains('particle/spark_7'));
  });

  test('firework sprites alone do not make a valid block atlas', () {
    final bitmap = buildAtlas(
      RawTextureData(
        textures: {'item/firework_rocket': _striped(0xFFFFFFFF, 0xFF808080)},
        blockstates: const {},
        models: const {},
        label: 'Items only',
      ),
    );
    expect(bitmap.width, 0);
    expect(bitmap.tiles, isEmpty);
  });

  test(
    'omitted state properties resolve while explicit states are respected',
    () {
      final data = _pack();
      final resolver = BlockModelResolver(
        blockstates: data.blockstates,
        models: {
          ...data.models,
          'block/grass_block_snow': '{"textures":{"all":"block/snow"}}',
        },
      );
      expect(
        resolver.facesFor(BlockState('minecraft:grass_block')).textures[4],
        'block/grass_block_side',
      );
      expect(
        resolver
            .facesFor(BlockState('minecraft:grass_block', {'snowy': 'true'}))
            .textures[4],
        'block/snow',
      );
      expect(
        resolver.facesFor(BlockState('minecraft:lava')).textures[4],
        'block/lava_still',
      );
    },
  );
}

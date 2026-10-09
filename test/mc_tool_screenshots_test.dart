// Renders every Minecraft tool in each of luma's four backgrounds and writes
// the result to assets/mc_tools/shots/, where the hub's cards and spotlight
// pick them up as banners.
//
// Off by default — it rewrites committed assets and wants the machine's
// fonts and a Minecraft client jar. Regenerate after a tool's look changes:
//
//   flutter test test/mc_tool_screenshots_test.dart --dart-define=MC_SHOTS=true
//
// Narrow it with --dart-define=MC_SHOTS_ONLY=enchantOptimizer,bannerMaker
// and --dart-define=MC_SHOTS_VARIANTS=light,coffee_dark; point it at a jar
// with --dart-define=MC_SHOTS_JAR=<path>.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/converter/schematic/schematic_model.dart';
import 'package:luma/features/converter/schematic/schematic_service.dart';
import 'package:luma/features/converter/schematic/textures/block_atlas.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_source_io.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_shots.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_tool_catalog.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_tool_host.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/minecraft_tools_page.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/tools/players/build_planner_tool.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/tools/players/map_art_tool.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

import 'mc_tool_screenshots_demo.dart';

const _enabled = bool.fromEnvironment('MC_SHOTS');
const _only = String.fromEnvironment('MC_SHOTS_ONLY');
const _variants = String.fromEnvironment('MC_SHOTS_VARIANTS');
const _jar = String.fromEnvironment('MC_SHOTS_JAR');

BlockAtlas? _atlas;

/// A Minecraft client jar to take block textures from: --dart-define=
/// MC_SHOTS_JAR, else the newest one Loom or the launcher has on disk.
String? _clientJar() {
  if (_jar.isNotEmpty) return _jar;
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null) return null;
  final candidates = <File>[
    for (final root in [
      '$home/.gradle/caches/fabric-loom',
      '$home/AppData/Roaming/.minecraft/versions',
      '$home/.minecraft/versions',
    ])
      if (Directory(root).existsSync())
        for (final dir in Directory(root).listSync().whereType<Directory>())
          for (final f in dir.listSync().whereType<File>())
            if (f.path.endsWith('minecraft-client.jar') ||
                f.path.endsWith('${dir.uri.pathSegments.reversed.skip(1).first}.jar'))
              f,
  ]..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return candidates.firstOrNull?.path;
}

/// The window the tools are laid out in. Wide enough for every tool's
/// desktop split, short enough that the banner shows the interesting top.
const _window = Size(1180, 860);

/// The banner's shape and its size on disk.
const _shotAspect = 16 / 9;
const _shotWidth = 960;

Future<void> _loadFonts() async {
  // flutter_test draws text in a box font; swap in the faces the app really
  // gets on Windows so the banners read like the app.
  const winFonts = r'C:\Windows\Fonts';
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    var any = false;
    for (final path in files) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      any = true;
    }
    if (any) await loader.load();
  }

  final segoe = [
    for (final f in [
      'segoeuil.ttf', 'segoeuisl.ttf', 'segoeui.ttf', 'seguisb.ttf',
      'segoeuib.ttf', 'seguibl.ttf',
    ])
      '$winFonts/$f',
  ];
  final roboto = [
    for (final f in [
      'roboto-light.ttf', 'roboto-regular.ttf', 'roboto-medium.ttf',
      'roboto-bold.ttf', 'roboto-black.ttf',
    ])
      '$materialFonts/$f',
  ];
  final body = File(segoe[2]).existsSync() ? segoe : roboto;
  // The test platform is Android, whose default family is Roboto; Windows
  // users see Segoe UI, so it stands in under both names.
  await family('Roboto', body);
  await family('Segoe UI', body);
  await family('MaterialIcons', ['$materialFonts/materialicons-regular.otf']);
  await family('Consolas', ['$winFonts/consola.ttf', '$winFonts/consolab.ttf']);
  await family('Georgia', ['$winFonts/georgia.ttf', '$winFonts/georgiab.ttf']);
}

/// A stand-in for the app support folder: the client jar where the launcher
/// keeps one (the asset library looks there), and a folder of demo builds
/// the schematic organizer already points at.
Future<Directory> _fakeSupportDir() async {
  final root = await Directory.systemTemp.createTemp('mc_shots');
  final jar = _clientJar();
  if (jar != null) {
    final dest = File('${root.path}/minecraft/versions/26.3/26.3.jar');
    dest.parent.createSync(recursive: true);
    File(jar).copySync(dest.path);
  }
  // Relative to the project (and git-ignored), so the organizer's banner
  // shows a neutral path rather than whoever ran this.
  final builds = Directory('build/.minecraft/schematics');
  if (builds.existsSync()) builds.deleteSync(recursive: true);
  builds.createSync(recursive: true);
  for (final (schematic, format) in [
    (demoCottage(), SchematicFormat.litematic),
    (demoTower(), SchematicFormat.litematic),
    (demoTree(), SchematicFormat.litematic),
    (demoFountain(), SchematicFormat.litematic),
    (demoBridge(), SchematicFormat.litematic),
  ]) {
    final export = SchematicService.save(schematic, format);
    File('${builds.path}/${schematic.name}.${format.extension}')
        .writeAsBytesSync(export.bytes);
  }
  final settings = File('${root.path}/minecraft_tools/schematic_organizer.json');
  settings.parent.createSync(recursive: true);
  settings.writeAsStringSync(jsonEncode({
    'folder': builds.path,
    'favorites': [
      '${builds.path}${Platform.pathSeparator}Cozy Cottage.litematic',
    ],
    'groups': <String, String>{},
  }));
  return root;
}

/// The Pointer painting from the client jar: a real, colourful picture for the
/// map art banner.
Uint8List? _panorama() {
  final jar = _clientJar();
  if (jar == null) return null;
  final archive = ZipDecoder().decodeBytes(File(jar).readAsBytesSync());
  for (final name in [
    'assets/minecraft/textures/painting/pointer.png',
    'assets/minecraft/textures/painting/sunset.png',
  ]) {
    final file = archive.findFile(name);
    if (file != null) return file.content;
  }
  return null;
}

void main() {
  if (!_enabled) {
    test('screenshots are off without --dart-define=MC_SHOTS=true', () {});
    return;
  }

  final only = _only.isEmpty ? null : _only.split(',').map((s) => s.trim()).toSet();
  final outRoot = Directory('assets/mc_tools/shots');
  late Directory support;
  Uint8List? panorama;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    support = await _fakeSupportDir();
    panorama = _panorama();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => support.path,
    );
    // The asset library keeps an audio player; nothing plays here.
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });

  tearDownAll(() {
    try {
      support.deleteSync(recursive: true);
    } on FileSystemException {
      // A file still held open on Windows; the temp folder is swept later.
    }
  });

  // MC_SHOTS_HUB=true: a picture of the hub itself per background, into
  // build/, for checking the page after a design change.
  if (const bool.fromEnvironment('MC_SHOTS_HUB')) {
    for (final variant in McShotVariant.values) {
      testWidgets('hub / ${variant.name}', (tester) async {
        const size = Size(1440, 1700);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: variant.theme,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: RepaintBoundary(
              key: boundary,
              child: const Scaffold(body: MinecraftToolsPage()),
            ),
          ),
        );
        final context = tester.element(find.byType(MinecraftToolsPage));
        await tester.runAsync(() async {
          for (final tool in McAudience.players.tools) {
            await precacheImage(AssetImage(mcShotAsset(tool, variant)), context);
          }
        });
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        final bytes = await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 0.75);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        File('build/mc_hub_${variant.dir}.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
        await tester.pumpWidget(const SizedBox());
      });
    }
    return;
  }

  for (final variant in McShotVariant.values) {
    if (_variants.isNotEmpty && !_variants.split(',').contains(variant.dir)) {
      continue;
    }
    for (final tool in McTool.values) {
      if (only != null && !only.contains(tool.name)) continue;
      testWidgets('${variant.name} / ${tool.name}', (tester) async {
        tester.view.physicalSize = _window;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // The asset library's audio player opens event channels under
        // random names, so they can't be mocked up front; its missing
        // plugin has nothing to do with how the screen looks.
        final onError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exception is MissingPluginException) return;
          onError?.call(details);
        };

        // Real block textures, so the 3D tools show actual blocks. Built
        // once, outside the fake clock: a load started from a tool's
        // initState would never finish.
        BlockAtlas.autoLoad = false;
        await tester.runAsync(() async {
          final jar = _clientJar();
          if (_atlas == null && jar != null) {
            final bitmap = await Isolate.run(() => readAndBuildAtlas(jar));
            _atlas = await BlockAtlas.fromBitmap(bitmap);
          }
        });
        BlockAtlas.installForTesting(_atlas);

        final host = McToolHost(tool: tool, onBack: () {});
        final Widget body = switch (tool) {
          McTool.buildPlanner =>
            BuildPlannerTool(host: host, initial: demoCottage()),
          McTool.mapArtGenerator => MapArtTool(
            host: host,
            initialImage: panorama,
            initialName: 'panorama',
          ),
          _ => MinecraftToolsPage(initialTool: tool),
        };

        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: variant.theme,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(body: body),
            ),
          ),
        );

        // Let async loads (files, isolates, textures) land between frames.
        Future<void> settle(int rounds) async {
          for (var i = 0; i < rounds; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)),
            );
            await tester.pump(const Duration(milliseconds: 150));
          }
        }

        await settle(tool == McTool.assetLibrary ? 30 : 8);
        await _stage(tool, tester);
        await settle(tool == McTool.schematicOrganizer ? 60 : 5);

        if (const bool.fromEnvironment('MC_SHOTS_DEBUG')) {
          // Text that names no font family: drawn as boxes here.
          void visit(RenderObject o) {
            if (o is RenderParagraph && o.text.style?.fontFamily == null) {
              // ignore: avoid_print
              print('NO FAMILY ${tool.name}: "${o.text.toPlainText()}" ${o.debugCreator}'.split('\n').first);
            }
            o.visitChildren(visit);
          }
          visit(tester.renderObject(find.byKey(boundary)));
        }
        // Crop off the frame's heading: the card already names the tool.
        final t = L.of(tester.element(find.byKey(boundary)));
        final subtitle = find.text(tool.blurb(t));
        final top = subtitle.evaluate().isEmpty
            ? 0.0
            : tester.getRect(subtitle.first).bottom + 6;
        final width = _window.width;
        final height = width / _shotAspect;
        final crop = Rect.fromLTWH(0, top, width, height)
            .intersect(Offset.zero & _window);

        final bytes = await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final scale = _shotWidth / width;
          final image = await render.toImage(pixelRatio: scale);
          final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final full = img.Image.fromBytes(
            width: image.width,
            height: image.height,
            bytes: data!.buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          final cropped = img.copyCrop(
            full,
            x: 0,
            y: (crop.top * scale).round(),
            width: image.width,
            height: (crop.height * scale).round(),
          );
          image.dispose();
          return img.encodeJpg(cropped, quality: 82);
        });

        final file = File('${outRoot.path}/${variant.dir}/${tool.name}.jpg');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!);

        await tester.pumpWidget(const SizedBox());
        await settle(2);
        FlutterError.onError = onError;
      });
    }
  }
}

/// Puts a tool into a state worth showing before it is captured. Tools not
/// listed open looking good already.
Future<void> _stage(McTool tool, WidgetTester tester) async {
  switch (tool) {
    case McTool.enchantOptimizer:
      // A god sword, picked the way a player would: one level at a time.
      for (final (name, level) in const [
        ('Sharpness', 'V'),
        ('Looting', 'III'),
        ('Sweeping Edge', 'III'),
        ('Fire Aspect', 'II'),
        ('Unbreaking', 'III'),
        ('Mending', 'I'),
      ]) {
        final row = find.ancestor(of: find.text(name), matching: find.byType(Row));
        if (row.evaluate().isEmpty) continue;
        final button = find.descendant(
          of: row.first,
          matching: find.ancestor(of: find.text(level), matching: find.byType(InkWell)),
        );
        if (button.evaluate().isEmpty) continue;
        tester.widget<InkWell>(button.first).onTap?.call();
        await tester.pump();
      }
    default:
      break;
  }
}

/// Gives every text style a real family. Material 3 leaves some (button
/// labels, menus) without one, and flutter_test draws those as boxes.
ThemeData _withFonts(ThemeData theme) {
  TextStyle? fix(TextStyle? s) =>
      s == null || (s.fontFamily != null && s.fontFamily != 'Roboto')
      ? s
      : s.copyWith(fontFamily: 'Segoe UI');
  TextTheme all(TextTheme tt) => tt.copyWith(
    displayLarge: fix(tt.displayLarge),
    displayMedium: fix(tt.displayMedium),
    displaySmall: fix(tt.displaySmall),
    headlineLarge: fix(tt.headlineLarge),
    headlineMedium: fix(tt.headlineMedium),
    headlineSmall: fix(tt.headlineSmall),
    titleLarge: fix(tt.titleLarge),
    titleMedium: fix(tt.titleMedium),
    titleSmall: fix(tt.titleSmall),
    bodyLarge: fix(tt.bodyLarge),
    bodyMedium: fix(tt.bodyMedium),
    bodySmall: fix(tt.bodySmall),
    labelLarge: fix(tt.labelLarge),
    labelMedium: fix(tt.labelMedium),
    labelSmall: fix(tt.labelSmall),
  );
  return theme.copyWith(
    textTheme: all(theme.textTheme),
    primaryTextTheme: all(theme.primaryTextTheme),
  );
}

extension on McShotVariant {
  ThemeData get theme => _withFonts(switch (this) {
    McShotVariant.light => LumaTheme.from(Brightness.light),
    McShotVariant.dark => LumaTheme.from(Brightness.dark),
    McShotVariant.coffeeLight =>
      LumaTheme.from(Brightness.light, null, LumaThemeStyle.coffee),
    McShotVariant.coffeeDark =>
      LumaTheme.from(Brightness.dark, null, LumaThemeStyle.coffee),
  });
}

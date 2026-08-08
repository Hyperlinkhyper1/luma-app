import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_media.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_page.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_repository.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_scope.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_source.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_tile.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/theme/luma_theme.dart';

/// A library with no device under it. Thumbnails are a real 2×2 JPEG so the
/// tiles decode something rather than falling back to their placeholder.
class FakeGallerySource extends GallerySource {
  FakeGallerySource({
    required this.items,
    this.access = GalleryAccess.granted,
  });

  final List<GalleryItem> items;
  final GalleryAccess access;

  static final Uint8List _pixel = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 2, height: 2)),
  );

  @override
  Future<GalleryAccess> requestAccess() async => access;

  @override
  Future<List<GalleryItem>> load() async => List.of(items);

  @override
  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) async => _pixel;

  @override
  Future<String?> resolvePath(GalleryItem item) async => item.path;

  @override
  Future<GalleryItem> enrich(GalleryItem item) async => item;
}

GalleryItem _item({
  required String name,
  required String folder,
  GalleryMediaType type = GalleryMediaType.image,
  DateTime? takenAt,
}) =>
    GalleryItem(
      id: '$folder/$name',
      name: name,
      type: type,
      folder: folder,
      takenAt: takenAt ?? DateTime(2026, 7, 31, 12),
      width: 4000,
      height: 3000,
    );

final _library = [
  _item(name: 'IMG_1.jpg', folder: 'DCIM/Camera'),
  _item(name: 'IMG_2.jpg', folder: 'DCIM/Camera'),
  _item(
    name: 'VID_1.mp4',
    folder: 'DCIM/Camera',
    type: GalleryMediaType.video,
  ),
  _item(name: 'Screenshot_1.png', folder: 'Pictures/Screenshots'),
  _item(name: 'IMG-WA0001.jpg', folder: 'WhatsApp/Media/WhatsApp Images'),
  _item(name: 'meme.gif', folder: 'Download'),
];

/// Loading settings touches real async I/O, so it runs outside the widget
/// tester's fake clock; there is no path_provider on the host, so the
/// controller stays in memory.
Future<SettingsController> _settings(WidgetTester tester, String plan) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  controller.setAdminPlan(plan);
  return controller;
}

Future<GalleryRepository> _pump(
  WidgetTester tester, {
  List<GalleryItem>? items,
  GalleryAccess access = GalleryAccess.granted,
  String plan = 'core',
}) async {
  tester.view.physicalSize = const Size(1100, 2000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final settings = await _settings(tester, plan);
  final repository = GalleryRepository(
    source: FakeGallerySource(
      items: items ?? _library,
      access: access,
    ),
  );
  addTearDown(repository.dispose);

  // The scan (and the cache read behind it) is real async I/O, so it runs
  // outside the widget tester's fake clock. By the time the page is pumped
  // the repository is already loaded, and its own initialise() is a no-op.
  await tester.runAsync(repository.initialise);

  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      home: SettingsScope(
        controller: settings,
        child: GalleryScope(
          repository: repository,
          child: const Scaffold(body: GalleryPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  return repository;
}

/// Taps a pill in the strip. The strip scrolls horizontally, so a tab far
/// enough along is off-screen and has to be brought into view first.
Future<void> _selectTab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the tab strip lists the fixed tabs then the folders',
      (tester) async {
    await _pump(tester);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pictures'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    expect(find.text('GIFs'), findsOneWidget);
    expect(find.text('WhatsApp Images'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    // Camera would only repeat Pictures and Videos.
    expect(find.text('Camera'), findsNothing);
  });

  testWidgets('the grid shows every item, under a date heading',
      (tester) async {
    await _pump(tester);

    expect(find.byType(GalleryTile), findsNWidgets(_library.length));
    expect(find.text('July 31'), findsOneWidget);
    expect(find.textContaining('6 items'), findsOneWidget);
  });

  testWidgets('picking a tab narrows the grid to that category',
      (tester) async {
    await _pump(tester);

    await _selectTab(tester, 'Pictures');
    expect(find.byType(GalleryTile), findsNWidgets(2));

    await _selectTab(tester, 'Downloads');
    expect(find.byType(GalleryTile), findsOneWidget);
  });

  testWidgets('a video tile is badged with its length', (tester) async {
    await _pump(tester, items: [
      GalleryItem(
        id: 'v',
        name: 'VID.mp4',
        type: GalleryMediaType.video,
        folder: 'DCIM/Camera',
        takenAt: DateTime(2026, 7, 31),
        duration: const Duration(minutes: 4, seconds: 7),
      ),
    ]);

    expect(find.text('4:07'), findsOneWidget);
  });

  testWidgets('smart categories are offered, not given, below Nova',
      (tester) async {
    await _pump(tester);

    expect(find.text('✦ Smart'), findsOneWidget);
    await _selectTab(tester, '✦ Smart');
    expect(find.textContaining('Nova extra'), findsOneWidget);
  });

  testWidgets('Nova gets the smart tabs instead of the upsell',
      (tester) async {
    await _pump(tester, plan: 'nova');

    expect(find.text('✦ Smart'), findsNothing);
  });

  testWidgets('a refused grant explains itself and offers a way back',
      (tester) async {
    await _pump(tester, access: GalleryAccess.denied);

    expect(find.byType(LumaEmptyState), findsOneWidget);
    expect(find.byType(GalleryTile), findsNothing);
  });

  testWidgets('an empty library says so rather than showing a blank grid',
      (tester) async {
    await _pump(tester, items: const []);

    expect(find.text('No photos or videos yet'), findsOneWidget);
  });

  testWidgets('the map button stays disabled until something has a location',
      (tester) async {
    await _pump(tester);

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.map_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}

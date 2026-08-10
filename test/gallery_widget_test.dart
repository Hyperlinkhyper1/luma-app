import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_album_card.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_categories.dart';
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
    this.blockThumbnails = false,
  });

  final List<GalleryItem> items;
  final GalleryAccess access;

  /// Hold every thumbnail request open, so a test can look at how many the
  /// repository let through at once.
  final bool blockThumbnails;

  final List<Completer<Uint8List?>> pendingThumbnails = [];

  /// Requests that reached the source, as opposed to ones queued behind the
  /// concurrency limit.
  int startedThumbnails = 0;

  static final Uint8List _pixel = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 2, height: 2)),
  );

  @override
  Future<GalleryAccess> requestAccess() async => access;

  @override
  Future<List<GalleryItem>> load() async => List.of(items);

  @override
  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) async {
    startedThumbnails++;
    if (!blockThumbnails) return _pixel;
    final completer = Completer<Uint8List?>();
    pendingThumbnails.add(completer);
    return completer.future;
  }

  @override
  Future<String?> resolvePath(GalleryItem item) async => item.path;

  /// Items the repository asked for coordinates.
  final List<String> enriched = [];

  @override
  Future<GalleryItem> enrich(GalleryItem item) async {
    enriched.add(item.id);
    return item;
  }
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

/// A folder needs [minimumAlbumItems] pictures before it becomes an album, so
/// the app folders here carry three apiece.
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
  _item(name: 'IMG-WA0002.jpg', folder: 'WhatsApp/Media/WhatsApp Images'),
  _item(name: 'IMG-WA0003.jpg', folder: 'WhatsApp/Media/WhatsApp Images'),
  _item(name: 'meme.gif', folder: 'Download'),
  _item(name: 'invoice.png', folder: 'Download'),
  _item(name: 'receipt.png', folder: 'Download'),
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

/// Opens an album by tapping its card. Cards further down the page have to be
/// scrolled to first.
Future<void> _openAlbum(WidgetTester tester, String label) async {
  final card = find.ancestor(
    of: find.text(label),
    matching: find.byType(GalleryAlbumCard),
  );
  await tester.ensureVisible(card.first);
  await tester.pumpAndSettle();
  await tester.tap(card.first);
  await tester.pumpAndSettle();
}

/// Back out of an album to the albums screen.
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the gallery opens on albums, not on a wall of photos',
      (tester) async {
    await _pump(tester);

    expect(find.byType(GalleryAlbumCard), findsWidgets);
    // No photo grid until an album is opened.
    expect(find.byType(GalleryTile), findsNothing);

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

  testWidgets('each album card carries its own count', (tester) async {
    await _pump(tester);

    Finder subtitleOf(String label) => find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(GalleryAlbumCard),
          ),
          matching: find.textContaining('item'),
        );

    expect(tester.widget<Text>(subtitleOf('All')).data, '10 items');
    expect(tester.widget<Text>(subtitleOf('Pictures')).data, '2 items');
    expect(tester.widget<Text>(subtitleOf('Downloads')).data, '3 items');
  });

  testWidgets('an album card shows its newest photo as the cover',
      (tester) async {
    final repository = await _pump(tester, items: [
      _item(
        name: 'old.jpg',
        folder: 'Download',
        takenAt: DateTime(2020, 1, 1),
      ),
      _item(
        name: 'middle.jpg',
        folder: 'Download',
        takenAt: DateTime(2023, 1, 1),
      ),
      _item(
        name: 'newest.jpg',
        folder: 'Download',
        takenAt: DateTime(2026, 5, 5),
      ),
    ]);

    final downloads = repository.categories
        .firstWhere((c) => c.label == 'Downloads');
    expect(downloads.cover?.name, 'newest.jpg');
  });

  testWidgets('opening an album shows its photos under a date heading',
      (tester) async {
    await _pump(tester);

    await _openAlbum(tester, 'All');
    expect(find.byType(GalleryTile), findsNWidgets(_library.length));
    expect(find.text('July 31'), findsOneWidget);
  });

  testWidgets('each album opens only its own photos', (tester) async {
    await _pump(tester);

    await _openAlbum(tester, 'Pictures');
    expect(find.byType(GalleryTile), findsNWidgets(2));

    await _back(tester);
    await _openAlbum(tester, 'Downloads');
    expect(find.byType(GalleryTile), findsNWidgets(3));
  });

  testWidgets('backing out of an album returns to the albums screen',
      (tester) async {
    await _pump(tester);

    await _openAlbum(tester, 'Screenshots');
    expect(find.byType(GalleryTile), findsOneWidget);

    await _back(tester);
    expect(find.byType(GalleryAlbumCard), findsWidgets);
    expect(find.byType(GalleryTile), findsNothing);
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
    await _openAlbum(tester, 'Videos');

    expect(find.text('4:07'), findsOneWidget);
  });

  testWidgets('smart albums are offered, not given, below Nova',
      (tester) async {
    await _pump(tester);

    expect(find.text('Nova'), findsOneWidget);
    await _openAlbum(tester, 'Smart albums');
    expect(find.textContaining('Nova extra'), findsOneWidget);
  });

  testWidgets('Nova gets real smart albums instead of the upsell card',
      (tester) async {
    await _pump(tester, plan: 'nova');

    expect(find.text('Nova'), findsNothing);
    expect(find.text('Included with Nova'), findsNothing);
  });

  testWidgets('a refused grant explains itself and offers a way back',
      (tester) async {
    await _pump(tester, access: GalleryAccess.denied);

    expect(find.byType(LumaEmptyState), findsOneWidget);
    expect(find.byType(GalleryAlbumCard), findsNothing);
  });

  testWidgets('an empty library says so rather than showing a blank grid',
      (tester) async {
    await _pump(tester, items: const []);

    expect(find.text('No photos or videos yet'), findsOneWidget);
  });

  testWidgets('opening a big album does not ask for every thumbnail at once',
      (tester) async {
    // The freeze this guards against: every tile asked for its picture the
    // moment it was built, so opening an album kicked off a screenful of
    // decodes in one frame — on desktop, one isolate each.
    final source = FakeGallerySource(
      items: [
        for (var i = 0; i < 300; i++)
          _item(
            name: 'IMG_$i.jpg',
            folder: 'DCIM/Camera',
            takenAt: DateTime(2026, 7, 31, 12, 0, i),
          ),
      ],
      blockThumbnails: true,
    );

    tester.view.physicalSize = const Size(1100, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final settings = await _settings(tester, 'core');
    final repository = GalleryRepository(source: source);
    addTearDown(repository.dispose);
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

    source.startedThumbnails = 0;
    await _openAlbum(tester, 'Pictures');

    // Every visible tile has asked, but only a handful are in flight; the
    // rest wait for a slot. The exact cap is platform-dependent, so this
    // asserts the property that matters: it is bounded, and far below the
    // number of tiles on screen.
    expect(source.startedThumbnails, greaterThan(0));
    expect(source.startedThumbnails, lessThanOrEqualTo(4));
    expect(find.byType(GalleryTile), findsWidgets);
  });

  testWidgets('two tiles wanting the same picture decode it once',
      (tester) async {
    final source = FakeGallerySource(items: _library);
    final repository = GalleryRepository(source: source);
    addTearDown(repository.dispose);
    await tester.runAsync(repository.initialise);

    final item = repository.items.first;
    await tester.runAsync(() async {
      await Future.wait([
        repository.thumbnail(item, 256),
        repository.thumbnail(item, 256),
        repository.thumbnail(item, 256),
      ]);
    });

    expect(source.startedThumbnails, 1);
  });

  testWidgets('the albums grid lays out three-up on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    // Three cards across, and the row is inside the screen — no overflow.
    final cards = tester.widgetList<GalleryAlbumCard>(
      find.byType(GalleryAlbumCard),
    );
    expect(cards.length, greaterThanOrEqualTo(6));

    final width = tester.getSize(find.byType(GalleryAlbumCard).first).width;
    final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(width * 3, lessThan(screen));
  });

  testWidgets('the map is reachable before any coordinates have been read',
      (tester) async {
    // Coordinates are only read once the map is opened, so "no pins yet" is
    // the normal state on a first visit — not a reason to disable the button.
    final repository = await _pump(tester);
    expect(repository.hasLocatedItems, isFalse);

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.map_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the scan does not read locations on its own', (tester) async {
    // Reading a GPS tag opens the file. Doing that for the whole library on
    // open is what made the plugin feel stuck.
    final source = FakeGallerySource(items: _library);
    final repository = GalleryRepository(source: source);
    addTearDown(repository.dispose);

    await tester.runAsync(repository.initialise);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    expect(repository.isLocating, isFalse);
    expect(source.enriched, isEmpty);
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_album_card.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_cache.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_categories.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_media.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_page.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_people.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_repository.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_scope.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_smart.dart';
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
  bool get supportsScanRoot => true;

  @override
  String? get scanRoot => _scanRoot;
  String? _scanRoot;

  @override
  Future<void> setScanRoot(String? path) async => _scanRoot = path;

  @override
  void restoreScanRoot(String? path) => _scanRoot = path;

  @override
  List<String> get knownFolders =>
      {for (final item in items) item.folder}.toList()..sort();

  @override
  Future<List<GalleryItem>> load({GalleryScanProgress? onProgress}) async {
    final within = [
      for (final item in items)
        if (folderWithinScanRoot(item.folder, _scanRoot)) item,
    ];
    onProgress?.call(within.length, within.length);
    return within;
  }

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

/// Stands in for [GalleryAnalyser]. The real one needs `path_provider` (a
/// real model download, a real ONNX or ML Kit session), none of which a
/// widget test's fake platform binding provides — this exercises the
/// repository's bookkeeping (pending/examined/skipped counts, the "up to
/// date" card, re-analysis) without any of that.
///
/// Every third photo comes back skipped, so the skipped/examined split is
/// exercised the same way an OneDrive-heavy library would produce it for
/// real.
class FakeAnalyser extends GalleryAnalyser {
  FakeAnalyser() : super(people: GalleryPeopleStore());

  int _seen = 0;

  @override
  Future<bool> prepare({
    void Function(String label, double? progress)? onProgress,
  }) async =>
      true;

  @override
  Future<GalleryCacheEntry> analyse({
    required GalleryCacheEntry previous,
    required String cacheKey,
    String? path,
    Uint8List? thumbnail,
  }) async {
    _seen++;
    final skip = _seen % 3 == 0;
    return previous.copyWith(
      analysed: true,
      skipped: skip,
      labels: skip ? const [] : const ['stub'],
    );
  }

  @override
  Future<void> dispose() async {}
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
  GalleryAnalyser? analyser,
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
    analyser: analyser,
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

/// Scrolls the albums screen to the bottom. Content past the last section —
/// the sort-progress card — sits beyond a fixed test viewport's cache
/// extent and isn't built until it's been scrolled into view at least once.
Future<void> _scrollAlbumsScreen(WidgetTester tester) async {
  await tester.drag(
    find.byType(CustomScrollView).first,
    const Offset(0, -600),
  );
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

  testWidgets('a library spanning years builds only the visible days',
      (tester) async {
    // The phone crash. An album used to be two slivers per day inside one
    // CustomScrollView; a sliver list is lazy in its children but never in
    // the list of slivers, so a camera roll covering a few years laid out —
    // and kept alive — thousands of them before it could draw a frame. On a
    // desktop that is a stutter; on a phone the OS kills the app.
    //
    // 600 photos on 600 separate days is a modest version of that shape. What
    // is checked is that the number of days costs nothing: only the handful
    // on screen are built.
    final library = [
      for (var day = 0; day < 600; day++)
        _item(
          name: 'IMG_$day.jpg',
          folder: 'DCIM/Camera',
          takenAt: DateTime(2026, 7, 31, 12).subtract(Duration(days: day)),
        ),
    ];
    await _pump(tester, items: library);

    await _openAlbum(tester, 'All');

    final tiles = tester.widgetList(find.byType(GalleryTile)).length;
    expect(tiles, greaterThan(0), reason: 'the grid still shows photos');
    expect(
      tiles,
      lessThan(library.length ~/ 4),
      reason: 'a screenful and its cache, not the whole library',
    );

    // Each day carries a heading, so headings are the direct count of how
    // much of the album got built. Under the old layout all 600 existed.
    final headings = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => (text.data ?? '').startsWith('July') ||
            (text.data ?? '').startsWith('August') ||
            (text.data ?? '').startsWith('June'))
        .length;
    expect(
      headings,
      lessThan(60),
      reason: 'a day heading off screen must not be built at all',
    );
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

  testWidgets('People and Categories are offered, not given, below Nova',
      (tester) async {
    await _pump(tester);

    expect(find.text('Nova'), findsOneWidget);
    await _openAlbum(tester, 'People & Categories');
    expect(find.textContaining('Nova extra'), findsOneWidget);
  });

  testWidgets('Nova gets real People and Categories instead of the upsell',
      (tester) async {
    await _pump(tester, plan: 'nova');

    expect(find.text('Nova'), findsNothing);
    expect(find.text('People & Categories'), findsNothing);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('Memories is free on every plan, unlike People and Categories',
      (tester) async {
    await _pump(tester);
    // Memories sits alongside the Nova-gated card, not behind it.
    expect(find.text('Memories'), findsOneWidget);
    expect(find.text('People & Categories'), findsOneWidget);
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

  testWidgets('a finished pass reports what it managed instead of vanishing',
      (tester) async {
    // The button disappearing with almost-empty albums behind it reads as a
    // bug. When there is nothing left to do, the card says what happened —
    // including how much it could not read, which on a cloud library is most
    // of it.
    final repository =
        await _pump(tester, plan: 'nova', analyser: FakeAnalyser());

    await tester.runAsync(() => repository.analyseSmart());
    await tester.pumpAndSettle();

    expect(repository.pendingAnalysis, 0);
    // The prompt card sits below three sections of album cards — off-screen
    // in this fixed test viewport, and slivers past the cache extent aren't
    // built until scrolled into view.
    await _scrollAlbumsScreen(tester);
    expect(find.text('People and Categories are up to date'), findsOneWidget);
    expect(find.text('Look again'), findsOneWidget);
  });

  testWidgets('photos that could not be read are counted as skipped, not done',
      (tester) async {
    // A fake analyser stands in for the real one — a fresh library never has
    // its models on disk, and this is what that day-one shape looks like.
    final repository =
        await _pump(tester, plan: 'nova', analyser: FakeAnalyser());
    await tester.runAsync(() => repository.analyseSmart());
    await tester.pumpAndSettle();

    final photos = repository.items.where((i) => !i.isVideo).length;
    expect(repository.skippedAnalysis + repository.examinedAnalysis, photos);
    expect(repository.skippedAnalysis, greaterThan(0));
    await _scrollAlbumsScreen(tester);
    expect(find.textContaining('skipped'), findsOneWidget);
  });

  testWidgets('looking again clears the verdicts and starts over',
      (tester) async {
    final repository =
        await _pump(tester, plan: 'nova', analyser: FakeAnalyser());
    await tester.runAsync(() => repository.analyseSmart());
    await tester.pumpAndSettle();
    expect(repository.pendingAnalysis, 0);

    await tester.runAsync(() => repository.reanalyseAll());
    await tester.pumpAndSettle();
    // It ran again rather than finding nothing to do.
    expect(repository.examinedAnalysis + repository.skippedAnalysis,
        greaterThan(0));
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

  testWidgets('a confined scan says so, and says how to undo it',
      (tester) async {
    final repository = await _pump(tester, items: _library);
    expect(find.textContaining('Only scanning'), findsNothing);

    await tester.runAsync(() => repository.setScanRoot('DCIM'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Only scanning DCIM'), findsOneWidget);
    // §1 escape-routes: the confinement outlives a restart, so the way back
    // has to be on the screen rather than buried in the picker.
    expect(find.text('Scan everything'), findsOneWidget);

    await tester.tap(find.text('Scan everything'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only scanning'), findsNothing);
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

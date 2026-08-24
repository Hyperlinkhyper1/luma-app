import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/gallery/gallery_cache.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_categories.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_exif.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_file_editor.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_map_page.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_media.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_smart.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_source_folders.dart';

GalleryItem item({
  required String name,
  required String folder,
  GalleryMediaType type = GalleryMediaType.image,
  DateTime? takenAt,
  int width = 4000,
  int height = 3000,
  double? latitude,
  double? longitude,
  bool cloudOnly = false,
}) =>
    GalleryItem(
      id: '$folder/$name',
      name: name,
      type: type,
      folder: folder,
      takenAt: takenAt ?? DateTime(2026, 7, 31, 12),
      width: width,
      height: height,
      latitude: latitude,
      longitude: longitude,
      cloudOnly: cloudOnly,
    );

void main() {
  group('classification', () {
    test('camera shots come out of DCIM, screenshots never do', () {
      expect(
        isCameraShot(item(name: 'IMG_0001.jpg', folder: 'DCIM/Camera')),
        isTrue,
      );
      expect(
        isCameraShot(item(name: 'IMG_0002.jpg', folder: 'DCIM/100ANDRO')),
        isTrue,
      );
      expect(isCameraShot(item(name: 'IMG_0003.jpg', folder: 'DCIM')), isTrue);
      expect(
        isCameraShot(item(name: 'IMG-2026.jpg', folder: 'Pictures/WhatsApp')),
        isFalse,
      );
      // A screenshot filed under DCIM is still a screenshot.
      expect(
        isCameraShot(
          item(name: 'Screenshot_1.png', folder: 'DCIM/Screenshots'),
        ),
        isFalse,
      );
    });

    test('screen captures are found by folder or by file name', () {
      expect(
        isScreenCapture(
          item(name: 'anything.png', folder: 'Pictures/Screenshots'),
        ),
        isTrue,
      );
      expect(
        isScreenCapture(
          item(name: 'Screenshot_20260731.png', folder: 'Pictures'),
        ),
        isTrue,
      );
      // Screen recordings count too — they are captures of the same screen.
      expect(
        isScreenCapture(item(
          name: 'screenrecord_01.mp4',
          folder: 'Movies',
          type: GalleryMediaType.video,
        )),
        isTrue,
      );
      expect(
        isScreenCapture(item(name: 'IMG_0001.jpg', folder: 'DCIM/Camera')),
        isFalse,
      );
    });

    test('a GIF is one by extension or by MIME type', () {
      expect(item(name: 'party.GIF', folder: 'Download').isGif, isTrue);
      final noExtension = GalleryItem(
        id: '1',
        name: 'image',
        type: GalleryMediaType.image,
        folder: 'Download',
        takenAt: DateTime(2026),
        mimeType: 'image/gif',
      );
      expect(noExtension.isGif, isTrue);
    });
  });

  group('categories', () {
    final library = [
      item(name: 'IMG_1.jpg', folder: 'DCIM/Camera'),
      item(name: 'IMG_2.jpg', folder: 'DCIM/Camera'),
      item(
        name: 'VID_1.mp4',
        folder: 'DCIM/Camera',
        type: GalleryMediaType.video,
      ),
      item(name: 'Screenshot_1.png', folder: 'Pictures/Screenshots'),
      item(name: 'Screenshot_2.png', folder: 'DCIM/Screenshots'),
      item(name: 'IMG-2026-WA0001.jpg', folder: 'WhatsApp/Media/WhatsApp Images'),
      item(name: 'IMG-2026-WA0002.jpg', folder: 'WhatsApp/Media/WhatsApp Images'),
      item(name: 'IMG-2026-WA0003.jpg', folder: 'WhatsApp/Media/WhatsApp Images'),
      item(name: 'meme.gif', folder: 'Download'),
      item(name: 'invoice.png', folder: 'Download'),
      item(name: 'receipt.png', folder: 'Download'),
    ];

    test('the fixed tabs count only what belongs to them', () {
      final categories = buildCategories(library);
      final byId = {for (final c in categories) c.id: c};

      expect(byId[GalleryCategoryIds.all]!.count, 11);
      expect(byId[GalleryCategoryIds.pictures]!.count, 2);
      expect(byId[GalleryCategoryIds.videos]!.count, 1);
      expect(byId[GalleryCategoryIds.screenshots]!.count, 2);
      expect(byId[GalleryCategoryIds.gifs]!.count, 1);
    });

    test('folders get their own tab, minus the ones a fixed tab covers', () {
      final labels = [
        for (final c in buildCategories(library))
          if (c.isFolder) c.label,
      ];
      expect(labels, contains('WhatsApp Images'));
      expect(labels, contains('Downloads'));
      // Camera and Screenshots are already fixed tabs.
      expect(labels, isNot(contains('Camera')));
      expect(labels, isNot(contains('Screenshots')));
    });

    test('every album carries its newest item as a cover', () {
      final categories = buildCategories([
        item(
          name: 'old.jpg',
          folder: 'Download',
          takenAt: DateTime(2020, 1, 1),
        ),
        item(
          name: 'middle.jpg',
          folder: 'Download',
          takenAt: DateTime(2023, 1, 1),
        ),
        item(
          name: 'newest.jpg',
          folder: 'Download',
          takenAt: DateTime(2026, 5, 5),
        ),
      ]);
      final byId = {for (final c in categories) c.id: c};
      expect(byId[GalleryCategoryIds.all]!.cover?.name, 'newest.jpg');
      expect(
        categories.firstWhere((c) => c.label == 'Downloads').cover?.name,
        'newest.jpg',
      );
    });

    test('a cover prefers a local photo over a newer cloud placeholder', () {
      // A cloud placeholder has no thumbnail — asking for one would download
      // the file — so it must not win the cover slot from a photo that can
      // actually be shown.
      final categories = buildCategories([
        item(
          name: 'local.jpg',
          folder: 'OneDrive/Holidays',
          takenAt: DateTime(2024, 1, 1),
        ),
        item(
          name: 'in-the-cloud.jpg',
          folder: 'OneDrive/Holidays',
          takenAt: DateTime(2026, 6, 6),
          cloudOnly: true,
        ),
        item(
          name: 'also-cloud.jpg',
          folder: 'OneDrive/Holidays',
          takenAt: DateTime(2026, 6, 7),
          cloudOnly: true,
        ),
      ]);
      expect(
        categories.firstWhere((c) => c.label == 'Holidays').cover?.name,
        'local.jpg',
      );
    });

    test('an all-cloud album still gets a cover', () {
      final categories = buildCategories([
        item(
          name: 'a.jpg',
          folder: 'OneDrive/Holidays',
          takenAt: DateTime(2024),
          cloudOnly: true,
        ),
        item(
          name: 'b.jpg',
          folder: 'OneDrive/Holidays',
          takenAt: DateTime(2026),
          cloudOnly: true,
        ),
        item(
          name: 'c.jpg',
          folder: 'OneDrive/Holidays',
          takenAt: DateTime(2025),
          cloudOnly: true,
        ),
      ]);
      expect(
        categories.firstWhere((c) => c.label == 'Holidays').cover?.name,
        'b.jpg',
      );
    });

    test('an album with nothing in it has no cover', () {
      final categories = buildCategories(const []);
      expect(categories.single.id, GalleryCategoryIds.all);
      expect(categories.single.cover, isNull);
    });

    test('the same album in two places is one tab', () {
      final categories = buildCategories([
        item(name: 'a.jpg', folder: 'Pictures/Instagram'),
        item(name: 'b.jpg', folder: 'Pictures/Instagram'),
        item(name: 'c.jpg', folder: 'DCIM/Instagram'),
      ]);
      final instagram =
          categories.where((c) => c.label == 'Instagram').toList();
      expect(instagram, hasLength(1));
      expect(instagram.single.count, 3);
      expect(instagram.single.folders, hasLength(2));
    });

    test('a folder with a picture or two in it earns no album', () {
      // Nothing is lost: these are still in All, and still in their folder on
      // disk. What is gained is an albums screen that isn't buried under
      // one-item strays from downloads and extracted archives.
      final categories = buildCategories([
        for (var i = 0; i < minimumAlbumItems - 1; i++)
          item(name: 'stray$i.jpg', folder: 'Download/Extracted'),
        for (var i = 0; i < minimumAlbumItems; i++)
          item(name: 'holiday$i.jpg', folder: 'Pictures/Rome'),
      ]);
      final labels = [for (final c in categories) c.label];
      expect(labels, contains('Rome'));
      expect(labels, isNot(contains('Extracted')));
      // All still holds every one of them.
      expect(
        categories.first.count,
        (minimumAlbumItems - 1) + minimumAlbumItems,
      );
    });

    test('folders no person named get no album, however full', () {
      final categories = buildCategories([
        for (var i = 0; i < 20; i++)
          item(name: 'x$i.jpg', folder: 'Download/1761572236343'),
        for (var i = 0; i < 20; i++)
          item(
            name: 'y$i.jpg',
            folder: 'Download/{0D75C5A9-8574-42CF-9B99-FFD0D2F44FF5}',
          ),
        for (var i = 0; i < 20; i++)
          item(name: 'z$i.jpg', folder: 'Pictures/Wedding'),
      ]);
      final labels = [for (final c in categories) c.label];
      expect(labels, contains('Wedding'));
      expect(labels.where(looksMachineNamed), isEmpty);
    });

    test('machine-named folders are recognised, human ones are not', () {
      expect(looksMachineNamed('1761572236343'), isTrue);
      expect(looksMachineNamed('{0D75C5A9 8574 42CF 9B99 FFD0D2F44FF5}'),
          isTrue);
      expect(looksMachineNamed('a3f5b8c9d0e1f2a3'), isTrue);
      expect(looksMachineNamed('Wedding'), isFalse);
      expect(looksMachineNamed('2026'), isFalse, reason: 'a year is a name');
      expect(looksMachineNamed('Trip 2024'), isFalse);
      expect(looksMachineNamed('Boat'), isFalse);
    });

    test('empty fixed tabs are left out, All never is', () {
      final categories = buildCategories([
        item(name: 'a.jpg', folder: 'Download'),
      ]);
      final ids = [for (final c in categories) c.id];
      expect(ids, contains(GalleryCategoryIds.all));
      expect(ids, isNot(contains(GalleryCategoryIds.pictures)));
      expect(ids, isNot(contains(GalleryCategoryIds.videos)));
    });

    test('selecting a category returns its items, newest first', () {
      final categories = buildCategories(library);
      final pictures = categories.firstWhere(
        (c) => c.id == GalleryCategoryIds.pictures,
      );
      expect(itemsInCategory(pictures, library), hasLength(2));

      final whatsapp =
          categories.firstWhere((c) => c.label == 'WhatsApp Images');
      expect(itemsInCategory(whatsapp, library), hasLength(3));
    });

    test('items come back newest first', () {
      final items = [
        item(name: 'old.jpg', folder: 'Download', takenAt: DateTime(2020)),
        item(name: 'new.jpg', folder: 'Download', takenAt: DateTime(2026)),
      ];
      final all = itemsInCategory(
        buildCategories(items).first,
        items,
      );
      expect(all.first.name, 'new.jpg');
    });

    test('folder labels are tidied, not invented', () {
      expect(folderLabel('Download'), 'Downloads');
      expect(folderLabel('holiday_photos'), 'Holiday Photos');
      expect(folderLabel('WhatsApp Images'), 'WhatsApp Images');
      expect(folderLabel(''), 'Other');
    });
  });

  group('date grouping', () {
    final now = DateTime(2026, 7, 31, 18);

    test('days become sections with readable headings', () {
      final items = [
        item(name: 'a.jpg', folder: 'DCIM/Camera', takenAt: DateTime(2026, 7, 31, 9)),
        item(name: 'b.jpg', folder: 'DCIM/Camera', takenAt: DateTime(2026, 7, 31, 8)),
        item(name: 'c.jpg', folder: 'DCIM/Camera', takenAt: DateTime(2026, 7, 30)),
        item(name: 'd.jpg', folder: 'DCIM/Camera', takenAt: DateTime(2025, 3, 2)),
      ];
      final groups = groupByDate(items, now);
      expect(groups, hasLength(3));
      expect(groups[0].label, 'Today');
      expect(groups[0].items, hasLength(2));
      expect(groups[1].label, 'Yesterday');
      expect(groups[2].label, 'March 2, 2025');
    });

    test('a date earlier this year drops the year', () {
      expect(dateGroupLabel(DateTime(2026, 1, 4), now), 'January 4');
    });
  });

  group('smart groups', () {
    test('labels map into the buckets people browse by', () {
      expect(bucketForLabel('Dog'), 'Pets');
      expect(bucketForLabel('dessert'), 'Food');
      expect(bucketForLabel('Skyscraper'), 'Architecture');
      expect(bucketForLabel('Nothing In Particular'), isNull);
    });

    test('a panorama is a shape, not a label', () {
      expect(isPanorama(item(name: 'p.jpg', folder: 'DCIM/Camera',
          width: 8000, height: 2000)), isTrue);
      expect(isPanorama(item(name: 'n.jpg', folder: 'DCIM/Camera')), isFalse);
      // Desktop scans don't know the dimensions, and must not guess.
      expect(
        isPanorama(item(
          name: 'u.jpg',
          folder: 'Pictures',
          width: 0,
          height: 0,
        )),
        isFalse,
      );
    });

    test('groups need a few members before they earn a tab', () {
      final items = [
        for (var i = 0; i < 4; i++)
          item(name: 'face$i.jpg', folder: 'DCIM/Camera'),
        item(name: 'lonely.jpg', folder: 'DCIM/Camera'),
      ];
      final cache = <String, GalleryCacheEntry>{
        for (var i = 0; i < 4; i++)
          items[i].cacheKey: const GalleryCacheEntry(
            faceCount: 1,
            analysed: true,
          ),
        items[4].cacheKey: const GalleryCacheEntry(
          labels: ['Dog'],
          analysed: true,
        ),
      };

      final groups = buildSmartGroups(items, cache);
      final labels = [for (final g in groups) g.label];
      expect(labels, contains('People'));
      // One dog is not a Pets tab.
      expect(labels, isNot(contains('Pets')));
    });

    test('photos with coordinates form the Places group', () {
      final items = [
        for (var i = 0; i < 3; i++)
          item(
            name: 'p$i.jpg',
            folder: 'DCIM/Camera',
            latitude: 52.37 + i,
            longitude: 4.89,
          ),
      ];
      final groups = buildSmartGroups(items, const {});
      expect(
        groups.singleWhere((g) => g.id == 'places').count,
        3,
      );
    });
  });

  group('map clustering', () {
    test('nearby photos share a pin, distant ones do not', () {
      final items = [
        item(name: 'a.jpg', folder: 'DCIM/Camera', latitude: 52.370, longitude: 4.890),
        item(name: 'b.jpg', folder: 'DCIM/Camera', latitude: 52.371, longitude: 4.891),
        item(name: 'c.jpg', folder: 'DCIM/Camera', latitude: -33.86, longitude: 151.20),
      ];
      final clusters = clusterItems(items, 1);
      expect(clusters, hasLength(2));
      expect(clusters.map((c) => c.count).toList()..sort(), [1, 2]);
    });

    test('zooming in splits a cluster apart', () {
      final items = [
        item(name: 'a.jpg', folder: 'DCIM/Camera', latitude: 52.30, longitude: 4.80),
        item(name: 'b.jpg', folder: 'DCIM/Camera', latitude: 52.60, longitude: 5.40),
      ];
      expect(clusterItems(items, 1), hasLength(1));
      expect(clusterItems(items, 40), hasLength(2));
    });
  });

  group('EXIF', () {
    test('reads GPS degrees, minutes and seconds with the hemisphere', () {
      final bytes = _jpegWithGps(
        latitude: [52, 22, 23],
        latitudeRef: 'N',
        longitude: [4, 53, 32],
        longitudeRef: 'E',
        taken: '2026:07:31 14:12:33',
      );
      final metadata = parseImageDetails(bytes);

      expect(metadata, isNotNull);
      expect(metadata!.latitude, closeTo(52.3730, 0.001));
      expect(metadata.longitude, closeTo(4.8922, 0.001));
      expect(metadata.takenAt, DateTime(2026, 7, 31, 14, 12, 33));
    });

    test('south and west come back negative', () {
      final bytes = _jpegWithGps(
        latitude: [33, 51, 54],
        latitudeRef: 'S',
        longitude: [151, 12, 36],
        longitudeRef: 'W',
      );
      final metadata = parseImageDetails(bytes)!;
      expect(metadata.latitude, lessThan(0));
      expect(metadata.longitude, lessThan(0));
    });

    test('a file in no known format is simply detail-free', () {
      expect(parseImageDetails(Uint8List.fromList([1, 2, 3, 4])), isNull);
      expect(parseImageDetails(Uint8List(0)), isNull);
    });

    test('a JPEG with no EXIF still gives up its size', () {
      // Frame size is what the Panoramas album is built from, and it lives in
      // the SOF header that every JPEG has — EXIF or not.
      final plain = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 1600, height: 400)),
      );
      final details = parseImageDetails(plain)!;
      expect(details.width, 1600);
      expect(details.height, 400);
      expect(details.latitude, isNull);
    });

    test('a PNG gives up its size from IHDR', () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 300, height: 120)),
      );
      final details = parseImageDetails(png)!;
      expect(details.width, 300);
      expect(details.height, 120);
    });

    test('a GIF gives up its size from the screen descriptor', () {
      final gif = Uint8List.fromList(
        img.encodeGif(img.Image(width: 48, height: 64)),
      );
      final details = parseImageDetails(gif)!;
      expect(details.width, 48);
      expect(details.height, 64);
    });

    test('a geotagged JPEG reports both its place and its shape', () {
      final bytes = _jpegWithGps(
        latitude: [52, 22, 23],
        latitudeRef: 'N',
        longitude: [4, 53, 32],
        longitudeRef: 'E',
      );
      final details = parseImageDetails(bytes)!;
      expect(details.latitude, isNotNull);
      expect(details.width, 8);
      expect(details.height, 8);
    });
  });

  group('cloud placeholders', () {
    // OneDrive's Files On-Demand leaves a file listed in the folder while its
    // contents sit online. Reading one downloads it, so the desktop source
    // must refuse — a gallery that thumbnails everything it finds would drag
    // someone's whole cloud library onto their disk. Each test here pairs the
    // guarded call with the identical unguarded one, so it fails if the guard
    // is dropped rather than passing because the file was unreadable anyway.
    late Directory temp;
    late FolderGallerySource source;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      temp = await Directory.systemTemp.createTemp('luma_gallery');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => temp.path,
      );
      source = FolderGallerySource();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      source.dispose();
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    GalleryItem onDisk(String name, {required bool cloudOnly}) => GalleryItem(
          id: '$name#${cloudOnly ? 'cloud' : 'local'}',
          name: name,
          type: GalleryMediaType.image,
          folder: 'OneDrive/Pictures',
          takenAt: DateTime(2026, 3, 3),
          path: '${temp.path}${Platform.pathSeparator}$name',
          cloudOnly: cloudOnly,
        );

    test('no thumbnail is decoded for a file that lives in the cloud',
        () async {
      final file = File('${temp.path}${Platform.pathSeparator}photo.jpg')
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 64, height: 64)));
      expect(file.existsSync(), isTrue);

      // The same readable file, twice: only the flag differs.
      expect(
        await source.thumbnail(onDisk('photo.jpg', cloudOnly: false), 64),
        isNotNull,
        reason: 'a local photo should still get a thumbnail',
      );
      expect(
        await source.thumbnail(onDisk('photo.jpg', cloudOnly: true), 64),
        isNull,
        reason: 'reading a placeholder would download it',
      );
    });

    test('a scanned photo learns its shape, so Panoramas can exist', () async {
      // The desktop walk has no media index to ask for dimensions, so
      // without this pass every desktop photo has width 0 and the Panoramas
      // album can never appear.
      final wide = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 4000, height: 1000)),
      );
      File('${temp.path}${Platform.pathSeparator}pano.jpg')
          .writeAsBytesSync(wide);

      final scanned = onDisk('pano.jpg', cloudOnly: false);
      expect(scanned.width, 0, reason: 'the walk itself knows no dimensions');

      final enriched = await source.enrich(scanned);
      expect(enriched.width, 4000);
      expect(enriched.height, 1000);
      expect(isPanorama(enriched), isTrue);
    });

    test('no EXIF is read from a file that lives in the cloud', () async {
      final bytes = _jpegWithGps(
        latitude: [52, 22, 23],
        latitudeRef: 'N',
        longitude: [4, 53, 32],
        longitudeRef: 'E',
      );
      File('${temp.path}${Platform.pathSeparator}geo.jpg')
          .writeAsBytesSync(bytes);

      final local = await source.enrich(onDisk('geo.jpg', cloudOnly: false));
      expect(local.hasLocation, isTrue,
          reason: 'a local photo should still land on the map');

      final cloud = await source.enrich(onDisk('geo.jpg', cloudOnly: true));
      expect(cloud.hasLocation, isFalse,
          reason: 'a placeholder has no pin rather than being downloaded');
    });
  });

  group('what the desktop walk refuses to pick up', () {
    test('technical folders are never descended into', () {
      for (final junk in [
        'node_modules',
        '.git',
        'AppData',
        'resourcepacks',
        'Textures',
        'build',
        'Program Files (x86)',
      ]) {
        expect(isSkippedFolder(junk), isTrue, reason: junk);
      }
      for (final real in ['Rome 2024', 'Camera', 'WhatsApp Images', 'Boat']) {
        expect(isSkippedFolder(real), isFalse, reason: real);
      }
    });

    test('tiny images are icons and sprites, not photographs', () {
      expect(isLikelyPhotoFile(GalleryMediaType.image, 400), isFalse);
      expect(
        isLikelyPhotoFile(
          GalleryMediaType.image,
          FolderGallerySource.minimumImageBytes - 1,
        ),
        isFalse,
      );
      expect(
        isLikelyPhotoFile(GalleryMediaType.image, 2 * 1024 * 1024),
        isTrue,
      );
      // A video is a video whatever it weighs.
      expect(isLikelyPhotoFile(GalleryMediaType.video, 400), isTrue);
    });
  });

  group('editing a file', () {
    const original = 'IMG_2026.jpg';
    String? check(String name) =>
        GalleryFileEditor.validateName(name, originalName: original);

    test('an ordinary rename is allowed', () {
      expect(check('Rome rooftop.jpg'), isNull);
      expect(check('holiday-01.jpg'), isNull);
    });

    test('names the filesystem would refuse are caught before writing', () {
      expect(check(''), isNotNull);
      expect(check('   '), isNotNull);
      expect(check('a/b.jpg'), isNotNull);
      expect(check(r'a\b.jpg'), isNotNull);
      expect(check('what?.jpg'), isNotNull);
      expect(check('trailing.jpg.'), isNotNull);
      expect(check('.hidden.jpg'), isNotNull);
      expect(check('CON.jpg'), isNotNull, reason: 'reserved on Windows');
    });

    test('the extension is protected', () {
      // Renaming a JPEG to .txt stops it opening; the field says so rather
      // than letting it happen.
      expect(check('IMG_2026.txt'), isNotNull);
      expect(check('IMG_2026'), isNotNull);
      expect(check('IMG_2026.JPG'), isNull, reason: 'case is not a change');
    });

    test('impossible dates are rejected', () {
      final now = DateTime(2026, 8, 10);
      expect(
        GalleryFileEditor.validateDate(DateTime(2026, 7, 1), now: now),
        isNull,
      );
      expect(
        GalleryFileEditor.validateDate(DateTime(2030), now: now),
        isNotNull,
      );
      expect(
        GalleryFileEditor.validateDate(DateTime(1500), now: now),
        isNotNull,
      );
    });

    test('renaming moves the file and keeps the rest of the item', () async {
      final temp = await Directory.systemTemp.createTemp('luma_edit');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}${Platform.pathSeparator}$original';
      File(path).writeAsBytesSync(
        img.encodeJpg(img.Image(width: 32, height: 32)),
      );

      final item = GalleryItem(
        id: path,
        name: original,
        type: GalleryMediaType.image,
        folder: 'Pictures',
        takenAt: DateTime(2026, 7, 31),
        path: path,
        latitude: 52.1,
        longitude: 4.9,
      );

      final result = await GalleryFileEditor.apply(item, newName: 'Rome.jpg');
      expect(result.ok, isTrue, reason: result.error);
      expect(result.item!.name, 'Rome.jpg');
      expect(File(result.item!.path!).existsSync(), isTrue);
      expect(File(path).existsSync(), isFalse);
      // Everything learned about the photo survives the rename.
      expect(result.item!.latitude, 52.1);
      expect(result.item!.folder, 'Pictures');
    });

    test('a rename onto an existing file is refused, not silently merged',
        () async {
      final temp = await Directory.systemTemp.createTemp('luma_edit');
      addTearDown(() => temp.delete(recursive: true));
      final separator = Platform.pathSeparator;
      final bytes = img.encodeJpg(img.Image(width: 8, height: 8));
      File('${temp.path}${separator}a.jpg').writeAsBytesSync(bytes);
      File('${temp.path}${separator}b.jpg').writeAsBytesSync(bytes);

      final item = GalleryItem(
        id: '${temp.path}${separator}a.jpg',
        name: 'a.jpg',
        type: GalleryMediaType.image,
        folder: 'Pictures',
        takenAt: DateTime(2026),
        path: '${temp.path}${separator}a.jpg',
      );

      final result = await GalleryFileEditor.apply(item, newName: 'b.jpg');
      expect(result.ok, isFalse);
      expect(result.error, contains('already'));
      expect(File('${temp.path}${separator}a.jpg').existsSync(), isTrue);
    });

    test('the date is written to the file, not re-encoded into it', () async {
      final temp = await Directory.systemTemp.createTemp('luma_edit');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}${Platform.pathSeparator}dated.jpg';
      final bytes = img.encodeJpg(img.Image(width: 16, height: 16));
      File(path).writeAsBytesSync(bytes);

      final item = GalleryItem(
        id: path,
        name: 'dated.jpg',
        type: GalleryMediaType.image,
        folder: 'Pictures',
        takenAt: DateTime(2020),
        path: path,
      );

      final when = DateTime(2024, 5, 6, 7, 8);
      final result = await GalleryFileEditor.apply(item, newTakenAt: when);
      expect(result.ok, isTrue, reason: result.error);
      expect(result.item!.takenAt, when);
      expect(File(path).lastModifiedSync(), when);
      // The pixels are untouched — nothing was re-compressed.
      expect(File(path).readAsBytesSync(), bytes);
    });
  });

  group('scanning one folder only', () {
    // Pointing the gallery at a single folder is what makes it usable on a
    // phone whose camera roll is 20 000 photos, and what makes a desktop
    // library that lives in one place cost one walk rather than a crawl of
    // Downloads. Both halves of it are here: the rule that decides what is
    // "inside" a folder, and the desktop walk that has to obey it.
    test('a folder contains itself and everything nested in it', () {
      expect(folderWithinScanRoot('DCIM/Camera', 'DCIM'), isTrue);
      expect(folderWithinScanRoot('DCIM', 'DCIM'), isTrue);
      expect(folderWithinScanRoot('DCIM/Camera/2026', 'DCIM/Camera'), isTrue);
    });

    test('a sibling with the same prefix is not inside it', () {
      // The bug a bare startsWith would have: DCIM-old is not in DCIM.
      expect(folderWithinScanRoot('DCIM-old', 'DCIM'), isFalse);
      expect(folderWithinScanRoot('Pictures', 'DCIM'), isFalse);
      expect(folderWithinScanRoot('', 'DCIM'), isFalse);
    });

    test('no confinement means everything is in scope', () {
      expect(folderWithinScanRoot('anything/at/all', null), isTrue);
      expect(folderWithinScanRoot('', null), isTrue);
    });

    group('the desktop walk', () {
      late Directory temp;
      late FolderGallerySource source;

      setUp(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        temp = await Directory.systemTemp.createTemp('luma_scan_root');
        source = FolderGallerySource();
      });

      tearDown(() async {
        source.dispose();
        if (temp.existsSync()) await temp.delete(recursive: true);
      });

      /// A JPEG big enough to clear [FolderGallerySource.minimumImageBytes],
      /// so the walk keeps it rather than writing it off as interface art.
      void photo(String relative) {
        final path = '${temp.path}${Platform.pathSeparator}'
            '${relative.replaceAll('/', Platform.pathSeparator)}';
        final file = File(path);
        file.parent.createSync(recursive: true);
        // Noise, not a blank frame: a flat image compresses to well under
        // the size floor the walk uses to tell photographs from icons.
        final image = img.Image(width: 256, height: 256);
        var seed = 1;
        for (final pixel in image) {
          seed = (seed * 1103515245 + 12345) & 0x7fffffff;
          pixel.setRgb(seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff);
        }
        file.writeAsBytesSync(img.encodeJpg(image, quality: 100));
        expect(
          file.lengthSync(),
          greaterThanOrEqualTo(FolderGallerySource.minimumImageBytes),
        );
      }

      test('only the chosen folder and its children are walked', () async {
        photo('Trips/rome.jpg');
        photo('Trips/2026/venice.jpg');
        photo('Elsewhere/stray.jpg');

        await source.setScanRoot('${temp.path}${Platform.pathSeparator}Trips');
        final names = [for (final item in await source.load()) item.name];

        expect(names, containsAll(<String>['rome.jpg', 'venice.jpg']));
        expect(
          names,
          isNot(contains('stray.jpg')),
          reason: 'a folder outside the chosen one must never be walked',
        );
      });

      test('lifting the confinement is one call, not a reinstall', () async {
        photo('Trips/rome.jpg');
        await source.setScanRoot('${temp.path}${Platform.pathSeparator}Trips');
        expect(source.scanRoot, isNotNull);

        await source.setScanRoot(null);
        expect(source.scanRoot, isNull);
        // With no confinement the walk is back to the picture folders, which
        // this temp directory is not one of — the point is only that the
        // confinement is gone.
        expect(
          [for (final item in await source.load()) item.name],
          isNot(contains('rome.jpg')),
        );
      });

      test('a confined scan reports how much it has found', () async {
        for (var i = 0; i < 3; i++) {
          photo('Trips/photo$i.jpg');
        }
        await source.setScanRoot('${temp.path}${Platform.pathSeparator}Trips');

        final reported = <int>[];
        final items = await source.load(
          onProgress: (found, total) => reported.add(found),
        );

        expect(items, hasLength(3));
        expect(reported.first, 0, reason: 'the bar starts empty');
        expect(
          reported.last,
          items.length,
          reason: 'and ends on what the scan actually found',
        );
      });
    });
  });

  group('folder normalisation', () {
    test('slashes are levelled and trimmed', () {
      expect(normaliseFolder('/DCIM/Camera/'), 'DCIM/Camera');
      expect(normaliseFolder(r'Pictures\Trips\Rome'), 'Pictures/Trips/Rome');
      expect(normaliseFolder('//'), '');
    });

    test('only image and video extensions are media', () {
      expect(mediaTypeForName('a.JPG'), GalleryMediaType.image);
      expect(mediaTypeForName('b.mp4'), GalleryMediaType.video);
      expect(mediaTypeForName('c.mp3'), isNull);
      expect(mediaTypeForName('no-extension'), isNull);
    });
  });
}

/// EXIF coordinates are whole/1 rationals. The image package's `Rational`
/// class isn't exported, so the values are handed over as the big-endian
/// numerator/denominator pairs the format actually stores.
img.IfdValue _rationals(List<int> values) {
  final bytes = Uint8List(values.length * 8);
  final view = ByteData.view(bytes.buffer);
  for (var i = 0; i < values.length; i++) {
    view.setUint32(i * 8, values[i]);
    view.setUint32(i * 8 + 4, 1);
  }
  return img.IfdValueRational.data(
    img.InputBuffer(bytes, bigEndian: true),
    values.length,
  );
}

/// Builds a real JPEG carrying the EXIF tags under test, so the parser is
/// exercised against the same byte layout a camera writes.
Uint8List _jpegWithGps({
  required List<int> latitude,
  required String latitudeRef,
  required List<int> longitude,
  required String longitudeRef,
  String? taken,
}) {
  final image = img.Image(width: 8, height: 8);
  final gps = image.exif.gpsIfd;
  gps[0x0001] = img.IfdValueAscii(latitudeRef);
  gps[0x0002] = _rationals(latitude);
  gps[0x0003] = img.IfdValueAscii(longitudeRef);
  gps[0x0004] = _rationals(longitude);
  if (taken != null) {
    image.exif.exifIfd[0x9003] = img.IfdValueAscii(taken);
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

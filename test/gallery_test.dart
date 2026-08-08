import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/gallery/gallery_cache.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_categories.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_exif.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_map_page.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_media.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_smart.dart';

GalleryItem item({
  required String name,
  required String folder,
  GalleryMediaType type = GalleryMediaType.image,
  DateTime? takenAt,
  int width = 4000,
  int height = 3000,
  double? latitude,
  double? longitude,
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
      item(name: 'meme.gif', folder: 'Download'),
      item(name: 'invoice.png', folder: 'Download'),
    ];

    test('the fixed tabs count only what belongs to them', () {
      final categories = buildCategories(library);
      final byId = {for (final c in categories) c.id: c};

      expect(byId[GalleryCategoryIds.all]!.count, 9);
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

    test('the same album in two places is one tab', () {
      final categories = buildCategories([
        item(name: 'a.jpg', folder: 'Pictures/Instagram'),
        item(name: 'b.jpg', folder: 'DCIM/Instagram'),
      ]);
      final instagram =
          categories.where((c) => c.label == 'Instagram').toList();
      expect(instagram, hasLength(1));
      expect(instagram.single.count, 2);
      expect(instagram.single.folders, hasLength(2));
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
      expect(itemsInCategory(whatsapp, library), hasLength(2));
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
      expect(bucketForLabel('Skyscraper'), 'City');
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
      final metadata = parseJpegMetadata(bytes);

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
      final metadata = parseJpegMetadata(bytes)!;
      expect(metadata.latitude, lessThan(0));
      expect(metadata.longitude, lessThan(0));
    });

    test('a file that is not a JPEG is simply metadata-free', () {
      expect(parseJpegMetadata(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
          isNull);
      expect(parseJpegMetadata(Uint8List(0)), isNull);
    });

    test('a JPEG without an EXIF block reads as null', () {
      final plain = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 4, height: 4)),
      );
      expect(parseJpegMetadata(plain), isNull);
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

import 'package:flutter/material.dart';

import 'gallery_media.dart';

/// Ids of the five categories that are always offered, in tab order. Folder
/// categories are appended after them and use `folder:<label>` ids.
class GalleryCategoryIds {
  const GalleryCategoryIds._();

  static const all = 'all';
  static const pictures = 'pictures';
  static const videos = 'videos';
  static const screenshots = 'screenshots';
  static const gifs = 'gifs';

  static const folderPrefix = 'folder:';
}

/// One album: either one of the five fixed categories or a folder the library
/// actually contains.
@immutable
class GalleryCategory {
  const GalleryCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.count,
    this.cover,
    this.folders = const {},
  });

  final String id;
  final String label;
  final IconData icon;
  final int count;

  /// The newest item in the album — what the card on the albums screen shows.
  /// Found during the same pass that counts the album, so opening the screen
  /// never has to walk the library once per album.
  final GalleryItem? cover;

  /// For folder categories, every folder path folded into this label. Two
  /// devices may keep the same album in different places (`DCIM/Screenshots`
  /// and `Pictures/Screenshots`), and one tab for both is what a person
  /// expects.
  final Set<String> folders;

  bool get isFolder => id.startsWith(GalleryCategoryIds.folderPrefix);
}

/// Whether [item] is a screen capture. Covers screen recordings too: they are
/// captures of the same screen, they land in a sibling folder, and nobody
/// looks for them among their holiday videos.
bool isScreenCapture(GalleryItem item) {
  for (final segment in item.folder.toLowerCase().split('/')) {
    if (_screenCaptureWords.any(segment.contains)) return true;
  }
  final name = item.name.toLowerCase();
  return _screenCaptureWords.any(name.startsWith);
}

const _screenCaptureWords = [
  'screenshot',
  'screen_shot',
  'screen-shot',
  'screencapture',
  'screenrecord',
  'screen_record',
  'screen record',
];

/// Whether [item] came off this device's own camera rather than an app that
/// happened to save a picture. `DCIM` is the convention every camera app
/// follows; the numbered folders are what phones fall back to when they mimic
/// a digital camera's card layout.
bool isCameraShot(GalleryItem item) {
  if (isScreenCapture(item)) return false;
  final folder = item.folder.toLowerCase();
  if (folder == 'dcim') return true;
  final last = item.folderName.toLowerCase();
  if (_cameraFolderNames.contains(last)) return true;
  // DCIM/100ANDRO, DCIM/100MEDIA, DCIM/100APPLE, …
  return folder.startsWith('dcim/') &&
      RegExp(r'^\d{3}[a-z]+$').hasMatch(last);
}

const _cameraFolderNames = {'camera', 'open camera', 'opencamera'};

/// How many pictures a folder needs before it earns a card of its own.
///
/// A real library is surrounded by folders holding one stray image — a
/// download, an extracted archive, an app's working directory. An albums
/// screen where the first screenful is single-item folders is worse than one
/// that admits fewer albums: nothing is lost, because everything is still in
/// All, and still in the folder it came from on disk.
const minimumAlbumItems = 3;

/// Whether a folder name was written by a program rather than a person:
/// a GUID, a millisecond timestamp, or a bare hash. Those never make a
/// meaningful album name, however many pictures happen to be inside.
bool looksMachineNamed(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return false;
  // `{0D75C5A9 8574 42CF 9B99 FFD0D2F44FF5}` — a GUID, with the separators
  // already tidied into spaces by folderLabel.
  if (RegExp(r'^\{[0-9A-Fa-f \-]{8,}\}$').hasMatch(trimmed)) return true;
  // `1761572236343` — epoch milliseconds.
  if (RegExp(r'^\d{8,}$').hasMatch(trimmed)) return true;
  // A long run of hex with no vowels to break it up: a checksum or an id.
  if (RegExp(r'^[0-9A-Fa-f]{16,}$').hasMatch(trimmed)) return true;
  return false;
}

/// Builds the album list for [items]: the fixed five (minus any that would be
/// empty) followed by one per folder, busiest first.
///
/// Three kinds of folder are left out. Ones whose contents are already a
/// fixed album in full — the camera roll, the screenshot folders — because a
/// "Camera" card next to "Pictures" and "Videos" showing the same files is
/// noise. Ones with fewer than [minimumAlbumItems] pictures. And ones whose
/// name no person chose (see [looksMachineNamed]).
List<GalleryCategory> buildCategories(List<GalleryItem> items) {
  final all = _Bucket();
  final pictures = _Bucket();
  final videos = _Bucket();
  final screenshots = _Bucket();
  final gifs = _Bucket();
  final byLabel = <String, _FolderBucket>{};

  for (final item in items) {
    final capture = isScreenCapture(item);
    final camera = !capture && isCameraShot(item);
    all.add(item);
    if (capture) screenshots.add(item);
    if (item.isGif) gifs.add(item);
    if (camera) {
      if (item.isVideo) {
        videos.add(item);
      } else if (!item.isGif) {
        pictures.add(item);
      }
    }

    if (item.folder.isEmpty) continue;
    final label = folderLabel(item.folderName);
    final bucket = byLabel.putIfAbsent(label, _FolderBucket.new);
    bucket.add(item);
    bucket.folders.add(item.folder);
    if (!capture) bucket.allCaptures = false;
    if (!camera) bucket.allCamera = false;
  }

  final categories = <GalleryCategory>[
    GalleryCategory(
      id: GalleryCategoryIds.all,
      label: 'All',
      icon: Icons.photo_library_rounded,
      count: all.count,
      cover: all.cover,
    ),
    if (pictures.count > 0)
      GalleryCategory(
        id: GalleryCategoryIds.pictures,
        label: 'Pictures',
        icon: Icons.photo_camera_rounded,
        count: pictures.count,
        cover: pictures.cover,
      ),
    if (videos.count > 0)
      GalleryCategory(
        id: GalleryCategoryIds.videos,
        label: 'Videos',
        icon: Icons.videocam_rounded,
        count: videos.count,
        cover: videos.cover,
      ),
    if (screenshots.count > 0)
      GalleryCategory(
        id: GalleryCategoryIds.screenshots,
        label: 'Screenshots',
        icon: Icons.crop_rounded,
        count: screenshots.count,
        cover: screenshots.cover,
      ),
    if (gifs.count > 0)
      GalleryCategory(
        id: GalleryCategoryIds.gifs,
        label: 'GIFs',
        icon: Icons.gif_box_rounded,
        count: gifs.count,
        cover: gifs.cover,
      ),
  ];

  final folders = byLabel.entries
      .where((e) =>
          !e.value.allCaptures &&
          !e.value.allCamera &&
          e.value.count >= minimumAlbumItems &&
          !looksMachineNamed(e.key))
      .map(
        (e) => GalleryCategory(
          id: '${GalleryCategoryIds.folderPrefix}${e.key}',
          label: e.key,
          icon: folderIcon(e.key),
          count: e.value.count,
          cover: e.value.cover,
          folders: e.value.folders,
        ),
      )
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });

  return [...categories, ...folders];
}

/// Counts an album and remembers its newest member, so both come out of the
/// one pass over the library.
class _Bucket {
  int count = 0;
  GalleryItem? cover;

  void add(GalleryItem item) {
    count++;
    final current = cover;
    if (current == null) {
      cover = item;
      return;
    }
    // Newest wins, except that a picture we can actually show beats one we
    // can't: a cloud placeholder has no thumbnail (fetching it would download
    // the file), so an album full of OneDrive photos would otherwise show a
    // blank card whenever its newest item happened to be online-only.
    if (current.cloudOnly && !item.cloudOnly) {
      cover = item;
      return;
    }
    if (!current.cloudOnly && item.cloudOnly) return;
    if (item.takenAt.isAfter(current.takenAt)) cover = item;
  }
}

class _FolderBucket extends _Bucket {
  final Set<String> folders = {};
  bool allCaptures = true;
  bool allCamera = true;
}

/// The items belonging to [category], newest first.
List<GalleryItem> itemsInCategory(
  GalleryCategory category,
  List<GalleryItem> items,
) {
  final matches = switch (category.id) {
    GalleryCategoryIds.all => items,
    GalleryCategoryIds.pictures => items.where(
        (i) => !i.isVideo && !i.isGif && isCameraShot(i),
      ),
    GalleryCategoryIds.videos => items.where(
        (i) => i.isVideo && isCameraShot(i),
      ),
    GalleryCategoryIds.screenshots => items.where(isScreenCapture),
    GalleryCategoryIds.gifs => items.where((i) => i.isGif),
    _ => items.where((i) => category.folders.contains(i.folder)),
  };
  return matches.toList()..sort((a, b) => b.takenAt.compareTo(a.takenAt));
}

/// The name to show for a folder. Android's download directory is singular on
/// disk and plural everywhere a person reads it, and folders written by
/// scripts tend to be `snake_case`.
String folderLabel(String folderName) {
  final trimmed = folderName.trim();
  if (trimmed.isEmpty) return 'Other';
  final lower = trimmed.toLowerCase();
  if (lower == 'download' || lower == 'downloads') return 'Downloads';
  if (lower == 'dcim') return 'Camera';

  final words = trimmed.replaceAll(RegExp(r'[_\-]+'), ' ').split(RegExp(r'\s+'));
  return words
      .where((w) => w.isNotEmpty)
      .map((w) => w == w.toLowerCase()
          ? '${w[0].toUpperCase()}${w.substring(1)}'
          : w)
      .join(' ');
}

/// A glyph for a folder tab, recognising the apps that fill most people's
/// libraries and falling back to a plain folder.
IconData folderIcon(String label) {
  final lower = label.toLowerCase();
  if (lower == 'downloads') return Icons.download_rounded;
  if (lower.contains('whatsapp') ||
      lower.contains('messenger') ||
      lower.contains('signal') ||
      lower.contains('viber')) {
    return Icons.chat_rounded;
  }
  if (lower.contains('telegram')) return Icons.send_rounded;
  if (lower.contains('instagram') ||
      lower.contains('snapchat') ||
      lower.contains('tiktok') ||
      lower.contains('facebook')) {
    return Icons.tag_faces_rounded;
  }
  if (lower.contains('camera')) return Icons.photo_camera_rounded;
  if (lower.contains('screenshot') || lower.contains('screen')) {
    return Icons.crop_rounded;
  }
  if (lower.contains('video') || lower.contains('movie')) {
    return Icons.movie_rounded;
  }
  if (lower.contains('gif')) return Icons.gif_box_rounded;
  if (lower.contains('picture') || lower.contains('photo')) {
    return Icons.image_rounded;
  }
  return Icons.folder_rounded;
}

/// Groups [items] (already newest-first) into the day-by-day sections the
/// grid shows, each with a heading a person would recognise.
List<GalleryDateGroup> groupByDate(List<GalleryItem> items, DateTime now) {
  final groups = <GalleryDateGroup>[];
  DateTime? currentDay;
  var bucket = <GalleryItem>[];

  void flush() {
    if (bucket.isEmpty) return;
    groups.add(GalleryDateGroup(
      day: currentDay!,
      label: dateGroupLabel(currentDay, now),
      items: bucket,
    ));
    bucket = <GalleryItem>[];
  }

  for (final item in items) {
    final day = DateTime(item.takenAt.year, item.takenAt.month, item.takenAt.day);
    if (currentDay == null || day != currentDay) {
      flush();
      currentDay = day;
    }
    bucket.add(item);
  }
  flush();
  return groups;
}

@immutable
class GalleryDateGroup {
  const GalleryDateGroup({
    required this.day,
    required this.label,
    required this.items,
  });

  final DateTime day;
  final String label;
  final List<GalleryItem> items;
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String dateGroupLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final month = _months[day.month - 1];
  if (day.year == now.year) return '$month ${day.day}';
  return '$month ${day.day}, ${day.year}';
}

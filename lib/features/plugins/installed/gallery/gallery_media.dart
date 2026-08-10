import 'package:flutter/foundation.dart';

/// The two kinds of media the gallery shows. Anything else on disk — audio,
/// documents — never makes it into a [GalleryItem].
enum GalleryMediaType { image, video }

/// One photo or video, described well enough to sort, group and categorise it
/// without touching the file again. Everything here comes out of the media
/// index (MediaStore on Android, a directory walk on desktop); the expensive
/// bits — pixels, byte size, GPS — are filled in later and folded back with
/// [copyWith].
@immutable
class GalleryItem {
  const GalleryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.folder,
    required this.takenAt,
    this.path,
    this.mimeType,
    this.width = 0,
    this.height = 0,
    this.duration = Duration.zero,
    this.sizeBytes,
    this.latitude,
    this.longitude,
    this.cloudOnly = false,
  });

  /// Stable per-device identity: the MediaStore id on Android, the absolute
  /// file path on desktop.
  final String id;

  /// File name including its extension, e.g. `IMG_20260731_141233.jpg`.
  final String name;

  final GalleryMediaType type;

  /// Where the file lives, as a `/`-separated path relative to the media
  /// root — `DCIM/Camera`, `Pictures/Screenshots`,
  /// `Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images`. This is the
  /// only thing the categories are built from, so it is normalised on the way
  /// in: no leading or trailing slash, no backslashes.
  final String folder;

  /// When the shot was taken where that is known, otherwise when the file was
  /// last written. Drives every sort and the date grouping in the grid.
  final DateTime takenAt;

  /// Absolute path on disk. Null on Android until the asset is materialised —
  /// MediaStore hands out ids, and resolving each one to a file is slow
  /// enough that the grid must not do it.
  final String? path;

  final String? mimeType;
  final int width;
  final int height;

  /// Zero for images.
  final Duration duration;

  /// Null until something has had a reason to stat the file.
  final int? sizeBytes;

  /// Null when the file carries no GPS tag, or when it hasn't been read yet.
  final double? latitude;
  final double? longitude;

  /// The file is a cloud placeholder — it appears in the folder, but its
  /// contents are not on this disk and reading them would download it. The
  /// gallery lists these and refuses to open them on its own; see
  /// [CloudFiles].
  final bool cloudOnly;

  bool get isVideo => type == GalleryMediaType.video;

  bool get hasLocation => latitude != null && longitude != null;

  /// Lowercase extension without the dot, or an empty string.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  bool get isGif => extension == 'gif' || mimeType == 'image/gif';

  /// Last segment of [folder] — the name a person would call the album.
  String get folderName {
    if (folder.isEmpty) return '';
    final slash = folder.lastIndexOf('/');
    return slash < 0 ? folder : folder.substring(slash + 1);
  }

  /// Key for anything cached about this file. [takenAt] is folded in so that
  /// an id reused for different content — which MediaStore does after a
  /// delete — can't inherit the old file's coordinates and labels.
  String get cacheKey => '$id@${takenAt.millisecondsSinceEpoch}';

  GalleryItem copyWith({
    String? path,
    int? sizeBytes,
    double? latitude,
    double? longitude,
    int? width,
    int? height,
    bool? cloudOnly,
  }) =>
      GalleryItem(
        id: id,
        name: name,
        type: type,
        folder: folder,
        takenAt: takenAt,
        path: path ?? this.path,
        mimeType: mimeType,
        width: width ?? this.width,
        height: height ?? this.height,
        duration: duration,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        cloudOnly: cloudOnly ?? this.cloudOnly,
      );

  @override
  bool operator ==(Object other) => other is GalleryItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Turns a raw directory path from either platform into the form
/// [GalleryItem.folder] expects.
String normaliseFolder(String raw) {
  var folder = raw.replaceAll('\\', '/');
  while (folder.startsWith('/')) {
    folder = folder.substring(1);
  }
  while (folder.endsWith('/')) {
    folder = folder.substring(0, folder.length - 1);
  }
  return folder;
}

/// Whether a file name is media this plugin shows, judged by extension. Used
/// by the desktop walker, where there is no MediaStore to ask.
GalleryMediaType? mediaTypeForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_imageExtensions.contains(ext)) return GalleryMediaType.image;
  if (_videoExtensions.contains(ext)) return GalleryMediaType.video;
  return null;
}

const _imageExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tif', 'tiff',
  'dng', 'avif',
};

const _videoExtensions = {
  'mp4', 'mov', 'mkv', 'avi', 'webm', '3gp', 'm4v', 'wmv', 'mpg', 'mpeg',
};

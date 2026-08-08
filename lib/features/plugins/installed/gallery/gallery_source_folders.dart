import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'gallery_exif.dart';
import 'gallery_media.dart';
import 'gallery_source.dart';

/// The desktop half of the gallery. Windows and Linux have no media index to
/// query, so the plugin walks the folders where pictures normally live —
/// Pictures, Videos, Downloads — plus anything the user points it at.
class FolderGallerySource extends GallerySource {
  final List<String> _customRoots = [];

  /// Thumbnails already made this session, keyed by cache key. Bounded so a
  /// long scroll through a large library can't grow without limit.
  final Map<String, Uint8List> _memoryThumbs = {};
  static const _memoryThumbLimit = 400;

  /// At most this many files, so a folder pointed at a whole drive doesn't
  /// scan forever.
  static const _fileLimit = 50000;

  /// Directory nesting to follow below a root.
  static const _maxDepth = 8;

  Directory? _thumbDirectory;

  @override
  Future<GalleryAccess> requestAccess() async =>
      _defaultRoots().isEmpty && _customRoots.isEmpty
          ? GalleryAccess.unsupported
          : GalleryAccess.granted;

  @override
  bool get supportsCustomFolders => true;

  @override
  List<String> get roots => List.unmodifiable(_customRoots);

  @override
  void restoreRoots(List<String> paths) {
    _customRoots
      ..clear()
      ..addAll(paths.where((p) => p.trim().isNotEmpty));
  }

  @override
  Future<void> addRoot(String path) async {
    final normalised = _trimTrailingSeparator(path);
    if (normalised.isEmpty || _customRoots.contains(normalised)) return;
    _customRoots.add(normalised);
  }

  @override
  Future<void> removeRoot(String path) async {
    _customRoots.remove(_trimTrailingSeparator(path));
  }

  /// The folders scanned without the user asking for anything.
  List<Directory> _defaultRoots() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return const [];
    final separator = Platform.pathSeparator;
    final candidates = [
      '$home${separator}Pictures',
      '$home${separator}Videos',
      '$home${separator}Downloads',
      // Windows quietly redirects Pictures into OneDrive on a lot of
      // machines, leaving the real folder empty.
      '$home${separator}OneDrive${separator}Pictures',
    ];
    return [
      for (final path in candidates)
        if (Directory(path).existsSync()) Directory(path),
    ];
  }

  @override
  Future<List<GalleryItem>> load() async {
    final seen = <String>{};
    final items = <GalleryItem>[];
    final roots = <Directory>[
      ..._defaultRoots(),
      for (final path in _customRoots)
        if (Directory(path).existsSync()) Directory(path),
    ];

    for (final root in roots) {
      if (items.length >= _fileLimit) break;
      await _walk(root, root, 0, seen, items);
    }
    return items;
  }

  Future<void> _walk(
    Directory root,
    Directory directory,
    int depth,
    Set<String> seen,
    List<GalleryItem> into,
  ) async {
    if (depth > _maxDepth || into.length >= _fileLimit) return;

    final List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      // A folder we aren't allowed into is not an error worth surfacing —
      // every Windows profile has a few.
      return;
    }

    for (final entry in entries) {
      if (into.length >= _fileLimit) return;
      final name = _basename(entry.path);
      if (name.startsWith('.')) continue;

      if (entry is Directory) {
        if (_skippedFolders.contains(name.toLowerCase())) continue;
        await _walk(root, entry, depth + 1, seen, into);
        continue;
      }
      if (entry is! File) continue;

      final type = mediaTypeForName(name);
      if (type == null) continue;
      if (!seen.add(entry.path)) continue;

      FileStat stat;
      try {
        stat = await entry.stat();
      } on FileSystemException {
        continue;
      }

      into.add(GalleryItem(
        id: entry.path,
        name: name,
        type: type,
        folder: _folderFor(root, entry.path),
        // The file's own timestamp. EXIF knows better for photos, but
        // reading it for every file would turn a scan into a crawl; the
        // detail view reads the real capture time when a photo is opened.
        takenAt: stat.modified,
        path: entry.path,
        sizeBytes: stat.size,
      ));
    }
  }

  /// Folders that are never worth walking: caches, package internals and the
  /// app's own thumbnail store.
  static const _skippedFolders = {
    'node_modules',
    'appdata',
    '\$recycle.bin',
    'system volume information',
    'gallery_cache',
    '.git',
    '.thumbnails',
  };

  /// A photo in `C:\Users\me\Pictures\Trips\Rome` under the `Pictures` root
  /// becomes `Pictures/Trips/Rome`, which is the same shape MediaStore
  /// reports on the phone.
  static String _folderFor(Directory root, String filePath) {
    final rootParent = root.parent.path;
    final directory = _dirname(filePath);
    if (directory.length > rootParent.length &&
        directory.startsWith(rootParent)) {
      return normaliseFolder(directory.substring(rootParent.length));
    }
    return normaliseFolder(_basename(directory));
  }

  static String _basename(String path) {
    final index = path.lastIndexOf(RegExp(r'[/\\]'));
    return index < 0 ? path : path.substring(index + 1);
  }

  static String _dirname(String path) {
    final index = path.lastIndexOf(RegExp(r'[/\\]'));
    return index < 0 ? '' : path.substring(0, index);
  }

  static String _trimTrailingSeparator(String path) {
    var out = path.trim();
    while (out.length > 3 && (out.endsWith('/') || out.endsWith('\\'))) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  @override
  Future<String?> resolvePath(GalleryItem item) async => item.path ?? item.id;

  @override
  Future<GalleryItem> enrich(GalleryItem item) async {
    if (item.isVideo || item.hasLocation) return item;
    final path = item.path ?? item.id;
    final metadata = await readJpegMetadata(File(path));
    if (metadata == null || metadata.latitude == null) return item;
    return item.copyWith(
      latitude: metadata.latitude,
      longitude: metadata.longitude,
    );
  }

  @override
  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) async {
    // Desktop has no frame grabber, so videos show an icon instead. Pulling
    // in ffmpeg for a thumbnail isn't worth it — the converter already
    // treats an ffmpeg binary as optional.
    if (item.isVideo) return null;

    final cached = _memoryThumbs[item.cacheKey];
    if (cached != null) return cached;

    final directory = await _thumbnailDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}'
        '${_thumbName(item, pixels)}');
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      _remember(item.cacheKey, bytes);
      return bytes;
    }

    final bytes = await compute(
      _renderThumbnail,
      _ThumbnailRequest(item.path ?? item.id, pixels),
    );
    if (bytes == null) return null;
    try {
      await file.writeAsBytes(bytes, flush: false);
    } on FileSystemException {
      // A thumbnail we can't cache is still a thumbnail we can show.
    }
    _remember(item.cacheKey, bytes);
    return bytes;
  }

  void _remember(String key, Uint8List bytes) {
    if (_memoryThumbs.length >= _memoryThumbLimit) {
      _memoryThumbs.remove(_memoryThumbs.keys.first);
    }
    _memoryThumbs[key] = bytes;
  }

  static String _thumbName(GalleryItem item, int pixels) {
    final digest = sha1.convert(utf8.encode('${item.cacheKey}|$pixels'));
    return '$digest.jpg';
  }

  Future<Directory> _thumbnailDirectory() async {
    final existing = _thumbDirectory;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}gallery_cache'
      '${Platform.pathSeparator}thumbs',
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return _thumbDirectory = directory;
  }

  @override
  void dispose() {
    _memoryThumbs.clear();
  }
}

class _ThumbnailRequest {
  const _ThumbnailRequest(this.path, this.pixels);
  final String path;
  final int pixels;
}

/// Runs on a worker isolate: decoding a 12 MP JPEG takes long enough to drop
/// frames if it happens on the UI thread.
Uint8List? _renderThumbnail(_ThumbnailRequest request) {
  try {
    final bytes = File(request.path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final square = decoded.width >= decoded.height
        ? img.copyResize(decoded, height: request.pixels)
        : img.copyResize(decoded, width: request.pixels);
    return Uint8List.fromList(img.encodeJpg(square, quality: 78));
  } catch (_) {
    return null;
  }
}

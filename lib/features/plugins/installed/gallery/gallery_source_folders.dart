import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'gallery_cloud_files.dart';
import 'gallery_exif.dart';
import 'gallery_media.dart';
import 'gallery_source.dart';

/// The desktop half of the gallery. Windows and Linux have no media index to
/// query, so the plugin walks the folders where pictures normally live —
/// Pictures, Videos, Downloads — plus anything the user points it at.
///
/// The walk takes in however many pictures it finds. There used to be a
/// 50 000-file ceiling on it, which is a number a real photo library reaches
/// and then silently stops at — a gallery that quietly hides the second half
/// of someone's photos is worse than a slow one. What keeps a scan sane is
/// what it refuses to look at rather than what it counts: [skippedFolders],
/// [_maxDepth], [minimumImageBytes], and [scanRoot] when the user points it
/// at one folder.
class FolderGallerySource extends GallerySource {
  final List<String> _customRoots = [];

  /// The one directory the scan is confined to, or null for the usual set of
  /// picture folders plus whatever the user added. When it is set nothing
  /// else is walked at all — that is the point: a library kept in one place
  /// shouldn't cost a crawl of Downloads to find.
  String? _scanRoot;

  /// Thumbnails already made this session, keyed by cache key. Bounded so a
  /// long scroll through a large library can't grow without limit.
  final Map<String, Uint8List> _memoryThumbs = {};
  static const _memoryThumbLimit = 400;

  /// Set by [dispose]; the walk checks it between folders so closing the
  /// plugin mid-scan doesn't leave a crawl running in the background.
  bool _disposed = false;

  /// Directory nesting to follow below a root.
  static const _maxDepth = 8;

  Directory? _thumbDirectory;

  @override
  Future<GalleryAccess> requestAccess() async => _scanRoots().isEmpty
      ? GalleryAccess.unsupported
      : GalleryAccess.granted;

  @override
  bool get supportsCustomFolders => true;

  @override
  List<String> get roots => List.unmodifiable(_customRoots);

  @override
  bool get supportsScanRoot => true;

  @override
  String? get scanRoot => _scanRoot;

  @override
  Future<void> setScanRoot(String? path) async {
    final normalised = _trimTrailingSeparator(path ?? '');
    _scanRoot = normalised.isEmpty ? null : normalised;
  }

  @override
  void restoreScanRoot(String? path) {
    final normalised = _trimTrailingSeparator(path ?? '');
    _scanRoot = normalised.isEmpty ? null : normalised;
  }

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

  /// The directories this scan will walk: the one it is confined to, or the
  /// usual picture folders plus everything the user added.
  List<Directory> _scanRoots() {
    final confined = _scanRoot;
    if (confined != null) {
      final directory = Directory(confined);
      return directory.existsSync() ? [directory] : const [];
    }
    return [
      ..._defaultRoots(),
      for (final path in _customRoots)
        if (Directory(path).existsSync()) Directory(path),
    ];
  }

  @override
  Future<List<GalleryItem>> load({GalleryScanProgress? onProgress}) async {
    final seen = <String>{};
    final items = <GalleryItem>[];

    // A walk cannot know how much there is until it is done, so progress is
    // reported as a count with no total — the bar spins, the number climbs.
    onProgress?.call(0, null);
    for (final root in _scanRoots()) {
      await _walk(root, root, 0, seen, items, onProgress);
    }
    onProgress?.call(items.length, items.length);
    return items;
  }

  /// How many files to take in before pausing to report progress and let the
  /// framework draw. Small enough that the count visibly moves, large enough
  /// that the yield isn't what makes the scan slow.
  static const _progressStride = 64;

  /// How many files are `stat()`ed at once. One awaited call per file was the
  /// shape of the old walk, and on Windows each of those round-trips costs
  /// about a millisecond of pure latency — thirty thousand photos spent half
  /// a minute waiting on the filesystem between doing any work. A batch pays
  /// the latency once and lets the runtime interleave the rest; past a few
  /// dozen the returns vanish, because the disk becomes the bottleneck
  /// instead of the message loop.
  static const _statBatch = 24;

  Future<void> _walk(
    Directory root,
    Directory directory,
    int depth,
    Set<String> seen,
    List<GalleryItem> into,
    GalleryScanProgress? onProgress,
  ) async {
    if (depth > _maxDepth) return;

    final List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      // A folder we aren't allowed into is not an error worth surfacing —
      // every Windows profile has a few.
      return;
    }

    var sinceYield = 0;
    Future<void> breathe() async {
      onProgress?.call(into.length, null);
      await Future<void>.delayed(Duration.zero);
    }

    final subDirectories = <Directory>[];
    final candidates = <File, GalleryMediaType>{};

    for (final entry in entries) {
      final name = _basename(entry.path);
      if (name.startsWith('.')) continue;

      if (entry is Directory) {
        if (!isSkippedFolder(name)) subDirectories.add(entry);
        continue;
      }
      if (entry is! File) continue;

      final type = mediaTypeForName(name);
      if (type == null) continue;
      if (!seen.add(entry.path)) continue;
      candidates[entry] = type;
    }

    final files = candidates.keys.toList(growable: false);
    for (var start = 0; start < files.length; start += _statBatch) {
      final end = math.min(start + _statBatch, files.length);
      final batch = files.sublist(start, end);
      final stats = await Future.wait(
        [for (final file in batch) _quietStat(file)],
      );

      for (var i = 0; i < batch.length; i++) {
        final stat = stats[i];
        if (stat == null) continue;
        final type = candidates[batch[i]]!;
        if (!isLikelyPhotoFile(type, stat.size)) continue;

        into.add(GalleryItem(
          id: batch[i].path,
          name: _basename(batch[i].path),
          type: type,
          folder: _folderFor(root, batch[i].path),
          // The file's own timestamp. EXIF knows better for photos, but
          // reading it for every file would turn a scan into a crawl; the
          // detail view reads the real capture time when a photo is opened.
          takenAt: stat.modified,
          path: batch[i].path,
          // stat() is safe on a placeholder — it reports the real size
          // without fetching anything.
          sizeBytes: stat.size,
          cloudOnly: CloudFiles.isCloudOnly(batch[i].path),
        ));

        if (into.length % _progressStride == 0) {
          await breathe();
          sinceYield = 0;
        }
      }
      sinceYield += batch.length;
    }

    for (final subDirectory in subDirectories) {
      if (_disposed) return;
      await _walk(root, subDirectory, depth + 1, seen, into, onProgress);
      // Deep, media-free trees used to go silent for whole seconds at a
      // stretch, which reads as a hung scan.
      if (++sinceYield >= _progressStride) {
        await breathe();
        sinceYield = 0;
      }
    }
  }

  /// A file that vanishes or refuses access mid-scan is skipped, not fatal.
  static Future<FileStat?> _quietStat(File file) async {
    try {
      return await file.stat();
    } on FileSystemException {
      return null;
    }
  }

  /// Folders that are never worth walking. A Downloads folder is where
  /// extracted archives, game installs and checked-out repositories end up,
  /// and every one of those is thousands of PNGs that are not photographs —
  /// a Minecraft resource pack alone contributes a few hundred.
  static const skippedFolders = {
    // The app's own store, and Windows' own.
    'gallery_cache',
    'appdata',
    'programdata',
    'program files',
    'program files (x86)',
    'windows',
    '\$recycle.bin',
    'system volume information',
    // Caches and temporaries.
    'cache',
    'caches',
    '.cache',
    'temp',
    'tmp',
    'logs',
    '.thumbnails',
    'thumbnails',
    // Games: textures, skins and resource packs, by the thousand.
    '.minecraft',
    'resourcepacks',
    'texturepacks',
    'shaderpacks',
    'mods',
    'saves',
    'steamapps',
    'crash-reports',
    // Development trees.
    'node_modules',
    '.git',
    '.gradle',
    '.m2',
    '.idea',
    '.vscode',
    'venv',
    '.venv',
    'site-packages',
    'build',
    'obj',
    'bin',
    'target',
    'vendor',
    'assets',
    // Interface art rather than pictures.
    'icons',
    'emoji',
    'sprites',
    'textures',
  };

  /// Images smaller than this aren't photographs. Icons, sprites, emoji,
  /// avatars and UI art are all a few kilobytes; the smallest thing a camera
  /// or a screenshot produces is far bigger. This is what keeps a stray
  /// asset folder from adding thousands of 16×16 PNGs to the library — and
  /// it is checked against the size on disk, so it costs no extra I/O.
  ///
  /// Videos have no floor: a video file is a video whatever its size.
  static const minimumImageBytes = 12 * 1024;

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
    for (var i = path.length - 1; i >= 0; i--) {
      final unit = path.codeUnitAt(i);
      if (unit == 0x2F || unit == 0x5C) return path.substring(i + 1);
    }
    return path;
  }

  static String _dirname(String path) {
    for (var i = path.length - 1; i >= 0; i--) {
      final unit = path.codeUnitAt(i);
      if (unit == 0x2F || unit == 0x5C) return path.substring(0, i);
    }
    return '';
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
    if (item.isVideo) return item;
    // Reading the header means opening the file, which for a cloud
    // placeholder means downloading it. A photo that isn't on this disk
    // simply doesn't get a pin on the map or a shape the gallery knows.
    if (item.cloudOnly) return item;
    final path = item.path ?? item.id;
    final details = await readImageDetails(File(path));
    if (details == null || details.isEmpty) return item;
    return item.copyWith(
      latitude: details.latitude,
      longitude: details.longitude,
      width: details.width,
      height: details.height,
    );
  }

  @override
  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) async {
    // Desktop has no frame grabber, so videos show an icon instead. Pulling
    // in ffmpeg for a thumbnail isn't worth it — the converter already
    // treats an ffmpeg binary as optional.
    if (item.isVideo) return null;

    // The whole point of the placeholder check: decoding a thumbnail reads
    // the file, and reading a cloud placeholder downloads it. Scrolling past
    // a OneDrive folder must not move someone's library onto their disk, so
    // these get the cloud badge rather than a picture.
    if (item.cloudOnly) return null;

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

    Uint8List? bytes = await _renderThumbnailNative(
      item.path ?? item.id,
      pixels,
    );
    bytes ??= await compute(
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
    _disposed = true;
    _memoryThumbs.clear();
  }
}

/// Whether the walk should descend into a directory called [name]. Public so
/// the rules can be tested without a filesystem to walk.
bool isSkippedFolder(String name) =>
    FolderGallerySource.skippedFolders.contains(name.trim().toLowerCase());

/// Whether a file of this [type] and [sizeBytes] is worth showing in a
/// gallery. See [FolderGallerySource.minimumImageBytes].
bool isLikelyPhotoFile(GalleryMediaType type, int sizeBytes) =>
    type == GalleryMediaType.video ||
    sizeBytes >= FolderGallerySource.minimumImageBytes;

class _ThumbnailRequest {
  const _ThumbnailRequest(this.path, this.pixels);
  final String path;
  final int pixels;
}

/// Tries the engine's own codecs first — JPEG, PNG, WebP, BMP, GIF, HEIF on
/// a platform that supports it. libjpeg-turbo and friends decode with
/// subsampling (`targetWidth`), so a 12 MP picture is read as a 384 px strip
/// rather than fully in Dart. Anything the engine cannot read falls back to
/// the old `package:image` path.
Future<Uint8List?> _renderThumbnailNative(String path, int pixels) async {
  Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } catch (_) {
    return null;
  }

  ui.Codec? codec;
  ui.Image? image;
  try {
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: pixels,
        allowUpscaling: false,
      );
    } catch (_) {
      return null;
    }
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
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

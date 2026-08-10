import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gallery_cache.dart';
import 'gallery_categories.dart';
import 'gallery_media.dart';
import 'gallery_smart.dart';
import 'gallery_source.dart';
import 'onnx/gallery_model_store.dart';

/// Where the library scan has got to.
enum GalleryStatus { idle, askingAccess, scanning, ready, noAccess, empty }

/// Owns the device's media index for the Gallery plugin: the scan, the
/// categories built from it, the slow background passes that fill in
/// locations and smart labels, and the cache that means none of it has to
/// happen twice.
class GalleryRepository extends ChangeNotifier {
  GalleryRepository({GallerySource? source, GalleryCache? cache})
      : _source = source ?? GallerySource.forPlatform(),
        _cache = cache ?? GalleryCache();

  final GallerySource _source;
  final GalleryCache _cache;
  final GalleryAnalyser _analyser = GalleryAnalyser();

  GalleryStatus _status = GalleryStatus.idle;
  GalleryAccess _access = GalleryAccess.denied;
  List<GalleryItem> _items = const [];
  List<GalleryCategory> _categories = const [];
  bool _disposed = false;

  /// True while the background pass that reads GPS tags is running, with how
  /// far it has got — the map shows both.
  bool _locating = false;
  int _locatedCount = 0;

  bool _analysing = false;
  int _analysedCount = 0;

  GalleryStatus get status => _status;
  GalleryAccess get access => _access;
  List<GalleryItem> get items => _items;
  List<GalleryCategory> get categories => _categories;
  Map<String, GalleryCacheEntry> get cacheEntries => _cache.entries;

  bool get isLocating => _locating;
  int get locatedCount => _locatedCount;
  bool get isAnalysing => _analysing;
  int get analysedCount => _analysedCount;

  bool get canPresentPicker => _source.canPresentPicker;
  bool get supportsCustomFolders => _source.supportsCustomFolders;
  List<String> get customRoots => _source.roots;
  bool get smartModelsAvailable => GalleryAnalyser.isSupported;

  /// Photos with a known position, newest first — the pins on the map. Walks
  /// the whole library, so the header asks [hasLocatedItems] instead.
  List<GalleryItem> get locatedItems =>
      _items.where((i) => i.hasLocation).toList()
        ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

  /// Whether anything has a position yet. Kept as a counter rather than a
  /// scan: it is read every time the page rebuilds, which during the location
  /// pass is often.
  bool get hasLocatedItems => _withLocation > 0;
  int _withLocation = 0;

  /// How many photos the smart pass still hasn't looked at.
  int get pendingAnalysis => _items
      .where((i) => !i.isVideo && !(_cache[i.cacheKey]?.analysed ?? false))
      .length;

  /// How many the pass reached but couldn't read — cloud placeholders, and
  /// formats the decoder doesn't handle. Reported rather than hidden: on a
  /// library that lives mostly in OneDrive this is the difference between
  /// "the models found nothing" and "the models never saw your photos".
  int get skippedAnalysis => _items
      .where((i) => !i.isVideo && (_cache[i.cacheKey]?.skipped ?? false))
      .length;

  /// How many were actually looked at.
  int get examinedAnalysis => _items.where((i) {
        final entry = _cache[i.cacheKey];
        if (entry == null || i.isVideo) return false;
        return entry.analysed && !entry.skipped;
      }).length;

  /// Forgets every verdict and runs the pass again — after the models have
  /// been improved, or after cloud photos have been made available offline.
  Future<void> reanalyseAll() async {
    if (_analysing) return;
    for (final item in _items) {
      final entry = _cache[item.cacheKey];
      if (entry == null || !entry.analysed) continue;
      _cache.put(
        item.cacheKey,
        entry.copyWith(
          analysed: false,
          skipped: false,
          labels: const [],
          faceCount: 0,
        ),
      );
    }
    _smartVersion++;
    notifyListeners();
    await analyseSmart();
  }

  /// First call does everything: reads the cache, asks for access, scans, and
  /// kicks off the location pass. Later calls are a no-op unless [force].
  Future<void> initialise({bool force = false}) async {
    if (!force &&
        _status != GalleryStatus.idle &&
        _status != GalleryStatus.noAccess) {
      return;
    }

    await _cache.load();
    _source.restoreRoots(_cache.roots);
    unawaited(refreshModelState());

    _set(() => _status = GalleryStatus.askingAccess);
    _access = await _source.requestAccess();
    if (_access == GalleryAccess.denied ||
        _access == GalleryAccess.unsupported) {
      _set(() => _status = GalleryStatus.noAccess);
      return;
    }

    await _scan();
  }

  /// Re-reads the library from scratch, keeping everything already cached.
  Future<void> refresh() async {
    if (_status == GalleryStatus.scanning) return;
    if (_access == GalleryAccess.denied ||
        _access == GalleryAccess.unsupported) {
      await initialise(force: true);
      return;
    }
    await _scan();
  }

  Future<void> _scan() async {
    _set(() => _status = GalleryStatus.scanning);
    final scanned = await _source.load();
    if (_disposed) return;

    // Fold in what earlier runs learned — coordinates and frame sizes — so
    // the map and the shape-based albums are populated before the background
    // pass has reopened a single file.
    _items = [
      for (final item in scanned) _withCached(item),
    ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));

    _withLocation = _items.where((i) => i.hasLocation).length;
    _cache.retainKeys({for (final item in _items) item.cacheKey});
    _categories = buildCategories(_items);
    _smartVersion++;
    _libraryVersion++;
    _set(() => _status =
        _items.isEmpty ? GalleryStatus.empty : GalleryStatus.ready);
    unawaited(_cache.flush());
  }

  /// Puts back whatever the cache already knows about [item].
  GalleryItem _withCached(GalleryItem item) {
    final entry = _cache[item.cacheKey];
    if (entry == null) return item;
    return item.copyWith(
      latitude: entry.latitude,
      longitude: entry.longitude,
      // MediaStore supplies these on the phone; only fall back to the cache
      // where the scan couldn't know them.
      width: item.width > 0 ? null : entry.width,
      height: item.height > 0 ? null : entry.height,
    );
  }

  /// Bumped whenever the set of items changes — a rescan, or the end of the
  /// location pass. The page memoises an album's sorted, date-grouped
  /// contents against it, so the background passes don't make it re-sort
  /// thousands of items on every progress notification.
  int _libraryVersion = 0;
  int get libraryVersion => _libraryVersion;

  /// How many photos the header pass hasn't read yet.
  int get pendingDetails => _pendingDetails().length;

  List<GalleryItem> _pendingDetails() => [
        for (final item in _items)
          if (!item.isVideo && !(_cache[item.cacheKey]?.detailsRead ?? false))
            item,
      ];

  /// Reads each photo's header for its GPS tag and frame size — what the map
  /// and the shape-based albums are built from.
  ///
  /// One file read each, thousands of them, so this is deliberately *not*
  /// started by [initialise]: doing it on open competes with the thumbnails
  /// and makes the whole plugin feel stuck. The map page starts it, and on
  /// desktop the smart albums section offers it.
  Future<void> locateAll() async {
    if (_locating || _status != GalleryStatus.ready) return;
    final pending = _pendingDetails();
    if (pending.isEmpty) return;

    _set(() {
      _locating = true;
      _locatedCount = 0;
    });

    const batch = 24;
    var index = 0;
    for (final item in pending) {
      if (_disposed) return;
      final enriched = await _source.enrich(item);
      final previous = _cache[item.cacheKey] ?? const GalleryCacheEntry();
      if (enriched.hasLocation && !item.hasLocation) {
        _locatedCount++;
        _withLocation++;
      }
      _replace(enriched);
      _cache.put(
        item.cacheKey,
        previous.copyWith(
          latitude: enriched.latitude,
          longitude: enriched.longitude,
          width: enriched.width > 0 ? enriched.width : null,
          height: enriched.height > 0 ? enriched.height : null,
          detailsRead: true,
        ),
      );
      _smartVersion++;
      // Let the UI breathe between batches; a tight loop over thousands of
      // files makes the grid stutter even though the work is off-thread.
      if (++index % batch == 0) {
        notifyListeners();
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _cache.flush();
    // One bump at the end rather than one per photo: the album lists only
    // change in that they now carry coordinates, and re-sorting the library
    // a thousand times over would cost more than the pass itself.
    _libraryVersion++;
    _set(() => _locating = false);
  }

  /// Runs the on-device models over photos that haven't been looked at yet,
  /// up to [budget] of them, newest first. Nova-only — the page checks the
  /// plan before calling this.
  /// Looks at every photo that hasn't been looked at yet, newest first.
  ///
  /// This used to stop after a few hundred, which for a 23 000-photo library
  /// meant clicking the same button sixty times. It now runs the lot; the
  /// results are cached per photo as it goes, so [stopAnalysing] — or closing
  /// the app — loses nothing but the photo in flight.
  Future<void> analyseSmart({int? budget}) async {
    if (_analysing || !GalleryAnalyser.isSupported) return;
    final all = [
      for (final item in _items)
        if (!item.isVideo && !(_cache[item.cacheKey]?.analysed ?? false)) item,
    ];
    final pending = budget == null ? all : all.take(budget).toList();
    if (pending.isEmpty) return;
    _analysisTotal = pending.length;
    _cancelAnalysis = false;

    _set(() {
      _analysing = true;
      _analysedCount = 0;
      _analysisStatus = null;
    });

    // On desktop this is where the models are fetched, the first time only.
    final started = await _analyser.prepare(
      onProgress: (label, progress) => _set(() {
        _analysisStatus = label;
        _analysisProgress = progress;
      }),
    );
    _analysisStatus = null;
    _analysisProgress = null;
    if (!started || _disposed) {
      _set(() {
        _analysing = false;
        _analysisError = _analyser.lastError ??
            'The smart album models could not be started.';
      });
      return;
    }
    _analysisError = null;

    _modelsPresent = true;

    for (final item in pending) {
      if (_disposed || _cancelAnalysis) break;
      final previous = _cache[item.cacheKey] ?? const GalleryCacheEntry();
      // ML Kit reads the file; the ONNX path works from the thumbnail the
      // grid already made, which also means a cloud placeholder — which has
      // no thumbnail — is skipped rather than downloaded.
      final entry = await _analyser.analyse(
        previous: previous,
        path: _analyser.usesOnnx ? null : await _source.resolvePath(item),
        thumbnail:
            _analyser.usesOnnx ? await thumbnail(item, _analysisPixels) : null,
      );
      _cache.put(item.cacheKey, entry);
      _analysedCount++;
      _smartVersion++;
      if (_analysedCount % 12 == 0) {
        notifyListeners();
        // Flushed as it goes, not only at the end: a pass over 23 000 photos
        // takes a while, and closing the app halfway should keep the half
        // that is done.
        if (_analysedCount % 240 == 0) await _cache.flush();
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _cache.flush();
    _set(() {
      _analysing = false;
      _cancelAnalysis = false;
    });
  }

  /// Asks the running pass to stop after the photo it is on.
  void stopAnalysing() {
    if (!_analysing) return;
    _set(() => _cancelAnalysis = true);
  }

  bool _cancelAnalysis = false;
  int _analysisTotal = 0;

  /// How many this pass set out to do, for the "N of M" line.
  int get analysisTotal => _analysisTotal;

  /// The thumbnail size handed to the ONNX models. Big enough for the
  /// classifier's 224² crop and for a face to survive the 320×240 squash,
  /// small enough that it costs nothing next to the full-size file.
  static const _analysisPixels = 384;

  /// What the model download is doing, while it is doing it.
  String? _analysisStatus;
  double? _analysisProgress;
  String? _analysisError;

  String? get analysisStatus => _analysisStatus;
  double? get analysisProgress => _analysisProgress;

  /// Why the last attempt to start the models failed, if it did.
  String? get analysisError => _analysisError;

  /// Whether the models still have to be fetched — the platform downloads
  /// them *and* they aren't on disk yet. Checked against the filesystem
  /// rather than the platform alone, or the card would keep offering to
  /// download models that were downloaded an hour ago.
  bool get smartModelsNeedDownload =>
      GalleryAnalyser.needsDownload && !_modelsPresent;

  bool _modelsPresent = false;

  /// Re-checks whether the models are on disk. Cheap (two `exists` calls) and
  /// only run when the answer could have changed.
  Future<void> refreshModelState() async {
    if (!GalleryAnalyser.needsDownload) return;
    final present = await GalleryModelStore.instance.ready;
    if (present == _modelsPresent) return;
    _set(() => _modelsPresent = present);
  }

  /// Roughly how much that download is.
  int get smartModelBytes => GalleryModelStore.totalBytes;

  /// Bumped whenever something a smart group is built from changes: the
  /// library itself, a new location, a freshly analysed photo.
  int _smartVersion = 0;
  int _smartGroupsVersion = -1;
  List<GallerySmartGroup> _smartGroups = const [];

  /// The smart tabs as they stand right now. Safe to call before the pass has
  /// finished — groups simply grow as photos are analysed. Memoised, because
  /// the page asks for them on every rebuild and building them walks the
  /// whole library.
  List<GallerySmartGroup> smartGroups() {
    if (_smartGroupsVersion == _smartVersion) return _smartGroups;
    _smartGroups = buildSmartGroups(_items, _cache.entries);
    _smartGroupsVersion = _smartVersion;
    return _smartGroups;
  }

  /// Thumbnails already decoded this session. Scrolling back up a long grid
  /// is the common case, and re-decoding on the way is what makes a gallery
  /// feel slow.
  final Map<String, Uint8List> _thumbnails = {};
  static const _thumbnailLimit = 300;

  /// Requests already running or queued, so two tiles asking for the same
  /// picture — a cover and its first grid tile, say — decode it once.
  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// How many thumbnails may be produced at once.
  ///
  /// Every tile asks for its picture the moment it is built, so opening an
  /// album asks for a whole screenful in the same frame. Unbounded, that was
  /// the freeze: thirty requests at once.
  ///
  /// The right number differs by platform. On the phone each request is a
  /// cheap call into MediaStore's own thumbnailer, so a few in parallel keep
  /// the grid filling quickly. On desktop each one spawns an isolate that
  /// decodes a full-size JPEG — a 12 MP photo is ~50 MB of pixels while it is
  /// being resized — so two at a time is as much as is worth risking.
  static final int _maxConcurrentThumbnails =
      defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? 4
          : 2;

  int _decoding = 0;

  /// Requests waiting for a slot. Served newest-first: after a fast scroll
  /// the tiles that are actually on screen are the ones that asked last, and
  /// a queue drained in order would spend its time decoding pictures that
  /// have already scrolled away.
  final List<Completer<void>> _thumbnailQueue = [];

  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) {
    final key = '${item.cacheKey}|$pixels';
    final cached = _thumbnails[key];
    if (cached != null) return Future.value(cached);
    final running = _inFlight[key];
    if (running != null) return running;

    final request = _decodeThumbnail(key, item, pixels);
    _inFlight[key] = request;
    return request;
  }

  Future<Uint8List?> _decodeThumbnail(
    String key,
    GalleryItem item,
    int pixels,
  ) async {
    try {
      if (_decoding >= _maxConcurrentThumbnails) {
        final slot = Completer<void>();
        _thumbnailQueue.add(slot);
        await slot.future;
      }
      if (_disposed) return null;

      _decoding++;
      try {
        final bytes = await _source.thumbnail(item, pixels);
        if (bytes == null || _disposed) return bytes;
        if (_thumbnails.length >= _thumbnailLimit) {
          _thumbnails.remove(_thumbnails.keys.first);
        }
        _thumbnails[key] = bytes;
        return bytes;
      } finally {
        _decoding--;
        if (_thumbnailQueue.isNotEmpty) {
          _thumbnailQueue.removeLast().complete();
        }
      }
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> resolvePath(GalleryItem item) => _source.resolvePath(item);

  Future<int?> fileSize(GalleryItem item) => _source.fileSize(item);

  Future<void> openSystemSettings() => _source.openSettings();

  /// Widens a "selected photos only" grant, then rescans.
  Future<void> presentPicker() async {
    if (!_source.canPresentPicker) return;
    await _source.presentPicker();
    await refresh();
  }

  Future<void> addFolder(String path) async {
    if (!_source.supportsCustomFolders) return;
    await _source.addRoot(path);
    _cache.setRoots(_source.roots);
    await _cache.flush();
    await refresh();
  }

  Future<void> removeFolder(String path) async {
    if (!_source.supportsCustomFolders) return;
    await _source.removeRoot(path);
    _cache.setRoots(_source.roots);
    await _cache.flush();
    await refresh();
  }

  void _replace(GalleryItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) _items[index] = item;
  }

  void _set(VoidCallback change) {
    change();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _thumbnails.clear();
    unawaited(_analyser.dispose());
    _source.dispose();
    unawaited(_cache.flush());
    super.dispose();
  }
}

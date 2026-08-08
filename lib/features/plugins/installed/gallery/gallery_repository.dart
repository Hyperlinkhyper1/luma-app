import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gallery_cache.dart';
import 'gallery_categories.dart';
import 'gallery_media.dart';
import 'gallery_smart.dart';
import 'gallery_source.dart';

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
  final GallerySmartAnalyser _analyser = GallerySmartAnalyser();

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
  bool get smartModelsAvailable => GallerySmartAnalyser.isSupported;

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

    _set(() => _status = GalleryStatus.askingAccess);
    _access = await _source.requestAccess();
    if (_access == GalleryAccess.denied ||
        _access == GalleryAccess.unsupported) {
      _set(() => _status = GalleryStatus.noAccess);
      return;
    }

    await _scan();
    unawaited(locateAll());
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
    unawaited(locateAll());
  }

  Future<void> _scan() async {
    _set(() => _status = GalleryStatus.scanning);
    final scanned = await _source.load();
    if (_disposed) return;

    // Fold in coordinates learned on an earlier run so the map is populated
    // before the background pass has read a single file.
    _items = [
      for (final item in scanned)
        if (_cache[item.cacheKey]?.hasLocation ?? false)
          item.copyWith(
            latitude: _cache[item.cacheKey]!.latitude,
            longitude: _cache[item.cacheKey]!.longitude,
          )
        else
          item,
    ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));

    _withLocation = _items.where((i) => i.hasLocation).length;
    _cache.retainKeys({for (final item in _items) item.cacheKey});
    _categories = buildCategories(_items);
    _smartVersion++;
    _set(() => _status =
        _items.isEmpty ? GalleryStatus.empty : GalleryStatus.ready);
    unawaited(_cache.flush());
  }

  /// Walks every photo that has no position yet and asks the platform for its
  /// GPS tag. Slow — one file read each — so it runs in the background, in
  /// batches, and reports progress as it goes.
  Future<void> locateAll() async {
    if (_locating || _status != GalleryStatus.ready) return;
    final pending = [
      for (final item in _items)
        if (!item.hasLocation && !(_cache[item.cacheKey]?.geoChecked ?? false))
          item,
    ];
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
      if (enriched.hasLocation) {
        _replace(enriched);
        _cache.put(
          item.cacheKey,
          previous.copyWith(
            latitude: enriched.latitude,
            longitude: enriched.longitude,
            geoChecked: true,
          ),
        );
        _locatedCount++;
        _withLocation++;
        _smartVersion++;
      } else {
        _cache.put(item.cacheKey, previous.copyWith(geoChecked: true));
      }
      // Let the UI breathe between batches; a tight loop over thousands of
      // files makes the grid stutter even though the work is on a platform
      // thread.
      if (++index % batch == 0) {
        notifyListeners();
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _cache.flush();
    _set(() => _locating = false);
  }

  /// Runs the on-device models over photos that haven't been looked at yet,
  /// up to [budget] of them, newest first. Nova-only — the page checks the
  /// plan before calling this.
  Future<void> analyseSmart({int budget = 400}) async {
    if (_analysing || !GallerySmartAnalyser.isSupported) return;
    final pending = [
      for (final item in _items)
        if (!item.isVideo && !(_cache[item.cacheKey]?.analysed ?? false)) item,
    ].take(budget).toList();
    if (pending.isEmpty) return;

    _set(() {
      _analysing = true;
      _analysedCount = 0;
    });

    for (final item in pending) {
      if (_disposed) break;
      final path = await _source.resolvePath(item);
      if (path == null) {
        _cache.put(
          item.cacheKey,
          (_cache[item.cacheKey] ?? const GalleryCacheEntry())
              .copyWith(analysed: true),
        );
        continue;
      }
      final entry = await _analyser.analyse(
        path,
        _cache[item.cacheKey] ?? const GalleryCacheEntry(),
      );
      _cache.put(item.cacheKey, entry);
      _analysedCount++;
      _smartVersion++;
      if (_analysedCount % 12 == 0) {
        notifyListeners();
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _cache.flush();
    _set(() => _analysing = false);
  }

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

  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) async {
    final key = '${item.cacheKey}|$pixels';
    final cached = _thumbnails[key];
    if (cached != null) return cached;
    final bytes = await _source.thumbnail(item, pixels);
    if (bytes == null || _disposed) return bytes;
    if (_thumbnails.length >= _thumbnailLimit) {
      _thumbnails.remove(_thumbnails.keys.first);
    }
    _thumbnails[key] = bytes;
    return bytes;
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
    _analyser.dispose();
    _source.dispose();
    unawaited(_cache.flush());
    super.dispose();
  }
}

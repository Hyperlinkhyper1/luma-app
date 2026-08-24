import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bumped whenever a stored verdict stops meaning what it used to.
///
/// Version 2 introduced [GalleryCacheEntry.skipped]. Before it, a photo the
/// pass couldn't read — a cloud placeholder, a HEIC — was written as
/// `analysed` with no labels, indistinguishable from one that was looked at
/// and found to contain nothing. A library whose entries all predate the
/// flag would report tens of thousands of photos examined when almost none
/// were, so those verdicts are thrown away and re-taken.
///
/// Coordinates and frame sizes survive a bump: they are facts about the file,
/// not judgements, and re-reading them costs a pass over every header.
const kGalleryAnalysisVersion = 2;

/// What has already been learned about one file, so opening the gallery a
/// second time doesn't re-read every EXIF header and re-run every model.
class GalleryCacheEntry {
  const GalleryCacheEntry({
    this.latitude,
    this.longitude,
    this.labels = const [],
    this.faceCount = 0,
    this.analysed = false,
    this.skipped = false,
    this.detailsRead = false,
    this.width,
    this.height,
    this.personIds = const [],
  });

  final double? latitude;
  final double? longitude;

  /// Frame size, learned from the file header on desktop. MediaStore already
  /// knows it on the phone.
  final int? width;
  final int? height;

  /// Whether the file header has been read. Most photos carry no GPS tag at
  /// all, and without this the background pass would re-read every untagged
  /// file on every launch.
  final bool detailsRead;

  /// Smart-category labels from the on-device image labeller.
  final List<String> labels;

  final int faceCount;

  /// Whether the smart pass has run. Distinguishes "no labels because we
  /// haven't looked" from "no labels because there was nothing to see", which
  /// is the difference between re-running a model on every launch and not.
  final bool analysed;

  /// Set when the pass *couldn't* look — the file is a cloud placeholder, or
  /// it's in a format the decoder doesn't read. Without this, a library that
  /// is mostly online-only reports every photo as done and shows nearly
  /// empty albums with no hint as to why.
  final bool skipped;

  /// Which [PersonCluster]s this photo's faces were assigned to. Only the
  /// ids live here — the fingerprints themselves are discarded once a face
  /// has been placed, and the clusters' running centroids live in
  /// `GalleryPeopleStore`, so this stays a couple of small integers per
  /// photo rather than a float vector per face.
  final List<int> personIds;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lon': longitude,
        if (labels.isNotEmpty) 'labels': labels,
        if (faceCount > 0) 'faces': faceCount,
        if (analysed) 'done': true,
        if (skipped) 'skip': true,
        if (detailsRead) 'read': true,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
        if (personIds.isNotEmpty) 'people': personIds,
      };

  factory GalleryCacheEntry.fromJson(Map<String, dynamic> json) =>
      GalleryCacheEntry(
        latitude: (json['lat'] as num?)?.toDouble(),
        longitude: (json['lon'] as num?)?.toDouble(),
        labels: [
          for (final label in (json['labels'] as List<dynamic>? ?? const []))
            label.toString(),
        ],
        faceCount: (json['faces'] as num?)?.toInt() ?? 0,
        analysed: json['done'] == true,
        skipped: json['skip'] == true,
        // Entries written before the header pass also learned frame sizes
        // carry the old 'geo' flag. Treating those as unread costs one extra
        // header read per photo, once, and fills in the dimensions they
        // never had.
        detailsRead: json['read'] == true,
        width: (json['w'] as num?)?.toInt(),
        height: (json['h'] as num?)?.toInt(),
        personIds: [
          for (final id in (json['people'] as List<dynamic>? ?? const []))
            (id as num).toInt(),
        ],
      );

  GalleryCacheEntry copyWith({
    double? latitude,
    double? longitude,
    List<String>? labels,
    int? faceCount,
    bool? analysed,
    bool? skipped,
    bool? detailsRead,
    int? width,
    int? height,
    List<int>? personIds,
  }) =>
      GalleryCacheEntry(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        labels: labels ?? this.labels,
        faceCount: faceCount ?? this.faceCount,
        analysed: analysed ?? this.analysed,
        skipped: skipped ?? this.skipped,
        detailsRead: detailsRead ?? this.detailsRead,
        width: width ?? this.width,
        height: height ?? this.height,
        personIds: personIds ?? this.personIds,
      );
}

/// The gallery's side notes, kept in one JSON file next to the thumbnails.
///
/// Everything in here is derived from files the user already has, so it lives
/// under `gallery_cache/` — the one directory [StorageGuardService] leaves out
/// of the local storage cap.
class GalleryCache {
  final Map<String, GalleryCacheEntry> _entries = {};
  List<String> _roots = [];
  String? _scanRoot;
  File? _file;
  bool _dirty = false;
  bool _writing = false;

  Map<String, GalleryCacheEntry> get entries => Map.unmodifiable(_entries);

  /// Extra folders the user added on desktop.
  List<String> get roots => List.unmodifiable(_roots);

  /// The single folder the scan is confined to, or null for the whole
  /// library. Survives a restart — a confinement that quietly lifted itself
  /// on the next launch would be worse than not having one.
  String? get scanRoot => _scanRoot;

  GalleryCacheEntry? operator [](String key) => _entries[key];

  Future<void> load() async {
    try {
      final file = await _open();
      if (!file.existsSync()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      _roots = [
        for (final root in (decoded['roots'] as List<dynamic>? ?? const []))
          root.toString(),
      ];
      final storedScanRoot = (decoded['scanRoot'] as String?)?.trim();
      _scanRoot =
          (storedScanRoot == null || storedScanRoot.isEmpty) ? null : storedScanRoot;
      final entries = decoded['entries'];
      if (entries is Map<String, dynamic>) {
        entries.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _entries[key] = GalleryCacheEntry.fromJson(value);
          }
        });
      }

      final storedVersion = (decoded['analysisVersion'] as num?)?.toInt() ?? 0;
      if (storedVersion != kGalleryAnalysisVersion) _forgetVerdicts();
    } catch (_) {
      // A cache that won't parse is a cache worth throwing away.
      _entries.clear();
    }
  }

  /// Drops what the models decided, keeping what was measured.
  void _forgetVerdicts() {
    _entries.updateAll(
      (_, entry) => entry.copyWith(
        analysed: false,
        skipped: false,
        labels: const [],
        faceCount: 0,
      ),
    );
    _dirty = true;
  }

  void put(String key, GalleryCacheEntry entry) {
    _entries[key] = entry;
    _dirty = true;
  }

  void setRoots(List<String> roots) {
    _roots = List.of(roots);
    _dirty = true;
  }

  void setScanRoot(String? root) {
    _scanRoot = (root == null || root.trim().isEmpty) ? null : root.trim();
    _dirty = true;
  }

  /// Drops notes about files that are no longer in the library, so the cache
  /// tracks the device rather than growing forever.
  void retainKeys(Set<String> keys) {
    final before = _entries.length;
    _entries.removeWhere((key, _) => !keys.contains(key));
    if (_entries.length != before) _dirty = true;
  }

  /// Writes only when something changed, and never twice at once.
  Future<void> flush() async {
    if (!_dirty || _writing) return;
    _writing = true;
    _dirty = false;
    try {
      final file = await _open();
      await file.writeAsString(jsonEncode({
        'version': 1,
        'analysisVersion': kGalleryAnalysisVersion,
        'roots': _roots,
        if (_scanRoot != null) 'scanRoot': _scanRoot,
        'entries': {
          for (final entry in _entries.entries)
            if (entry.value.toJson().isNotEmpty)
              entry.key: entry.value.toJson(),
        },
      }));
    } catch (_) {
      _dirty = true;
    } finally {
      _writing = false;
    }
  }

  Future<File> _open() async {
    final existing = _file;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final separator = Platform.pathSeparator;
    final directory = Directory('${support.path}${separator}gallery_cache');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return _file = File('${directory.path}${separator}index.json');
  }
}

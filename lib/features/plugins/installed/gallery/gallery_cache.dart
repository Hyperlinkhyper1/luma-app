import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// What has already been learned about one file, so opening the gallery a
/// second time doesn't re-read every EXIF header and re-run every model.
class GalleryCacheEntry {
  const GalleryCacheEntry({
    this.latitude,
    this.longitude,
    this.labels = const [],
    this.faceCount = 0,
    this.analysed = false,
    this.geoChecked = false,
  });

  final double? latitude;
  final double? longitude;

  /// Whether the GPS tag has been read. Most photos don't have one, and
  /// without this the background pass would re-read every untagged file on
  /// every launch.
  final bool geoChecked;

  /// Smart-category labels from the on-device image labeller.
  final List<String> labels;

  final int faceCount;

  /// Whether the smart pass has run. Distinguishes "no labels because we
  /// haven't looked" from "no labels because there was nothing to see", which
  /// is the difference between re-running a model on every launch and not.
  final bool analysed;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lon': longitude,
        if (labels.isNotEmpty) 'labels': labels,
        if (faceCount > 0) 'faces': faceCount,
        if (analysed) 'done': true,
        if (geoChecked) 'geo': true,
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
        geoChecked: json['geo'] == true,
      );

  GalleryCacheEntry copyWith({
    double? latitude,
    double? longitude,
    List<String>? labels,
    int? faceCount,
    bool? analysed,
    bool? geoChecked,
  }) =>
      GalleryCacheEntry(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        labels: labels ?? this.labels,
        faceCount: faceCount ?? this.faceCount,
        analysed: analysed ?? this.analysed,
        geoChecked: geoChecked ?? this.geoChecked,
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
  File? _file;
  bool _dirty = false;
  bool _writing = false;

  Map<String, GalleryCacheEntry> get entries => Map.unmodifiable(_entries);

  /// Extra folders the user added on desktop.
  List<String> get roots => List.unmodifiable(_roots);

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
      final entries = decoded['entries'];
      if (entries is Map<String, dynamic>) {
        entries.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _entries[key] = GalleryCacheEntry.fromJson(value);
          }
        });
      }
    } catch (_) {
      // A cache that won't parse is a cache worth throwing away.
      _entries.clear();
    }
  }

  void put(String key, GalleryCacheEntry entry) {
    _entries[key] = entry;
    _dirty = true;
  }

  void setRoots(List<String> roots) {
    _roots = List.of(roots);
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
        'roots': _roots,
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

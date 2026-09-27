import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'model/sketch_meta.dart';

/// A document as the library shows it.
class SketchSummary {
  const SketchSummary({required this.meta, this.thumbnail});

  final SketchMeta meta;

  /// The saved preview, or null before the first save.
  final File? thumbnail;
}

/// A document read back from disk: its metadata and the PNG bytes of every
/// layer that has pixels, keyed by layer id.
class StoredSketch {
  const StoredSketch({required this.meta, required this.layers});

  final SketchMeta meta;
  final Map<int, Uint8List> layers;
}

/// Free Sketch documents on disk.
///
/// Artwork is pixels, often tens of megabytes of them, so it lives in plain
/// files rather than a database: one folder per document holding
/// `document.json`, one PNG per painted layer and a thumbnail. Saving writes
/// changed layers under fresh file names first and swaps `document.json` in
/// last, so a crash mid-save leaves the previous version intact rather than a
/// document pointing at half-written pixels.
///
/// Documents are not part of server sync: a single painting can be larger
/// than an entire plan's sync quota.
class FreeSketchRepository extends ChangeNotifier {
  FreeSketchRepository({Future<Directory> Function()? root}) : _rootProvider = root ?? _defaultRoot;

  final Future<Directory> Function() _rootProvider;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}free_sketch');
  }

  String get _sep => Platform.pathSeparator;

  Future<Directory> _docsDir() async {
    final root = await _rootProvider();
    final dir = Directory('${root.path}${_sep}docs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _docDir(String id) async {
    if (id.isEmpty || id.contains('/') || id.contains(r'\') || id.contains('..')) {
      throw ArgumentError.value(id, 'id', 'Not a document id');
    }
    return Directory('${(await _docsDir()).path}$_sep$id');
  }

  File _file(Directory dir, String name) => File('${dir.path}$_sep$name');

  Future<List<SketchSummary>> list() async {
    final docs = await _docsDir();
    final out = <SketchSummary>[];
    await for (final entity in docs.list()) {
      if (entity is! Directory) continue;
      final id = entity.path.split(_sep).last;
      try {
        final meta = await _readMeta(entity, id);
        final thumb = _file(entity, 'thumb.png');
        out.add(SketchSummary(meta: meta, thumbnail: await thumb.exists() ? thumb : null));
      } on Object {
        // A folder without a readable document.json is an interrupted create;
        // it is not shown rather than failing the whole library.
        continue;
      }
    }
    out.sort((a, b) => b.meta.updated.compareTo(a.meta.updated));
    return out;
  }

  Future<SketchMeta> _readMeta(Directory dir, String id) async {
    final text = await _file(dir, 'document.json').readAsString();
    final json = jsonDecode(text);
    if (json is! Map) throw const FormatException('document.json is not an object');
    return SketchMeta.fromJson(id, json.cast<String, Object?>());
  }

  Future<SketchMeta> meta(String id) async => _readMeta(await _docDir(id), id);

  /// Creates an empty document, optionally with a first layer already
  /// painted (an imported image).
  Future<SketchMeta> create({
    required String title,
    required int width,
    required int height,
    int background = 0xFFFFFFFF,
    bool showBackground = true,
    Uint8List? firstLayerPng,
    String firstLayerName = 'Layer 1',
  }) async {
    final docs = await _docsDir();
    var id = 's${DateTime.now().millisecondsSinceEpoch}';
    while (await Directory('${docs.path}$_sep$id').exists()) {
      id = '${id}x';
    }
    final dir = Directory('${docs.path}$_sep$id');
    await dir.create(recursive: true);
    String? file;
    if (firstLayerPng != null) {
      file = 'layer_1_0.png';
      await _file(dir, file).writeAsBytes(firstLayerPng, flush: true);
    }
    final now = DateTime.now();
    final meta = SketchMeta(
      id: id,
      title: title,
      width: width,
      height: height,
      created: now,
      updated: now,
      background: background,
      showBackground: showBackground,
      activeLayerId: 1,
      layers: [SketchLayerMeta(id: 1, name: firstLayerName, file: file)],
    );
    await _writeMeta(dir, meta);
    StorageGuard.instance.scheduleRefresh();
    notifyListeners();
    return meta;
  }

  Future<StoredSketch> load(String id) async {
    final dir = await _docDir(id);
    final meta = await _readMeta(dir, id);
    final layers = <int, Uint8List>{};
    for (final layer in meta.layers) {
      final name = layer.file;
      if (name == null) continue;
      final file = _file(dir, name);
      if (await file.exists()) layers[layer.id] = await file.readAsBytes();
    }
    return StoredSketch(meta: meta, layers: layers);
  }

  /// Writes a new version of a document.
  ///
  /// [changed] holds fresh PNGs for the layers whose pixels changed since
  /// the last save; every other layer keeps the `file` already in [meta]. A
  /// layer id mapped to null was cleared. Returns the metadata as written,
  /// with the new file names filled in.
  Future<SketchMeta> save(
    SketchMeta meta, {
    Map<int, Uint8List?> changed = const {},
    Uint8List? thumbnail,
  }) async {
    final dir = await _docDir(meta.id);
    if (!await dir.exists()) await dir.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final layers = <SketchLayerMeta>[];
    for (final layer in meta.layers) {
      if (!changed.containsKey(layer.id)) {
        layers.add(layer);
        continue;
      }
      final bytes = changed[layer.id];
      String? file;
      if (bytes != null) {
        file = 'layer_${layer.id}_$stamp.png';
        await _file(dir, file).writeAsBytes(bytes, flush: true);
      }
      layers.add(SketchLayerMeta(
        id: layer.id,
        name: layer.name,
        file: file,
        opacity: layer.opacity,
        blend: layer.blend,
        visible: layer.visible,
        locked: layer.locked,
        alphaLocked: layer.alphaLocked,
        clipped: layer.clipped,
      ));
    }
    final written = meta.copyWith(layers: layers, updated: DateTime.now());
    if (thumbnail != null) {
      final tmp = _file(dir, 'thumb.png.tmp');
      await tmp.writeAsBytes(thumbnail, flush: true);
      await _replace(tmp, _file(dir, 'thumb.png'));
    }
    await _writeMeta(dir, written);

    final keep = {
      'document.json',
      'thumb.png',
      for (final layer in layers)
        if (layer.file != null) layer.file!,
    };
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(_sep).last;
      if (!keep.contains(name) && name.startsWith('layer_') && name.endsWith('.png')) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Still open elsewhere (Windows); the next save sweeps it up.
        }
      }
    }
    StorageGuard.instance.scheduleRefresh();
    notifyListeners();
    return written;
  }

  Future<void> _writeMeta(Directory dir, SketchMeta meta) async {
    final tmp = _file(dir, 'document.json.tmp');
    await tmp.writeAsString(jsonEncode(meta.toJson()), flush: true);
    await _replace(tmp, _file(dir, 'document.json'));
  }

  Future<void> _replace(File source, File target) async {
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // Windows refuses to rename over an existing file on some volumes.
      if (await target.exists()) await target.delete();
      await source.rename(target.path);
    }
  }

  Future<void> rename(String id, String title) async {
    final dir = await _docDir(id);
    final meta = await _readMeta(dir, id);
    await _writeMeta(dir, meta.copyWith(title: title));
    notifyListeners();
  }

  Future<SketchMeta> duplicate(String id) async {
    final source = await _docDir(id);
    final meta = await _readMeta(source, id);
    final docs = await _docsDir();
    var copyId = 's${DateTime.now().millisecondsSinceEpoch}';
    while (await Directory('${docs.path}$_sep$copyId').exists()) {
      copyId = '${copyId}x';
    }
    final target = Directory('${docs.path}$_sep$copyId');
    await target.create(recursive: true);
    await for (final entity in source.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(_sep).last;
      if (name == 'document.json' || name.endsWith('.tmp')) continue;
      await entity.copy(_file(target, name).path);
    }
    final now = DateTime.now();
    final copy = SketchMeta(
      id: copyId,
      title: '${meta.title} copy',
      width: meta.width,
      height: meta.height,
      created: now,
      updated: now,
      background: meta.background,
      showBackground: meta.showBackground,
      activeLayerId: meta.activeLayerId,
      layers: meta.layers,
    );
    await _writeMeta(target, copy);
    StorageGuard.instance.scheduleRefresh();
    notifyListeners();
    return copy;
  }

  Future<void> delete(String id) async {
    final dir = await _docDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    StorageGuard.instance.scheduleRefresh();
    notifyListeners();
  }

  // --------------------------------------------------------------- prefs

  Future<File> _prefsFile() async {
    final root = await _rootProvider();
    if (!await root.exists()) await root.create(recursive: true);
    return File('${root.path}${_sep}prefs.json');
  }

  /// Studio preferences: brush tweaks, palettes, recent colours, input
  /// settings. Missing or unreadable means defaults.
  Future<Map<String, Object?>> loadPrefs() async {
    try {
      final file = await _prefsFile();
      if (!await file.exists()) return {};
      final json = jsonDecode(await file.readAsString());
      return json is Map ? json.cast<String, Object?>() : {};
    } on Object {
      return {};
    }
  }

  Future<void> savePrefs(Map<String, Object?> prefs) async {
    final file = await _prefsFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(prefs), flush: true);
    await _replace(tmp, file);
  }
}

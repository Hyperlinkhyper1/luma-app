import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One interactive benchmark scene the app can download, e.g. a model's
/// independent implementation of the Pagoda, Engine, or Cathedral test.
///
/// The roster (id, kind, display name, description) lives in a `manifest.json`
/// next to the scenes; the heavy blobs — one HTML or GLB file per scene plus
/// optional PNG previews — live beside it. All three used to ship
/// inside the app bundle (`assets/tests/`), where ~6 MB of scenes made every
/// download bigger for data most installs never open. They now live on the
/// server and the app fetches them on demand, caching them on disk.
class AiBenchmarkEntry {
  const AiBenchmarkEntry({
    required this.id,
    required this.kind,
    required this.model,
    required this.description,
    required this.sizeBytes,
    required this.sha256,
    required this.updatedAtMs,
    required this.hasPreview,
    this.previewSha256 = '',
    this.vendor = '',
  });

  /// File stem of the scene, e.g. `pagoda_haiku45`. Also the detail-route key
  /// the client caches the download under.
  final String id;

  /// `pagoda`, `engine`, `pc`, `cathedral`, `keyboard` or `cruise_ship` — which test this
  /// scene implements.
  final String kind;

  /// Display name of the benchmarked model, e.g. `Haiku 4.5`.
  final String model;
  final String description;

  /// Vendor key of the company behind [model] (`anthropic`, `openai`, …), or
  /// '' when the app should work it out from the model name as it always has.
  final String vendor;

  /// The scene file's size and SHA-256, so the client can verify a download
  /// before pointing a WebView at it.
  final int sizeBytes;
  final String sha256;

  /// Last modification time of the scene file, milliseconds since epoch.
  final int updatedAtMs;

  /// Whether a per-scene PNG preview exists. Without one the client falls
  /// back to the kind's generic artwork, then to a plain icon tile.
  final bool hasPreview;

  /// SHA-256 of the preview PNG, or '' when there is none. The client caches
  /// previews on disk and re-downloads when this changes, so a re-rendered
  /// banner actually reaches installs that already cached the old one.
  final String previewSha256;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'model': model,
        'description': description,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'updatedAtMs': updatedAtMs,
        'hasPreview': hasPreview,
        'previewSha256': previewSha256,
        if (vendor.isNotEmpty) 'vendor': vendor,
      };
}

/// Serves the AI benchmark scenes from disk.
///
/// Files are read from `<dataDir>/ai_benchmarks/`, overlaid on an optional
/// read-only seed directory (the `server/benchmarks/` checkout baked into the
/// Docker image, or `server/benchmarks/` when running from source): a file
/// the operator dropped into the data directory wins, everything else falls
/// back to the seed. The manifest is rebuilt from disk on every call, so an
/// operator who adds a scene and edits the manifest needs no restart and no
/// rescan step — the next manifest fetch simply lists it.
class AiBenchmarkStore {
  AiBenchmarkStore._(this._dataDir, this._seedDir);

  final String _dataDir;
  final String? _seedDir;

  static const dirName = 'ai_benchmarks';

  static final RegExp idPattern = RegExp(r'^[a-z0-9_]{1,80}$');

  /// Every test a scene can implement. A scene's id always starts with its
  /// kind and an underscore.
  static const kinds = [
    'pagoda',
    'engine',
    'pc',
    'cathedral',
    'keyboard',
    'cruise_ship',
  ];

  static final RegExp vendorPattern = RegExp(r'^[a-z0-9-]{0,40}$');

  /// Cap on one uploaded scene. The biggest checked-in GLB is ~16 MB; this
  /// stays under Cloudflare's 100 MB request limit and GitHub's 100 MB file
  /// limit even after the base64 blob upload inflates it by a third.
  static const maxUploadBytes = 60 * 1024 * 1024;

  /// File extension a scene of [kind] is stored under.
  static String extForKind(String kind) => kind == 'cathedral' ? 'glb' : 'html';

  /// Generic artwork lives under fixed historical names (`pagoda-preview.png`),
  /// so hyphens are allowed here — unlike scene ids, these never become cache
  /// keys or file stems, they are only looked up in the previews directory.
  static final RegExp _previewFilePattern = RegExp(r'^[a-z0-9_-]+\.png$');

  static Future<AiBenchmarkStore> open(String dataDir,
      {String? seedDir}) async {
    await Directory('$dataDir/$dirName').create(recursive: true);
    await Directory('$dataDir/$dirName/previews').create(recursive: true);
    return AiBenchmarkStore._(dataDir, seedDir);
  }

  String get _dir => '$_dataDir/$dirName';

  /// Scenes uploaded from the admin dashboard, kept apart from the operator's
  /// hand-dropped overrides: an upload is also committed to the repo, and
  /// once a deploy brings that (or a later) version into the seed, the seed
  /// must win again — see [_sceneFile] and [_readRoster].
  String get _uploadsDir => '$_dir/uploads';

  File get _uploadsRoster => File('$_dir/uploads.json');

  /// Every roster entry with a servable scene, with the fields the
  /// dashboard's edit form shows.
  Future<List<Map<String, dynamic>>> editableEntries() async {
    final roster = await _readRoster();
    final byId = {for (final item in roster.benchmarks) item.id: item};
    return [
      for (final c in await previewCoverage())
        {
          'id': c.id,
          'kind': byId[c.id]?.kind ?? _kindOf(c.id),
          'model': byId[c.id]?.model ?? _prettyId(c.id),
          'vendor': byId[c.id]?.vendor ?? '',
          'description': byId[c.id]?.description ?? '',
        },
    ];
  }

  /// Stores a scene uploaded from the admin dashboard and adds (or replaces)
  /// its roster stanza. Returns the stanza as it belongs in the manifest, or
  /// throws [ArgumentError] with a message fit for the dashboard.
  ///
  /// With [bytes] null this edits an existing entry: only the stanza
  /// changes, and the scene already served for [id] stays.
  Future<Map<String, dynamic>> saveUpload({
    required String kind,
    required String id,
    required String model,
    required String vendor,
    required String description,
    required List<int>? bytes,
  }) async {
    final entry = validateUpload(
      kind: kind,
      id: id,
      model: model,
      vendor: vendor,
      description: description,
      bytes: bytes,
    );
    if (bytes == null) {
      if (await _sceneFile(id) == null) {
        throw ArgumentError('There is no test "$id" to edit.');
      }
    } else {
      final dir = Directory(_uploadsDir);
      await dir.create(recursive: true);
      final target = File('${dir.path}/$id.${extForKind(kind)}');
      final tmp = File('${target.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
    }

    final uploads = await _readUploads();
    uploads.removeWhere((e) => e['id'] == id);
    uploads.add({
      ...entry,
      'uploadedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    final rosterTmp = File('${_uploadsRoster.path}.tmp');
    await rosterTmp.writeAsString(jsonEncode(uploads));
    await rosterTmp.rename(_uploadsRoster.path);
    return entry;
  }

  /// Checks an upload's metadata and bytes (unless null, for an edit) and
  /// returns its manifest stanza.
  static Map<String, dynamic> validateUpload({
    required String kind,
    required String id,
    required String model,
    required String vendor,
    required String description,
    required List<int>? bytes,
  }) {
    if (!kinds.contains(kind)) throw ArgumentError('Unknown test "$kind".');
    if (!idPattern.hasMatch(id) ||
        !id.startsWith('${kind}_') ||
        id.length <= kind.length + 1) {
      throw ArgumentError('The id must look like ${kind}_my_model: '
          'lowercase letters, digits and underscores.');
    }
    final name = model.trim();
    if (name.isEmpty || name.length > 80) {
      throw ArgumentError('Give the model a name (up to 80 characters).');
    }
    if (!vendorPattern.hasMatch(vendor)) {
      throw ArgumentError('Unknown company "$vendor".');
    }
    if (description.length > 300) {
      throw ArgumentError('Keep the description under 300 characters.');
    }
    if (bytes != null) _checkSceneBytes(kind, bytes);
    return {
      'id': id,
      'kind': kind,
      'model': name,
      if (vendor.isNotEmpty) 'vendor': vendor,
      'description': description.trim(),
    };
  }

  static void _checkSceneBytes(String kind, List<int> bytes) {
    if (bytes.isEmpty) throw ArgumentError('The file is empty.');
    if (bytes.length > maxUploadBytes) {
      throw ArgumentError(
          'The file is over ${maxUploadBytes ~/ (1024 * 1024)} MB.');
    }
    final isGlb =
        bytes.length >= 12 && String.fromCharCodes(bytes.take(4)) == 'glTF';
    if (extForKind(kind) == 'glb') {
      if (!isGlb) {
        throw ArgumentError('The $kind test takes a binary .glb model.');
      }
    } else {
      final head = utf8.decode(bytes.take(4096).toList(), allowMalformed: true);
      if (isGlb || !head.contains('<')) {
        throw ArgumentError(
            'The $kind test takes a self-contained .html page.');
      }
      if (_canvasKinds.contains(kind) &&
          !_drawsOnCanvas.hasMatch(utf8.decode(bytes, allowMalformed: true))) {
        throw ArgumentError('The $kind test is a 3D scene, but this page '
            'never draws to a canvas. Is it meant for another test?');
      }
    }
  }

  /// Tests whose scenes are always WebGL. The banner renderer waits for
  /// their canvas, so a page without one (a CSS keyboard filed under the
  /// wrong test) can only ever fail there.
  static const _canvasKinds = {'pagoda', 'engine', 'pc', 'cruise_ship'};

  static final RegExp _drawsOnCanvas = RegExp(
      r'''<canvas|getcontext\(|webgl|three(\.module)?(\.min)?\.js|["']three["']''',
      caseSensitive: false);

  Future<List<Map<String, dynamic>>> _readUploads() async {
    try {
      final decoded = jsonDecode(await _uploadsRoster.readAsString());
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map<String, dynamic> && e['id'] is String) e,
        ];
      }
    } catch (_) {
      // No uploads yet, or a torn file: the seed roster still stands.
    }
    return [];
  }

  /// Every benchmarked scene, manifest order first, then any scene file on
  /// disk the manifest doesn't name yet (with a derived display name, so a
  /// dropped-in file shows up instead of silently 404ing).
  Future<List<AiBenchmarkEntry>> list() async {
    final roster = await _readRoster();
    final entries = <AiBenchmarkEntry>[];
    final seen = <String>{};
    for (final item in roster.benchmarks) {
      final scene = await _sceneFile(item.id);
      if (scene == null) continue;
      entries.add(await _describe(item, scene));
      seen.add(item.id);
    }
    for (final id in await _sceneIdsOnDisk()) {
      if (seen.contains(id)) continue;
      final scene = await _sceneFile(id);
      if (scene == null) continue;
      entries.add(await _describe(
        _RosterItem(id: id, kind: _kindOf(id), model: _prettyId(id)),
        scene,
      ));
    }
    return entries;
  }

  /// Every servable scene id and whether it has a preview, in [list] order.
  /// Unlike [list] this hashes nothing, so the admin dashboard can poll it.
  Future<List<({String id, bool hasPreview})>> previewCoverage() async {
    final ids = <String>[];
    for (final item in (await _readRoster()).benchmarks) {
      if (!ids.contains(item.id) && await _sceneFile(item.id) != null) {
        ids.add(item.id);
      }
    }
    for (final id in await _sceneIdsOnDisk()) {
      if (!ids.contains(id)) ids.add(id);
    }
    return [
      for (final id in ids)
        (id: id, hasPreview: await _previewFile('$id.png') != null),
    ];
  }

  /// Every servable scene for the dashboard's banner catalog: roster
  /// metadata, whether it has a banner (and when that was written, so the
  /// thumbnail can be cache-busted) and whether a hand-set framing exists.
  /// Like [previewCoverage] it hashes nothing.
  Future<List<Map<String, dynamic>>> bannerCatalog() async {
    final roster = await _readRoster();
    final byId = {for (final item in roster.benchmarks) item.id: item};
    final out = <Map<String, dynamic>>[];
    for (final c in await previewCoverage()) {
      final item = byId[c.id];
      final preview = c.hasPreview ? await _previewFile('${c.id}.png') : null;
      out.add({
        'id': c.id,
        'kind': item?.kind ?? _kindOf(c.id),
        'model': item?.model ?? _prettyId(c.id),
        'hasPreview': c.hasPreview,
        'previewAtMs': preview == null
            ? 0
            : (await preview.stat()).modified.millisecondsSinceEpoch,
        'hasFraming': await _framingFile(c.id) != null,
        'framable': _extOf(c.id) == 'html',
      });
    }
    return out;
  }

  /// A scene's hand-set banner camera (see `server/tool/shot_control.mjs`),
  /// or null when its banner is framed automatically. Saved in the data
  /// directory's `framing/` and read with the seed's `framing/` beneath it,
  /// like every other benchmark file.
  Future<Map<String, dynamic>?> readFraming(String id) async {
    if (!_validId(id)) return null;
    final file = await _framingFile(id);
    if (file == null) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Keeps only the numeric pose fields the renderer reads, so the file can
  /// never carry anything else.
  static Map<String, dynamic>? cleanFraming(Object? raw) {
    if (raw is! Map) return null;
    const required = ['px', 'py', 'pz', 'qx', 'qy', 'qz', 'qw'];
    const optional = ['fov', 'zoom'];
    final out = <String, dynamic>{};
    for (final k in [...required, ...optional]) {
      final v = raw[k];
      if (v is num && v.isFinite) {
        out[k] = v.toDouble();
      } else if (required.contains(k)) {
        return null;
      }
    }
    return out;
  }

  Future<bool> writeFraming(String id, Map<String, dynamic> pose) async {
    if (!_validId(id) || _extOf(id) != 'html') return false;
    final dir = Directory('$_dir/framing');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$id.json');
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      ...pose,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
    }));
    await tmp.rename(target.path);
    return true;
  }

  /// Drops the data directory's framing; a checked-in seed framing, if any,
  /// shows through again.
  Future<bool> deleteFraming(String id) async {
    if (!_validId(id)) return false;
    final file = File('$_dir/framing/$id.json');
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  Future<File?> _framingFile(String id) async {
    final override = File('$_dir/framing/$id.json');
    if (await override.exists()) return override;
    final seed = _seedDir == null ? null : File('$_seedDir/framing/$id.json');
    if (seed != null && await seed.exists()) return seed;
    return null;
  }

  /// The read-only seed directory under the data-directory overrides, if any.
  String? get seedDir => _seedDir;

  /// Generic tile artwork per test kind, e.g. `pagoda-preview.png`.
  Future<Map<String, String>> fallbackPreviews() async =>
      (await _readRoster()).fallbacks;

  /// SHA-256 per generic artwork file, so clients refresh a fallback they
  /// already cached when the operator replaces it.
  Future<Map<String, String>> fallbackHashes() async {
    final hashes = <String, String>{};
    for (final file in (await _readRoster()).fallbacks.values.toSet()) {
      final found = await _previewFile(file);
      if (found == null) continue;
      final hash = await _fileHash(found);
      if (hash.isNotEmpty) hashes[file] = hash;
    }
    return hashes;
  }

  Future<({List<int> bytes, String etag})?> readScene(String id) async {
    if (!_validId(id)) return null;
    final file = await _sceneFile(id);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return (bytes: bytes, etag: _etagFor(await file.stat(), bytes));
  }

  Future<({List<int> bytes, String etag})?> readPreview(String id) async {
    if (!_validId(id)) return null;
    final file = await _previewFile('$id.png');
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return (bytes: bytes, etag: _etagFor(await file.stat(), bytes));
  }

  /// Serves a generic artwork file from the previews directory (see
  /// [fallbackPreviews]). Only files actually present there are served, so
  /// this can't be used to read anything else off disk.
  Future<({List<int> bytes, String etag})?> readFallback(String file) async {
    if (!_previewFilePattern.hasMatch(file)) return null;
    final found = await _previewFile(file);
    if (found == null) return null;
    final bytes = await found.readAsBytes();
    return (bytes: bytes, etag: _etagFor(await found.stat(), bytes));
  }

  /// The manifest payload the app lists benchmarks from, with a content tag
  /// the client sends back as `If-None-Match`.
  Future<({Map<String, dynamic> json, String etag})> manifest() async {
    final benchmarks = await list();
    var refreshedAtMs = 0;
    var totalBytes = 0;
    final previewHashes = <String, String>{};
    for (final b in benchmarks) {
      if (b.updatedAtMs > refreshedAtMs) refreshedAtMs = b.updatedAtMs;
      totalBytes += b.sizeBytes;
      if (b.previewSha256.isNotEmpty) previewHashes[b.id] = b.previewSha256;
    }
    return (
      json: {
        'refreshedAtMs': refreshedAtMs,
        'fallbackPreviews': await fallbackPreviews(),
        'fallbackHashes': await fallbackHashes(),
        'previewHashes': previewHashes,
        'benchmarks': [for (final b in benchmarks) b.toJson()],
      },
      // Count, bytes and newest mtime move together on any change; a
      // collision would need two different rosters with identical totals.
      etag: '"${benchmarks.length}-$totalBytes-$refreshedAtMs"',
    );
  }

  // ---- Files ---------------------------------------------------------------

  bool _validId(String id) =>
      idPattern.hasMatch(id) && kinds.any((kind) => id.startsWith('${kind}_'));

  Future<File?> _sceneFile(String id) async {
    final ext = _extOf(id);
    final override = File('$_dir/$id.$ext');
    if (await override.exists()) return override;
    if (ext == 'html') {
      final overrideIndex = File('$_dir/$id/index.html');
      if (await overrideIndex.exists()) return overrideIndex;
    }
    File? seed = _seedDir == null ? null : File('$_seedDir/scenes/$id.$ext');
    if (seed != null && !await seed.exists() && ext == 'html') {
      seed = File('$_seedDir/scenes/$id/index.html');
    }
    final seedExists = seed != null && await seed.exists();
    final upload = File('$_uploadsDir/$id.$ext');
    if (await upload.exists() &&
        (!seedExists ||
            (await upload.lastModified()).isAfter(await seed.lastModified()))) {
      return upload;
    }
    if (seedExists) return seed;
    return null;
  }

  Future<File?> _previewFile(String file) async {
    final override = File('$_dir/previews/$file');
    if (await override.exists()) return override;
    final seed = _seedDir == null ? null : File('$_seedDir/previews/$file');
    if (seed != null && await seed.exists()) return seed;
    return null;
  }

  Future<List<String>> _sceneIdsOnDisk() async {
    final ids = <String>{};
    final dirs = [
      Directory(_dir),
      Directory(_uploadsDir),
      if (_seedDir != null) Directory('$_seedDir/scenes'),
    ];
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final id = entity.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last;
          if (_validId(id) &&
              _extOf(id) == 'html' &&
              await File('${entity.path}/index.html').exists()) {
            ids.add(id);
          }
          continue;
        }
        if (entity is! File) continue;
        final base = entity.uri.pathSegments.last;
        final dot = base.lastIndexOf('.');
        if (dot < 0) continue;
        final id = base.substring(0, dot);
        if (base.substring(dot + 1) != _extOf(id)) continue;
        if (_validId(id)) ids.add(id);
      }
    }
    return ids.toList()..sort();
  }

  Future<AiBenchmarkEntry> _describe(_RosterItem item, File scene) async {
    final stat = await scene.stat();
    final bytes = await scene.readAsBytes();
    final preview = await _previewFile('${item.id}.png');
    return AiBenchmarkEntry(
      id: item.id,
      kind: item.kind,
      model: item.model,
      description: item.description,
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      updatedAtMs: stat.modified.millisecondsSinceEpoch,
      hasPreview: preview != null,
      previewSha256: preview == null ? '' : await _fileHash(preview),
      vendor: item.vendor,
    );
  }

  /// SHA-256 of a small file, cached by modification time so every manifest
  /// fetch doesn't re-hash ~80 previews from scratch.
  final Map<String, ({int mtimeMs, String hash})> _hashCache = {};

  Future<String> _fileHash(File file) async {
    try {
      final stat = await file.stat();
      final mtimeMs = stat.modified.millisecondsSinceEpoch;
      final cached = _hashCache[file.path];
      if (cached != null && cached.mtimeMs == mtimeMs) return cached.hash;
      final hash = sha256.convert(await file.readAsBytes()).toString();
      _hashCache[file.path] = (mtimeMs: mtimeMs, hash: hash);
      return hash;
    } catch (_) {
      return '';
    }
  }

  String _etagFor(FileStat stat, List<int> bytes) =>
      '"${stat.size}-${stat.modified.millisecondsSinceEpoch}"';

  static String _extOf(String id) =>
      id.startsWith('cathedral_') ? 'glb' : 'html';

  static String _kindOf(String id) {
    for (final kind in kinds) {
      if (id.startsWith('${kind}_')) return kind;
    }
    return 'pagoda';
  }

  /// `pagoda_gpt56_sol_xhigh` → `Gpt56 Sol Xhigh`: only ever a fallback for a
  /// scene the manifest doesn't name, where a rough label beats a raw id.
  static String _prettyId(String id) {
    final prefix = '${_kindOf(id)}_';
    final stem = id.startsWith(prefix) ? id.substring(prefix.length) : id;
    return stem
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  // ---- Roster ----------------------------------------------------------------

  /// The base roster with the dashboard's uploads laid over it. An upload
  /// replaces the stanza with its id, unless the seed manifest changed after
  /// the upload — then a deploy brought the committed version (or a later
  /// edit of it) in, and the seed is the truth again.
  Future<_Roster> _readRoster() async {
    final base = await _readBaseRoster();
    final uploads = await _readUploads();
    if (uploads.isEmpty) return base;
    final seedManifest =
        _seedDir == null ? null : File('$_seedDir/manifest.json');
    final seedAtMs = seedManifest != null && await seedManifest.exists()
        ? (await seedManifest.lastModified()).millisecondsSinceEpoch
        : 0;
    final items = [...base.benchmarks];
    for (final upload in uploads) {
      final item = _Roster.item(upload);
      if (item == null) continue;
      final at = upload['uploadedAtMs'];
      final index = items.indexWhere((e) => e.id == item.id);
      if (index < 0) {
        items.add(item);
      } else if (at is! int || at >= seedAtMs) {
        items[index] = item;
      }
    }
    return _Roster(benchmarks: items, fallbacks: base.fallbacks);
  }

  Future<_Roster> _readBaseRoster() async {
    final override = File('$_dir/manifest.json');
    if (await override.exists()) {
      try {
        return _Roster.parse(jsonDecode(await override.readAsString()));
      } catch (_) {
        // A broken override must not take the seed roster down with it.
      }
    }
    if (_seedDir != null) {
      final seed = File('$_seedDir/manifest.json');
      if (await seed.exists()) {
        try {
          return _Roster.parse(jsonDecode(await seed.readAsString()));
        } catch (_) {
          return const _Roster.empty();
        }
      }
    }
    return const _Roster.empty();
  }
}

class _RosterItem {
  const _RosterItem({
    required this.id,
    required this.kind,
    required this.model,
    this.description = '',
    this.vendor = '',
  });

  final String id;
  final String kind;
  final String model;
  final String description;
  final String vendor;
}

class _Roster {
  const _Roster({required this.benchmarks, required this.fallbacks});
  const _Roster.empty()
      : benchmarks = const [],
        fallbacks = const {};

  final List<_RosterItem> benchmarks;
  final Map<String, String> fallbacks;

  static _RosterItem? item(Map<String, dynamic> e) {
    final id = e['id'];
    if (id is! String || !AiBenchmarkStore.idPattern.hasMatch(id)) return null;
    final kind = e['kind'];
    final vendor = e['vendor'];
    return _RosterItem(
      id: id,
      kind: kind is String && AiBenchmarkStore.kinds.contains(kind)
          ? kind
          : 'pagoda',
      model: e['model'] as String? ?? id,
      description: e['description'] as String? ?? '',
      vendor:
          vendor is String && AiBenchmarkStore.vendorPattern.hasMatch(vendor)
              ? vendor
              : '',
    );
  }

  static _Roster parse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return const _Roster.empty();
    return _Roster(
      benchmarks: [
        for (final e in (decoded['benchmarks'] as List? ?? const []))
          if (e is Map<String, dynamic>)
            if (item(e) case final parsed?) parsed,
      ],
      fallbacks: {
        for (final e
            in (decoded['fallbackPreviews'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
    );
  }
}

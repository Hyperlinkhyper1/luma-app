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
  });

  /// File stem of the scene, e.g. `pagoda_haiku45`. Also the detail-route key
  /// the client caches the download under.
  final String id;

  /// `pagoda` or `engine` — which test this scene implements.
  final String kind;

  /// Display name of the benchmarked model, e.g. `Haiku 4.5`.
  final String model;
  final String description;

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
      idPattern.hasMatch(id) &&
      (id.startsWith('pagoda_') ||
          id.startsWith('engine_') ||
          id.startsWith('pc_') ||
          id.startsWith('cathedral_'));

  Future<File?> _sceneFile(String id) async {
    final override = File('$_dir/$id.${_extOf(id)}');
    if (await override.exists()) return override;
    final seed =
        _seedDir == null ? null : File('$_seedDir/scenes/$id.${_extOf(id)}');
    if (seed != null && await seed.exists()) return seed;
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
      if (_seedDir != null) Directory('$_seedDir/scenes'),
    ];
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
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
    if (id.startsWith('engine_')) return 'engine';
    if (id.startsWith('pc_')) return 'pc';
    if (id.startsWith('cathedral_')) return 'cathedral';
    return 'pagoda';
  }

  /// `pagoda_gpt56_sol_xhigh` → `Gpt56 Sol Xhigh`: only ever a fallback for a
  /// scene the manifest doesn't name, where a rough label beats a raw id.
  static String _prettyId(String id) {
    final stem = id.startsWith('pagoda_')
        ? id.substring('pagoda_'.length)
        : id.startsWith('engine_')
            ? id.substring('engine_'.length)
            : id.startsWith('pc_')
                ? id.substring('pc_'.length)
                : id.startsWith('cathedral_')
                    ? id.substring('cathedral_'.length)
                    : id;
    return stem
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  // ---- Roster ----------------------------------------------------------------

  Future<_Roster> _readRoster() async {
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
  });

  final String id;
  final String kind;
  final String model;
  final String description;
}

class _Roster {
  const _Roster({required this.benchmarks, required this.fallbacks});
  const _Roster.empty()
      : benchmarks = const [],
        fallbacks = const {};

  final List<_RosterItem> benchmarks;
  final Map<String, String> fallbacks;

  static _Roster parse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return const _Roster.empty();
    return _Roster(
      benchmarks: [
        for (final e in (decoded['benchmarks'] as List? ?? const []))
          if (e is Map<String, dynamic> &&
              e['id'] is String &&
              AiBenchmarkStore.idPattern.hasMatch(e['id'] as String))
            _RosterItem(
              id: e['id'] as String,
              kind: e['kind'] == 'engine'
                  ? 'engine'
                  : e['kind'] == 'cathedral'
                      ? 'cathedral'
                      : e['kind'] == 'pc'
                          ? 'pc'
                          : 'pagoda',
              model: e['model'] as String? ?? (e['id'] as String),
              description: e['description'] as String? ?? '',
            ),
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

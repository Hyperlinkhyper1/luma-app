import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../sync/server_access.dart';
import '../../../../../sync/sync_service.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_api.dart';

/// Directory under the app-support root the roster and downloaded scenes live
/// in.
///
/// Listed in `StorageGuard._excludedDirNames`: scenes are a few megabytes of
/// derived, re-fetchable data that is byte-identical for every user, and
/// counting them would blow a Core plan's 5 MB cap the first time someone
/// opens a benchmark.
const String kAiBenchmarkCacheDir = 'ai_benchmarks_cache';

/// Owns the AI benchmark scenes on the client.
///
/// The scenes used to ship inside the app bundle; they live on the luma
/// server now. This repository holds the roster (which scenes exist), downloads
/// each scene's HTML the first time it is opened, and caches everything on
/// disk so benchmarks keep working offline once fetched.
///
/// Nothing here sends anything: the only requests made are GETs, and they are
/// only attempted once [SyncService.serverReady] is true — without an approved
/// account there is no roster at all, and the Tests tab says so.
class AiBenchmarkRepository extends ChangeNotifier {
  AiBenchmarkRepository(this._sync,
      {AiBenchmarkApi Function(String, String?)? apiFactory,
      Future<Directory> Function()? cacheDirProvider})
      : _apiFactory = apiFactory ??
            ((baseUrl, token) => AiBenchmarkApi(baseUrl, token: token)),
        _cacheDirProvider =
            cacheDirProvider ?? getApplicationSupportDirectory;

  /// A repository over a roster that is already in hand, with no sync service
  /// behind it — nothing it does can reach the network. Used by tests, and the
  /// honest shape for any caller that has no account to fetch from.
  @visibleForTesting
  AiBenchmarkRepository.withManifest(AiBenchmarkManifest manifest,
      {Directory? cacheDir})
      : _sync = null,
        _apiFactory = ((baseUrl, token) => AiBenchmarkApi(baseUrl)),
        _cacheDirProvider = cacheDir == null
            ? (() async =>
                Directory.systemTemp.createTemp('luma_bench_test'))
            : (() async => cacheDir),
        _manifest = manifest,
        _loaded = true {
    if (cacheDir != null) {
      _rootPath =
          '${cacheDir.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir';
    }
  }

  final SyncService? _sync;
  final AiBenchmarkApi Function(String baseUrl, String? token) _apiFactory;
  final Future<Directory> Function() _cacheDirProvider;

  /// Resolved by [_cacheRoot] on first use. The preview getters below are
  /// synchronous (cards read them during build) and simply report "not cached
  /// yet" until the first load has resolved it.
  String? _rootPath;

  AiBenchmarkManifest _manifest = AiBenchmarkManifest.empty;
  bool _loading = false;
  bool _refreshing = false;
  bool _loaded = false;
  String? _etag;
  String? _error;
  bool _previewsWarming = false;

  AiBenchmarkManifest get manifest => _manifest;

  /// True while the first load (cache, then server) is in flight — the tab
  /// shows a spinner rather than an empty roster.
  bool get loading => _loading;

  /// True while a server refresh runs behind an already-shown roster. Never
  /// blocks the UI.
  bool get refreshing => _refreshing;

  /// The last failure, or null. Only ever a footnote in the UI: a cached
  /// roster is still a roster.
  String? get error => _error;

  /// Whether a server fetch is even possible on this device right now.
  bool get canRefresh => _sync?.serverReady ?? false;

  List<AiBenchmark> benchmarksOfKind(String kind) =>
      _manifest.ofKind(kind);

  AiBenchmark? byId(String id) => _manifest.byId(id);

  /// Loads the cached roster without touching the network, then — if this
  /// device has an approved account — refreshes from the server in the
  /// background. Safe to call repeatedly; only the first call does the local
  /// load.
  Future<void> load() async {
    if (_loaded) {
      unawaited(refreshFromServer());
      return;
    }
    _loaded = true;
    _loading = true;
    notifyListeners();

    try {
      final cached = await _readCache();
      if (cached != null) {
        _manifest = cached.manifest;
        _etag = cached.etag;
      }
    } catch (e) {
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }

    unawaited(refreshFromServer());
  }

  /// Asks the server for a newer roster. Does nothing at all unless this
  /// device holds an approved account.
  Future<void> refreshFromServer({bool force = false}) async {
    if (_refreshing) return;
    final sync = _sync;
    final baseUrl = sync?.serverUrl;
    if (sync == null || !sync.serverReady || baseUrl == null) return;

    _refreshing = true;
    _error = null;
    notifyListeners();

    final api = _apiFactory(baseUrl, sync.authToken);
    try {
      final result = await api.fetchManifest(knownEtag: force ? null : _etag);
      if (!result.unchanged && result.manifest != null) {
        _manifest = result.manifest!;
        _etag = result.etag;
        await _writeCache(result.manifest!, result.etag);
      }
      unawaited(warmPreviews());
    } on ServerAccessDeniedException {
      // The gate shut between the check above and the request. Nothing to
      // report: the cached roster is already on screen.
    } catch (e) {
      _error = '$e';
    } finally {
      _refreshing = false;
      api.close();
      notifyListeners();
    }
  }

  /// Downloads the PNG previews for the whole roster in the background, so the
  /// model cards show artwork instead of placeholder icons. Small files, cached
  /// once — the scene HTML itself still only downloads when opened.
  Future<void> warmPreviews() async {
    if (_previewsWarming || _manifest.isEmpty) return;
    final sync = _sync;
    final baseUrl = sync?.serverUrl;
    if (sync == null || !sync.serverReady || baseUrl == null) return;
    _previewsWarming = true;
    final api = _apiFactory(baseUrl, sync.authToken);
    try {
      final root = await _cacheRoot();
      for (final b in _manifest.benchmarks) {
        if (!b.hasPreview) continue;
        final file = File('${root.path}/previews/${b.id}.png');
        if (await file.exists()) continue;
        try {
          final bytes = await api.fetchPreview(b.id);
          if (bytes == null) continue;
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // One missing preview must not stop the rest.
        }
      }
      for (final fallback in _manifest.fallbackPreviews.values) {
        final file = File('${root.path}/fallbacks/$fallback');
        if (await file.exists()) continue;
        try {
          final bytes = await api.fetchFallback(fallback);
          if (bytes == null) continue;
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // Same: best effort only.
        }
      }
    } catch (_) {
      // Preview warming is cosmetic; failures stay silent.
    } finally {
      _previewsWarming = false;
      api.close();
      notifyListeners();
    }
  }

  /// The scene's HTML on disk, downloading and verifying it first when needed.
  ///
  /// Throws [StateError] when there is no approved account to fetch from, and
  /// [AiBenchmarkApiException] when the download fails or the bytes don't
  /// match the manifest's hash — the caller shows a retry, never a WebView
  /// pointed at half a file.
  Future<File> sceneFile(String id) async {
    final benchmark = byId(id);
    if (benchmark == null) {
      throw StateError('Unknown benchmark "$id".');
    }
    final root = await _cacheRoot();
    final file = File('${root.path}/scenes/$id.html');
    if (await _validScene(file, benchmark)) return file;

    final sync = _sync;
    final baseUrl = sync?.serverUrl;
    if (sync == null || !sync.serverReady || baseUrl == null) {
      throw StateError(
          'Sign in to an approved luma account to download this benchmark.');
    }
    final api = _apiFactory(baseUrl, sync.authToken);
    try {
      final bytes = await api.fetchScene(id);
      if (bytes.length != benchmark.sizeBytes ||
          sha256.convert(bytes).toString() != benchmark.sha256) {
        throw const AiBenchmarkApiException(
            200, 'The downloaded scene failed its integrity check.');
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      api.close();
    }
  }

  /// A scene's cached preview, or null when it hasn't downloaded yet (see
  /// [warmPreviews]). Synchronous so cards can read it during build.
  File? previewFile(String id) {
    final root = _rootPath;
    if (root == null) return null;
    final file = File('$root/previews/$id.png');
    return file.existsSync() ? file : null;
  }

  /// Generic tile artwork for a test kind, or null when not cached yet.
  File? fallbackFile(String kind) {
    final root = _rootPath;
    final name = _manifest.fallbackPreviews[kind];
    if (root == null || name == null) return null;
    final file = File('$root/fallbacks/$name');
    return file.existsSync() ? file : null;
  }

  // ---- Local storage ------------------------------------------------------

  Future<Directory> _cacheRoot() async {
    final support = await _cacheDirProvider();
    final root = Directory(
        '${support.path}${Platform.pathSeparator}$kAiBenchmarkCacheDir');
    await root.create(recursive: true);
    _rootPath = root.path;
    return root;
  }

  Future<bool> _validScene(File file, AiBenchmark benchmark) async {
    try {
      if (!await file.exists()) return false;
      if (await file.length() != benchmark.sizeBytes) return false;
      if (benchmark.sha256.isEmpty) return true;
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString() == benchmark.sha256;
    } catch (_) {
      return false;
    }
  }

  Future<({AiBenchmarkManifest manifest, String? etag})?> _readCache() async {
    try {
      final root = await _cacheRoot();
      final file = File('${root.path}/manifest.json');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final body = decoded['manifest'];
      if (body is! Map<String, dynamic>) return null;
      return (
        manifest: AiBenchmarkManifest.fromJson(body),
        etag: decoded['etag'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(AiBenchmarkManifest manifest, String? etag) async {
    try {
      final root = await _cacheRoot();
      await File('${root.path}/manifest.json').writeAsString(jsonEncode({
        'etag': etag,
        'manifest': {
          'refreshedAtMs': manifest.refreshedAt?.millisecondsSinceEpoch,
          'fallbackPreviews': manifest.fallbackPreviews,
          'benchmarks': [
            for (final b in manifest.benchmarks)
              {
                'id': b.id,
                'kind': b.kind,
                'model': b.model,
                'description': b.description,
                'sizeBytes': b.sizeBytes,
                'sha256': b.sha256,
                'updatedAtMs': b.updatedAt?.millisecondsSinceEpoch,
                'hasPreview': b.hasPreview,
              },
          ],
        },
      }));
    } catch (_) {
      // Cache is an optimisation. Failing to write it costs one download on
      // the next launch and nothing else.
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../../../../sync/server_access.dart';
import '../../../../../sync/sync_service.dart';
import 'ai_catalog_api.dart';
import 'ai_model.dart';

/// Where the catalogue in the app bundle lives. Regenerate it with
/// `tool/refresh_ai_catalog.dart` (see that script's header).
const String kAiCatalogAssetPath = 'assets/ai_models/catalog.json';

/// Directory under the app-support root the downloaded copy is cached in.
///
/// Listed in `StorageGuard._excludedDirNames`: it is a derived, re-fetchable
/// cache that is byte-identical for every user, and at a few hundred KB it
/// would otherwise eat a twentieth of a Core plan's 5 MB cap for data the
/// user never created.
const String kAiCatalogCacheDir = 'ai_catalog_cache';

/// Where the leaderboard the app is showing came from.
enum AiCatalogSource {
  /// The snapshot shipped inside the app — correct as of the release, and
  /// what a fresh install with no account shows.
  bundled,

  /// A copy downloaded from the luma server on an earlier launch.
  cached,

  /// Downloaded from the luma server during this session.
  server,
}

/// Owns the AI model leaderboard on the client.
///
/// The plugin is still the offline usage dashboard it always was, so the
/// leaderboard is built to work with no account at all: a snapshot ships in
/// the app bundle and is shown immediately. When the device has an approved
/// account the repository asks the luma server for a fresher copy in the
/// background and swaps it in, caching it so the next launch starts from the
/// newer data instead of the bundled one.
///
/// Nothing here sends anything: the only request made is a GET, and it is
/// only attempted once [SyncService.serverReady] is true.
class AiCatalogRepository extends ChangeNotifier {
  AiCatalogRepository(this._sync, {AiCatalogApi Function(String, String?)? apiFactory})
      : _apiFactory = apiFactory ??
            ((baseUrl, token) => AiCatalogApi(baseUrl, token: token));

  /// A repository over a catalogue that is already in hand, with no sync
  /// service behind it — nothing it does can reach the network. Used by tests,
  /// and the honest shape for any caller that has no account to refresh from.
  @visibleForTesting
  AiCatalogRepository.withCatalog(AiCatalog catalog)
      : _sync = null,
        _apiFactory = ((baseUrl, token) => AiCatalogApi(baseUrl)),
        _catalog = catalog,
        _loaded = true;

  final SyncService? _sync;
  final AiCatalogApi Function(String baseUrl, String? token) _apiFactory;

  AiCatalog _catalog = AiCatalog.empty;
  AiCatalogSource _source = AiCatalogSource.bundled;
  bool _loading = false;
  bool _refreshing = false;
  bool _loaded = false;
  String? _etag;
  String? _error;

  AiCatalog get catalog => _catalog;
  AiCatalogSource get source => _source;

  /// True while the first load (bundle or cache) is in flight — the page
  /// shows a spinner rather than an empty table.
  bool get loading => _loading;

  /// True while a server refresh is in flight behind an already-shown
  /// catalogue. Never blocks the UI.
  bool get refreshing => _refreshing;

  /// The last refresh failure, or null. Only ever a footnote in the UI: a
  /// stale leaderboard is still a leaderboard.
  String? get error => _error;

  DateTime? get refreshedAt => _catalog.refreshedAt;

  /// Whether a server refresh is even possible on this device right now.
  bool get canRefresh => _sync?.serverReady ?? false;

  /// Loads the best catalogue available without touching the network, then —
  /// if this device has an approved account — refreshes from the server in
  /// the background. Safe to call repeatedly; only the first call does the
  /// local load.
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
        _catalog = cached.catalog;
        _etag = cached.etag;
        _source = AiCatalogSource.cached;
      } else {
        _catalog = await _readBundled();
        _source = AiCatalogSource.bundled;
      }
    } catch (e) {
      // A broken cache or a missing asset must not take the tab down; the
      // server refresh below is still free to fill it in.
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }

    unawaited(refreshFromServer());
  }

  /// Asks the server for a newer catalogue. Does nothing at all unless this
  /// device holds an approved account — the gate, not this method, is what
  /// decides whether the app may talk to a luma server.
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
      final result = await api.fetch(knownEtag: force ? null : _etag);
      if (!result.unchanged && result.catalog != null) {
        _catalog = result.catalog!;
        _etag = result.etag;
        _source = AiCatalogSource.server;
        await _writeCache(result.catalog!, result.etag);
      } else if (result.unchanged) {
        _source = AiCatalogSource.server;
      }
    } on ServerAccessDeniedException {
      // The gate shut between the check above and the request. Nothing to
      // report: the bundled catalogue is already on screen.
    } catch (e) {
      _error = '$e';
    } finally {
      _refreshing = false;
      api.close();
      notifyListeners();
    }
  }

  AiModel? byId(String id) {
    for (final model in _catalog.models) {
      if (model.id == id) return model;
    }
    return null;
  }

  // ---- Local storage ------------------------------------------------------

  Future<AiCatalog> _readBundled() async {
    final raw = await rootBundle.loadString(kAiCatalogAssetPath);
    return AiCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<({AiCatalog catalog, String? etag})?> _readCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final body = decoded['catalog'];
      if (body is! Map<String, dynamic>) return null;
      return (
        catalog: AiCatalog.fromJson(body),
        etag: decoded['etag'] as String?,
      );
    } catch (_) {
      // Corrupt cache — fall through to the bundled snapshot.
      return null;
    }
  }

  Future<void> _writeCache(AiCatalog catalog, String? etag) async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'etag': etag,
        'catalog': {
          'refreshedAtMs': catalog.refreshedAt?.millisecondsSinceEpoch,
          'models': [for (final m in catalog.models) _modelToJson(m)],
          'news': [for (final n in catalog.news) _newsToJson(n)],
        },
      }));
    } catch (_) {
      // Cache is an optimisation. Failing to write it costs one download on
      // the next launch and nothing else.
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$kAiCatalogCacheDir'
        '${Platform.pathSeparator}catalog.json');
  }

  Map<String, dynamic> _modelToJson(AiModel m) => {
        'id': m.id,
        'slug': m.slug,
        'name': m.name,
        'vendor': m.vendor,
        'vendorName': m.vendorName,
        if (m.description != null) 'description': m.description,
        if (m.releasedAt != null)
          'releasedAtMs': m.releasedAt!.millisecondsSinceEpoch,
        if (m.contextTokens != null) 'contextTokens': m.contextTokens,
        if (m.maxOutputTokens != null) 'maxOutputTokens': m.maxOutputTokens,
        if (m.inputPricePerM != null) 'inputPricePerM': m.inputPricePerM,
        if (m.outputPricePerM != null) 'outputPricePerM': m.outputPricePerM,
        if (m.cacheReadPerM != null) 'cacheReadPerM': m.cacheReadPerM,
        if (m.cacheWritePerM != null) 'cacheWritePerM': m.cacheWritePerM,
        if (m.llmStatsIndex != null) 'llmStatsIndex': m.llmStatsIndex,
        if (m.reasoningIndex != null) 'reasoningIndex': m.reasoningIndex,
        if (m.codingIndex != null) 'codingIndex': m.codingIndex,
        if (m.agentIndex != null) 'agentIndex': m.agentIndex,
        if (m.mathIndex != null) 'mathIndex': m.mathIndex,
        if (m.codeArena != null) 'codeArena': m.codeArena,
        if (m.codeArenaRank != null) 'codeArenaRank': m.codeArenaRank,
        if (m.speedTokensPerSec != null)
          'speedTokensPerSec': m.speedTokensPerSec,
        if (m.latencyMs != null) 'latencyMs': m.latencyMs,
        'openWeights': m.openWeights,
        if (m.licenseId != null) 'licenseId': m.licenseId,
        if (m.licenseName != null) 'licenseName': m.licenseName,
        if (m.parametersB != null) 'parametersB': m.parametersB,
        if (m.activeParametersB != null)
          'activeParametersB': m.activeParametersB,
        if (m.huggingFaceId != null) 'huggingFaceId': m.huggingFaceId,
        if (m.inputModalities.isNotEmpty) 'inputModalities': m.inputModalities,
        if (m.outputModalities.isNotEmpty)
          'outputModalities': m.outputModalities,
        if (m.knowledgeCutoff != null) 'knowledgeCutoff': m.knowledgeCutoff,
        if (m.supportedEfforts.isNotEmpty)
          'supportedEfforts': m.supportedEfforts,
        if (m.defaultEffort != null) 'defaultEffort': m.defaultEffort,
        if (m.effortProfiles.isNotEmpty)
          'effortProfiles': [
            for (final e in m.effortProfiles)
              {
                'effort': e.effort,
                if (e.intelligenceIndex != null)
                  'intelligenceIndex': e.intelligenceIndex,
                if (e.medianOutputTokens != null)
                  'medianOutputTokens': e.medianOutputTokens,
              },
          ],
      };

  Map<String, dynamic> _newsToJson(AiNewsItem n) => {
        'id': n.id,
        'title': n.title,
        'url': n.url,
        'source': n.source,
        'publishedAtMs': n.publishedAt?.millisecondsSinceEpoch ?? 0,
        if (n.summary != null) 'summary': n.summary,
      };
}

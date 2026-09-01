import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'mc_api.dart';
import 'mc_credentials.dart';
import 'mc_history.dart';
import 'mc_models.dart';
import 'pmc_extract.dart';

/// Loads a member's Planet Minecraft pages through an embedded browser.
///
/// Supplied by the UI (see `PmcWebViewFetcher`) because only a widget can own
/// a browser engine; the repository just awaits it like any other request.
typedef PmcPageFetcher = Future<List<PmcPage>> Function(
  String member, {
  int maxPages,
});

/// Owns the MC Content state: the three platforms, their combined library,
/// and the locally-grown download history behind the trend graphs.
///
/// A separate repository from [AccountOverviewRepository] rather than a
/// bigger one — the two services refresh independently, fail independently
/// and are credentialed independently, exactly like Steam Tools keeps its
/// price tracker and CS2 market apart.
class McContentRepository extends ChangeNotifier {
  McContentRepository({ModrinthApi? modrinth, CurseForgeApi? curseforge})
      : _modrinth = modrinth ?? ModrinthApi(),
        _curseforge = curseforge ?? CurseForgeApi();

  final ModrinthApi _modrinth;
  final CurseForgeApi _curseforge;

  McCredentials _credentials = const McCredentials();
  McCredentials get credentials => _credentials;

  McSnapshot _snapshot = McSnapshot.empty;
  McSnapshot get snapshot => _snapshot;

  McHistoryStore _history = McHistoryStore.inMemory();
  McHistoryStore get history => _history;

  PmcPageFetcher? _pmcFetcher;

  /// True once a browser engine has offered itself for PMC scraping.
  bool get pmcFetcherReady => _pmcFetcher != null;

  bool _loadStarted = false;
  bool _loaded = false;
  bool get loaded => _loaded;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  McPlatform? _stage;

  /// Which platform is being fetched right now, for the progress strip.
  McPlatform? get stage => _stage;

  String? _error;
  String? get error => _error;

  bool _disposed = false;
  File? _cacheFile;

  /// True when nothing at all has been configured yet.
  bool get configured => _credentials.hasAny;

  Future<File> _cache() async {
    if (_cacheFile != null) return _cacheFile!;
    final dir = await getApplicationSupportDirectory();
    return _cacheFile =
        File('${dir.path}${Platform.pathSeparator}luma_mc_snapshot.json');
  }

  /// Registers (or clears) the browser-backed PMC fetcher.
  void attachPmcFetcher(PmcPageFetcher? fetcher) {
    _pmcFetcher = fetcher;
    _notify();
  }

  Future<void> load() async {
    if (_loadStarted) return;
    _loadStarted = true;

    try {
      final store = await McCredentialStore.load();
      _credentials = await store.read() ?? const McCredentials();
    } catch (_) {
      _credentials = const McCredentials();
    }

    _history = await McHistoryStore.load();

    try {
      final file = await _cache();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          _snapshot =
              McSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
    } catch (_) {
      _snapshot = McSnapshot.empty;
    }

    _loaded = true;
    _notify();

    if (configured && _isStale) unawaitedRefresh();
  }

  /// Download counters move slowly; an hour-old snapshot is fine to open
  /// with, and refreshing more often would only add rate-limit pressure.
  bool get _isStale =>
      DateTime.now().difference(_snapshot.fetchedAt) > const Duration(hours: 1);

  void unawaitedRefresh() {
    refresh().catchError((_) {});
  }

  Future<void> saveCredentials(McCredentials credentials) async {
    final store = await McCredentialStore.load();
    await store.save(credentials);
    final previous = _credentials;
    _credentials = credentials;

    // Dropping a platform must drop its history too, or a later combined
    // chart would silently include an account that is no longer connected.
    for (final platform in McPlatform.values) {
      if (_configuredFor(previous, platform) &&
          !_configuredFor(credentials, platform)) {
        _history.forget(platform.id);
        _history.forgetWithPrefix('project:${platform.id}:');
        _snapshot = _snapshot.withResult(McPlatformResult(
          platform: platform,
          state: McPlatformState.notConfigured,
        ));
      }
    }
    await _history.persist();

    _notify();
    await refresh();
  }

  static bool _configuredFor(McCredentials c, McPlatform platform) =>
      switch (platform) {
        McPlatform.curseforge => c.hasCurseforge,
        McPlatform.modrinth => c.hasModrinth,
        McPlatform.planetMinecraft => c.hasPmc,
      };

  /// Adds a CurseForge project to the hand-picked list, resolving a URL or
  /// slug to its numeric id first.
  Future<McProject> trackCurseforgeProject(String input) async {
    final apiKey = _credentials.curseforgeApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw McApiException('Add your CurseForge API key first.');
    }
    final slug = CurseForgeApi.slugFromInput(input);
    if (slug == null) {
      throw McApiException(
        'That does not look like a CurseForge project URL or slug.',
      );
    }
    final project = await _curseforge.findBySlug(apiKey, slug);
    if (project == null) {
      throw McApiException('CurseForge has no project called "$slug".');
    }
    if (_credentials.curseforgeProjectIds.contains(project.id)) {
      return project;
    }
    await saveCredentials(_credentials.copyWith(
      curseforgeProjectIds: [..._credentials.curseforgeProjectIds, project.id],
    ));
    return project;
  }

  Future<void> untrackCurseforgeProject(String id) async {
    if (!_credentials.curseforgeProjectIds.contains(id)) return;
    _history.forget('project:${McPlatform.curseforge.id}:$id');
    await saveCredentials(_credentials.copyWith(
      curseforgeProjectIds: [
        for (final existing in _credentials.curseforgeProjectIds)
          if (existing != id) existing,
      ],
    ));
  }

  Future<void> disconnect() async {
    try {
      final store = await McCredentialStore.load();
      await store.clear();
    } catch (_) {}
    try {
      final file = await _cache();
      if (await file.exists()) await file.delete();
    } catch (_) {}
    for (final platform in McPlatform.values) {
      _history.forget(platform.id);
      _history.forgetWithPrefix('project:${platform.id}:');
    }
    await _history.persist();
    _credentials = const McCredentials();
    _snapshot = McSnapshot.empty;
    _error = null;
    _notify();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  // ---- refreshing -----------------------------------------------------------

  /// Refreshes every configured platform.
  ///
  /// Each one is independent: a bad CurseForge key must not cost the user
  /// their Modrinth numbers, so a failure is recorded against that platform
  /// and the others carry on.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _error = null;
    _notify();

    try {
      for (final platform in McPlatform.values) {
        _stage = platform;
        _notify();
        final result = await _fetchPlatform(platform);
        _snapshot = _snapshot.withResult(result);
        _recordHistory(result);
        _notify();
      }

      await _backfillModrinth();

      _snapshot = _snapshot.withFetchedAt(DateTime.now());
      await _history.persist();
      await _persist();
    } catch (e) {
      _error = e.toString();
    } finally {
      _refreshing = false;
      _stage = null;
      _notify();
    }
  }

  Future<McPlatformResult> _fetchPlatform(McPlatform platform) async {
    if (!_configuredFor(_credentials, platform)) {
      return McPlatformResult(
        platform: platform,
        state: McPlatformState.notConfigured,
        message: switch (platform) {
          McPlatform.curseforge => _credentials.curseforgeNeedsTarget
              ? 'Add your CurseForge author id, or track projects individually.'
              : 'Add a CurseForge API key to include it.',
          McPlatform.modrinth => 'Add your Modrinth username to include it.',
          McPlatform.planetMinecraft =>
            'Add your Planet Minecraft username to include it.',
        },
      );
    }

    try {
      return switch (platform) {
        McPlatform.modrinth => await _fetchModrinth(),
        McPlatform.curseforge => await _fetchCurseforge(),
        McPlatform.planetMinecraft => await _fetchPmc(),
      };
    } catch (e) {
      // Keep whatever was last known rather than blanking the platform: a
      // stale number with a warning beats an empty card.
      final previous = _snapshot.resultFor(platform);
      return previous.copyWith(
        state: McPlatformState.failed,
        message: e is McApiException ? e.message : e.toString(),
      );
    }
  }

  Future<McPlatformResult> _fetchModrinth() async {
    final username = _credentials.modrinthUsername!;
    final result = await _modrinth.fetchCreator(
      username,
      token: _credentials.modrinthToken,
    );
    return McPlatformResult(
      platform: McPlatform.modrinth,
      state: McPlatformState.ok,
      creator: result.creator,
      projects: result.projects,
      fetchedAt: DateTime.now(),
    );
  }

  Future<McPlatformResult> _fetchCurseforge() async {
    final apiKey = _credentials.curseforgeApiKey!;
    final projects = <McProject>[];

    final authorId = _credentials.curseforgeAuthorId;
    if (authorId != null && authorId.isNotEmpty) {
      projects.addAll(await _curseforge.fetchAuthorProjects(apiKey, authorId));
    }
    if (_credentials.curseforgeProjectIds.isNotEmpty) {
      final seen = projects.map((p) => p.id).toSet();
      final extra = await _curseforge.fetchProjectsByIds(
        apiKey,
        [
          for (final id in _credentials.curseforgeProjectIds)
            if (!seen.contains(id)) id,
        ],
      );
      projects.addAll(extra);
    }
    projects.sort((a, b) => b.downloads.compareTo(a.downloads));

    return McPlatformResult(
      platform: McPlatform.curseforge,
      state: McPlatformState.ok,
      creator: McCreator(
        platform: McPlatform.curseforge,
        handle: authorId ?? 'tracked projects',
        url: authorId == null
            ? null
            : 'https://www.curseforge.com/members/$authorId/projects',
      ),
      projects: projects,
      fetchedAt: DateTime.now(),
    );
  }

  Future<McPlatformResult> _fetchPmc() async {
    final member = _credentials.pmcUsername!;
    final fetcher = _pmcFetcher;
    if (fetcher == null) {
      throw McApiException(
        'Planet Minecraft needs an embedded browser, which is not available '
        'on this platform.',
      );
    }

    final pages = await fetcher(member, maxPages: 4);
    final projects = [for (final page in pages) ...page.projects];
    projects.sort((a, b) => b.views.compareTo(a.views));

    final menu = pages.isEmpty ? const <String, int>{} : pages.first.menuCounts;

    return McPlatformResult(
      platform: McPlatform.planetMinecraft,
      state: McPlatformState.ok,
      creator: McCreator(
        platform: McPlatform.planetMinecraft,
        handle: member,
        url: 'https://www.planetminecraft.com/member/$member/',
        followers: menu['subscribers'] ?? 0,
      ),
      projects: projects,
      fetchedAt: DateTime.now(),
    );
  }

  /// Writes today's totals into the trend store.
  void _recordHistory(McPlatformResult result) {
    if (result.state != McPlatformState.ok) return;

    _history.record(
      result.platform.id,
      downloads: result.downloads,
      followers: result.followers,
      views: result.views,
    );
    for (final project in result.projects) {
      _history.record(
        project.historyKey,
        downloads: project.downloads,
        followers: project.followers,
        views: project.views,
      );
    }
  }

  /// Seeds the Modrinth series with real history from its analytics endpoint.
  ///
  /// Everything else has to grow its own graph day by day, because no API on
  /// CurseForge or PMC will say what yesterday's total was. Modrinth is the
  /// one platform that can answer, so when a token is present its chart
  /// starts full instead of empty.
  Future<void> _backfillModrinth() async {
    final token = _credentials.modrinthToken;
    if (token == null || token.isEmpty) return;

    final result = _snapshot.resultFor(McPlatform.modrinth);
    if (result.state != McPlatformState.ok || result.projects.isEmpty) return;

    final byId = {for (final p in result.projects) p.id: p};
    final gains = await _modrinth.fetchDownloadHistory(
      byId.keys.toList(),
      token: token,
    );
    if (gains.isEmpty) return;

    final combined = <DateTime, int>{};
    for (final entry in gains.entries) {
      final project = byId[entry.key];
      if (project == null) continue;
      _history.backfillFromGains(
        project.historyKey,
        entry.value,
        currentTotal: project.downloads,
      );
      for (final day in entry.value.entries) {
        combined[day.key] = (combined[day.key] ?? 0) + day.value;
      }
    }
    _history.backfillFromGains(
      McPlatform.modrinth.id,
      combined,
      currentTotal: result.downloads,
    );
  }

  Future<void> _persist() async {
    try {
      final file = await _cache();
      await file.writeAsString(jsonEncode(_snapshot.toJson()), flush: true);
    } catch (_) {}
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Puts the repository into a populated state without touching disk or the
  /// network, for widget tests. Nothing in the app calls it.
  @visibleForTesting
  void seedForTest(
    McSnapshot snapshot, {
    McCredentials? credentials,
    McHistoryStore? history,
  }) {
    _credentials = credentials ?? const McCredentials(modrinthUsername: 'octo');
    _snapshot = snapshot;
    if (history != null) _history = history;
    _loadStarted = true;
    _loaded = true;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _modrinth.dispose();
    _curseforge.dispose();
    super.dispose();
  }
}

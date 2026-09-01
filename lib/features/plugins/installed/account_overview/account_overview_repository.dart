import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'github_api.dart';
import 'github_credentials.dart';
import 'github_models.dart';

/// Which part of a refresh is running, so the UI can say something more
/// useful than "loading".
enum GithubLoadStage {
  idle('Idle'),
  profile('Reading your profile'),
  repos('Listing repositories'),
  contributions('Counting contributions'),
  downloads('Adding up release downloads'),
  issues('Collecting issues and pull requests'),
  actions('Fetching workflow runs'),
  billing('Reading usage and allowances');

  const GithubLoadStage(this.label);
  final String label;
}

/// Owns the GitHub account state for the Account Overview plugin.
///
/// A [ChangeNotifier] rather than the drift-stream shape most plugins use:
/// there is no local database here worth watching. Everything is a snapshot
/// of a remote account, cached to one JSON file so reopening the plugin
/// paints immediately and only then refreshes in the background.
class AccountOverviewRepository extends ChangeNotifier {
  AccountOverviewRepository({GithubApi? api}) : _api = api ?? GithubApi();

  final GithubApi _api;

  GithubCredentials? _credentials;
  GithubCredentials? get credentials => _credentials;
  bool get connected => _credentials?.isComplete ?? false;

  GithubSnapshot _snapshot = GithubSnapshot.empty;
  GithubSnapshot get snapshot => _snapshot;

  bool _loadStarted = false;
  bool _loaded = false;

  /// True once the cached snapshot and stored token have been read off disk.
  /// Widgets show a spinner until this flips, so that a connected account
  /// never flashes the "connect" screen on the way in — which is why it is
  /// set after the reads finish, not when they start.
  bool get loaded => _loaded;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  GithubLoadStage _stage = GithubLoadStage.idle;
  GithubLoadStage get stage => _stage;

  String? _error;
  String? get error => _error;

  /// Non-fatal problems from the last refresh — a missing scope for one
  /// section, say — kept apart from [error] so a partial success still
  /// paints the parts that did work.
  final List<String> _warnings = [];
  List<String> get warnings => List.unmodifiable(_warnings);

  bool _disposed = false;

  File? _cacheFile;

  Future<File> _cache() async {
    if (_cacheFile != null) return _cacheFile!;
    final dir = await getApplicationSupportDirectory();
    return _cacheFile =
        File('${dir.path}${Platform.pathSeparator}luma_github_snapshot.json');
  }

  /// Reads the token and the cached snapshot, then refreshes if the cache is
  /// stale. Safe to call from every `didChangeDependencies`.
  Future<void> load() async {
    if (_loadStarted) return;
    _loadStarted = true;

    try {
      final store = await GithubCredentialStore.load();
      _credentials = await store.read();
    } catch (_) {
      _credentials = null;
    }

    try {
      final file = await _cache();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          _snapshot =
              GithubSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
    } catch (_) {
      _snapshot = GithubSnapshot.empty;
    }

    _loaded = true;
    _notify();

    if (connected && _isStale) unawaitedRefresh();
  }

  /// GitHub's numbers move slowly and its rate limit does not, so a
  /// fifteen-minute-old snapshot is good enough to open with.
  bool get _isStale =>
      DateTime.now().difference(_snapshot.fetchedAt) >
      const Duration(minutes: 15);

  void unawaitedRefresh() {
    refresh().catchError((_) {});
  }

  // ---- connecting -----------------------------------------------------------

  /// Validates a token against `/user` and stores it on success.
  ///
  /// Nothing is written until GitHub has confirmed the token, so a typo
  /// never leaves a broken credential behind for the next launch to trip on.
  Future<void> connect(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw GithubApiException('Paste a personal access token first.');
    }

    _error = null;
    _refreshing = true;
    _stage = GithubLoadStage.profile;
    _notify();

    try {
      final profile = await _api.fetchProfile(trimmed);
      final store = await GithubCredentialStore.load();
      final credentials =
          GithubCredentials(token: trimmed, login: profile.login);
      await store.save(credentials);
      _credentials = credentials;
      _snapshot = GithubSnapshot(
        profile: profile,
        repos: const [],
        contributions: GithubContributions.empty,
        issues: const [],
        issueTotals: GithubIssueTotals.empty,
        runs: const [],
        billing: GithubBilling.empty,
        fetchedAt: DateTime.now(),
      );
      _notify();
    } finally {
      _refreshing = false;
      _stage = GithubLoadStage.idle;
      _notify();
    }

    await refresh();
  }

  /// Forgets the token and every cached number that came with it.
  Future<void> disconnect() async {
    try {
      final store = await GithubCredentialStore.load();
      await store.clear();
    } catch (_) {}
    try {
      final file = await _cache();
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _credentials = null;
    _snapshot = GithubSnapshot.empty;
    _error = null;
    _warnings.clear();
    _notify();
  }

  /// Records the allowances GitHub will not report, so the usage meters have
  /// a denominator. Passing null for one clears it.
  Future<void> saveAllowances({
    double? copilot,
    double? storageGb,
    double? minutes,
  }) async {
    final current = _credentials;
    if (current == null) return;
    final updated = GithubCredentials(
      token: current.token,
      login: current.login,
      copilotAllowance: copilot,
      storageAllowanceGb: storageGb,
      minutesAllowance: minutes,
    );
    final store = await GithubCredentialStore.load();
    await store.save(updated);
    _credentials = updated;
    _notify();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  /// Puts the repository straight into the connected state with a given
  /// snapshot, touching neither disk nor network.
  ///
  /// Widget tests need a populated page, and the real path there runs
  /// through the credential store, which needs path_provider. Nothing in the
  /// app calls this.
  @visibleForTesting
  void seedForTest(GithubSnapshot snapshot, {GithubCredentials? credentials}) {
    _credentials = credentials ??
        const GithubCredentials(token: 'test-token', login: 'octo');
    _snapshot = snapshot;
    _loadStarted = true;
    _loaded = true;
    _notify();
  }

  // ---- refreshing -----------------------------------------------------------

  /// Rebuilds the whole snapshot.
  ///
  /// Sections are fetched in dependency order but failures are contained:
  /// only the profile and repository list are load-bearing, and everything
  /// after them degrades into a warning so one missing scope cannot blank
  /// the page.
  Future<void> refresh() async {
    final credentials = _credentials;
    if (credentials == null || _refreshing) return;

    _refreshing = true;
    _error = null;
    _warnings.clear();
    _stage = GithubLoadStage.profile;
    _notify();

    final token = credentials.token;
    final login = credentials.login;

    try {
      final profile = await _api.fetchProfile(token);
      _publish(_snapshot.copyWith(profile: profile));

      _setStage(GithubLoadStage.repos);
      var repos = await _api.fetchRepos(token);
      _publish(_snapshot.copyWith(profile: profile, repos: repos));

      _setStage(GithubLoadStage.contributions);
      var contributions = _snapshot.contributions;
      try {
        contributions = await _api.fetchContributions(token, login);
        _publish(_snapshot.copyWith(contributions: contributions));
      } catch (e) {
        _warn('Contribution graph unavailable: ${_describe(e)}');
      }

      _setStage(GithubLoadStage.downloads);
      try {
        repos = await _api.fetchDownloads(token, repos);
        _publish(_snapshot.copyWith(repos: repos));
      } catch (e) {
        _warn('Release downloads unavailable: ${_describe(e)}');
      }

      _setStage(GithubLoadStage.issues);
      try {
        final totals = await _api.fetchIssueTotals(token, login);
        final issues = await _api.fetchRecentIssues(token, login);
        _publish(_snapshot.copyWith(issueTotals: totals, issues: issues));
      } catch (e) {
        _warn('Issues and pull requests unavailable: ${_describe(e)}');
      }

      _setStage(GithubLoadStage.actions);
      try {
        final runs = await _api.fetchWorkflowRuns(token, repos);
        _publish(_snapshot.copyWith(runs: runs));
      } catch (e) {
        _warn('Workflow runs unavailable: ${_describe(e)}');
      }

      _setStage(GithubLoadStage.billing);
      try {
        final billing = await _api.fetchBilling(token, login);
        _publish(_snapshot.copyWith(billing: billing));
      } catch (e) {
        _warn('Usage and allowances unavailable: ${_describe(e)}');
      }

      _publish(_snapshot.copyWith(fetchedAt: DateTime.now()));
      await _persist();
    } catch (e) {
      _error = _describe(e);
    } finally {
      _refreshing = false;
      _stage = GithubLoadStage.idle;
      _notify();
    }
  }

  String _describe(Object error) =>
      error is GithubApiException ? error.message : error.toString();

  void _warn(String message) {
    _warnings.add(message);
    _notify();
  }

  void _setStage(GithubLoadStage stage) {
    _stage = stage;
    _notify();
  }

  void _publish(GithubSnapshot snapshot) {
    _snapshot = snapshot;
    _notify();
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

  @override
  void dispose() {
    _disposed = true;
    _api.dispose();
    super.dispose();
  }
}

/// Field-wise replacement for [GithubSnapshot], kept next to the repository
/// because incremental publishing is the only thing that needs it.
extension on GithubSnapshot {
  GithubSnapshot copyWith({
    GithubProfile? profile,
    List<GithubRepo>? repos,
    GithubContributions? contributions,
    List<GithubIssue>? issues,
    GithubIssueTotals? issueTotals,
    List<GithubWorkflowRun>? runs,
    GithubBilling? billing,
    DateTime? fetchedAt,
  }) =>
      GithubSnapshot(
        profile: profile ?? this.profile,
        repos: repos ?? this.repos,
        contributions: contributions ?? this.contributions,
        issues: issues ?? this.issues,
        issueTotals: issueTotals ?? this.issueTotals,
        runs: runs ?? this.runs,
        billing: billing ?? this.billing,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
}

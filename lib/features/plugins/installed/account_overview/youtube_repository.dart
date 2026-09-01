import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'youtube_api.dart';
import 'youtube_credentials.dart';
import 'youtube_models.dart';
import 'youtube_oauth.dart';

/// Which part of a refresh is running, so the UI can say something more
/// useful than "loading".
enum YoutubeLoadStage {
  idle('Idle'),
  channel('Reading your channel'),
  videos('Listing recent videos'),
  analytics('Fetching analytics');

  const YoutubeLoadStage(this.label);
  final String label;
}

/// Owns the YouTube account state for the Account Overview plugin.
///
/// A separate repository from [AccountOverviewRepository] and
/// [McContentRepository] rather than folded into either — YouTube carries its
/// own OAuth credential and its own token refresh, and fails independently
/// of GitHub's PAT and Minecraft's per-platform keys.
class YoutubeRepository extends ChangeNotifier {
  YoutubeRepository({YoutubeApi? api, YoutubeOAuth? oauth})
      : _api = api ?? YoutubeApi(),
        _oauth = oauth ?? YoutubeOAuth();

  final YoutubeApi _api;
  final YoutubeOAuth _oauth;

  YoutubeCredentials? _credentials;
  YoutubeCredentials? get credentials => _credentials;
  bool get connected => _credentials?.isComplete ?? false;

  YoutubeSnapshot _snapshot = YoutubeSnapshot.empty;
  YoutubeSnapshot get snapshot => _snapshot;

  bool _loadStarted = false;
  bool _loaded = false;

  /// True once the cached snapshot and stored credentials have been read off
  /// disk. Widgets show a spinner until this flips, so a connected channel
  /// never flashes the "connect" screen on the way in.
  bool get loaded => _loaded;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  YoutubeLoadStage _stage = YoutubeLoadStage.idle;
  YoutubeLoadStage get stage => _stage;

  String? _error;
  String? get error => _error;

  /// Non-fatal problems from the last refresh — analytics unavailable while
  /// the channel loaded fine, say — kept apart from [error] so a partial
  /// success still paints the parts that did work.
  final List<String> _warnings = [];
  List<String> get warnings => List.unmodifiable(_warnings);

  bool _disposed = false;
  File? _cacheFile;

  Future<File> _cache() async {
    if (_cacheFile != null) return _cacheFile!;
    final dir = await getApplicationSupportDirectory();
    return _cacheFile = File(
        '${dir.path}${Platform.pathSeparator}luma_youtube_snapshot.json');
  }

  /// Reads the stored credentials and the cached snapshot, then refreshes if
  /// the cache is stale. Safe to call from every `didChangeDependencies`.
  Future<void> load() async {
    if (_loadStarted) return;
    _loadStarted = true;

    try {
      final store = await YoutubeCredentialStore.load();
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
              YoutubeSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
    } catch (_) {
      _snapshot = YoutubeSnapshot.empty;
    }

    _loaded = true;
    _notify();

    if (connected && _isStale) unawaitedRefresh();
  }

  bool get _isStale =>
      DateTime.now().difference(_snapshot.fetchedAt) >
      const Duration(minutes: 15);

  void unawaitedRefresh() {
    refresh().catchError((_) {});
  }

  // ---- connecting -----------------------------------------------------------

  /// Runs the OAuth flow against the user's own Google Cloud client, then
  /// stores the resulting tokens and does a first refresh.
  Future<void> connect(String clientId, String clientSecret) async {
    final id = clientId.trim();
    final secret = clientSecret.trim();
    if (id.isEmpty || secret.isEmpty) {
      throw YoutubeOAuthException(
          'Enter both the Client ID and Client Secret first.');
    }

    _error = null;
    _refreshing = true;
    _stage = YoutubeLoadStage.channel;
    _notify();

    try {
      final tokens = await _oauth.authorize(clientId: id, clientSecret: secret);
      final channel = await _api.fetchChannel(tokens.accessToken);

      final credentials = YoutubeCredentials(
        clientId: id,
        clientSecret: secret,
        accessToken: tokens.accessToken,
        // `authorize` always requires a refresh token to succeed.
        refreshToken: tokens.refreshToken!,
        expiresAt: tokens.expiresAt,
        channelId: channel.id,
        channelTitle: channel.title,
      );
      final store = await YoutubeCredentialStore.load();
      await store.save(credentials);
      _credentials = credentials;
      _snapshot = YoutubeSnapshot(
        channel: channel,
        videos: const [],
        analytics: YoutubeAnalyticsSnapshot.empty,
        fetchedAt: DateTime.now(),
      );
      _notify();
    } finally {
      _refreshing = false;
      _stage = YoutubeLoadStage.idle;
      _notify();
    }

    await refresh();
  }

  /// Forgets the credentials and every cached number that came with them.
  Future<void> disconnect() async {
    final token = _credentials?.accessToken;
    if (token != null) await _oauth.revoke(token);
    try {
      final store = await YoutubeCredentialStore.load();
      await store.clear();
    } catch (_) {}
    try {
      final file = await _cache();
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _credentials = null;
    _snapshot = YoutubeSnapshot.empty;
    _error = null;
    _warnings.clear();
    _notify();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  /// Puts the repository straight into the connected state with a given
  /// snapshot, touching neither disk nor network. Nothing in the app calls
  /// this — it exists for widget tests, the same as
  /// `AccountOverviewRepository.seedForTest`.
  @visibleForTesting
  void seedForTest(YoutubeSnapshot snapshot, {YoutubeCredentials? credentials}) {
    _credentials = credentials ??
        YoutubeCredentials(
          clientId: 'test-client',
          clientSecret: 'test-secret',
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          channelId: 'UCtest',
          channelTitle: 'Test Channel',
        );
    _snapshot = snapshot;
    _loadStarted = true;
    _loaded = true;
    _notify();
  }

  // ---- refreshing -----------------------------------------------------------

  /// A valid access token, refreshing it first if it has expired.
  Future<String> _accessToken() async {
    final credentials = _credentials;
    if (credentials == null) {
      throw YoutubeOAuthException('YouTube is not connected.');
    }
    if (!credentials.isExpired) return credentials.accessToken;

    final tokens = await _oauth.refresh(
      clientId: credentials.clientId,
      clientSecret: credentials.clientSecret,
      refreshToken: credentials.refreshToken,
    );
    final updated = credentials.copyWith(
      accessToken: tokens.accessToken,
      expiresAt: tokens.expiresAt,
    );
    final store = await YoutubeCredentialStore.load();
    await store.save(updated);
    _credentials = updated;
    return updated.accessToken;
  }

  /// Runs [body] with a fresh access token, retrying exactly once if Google
  /// rejects the token mid-flight (e.g. revoked from Google's side after
  /// this repository last refreshed it).
  Future<T> _withToken<T>(Future<T> Function(String token) body) async {
    final token = await _accessToken();
    try {
      return await body(token);
    } on YoutubeApiException catch (e) {
      if (!e.needsReauth) rethrow;
      final refreshed = await _accessToken();
      return body(refreshed);
    }
  }

  /// Rebuilds the whole snapshot.
  ///
  /// The channel is load-bearing; recent videos and analytics degrade into a
  /// warning so a channel with Analytics not yet available (a brand-new
  /// channel, say) still shows what it can.
  Future<void> refresh() async {
    final credentials = _credentials;
    if (credentials == null || _refreshing) return;

    _refreshing = true;
    _error = null;
    _warnings.clear();
    _stage = YoutubeLoadStage.channel;
    _notify();

    try {
      final channel = await _withToken(_api.fetchChannel);
      _publish(_snapshot.copyWith(channel: channel));

      _setStage(YoutubeLoadStage.videos);
      try {
        final uploadsId = channel.uploadsPlaylistId;
        if (uploadsId != null) {
          final videos =
              await _withToken((token) => _api.fetchRecentVideos(token, uploadsId));
          _publish(_snapshot.copyWith(videos: videos));
        }
      } catch (e) {
        _warn('Recent videos unavailable: ${_describe(e)}');
      }

      _setStage(YoutubeLoadStage.analytics);
      try {
        final points = await _withToken(_api.fetchAnalyticsTimeSeries);
        final sources = await _withToken(_api.fetchTrafficSources);
        _publish(_snapshot.copyWith(
          analytics:
              YoutubeAnalyticsSnapshot(points: points, trafficSources: sources),
        ));
      } catch (e) {
        _warn('Analytics unavailable: ${_describe(e)}');
      }

      _publish(_snapshot.copyWith(fetchedAt: DateTime.now()));
      await _persist();
    } catch (e) {
      _error = _describe(e);
    } finally {
      _refreshing = false;
      _stage = YoutubeLoadStage.idle;
      _notify();
    }
  }

  String _describe(Object error) => switch (error) {
        YoutubeApiException() => error.message,
        YoutubeOAuthException() => error.message,
        _ => error.toString(),
      };

  void _warn(String message) {
    _warnings.add(message);
    _notify();
  }

  void _setStage(YoutubeLoadStage stage) {
    _stage = stage;
    _notify();
  }

  void _publish(YoutubeSnapshot snapshot) {
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
    _oauth.dispose();
    super.dispose();
  }
}

/// Field-wise replacement for [YoutubeSnapshot], kept next to the repository
/// because incremental publishing is the only thing that needs it.
extension on YoutubeSnapshot {
  YoutubeSnapshot copyWith({
    YoutubeChannelSnapshot? channel,
    List<YoutubeVideoStat>? videos,
    YoutubeAnalyticsSnapshot? analytics,
    DateTime? fetchedAt,
  }) =>
      YoutubeSnapshot(
        channel: channel ?? this.channel,
        videos: videos ?? this.videos,
        analytics: analytics ?? this.analytics,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
}

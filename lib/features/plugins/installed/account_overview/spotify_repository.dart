import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../l10n/current_l.dart';
import '../../../../security/secure_secret_store.dart';
import 'spotify_api.dart';
import 'spotify_models.dart';
import 'spotify_oauth.dart';

class SpotifyCredentials {
  const SpotifyCredentials({
    required this.clientId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.displayName,
    this.accountId,
  });

  final String clientId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String displayName;
  final String? accountId;

  bool get expired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'displayName': displayName,
    'accountId': accountId,
  };

  factory SpotifyCredentials.fromJson(Map<String, dynamic> json) =>
      SpotifyCredentials(
        clientId: json['clientId'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        displayName: json['displayName'] as String? ?? '',
        accountId: json['accountId'] as String?,
      );
}

class SpotifyRepository extends ChangeNotifier {
  SpotifyRepository({
    SpotifyApi? api,
    SpotifyOAuth? oauth,
    SecureSecretStore? secrets,
  }) : _api = api ?? SpotifyApi(),
       _oauth = oauth ?? SpotifyOAuth(),
       _secrets = secrets ?? SecureSecretStore.instance;

  static const _storageKey = 'account_overview.spotify';
  static String _minutesKey(String accountId) =>
      'account_overview.spotify.minutes.$accountId';
  final SpotifyApi _api;
  final SpotifyOAuth _oauth;
  final SecureSecretStore _secrets;

  SpotifyCredentials? _credentials;
  SpotifyCredentials? get credentials => _credentials;
  bool get connected => _credentials != null;
  SpotifySnapshot? _snapshot;
  SpotifySnapshot? get snapshot => _snapshot;
  bool _loaded = false;
  bool get loaded => _loaded;
  bool _loading = false;
  bool get loading => _loading;
  String? _error;
  String? get error => _error;
  final List<String> _warnings = [];
  List<String> get warnings => List.unmodifiable(_warnings);
  String _timeRange = 'medium_term';
  String get timeRange => _timeRange;
  SpotifyListeningTotal _listeningTotal = SpotifyListeningTotal.empty;
  SpotifyListeningTotal get listeningTotal => _listeningTotal;
  String? _listeningAccountId;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _storageQueue = Future.value();

  Future<void> _store(Future<void> Function() operation) {
    final next = _storageQueue.then((_) => operation());
    _storageQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _secrets.read(_storageKey);
      if (raw != null) {
        _credentials = SpotifyCredentials.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      _error = currentL.accountOverviewSpotifyReadSavedFailed('$e');
    }
    _loaded = true;
    _notify();
    if (connected) unawaitedRefresh();
  }

  Future<void> connect(String clientId) async {
    final id = clientId.trim();
    if (id.isEmpty) {
      throw SpotifyOAuthException(currentL.accountOverviewSpotifyEnterClientId);
    }
    final tokens = await _oauth.authorize(id);
    final profile = await _api.profile(tokens.accessToken);
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw SpotifyOAuthException(
        currentL.accountOverviewSpotifyNoRefreshToken,
      );
    }
    final credentials = SpotifyCredentials(
      clientId: id,
      accessToken: tokens.accessToken,
      refreshToken: refreshToken,
      expiresAt: tokens.expiresAt,
      displayName:
          profile['display_name'] as String? ??
          profile['id'] as String? ??
          currentL.accountOverviewSpotifyAccountDefault,
      accountId: profile['id'] as String?,
    );
    final oldAccountId = _credentials?.accountId;
    if (oldAccountId != null && oldAccountId != credentials.accountId) {
      await _store(() => _secrets.delete(_minutesKey(oldAccountId)));
    }
    await _store(
      () => _secrets.write(_storageKey, jsonEncode(credentials.toJson())),
    );
    _generation++;
    _loading = false;
    _credentials = credentials;
    _listeningAccountId = null;
    _listeningTotal = SpotifyListeningTotal.empty;
    _snapshot = null;
    _error = null;
    _notify();
    await refresh();
  }

  Future<void> disconnect() async {
    _generation++;
    final accountId = _credentials?.accountId ?? _listeningAccountId;
    if (accountId != null) {
      await _store(() => _secrets.delete(_minutesKey(accountId)));
    }
    await _store(() => _secrets.delete(_storageKey));
    _loading = false;
    _credentials = null;
    _snapshot = null;
    _listeningAccountId = null;
    _listeningTotal = SpotifyListeningTotal.empty;
    _error = null;
    _warnings.clear();
    _notify();
  }

  void setTimeRange(String range) {
    if (!const ['short_term', 'medium_term', 'long_term'].contains(range) ||
        range == _timeRange) {
      return;
    }
    _timeRange = range;
    _notify();
    unawaitedRefresh();
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void unawaitedRefresh() => refresh().catchError((Object _) {});

  Future<String> _token({bool force = false}) async {
    final credentials = _credentials;
    final generation = _generation;
    if (credentials == null) {
      throw SpotifyOAuthException(currentL.accountOverviewSpotifyNotConnected);
    }
    if (!force && !credentials.expired) return credentials.accessToken;
    final tokens = await _oauth.refresh(
      credentials.clientId,
      credentials.refreshToken,
    );
    if (generation != _generation || !identical(_credentials, credentials)) {
      throw SpotifyOAuthException(
        currentL.accountOverviewSpotifyConnectionChanged,
      );
    }
    final updated = SpotifyCredentials(
      clientId: credentials.clientId,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken ?? credentials.refreshToken,
      expiresAt: tokens.expiresAt,
      displayName: credentials.displayName,
      accountId: credentials.accountId,
    );
    await _store(
      () => _secrets.write(_storageKey, jsonEncode(updated.toJson())),
    );
    if (generation != _generation) {
      throw SpotifyOAuthException(
        currentL.accountOverviewSpotifyConnectionChanged,
      );
    }
    _credentials = updated;
    _notify();
    return updated.accessToken;
  }

  Future<T> _withToken<T>(Future<T> Function(String) read) async {
    final token = await _token();
    try {
      return await read(token);
    } on SpotifyApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      return read(await _token(force: true));
    }
  }

  Future<void> _loadListeningTotal(String accountId) async {
    if (_listeningAccountId == accountId) return;
    final raw = await _secrets.read(_minutesKey(accountId));
    _listeningTotal = raw == null
        ? SpotifyListeningTotal.empty
        : SpotifyListeningTotal.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
    _listeningAccountId = accountId;
  }

  Future<void> _countRecentPlays(
    String accountId,
    SpotifyRecentPage firstPage,
    int generation,
  ) async {
    final previous = _listeningTotal;
    final plays = <SpotifyPlay>[];
    var page = firstPage;
    DateTime? before;
    while (true) {
      plays.addAll(page.plays);
      if (page.plays.isEmpty) break;
      final oldest = page.plays
          .map((play) => play.playedAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      if (before != null && !oldest.isBefore(before)) {
        throw SpotifyApiException(
          currentL.accountOverviewSpotifyPaginationStalled,
          200,
        );
      }
      if (previous.lastPlayedAt != null &&
          !oldest.isAfter(previous.lastPlayedAt!)) {
        break;
      }
      if (!page.hasMore) {
        if (previous.lastPlayedAt != null) {
          _warnings.add(
            currentL.accountOverviewSpotifyHistoryGap,
          );
        }
        break;
      }
      before = oldest;
      page = await _withToken(
        (token) => _api.recentPage(token, before: before),
      );
    }
    if (generation != _generation) return;
    final unique = <int, SpotifyPlay>{
      for (final play in plays) play.playedAt.millisecondsSinceEpoch: play,
    };
    final updated = previous.add(unique.values);
    if (identical(updated, previous)) return;
    await _store(
      () =>
          _secrets.write(_minutesKey(accountId), jsonEncode(updated.toJson())),
    );
    if (generation != _generation) return;
    _listeningTotal = updated;
    _notify();
  }

  Future<void> refresh() async {
    if (!connected || _loading) return;
    _loading = true;
    _error = null;
    _warnings.clear();
    _notify();
    final range = _timeRange;
    final generation = _generation;
    try {
      final profile = await _withToken(_api.profile);
      final accountId = profile['id'] as String?;
      if (accountId != null) {
        try {
          await _loadListeningTotal(accountId);
        } catch (e) {
          _warnings.add(currentL.accountOverviewSpotifyWarningListeningTotal('$e'));
        }
      }
      Future<T> optional<T>(
        String label,
        Future<T> Function(String) read,
        T fallback,
      ) async {
        try {
          return await _withToken(read);
        } catch (e) {
          _warnings.add(currentL.accountOverviewSpotifyWarningLabeled(label, '$e'));
          return fallback;
        }
      }

      final artists = await optional(
        currentL.accountOverviewSpotifyTopArtists,
        (token) => _api.top(token, 'artists', range),
        <SpotifyItem>[],
      );
      final tracks = await optional(
        currentL.accountOverviewSpotifyTopTracks,
        (token) => _api.top(token, 'tracks', range),
        <SpotifyItem>[],
      );
      var recent = <SpotifyItem>[];
      try {
        final page = await _withToken((token) => _api.recentPage(token));
        recent = page.plays.take(10).map((play) => play.item).toList();
        if (accountId != null && _listeningAccountId == accountId) {
          try {
            await _countRecentPlays(accountId, page, generation);
          } catch (e) {
            _warnings.add(currentL.accountOverviewSpotifyWarningListeningTotal('$e'));
          }
        }
      } catch (e) {
        _warnings.add(currentL.accountOverviewSpotifyWarningRecentPlays('$e'));
      }
      final saved = await optional<int?>(
        currentL.accountOverviewSpotifySavedTracks,
        (token) => _api.total(token, '/me/tracks'),
        null,
      );
      final playlists = await optional<int?>(
        currentL.accountOverviewSpotifyPlaylists,
        (token) => _api.total(token, '/me/playlists'),
        null,
      );
      if (generation != _generation) return;
      _snapshot = SpotifySnapshot(
        displayName:
            profile['display_name'] as String? ??
            profile['id'] as String? ??
            currentL.accountOverviewSpotifyAccountDefault,
        profileUrl: (profile['external_urls'] as Map?)?['spotify'] as String?,
        followers: ((profile['followers'] as Map?)?['total'] as num?)?.toInt(),
        topArtists: artists,
        topTracks: tracks,
        recentTracks: recent,
        savedTracks: saved,
        playlists: playlists,
        fetchedAt: DateTime.now(),
        timeRange: range,
      );
    } catch (e) {
      if (generation == _generation) _error = currentL.accountOverviewSpotifyRefreshFailed('$e');
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
        if (range != _timeRange) unawaitedRefresh();
      }
    }
  }

  void seedForTest(SpotifySnapshot snapshot) {
    _credentials = SpotifyCredentials(
      clientId: 'test',
      accessToken: 'test',
      refreshToken: 'test',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      displayName: snapshot.displayName,
    );
    _snapshot = snapshot;
    _timeRange = snapshot.timeRange;
    _loaded = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _api.dispose();
    _oauth.dispose();
    super.dispose();
  }
}

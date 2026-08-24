import 'dart:convert';

import 'package:http/http.dart' as http;

import 'steam_models.dart';

/// Raised for every Steam request that did not come back usable. The
/// message is already user-facing.
class SteamApiException implements Exception {
  const SteamApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Talks to Steam directly from this device.
///
/// Two different Steam hosts are involved and only one of them wants the
/// key: `api.steampowered.com` needs it to read a private thing (which games
/// an account owns), while `store.steampowered.com` serves the public store
/// page and takes no key at all. Nothing here goes near a luma server, so
/// none of it passes through `GatedServerClient` — that gate exists to keep
/// traffic off *luma's* servers, and the user's Steam key must never be sent
/// anywhere but Steam.
class SteamApi {
  SteamApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _webApiHost = 'api.steampowered.com';
  static const _storeHost = 'store.steampowered.com';
  static const _timeout = Duration(seconds: 30);

  /// Turns whatever the user pasted into a 64-bit Steam id.
  ///
  /// Accepts the id itself, a `/profiles/<id>` or `/id/<vanity>` community
  /// URL, or a bare vanity name — people reach for all four, and only the
  /// first is usable as-is.
  Future<String> resolveSteamId(String input, {required String apiKey}) async {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw const SteamApiException('Enter your Steam ID or profile URL.');
    }

    final direct = _asSteamId64(raw);
    if (direct != null) return direct;

    final profileMatch =
        RegExp(r'/profiles/(\d{17})').firstMatch(raw);
    if (profileMatch != null) return profileMatch.group(1)!;

    var vanity = raw;
    final vanityMatch =
        RegExp(r'/id/([^/?#]+)').firstMatch(raw);
    if (vanityMatch != null) {
      vanity = vanityMatch.group(1)!;
    } else if (raw.contains('/') || raw.contains('.')) {
      throw const SteamApiException(
        'That does not look like a Steam ID or profile URL. Use your 17-digit '
        'ID, or the full link to your profile.',
      );
    }

    final uri = Uri.https(_webApiHost, '/ISteamUser/ResolveVanityURL/v1/', {
      'key': apiKey,
      'vanityurl': vanity,
    });
    final body = await _getJson(uri, what: 'resolve that profile name');
    final response = body['response'];
    if (response is Map && response['success'] == 1) {
      final id = response['steamid'];
      if (id is String && id.isNotEmpty) return id;
    }
    throw SteamApiException(
      'Steam does not know a profile called "$vanity". Check the name, or '
      'paste your 17-digit Steam ID instead.',
    );
  }

  /// Every game on the account, including free ones it has played.
  ///
  /// A private "Game details" setting is the usual reason this comes back
  /// empty, and Steam signals it by answering 200 with no `games` key rather
  /// than by failing, so that case is turned into a real error here.
  Future<List<SteamLibraryGame>> ownedGames({
    required String apiKey,
    required String steamId,
  }) async {
    final uri = Uri.https(_webApiHost, '/IPlayerService/GetOwnedGames/v1/', {
      'key': apiKey,
      'steamid': steamId,
      'include_appinfo': '1',
      'include_played_free_games': '1',
      'format': 'json',
    });
    final body = await _getJson(uri, what: 'read your library');
    final response = body['response'];
    if (response is! Map || !response.containsKey('games')) {
      throw const SteamApiException(
        'Steam returned no games. Open your Steam privacy settings and set '
        '"Game details" to Public, then try again.',
      );
    }
    final games = response['games'];
    if (games is! List) return const [];

    final out = <SteamLibraryGame>[];
    for (final entry in games) {
      if (entry is! Map) continue;
      final game = SteamLibraryGame.fromJson(entry.cast<String, dynamic>());
      if (game != null) out.add(game);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// The store page for one app, in [countryCode]'s currency.
  ///
  /// Returns null when Steam answers `success: false`, which is how it
  /// reports an app that is delisted or not sold in this region — a normal
  /// outcome for an old library, not an error worth interrupting the user
  /// over.
  Future<SteamAppDetails?> appDetails(
    int appId, {
    String countryCode = 'us',
  }) async {
    final uri = Uri.https(_storeHost, '/api/appdetails', {
      'appids': '$appId',
      'cc': countryCode,
      'l': 'en',
    });
    final body = await _getJson(uri, what: 'read that store page');
    final entry = body['$appId'];
    if (entry is! Map || entry['success'] != true) return null;
    final data = entry['data'];
    if (data is! Map) return null;
    return SteamAppDetails.fromJson(appId, data.cast<String, dynamic>());
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String what,
  }) async {
    http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } catch (e) {
      throw SteamApiException(
        'Could not reach Steam to $what. Check your connection and try again.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SteamApiException(
        'Steam rejected the API key. Check it under Connect, or generate a '
        'new one at steamcommunity.com/dev/apikey.',
        status: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw SteamApiException(
        'Steam is rate limiting this device. Wait a few minutes and try '
        'again.',
        status: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw SteamApiException(
        'Steam could not $what (HTTP ${response.statusCode}).',
        status: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SteamApiException('Steam sent back an unexpected reply.');
      }
      return decoded.cast<String, dynamic>();
    } on SteamApiException {
      rethrow;
    } catch (_) {
      throw SteamApiException('Steam sent back an unreadable reply to $what.');
    }
  }

  static String? _asSteamId64(String raw) {
    if (raw.length != 17) return null;
    if (!RegExp(r'^\d{17}$').hasMatch(raw)) return null;
    return raw;
  }
}

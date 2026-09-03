import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// What kind of Spotify link was pasted.
enum SpotifyLinkType { track, playlist, album }

class SpotifyLinkException implements Exception {
  SpotifyLinkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A single track's public metadata, enough to find and tag the matching
/// audio once it's located on YouTube.
class SpotifyTrackInfo {
  SpotifyTrackInfo({
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
  });

  final String title;
  final String artist;
  final String? thumbnailUrl;

  /// What gets searched for on YouTube to find the matching audio.
  String get searchQuery => artist.isEmpty ? title : '$artist - $title';

  String get displayTitle => artist.isEmpty ? title : '$artist — $title';
}

/// Reads public Spotify track metadata — no account, login, or API key.
///
/// Spotify's own audio streams are DRM-protected, so this never touches
/// them: it only resolves a track URL to its title, artist, and cover art
/// via Spotify's public oEmbed endpoint and the track page's own `<title>`
/// tag (the same server-rendered text Spotify serves for link previews).
/// [MediaDownloaderPage] then searches YouTube for that title/artist and
/// downloads the match through the existing yt-dlp pipeline.
class SpotifyClient {
  const SpotifyClient._();

  static final _linkPattern = RegExp(
    r'open\.spotify\.com/(?:intl-\w+/)?(track|playlist|album)/([A-Za-z0-9]+)',
  );
  static final _uriPattern =
      RegExp(r'^spotify:(track|playlist|album):([A-Za-z0-9]+)$');

  static bool isSpotifyUrl(String url) =>
      _linkPattern.hasMatch(url) || _uriPattern.hasMatch(url.trim());

  static SpotifyLinkType? linkType(String url) {
    final trimmed = url.trim();
    final match = _linkPattern.firstMatch(trimmed) ?? _uriPattern.firstMatch(trimmed);
    if (match == null) return null;
    switch (match.group(1)) {
      case 'track':
        return SpotifyLinkType.track;
      case 'playlist':
        return SpotifyLinkType.playlist;
      case 'album':
        return SpotifyLinkType.album;
      default:
        return null;
    }
  }

  static Future<SpotifyTrackInfo> fetchTrack(String url) async {
    final trackUrl = _canonicalTrackUrl(url);
    if (trackUrl == null) {
      throw SpotifyLinkException('That does not look like a Spotify track link.');
    }

    final oembedUri =
        Uri.https('open.spotify.com', '/oembed', {'url': trackUrl});
    http.Response oembedRes;
    try {
      oembedRes = await http.get(oembedUri).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw SpotifyLinkException('Could not reach Spotify. Check your connection.');
    }
    if (oembedRes.statusCode != 200) {
      throw SpotifyLinkException('Could not read that Spotify track.');
    }

    Map<String, dynamic> oembed;
    try {
      oembed = jsonDecode(oembedRes.body) as Map<String, dynamic>;
    } catch (_) {
      throw SpotifyLinkException('Could not read that Spotify track.');
    }

    final fallbackTitle = oembed['title']?.toString() ?? '';
    final thumbnail = oembed['thumbnail_url']?.toString();
    if (fallbackTitle.isEmpty) {
      throw SpotifyLinkException('Could not read that Spotify track.');
    }

    final parsed = await _titleAndArtistFromPage(trackUrl, fallbackTitle: fallbackTitle);
    return SpotifyTrackInfo(
      title: parsed.title,
      artist: parsed.artist,
      thumbnailUrl: thumbnail,
    );
  }

  /// Spotify's oEmbed response only carries the track title, not the
  /// artist. The public track page's `<title>` tag is rendered
  /// server-side as "Track - song by Artist | Spotify" and needs no auth
  /// to read, so it's used to recover the artist. Falls back to searching
  /// on the oEmbed title alone if the page can't be read or doesn't match
  /// the expected shape.
  static Future<({String title, String artist})> _titleAndArtistFromPage(
    String trackUrl, {
    required String fallbackTitle,
  }) async {
    try {
      final res = await http.get(Uri.parse(trackUrl)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final titleTag =
            RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(res.body);
        final raw = titleTag?.group(1);
        if (raw != null) {
          final decoded = _decodeHtmlEntities(raw.trim());
          final m = RegExp(
            r'^(.*?)\s*-\s*song(?:\s+and\s+lyrics)?\s+by\s+(.*?)\s*\|\s*Spotify\s*$',
            caseSensitive: false,
          ).firstMatch(decoded);
          if (m != null) {
            return (title: m.group(1)!.trim(), artist: m.group(2)!.trim());
          }
        }
      }
    } catch (_) {
      // Fall through — oEmbed title alone still lets us search YouTube.
    }
    return (title: fallbackTitle, artist: '');
  }

  static String _decodeHtmlEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  /// Downloads a track's cover art (from [SpotifyTrackInfo.thumbnailUrl]) so
  /// it can be embedded into the downloaded audio file. Returns null on any
  /// failure — cover art is a nice-to-have, never worth failing the download.
  static Future<Uint8List?> fetchThumbnailBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {
      // Cover art is optional — swallow and continue without it.
    }
    return null;
  }

  static String? _canonicalTrackUrl(String url) {
    final trimmed = url.trim();
    final uriMatch = _uriPattern.firstMatch(trimmed);
    if (uriMatch != null) {
      if (uriMatch.group(1) != 'track') return null;
      return 'https://open.spotify.com/track/${uriMatch.group(2)}';
    }
    final linkMatch = _linkPattern.firstMatch(trimmed);
    if (linkMatch == null || linkMatch.group(1) != 'track') return null;
    return 'https://open.spotify.com/track/${linkMatch.group(2)}';
  }
}

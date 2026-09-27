class SpotifyItem {
  const SpotifyItem({
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.url,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final String? url;

  factory SpotifyItem.artist(Map<String, dynamic> json) => SpotifyItem(
    name: json['name'] as String? ?? 'Unknown artist',
    subtitle:
        (json['genres'] as List?)?.cast<String>().take(2).join(' · ') ?? '',
    imageUrl: _firstImage(json['images']),
    url: _spotifyUrl(json),
  );

  factory SpotifyItem.track(Map<String, dynamic> json) => SpotifyItem(
    name: json['name'] as String? ?? 'Unknown track',
    subtitle: (json['artists'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((artist) => artist['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .join(', '),
    imageUrl: _firstImage((json['album'] as Map?)?['images']),
    url: _spotifyUrl(json),
  );

  static String? _firstImage(dynamic images) {
    if (images is! List || images.isEmpty) return null;
    return (images.first as Map?)?['url'] as String?;
  }

  static String? _spotifyUrl(Map<String, dynamic> json) =>
      (json['external_urls'] as Map?)?['spotify'] as String?;
}

class SpotifyPlay {
  const SpotifyPlay({
    required this.item,
    required this.playedAt,
    required this.durationMs,
  });

  final SpotifyItem item;
  final DateTime playedAt;
  final int durationMs;

  factory SpotifyPlay.fromJson(Map<String, dynamic> json) {
    final track = json['track'] as Map<String, dynamic>;
    return SpotifyPlay(
      item: SpotifyItem.track(track),
      playedAt: DateTime.parse(json['played_at'] as String),
      durationMs: ((track['duration_ms'] as num?)?.toInt() ?? 0).clamp(
        0,
        86400000,
      ),
    );
  }
}

class SpotifyRecentPage {
  const SpotifyRecentPage({required this.plays, required this.hasMore});

  final List<SpotifyPlay> plays;
  final bool hasMore;
}

class SpotifyListeningTotal {
  const SpotifyListeningTotal({
    required this.milliseconds,
    required this.lastPlayedAt,
    required this.firstPlayedAt,
  });

  static const empty = SpotifyListeningTotal(
    milliseconds: 0,
    lastPlayedAt: null,
    firstPlayedAt: null,
  );

  final int milliseconds;
  final DateTime? lastPlayedAt;
  final DateTime? firstPlayedAt;
  int get minutes => milliseconds ~/ 60000;

  SpotifyListeningTotal add(Iterable<SpotifyPlay> plays) {
    final fresh = plays
        .where(
          (play) =>
              lastPlayedAt == null || play.playedAt.isAfter(lastPlayedAt!),
        )
        .toList();
    if (fresh.isEmpty) return this;
    final first = fresh
        .map((play) => play.playedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final last = fresh
        .map((play) => play.playedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return SpotifyListeningTotal(
      milliseconds:
          milliseconds +
          fresh.fold<int>(0, (sum, play) => sum + play.durationMs),
      lastPlayedAt: last,
      firstPlayedAt: firstPlayedAt == null || first.isBefore(firstPlayedAt!)
          ? first
          : firstPlayedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'milliseconds': milliseconds,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'firstPlayedAt': firstPlayedAt?.toIso8601String(),
  };

  factory SpotifyListeningTotal.fromJson(Map<String, dynamic> json) =>
      SpotifyListeningTotal(
        milliseconds: (json['milliseconds'] as num?)?.toInt() ?? 0,
        lastPlayedAt: DateTime.tryParse(json['lastPlayedAt'] as String? ?? ''),
        firstPlayedAt: DateTime.tryParse(
          json['firstPlayedAt'] as String? ?? '',
        ),
      );
}

class SpotifySnapshot {
  const SpotifySnapshot({
    required this.displayName,
    required this.profileUrl,
    required this.followers,
    required this.topArtists,
    required this.topTracks,
    required this.recentTracks,
    required this.savedTracks,
    required this.playlists,
    required this.fetchedAt,
    required this.timeRange,
  });

  final String displayName;
  final String? profileUrl;
  final int? followers;
  final List<SpotifyItem> topArtists;
  final List<SpotifyItem> topTracks;
  final List<SpotifyItem> recentTracks;
  final int? savedTracks;
  final int? playlists;
  final DateTime fetchedAt;
  final String timeRange;
}

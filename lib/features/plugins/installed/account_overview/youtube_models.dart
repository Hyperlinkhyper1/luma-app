/// Plain data for everything the YouTube section shows.
///
/// Every model is JSON-round-trippable: the repository caches the whole
/// snapshot to disk so reopening the plugin paints instantly instead of
/// re-running a fresh round of Data API and Analytics API calls.
library;

/// The signed-in channel's identity and headline counts.
class YoutubeChannelSnapshot {
  const YoutubeChannelSnapshot({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.subscriberCount,
    required this.viewCount,
    required this.videoCount,
    required this.hiddenSubscriberCount,
    required this.uploadsPlaylistId,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String thumbnailUrl;
  final int subscriberCount;
  final int viewCount;
  final int videoCount;

  /// The owner has hidden their subscriber count — a real state, not a
  /// missing value, so the UI says "hidden" rather than "0".
  final bool hiddenSubscriberCount;

  /// The channel's uploads playlist id, used to list recent videos. Null
  /// only if the channel genuinely has none.
  final String? uploadsPlaylistId;
  final DateTime? publishedAt;

  String get htmlUrl => 'https://www.youtube.com/channel/$id';

  static const empty = YoutubeChannelSnapshot(
    id: '',
    title: '',
    description: null,
    thumbnailUrl: '',
    subscriberCount: 0,
    viewCount: 0,
    videoCount: 0,
    hiddenSubscriberCount: false,
    uploadsPlaylistId: null,
    publishedAt: null,
  );

  factory YoutubeChannelSnapshot.fromApi(Map<String, dynamic> j) {
    final snippet = j['snippet'] as Map<String, dynamic>? ?? const {};
    final stats = j['statistics'] as Map<String, dynamic>? ?? const {};
    final details = j['contentDetails'] as Map<String, dynamic>? ?? const {};
    final thumbnails =
        snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
    final thumb = (thumbnails['high'] ??
        thumbnails['medium'] ??
        thumbnails['default']) as Map<String, dynamic>?;
    final relatedPlaylists =
        details['relatedPlaylists'] as Map<String, dynamic>?;

    return YoutubeChannelSnapshot(
      id: j['id'] as String? ?? '',
      title: snippet['title'] as String? ?? '',
      description: snippet['description'] as String?,
      thumbnailUrl: thumb?['url'] as String? ?? '',
      // The Data API reports every count as a string.
      subscriberCount: int.tryParse('${stats['subscriberCount']}') ?? 0,
      viewCount: int.tryParse('${stats['viewCount']}') ?? 0,
      videoCount: int.tryParse('${stats['videoCount']}') ?? 0,
      hiddenSubscriberCount: stats['hiddenSubscriberCount'] as bool? ?? false,
      uploadsPlaylistId: relatedPlaylists?['uploads'] as String?,
      publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'subscriberCount': subscriberCount,
        'viewCount': viewCount,
        'videoCount': videoCount,
        'hiddenSubscriberCount': hiddenSubscriberCount,
        'uploadsPlaylistId': uploadsPlaylistId,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  factory YoutubeChannelSnapshot.fromJson(Map<String, dynamic> j) =>
      YoutubeChannelSnapshot(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String? ?? '',
        subscriberCount: (j['subscriberCount'] as num?)?.toInt() ?? 0,
        viewCount: (j['viewCount'] as num?)?.toInt() ?? 0,
        videoCount: (j['videoCount'] as num?)?.toInt() ?? 0,
        hiddenSubscriberCount: j['hiddenSubscriberCount'] as bool? ?? false,
        uploadsPlaylistId: j['uploadsPlaylistId'] as String?,
        publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
      );
}

/// One uploaded video and its lifetime counters.
class YoutubeVideoStat {
  const YoutubeVideoStat({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
  });

  final String id;
  final String title;
  final String thumbnailUrl;
  final DateTime? publishedAt;
  final int viewCount;
  final int likeCount;
  final int commentCount;

  String get htmlUrl => 'https://www.youtube.com/watch?v=$id';

  factory YoutubeVideoStat.fromApi(Map<String, dynamic> j) {
    final snippet = j['snippet'] as Map<String, dynamic>? ?? const {};
    final stats = j['statistics'] as Map<String, dynamic>? ?? const {};
    final thumbnails =
        snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
    final thumb = (thumbnails['medium'] ?? thumbnails['default'])
        as Map<String, dynamic>?;
    final rawId = j['id'];
    return YoutubeVideoStat(
      id: rawId is Map ? (rawId['videoId'] as String? ?? '') : '$rawId',
      title: snippet['title'] as String? ?? '',
      thumbnailUrl: thumb?['url'] as String? ?? '',
      publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      viewCount: int.tryParse('${stats['viewCount']}') ?? 0,
      likeCount: int.tryParse('${stats['likeCount']}') ?? 0,
      commentCount: int.tryParse('${stats['commentCount']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'publishedAt': publishedAt?.toIso8601String(),
        'viewCount': viewCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
      };

  factory YoutubeVideoStat.fromJson(Map<String, dynamic> j) =>
      YoutubeVideoStat(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        thumbnailUrl: j['thumbnailUrl'] as String? ?? '',
        publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
        viewCount: (j['viewCount'] as num?)?.toInt() ?? 0,
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
      );
}

/// One day of the Analytics API's channel-wide time series.
class YoutubeAnalyticsPoint {
  const YoutubeAnalyticsPoint({
    required this.day,
    required this.views,
    required this.estimatedMinutesWatched,
    required this.averageViewDuration,
    required this.subscribersGained,
    required this.subscribersLost,
  });

  final DateTime day;
  final int views;
  final int estimatedMinutesWatched;

  /// Seconds.
  final int averageViewDuration;
  final int subscribersGained;
  final int subscribersLost;

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'views': views,
        'estimatedMinutesWatched': estimatedMinutesWatched,
        'averageViewDuration': averageViewDuration,
        'subscribersGained': subscribersGained,
        'subscribersLost': subscribersLost,
      };

  factory YoutubeAnalyticsPoint.fromJson(Map<String, dynamic> j) =>
      YoutubeAnalyticsPoint(
        day: DateTime.parse(j['day'] as String),
        views: (j['views'] as num?)?.toInt() ?? 0,
        estimatedMinutesWatched:
            (j['estimatedMinutesWatched'] as num?)?.toInt() ?? 0,
        averageViewDuration: (j['averageViewDuration'] as num?)?.toInt() ?? 0,
        subscribersGained: (j['subscribersGained'] as num?)?.toInt() ?? 0,
        subscribersLost: (j['subscribersLost'] as num?)?.toInt() ?? 0,
      );
}

/// Views attributed to one of YouTube's traffic-source buckets.
class YoutubeTrafficSource {
  const YoutubeTrafficSource({required this.type, required this.views});

  /// The raw `insightTrafficSourceType` enum value from the API.
  final String type;
  final int views;

  /// A human label for the raw API enum — Google's own dashboard uses the
  /// same names, so this list mirrors those rather than inventing new ones.
  String get label => switch (type) {
        'ADVERTISING' => 'Advertising',
        'ANNOTATION' => 'Annotations',
        'CAMPAIGN_CARD' => 'Campaign cards',
        'END_SCREEN' => 'End screens',
        'EXT_URL' => 'External sites',
        'NO_LINK_EMBEDDED' => 'Embedded player',
        'NO_LINK_OTHER' => 'Direct or unknown',
        'NOTIFICATION' => 'Notifications',
        'PLAYLIST' => 'Playlists',
        'PROMOTED' => 'Promoted content',
        'RELATED_VIDEO' => 'Suggested videos',
        'SUBSCRIBER' => 'Subscription feed',
        'YT_CHANNEL' => 'Channel page',
        'YT_OTHER_PAGE' => 'Other YouTube pages',
        'YT_SEARCH' => 'YouTube search',
        'SHORTS' => 'Shorts feed',
        _ => type,
      };

  Map<String, dynamic> toJson() => {'type': type, 'views': views};

  factory YoutubeTrafficSource.fromJson(Map<String, dynamic> j) =>
      YoutubeTrafficSource(
        type: j['type'] as String? ?? '',
        views: (j['views'] as num?)?.toInt() ?? 0,
      );
}

/// The Analytics API slice of the picture, over whatever window it was
/// queried for.
class YoutubeAnalyticsSnapshot {
  const YoutubeAnalyticsSnapshot({
    required this.points,
    required this.trafficSources,
  });

  final List<YoutubeAnalyticsPoint> points;
  final List<YoutubeTrafficSource> trafficSources;

  static const empty =
      YoutubeAnalyticsSnapshot(points: [], trafficSources: []);

  int get totalViews => points.fold(0, (sum, p) => sum + p.views);

  int get totalMinutesWatched =>
      points.fold(0, (sum, p) => sum + p.estimatedMinutesWatched);

  int get netSubscribers => points.fold(
      0, (sum, p) => sum + p.subscribersGained - p.subscribersLost);

  /// Averaged across days that actually had views — a zero-view day would
  /// otherwise drag the average down for no real reason.
  double get averageViewDurationSeconds {
    final withViews = points.where((p) => p.views > 0).toList();
    if (withViews.isEmpty) return 0;
    return withViews.fold(0.0, (sum, p) => sum + p.averageViewDuration) /
        withViews.length;
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'trafficSources': trafficSources.map((s) => s.toJson()).toList(),
      };

  factory YoutubeAnalyticsSnapshot.fromJson(Map<String, dynamic> j) =>
      YoutubeAnalyticsSnapshot(
        points: (j['points'] as List<dynamic>? ?? [])
            .map((e) => YoutubeAnalyticsPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        trafficSources: (j['trafficSources'] as List<dynamic>? ?? [])
            .map((e) =>
                YoutubeTrafficSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// The whole YouTube picture, as one cacheable snapshot.
class YoutubeSnapshot {
  const YoutubeSnapshot({
    required this.channel,
    required this.videos,
    required this.analytics,
    required this.fetchedAt,
  });

  final YoutubeChannelSnapshot? channel;
  final List<YoutubeVideoStat> videos;
  final YoutubeAnalyticsSnapshot analytics;
  final DateTime fetchedAt;

  static final empty = YoutubeSnapshot(
    channel: null,
    videos: const [],
    analytics: YoutubeAnalyticsSnapshot.empty,
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  bool get isEmpty => channel == null;

  Map<String, dynamic> toJson() => {
        'channel': channel?.toJson(),
        'videos': videos.map((v) => v.toJson()).toList(),
        'analytics': analytics.toJson(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory YoutubeSnapshot.fromJson(Map<String, dynamic> j) => YoutubeSnapshot(
        channel: j['channel'] == null
            ? null
            : YoutubeChannelSnapshot.fromJson(
                j['channel'] as Map<String, dynamic>),
        videos: (j['videos'] as List<dynamic>? ?? [])
            .map((e) => YoutubeVideoStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        analytics: j['analytics'] == null
            ? YoutubeAnalyticsSnapshot.empty
            : YoutubeAnalyticsSnapshot.fromJson(
                j['analytics'] as Map<String, dynamic>),
        fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Data for the MC Content section: one shape for a published project no
/// matter which of the three platforms it came from.
library;

/// The platforms MC Content pulls together.
enum McPlatform {
  curseforge('CurseForge', 'curseforge'),
  modrinth('Modrinth', 'modrinth'),
  planetMinecraft('Planet Minecraft', 'pmc');

  const McPlatform(this.label, this.id);

  final String label;

  /// Stable key used in the history file and in JSON. Never derive it from
  /// [label] — renaming the label must not orphan a year of history.
  final String id;

  static McPlatform? byId(String id) {
    for (final platform in values) {
      if (platform.id == id) return platform;
    }
    return null;
  }
}

/// One published thing — a CurseForge mod, a Modrinth project, or a Planet
/// Minecraft submission.
///
/// The three platforms count different things, so fields that only one of
/// them reports ([views], [favourites]) are zero elsewhere rather than
/// nullable: a missing count and a zero count read the same on a card, and
/// [McPlatform] already says which fields are meaningful.
class McProject {
  const McProject({
    required this.platform,
    required this.id,
    required this.slug,
    required this.name,
    required this.url,
    this.summary,
    this.iconUrl,
    this.kind,
    this.downloads = 0,
    this.followers = 0,
    this.views = 0,
    this.favourites = 0,
    this.comments = 0,
    this.updatedAt,
    this.approximate = false,
  });

  final McPlatform platform;
  final String id;
  final String slug;
  final String name;
  final String url;
  final String? summary;
  final String? iconUrl;

  /// "mod", "modpack", "resourcepack", "skin", "project"… whatever the
  /// platform calls this thing.
  final String? kind;

  final int downloads;

  /// Modrinth followers, CurseForge thumbs-up, PMC diamonds — the platform's
  /// nearest equivalent of "people who liked this".
  final int followers;

  /// Planet Minecraft only.
  final int views;
  final int favourites;
  final int comments;

  final DateTime? updatedAt;

  /// True when the platform only served a rounded figure (Planet Minecraft
  /// prints "1.1k" on listing pages). The UI marks these so a total that
  /// does not add up is explained rather than mysterious.
  final bool approximate;

  /// Key used for this project's own history series.
  String get historyKey => 'project:${platform.id}:$id';

  Map<String, dynamic> toJson() => {
        'platform': platform.id,
        'id': id,
        'slug': slug,
        'name': name,
        'url': url,
        'summary': summary,
        'iconUrl': iconUrl,
        'kind': kind,
        'downloads': downloads,
        'followers': followers,
        'views': views,
        'favourites': favourites,
        'comments': comments,
        'updatedAt': updatedAt?.toIso8601String(),
        'approximate': approximate,
      };

  factory McProject.fromJson(Map<String, dynamic> j) => McProject(
        platform: McPlatform.byId(j['platform'] as String? ?? '') ??
            McPlatform.modrinth,
        id: j['id'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        summary: j['summary'] as String?,
        iconUrl: j['iconUrl'] as String?,
        kind: j['kind'] as String?,
        downloads: (j['downloads'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        views: (j['views'] as num?)?.toInt() ?? 0,
        favourites: (j['favourites'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
        approximate: j['approximate'] as bool? ?? false,
      );
}

/// A creator account on one platform.
class McCreator {
  const McCreator({
    required this.platform,
    required this.handle,
    this.displayName,
    this.avatarUrl,
    this.url,
    this.followers = 0,
  });

  final McPlatform platform;
  final String handle;
  final String? displayName;
  final String? avatarUrl;
  final String? url;

  /// Modrinth followers / PMC subscribers.
  final int followers;

  Map<String, dynamic> toJson() => {
        'platform': platform.id,
        'handle': handle,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'url': url,
        'followers': followers,
      };

  factory McCreator.fromJson(Map<String, dynamic> j) => McCreator(
        platform: McPlatform.byId(j['platform'] as String? ?? '') ??
            McPlatform.modrinth,
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        url: j['url'] as String?,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
      );
}

/// How one platform's fetch went.
///
/// A platform the user never configured, one that failed, and one that
/// legitimately has no projects are three different things, and the UI says
/// which — an empty grid with no explanation is the worst of the three.
enum McPlatformState {
  notConfigured('Not set up'),
  ok('Connected'),
  failed('Unavailable');

  const McPlatformState(this.label);
  final String label;
}

/// The result of asking one platform for everything it has.
class McPlatformResult {
  const McPlatformResult({
    required this.platform,
    required this.state,
    this.creator,
    this.projects = const [],
    this.message,
    this.fetchedAt,
  });

  final McPlatform platform;
  final McPlatformState state;
  final McCreator? creator;
  final List<McProject> projects;

  /// Why it failed, or what the user still needs to supply.
  final String? message;
  final DateTime? fetchedAt;

  int get downloads => projects.fold(0, (sum, p) => sum + p.downloads);
  int get followers => projects.fold(0, (sum, p) => sum + p.followers);
  int get views => projects.fold(0, (sum, p) => sum + p.views);

  /// True when any project's figures were rounded by the platform, which
  /// makes the totals above approximate too.
  bool get approximate => projects.any((p) => p.approximate);

  McPlatformResult copyWith({
    McPlatformState? state,
    McCreator? creator,
    List<McProject>? projects,
    String? message,
    DateTime? fetchedAt,
  }) =>
      McPlatformResult(
        platform: platform,
        state: state ?? this.state,
        creator: creator ?? this.creator,
        projects: projects ?? this.projects,
        message: message ?? this.message,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  Map<String, dynamic> toJson() => {
        'platform': platform.id,
        'state': state.name,
        'creator': creator?.toJson(),
        'projects': projects.map((p) => p.toJson()).toList(),
        'message': message,
        'fetchedAt': fetchedAt?.toIso8601String(),
      };

  factory McPlatformResult.fromJson(Map<String, dynamic> j) {
    final platform =
        McPlatform.byId(j['platform'] as String? ?? '') ?? McPlatform.modrinth;
    return McPlatformResult(
      platform: platform,
      state: McPlatformState.values.firstWhere(
        (s) => s.name == j['state'],
        orElse: () => McPlatformState.notConfigured,
      ),
      creator: j['creator'] == null
          ? null
          : McCreator.fromJson(j['creator'] as Map<String, dynamic>),
      projects: (j['projects'] as List<dynamic>? ?? [])
          .map((e) => McProject.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: j['message'] as String?,
      fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? ''),
    );
  }
}

/// Everything MC Content shows, as one cacheable snapshot.
class McSnapshot {
  const McSnapshot({required this.results, required this.fetchedAt});

  final Map<McPlatform, McPlatformResult> results;
  final DateTime fetchedAt;

  static final empty = McSnapshot(
    results: const {},
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  McPlatformResult resultFor(McPlatform platform) =>
      results[platform] ??
      McPlatformResult(platform: platform, state: McPlatformState.notConfigured);

  /// The two mod platforms, which the tab presents as one combined library.
  /// Planet Minecraft is deliberately excluded: it publishes skins, blogs and
  /// builds alongside mods and reports rounded figures, so folding it into
  /// the same totals would quietly corrupt them. It gets its own header.
  static const combinedPlatforms = [McPlatform.curseforge, McPlatform.modrinth];

  List<McProject> get combinedProjects => [
        for (final platform in combinedPlatforms) ...resultFor(platform).projects,
      ];

  int get combinedDownloads =>
      combinedProjects.fold(0, (sum, p) => sum + p.downloads);

  int get combinedFollowers =>
      combinedProjects.fold(0, (sum, p) => sum + p.followers);

  List<McProject> get pmcProjects => resultFor(McPlatform.planetMinecraft).projects;

  /// True once at least one platform has returned something.
  bool get hasAnyData => results.values.any((r) => r.projects.isNotEmpty);

  bool get isEmpty => results.isEmpty;

  McSnapshot withResult(McPlatformResult result) => McSnapshot(
        results: {...results, result.platform: result},
        fetchedAt: fetchedAt,
      );

  McSnapshot withFetchedAt(DateTime at) =>
      McSnapshot(results: results, fetchedAt: at);

  Map<String, dynamic> toJson() => {
        'results': [for (final r in results.values) r.toJson()],
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory McSnapshot.fromJson(Map<String, dynamic> j) {
    final results = <McPlatform, McPlatformResult>{};
    for (final raw in (j['results'] as List<dynamic>? ?? [])) {
      final result = McPlatformResult.fromJson(raw as Map<String, dynamic>);
      results[result.platform] = result;
    }
    return McSnapshot(
      results: results,
      fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Reads the shorthand counts Planet Minecraft prints on listing pages.
///
/// `"1,234"` is exact; `"1.1k"` and `"3.8M"` are the site's own rounding and
/// come back as 1100 and 3800000. Returns null for anything unparseable so
/// the caller can tell "no number" from "zero".
int? parseCompactCount(String? raw) {
  if (raw == null) return null;
  final text = raw.trim().toLowerCase().replaceAll(',', '');
  if (text.isEmpty) return null;

  final match = RegExp(r'^([0-9]*\.?[0-9]+)\s*([km])?$').firstMatch(text);
  if (match == null) return null;

  final value = double.tryParse(match.group(1)!);
  if (value == null) return null;

  return switch (match.group(2)) {
    'k' => (value * 1000).round(),
    'm' => (value * 1000000).round(),
    _ => value.round(),
  };
}

/// True when [raw] was rounded by the site rather than given exactly.
bool isCompactCount(String? raw) {
  if (raw == null) return false;
  final text = raw.trim().toLowerCase();
  return text.endsWith('k') || text.endsWith('m');
}

import 'dart:convert';

import 'package:http/http.dart' as http;

class ModrinthApiException implements Exception {
  ModrinthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sort orders Modrinth's search accepts, in the order its own site shows
/// them. The key goes straight into the `index` query parameter.
const modrinthSortIndexes = {
  'relevance': 'Relevance',
  'downloads': 'Downloads',
  'follows': 'Follows',
  'newest': 'Newest',
  'updated': 'Recently updated',
};

class ModrinthSearchHit {
  ModrinthSearchHit({
    required this.projectId,
    required this.slug,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.downloads,
    required this.follows,
    required this.projectType,
    required this.categories,
    required this.displayCategories,
    required this.author,
    required this.dateModified,
    required this.gallery,
    required this.featuredGallery,
    required this.color,
    required this.clientSide,
    required this.serverSide,
    required this.gameVersions,
  });

  final String projectId;
  final String slug;
  final String title;
  final String description;
  final String? iconUrl;
  final int downloads;
  final int follows;
  final String projectType; // mod | resourcepack | shader | datapack | modpack
  final List<String> categories;

  /// The subset Modrinth actually prints on a card — `categories` also holds
  /// loader tags (`fabric`, `forge`, …) that would just be noise there.
  final List<String> displayCategories;
  final String? author;
  final DateTime? dateModified;
  final List<String> gallery;
  final String? featuredGallery;

  /// Modrinth's own accent colour for the project, sampled from its icon and
  /// served as a packed RGB int.
  final int? color;
  final String clientSide; // required | optional | unsupported | unknown
  final String serverSide;
  final List<String> gameVersions;

  factory ModrinthSearchHit.fromJson(Map<String, dynamic> json) => ModrinthSearchHit(
        projectId: json['project_id'] as String,
        slug: json['slug'] as String? ?? json['project_id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        description: json['description'] as String? ?? '',
        iconUrl: _nonEmpty(json['icon_url'] as String?),
        downloads: (json['downloads'] as num?)?.toInt() ?? 0,
        follows: (json['follows'] as num?)?.toInt() ?? 0,
        projectType: json['project_type'] as String? ?? 'mod',
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
        displayCategories:
            (json['display_categories'] as List?)?.cast<String>() ?? const [],
        author: _nonEmpty(json['author'] as String?),
        dateModified: DateTime.tryParse(json['date_modified'] as String? ?? ''),
        gallery: (json['gallery'] as List?)?.cast<String>() ?? const [],
        featuredGallery: _nonEmpty(json['featured_gallery'] as String?),
        color: (json['color'] as num?)?.toInt(),
        clientSide: json['client_side'] as String? ?? 'unknown',
        serverSide: json['server_side'] as String? ?? 'unknown',
        gameVersions: (json['versions'] as List?)?.cast<String>() ?? const [],
      );
}

class ModrinthSearchResult {
  ModrinthSearchResult({required this.hits, required this.totalHits});
  final List<ModrinthSearchHit> hits;
  final int totalHits;
}

/// One image from a project's gallery, with the caption Modrinth prints
/// underneath it.
class ModrinthGalleryImage {
  ModrinthGalleryImage({
    required this.url,
    required this.title,
    required this.description,
    required this.featured,
  });
  final String url;
  final String? title;
  final String? description;
  final bool featured;

  factory ModrinthGalleryImage.fromJson(Map<String, dynamic> json) =>
      ModrinthGalleryImage(
        url: json['url'] as String,
        title: _nonEmpty(json['title'] as String?),
        description: _nonEmpty(json['description'] as String?),
        featured: json['featured'] as bool? ?? false,
      );
}

class ModrinthProject {
  ModrinthProject({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.body,
    required this.iconUrl,
    required this.downloads,
    required this.followers,
    required this.gameVersions,
    required this.loaders,
    required this.sourceUrl,
    required this.issuesUrl,
    required this.wikiUrl,
    required this.discordUrl,
    required this.gallery,
    required this.categories,
    required this.projectType,
    required this.clientSide,
    required this.serverSide,
    required this.licenseName,
    required this.licenseUrl,
    required this.published,
    required this.updated,
    required this.color,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String body;
  final String? iconUrl;
  final int downloads;
  final int followers;
  final List<String> gameVersions;
  final List<String> loaders;
  final String? sourceUrl;
  final String? issuesUrl;
  final String? wikiUrl;
  final String? discordUrl;
  final List<ModrinthGalleryImage> gallery;
  final List<String> categories;
  final String projectType;
  final String clientSide;
  final String serverSide;
  final String? licenseName;
  final String? licenseUrl;
  final DateTime? published;
  final DateTime? updated;
  final int? color;

  /// The gallery in the order Modrinth's carousel uses: featured shot first.
  List<ModrinthGalleryImage> get orderedGallery {
    final sorted = [...gallery];
    sorted.sort((a, b) {
      if (a.featured == b.featured) return 0;
      return a.featured ? -1 : 1;
    });
    return sorted;
  }

  factory ModrinthProject.fromJson(Map<String, dynamic> json) {
    final license = json['license'] as Map<String, dynamic>?;
    return ModrinthProject(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      body: json['body'] as String? ?? '',
      iconUrl: _nonEmpty(json['icon_url'] as String?),
      downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      gameVersions: (json['game_versions'] as List?)?.cast<String>() ?? const [],
      loaders: (json['loaders'] as List?)?.cast<String>() ?? const [],
      sourceUrl: _nonEmpty(json['source_url'] as String?),
      issuesUrl: _nonEmpty(json['issues_url'] as String?),
      wikiUrl: _nonEmpty(json['wiki_url'] as String?),
      discordUrl: _nonEmpty(json['discord_url'] as String?),
      gallery: ((json['gallery'] as List?) ?? const [])
          .map((e) => ModrinthGalleryImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: [
        ...((json['categories'] as List?)?.cast<String>() ?? const []),
        ...((json['additional_categories'] as List?)?.cast<String>() ?? const []),
      ],
      projectType: json['project_type'] as String? ?? 'mod',
      clientSide: json['client_side'] as String? ?? 'unknown',
      serverSide: json['server_side'] as String? ?? 'unknown',
      licenseName: _nonEmpty(license?['name'] as String?) ??
          _nonEmpty(license?['id'] as String?),
      licenseUrl: _nonEmpty(license?['url'] as String?),
      published: DateTime.tryParse(json['published'] as String? ?? ''),
      updated: DateTime.tryParse(json['updated'] as String? ?? ''),
      color: (json['color'] as num?)?.toInt(),
    );
  }
}

/// A member of a project's team — the project endpoint itself carries no
/// author name, so the detail page's `by <owner>` line comes from here.
class ModrinthTeamMember {
  ModrinthTeamMember({
    required this.username,
    required this.role,
    required this.avatarUrl,
  });
  final String username;
  final String role;
  final String? avatarUrl;

  factory ModrinthTeamMember.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    return ModrinthTeamMember(
      username: user['username'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatarUrl: _nonEmpty(user['avatar_url'] as String?),
    );
  }
}

class ModrinthVersionFile {
  ModrinthVersionFile({
    required this.url,
    required this.filename,
    required this.sha1,
    required this.size,
    required this.primary,
  });
  final String url;
  final String filename;
  final String sha1;
  final int size;
  final bool primary;

  factory ModrinthVersionFile.fromJson(Map<String, dynamic> json) => ModrinthVersionFile(
        url: json['url'] as String,
        filename: json['filename'] as String,
        sha1: (json['hashes'] as Map<String, dynamic>?)?['sha1'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        primary: json['primary'] as bool? ?? false,
      );
}

class ModrinthDependency {
  ModrinthDependency({this.versionId, this.projectId, required this.dependencyType});
  final String? versionId;
  final String? projectId;
  final String dependencyType; // required | optional | incompatible | embedded

  factory ModrinthDependency.fromJson(Map<String, dynamic> json) => ModrinthDependency(
        versionId: json['version_id'] as String?,
        projectId: json['project_id'] as String?,
        dependencyType: json['dependency_type'] as String? ?? 'optional',
      );
}

class ModrinthVersion {
  ModrinthVersion({
    required this.id,
    required this.projectId,
    required this.versionNumber,
    required this.name,
    required this.versionType,
    required this.gameVersions,
    required this.loaders,
    required this.files,
    required this.dependencies,
    required this.datePublished,
    required this.downloads,
    required this.changelog,
  });

  final String id;
  final String projectId;
  final String versionNumber;
  final String name;
  final String versionType; // release | beta | alpha
  final List<String> gameVersions;
  final List<String> loaders;
  final List<ModrinthVersionFile> files;
  final List<ModrinthDependency> dependencies;
  final DateTime datePublished;
  final int downloads;
  final String changelog;

  ModrinthVersionFile get primaryFile => files.firstWhere(
        (f) => f.primary,
        orElse: () => files.first,
      );

  factory ModrinthVersion.fromJson(Map<String, dynamic> json) => ModrinthVersion(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        versionNumber: json['version_number'] as String? ?? '',
        name: json['name'] as String? ?? '',
        versionType: json['version_type'] as String? ?? 'release',
        gameVersions: (json['game_versions'] as List?)?.cast<String>() ?? const [],
        loaders: (json['loaders'] as List?)?.cast<String>() ?? const [],
        files: ((json['files'] as List?) ?? const [])
            .map((e) => ModrinthVersionFile.fromJson(e as Map<String, dynamic>))
            .toList(),
        dependencies: ((json['dependencies'] as List?) ?? const [])
            .map((e) => ModrinthDependency.fromJson(e as Map<String, dynamic>))
            .toList(),
        datePublished:
            DateTime.tryParse(json['date_published'] as String? ?? '') ?? DateTime(2000),
        downloads: (json['downloads'] as num?)?.toInt() ?? 0,
        changelog: json['changelog'] as String? ?? '',
      );
}

String? _nonEmpty(String? value) =>
    (value == null || value.trim().isEmpty) ? null : value;

/// Thin client for Modrinth's public v2 API — read-only, no auth required.
/// Used for browsing/installing mods, resource packs, shader packs and
/// datapacks (Modrinth calls all of these "projects", distinguished by
/// `project_type`).
class ModrinthApiClient {
  ModrinthApiClient._();
  static final ModrinthApiClient instance = ModrinthApiClient._();

  static const _base = 'https://api.modrinth.com/v2';

  /// The public site, for "Open on Modrinth" links.
  static const site = 'https://modrinth.com';

  // Modrinth asks integrations to identify themselves with a descriptive
  // User-Agent rather than a registered API key for read-only usage.
  static const _headers = {'User-Agent': 'luma-app/minecraft-launcher (github.com/Hyperlinkhyper1/luma-app)'};

  /// The public page for a project. Modrinth's URL segment matches the
  /// project type for everything this launcher browses.
  static String projectUrl(String projectType, String slug) =>
      '$site/$projectType/$slug';

  Future<ModrinthSearchResult> search({
    String query = '',
    required String projectType, // mod | resourcepack | shader | datapack
    String? gameVersion,
    String? loader,
    String index = 'relevance',
    List<String> categories = const [],
    int limit = 20,
    int offset = 0,
  }) async {
    final facets = [
      ['project_type:$projectType'],
      if (gameVersion != null) ['versions:$gameVersion'],
      if (loader != null && (projectType == 'mod' || projectType == 'shader'))
        ['categories:$loader'],
      // Each extra category is its own AND group, matching how Modrinth's
      // own filter sidebar narrows results.
      for (final category in categories) ['categories:$category'],
    ];
    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'query': query,
      'limit': '$limit',
      'offset': '$offset',
      'index': index,
      'facets': jsonEncode(facets),
    });
    final json = await _getJson(uri);
    return ModrinthSearchResult(
      hits: (json['hits'] as List)
          .map((e) => ModrinthSearchHit.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalHits: (json['total_hits'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ModrinthProject> getProject(String idOrSlug) async {
    final json = await _getJson(Uri.parse('$_base/project/$idOrSlug'));
    return ModrinthProject.fromJson(json);
  }

  Future<List<ModrinthTeamMember>> getProjectMembers(String idOrSlug) async {
    final list = await _getJsonList(Uri.parse('$_base/project/$idOrSlug/members'));
    return list
        .map((e) => ModrinthTeamMember.fromJson(e as Map<String, dynamic>))
        .where((m) => m.username.isNotEmpty)
        .toList();
  }

  Future<List<ModrinthVersion>> getProjectVersions(
    String idOrSlug, {
    String? gameVersion,
    String? loader,
  }) async {
    final query = <String, String>{};
    if (gameVersion != null) query['game_versions'] = jsonEncode([gameVersion]);
    if (loader != null) query['loaders'] = jsonEncode([loader]);
    final uri = Uri.parse('$_base/project/$idOrSlug/version').replace(queryParameters: query);
    final list = await _getJsonList(uri);
    return list.map((e) => ModrinthVersion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ModrinthVersion> getVersion(String versionId) async {
    final json = await _getJson(Uri.parse('$_base/version/$versionId'));
    return ModrinthVersion.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response res;
    try {
      res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ModrinthApiException('Could not reach Modrinth. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw ModrinthApiException('Modrinth request failed (${res.statusCode}).');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getJsonList(Uri uri) async {
    final http.Response res;
    try {
      res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ModrinthApiException('Could not reach Modrinth. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw ModrinthApiException('Modrinth request failed (${res.statusCode}).');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }
}

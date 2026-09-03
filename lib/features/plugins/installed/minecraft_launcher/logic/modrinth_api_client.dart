import 'dart:convert';

import 'package:http/http.dart' as http;

class ModrinthApiException implements Exception {
  ModrinthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

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

  factory ModrinthSearchHit.fromJson(Map<String, dynamic> json) => ModrinthSearchHit(
        projectId: json['project_id'] as String,
        slug: json['slug'] as String? ?? json['project_id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        description: json['description'] as String? ?? '',
        iconUrl: json['icon_url'] as String?,
        downloads: (json['downloads'] as num?)?.toInt() ?? 0,
        follows: (json['follows'] as num?)?.toInt() ?? 0,
        projectType: json['project_type'] as String? ?? 'mod',
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
      );
}

class ModrinthSearchResult {
  ModrinthSearchResult({required this.hits, required this.totalHits});
  final List<ModrinthSearchHit> hits;
  final int totalHits;
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
    required this.gallery,
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
  final List<String> gallery;

  factory ModrinthProject.fromJson(Map<String, dynamic> json) => ModrinthProject(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        body: json['body'] as String? ?? '',
        iconUrl: json['icon_url'] as String?,
        downloads: (json['downloads'] as num?)?.toInt() ?? 0,
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        gameVersions: (json['game_versions'] as List?)?.cast<String>() ?? const [],
        loaders: (json['loaders'] as List?)?.cast<String>() ?? const [],
        sourceUrl: (json['source_url'] as String?),
        issuesUrl: (json['issues_url'] as String?),
        wikiUrl: (json['wiki_url'] as String?),
        gallery: ((json['gallery'] as List?) ?? const [])
            .map((e) => (e as Map<String, dynamic>)['url'] as String)
            .toList(),
      );
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
    required this.gameVersions,
    required this.loaders,
    required this.files,
    required this.dependencies,
    required this.datePublished,
  });

  final String id;
  final String projectId;
  final String versionNumber;
  final String name;
  final List<String> gameVersions;
  final List<String> loaders;
  final List<ModrinthVersionFile> files;
  final List<ModrinthDependency> dependencies;
  final DateTime datePublished;

  ModrinthVersionFile get primaryFile => files.firstWhere(
        (f) => f.primary,
        orElse: () => files.first,
      );

  factory ModrinthVersion.fromJson(Map<String, dynamic> json) => ModrinthVersion(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        versionNumber: json['version_number'] as String? ?? '',
        name: json['name'] as String? ?? '',
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
      );
}

/// Thin client for Modrinth's public v2 API — read-only, no auth required.
/// Used for browsing/installing mods, resource packs, shader packs and
/// datapacks (Modrinth calls all of these "projects", distinguished by
/// `project_type`).
class ModrinthApiClient {
  ModrinthApiClient._();
  static final ModrinthApiClient instance = ModrinthApiClient._();

  static const _base = 'https://api.modrinth.com/v2';

  // Modrinth asks integrations to identify themselves with a descriptive
  // User-Agent rather than a registered API key for read-only usage.
  static const _headers = {'User-Agent': 'luma-app/minecraft-launcher (github.com/Hyperlinkhyper1/luma-app)'};

  Future<ModrinthSearchResult> search({
    String query = '',
    required String projectType, // mod | resourcepack | shader | datapack
    String? gameVersion,
    String? loader,
    int limit = 20,
    int offset = 0,
  }) async {
    final facets = [
      ['project_type:$projectType'],
      if (gameVersion != null) ['versions:$gameVersion'],
      if (loader != null && (projectType == 'mod' || projectType == 'shader'))
        ['categories:$loader'],
    ];
    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'query': query,
      'limit': '$limit',
      'offset': '$offset',
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

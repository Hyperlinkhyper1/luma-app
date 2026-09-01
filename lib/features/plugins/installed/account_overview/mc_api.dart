import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mc_models.dart';

/// Raised when a Minecraft platform answers with something the UI should
/// explain rather than swallow.
class McApiException implements Exception {
  McApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Raw result of a connection test, so the UI can show why a key was
/// rejected instead of the generic error [McApiException] wraps it in.
class McKeyTestResult {
  const McKeyTestResult({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  bool get ok => statusCode == 200;
}

/// Modrinth asks every client to identify itself with a contactable
/// User-Agent, and refuses generic ones.
const _userAgent = 'luma/1.0 (account-overview plugin; +https://github.com)';

/// Read-only client for Modrinth.
///
/// Totals are public, so the common case needs no credential at all. A token
/// only unlocks [fetchDownloadHistory], which is the one thing that turns a
/// Modrinth trend graph into real history instead of a line luma has to grow
/// itself.
class ModrinthApi {
  ModrinthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.modrinth.com/v2';
  static const _v3 = 'https://api.modrinth.com/v3';

  void dispose() => _client.close();

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
        if (token != null && token.isNotEmpty) 'Authorization': token,
      };

  Future<dynamic> _get(String url, {String? token}) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers(token))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (response.statusCode == 404) {
      throw McApiException('Modrinth has no user by that name.',
          statusCode: 404);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw McApiException(
        'Modrinth rejected the token. Check it has the analytics scope.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw McApiException('Modrinth rate limit reached. Try again shortly.',
          statusCode: 429);
    }
    throw McApiException(
      'Modrinth returned HTTP ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  /// The creator and everything they have published.
  Future<({McCreator creator, List<McProject> projects})> fetchCreator(
    String username, {
    String? token,
  }) async {
    final user = await _get('$_base/user/$username', token: token);
    if (user is! Map<String, dynamic>) {
      throw McApiException('Modrinth returned an unexpected user payload.');
    }

    final id = user['id'] as String? ?? username;
    final creator = McCreator(
      platform: McPlatform.modrinth,
      handle: user['username'] as String? ?? username,
      displayName: user['name'] as String?,
      avatarUrl: user['avatar_url'] as String?,
      url: 'https://modrinth.com/user/${user['username'] ?? username}',
    );

    final raw = await _get('$_base/user/$id/projects', token: token);
    final projects = <McProject>[];
    if (raw is List) {
      for (final entry in raw.cast<Map<String, dynamic>>()) {
        final slug = entry['slug'] as String? ?? entry['id'] as String? ?? '';
        final type = entry['project_type'] as String? ?? 'mod';
        projects.add(McProject(
          platform: McPlatform.modrinth,
          id: entry['id'] as String? ?? slug,
          slug: slug,
          name: entry['title'] as String? ?? slug,
          url: 'https://modrinth.com/$type/$slug',
          summary: entry['description'] as String?,
          iconUrl: entry['icon_url'] as String?,
          kind: type,
          downloads: (entry['downloads'] as num?)?.toInt() ?? 0,
          followers: (entry['followers'] as num?)?.toInt() ?? 0,
          updatedAt: DateTime.tryParse(entry['updated'] as String? ?? ''),
        ));
      }
    }
    projects.sort((a, b) => b.downloads.compareTo(a.downloads));
    return (creator: creator, projects: projects);
  }

  /// Real per-day download counts for the given projects.
  ///
  /// This is the v3 analytics endpoint, which is in beta and needs a token
  /// carrying the analytics scope — so every failure here is soft. Returns a
  /// map of project id to day-to-gain, or an empty map when it is not
  /// available; losing backfill must never lose the totals.
  Future<Map<String, Map<DateTime, int>>> fetchDownloadHistory(
    List<String> projectIds, {
    required String token,
    int days = 180,
  }) async {
    if (projectIds.isEmpty || token.isEmpty) return {};

    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    final uri = Uri.parse('$_v3/analytics/downloads').replace(
      queryParameters: {
        'project_ids': jsonEncode(projectIds),
        'start_date': start.toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
        'resolution_minutes': '1440',
      },
    );

    try {
      final response = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return {};

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return {};

      // Shape: { "<project id>": { "<unix seconds>": <count> } }. Parsed
      // leniently because v3 is still moving.
      final out = <String, Map<DateTime, int>>{};
      for (final entry in body.entries) {
        final buckets = entry.value;
        if (buckets is! Map) continue;
        final series = <DateTime, int>{};
        for (final bucket in buckets.entries) {
          final seconds = int.tryParse(bucket.key.toString());
          final count = (bucket.value as num?)?.toInt();
          if (seconds == null || count == null) continue;
          final at = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          final day = DateTime(at.year, at.month, at.day);
          series[day] = (series[day] ?? 0) + count;
        }
        if (series.isNotEmpty) out[entry.key] = series;
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}

/// Read-only client for CurseForge.
///
/// Everything needs the user's own eternal API key in an `x-api-key` header;
/// there is no anonymous access and no username lookup, which is why the
/// author is identified by numeric id.
class CurseForgeApi {
  CurseForgeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.curseforge.com/v1';

  /// CurseForge's game id for Minecraft.
  static const minecraftGameId = 432;

  void dispose() => _client.close();

  Map<String, String> _headers(String apiKey) => {
        'Accept': 'application/json',
        'x-api-key': apiKey,
        'User-Agent': _userAgent,
      };

  /// Hits the cheapest possible endpoint and hands back the raw status and
  /// body, since [_get] only ever surfaces a generic "rejected" message and
  /// the UI's test button needs the actual reason.
  Future<McKeyTestResult> testKey(String apiKey) async {
    final response = await _client
        .get(Uri.parse('$_base/games'), headers: _headers(apiKey))
        .timeout(const Duration(seconds: 30));
    return McKeyTestResult(
      statusCode: response.statusCode,
      body: utf8.decode(response.bodyBytes),
    );
  }

  Future<dynamic> _get(String url, String apiKey) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers(apiKey))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw McApiException(
        'CurseForge rejected the API key. Generate one in the CurseForge '
        'for Studios console.',
        statusCode: response.statusCode,
      );
    }
    throw McApiException(
      'CurseForge returned HTTP ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  McProject _project(Map<String, dynamic> mod) {
    final links = mod['links'] as Map<String, dynamic>?;
    final logo = mod['logo'] as Map<String, dynamic>?;
    final slug = mod['slug'] as String? ?? '';
    return McProject(
      platform: McPlatform.curseforge,
      id: (mod['id'] ?? '').toString(),
      slug: slug,
      name: mod['name'] as String? ?? slug,
      url: links?['websiteUrl'] as String? ??
          'https://www.curseforge.com/minecraft/mc-mods/$slug',
      summary: mod['summary'] as String?,
      iconUrl: logo?['thumbnailUrl'] as String? ?? logo?['url'] as String?,
      kind: _kindFromClassId((mod['classId'] as num?)?.toInt()),
      downloads: (mod['downloadCount'] as num?)?.toInt() ?? 0,
      followers: (mod['thumbsUpCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(mod['dateModified'] as String? ?? ''),
    );
  }

  /// CurseForge identifies content type by a numeric class id. Only the
  /// Minecraft ones are named; anything else falls back to a neutral label
  /// rather than a wrong one.
  static String _kindFromClassId(int? classId) => switch (classId) {
        6 => 'mod',
        12 => 'resourcepack',
        17 => 'world',
        4471 => 'modpack',
        4546 => 'customization',
        4559 => 'addon',
        6552 => 'shader',
        6945 => 'datapack',
        _ => 'project',
      };

  /// Every Minecraft project owned by an author id.
  ///
  /// `primaryAuthorId` is the ownership filter; `authorId` would also return
  /// projects the user merely contributes to, whose download counts are not
  /// theirs to claim.
  Future<List<McProject>> fetchAuthorProjects(
    String apiKey,
    String authorId, {
    int maxPages = 6,
    int pageSize = 50,
  }) async {
    final out = <McProject>[];
    for (var page = 0; page < maxPages; page++) {
      final body = await _get(
        '$_base/mods/search?gameId=$minecraftGameId'
        '&primaryAuthorId=$authorId'
        '&pageSize=$pageSize&index=${page * pageSize}',
        apiKey,
      );
      if (body is! Map<String, dynamic>) break;
      final data = body['data'] as List<dynamic>? ?? const [];
      if (data.isEmpty) break;
      out.addAll(data.cast<Map<String, dynamic>>().map(_project));
      if (data.length < pageSize) break;
    }
    out.sort((a, b) => b.downloads.compareTo(a.downloads));
    return out;
  }

  /// Looks up specific projects by numeric id, for people tracking a
  /// hand-picked list instead of a whole author.
  Future<List<McProject>> fetchProjectsByIds(
    String apiKey,
    List<String> ids,
  ) async {
    final out = <McProject>[];
    for (final id in ids) {
      try {
        final body = await _get('$_base/mods/$id', apiKey);
        if (body is! Map<String, dynamic>) continue;
        final mod = body['data'];
        if (mod is Map<String, dynamic>) out.add(_project(mod));
      } catch (_) {
        // One dead id must not lose the rest of the list.
      }
    }
    out.sort((a, b) => b.downloads.compareTo(a.downloads));
    return out;
  }

  /// Resolves a project slug (from a CurseForge URL) to a project, so the
  /// user can paste a link instead of hunting for a numeric id.
  Future<McProject?> findBySlug(String apiKey, String slug) async {
    final body = await _get(
      '$_base/mods/search?gameId=$minecraftGameId'
      '&slug=${Uri.encodeQueryComponent(slug)}&pageSize=5',
      apiKey,
    );
    if (body is! Map<String, dynamic>) return null;
    final data = body['data'] as List<dynamic>? ?? const [];
    if (data.isEmpty) return null;
    return _project(data.first as Map<String, dynamic>);
  }

  /// Pulls the slug out of a CurseForge project URL, or returns the input
  /// unchanged when it already looks like a slug.
  static String? slugFromInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.host.contains('curseforge.com')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.last;
      return null;
    }
    if (RegExp(r'^[a-z0-9][a-z0-9-]*$', caseSensitive: false).hasMatch(text)) {
      return text;
    }
    return null;
  }
}

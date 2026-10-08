import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../l10n/current_l.dart';
import '../../account_overview/mc_credentials.dart';
import 'modrinth_api_client.dart';

/// Thrown when CurseForge is asked for something before the user has given
/// the launcher an API key — the UI turns this into a "add your key" prompt
/// rather than a generic failure.
class CurseForgeKeyMissingException extends ModrinthApiException {
  CurseForgeKeyMissingException()
      : super(currentL.mcCurseForgeNeedsKey);
}

/// Read-only CurseForge client for the launcher's browse and install flow.
///
/// CurseForge serves nothing without an `x-api-key`, so it uses the user's
/// own key, shared with the Account Overview plugin through
/// [McCredentialStore] — enter it once, both plugins see it. The key only
/// ever goes to api.curseforge.com.
///
/// Every response is mapped onto the Modrinth models the launcher already
/// renders and installs, with ids prefixed by [idPrefix] so the rest of the
/// launcher can tell the two catalogues apart from an id alone (installed
/// rows, dependency lookups and update checks all key on it).
class CurseForgeApiClient {
  CurseForgeApiClient._();
  static final CurseForgeApiClient instance = CurseForgeApiClient._();

  static const idPrefix = 'cf:';
  static const _base = 'https://api.curseforge.com/v1';
  static const _minecraftGameId = 432;

  /// CurseForge's class ids for the content kinds the launcher browses.
  static const _classIds = {'mod': 6, 'resourcepack': 12, 'shader': 6552};

  /// CurseForge `modLoaderType` values for the loaders the launcher runs.
  static const _loaderTypes = {'forge': 1, 'fabric': 4, 'quilt': 5, 'neoforge': 6};

  /// The launcher's sort keys mapped to CurseForge `sortField` values.
  static const _sortFields = {
    'relevance': 2,
    'downloads': 6,
    'follows': 2,
    'newest': 11,
    'updated': 3,
  };

  /// CurseForge refuses any page whose end lies past this offset.
  static const _maxResultWindow = 10000;

  String? _apiKey;
  final _projectCache = <String, ModrinthProject>{};

  static bool isCurseForgeId(String id) => id.startsWith(idPrefix);

  static String _rawId(String id) =>
      isCurseForgeId(id) ? id.substring(idPrefix.length) : id;

  /// Whether a key is stored — checked before showing CurseForge results so
  /// the browse page can ask for one up front.
  Future<bool> hasKey() async => (await _key(required: false)) != null;

  Future<String?> _key({bool required = true}) async {
    if (_apiKey != null) return _apiKey;
    final store = await McCredentialStore.load();
    final key = (await store.read())?.curseforgeApiKey?.trim();
    if (key == null || key.isEmpty) {
      if (required) throw CurseForgeKeyMissingException();
      return null;
    }
    return _apiKey = key;
  }

  /// Saves (or, with an empty [key], removes) the shared CurseForge key.
  Future<void> saveKey(String key) async {
    final store = await McCredentialStore.load();
    final current = await store.read() ?? McCredentials();
    final trimmed = key.trim();
    await store.save(McCredentials(
      curseforgeApiKey: trimmed,
      curseforgeAuthorId: current.curseforgeAuthorId,
      curseforgeProjectIds: current.curseforgeProjectIds,
      modrinthUsername: current.modrinthUsername,
      modrinthToken: current.modrinthToken,
      pmcUsername: current.pmcUsername,
    ));
    _apiKey = trimmed.isEmpty ? null : trimmed;
    _projectCache.clear();
  }

  Future<ModrinthSearchResult> search({
    String query = '',
    required String projectType,
    String? gameVersion,
    String? loader,
    String index = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async {
    if (offset >= _maxResultWindow) {
      return ModrinthSearchResult(hits: const [], totalHits: _maxResultWindow);
    }
    final loaderType = projectType == 'mod' ? _loaderTypes[loader] : null;
    final params = <String, String>{
      'gameId': '$_minecraftGameId',
      'classId': '${_classIds[projectType] ?? _classIds['mod']}',
      if (query.isNotEmpty) 'searchFilter': query,
      'gameVersion': ?gameVersion,
      if (loaderType != null) 'modLoaderType': '$loaderType',
      'sortField': '${_sortFields[index] ?? 2}',
      'sortOrder': 'desc',
      'index': '$offset',
      'pageSize': '${limit.clamp(1, _maxResultWindow - offset).clamp(1, 50)}',
    };
    final json = await _get(Uri.parse('$_base/mods/search').replace(queryParameters: params));
    final data = (json['data'] as List?) ?? const [];
    final pagination = json['pagination'] as Map<String, dynamic>?;
    final total = (pagination?['totalCount'] as num?)?.toInt() ?? data.length;
    return ModrinthSearchResult(
      hits: data.map((e) => hitFromJson(e as Map<String, dynamic>)).toList(),
      totalHits: total > _maxResultWindow ? _maxResultWindow : total,
    );
  }

  Future<ModrinthProject> getProject(String id) async {
    final raw = _rawId(id);
    final cached = _projectCache[raw];
    if (cached != null) return cached;
    final results = await Future.wait([
      _get(Uri.parse('$_base/mods/$raw')),
      _get(Uri.parse('$_base/mods/$raw/description')).then<Map<String, dynamic>?>(
        (json) => json,
        onError: (_) => null,
      ),
    ]);
    final project = projectFromJson(
      results[0]!['data'] as Map<String, dynamic>,
      descriptionHtml: results[1]?['data'] as String? ?? '',
    );
    return _projectCache[raw] = project;
  }

  /// CurseForge has no team endpoint; the project's author list stands in
  /// for it.
  Future<List<ModrinthTeamMember>> getProjectMembers(String id) async {
    final json = await _get(Uri.parse('$_base/mods/${_rawId(id)}'));
    final authors = ((json['data'] as Map<String, dynamic>)['authors'] as List?) ?? const [];
    return [
      for (final (i, a) in authors.indexed)
        ModrinthTeamMember(
          username: (a as Map<String, dynamic>)['name'] as String? ?? '',
          role: i == 0 ? currentL.mcTeamRoleOwner : currentL.mcTeamRoleMember,
          avatarUrl: null,
        ),
    ].where((m) => m.username.isNotEmpty).toList();
  }

  /// Files for a project, newest first, narrowed to [gameVersion] and
  /// [loader] the way Modrinth's version list is.
  Future<List<ModrinthVersion>> getProjectVersions(
    String id, {
    String? gameVersion,
    String? loader,
  }) async {
    final loaderType = _loaderTypes[loader];
    final versions = <ModrinthVersion>[];
    const pageSize = 50;
    for (var page = 0; page < 4; page++) {
      final uri = Uri.parse('$_base/mods/${_rawId(id)}/files').replace(queryParameters: {
        'gameVersion': ?gameVersion,
        if (loaderType != null) 'modLoaderType': '$loaderType',
        'index': '${page * pageSize}',
        'pageSize': '$pageSize',
      });
      final data = ((await _get(uri))['data'] as List?) ?? const [];
      versions.addAll(data.map((e) => versionFromJson(e as Map<String, dynamic>)));
      if (data.length < pageSize) break;
    }
    versions.sort((a, b) => b.datePublished.compareTo(a.datePublished));
    return versions;
  }

  Future<ModrinthVersion> getVersion(String versionId) async {
    final fileId = int.tryParse(_rawId(versionId));
    if (fileId == null) throw ModrinthApiException(currentL.mcCurseForgeUnknownFile(versionId));
    final json = await _post(
      Uri.parse('$_base/mods/files'),
      {'fileIds': [fileId]},
    );
    final data = (json['data'] as List?) ?? const [];
    if (data.isEmpty) throw ModrinthApiException(currentL.mcCurseForgeFileGone);
    return versionFromJson(data.first as Map<String, dynamic>);
  }

  // ── Mapping ───────────────────────────────────────────────────────────

  static String kindFromClassId(int? classId) => switch (classId) {
        12 => 'resourcepack',
        6552 => 'shader',
        _ => 'mod',
      };

  static String _websiteSection(String kind) => switch (kind) {
        'resourcepack' => 'texture-packs',
        'shader' => 'shaders',
        _ => 'mc-mods',
      };

  static String _pageUrl(Map<String, dynamic> json, String kind, String slug) =>
      _nonEmpty((json['links'] as Map<String, dynamic>?)?['websiteUrl'] as String?) ??
      'https://www.curseforge.com/minecraft/${_websiteSection(kind)}/$slug';

  static List<String> _categorySlugs(Map<String, dynamic> json) => [
        for (final c in (json['categories'] as List?) ?? const [])
          if ((c as Map<String, dynamic>)['slug'] is String) c['slug'] as String,
      ];

  static ModrinthSearchHit hitFromJson(Map<String, dynamic> json) {
    final id = '${json['id']}';
    final kind = kindFromClassId((json['classId'] as num?)?.toInt());
    final logo = json['logo'] as Map<String, dynamic>?;
    final screenshots = [
      for (final s in (json['screenshots'] as List?) ?? const [])
        if ((s as Map<String, dynamic>)['url'] is String) s['url'] as String,
    ];
    final authors = (json['authors'] as List?) ?? const [];
    final gameVersions = <String>{
      for (final f in (json['latestFilesIndexes'] as List?) ?? const [])
        if ((f as Map<String, dynamic>)['gameVersion'] is String) f['gameVersion'] as String,
    }.toList();
    final categories = _categorySlugs(json);
    return ModrinthSearchHit(
      projectId: '$idPrefix$id',
      slug: json['slug'] as String? ?? id,
      title: json['name'] as String? ?? currentL.commonUntitled,
      description: json['summary'] as String? ?? '',
      iconUrl: _nonEmpty(logo?['thumbnailUrl'] as String?) ?? _nonEmpty(logo?['url'] as String?),
      downloads: (json['downloadCount'] as num?)?.toInt() ?? 0,
      follows: (json['thumbsUpCount'] as num?)?.toInt() ?? 0,
      projectType: kind,
      categories: categories,
      displayCategories: categories,
      author: authors.isEmpty
          ? null
          : _nonEmpty((authors.first as Map<String, dynamic>)['name'] as String?),
      dateModified: DateTime.tryParse(json['dateModified'] as String? ?? ''),
      gallery: screenshots,
      featuredGallery: screenshots.isEmpty ? null : screenshots.first,
      color: null,
      clientSide: 'unknown',
      serverSide: 'unknown',
      gameVersions: gameVersions,
    );
  }

  static ModrinthProject projectFromJson(
    Map<String, dynamic> json, {
    String descriptionHtml = '',
  }) {
    final id = '${json['id']}';
    final slug = json['slug'] as String? ?? id;
    final kind = kindFromClassId((json['classId'] as num?)?.toInt());
    final links = json['links'] as Map<String, dynamic>?;
    final logo = json['logo'] as Map<String, dynamic>?;
    final indexes = (json['latestFilesIndexes'] as List?) ?? const [];
    final gameVersions = <String>{};
    final loaders = <String>{};
    for (final f in indexes) {
      final m = f as Map<String, dynamic>;
      if (m['gameVersion'] is String) gameVersions.add(m['gameVersion'] as String);
      final loader = _loaderName((m['modLoader'] as num?)?.toInt());
      if (loader != null) loaders.add(loader);
    }
    return ModrinthProject(
      id: '$idPrefix$id',
      slug: slug,
      title: json['name'] as String? ?? currentL.commonUntitled,
      description: json['summary'] as String? ?? '',
      body: htmlToMarkdown(descriptionHtml),
      iconUrl: _nonEmpty(logo?['thumbnailUrl'] as String?) ?? _nonEmpty(logo?['url'] as String?),
      downloads: (json['downloadCount'] as num?)?.toInt() ?? 0,
      followers: (json['thumbsUpCount'] as num?)?.toInt() ?? 0,
      gameVersions: gameVersions.toList(),
      loaders: loaders.toList(),
      sourceUrl: _nonEmpty(links?['sourceUrl'] as String?),
      issuesUrl: _nonEmpty(links?['issuesUrl'] as String?),
      wikiUrl: _nonEmpty(links?['wikiUrl'] as String?),
      discordUrl: null,
      gallery: [
        for (final s in (json['screenshots'] as List?) ?? const [])
          if ((s as Map<String, dynamic>)['url'] is String)
            ModrinthGalleryImage(
              url: s['url'] as String,
              title: _nonEmpty(s['title'] as String?),
              description: _nonEmpty(s['description'] as String?),
              featured: false,
            ),
      ],
      categories: _categorySlugs(json),
      projectType: kind,
      clientSide: 'unknown',
      serverSide: 'unknown',
      licenseName: null,
      licenseUrl: null,
      published: DateTime.tryParse(json['dateCreated'] as String? ?? ''),
      updated: DateTime.tryParse(json['dateModified'] as String? ?? ''),
      color: null,
      pageUrl: _pageUrl(json, kind, slug),
    );
  }

  /// A CurseForge file as a Modrinth version. `downloadUrl` is null when
  /// the author has opted out of downloads outside CurseForge; the file
  /// keeps an empty url and the installer refuses it with an explanation
  /// rather than going around the author's choice.
  static ModrinthVersion versionFromJson(Map<String, dynamic> json) {
    final tags = ((json['gameVersions'] as List?) ?? const []).cast<String>();
    final sha1 = [
      for (final h in (json['hashes'] as List?) ?? const [])
        if ((h as Map<String, dynamic>)['algo'] == 1) h['value'] as String? ?? '',
    ].firstOrNull ?? '';
    final displayName = json['displayName'] as String? ?? json['fileName'] as String? ?? '';
    return ModrinthVersion(
      id: '$idPrefix${json['id']}',
      projectId: '$idPrefix${json['modId']}',
      versionNumber: displayName,
      name: displayName,
      versionType: switch ((json['releaseType'] as num?)?.toInt()) {
        2 => 'beta',
        3 => 'alpha',
        _ => 'release',
      },
      gameVersions: tags.where((t) => RegExp(r'^\d+\.\d+').hasMatch(t)).toList(),
      loaders: tags
          .map((t) => t.toLowerCase())
          .where((t) => _loaderTypes.containsKey(t))
          .toList(),
      files: [
        ModrinthVersionFile(
          url: json['downloadUrl'] as String? ?? '',
          filename: json['fileName'] as String? ?? '',
          sha1: sha1,
          size: (json['fileLength'] as num?)?.toInt() ?? 0,
          primary: true,
        ),
      ],
      dependencies: [
        for (final d in (json['dependencies'] as List?) ?? const [])
          ModrinthDependency(
            projectId: '$idPrefix${(d as Map<String, dynamic>)['modId']}',
            dependencyType: switch ((d['relationType'] as num?)?.toInt()) {
              1 => 'embedded',
              3 => 'required',
              5 => 'incompatible',
              _ => 'optional',
            },
          ),
      ],
      datePublished: DateTime.tryParse(json['fileDate'] as String? ?? '') ?? DateTime(2000),
      downloads: (json['downloadCount'] as num?)?.toInt() ?? 0,
      changelog: '',
    );
  }

  static String? _loaderName(int? type) => switch (type) {
        1 => 'forge',
        4 => 'fabric',
        5 => 'quilt',
        6 => 'neoforge',
        _ => null,
      };

  /// CurseForge descriptions are plain HTML. The project page's renderer
  /// reads Markdown with a little inline HTML, so the block-level tags are
  /// turned into the Markdown it understands; only links, images and line
  /// breaks — which it folds itself — survive as tags.
  static String htmlToMarkdown(String html) {
    var text = html.replaceAll('\r\n', '\n').replaceAll('\n', ' ');
    text = text.replaceAllMapped(
      RegExp(r'<h([1-6])[^>]*>', caseSensitive: false),
      (m) => '\n\n${'#' * int.parse(m.group(1)!)} ',
    );
    text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ');
    text = text.replaceAll(RegExp(r'<hr[^>]*>', caseSensitive: false), '\n\n---\n\n');
    text = text.replaceAll(
      RegExp(r'</(p|h[1-6]|ul|ol|div|blockquote|table|tr)>', caseSensitive: false),
      '\n\n',
    );
    text = text.replaceAll(
      RegExp(r'<(?!/?(img|a|br)\b)[^>]*>', caseSensitive: false),
      '',
    );
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text
        .split('\n')
        .map((l) => l.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ── HTTP ──────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-api-key': (await _key())!,
        'User-Agent': 'luma-app/minecraft-launcher (github.com/Hyperlinkhyper1/luma-app)',
      };

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final headers = await _headers();
    return _decode(() => http.get(uri, headers: headers));
  }

  Future<Map<String, dynamic>> _post(Uri uri, Object body) async {
    final headers = await _headers();
    return _decode(() => http.post(uri, headers: headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> _decode(Future<http.Response> Function() send) async {
    final http.Response res;
    try {
      res = await send().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ModrinthApiException(currentL.mcCurseForgeUnreachable);
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      _apiKey = null;
      throw ModrinthApiException(currentL.mcCurseForgeKeyRejected);
    }
    if (res.statusCode != 200) {
      throw ModrinthApiException(currentL.mcCurseForgeRequestFailed('${res.statusCode}'));
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}

String? _nonEmpty(String? value) =>
    (value == null || value.trim().isEmpty) ? null : value;

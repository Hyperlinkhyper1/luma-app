part of 'api.dart';

/// The Team Clipboard's assets library (see `team_library.dart`). Everyone
/// on the team can browse it and ask for an update check; only a lead picks
/// which mods are in it.
extension TeamLibraryApi on Api {
  Response? _teamLibraryLeadOnly(StoredUser user) {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    if (role != 'lead') {
      return errorResponse(403, 'forbidden',
          'Only a team lead can choose the library\'s mods.');
    }
    return null;
  }

  Map<String, dynamic> _teamLibraryModJson(TeamLibraryMod m) => {
        'id': m.projectId,
        'slug': m.slug,
        'title': m.title,
        'projectType': m.projectType,
        'url': 'https://modrinth.com/${m.projectType}/${m.slug}',
        'iconUrl': m.iconUrl,
        'description': m.description,
        'addedBy': _teamName(m.addedById, m.addedByEmail),
        'addedAtMs': m.addedAtMs,
        'loaders': m.loaders,
        'gameVersions': m.gameVersions,
        'loader': m.loader,
        'gameVersion': m.gameVersion,
        'state': m.state,
        'error': m.error,
        'version': m.version?.toJson(),
        'loadedAtMs': m.loadedAtMs,
        'checkedAtMs': m.checkedAtMs,
        'fileCount': m.fileCount,
        'bytes': m.bytes,
        'skipped': m.skipped,
        'namespaces': m.namespaces,
        'history': m.history,
      };

  Response _teamLibraryResponse(int status, String role) =>
      jsonResponse(status, {
        'revision': teamLibrary.revision,
        'canManage': role == 'lead',
        'busy': teamLibrary.busy,
        'mods': [for (final m in teamLibrary.mods) _teamLibraryModJson(m)],
      });

  /// Every mod in the library, or `unchanged` when `?since=` is already the
  /// latest revision.
  Response _teamLibraryGet(Request request, StoredUser user) {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final since = int.tryParse(request.url.queryParameters['since'] ?? '');
    if (since == teamLibrary.revision) {
      return jsonResponse(
          200, {'revision': teamLibrary.revision, 'unchanged': true});
    }
    return _teamLibraryResponse(200, role!);
  }

  /// Modrinth's mods and resource packs matching `?q=`, for a lead adding
  /// one.
  Future<Response> _teamLibrarySearch(Request request, StoredUser user) async {
    final refused = _teamLibraryLeadOnly(user);
    if (refused != null) return refused;
    final query = (request.url.queryParameters['q'] ?? '').trim();
    if (query.length > 100) {
      return errorResponse(400, 'bad_query', 'Search for something shorter.');
    }
    try {
      final hits = await teamLibrary.search(query);
      return jsonResponse(200, {
        'hits': [for (final h in hits) h.json],
      });
    } on TeamLibraryException catch (e) {
      return errorResponse(502, 'modrinth', e.message);
    }
  }

  /// Adds `{projectId, loader?, gameVersion?}` and starts unpacking it.
  Future<Response> _teamLibraryAdd(Request request, StoredUser user) async {
    final refused = _teamLibraryLeadOnly(user);
    if (refused != null) return refused;
    final body = await _teamJsonBody(request);
    final projectId = body?['projectId'];
    final (loaderOk, loader) = cleanTeamLibraryFilter(body?['loader']);
    final (versionOk, gameVersion) =
        cleanTeamLibraryFilter(body?['gameVersion']);
    if (projectId is! String ||
        !isTeamLibraryProjectId(projectId) ||
        !loaderOk ||
        !versionOk) {
      return errorResponse(400, 'bad_request', 'Pick a mod from Modrinth.');
    }
    try {
      await teamLibrary.add(
        projectId: projectId,
        loader: loader,
        gameVersion: gameVersion,
        userId: user.id,
        email: user.email,
      );
    } on TeamLibraryException catch (e) {
      return errorResponse(409, 'library', e.message);
    }
    return _teamLibraryResponse(201, 'lead');
  }

  /// Changes `{loader, gameVersion}` for a mod; both null take any.
  Future<Response> _teamLibraryUpdate(Request request, StoredUser user) async {
    final refused = _teamLibraryLeadOnly(user);
    if (refused != null) return refused;
    final id = request.params['id'] ?? '';
    if (teamLibrary.mod(id) == null) {
      return errorResponse(404, 'not_found', 'That mod is not in the library.');
    }
    final body = await _teamJsonBody(request);
    final (loaderOk, loader) = cleanTeamLibraryFilter(body?['loader']);
    final (versionOk, gameVersion) =
        cleanTeamLibraryFilter(body?['gameVersion']);
    if (body == null || !loaderOk || !versionOk) {
      return errorResponse(400, 'bad_request', 'Check the loader and version.');
    }
    await teamLibrary.setFilters(id, loader, gameVersion);
    return _teamLibraryResponse(200, 'lead');
  }

  Future<Response> _teamLibraryRemove(Request request, StoredUser user) async {
    final refused = _teamLibraryLeadOnly(user);
    if (refused != null) return refused;
    if (!await teamLibrary.remove(request.params['id'] ?? '')) {
      return errorResponse(404, 'not_found', 'That mod is not in the library.');
    }
    return _teamLibraryResponse(200, 'lead');
  }

  /// Looks for new versions now: of `{projectId}`, or of every mod.
  Future<Response> _teamLibraryCheck(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final body = await _teamJsonBody(request);
    final projectId = body?['projectId'];
    if (projectId != null && projectId is! String) {
      return errorResponse(400, 'bad_request', 'Pick a mod.');
    }
    teamLibrary.check(projectId as String?);
    return _teamLibraryResponse(200, role!);
  }

  /// A mod's file list: `{versionId, files: [[path, sha1, size], ...]}`.
  Future<Response> _teamLibraryFiles(Request request, StoredUser user) async {
    final (_, refused) = _teamRole(user);
    if (refused != null) return refused;
    final id = request.params['id'] ?? '';
    final index =
        teamLibrary.mod(id) == null ? null : await teamLibrary.readIndex(id);
    if (index == null) {
      return errorResponse(404, 'not_found', 'That mod has no assets yet.');
    }
    return Response(200,
        body: index, headers: {'Content-Type': 'application/json'});
  }

  /// One asset by its SHA-1, as inert bytes the browser may not sniff,
  /// render or run.
  Future<Response> _teamLibraryBlob(Request request, StoredUser user) async {
    final (_, refused) = _teamRole(user);
    if (refused != null) return refused;
    final bytes = await teamLibrary.readBlob(request.params['sha1'] ?? '');
    if (bytes == null) {
      return errorResponse(404, 'not_found', 'That file is gone.');
    }
    return Response(200, body: bytes, headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': 'attachment',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'Cache-Control': 'private, max-age=31536000, immutable',
    });
  }
}

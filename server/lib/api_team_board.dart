part of 'api.dart';

/// The Team Clipboard's endpoints and its Users-tab actions. See
/// `team_board.dart` for what the board is.
extension TeamBoardApi on Api {
  /// The role [user] has on the board, or a 403 when they have none. Every
  /// board endpoint but the board itself starts here, so an account the
  /// operator never added can neither read nor write anything.
  (String?, Response?) _teamRole(StoredUser user) {
    final role = teamBoard.roleOf(user.id);
    if (role == null) {
      return (
        null,
        errorResponse(403, 'team_access_required',
            'Ask the admin to add you to the Team Clipboard.')
      );
    }
    return (role, null);
  }

  /// The name [userId] shows up under: the one they picked for the board,
  /// or else their email's local part, the way the recipe catalogue does.
  /// Empty once the account has been deleted.
  String _teamName(String userId, String email) {
    if (email.isEmpty) return '';
    return teamBoard.nameOf(userId) ?? _teamDefaultName(email);
  }

  static String _teamDefaultName(String email) {
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  /// Whether someone else on the team already goes by [name], in any case,
  /// so nobody can post as a teammate.
  bool _teamNameTaken(String userId, String name) {
    final wanted = name.toLowerCase();
    for (final id in teamBoard.roles.keys) {
      if (id == userId) continue;
      final other = store.usersById[id];
      if (other != null && _teamName(id, other.email).toLowerCase() == wanted) {
        return true;
      }
    }
    return false;
  }

  /// Why [entry] (null for a new one) can't be filed under main thread
  /// [parentId], or null when it can. Main threads are one level deep.
  String? _teamParentProblem(TeamBoardEntry? entry, String parentId) {
    final parent = TeamBoardStore.idPattern.hasMatch(parentId)
        ? teamBoard.entry(parentId)
        : null;
    if (parent == null) return 'That main thread is gone.';
    if (parent.parentId != null) {
      return 'A sub-entry can’t have entries of its own.';
    }
    if (entry != null &&
        (entry.id == parentId || teamBoard.childrenOf(entry.id).isNotEmpty)) {
      return 'A main thread can’t go under another one.';
    }
    if (parent.closed) return 'Reopen the main thread first.';
    return null;
  }

  /// Changes the name this account goes by on the board. An empty name
  /// goes back to the email's.
  Future<Response> _teamNameSet(Request request, StoredUser user) async {
    final (_, refused) = _teamRole(user);
    if (refused != null) return refused;
    final body = await _teamJsonBody(request);
    var name = cleanTeamBoardName(body?['name']);
    if (body == null || name == null) {
      return errorResponse(400, 'bad_name',
          'Pick a name of at most $kTeamBoardMaxNameChars characters.');
    }
    if (name == _teamDefaultName(user.email)) name = '';
    if (name.isNotEmpty && _teamNameTaken(user.id, name)) {
      return errorResponse(
          409, 'name_taken', 'Someone on the team already goes by $name.');
    }
    await teamBoard.setName(user.id, name);
    return jsonResponse(200, {
      'me': _teamName(user.id, user.email),
      'revision': teamBoard.revision,
    });
  }

  Map<String, dynamic> _teamFileJson(
          TeamBoardFile f, StoredUser viewer, TeamBoardPermissions can) =>
      {
        'id': f.id,
        'name': f.name,
        'sizeBytes': f.sizeBytes,
        'uploader': _teamName(f.uploaderId, f.uploaderEmail),
        'mine': f.uploaderId == viewer.id,
        'canRemove': can.canRemoveFile(f),
        'createdAtMs': f.createdAtMs,
      };

  Map<String, dynamic> _teamEntryJson(
      TeamBoardEntry e, StoredUser viewer, String role,
      {bool withMessages = false}) {
    final can = TeamBoardPermissions(e, viewer.id, role);
    final last = e.messages.isEmpty ? null : e.messages.last;
    return {
      'id': e.id,
      'kind': e.kind,
      'title': e.title,
      'brief': e.brief,
      'stage': e.stage,
      'closed': e.closed,
      'author': _teamName(e.authorId, e.authorEmail),
      'mine': can.isAuthor,
      'claimedBy': e.claimedById == null
          ? null
          : _teamName(e.claimedById!, e.claimedByEmail ?? ''),
      'parentId': e.parentId,
      'claimedByMe': e.claimedById == viewer.id,
      'createdAtMs': e.createdAtMs,
      'updatedAtMs': e.updatedAtMs,
      'messageCount': e.messages.length,
      if (last != null)
        'lastMessage': {
          'author': _teamName(last.authorId, last.authorEmail),
          'text': last.text.length > 140
              ? '${last.text.substring(0, 140)}…'
              : last.text,
          'createdAtMs': last.createdAtMs,
        },
      'files': [for (final f in e.files) _teamFileJson(f, viewer, can)],
      'canEdit': can.canEdit,
      'canClose': can.canClose,
      'canDelete': can.canDelete,
      if (withMessages)
        'messages': [
          for (final m in e.messages)
            {
              'id': m.id,
              'author': _teamName(m.authorId, m.authorEmail),
              'mine': m.authorId == viewer.id,
              'text': m.text,
              'createdAtMs': m.createdAtMs,
            }
        ],
    };
  }

  Response _teamEntryResponse(
          int status, TeamBoardEntry e, StoredUser user, String role) =>
      jsonResponse(status, {
        ..._teamEntryJson(e, user, role, withMessages: true),
        'revision': teamBoard.revision,
      });

  /// The whole board, or `unchanged` when `?since=` is already the latest
  /// revision. An account that isn't on the team gets `member: false` and
  /// nothing else, so the app can show who to ask instead of an error.
  Response _teamBoardGet(Request request, StoredUser user) {
    final role = teamBoard.roleOf(user.id);
    if (role == null) {
      return jsonResponse(200, {'member': false, 'email': user.email});
    }
    final since = int.tryParse(request.url.queryParameters['since'] ?? '');
    final base = {
      'member': true,
      'lead': role == 'lead',
      'me': _teamName(user.id, user.email),
      'revision': teamBoard.revision,
    };
    if (since == teamBoard.revision) {
      return jsonResponse(200, {...base, 'unchanged': true});
    }
    return jsonResponse(200, {
      ...base,
      'entries': [
        for (final e in teamBoard.board()) _teamEntryJson(e, user, role)
      ],
    });
  }

  (TeamBoardEntry?, Response?) _teamEntryParam(Request request) {
    final id = request.params['id'] ?? '';
    final entry =
        TeamBoardStore.idPattern.hasMatch(id) ? teamBoard.entry(id) : null;
    if (entry == null) {
      return (null, errorResponse(404, 'not_found', 'That entry is gone.'));
    }
    return (entry, null);
  }

  Future<Map<String, dynamic>?> _teamJsonBody(Request request) async {
    try {
      return await Api._readJson(request);
    } on FormatException {
      return null;
    }
  }

  Response _teamEntryGet(Request request, StoredUser user) {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    return _teamEntryResponse(200, entry!, user, role!);
  }

  Future<Response> _teamEntryCreate(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final body = await _teamJsonBody(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final kind = body['kind'];
    final title = cleanTeamBoardTitle(body['title']);
    final brief = cleanTeamBoardText(body['brief'], kTeamBoardMaxBriefChars);
    if (!kTeamBoardKinds.contains(kind)) {
      return errorResponse(400, 'bad_kind', 'Pick bug, suggestion or model.');
    }
    if (title == null) {
      return errorResponse(400, 'bad_title',
          'Give it a title of at most $kTeamBoardMaxTitleChars characters.');
    }
    if (brief == null) {
      return errorResponse(400, 'bad_brief', 'The brief is too long.');
    }
    if (teamBoard.entryCount >= kTeamBoardMaxEntries) {
      return errorResponse(
          409, 'board_full', 'The board is full. Remove old entries first.');
    }
    final parentId = body['parentId'];
    if (parentId != null && parentId is! String) {
      return errorResponse(400, 'bad_parent', 'Pick a main thread.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = TeamBoardEntry(
      id: TeamBoardStore.newId(),
      kind: kind as String,
      title: title,
      brief: brief,
      authorId: user.id,
      authorEmail: user.email,
      createdAtMs: now,
      updatedAtMs: now,
      parentId: parentId as String?,
    );
    final problem = await teamBoard.mutate(() {
      if (parentId != null) {
        final why = _teamParentProblem(null, parentId);
        if (why != null) return why;
        teamBoard.entry(parentId)!.updatedAtMs = now;
      }
      teamBoard.addEntry(entry);
      return null;
    });
    if (problem != null) return errorResponse(409, 'bad_parent', problem);
    return _teamEntryResponse(201, entry, user, role!);
  }

  Future<Response> _teamEntryUpdate(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    if (!TeamBoardPermissions(entry!, user.id, role!).canEdit) {
      return errorResponse(
          403, 'forbidden', 'Only its author or a team lead can edit this.');
    }
    final body = await _teamJsonBody(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final kind = body['kind'] ?? entry.kind;
    final title = cleanTeamBoardTitle(body['title'] ?? entry.title);
    final brief = cleanTeamBoardText(
        body['brief'] ?? entry.brief, kTeamBoardMaxBriefChars);
    if (!kTeamBoardKinds.contains(kind) || title == null || brief == null) {
      return errorResponse(400, 'bad_request', 'Check the title and brief.');
    }
    final moves = body.containsKey('parentId');
    final parentId = body['parentId'];
    if (parentId != null && parentId is! String) {
      return errorResponse(400, 'bad_parent', 'Pick a main thread.');
    }
    final problem = await teamBoard.mutate(() {
      if (moves && parentId != null && parentId != entry.parentId) {
        final why = _teamParentProblem(entry, parentId as String);
        if (why != null) return why;
      }
      entry
        ..kind = kind as String
        ..title = title
        ..brief = brief
        ..parentId = moves ? parentId as String? : entry.parentId
        ..updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      return null;
    });
    if (problem != null) return errorResponse(409, 'bad_parent', problem);
    return _teamEntryResponse(200, entry, user, role);
  }

  Future<Response> _teamEntryStage(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    final body = await _teamJsonBody(request);
    final stage = body?['stage'];
    if (stage is! String) {
      return errorResponse(400, 'bad_stage', 'Pick a stage.');
    }
    final why =
        TeamBoardPermissions(entry!, user.id, role!).stageRefusal(stage);
    if (why != null) return errorResponse(403, 'forbidden', why);
    await teamBoard.mutate(() {
      switch (stage) {
        case 'idea':
          entry
            ..claimedById = null
            ..claimedByEmail = null;
        case 'claimed':
          entry
            ..claimedById = user.id
            ..claimedByEmail = user.email;
        default:
          if (entry.claimedById == null) {
            entry
              ..claimedById = user.id
              ..claimedByEmail = user.email;
          }
      }
      entry
        ..stage = stage
        ..updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    });
    return _teamEntryResponse(200, entry, user, role);
  }

  /// Closes or reopens the thread. A closed entry sinks to the bottom of
  /// the board and takes no more messages, files or stage changes.
  Future<Response> _teamEntryClose(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    if (!TeamBoardPermissions(entry!, user.id, role!).canClose) {
      return errorResponse(
          403, 'forbidden', 'Only its author or a team lead can close this.');
    }
    final body = await _teamJsonBody(request);
    final closed = body?['closed'];
    if (closed is! bool) {
      return errorResponse(400, 'bad_request', 'Say whether to close it.');
    }
    await teamBoard.mutate(() {
      entry
        ..closed = closed
        ..updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    });
    return _teamEntryResponse(200, entry, user, role);
  }

  Future<Response> _teamEntryDelete(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    if (!TeamBoardPermissions(entry!, user.id, role!).canDelete) {
      return errorResponse(403, 'forbidden',
          'Others have added to this entry. Ask a team lead to remove it.');
    }
    await teamBoard.mutate(() => teamBoard.removeEntry(entry.id));
    for (final f in entry.files) {
      await teamBoard.deleteFile(f.id);
    }
    return jsonResponse(200, {'ok': true, 'revision': teamBoard.revision});
  }

  Future<Response> _teamMessagePost(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    if (!TeamBoardPermissions(entry!, user.id, role!).canPost) {
      return errorResponse(409, 'closed', 'This thread is closed.');
    }
    final body = await _teamJsonBody(request);
    final text = cleanTeamBoardText(body?['text'], kTeamBoardMaxMessageChars,
        required: true);
    if (text == null) {
      return errorResponse(400, 'bad_text',
          'Write a message of at most $kTeamBoardMaxMessageChars characters.');
    }
    if (entry.messages.length >= kTeamBoardMaxMessagesPerEntry) {
      return errorResponse(
          409, 'thread_full', 'This thread is full. Start a new entry.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await teamBoard.mutate(() {
      entry.messages.add(TeamBoardMessage(
        id: TeamBoardStore.newId(),
        authorId: user.id,
        authorEmail: user.email,
        text: text,
        createdAtMs: now,
      ));
      entry.updatedAtMs = now;
    });
    return _teamEntryResponse(201, entry, user, role);
  }

  /// Attaches one file, sent as the raw body with its name in `?name=`.
  Future<Response> _teamFileUpload(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    if (!TeamBoardPermissions(entry!, user.id, role!).canPost) {
      return errorResponse(409, 'closed', 'This thread is closed.');
    }
    final name = cleanTeamBoardFileName(request.url.queryParameters['name']);
    if (name == null) {
      return errorResponse(400, 'bad_file_type',
          'Only .png, .json and .mcmeta files can be attached.');
    }
    if (entry.files.length >= kTeamBoardMaxFilesPerEntry) {
      return errorResponse(409, 'too_many_files',
          'An entry holds at most $kTeamBoardMaxFilesPerEntry files.');
    }
    final bytes = await _readCappedBytes(request, kTeamBoardMaxFileBytes);
    if (bytes == null) {
      return errorResponse(413, 'file_too_large',
          'Files can be at most ${kTeamBoardMaxFileBytes ~/ (1024 * 1024)} MB.');
    }
    final problem = teamBoardFileProblem(name, bytes);
    if (problem != null) {
      return errorResponse(400, 'bad_file_content', problem);
    }
    if (teamBoard.totalFileBytes + bytes.length > kTeamBoardMaxTotalFileBytes) {
      return errorResponse(507, 'board_storage_full',
          'The board has no room left. Remove old files first.');
    }
    final file = TeamBoardFile(
      id: TeamBoardStore.newId(),
      name: name,
      sizeBytes: bytes.length,
      uploaderId: user.id,
      uploaderEmail: user.email,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await teamBoard.writeFile(file.id, bytes);
    final attached = await teamBoard.mutate(() {
      if (teamBoard.entry(entry.id) == null || entry.closed) return false;
      entry.files.add(file);
      entry.updatedAtMs = file.createdAtMs;
      return true;
    });
    if (!attached) {
      await teamBoard.deleteFile(file.id);
      return errorResponse(409, 'closed', 'This thread is closed.');
    }
    return _teamEntryResponse(201, entry, user, role);
  }

  Future<Response> _teamFileDelete(Request request, StoredUser user) async {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    final (entry, missing) = _teamEntryParam(request);
    if (missing != null) return missing;
    final fileId = request.params['fileId'];
    final file = entry!.files.where((f) => f.id == fileId).firstOrNull;
    if (file == null) {
      return errorResponse(404, 'not_found', 'That file is gone.');
    }
    if (!TeamBoardPermissions(entry, user.id, role!).canRemoveFile(file)) {
      return errorResponse(
          403, 'forbidden', 'Only its uploader or a team lead can remove it.');
    }
    await teamBoard.mutate(() {
      entry.files.remove(file);
      entry.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    });
    await teamBoard.deleteFile(file.id);
    return _teamEntryResponse(200, entry, user, role);
  }

  /// Hands a file to any team member, member or lead, open thread or
  /// closed. It always goes out as a download the browser may not sniff,
  /// render or run.
  Future<Response> _teamFileGet(Request request, StoredUser user) async {
    final (_, refused) = _teamRole(user);
    if (refused != null) return refused;
    final found = teamBoard.findFile(request.params['fileId'] ?? '');
    final bytes =
        found == null ? null : await teamBoard.readFile(found.file.id);
    if (found == null || bytes == null) {
      return errorResponse(404, 'not_found', 'That file is gone.');
    }
    return Response(200, body: bytes, headers: {
      'Content-Type': teamBoardFileContentType(found.file.name),
      'Content-Disposition': 'attachment',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'Cache-Control': 'private, max-age=86400',
    });
  }

  /// The Users tab's Team Clipboard actions for [u]: add them, make them a
  /// lead or a plain member, or take them off the board.
  List<String> _teamBoardMenuItems(
      StoredUser u,
      String safeEmail,
      String Function(String action, String label,
              {String? confirm, bool danger, bool askReason})
          item) {
    String access(String role, String label,
            {String? confirm, bool danger = false}) =>
        item('/admin/team-board/access?role=$role', label,
            confirm: confirm, danger: danger);
    return switch (teamBoard.roleOf(u.id)) {
      null => [
          access('member', 'Add to Team Clipboard',
              confirm: 'Let $safeEmail into the Team Clipboard? They can read '
                  'every entry and file, post, and upload.'),
        ],
      final role => [
          if (role == 'member')
            access('lead', 'Make Team Clipboard lead',
                confirm: 'Make $safeEmail a lead? Leads can mark entries '
                    'added, close any thread and remove anything.')
          else
            access('member', 'Make regular team member'),
          access('none', 'Remove from Team Clipboard',
              confirm: 'Take $safeEmail off the Team Clipboard? What they '
                  'posted stays on the board.',
              danger: true),
        ],
    };
  }

  /// A small pill after the email on the Users tab for anyone on the team.
  String _teamBoardBadge(StoredUser u) => switch (teamBoard.roleOf(u.id)) {
        'lead' => ' <span class="badge ok">team lead</span>',
        'member' => ' <span class="badge ok">team</span>',
        _ => '',
      };

  Future<Response> _adminTeamBoardAccess(Request request) async {
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final email = form['email']?.trim().toLowerCase();
    final userId = email == null ? null : store.userIdByEmail[email];
    if (userId == null) {
      return errorResponse(404, 'not_found', 'No account with that email.');
    }
    final role = request.url.queryParameters['role'] ?? form['role'];
    if (role != 'none' && !kTeamBoardRoles.contains(role)) {
      return errorResponse(400, 'bad_role', 'Pick member, lead or none.');
    }
    await teamBoard.setRole(userId, role == 'none' ? null : role);
    await store.logActivity(
        'team_board_access',
        role == 'none'
            ? '$email was taken off the Team Clipboard'
            : '$email is on the Team Clipboard as $role');
    return _adminFormResponse(request, '/admin',
        fragment: 'users', json: {'ok': true, 'role': role});
  }
}

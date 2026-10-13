part of 'api.dart';

/// The Team Clipboard's Discord bot (see `team_discord.dart`). Everyone on
/// the team can see how the bot is doing and what its rules are; only a
/// lead can link it or change them.
extension TeamDiscordApi on Api {
  Response? _teamDiscordLeadOnly(StoredUser user) {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    if (role != 'lead') {
      return errorResponse(
          403, 'forbidden', 'Only a team lead can manage the Discord bot.');
    }
    return null;
  }

  Map<String, dynamic> _teamDiscordJson(String role) {
    final bot = teamDiscord;
    return {
      'canManage': role == 'lead',
      'linked': bot.linked,
      'enabled': bot.enabled,
      'automodOn': bot.automodOn,
      'repliesOn': bot.repliesOn,
      'forumsOn': bot.forumsOn,
      'status': bot.status,
      'statusReason': bot.statusReason,
      if (bot.identity != null)
        'bot': {
          'id': bot.identity!.id,
          'name': bot.identity!.name,
          if (bot.identity!.avatarUrl != null)
            'avatarUrl': bot.identity!.avatarUrl,
        },
      'inviteUrl': bot.inviteUrl,
      'guilds': [
        for (final g in bot.guilds.entries) {'id': g.key, 'name': g.value}
      ],
      'automod': [for (final r in bot.automod) r.toJson()],
      'replies': [for (final r in bot.replies) r.toJson()],
      'trackers': [for (final t in bot.trackers) t.toJson()],
      'forums': [
        for (final f in bot.forums)
          {
            'id': f.id,
            'name': f.name,
            'guild': bot.guildName(f.guildId),
            'tags': [for (final t in f.tags) t.toJson()],
          }
      ],
      'log': [for (final e in bot.log) e.toJson()],
      'metrics': bot.metricsJson(),
    };
  }

  Response _teamDiscordGet(Request request, StoredUser user) {
    final (role, refused) = _teamRole(user);
    if (refused != null) return refused;
    return jsonResponse(200, _teamDiscordJson(role!));
  }

  /// Saves `enabled`, `automodOn`, `repliesOn`, `forumsOn`, `automod`,
  /// `replies` and/or `trackers`. A list replaces the whole list, and one
  /// bad rule refuses the lot.
  Future<Response> _teamDiscordUpdate(Request request, StoredUser user) async {
    final refused = _teamDiscordLeadOnly(user);
    if (refused != null) return refused;
    final body = await _teamJsonBody(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final enabled = body['enabled'];
    final automodOn = body['automodOn'];
    final repliesOn = body['repliesOn'];
    final forumsOn = body['forumsOn'];
    if ([enabled, automodOn, repliesOn, forumsOn]
        .any((v) => v != null && v is! bool)) {
      return errorResponse(400, 'bad_request', 'Say whether the bot is on.');
    }
    List<T>? rules<T>(String key, T? Function(Object?) parse,
        {int max = kDiscordMaxRules}) {
      final raw = body[key];
      if (raw is! List || raw.length > max) return null;
      final out = <T>[];
      for (final r in raw) {
        final rule = parse(r);
        if (rule == null) return null;
        out.add(rule);
      }
      return out;
    }

    final automod = body.containsKey('automod')
        ? rules('automod', DiscordAutomodRule.fromJson)
        : null;
    if (body.containsKey('automod') && automod == null) {
      return errorResponse(400, 'bad_rule',
          'Each automod rule needs 1–$kDiscordMaxWordsPerRule words.');
    }
    final replies = body.containsKey('replies')
        ? rules('replies', DiscordReplyRule.fromJson)
        : null;
    if (body.containsKey('replies') && replies == null) {
      return errorResponse(
          400,
          'bad_rule',
          'Each auto reply needs a trigger word and a reply of at most '
              '$kDiscordMaxReplyChars characters.');
    }
    final trackers = body.containsKey('trackers')
        ? rules('trackers', DiscordForumTracker.fromJson,
            max: kDiscordMaxForumTrackers)
        : null;
    if (body.containsKey('trackers') && trackers == null) {
      return errorResponse(
          400,
          'bad_rule',
          'Each tracked forum needs a forum, a kind and messages of at most '
              '$kDiscordMaxReplyChars characters.');
    }
    await teamDiscord.configure(
        enabled: enabled as bool?,
        automodOn: automodOn as bool?,
        repliesOn: repliesOn as bool?,
        forumsOn: forumsOn as bool?,
        automod: automod,
        replies: replies,
        trackers: trackers);
    return jsonResponse(200, _teamDiscordJson('lead'));
  }

  Future<Response> _teamDiscordLink(Request request, StoredUser user) async {
    final refused = _teamDiscordLeadOnly(user);
    if (refused != null) return refused;
    final body = await _teamJsonBody(request);
    final token = body?['token'];
    if (token is! String ||
        !RegExp(r'^[A-Za-z0-9._\-]{30,200}$').hasMatch(token.trim())) {
      return errorResponse(400, 'bad_token',
          'Paste the bot token from the Bot page of the developer portal.');
    }
    try {
      await teamDiscord.link(token.trim());
    } on DiscordTokenRejected catch (e) {
      return errorResponse(400, 'bad_token', e.message);
    }
    await store.logActivity(
        'team_discord', '${user.email} linked a Discord bot');
    return jsonResponse(200, _teamDiscordJson('lead'));
  }

  Future<Response> _teamDiscordUnlink(Request request, StoredUser user) async {
    final refused = _teamDiscordLeadOnly(user);
    if (refused != null) return refused;
    await teamDiscord.unlink();
    await store.logActivity(
        'team_discord', '${user.email} unlinked the Discord bot');
    return jsonResponse(200, _teamDiscordJson('lead'));
  }
}

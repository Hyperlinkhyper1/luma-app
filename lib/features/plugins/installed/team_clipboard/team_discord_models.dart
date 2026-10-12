import 'team_clipboard_models.dart';

/// The team's Discord bot as the server reports it. The bot itself runs on
/// the luma server; the app only shows and edits its settings. The token is
/// never sent back, so nothing here holds it.
class TeamDiscordState {
  const TeamDiscordState({
    required this.canManage,
    required this.linked,
    required this.enabled,
    this.automodOn = false,
    this.repliesOn = false,
    this.forumsOn = false,
    required this.status,
    this.statusReason,
    this.botName,
    this.botAvatarUrl,
    this.inviteUrl,
    this.guilds = const [],
    this.automod = const [],
    this.replies = const [],
    this.trackers = const [],
    this.forums = const [],
    this.log = const [],
  });

  final bool canManage;
  final bool linked;
  final bool enabled;

  /// Whether each plugin is switched on as a whole.
  final bool automodOn;
  final bool repliesOn;
  final bool forumsOn;
  final TeamDiscordStatus status;

  /// Why the bot is in [TeamDiscordStatus.error]: `bad_token`, `intents`,
  /// `network` or `other`.
  final String? statusReason;
  final String? botName;
  final String? botAvatarUrl;

  /// Adds the bot to a Discord server with the permissions its rules need.
  final String? inviteUrl;
  final List<String> guilds;
  final List<TeamAutomodRule> automod;
  final List<TeamReplyRule> replies;
  final List<TeamForumTracker> trackers;

  /// The forum channels the bot can see right now. Empty while it is
  /// offline.
  final List<TeamDiscordForum> forums;
  final List<TeamDiscordLogEntry> log;

  factory TeamDiscordState.fromJson(Map<String, dynamic> json) =>
      TeamDiscordState(
        canManage: json['canManage'] == true,
        linked: json['linked'] == true,
        enabled: json['enabled'] != false,
        automodOn: json['automodOn'] == true,
        repliesOn: json['repliesOn'] == true,
        forumsOn: json['forumsOn'] == true,
        status:
            TeamDiscordStatus.values.asNameMap()[json['status']] ??
            TeamDiscordStatus.off,
        statusReason: json['statusReason'] as String?,
        botName: (json['bot'] as Map?)?['name'] as String?,
        botAvatarUrl: (json['bot'] as Map?)?['avatarUrl'] as String?,
        inviteUrl: json['inviteUrl'] as String?,
        guilds: [
          for (final g in json['guilds'] as List? ?? const [])
            (g as Map)['name'] as String? ?? '',
        ],
        automod: [
          for (final r in json['automod'] as List? ?? const [])
            TeamAutomodRule.fromJson(r as Map<String, dynamic>),
        ],
        replies: [
          for (final r in json['replies'] as List? ?? const [])
            TeamReplyRule.fromJson(r as Map<String, dynamic>),
        ],
        trackers: [
          for (final r in json['trackers'] as List? ?? const [])
            TeamForumTracker.fromJson(r as Map<String, dynamic>),
        ],
        forums: [
          for (final f in json['forums'] as List? ?? const [])
            TeamDiscordForum.fromJson(f as Map<String, dynamic>),
        ],
        log: [
          for (final e in json['log'] as List? ?? const [])
            TeamDiscordLogEntry.fromJson(e as Map<String, dynamic>),
        ],
      );
}

enum TeamDiscordStatus { off, connecting, online, error }

/// Removes messages that use any of [words].
class TeamAutomodRule {
  const TeamAutomodRule({
    this.id,
    required this.words,
    this.wholeWord = true,
    this.warn = '',
    this.timeoutMinutes = 0,
    this.enabled = true,
  });

  /// Null until the server has saved it.
  final String? id;
  final List<String> words;
  final bool wholeWord;
  final String warn;
  final int timeoutMinutes;
  final bool enabled;

  factory TeamAutomodRule.fromJson(Map<String, dynamic> json) =>
      TeamAutomodRule(
        id: json['id'] as String?,
        words: [for (final w in json['words'] as List? ?? const []) '$w'],
        wholeWord: json['wholeWord'] != false,
        warn: json['warn'] as String? ?? '',
        timeoutMinutes: json['timeoutMinutes'] as int? ?? 0,
        enabled: json['enabled'] != false,
      );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'words': words,
    'wholeWord': wholeWord,
    'warn': warn,
    'timeoutMinutes': timeoutMinutes,
    'enabled': enabled,
  };

  TeamAutomodRule copyWith({bool? enabled}) => TeamAutomodRule(
    id: id,
    words: words,
    wholeWord: wholeWord,
    warn: warn,
    timeoutMinutes: timeoutMinutes,
    enabled: enabled ?? this.enabled,
  );
}

/// How a reply rule's triggers have to appear in a message.
enum TeamReplyMatch { word, contains, exact }

/// Answers messages that mention any of [triggers] with [reply].
class TeamReplyRule {
  const TeamReplyRule({
    this.id,
    required this.triggers,
    required this.reply,
    this.match = TeamReplyMatch.word,
    this.enabled = true,
  });

  final String? id;
  final List<String> triggers;
  final String reply;
  final TeamReplyMatch match;
  final bool enabled;

  factory TeamReplyRule.fromJson(Map<String, dynamic> json) => TeamReplyRule(
    id: json['id'] as String?,
    triggers: [for (final t in json['triggers'] as List? ?? const []) '$t'],
    reply: json['reply'] as String? ?? '',
    match:
        TeamReplyMatch.values.asNameMap()[json['match']] ?? TeamReplyMatch.word,
    enabled: json['enabled'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'triggers': triggers,
    'reply': reply,
    'match': match.name,
    'enabled': enabled,
  };

  TeamReplyRule copyWith({bool? enabled}) => TeamReplyRule(
    id: id,
    triggers: triggers,
    reply: reply,
    match: match,
    enabled: enabled ?? this.enabled,
  );
}

class TeamDiscordTag {
  const TeamDiscordTag(this.id, this.name);

  final String id;
  final String name;

  factory TeamDiscordTag.fromJson(Map<String, dynamic> json) => TeamDiscordTag(
    json['id'] as String? ?? '',
    json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is TeamDiscordTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A forum channel in the bot's Discord server, with its post tags.
class TeamDiscordForum {
  const TeamDiscordForum({
    required this.id,
    required this.name,
    this.guild = '',
    this.tags = const [],
  });

  final String id;
  final String name;
  final String guild;
  final List<TeamDiscordTag> tags;

  factory TeamDiscordForum.fromJson(Map<String, dynamic> json) =>
      TeamDiscordForum(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        guild: json['guild'] as String? ?? '',
        tags: [
          for (final t in json['tags'] as List? ?? const [])
            TeamDiscordTag.fromJson(t as Map<String, dynamic>),
        ],
      );
}

/// What a tracked forum's posts have to include.
enum TeamForumRequire { none, image, log, either, both }

/// One tracked forum: its new posts go on the board as [kind].
class TeamForumTracker {
  const TeamForumTracker({
    this.id,
    required this.forumId,
    this.forumName = '',
    this.tags = const [],
    this.kind = TeamEntryKind.bug,
    this.require = TeamForumRequire.none,
    this.missingMessage = '',
    this.doneMessage = '',
    this.enabled = true,
  });

  final String? id;
  final String forumId;
  final String forumName;

  /// Only posts with one of these tags; every post when empty.
  final List<TeamDiscordTag> tags;
  final TeamEntryKind kind;
  final TeamForumRequire require;

  /// What the bot answers a post that lacks what [require] asks for.
  final String missingMessage;

  /// What the bot posts when the entry is fixed or closed; `{status}`
  /// stands for which.
  final String doneMessage;
  final bool enabled;

  factory TeamForumTracker.fromJson(Map<String, dynamic> json) =>
      TeamForumTracker(
        id: json['id'] as String?,
        forumId: json['forumId'] as String? ?? '',
        forumName: json['forumName'] as String? ?? '',
        tags: [
          for (final t in json['tags'] as List? ?? const [])
            TeamDiscordTag.fromJson(t as Map<String, dynamic>),
        ],
        kind: TeamEntryKind.parse(json['kind']),
        require:
            TeamForumRequire.values.asNameMap()[json['require']] ??
            TeamForumRequire.none,
        missingMessage: json['missingMessage'] as String? ?? '',
        doneMessage: json['doneMessage'] as String? ?? '',
        enabled: json['enabled'] != false,
      );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'forumId': forumId,
    'forumName': forumName,
    'tags': [for (final t in tags) t.toJson()],
    'kind': kind.name,
    'require': require.name,
    'missingMessage': missingMessage,
    'doneMessage': doneMessage,
    'enabled': enabled,
  };

  TeamForumTracker copyWith({bool? enabled}) => TeamForumTracker(
    id: id,
    forumId: forumId,
    forumName: forumName,
    tags: tags,
    kind: kind,
    require: require,
    missingMessage: missingMessage,
    doneMessage: doneMessage,
    enabled: enabled ?? this.enabled,
  );
}

/// One thing the bot did. [detail] is the matched word for `automod` and
/// `reply`, and a sentence from the server for `error` and `info`.
class TeamDiscordLogEntry {
  const TeamDiscordLogEntry({
    required this.kind,
    required this.detail,
    required this.atMs,
    this.guild = '',
    this.channel = '',
    this.user = '',
  });

  final String kind;
  final String detail;
  final int atMs;
  final String guild;
  final String channel;
  final String user;

  factory TeamDiscordLogEntry.fromJson(Map<String, dynamic> json) =>
      TeamDiscordLogEntry(
        kind: json['kind'] as String? ?? 'info',
        detail: json['detail'] as String? ?? '',
        atMs: json['atMs'] as int? ?? 0,
        guild: json['guild'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        user: json['user'] as String? ?? '',
      );
}

/// Splits what was typed into a word list the way the server will keep it:
/// one per comma or line, trimmed, lower-cased, no repeats.
List<String> splitTeamDiscordWords(String text) {
  final out = <String>[];
  for (final part in text.split(RegExp(r'[,\n]'))) {
    final word = part.trim().toLowerCase();
    if (word.isNotEmpty && !out.contains(word)) out.add(word);
  }
  return out;
}

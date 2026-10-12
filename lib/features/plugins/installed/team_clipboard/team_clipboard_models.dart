/// What a Team Clipboard entry is about.
enum TeamEntryKind {
  bug,
  suggestion,
  model;

  static TeamEntryKind parse(Object? raw) => switch (raw) {
    'bug' => bug,
    'model' => model,
    _ => suggestion,
  };
}

/// Where an entry is. A bug reads [idea] as "open" and [added] as "fixed".
enum TeamEntryStage {
  idea,
  claimed,
  done,
  added;

  static TeamEntryStage parse(Object? raw) => switch (raw) {
    'claimed' => claimed,
    'done' => done,
    'added' => added,
    _ => idea,
  };
}

/// Whether this account may use the board: unknown until the server has
/// answered, then in (as a member or lead) or out.
enum TeamAccess { unknown, outside, member, lead }

class TeamFile {
  const TeamFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.uploader,
    required this.mine,
    required this.canRemove,
    required this.createdAt,
    this.fromDiscord = false,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final String uploader;
  final bool mine;
  final bool canRemove;
  final DateTime createdAt;

  /// Copied off a Discord forum post by the bot; [uploader] is then the
  /// Discord user.
  final bool fromDiscord;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isImage => extension == 'png';

  bool get isLog => extension == 'log' || extension == 'txt';

  factory TeamFile.fromJson(Map<String, dynamic> j) => TeamFile(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    sizeBytes: j['sizeBytes'] as int? ?? 0,
    uploader: j['uploader'] as String? ?? '',
    fromDiscord: j['fromDiscord'] == true,
    mine: j['mine'] == true,
    canRemove: j['canRemove'] == true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      j['createdAtMs'] as int? ?? 0,
    ),
  );
}

class TeamMessage {
  const TeamMessage({
    required this.id,
    required this.author,
    required this.mine,
    required this.text,
    required this.createdAt,
    this.fromDiscord = false,
  });

  final String id;
  final String author;
  final bool mine;
  final String text;
  final DateTime createdAt;

  /// A reply in the entry's Discord thread, mirrored by the bot.
  final bool fromDiscord;

  factory TeamMessage.fromJson(Map<String, dynamic> j) => TeamMessage(
    id: j['id'] as String? ?? '',
    author: j['author'] as String? ?? '',
    fromDiscord: j['fromDiscord'] == true,
    mine: j['mine'] == true,
    text: j['text'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      j['createdAtMs'] as int? ?? 0,
    ),
  );
}

/// What a Discord forum post still lacks of what its forum asks for.
enum TeamDiscordMissing {
  none,
  image,
  log,
  both,
  either;

  static TeamDiscordMissing parse(Object? raw) =>
      values.asNameMap()[raw] ?? none;
}

/// The Discord forum post an entry came from.
class TeamEntryDiscord {
  const TeamEntryDiscord({
    required this.url,
    required this.author,
    this.missing = TeamDiscordMissing.none,
    this.attachments = const [],
  });

  final String url;

  /// Who posted it, by their Discord name.
  final String author;
  final TeamDiscordMissing missing;

  /// Attachments the board couldn't keep a copy of (a JPEG, say), each with
  /// a link to the Discord message it is on.
  final List<({String name, String url})> attachments;

  static TeamEntryDiscord? fromJson(Object? raw) {
    if (raw is! Map || raw['url'] is! String) return null;
    return TeamEntryDiscord(
      url: raw['url'] as String,
      author: raw['author'] as String? ?? '',
      missing: TeamDiscordMissing.parse(raw['missing']),
      attachments: [
        for (final a in raw['attachments'] as List? ?? const [])
          if (a is Map && a['name'] is String && a['messageUrl'] is String)
            (name: a['name'] as String, url: a['messageUrl'] as String),
      ],
    );
  }
}

/// One card on the board. [messages] is only filled in when the entry was
/// fetched on its own; the board itself carries [messageCount] and
/// [lastMessage].
class TeamEntry {
  const TeamEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.brief,
    required this.stage,
    required this.closed,
    required this.author,
    required this.mine,
    required this.claimedBy,
    required this.claimedByMe,
    required this.createdAt,
    required this.updatedAtMs,
    required this.messageCount,
    required this.lastMessage,
    required this.files,
    required this.canEdit,
    required this.canClose,
    required this.canDelete,
    this.parentId,
    this.discord,
    this.messages,
  });

  final String id;
  final TeamEntryKind kind;
  final String title;
  final String brief;
  final TeamEntryStage stage;
  final bool closed;
  final String author;
  final bool mine;
  final String? claimedBy;
  final bool claimedByMe;
  final DateTime createdAt;
  final int updatedAtMs;
  final int messageCount;
  final TeamMessage? lastMessage;
  final List<TeamFile> files;
  final bool canEdit;
  final bool canClose;
  final bool canDelete;

  /// The main thread this entry is filed under, or null.
  final String? parentId;

  /// The Discord forum post this entry came from, if the bot made it.
  final TeamEntryDiscord? discord;
  final List<TeamMessage>? messages;

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  /// Done, added or closed: what sinks to the bottom of the board, darker.
  bool get finished => closed || stage.index >= TeamEntryStage.done.index;

  factory TeamEntry.fromJson(Map<String, dynamic> j) {
    final last = j['lastMessage'];
    final messages = j['messages'];
    return TeamEntry(
      id: j['id'] as String,
      kind: TeamEntryKind.parse(j['kind']),
      title: j['title'] as String? ?? '',
      brief: j['brief'] as String? ?? '',
      stage: TeamEntryStage.parse(j['stage']),
      closed: j['closed'] == true,
      author: j['author'] as String? ?? '',
      mine: j['mine'] == true,
      claimedBy: j['claimedBy'] as String?,
      claimedByMe: j['claimedByMe'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        j['createdAtMs'] as int? ?? 0,
      ),
      updatedAtMs: j['updatedAtMs'] as int? ?? 0,
      messageCount: j['messageCount'] as int? ?? 0,
      lastMessage: last is Map<String, dynamic>
          ? TeamMessage.fromJson(last)
          : null,
      files: [
        for (final f in j['files'] as List? ?? const [])
          TeamFile.fromJson(f as Map<String, dynamic>),
      ],
      canEdit: j['canEdit'] == true,
      canClose: j['canClose'] == true,
      canDelete: j['canDelete'] == true,
      parentId: j['parentId'] as String?,
      discord: TeamEntryDiscord.fromJson(j['discord']),
      messages: messages is List
          ? [
              for (final m in messages)
                TeamMessage.fromJson(m as Map<String, dynamic>),
            ]
          : null,
    );
  }
}

/// The extensions the board takes, as the server checks them.
const kTeamFileExtensions = ['png', 'json', 'mcmeta', 'log', 'txt'];

const kTeamMaxFileBytes = 10 * 1024 * 1024;

/// For an animated texture (a strip of square frames stacked vertically),
/// how many frames it holds; 1 for anything else.
int teamTextureFrames(int width, int height) =>
    width > 0 && height > width && height % width == 0 ? height ~/ width : 1;

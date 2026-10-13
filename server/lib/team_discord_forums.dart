part of 'team_discord.dart';

/// The bot's forum plugin. A lead picks forum channels (and, if they like,
/// only posts with certain tags), and every new post there goes on the
/// board as an entry of the kind they chose, author and all:
///
///  * the post's PNGs, models and log files are copied onto the entry; any
///    other attachment is listed with a link to its message,
///  * a post that lacks the screenshot or log the forum asks for still goes
///    on the board, marked as missing it, and the bot answers in the thread
///    with the lead's message; the mark goes once someone shares the file,
///  * later replies in the thread land in the entry's chat, and
///  * fixing or closing the entry tells the thread so and closes it.

const kDiscordMaxForumTrackers = 25;
const kDiscordMaxTagsPerTracker = 20;
const kDiscordMaxNameChars = 100;

/// Discord's forum and media channels: the two whose posts are threads
/// with tags.
const _forumChannelTypes = {15, 16};

final _snowflake = RegExp(r'^\d{1,20}$');

/// Paste sites players share logs on instead of attaching the file. A link
/// to one counts as a log.
const _logHosts = [
  'mclo.gs',
  'pastebin.com',
  'paste.ee',
  'hastebin.com',
  'gist.github.com',
  'paste.gg',
];

bool discordAttachmentIsImage(String name, Object? contentType) =>
    (contentType is String && contentType.startsWith('image/')) ||
    RegExp(r'\.(png|jpe?g|gif|webp|bmp)$', caseSensitive: false).hasMatch(name);

bool discordAttachmentIsLog(String name) =>
    RegExp(r'\.(log|txt)(\.gz)?$', caseSensitive: false).hasMatch(name);

/// Whether [text] links to a log on one of the usual paste sites.
bool discordTextHasLogLink(String text) {
  for (final match in RegExp(r'https?://([^/\s]+)').allMatches(text)) {
    final host = match.group(1)!.toLowerCase();
    if (_logHosts.any((h) => host == h || host.endsWith('.$h'))) return true;
  }
  return false;
}

String _cleanLabel(Object? raw, {int max = kDiscordMaxNameChars}) {
  if (raw is! String) return '';
  final text = raw
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.length > max ? text.substring(0, max) : text;
}

class DiscordForumTag {
  const DiscordForumTag(this.id, this.name);
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static DiscordForumTag? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || !_snowflake.hasMatch(id)) return null;
    return DiscordForumTag(id, _cleanLabel(raw['name']));
  }
}

/// A forum channel the bot can see, with the tags a post there can carry.
class DiscordForum {
  const DiscordForum(this.id, this.guildId, this.name, this.tags);
  final String id;
  final String guildId;
  final String name;
  final List<DiscordForumTag> tags;
}

/// One tracked forum: which posts to take, as what, what they need, and
/// what the bot says.
class DiscordForumTracker {
  DiscordForumTracker({
    required this.id,
    required this.forumId,
    this.forumName = '',
    this.tags = const [],
    this.kind = 'bug',
    this.require = 'none',
    this.missingMessage = '',
    this.doneMessage = '',
    this.enabled = true,
  });

  final String id;
  final String forumId;

  /// The names as they were when the rule was saved, to show while the bot
  /// is offline and can't look them up.
  final String forumName;

  /// Only posts with at least one of these; every post when empty.
  final List<DiscordForumTag> tags;

  /// One of [kTeamBoardKinds].
  final String kind;

  /// One of [kTeamBoardDiscordRequires].
  final String require;

  /// Posted in the thread, mentioning its author, when the post lacks what
  /// [require] asks for. Empty to say nothing.
  final String missingMessage;

  /// Posted in the thread when its entry is fixed or closed, with
  /// `{status}` standing for what happened. Empty to close it silently.
  final String doneMessage;
  final bool enabled;

  /// Whether a post in [forumId] carrying [appliedTags] is one for this
  /// rule.
  bool takes(String forumId, List<String> appliedTags) =>
      enabled &&
      this.forumId == forumId &&
      (tags.isEmpty || tags.any((t) => appliedTags.contains(t.id)));

  Map<String, dynamic> toJson() => {
        'id': id,
        'forumId': forumId,
        'forumName': forumName,
        'tags': [for (final t in tags) t.toJson()],
        'kind': kind,
        'require': require,
        'missingMessage': missingMessage,
        'doneMessage': doneMessage,
        'enabled': enabled,
      };

  static DiscordForumTracker? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final forumId = raw['forumId'];
    final kind = raw['kind'] ?? 'bug';
    final require = raw['require'] ?? 'none';
    final missing = raw['missingMessage'] ?? '';
    final done = raw['doneMessage'] ?? '';
    final rawTags = raw['tags'] ?? const [];
    if (forumId is! String ||
        !_snowflake.hasMatch(forumId) ||
        !kTeamBoardKinds.contains(kind) ||
        !kTeamBoardDiscordRequires.contains(require) ||
        missing is! String ||
        missing.trim().length > kDiscordMaxReplyChars ||
        done is! String ||
        done.trim().length > kDiscordMaxReplyChars ||
        rawTags is! List ||
        rawTags.length > kDiscordMaxTagsPerTracker) {
      return null;
    }
    final tags = <DiscordForumTag>[];
    for (final t in rawTags) {
      final tag = DiscordForumTag.fromJson(t);
      if (tag == null) return null;
      if (!tags.any((o) => o.id == tag.id)) tags.add(tag);
    }
    return DiscordForumTracker(
      id: _cleanId(raw['id']) ?? _newRuleId(),
      forumId: forumId,
      forumName: _cleanLabel(raw['forumName']),
      tags: tags,
      kind: kind as String,
      require: require as String,
      missingMessage: missing.trim(),
      doneMessage: done.trim(),
      enabled: raw['enabled'] != false,
    );
  }
}

/// The rule a post in [forumId] with [appliedTags] falls under: one that
/// names one of its tags before one that takes every post, else the first.
DiscordForumTracker? pickDiscordForumTracker(List<DiscordForumTracker> trackers,
    String forumId, List<String> appliedTags) {
  DiscordForumTracker? any;
  for (final t in trackers) {
    if (!t.takes(forumId, appliedTags)) continue;
    if (t.tags.isNotEmpty) return t;
    any ??= t;
  }
  return any;
}

/// What one Discord message brought along.
class _Gathered {
  final files = <TeamBoardFile>[];
  final links = <TeamBoardDiscordAttachment>[];
  var hasImage = false;
  var hasLog = false;

  List<String> get names => [
        for (final f in files) f.name,
        for (final l in links) l.name,
      ];
}

extension _DiscordForums on TeamDiscordBot {
  void _seeForum(Map c, String guildId) {
    final id = c['id'];
    if (id is! String || !_forumChannelTypes.contains(c['type'])) return;
    _forums[id] = DiscordForum(id, guildId, _cleanLabel(c['name']), [
      for (final t in c['available_tags'] as List? ?? const [])
        if (DiscordForumTag.fromJson(t) case final tag?) tag,
    ]);
  }

  /// Copies what [message] carries onto the board as far as the board
  /// takes it, and links the rest. [filesAlready] is how many files the
  /// entry has, so it never goes over its limit.
  Future<_Gathered> _gather(Map message, String guildId, String threadId,
      String uploaderId, String uploaderName, int filesAlready) async {
    final board = this.board!;
    final out = _Gathered();
    if (discordTextHasLogLink(message['content'] as String? ?? '')) {
      out.hasLog = true;
    }
    final messageUrl =
        'https://discord.com/channels/$guildId/$threadId/${message['id']}';
    var added = 0;
    for (final a in message['attachments'] as List? ?? const []) {
      if (a is! Map) continue;
      final rawName = _cleanLabel(a['filename'], max: 120);
      if (rawName.isEmpty) continue;
      if (discordAttachmentIsImage(rawName, a['content_type'])) {
        out.hasImage = true;
      }
      if (discordAttachmentIsLog(rawName)) out.hasLog = true;
      final name = cleanTeamBoardFileName(rawName);
      final url = a['url'];
      final size = a['size'] is int ? a['size'] as int : 0;
      Uint8List? bytes;
      if (name != null &&
          url is String &&
          size <= kTeamBoardMaxFileBytes &&
          filesAlready + out.files.length < kTeamBoardMaxFilesPerEntry &&
          board.totalFileBytes + added + size <= kTeamBoardMaxTotalFileBytes) {
        bytes = await download(url, kTeamBoardMaxFileBytes);
        if (bytes != null && teamBoardFileProblem(name, bytes) != null) {
          bytes = null;
        }
      }
      if (bytes == null) {
        out.links.add(TeamBoardDiscordAttachment(rawName, messageUrl));
        continue;
      }
      final file = TeamBoardFile(
        id: TeamBoardStore.newId(),
        name: name!,
        sizeBytes: bytes.length,
        uploaderId: uploaderId,
        uploaderEmail: uploaderName,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await board.writeFile(file.id, bytes);
      added += bytes.length;
      out.files.add(file);
    }
    return out;
  }

  /// A new forum post: if a rule takes it, it goes on the board.
  Future<void> _onThreadCreate(Map d, String token) async {
    final board = this.board;
    final threadId = d['id'], forumId = d['parent_id'], guildId = d['guild_id'];
    if (board == null ||
        !forumsOn ||
        d['newly_created'] != true ||
        threadId is! String ||
        forumId is! String ||
        guildId is! String) {
      return;
    }
    final tracker = pickDiscordForumTracker(trackers, forumId, [
      for (final t in d['applied_tags'] as List? ?? const [])
        if (t is String) t,
    ]);
    if (tracker == null) return;
    final forumName = _forums[forumId]?.name ?? tracker.forumName;
    void fail(String what) => _note(DiscordLogEntry('error', what,
        guild: guildName(guildId), channel: forumName));

    final created = await _forumLock.synchronized(() async {
      if (board.entryForThread(threadId) != null) return null;
      // A forum post's first message has the thread's own id. It is
      // usually there by the time the thread is announced, but not always.
      var starter =
          await rest(token, 'GET', '/channels/$threadId/messages/$threadId');
      if (starter.status == 404) {
        await Future<void>.delayed(const Duration(seconds: 2));
        starter =
            await rest(token, 'GET', '/channels/$threadId/messages/$threadId');
      }
      final message = starter.body;
      if (!starter.ok || message is! Map || message['author'] is! Map) {
        fail('Could not read a new forum post: ${starter.describe()}');
        return null;
      }
      final author = message['author'] as Map;
      if (author['bot'] == true) return null;
      if (board.entryCount >= kTeamBoardMaxEntries) {
        fail('The board is full, so a forum post was left off it.');
        return null;
      }
      final authorId = author['id'] as String? ?? '';
      final authorName = _cleanLabel(
          author['global_name'] ?? author['username'],
          max: kTeamBoardMaxNameChars);
      final uploaderId = '$kTeamBoardDiscordIdPrefix$authorId';
      final got =
          await _gather(message, guildId, threadId, uploaderId, authorName, 0);
      var brief = (message['content'] as String? ?? '')
          .replaceAll('\r\n', '\n')
          .replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '')
          .trim();
      if (brief.length > kTeamBoardMaxBriefChars) {
        brief = '${brief.substring(0, kTeamBoardMaxBriefChars - 1)}…';
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final link = TeamBoardDiscordLink(
        guildId: guildId,
        forumId: forumId,
        threadId: threadId,
        trackerId: tracker.id,
        authorName: authorName,
        require: tracker.require,
        hasImage: got.hasImage,
        hasLog: got.hasLog,
        attachments: got.links,
      );
      final entry = TeamBoardEntry(
        id: TeamBoardStore.newId(),
        kind: tracker.kind,
        title: cleanTeamBoardTitle(d['name']) ?? 'Post in #$forumName',
        brief: brief,
        authorId: uploaderId,
        authorEmail: authorName,
        createdAtMs: now,
        updatedAtMs: now,
        discord: link,
        files: got.files,
      );
      await board.mutate(() => board.addEntry(entry));
      return (entry: entry, authorId: authorId);
    });
    if (created == null) return;
    final entry = created.entry;
    _note(DiscordLogEntry('forum', entry.title,
        guild: guildName(guildId),
        channel: forumName,
        user: entry.discord!.authorName));
    if (entry.discord!.missing.isNotEmpty &&
        tracker.missingMessage.isNotEmpty) {
      final sent =
          await rest(token, 'POST', '/channels/$threadId/messages', body: {
        'content': '<@${created.authorId}> ${tracker.missingMessage}',
        'allowed_mentions': {
          'parse': <String>[],
          'users': [created.authorId],
        },
      });
      if (!sent.ok) {
        fail('Could not ask for the missing file: ${sent.describe()}');
      }
    }
  }

  /// A reply in a thread that became an entry: into the entry's chat, with
  /// its files.
  Future<void> _onThreadMessage(Map d) async {
    final board = this.board;
    final threadId = d['channel_id'], guildId = d['guild_id'];
    final author = d['author'];
    if (board == null ||
        !forumsOn ||
        threadId is! String ||
        guildId is! String ||
        author is! Map ||
        d['id'] == threadId) {
      return;
    }
    if (board.entryForThread(threadId) == null) return;
    await _forumLock.synchronized(() async {
      final entry = board.entryForThread(threadId);
      final link = entry?.discord;
      if (entry == null ||
          link == null ||
          entry.closed ||
          entry.messages.length >= kTeamBoardMaxMessagesPerEntry) {
        return;
      }
      final authorName = _cleanLabel(
          author['global_name'] ?? author['username'],
          max: kTeamBoardMaxNameChars);
      final authorId = '$kTeamBoardDiscordIdPrefix${author['id']}';
      final got = await _gather(
          d, guildId, threadId, authorId, authorName, entry.files.length);
      var text = cleanTeamBoardText(
              d['content'] as String? ?? '', kTeamBoardMaxMessageChars) ??
          '';
      if (got.names.isNotEmpty) {
        final shared = 'Shared ${got.names.join(', ')}';
        text = text.isEmpty ? shared : '$text\n\n$shared';
        if (text.length > kTeamBoardMaxMessageChars) {
          text = '${text.substring(0, kTeamBoardMaxMessageChars - 1)}…';
        }
      }
      if (text.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      await board.mutate(() {
        entry.messages.add(TeamBoardMessage(
          id: TeamBoardStore.newId(),
          authorId: authorId,
          authorEmail: authorName,
          text: text,
          createdAtMs: now,
        ));
        entry.files.addAll(got.files);
        link.attachments.addAll(got.links);
        link.hasImage = link.hasImage || got.hasImage;
        link.hasLog = link.hasLog || got.hasLog;
        entry.updatedAtMs = now;
      });
    });
  }
}

extension DiscordForumSync on TeamDiscordBot {
  /// Tells [entry]'s Discord thread, once, that it was fixed or closed, and
  /// closes the thread. Reopening the entry lets it say so again later.
  Future<void> syncEntryState(TeamBoardEntry entry) =>
      meter.run(() => _syncEntryState(entry));

  Future<void> _syncEntryState(TeamBoardEntry entry) async {
    final link = entry.discord;
    final board = this.board;
    if (link == null || board == null) return;
    final resolved = entry.closed || entry.stage == 'added';
    if (!resolved) {
      if (link.notified) await board.mutate(() => link.notified = false);
      return;
    }
    final token = _token;
    if (link.notified || token == null || !forumsOn) return;
    await board.mutate(() => link.notified = true);
    final status = entry.stage == 'added'
        ? (entry.kind == 'bug' ? 'fixed' : 'added')
        : 'closed';
    final tracker = trackers.where((t) => t.id == link.trackerId).firstOrNull;
    final where = (
      guild: guildName(link.guildId),
      channel: _forums[link.forumId]?.name ?? tracker?.forumName ?? '',
    );
    final text = tracker?.doneMessage.replaceAll('{status}', status) ?? '';
    if (text.isNotEmpty) {
      final sent = await rest(
          token, 'POST', '/channels/${link.threadId}/messages',
          body: {
            'content': text,
            'allowed_mentions': {'parse': <String>[]},
          });
      if (!sent.ok) {
        _note(DiscordLogEntry(
            'error', 'Could not post in a forum post: ${sent.describe()}',
            guild: where.guild, channel: where.channel));
      }
    }
    final archived = await rest(token, 'PATCH', '/channels/${link.threadId}',
        body: {'archived': true}, reason: 'luma: marked $status');
    if (!archived.ok) {
      _note(DiscordLogEntry(
          'error', 'Could not close a forum post: ${archived.describe()}',
          guild: where.guild, channel: where.channel));
      return;
    }
    _note(DiscordLogEntry('forum_done', '${entry.title} ($status)',
        guild: where.guild, channel: where.channel));
  }
}

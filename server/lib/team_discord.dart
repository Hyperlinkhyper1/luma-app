import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'team_board.dart';
import 'util.dart';

part 'team_discord_forums.dart';

/// The Team Clipboard's Discord bot: a bot the team's leads link from the
/// app, which then sits in the team's Discord server and
///
///  * removes messages that use a banned word (automod), optionally warning
///    the author or putting them in timeout,
///  * answers messages that mention a trigger word with a canned reply, and
///  * puts every new post in the forums it tracks on the board (see
///    `team_discord_forums.dart`).
///
/// The bot has to be online while every app is closed, so it runs here on
/// the server, over Discord's gateway. The app only edits its settings. The
/// token is a secret: it is stored here and never sent back to any client.

const kDiscordMaxRules = 50;
const kDiscordMaxWordsPerRule = 50;
const kDiscordMaxWordChars = 100;

/// Discord's own limit on a message's length.
const kDiscordMaxReplyChars = 2000;
const kDiscordMaxWarnChars = 500;

/// Discord's longest timeout is 28 days.
const kDiscordMaxTimeoutMinutes = 28 * 24 * 60;

/// How long a reply rule stays quiet in a channel after it answered, so a
/// busy conversation about the trigger doesn't turn into bot spam.
const kDiscordReplyCooldown = Duration(seconds: 15);

const kDiscordReplyMatches = ['contains', 'word', 'exact'];

/// Guilds, guild messages and message content. The last is privileged: it
/// has to be switched on in the developer portal, or Discord closes the
/// connection with 4014.
const kDiscordIntents = 1 | (1 << 9) | (1 << 15);

/// View channels, send messages, manage messages, read message history,
/// moderate members, send messages in threads and manage threads (to close
/// a forum post): everything the rules can do, nothing more.
const kDiscordInvitePermissions =
    1024 + 2048 + 8192 + 65536 + 1099511627776 + 274877906944 + 17179869184;

const _api = 'https://discord.com/api/v10';
const _gateway = 'wss://gateway.discord.gg/?v=10&encoding=json';
const _userAgent = 'DiscordBot (luma, 1.0)';

String _newRuleId() =>
    randomBytes(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

final _ruleIdPattern = RegExp(r'^[a-f0-9]{16}$');

String? _cleanId(Object? raw) =>
    raw is String && _ruleIdPattern.hasMatch(raw) ? raw : null;

/// Trimmed, lower-cased, de-duplicated words, or null when any is too long
/// or there are too many.
List<String>? _cleanWords(Object? raw) {
  if (raw is! List) return null;
  final out = <String>[];
  for (final w in raw) {
    if (w is! String) return null;
    final word = w.trim().toLowerCase();
    if (word.isEmpty) continue;
    if (word.length > kDiscordMaxWordChars) return null;
    if (!out.contains(word)) out.add(word);
  }
  if (out.isEmpty || out.length > kDiscordMaxWordsPerRule) return null;
  return out;
}

/// Whether [word] appears in [text] (both already lower-case): anywhere, or
/// with [whole] only as a word of its own, so "class" doesn't trip "ass".
bool discordTextHas(String text, String word, {required bool whole}) {
  if (!whole) return text.contains(word);
  return RegExp(
    '(?<![\\p{L}\\p{N}_])${RegExp.escape(word)}(?![\\p{L}\\p{N}_])',
    unicode: true,
  ).hasMatch(text);
}

/// Removes messages that use any of [words].
class DiscordAutomodRule {
  DiscordAutomodRule({
    required this.id,
    required this.words,
    this.wholeWord = true,
    this.warn = '',
    this.timeoutMinutes = 0,
    this.enabled = true,
  });

  final String id;
  final List<String> words;
  final bool wholeWord;

  /// Posted in the channel, mentioning the author, after a removal. Empty
  /// for a silent removal.
  final String warn;

  /// 0 for none.
  final int timeoutMinutes;
  final bool enabled;

  /// The first of [words] in [text], or null.
  String? match(String text) {
    for (final w in words) {
      if (discordTextHas(text, w, whole: wholeWord)) return w;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'words': words,
        'wholeWord': wholeWord,
        'warn': warn,
        'timeoutMinutes': timeoutMinutes,
        'enabled': enabled,
      };

  /// A rule from the app or from disk, or null when it doesn't hold up.
  static DiscordAutomodRule? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final words = _cleanWords(raw['words']);
    final warn = raw['warn'] ?? '';
    final timeout = raw['timeoutMinutes'] ?? 0;
    if (words == null ||
        warn is! String ||
        warn.trim().length > kDiscordMaxWarnChars ||
        timeout is! int ||
        timeout < 0 ||
        timeout > kDiscordMaxTimeoutMinutes) {
      return null;
    }
    return DiscordAutomodRule(
      id: _cleanId(raw['id']) ?? _newRuleId(),
      words: words,
      wholeWord: raw['wholeWord'] != false,
      warn: warn.trim(),
      timeoutMinutes: timeout,
      enabled: raw['enabled'] != false,
    );
  }
}

/// Answers messages that mention any of [triggers] with [reply].
class DiscordReplyRule {
  DiscordReplyRule({
    required this.id,
    required this.triggers,
    required this.reply,
    this.match = 'word',
    this.enabled = true,
  });

  final String id;
  final List<String> triggers;
  final String reply;

  /// `contains` anywhere, as a `word` of its own, or the `exact` message.
  final String match;
  final bool enabled;

  /// The first of [triggers] that [text] answers to, or null.
  String? matchIn(String text) {
    final trimmed = text.trim();
    for (final t in triggers) {
      final hit = switch (match) {
        'exact' => trimmed == t,
        'contains' => discordTextHas(text, t, whole: false),
        _ => discordTextHas(text, t, whole: true),
      };
      if (hit) return t;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'triggers': triggers,
        'reply': reply,
        'match': match,
        'enabled': enabled,
      };

  static DiscordReplyRule? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final triggers = _cleanWords(raw['triggers']);
    final reply = raw['reply'];
    final match = raw['match'] ?? 'word';
    if (triggers == null ||
        reply is! String ||
        reply.trim().isEmpty ||
        reply.trim().length > kDiscordMaxReplyChars ||
        !kDiscordReplyMatches.contains(match)) {
      return null;
    }
    return DiscordReplyRule(
      id: _cleanId(raw['id']) ?? _newRuleId(),
      triggers: triggers,
      reply: reply.trim(),
      match: match as String,
      enabled: raw['enabled'] != false,
    );
  }
}

/// What the bot does about one message.
sealed class DiscordAction {}

class DiscordRemove extends DiscordAction {
  DiscordRemove(this.rule, this.word);
  final DiscordAutomodRule rule;
  final String word;
}

class DiscordAnswer extends DiscordAction {
  DiscordAnswer(this.rule, this.trigger);
  final DiscordReplyRule rule;
  final String trigger;
}

/// The bot's answer to a message saying [content]: automod goes first, and
/// a removed message gets no reply. [replyReady] says whether a reply rule
/// is off cooldown.
DiscordAction? decideDiscordAction(
  String content, {
  required List<DiscordAutomodRule> automod,
  required List<DiscordReplyRule> replies,
  bool Function(DiscordReplyRule rule)? replyReady,
}) {
  final text = content.toLowerCase();
  if (text.trim().isEmpty) return null;
  for (final rule in automod) {
    if (!rule.enabled) continue;
    final word = rule.match(text);
    if (word != null) return DiscordRemove(rule, word);
  }
  for (final rule in replies) {
    if (!rule.enabled) continue;
    final trigger = rule.matchIn(text);
    if (trigger != null && (replyReady?.call(rule) ?? true)) {
      return DiscordAnswer(rule, trigger);
    }
  }
  return null;
}

/// One line of the bot's recent activity, shown to the team.
class DiscordLogEntry {
  DiscordLogEntry(this.kind, this.detail,
      {this.guild = '', this.channel = '', this.user = ''})
      : atMs = DateTime.now().millisecondsSinceEpoch;

  /// `automod`, `reply`, `error` or `info`.
  final String kind;
  final String detail;
  final String guild;
  final String channel;
  final String user;
  final int atMs;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'detail': detail,
        'guild': guild,
        'channel': channel,
        'user': user,
        'atMs': atMs,
      };
}

/// Who a token belongs to.
class DiscordIdentity {
  const DiscordIdentity(this.id, this.name);
  final String id;
  final String name;
}

/// Why a token was refused.
class DiscordTokenRejected implements Exception {
  const DiscordTokenRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs the bot and keeps its settings in `team_board/discord.json`.
///
/// Nothing connects until [start] is called (the server's `main` does), so
/// tests and tools that construct the API never reach Discord.
class TeamDiscordBot {
  TeamDiscordBot(String dataDir) : _path = '$dataDir/team_board/discord.json' {
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return;
      final token = raw['token'];
      if (token is String && token.isNotEmpty) _token = token;
      _identity = raw['botId'] is String && raw['botName'] is String
          ? DiscordIdentity(raw['botId'] as String, raw['botName'] as String)
          : null;
      enabled = raw['enabled'] != false;
      automodOn = raw['automodOn'] == true;
      repliesOn = raw['repliesOn'] == true;
      forumsOn = raw['forumsOn'] == true;
      trackers = (raw['trackers'] as List? ?? const [])
          .map(DiscordForumTracker.fromJson)
          .whereType<DiscordForumTracker>()
          .toList();
      automod = (raw['automod'] as List? ?? const [])
          .map(DiscordAutomodRule.fromJson)
          .whereType<DiscordAutomodRule>()
          .toList();
      replies = (raw['replies'] as List? ?? const [])
          .map(DiscordReplyRule.fromJson)
          .whereType<DiscordReplyRule>()
          .toList();
    } catch (e) {
      stderr.writeln('[luma] could not read $_path: $e');
    }
  }

  final String _path;
  final AsyncLock _lock = AsyncLock();

  String? _token;
  DiscordIdentity? _identity;
  bool enabled = true;

  /// Whether each plugin is switched on. Both start off: a lead enables
  /// a plugin from its card, the way a bot dashboard does.
  bool automodOn = false;
  bool repliesOn = false;
  bool forumsOn = false;
  List<DiscordAutomodRule> automod = [];
  List<DiscordReplyRule> replies = [];
  List<DiscordForumTracker> trackers = [];

  /// Where tracked forum posts go. Set by the API; without it the forum
  /// plugin does nothing.
  TeamBoardStore? board;

  /// Checks a token with Discord. Swapped out by tests.
  Future<DiscordIdentity> Function(String token) whoAmI = _restWhoAmI;

  /// Calls Discord's REST API. Swapped out by tests.
  Future<DiscordRestResult> Function(String token, String method, String path,
      {Object? body, String? reason}) rest = _rest;

  /// Fetches an attachment from Discord's CDN, or null when it can't or it
  /// is over the byte limit. Swapped out by tests.
  Future<Uint8List?> Function(String url, int maxBytes) download =
      _downloadAttachment;

  bool get linked => _token != null;
  DiscordIdentity? get identity => _identity;

  /// `off`, `connecting`, `online` or `error`.
  String status = 'off';

  /// Why the bot is in `error`: `bad_token`, `intents`, `network` or
  /// `other`.
  String? statusReason;

  final Map<String, String> _guilds = {};
  final Map<String, String> _channels = {};
  final Map<String, DiscordForum> _forums = {};
  final List<DiscordLogEntry> _log = [];
  final Map<String, DateTime> _replyCooldown = {};

  /// Forum posts are handled one at a time, so a reply that arrives while
  /// its post is still being put on the board waits for the entry.
  final AsyncLock _forumLock = AsyncLock();

  Map<String, String> get guilds => Map.unmodifiable(_guilds);

  /// The forum channels the bot can see right now, by name.
  List<DiscordForum> get forums => _forums.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// The name of guild [id], once the bot has seen it.
  String guildName(String id) => _guilds[id] ?? '';
  List<DiscordLogEntry> get log => List.unmodifiable(_log.reversed);

  String? get inviteUrl => _identity == null
      ? null
      : 'https://discord.com/oauth2/authorize?client_id=${_identity!.id}'
          '&scope=bot&permissions=$kDiscordInvitePermissions';

  bool _started = false;
  int _generation = 0;
  WebSocket? _socket;

  void _note(DiscordLogEntry entry) {
    _log.add(entry);
    if (_log.length > 100) _log.removeAt(0);
  }

  Future<void> _save() async {
    await Directory(File(_path).parent.path).create(recursive: true);
    await atomicWriteString(
        _path,
        jsonEncode({
          'token': _token,
          'botId': _identity?.id,
          'botName': _identity?.name,
          'enabled': enabled,
          'automodOn': automodOn,
          'repliesOn': repliesOn,
          'forumsOn': forumsOn,
          'automod': [for (final r in automod) r.toJson()],
          'replies': [for (final r in replies) r.toJson()],
          'trackers': [for (final t in trackers) t.toJson()],
        }));
  }

  /// Links the bot behind [token], once Discord confirms it is a bot
  /// token. Throws [DiscordTokenRejected] when it isn't.
  Future<DiscordIdentity> link(String token) async {
    final who = await whoAmI(token);
    await _lock.synchronized(() async {
      _token = token;
      _identity = who;
      _guilds.clear();
      _channels.clear();
      _forums.clear();
      _note(DiscordLogEntry('info', 'Linked ${who.name}.'));
      await _save();
    });
    _restart();
    return who;
  }

  Future<void> unlink() async {
    await _lock.synchronized(() async {
      _token = null;
      _identity = null;
      _guilds.clear();
      _channels.clear();
      _forums.clear();
      _note(DiscordLogEntry('info', 'Unlinked the bot.'));
      await _save();
    });
    _restart();
  }

  /// Saves new settings; any left null stay as they are.
  Future<void> configure({
    bool? enabled,
    bool? automodOn,
    bool? repliesOn,
    bool? forumsOn,
    List<DiscordAutomodRule>? automod,
    List<DiscordReplyRule>? replies,
    List<DiscordForumTracker>? trackers,
  }) async {
    final wasOn = this.enabled;
    await _lock.synchronized(() async {
      if (enabled != null) this.enabled = enabled;
      if (automodOn != null) this.automodOn = automodOn;
      if (repliesOn != null) this.repliesOn = repliesOn;
      if (forumsOn != null) this.forumsOn = forumsOn;
      if (automod != null) this.automod = automod;
      if (replies != null) this.replies = replies;
      if (trackers != null) this.trackers = trackers;
      await _save();
    });
    if (wasOn != this.enabled) _restart();
  }

  bool get _shouldRun => _started && _token != null && enabled;

  /// Connects, and keeps reconnecting until [stop].
  void start() {
    _started = true;
    _restart();
  }

  Future<void> stop() async {
    _started = false;
    _restart();
  }

  void _restart() {
    _generation++;
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close(1000));
    _guilds.clear();
    _channels.clear();
    _forums.clear();
    if (!_shouldRun) {
      status = 'off';
      statusReason = null;
      return;
    }
    unawaited(_run(_generation));
  }

  Future<void> _run(int generation) async {
    var backoff = const Duration(seconds: 2);
    while (generation == _generation && _shouldRun) {
      status = 'connecting';
      final began = DateTime.now();
      final fatal = await _session(generation);
      if (generation != _generation) return;
      if (fatal != null) {
        status = 'error';
        statusReason = fatal;
        _note(DiscordLogEntry(
            'error',
            switch (fatal) {
              'bad_token' => 'Discord refused the token. Link the bot again.',
              'intents' => 'Message Content Intent is off for this bot.',
              _ => 'Discord closed the connection for good.',
            }));
        return;
      }
      if (DateTime.now().difference(began) > const Duration(minutes: 2)) {
        backoff = const Duration(seconds: 2);
      }
      await Future<void>.delayed(backoff);
      backoff = Duration(seconds: min(backoff.inSeconds * 2, 60));
    }
  }

  /// One gateway connection, from hello to close. Returns why the bot
  /// should give up, or null to reconnect.
  Future<String?> _session(int generation) async {
    final token = _token!;
    final WebSocket ws;
    try {
      ws =
          await WebSocket.connect(_gateway, headers: {'User-Agent': _userAgent})
              .timeout(const Duration(seconds: 20));
    } catch (e) {
      status = 'error';
      statusReason = 'network';
      return null;
    }
    if (generation != _generation) {
      unawaited(ws.close(1000));
      return null;
    }
    _socket = ws;
    int? seq;
    var acked = true;
    Timer? beat;
    void send(Map<String, dynamic> payload) {
      if (ws.readyState == WebSocket.open) ws.add(jsonEncode(payload));
    }

    void heartbeat() {
      if (!acked) {
        unawaited(ws.close(4000));
        return;
      }
      acked = false;
      send({'op': 1, 'd': seq});
    }

    final done = Completer<void>();
    ws.listen(
      (raw) {
        if (raw is! String) return;
        final Map<String, dynamic> payload;
        try {
          payload = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        final d = payload['d'];
        switch (payload['op']) {
          case 10:
            final every =
                Duration(milliseconds: (d as Map)['heartbeat_interval'] as int);
            beat = Timer(every * Random().nextDouble(), () {
              heartbeat();
              beat = Timer.periodic(every, (_) => heartbeat());
            });
            send({
              'op': 2,
              'd': {
                'token': token,
                'intents': kDiscordIntents,
                'properties': {
                  'os': Platform.operatingSystem,
                  'browser': 'luma',
                  'device': 'luma',
                },
              },
            });
          case 1:
            send({'op': 1, 'd': seq});
          case 11:
            acked = true;
          case 7 || 9:
            unawaited(ws.close(4000));
          case 0:
            seq = payload['s'] as int? ?? seq;
            if (generation == _generation) {
              unawaited(_dispatch(payload['t'] as String?, d, token));
            }
        }
      },
      onDone: () {
        beat?.cancel();
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        beat?.cancel();
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    if (identical(_socket, ws)) _socket = null;
    return switch (ws.closeCode) {
      4004 => 'bad_token',
      4013 || 4014 => 'intents',
      4010 || 4011 || 4012 => 'other',
      _ => null,
    };
  }

  /// Handles one gateway event as if it had just come in. The gateway
  /// calls this; tests feed it events directly.
  Future<void> handleGatewayEvent(String type, Map d) async {
    final token = _token;
    if (token != null) await _dispatch(type, d, token);
  }

  Future<void> _dispatch(String? type, Object? d, String token) async {
    if (d is! Map) return;
    switch (type) {
      case 'READY':
        final user = d['user'];
        if (user is Map && user['id'] is String) {
          _identity = DiscordIdentity(
              user['id'] as String, user['username'] as String? ?? 'bot');
        }
        status = 'online';
        statusReason = null;
        _note(DiscordLogEntry('info', 'Connected to Discord.'));
      case 'GUILD_CREATE':
        final id = d['id'];
        if (id is! String) return;
        _guilds[id] = d['name'] as String? ?? id;
        for (final c in d['channels'] as List? ?? const []) {
          if (c is Map && c['id'] is String) {
            _channels[c['id'] as String] = c['name'] as String? ?? '';
            _seeForum(c, id);
          }
        }
      case 'GUILD_DELETE':
        if (d['unavailable'] != true) {
          _guilds.remove(d['id']);
          _forums.removeWhere((_, f) => f.guildId == d['id']);
        }
      case 'CHANNEL_CREATE' || 'CHANNEL_UPDATE':
        if (d['id'] is String && d['name'] is String) {
          _channels[d['id'] as String] = d['name'] as String;
          if (d['guild_id'] is String) _seeForum(d, d['guild_id'] as String);
        }
      case 'CHANNEL_DELETE':
        _forums.remove(d['id']);
      case 'THREAD_CREATE':
        try {
          await _onThreadCreate(d, token);
        } catch (e) {
          _note(DiscordLogEntry('error', 'Handling a forum post failed: $e'));
        }
      case 'MESSAGE_CREATE':
        try {
          await _onMessage(d, token);
        } catch (e) {
          _note(DiscordLogEntry('error', 'Handling a message failed: $e'));
        }
    }
  }

  Future<void> _onMessage(Map d, String token) async {
    final guildId = d['guild_id'];
    final author = d['author'];
    if (guildId is! String || author is! Map) return;
    if (author['bot'] == true || d['webhook_id'] != null) return;
    final channelId = d['channel_id'] as String? ?? '';
    final messageId = d['id'] as String? ?? '';
    final userId = author['id'] as String? ?? '';
    final now = DateTime.now();
    final action = decideDiscordAction(
      d['content'] as String? ?? '',
      automod: automodOn ? automod : const [],
      replies: repliesOn ? replies : const [],
      replyReady: (rule) {
        final until = _replyCooldown['${rule.id}:$channelId'];
        return until == null || now.isAfter(until);
      },
    );
    if (action is! DiscordRemove) await _onThreadMessage(d);
    if (action == null) return;
    final where = (
      guild: _guilds[guildId] ?? '',
      channel: _channels[channelId] ?? '',
      user: author['username'] as String? ?? '',
    );
    void fail(String what, DiscordRestResult r) =>
        _note(DiscordLogEntry('error', '$what: ${r.describe()}',
            guild: where.guild, channel: where.channel, user: where.user));

    switch (action) {
      case DiscordRemove(:final rule, :final word):
        final removed = await rest(
            token, 'DELETE', '/channels/$channelId/messages/$messageId',
            reason: 'luma automod');
        if (!removed.ok) return fail('Could not remove a message', removed);
        _note(DiscordLogEntry('automod', word,
            guild: where.guild, channel: where.channel, user: where.user));
        if (rule.warn.isNotEmpty) {
          final warned =
              await rest(token, 'POST', '/channels/$channelId/messages', body: {
            'content': '<@$userId> ${rule.warn}',
            'allowed_mentions': {
              'parse': <String>[],
              'users': [userId],
            },
          });
          if (!warned.ok) fail('Could not post the warning', warned);
        }
        if (rule.timeoutMinutes > 0) {
          final until = now.toUtc().add(Duration(minutes: rule.timeoutMinutes));
          final timedOut = await rest(
              token, 'PATCH', '/guilds/$guildId/members/$userId',
              body: {'communication_disabled_until': until.toIso8601String()},
              reason: 'luma automod');
          if (!timedOut.ok) fail('Could not time out the author', timedOut);
        }
      case DiscordAnswer(:final rule, :final trigger):
        _replyCooldown['${rule.id}:$channelId'] =
            now.add(kDiscordReplyCooldown);
        final sent =
            await rest(token, 'POST', '/channels/$channelId/messages', body: {
          'content': rule.reply,
          'message_reference': {
            'message_id': messageId,
            'fail_if_not_exists': false,
          },
          'allowed_mentions': {'parse': <String>[], 'replied_user': true},
        });
        if (!sent.ok) return fail('Could not send a reply', sent);
        _note(DiscordLogEntry('reply', trigger,
            guild: where.guild, channel: where.channel, user: where.user));
    }
  }

  static Future<DiscordIdentity> _restWhoAmI(String token) async {
    final r = await _rest(token, 'GET', '/users/@me');
    if (r.status == 401) {
      throw const DiscordTokenRejected('Discord did not accept that token.');
    }
    final body = r.body;
    if (!r.ok || body is! Map || body['id'] is! String) {
      throw DiscordTokenRejected('Could not reach Discord (${r.describe()}).');
    }
    if (body['bot'] != true) {
      throw const DiscordTokenRejected(
          'That is not a bot token. Copy it from the Bot page.');
    }
    return DiscordIdentity(
        body['id'] as String, body['username'] as String? ?? 'bot');
  }

  /// One REST call, retried once if Discord asks us to slow down.
  static Future<DiscordRestResult> _rest(
      String token, String method, String path,
      {Object? body, String? reason}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      for (var attempt = 0;; attempt++) {
        final request = await client.openUrl(method, Uri.parse('$_api$path'));
        request.headers
          ..set('Authorization', 'Bot $token')
          ..set('User-Agent', _userAgent);
        if (reason != null) {
          request.headers
              .set('X-Audit-Log-Reason', Uri.encodeComponent(reason));
        }
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.add(utf8.encode(jsonEncode(body)));
        }
        final response =
            await request.close().timeout(const Duration(seconds: 20));
        final text = await response.transform(utf8.decoder).join();
        Object? decoded;
        try {
          decoded = text.isEmpty ? null : jsonDecode(text);
        } catch (_) {}
        if (response.statusCode == 429 && attempt == 0) {
          final wait = decoded is Map ? decoded['retry_after'] : null;
          final seconds = wait is num ? wait.toDouble().clamp(0.5, 10) : 2.0;
          await Future<void>.delayed(
              Duration(milliseconds: (seconds * 1000).round()));
          continue;
        }
        return DiscordRestResult(response.statusCode, decoded);
      }
    } catch (e) {
      return DiscordRestResult(0, null, e.toString());
    } finally {
      client.close();
    }
  }

  /// Only Discord's own CDN, over HTTPS: the URL comes from a message, so
  /// the server never fetches anything else on its say-so.
  static Future<Uint8List?> _downloadAttachment(
      String url, int maxBytes) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !const {'cdn.discordapp.com', 'media.discordapp.net'}
            .contains(uri.host)) {
      return null;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) return null;
      }
      return bytes.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class DiscordRestResult {
  DiscordRestResult(this.status, this.body, [this.failure]);
  final int status;
  final Object? body;
  final String? failure;

  bool get ok => status >= 200 && status < 300;

  String describe() {
    if (failure != null) return failure!;
    final b = body;
    if (b is Map && b['code'] == 50013) {
      return 'the bot is missing a permission in that channel';
    }
    if (b is Map && b['message'] is String) return '${b['message']} ($status)';
    return 'HTTP $status';
  }
}

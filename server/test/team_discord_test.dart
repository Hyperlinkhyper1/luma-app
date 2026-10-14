import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:luma_sync_server/team_board.dart';
import 'package:luma_sync_server/team_discord.dart';
import 'package:luma_sync_server/util.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Not a real token, and deliberately not shaped like one, so secret
/// scanners leave it alone. It only has to pass the endpoint's charset and
/// length check; `whoAmI` is stubbed.
const _token = 'fake-bot-token-for-tests-only-0000000000';

void main() {
  group('rules', () {
    final swear = DiscordAutomodRule(id: 'a', words: ['ass', 'darn it']);
    final help = DiscordReplyRule(
        id: 'r', triggers: ['modpack'], reply: 'See #downloads.');

    test('whole-word automod ignores words inside other words', () {
      expect(swear.match('what a pain in the ass!'), 'ass');
      expect(swear.match('first class pass'), isNull);
      expect(swear.match('oh darn it.'), 'darn it');
      final loose =
          DiscordAutomodRule(id: 'b', words: ['ass'], wholeWord: false);
      expect(loose.match('first class'), 'ass');
    });

    test('automod goes first and a removed message gets no reply', () {
      final action = decideDiscordAction('Where is the modpack, ass',
          automod: [swear], replies: [help]);
      expect(action, isA<DiscordRemove>());
      final answer = decideDiscordAction('Where is the MODPACK?',
          automod: [swear], replies: [help]);
      expect(answer, isA<DiscordAnswer>());
      expect((answer as DiscordAnswer).trigger, 'modpack');
    });

    test('disabled rules and cooldowns stay quiet', () {
      final off = DiscordReplyRule(
          id: 'r', triggers: ['modpack'], reply: 'x', enabled: false);
      expect(
          decideDiscordAction('modpack', automod: [], replies: [off]), isNull);
      expect(
          decideDiscordAction('modpack',
              automod: [], replies: [help], replyReady: (_) => false),
          isNull);
    });

    test('match modes', () {
      DiscordReplyRule rule(String match) => DiscordReplyRule(
          id: 'r', triggers: ['ip'], reply: 'play.example.net', match: match);
      expect(rule('exact').matchIn(' ip '), 'ip');
      expect(rule('exact').matchIn('what is the ip'), isNull);
      expect(rule('word').matchIn('what is the ip?'), 'ip');
      expect(rule('word').matchIn('skip'), isNull);
      expect(rule('contains').matchIn('skip'), 'ip');
    });

    test('rules from the app are cleaned and checked', () {
      final rule = DiscordAutomodRule.fromJson({
        'words': ['  BadWord ', 'badword', ''],
        'timeoutMinutes': 10,
      })!;
      expect(rule.words, ['badword']);
      expect(rule.id, matches(RegExp(r'^[a-f0-9]{16}$')));
      expect(DiscordAutomodRule.fromJson({'words': []}), isNull);
      expect(
          DiscordAutomodRule.fromJson({
            'words': ['x'],
            'timeoutMinutes': kDiscordMaxTimeoutMinutes + 1,
          }),
          isNull);
      expect(
          DiscordReplyRule.fromJson({
            'triggers': ['x'],
            'reply': 'y' * (kDiscordMaxReplyChars + 1),
          }),
          isNull);
      expect(
          DiscordReplyRule.fromJson({
            'triggers': ['x'],
            'reply': 'y',
            'match': 'regex',
          }),
          isNull);
    });
  });

  group('forums', () {
    DiscordForumTracker tracker(String id,
            {List<String> tags = const [], bool enabled = true}) =>
        DiscordForumTracker(
            id: id,
            forumId: '100',
            tags: [for (final t in tags) DiscordForumTag(t, t)],
            enabled: enabled);

    test('a rule naming the post’s tag beats one that takes every post', () {
      final any = tracker('any');
      final crash = tracker('crash', tags: ['7']);
      expect(pickDiscordForumTracker([any, crash], '100', ['7'])?.id, 'crash');
      expect(pickDiscordForumTracker([any, crash], '100', ['8'])?.id, 'any');
      expect(pickDiscordForumTracker([crash], '100', const []), isNull);
      expect(pickDiscordForumTracker([any], '200', const []), isNull);
      expect(
          pickDiscordForumTracker(
              [tracker('off', enabled: false)], '100', const []),
          isNull);
    });

    test('what a post still misses', () {
      String missing(String require, bool image, bool log) =>
          teamBoardDiscordMissing(require, hasImage: image, hasLog: log);
      expect(missing('none', false, false), '');
      expect(missing('image', false, true), 'image');
      expect(missing('log', false, true), '');
      expect(missing('either', false, false), 'either');
      expect(missing('either', true, false), '');
      expect(missing('both', false, false), 'both');
      expect(missing('both', true, false), 'log');
      expect(missing('both', true, true), '');
    });

    test('screenshots, logs and paste links are recognised', () {
      expect(discordAttachmentIsImage('shot.JPG', null), isTrue);
      expect(discordAttachmentIsImage('clip', 'image/png'), isTrue);
      expect(discordAttachmentIsImage('latest.log', 'text/plain'), isFalse);
      expect(discordAttachmentIsLog('latest.log'), isTrue);
      expect(discordAttachmentIsLog('crash-2026.txt'), isTrue);
      expect(discordAttachmentIsLog('debug.log.gz'), isTrue);
      expect(discordTextHasLogLink('log: https://mclo.gs/abc123'), isTrue);
      expect(discordTextHasLogLink('see https://evilmclo.gs/x'), isFalse);
      expect(discordTextHasLogLink('no link here'), isFalse);
    });

    test('rules from the app are checked', () {
      final ok = DiscordForumTracker.fromJson({
        'forumId': '123456789',
        'forumName': ' bug-reports ',
        'tags': [
          {'id': '5', 'name': 'Crash'},
          {'id': '5', 'name': 'Crash'},
        ],
        'kind': 'bug',
        'require': 'both',
        'missingMessage': ' Please add a screenshot and your log. ',
      })!;
      expect(ok.forumName, 'bug-reports');
      expect(ok.tags.map((t) => t.id), ['5']);
      expect(ok.missingMessage, 'Please add a screenshot and your log.');
      for (final bad in [
        {'forumId': 'general'},
        {'forumId': '1', 'kind': 'issue'},
        {'forumId': '1', 'require': 'video'},
        {'forumId': '1', 'missingMessage': 'x' * (kDiscordMaxReplyChars + 1)},
        {
          'forumId': '1',
          'tags': [
            {'id': 'x'}
          ]
        },
      ]) {
        expect(DiscordForumTracker.fromJson(bad), isNull, reason: '$bad');
      }
    });
  });

  group('endpoints', () {
    late Directory dir;
    late Api api;
    late Handler handler;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('team_discord_api');
      final config = ServerConfig(
        port: 0,
        dataDir: dir.path,
        allowRegistration: true,
        maxBlobBytes: 1024 * 1024,
        tokenTtl: const Duration(days: 30),
        corsOrigin: '*',
        trustProxy: false,
        verificationTtl: const Duration(hours: 24),
        maxVerificationEmailsPerHour: 50,
        approvalMode: ApprovalMode.open,
        adminKey: 'test-admin-key',
        mistralApiKey: null,
        googleApiKey: null,
        itadApiKey: null,
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: null,
        wikiDir: null,
        publicUrl: 'https://sync.example.com',
        oauthProviders: const {},
      );
      api = Api(
        await Store.open(dir.path),
        config,
        Mailer(MailConfig.fromEnvironment(const {})),
        await FamilyStore.open(dir.path),
        await ChatStore.open(dir.path),
        await AiUsageStore.open(dir.path),
        await SubwayStore.open(dir.path),
        await RecipeStore.open(dir.path),
        await AiModelCatalogStore.open(dir.path),
        await AiBenchmarkStore.open(dir.path),
      );
      api.teamDiscord.whoAmI = (token) async {
        if (token != _token) {
          throw const DiscordTokenRejected(
              'Discord did not accept that token.');
        }
        return const DiscordIdentity('123456789012345678', 'ModBot');
      };
      handler = api.handler;
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> call(String method, String path,
        {Object? json, String? form, String? token, bool admin = false}) async {
      final response = await handler(Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          if (json != null) 'Content-Type': 'application/json',
          if (form != null) 'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
          if (admin) 'x-admin-key': 'test-admin-key',
        },
        body: json != null ? jsonEncode(json) : form,
      ));
      final raw = await response.readAsString();
      return {
        ...(raw.trimLeft().startsWith('{')
            ? jsonDecode(raw) as Map<String, dynamic>
            : const <String, dynamic>{}),
        'httpStatus': response.statusCode,
        'raw': raw,
      };
    }

    Future<String> register(String email, {String? role}) async {
      final result = await call('POST', '/api/v1/auth/register', json: {
        'email': email,
        'authKey': base64Encode(Uint8List.fromList(
            c.sha256.convert(utf8.encode('key:$email')).bytes)),
        'kdfSalt': base64Encode(List.filled(16, 7)),
        'kdfIterations': 210000,
      });
      expect(result['httpStatus'], 201, reason: 'register: $result');
      if (role != null) {
        await call('POST', '/admin/team-board/access?role=$role',
            admin: true, form: 'email=${Uri.encodeQueryComponent(email)}');
      }
      return result['token'] as String;
    }

    test('only the team sees the bot, and only a lead changes it', () async {
      final stranger = await register('stranger@example.com');
      final member = await register('member@example.com', role: 'member');
      final lead = await register('lead@example.com', role: 'lead');

      expect(
          (await call('GET', '/api/v1/team-board/discord',
              token: stranger))['httpStatus'],
          403);
      final seen =
          await call('GET', '/api/v1/team-board/discord', token: member);
      expect(seen['canManage'], isFalse);
      expect(seen['linked'], isFalse);

      for (final (method, path, body) in [
        ('PUT', '/api/v1/team-board/discord', {'enabled': false}),
        ('PUT', '/api/v1/team-board/discord/token', {'token': _token}),
        ('DELETE', '/api/v1/team-board/discord/token', null),
      ]) {
        expect(
            (await call(method, path, token: member, json: body))['httpStatus'],
            403,
            reason: '$method $path');
      }
      expect(
          (await call('GET', '/api/v1/team-board/discord',
              token: lead))['canManage'],
          isTrue);
    });

    test('linking checks the token and never hands it back', () async {
      final lead = await register('lead@example.com', role: 'lead');
      final wrong = await call('PUT', '/api/v1/team-board/discord/token',
          token: lead, json: {'token': '${_token}x'});
      expect(wrong['httpStatus'], 400);
      expect(wrong['error'], 'bad_token');

      final linked = await call('PUT', '/api/v1/team-board/discord/token',
          token: lead, json: {'token': _token});
      expect(linked['httpStatus'], 200);
      expect(linked['linked'], isTrue);
      expect(linked['bot'], {'id': '123456789012345678', 'name': 'ModBot'});
      expect(linked['inviteUrl'], contains('client_id=123456789012345678'));
      expect(linked['raw'], isNot(contains(_token)));
      expect(linked['status'], 'off');

      final member = await register('member@example.com', role: 'member');
      final seen =
          await call('GET', '/api/v1/team-board/discord', token: member);
      expect(seen['raw'], isNot(contains(_token)));

      final unlinked =
          await call('DELETE', '/api/v1/team-board/discord/token', token: lead);
      expect(unlinked['linked'], isFalse);
      expect(unlinked['bot'], isNull);
    });

    test('rules are saved, cleaned and survive a restart', () async {
      final lead = await register('lead@example.com', role: 'lead');
      final saved =
          await call('PUT', '/api/v1/team-board/discord', token: lead, json: {
        'automod': [
          {
            'words': ['Slur', 'slur'],
            'warn': 'Keep it friendly.',
            'timeoutMinutes': 5,
          }
        ],
        'replies': [
          {
            'triggers': ['modpack'],
            'reply': 'Grab it from #downloads.',
            'match': 'contains',
          }
        ],
      });
      expect(saved['httpStatus'], 200, reason: '$saved');
      final automod = (saved['automod'] as List).single as Map;
      expect(automod['words'], ['slur']);
      expect(automod['timeoutMinutes'], 5);

      final bad =
          await call('PUT', '/api/v1/team-board/discord', token: lead, json: {
        'replies': [
          {'triggers': [], 'reply': 'x'}
        ],
      });
      expect(bad['httpStatus'], 400);

      expect(saved['automodOn'], isFalse);
      final on = await call('PUT', '/api/v1/team-board/discord',
          token: lead, json: {'automodOn': true});
      expect(on['automodOn'], isTrue);
      expect(on['repliesOn'], isFalse);
      expect(on['automod'], hasLength(1));

      final reopened = TeamDiscordBot(dir.path);
      expect(reopened.automodOn, isTrue);
      expect(reopened.repliesOn, isFalse);
      expect(reopened.automod.single.words, ['slur']);
      expect(reopened.automod.single.warn, 'Keep it friendly.');
      expect(reopened.replies.single.reply, 'Grab it from #downloads.');
      expect(reopened.replies.single.match, 'contains');
    });

    test('a forum post goes on the board and stays in step with it', () async {
      final lead = await register('lead@example.com', role: 'lead');
      final calls = <String>[];
      final posted = <Object?>[];
      final bot = api.teamDiscord
        ..rest = (token, method, path, {body, reason}) async {
          calls.add('$method $path');
          if (method == 'GET' && path == '/channels/900/messages/900') {
            return DiscordRestResult(200, {
              'id': '900',
              'content': 'The game crashes when I open the ruby chest.',
              'author': {'id': '42', 'username': 'steve', 'bot': false},
              'attachments': [
                {
                  'filename': 'crash.jpg',
                  'url': 'https://cdn.discordapp.com/a/crash.jpg',
                  'size': 10,
                  'content_type': 'image/jpeg',
                },
              ],
            });
          }
          if (method == 'POST') posted.add(body);
          return DiscordRestResult(200, {});
        }
        ..download = (url, max) async =>
            url.endsWith('.log') ? utf8.encode('[main/INFO] boom\n') : null;

      await call('PUT', '/api/v1/team-board/discord/token',
          token: lead, json: {'token': _token});
      final saved =
          await call('PUT', '/api/v1/team-board/discord', token: lead, json: {
        'forumsOn': true,
        'trackers': [
          {
            'forumId': '100',
            'forumName': 'bug-reports',
            'kind': 'bug',
            'require': 'both',
            'missingMessage': 'Please attach your latest.log.',
            'doneMessage': 'This was {status} in the mod.',
          }
        ],
      });
      expect(saved['httpStatus'], 200, reason: '$saved');
      expect(saved['forumsOn'], isTrue);

      await bot.handleGatewayEvent('GUILD_CREATE', {
        'id': '1',
        'name': 'Mod Team',
        'channels': [
          {
            'id': '100',
            'type': 15,
            'name': 'bug-reports',
            'available_tags': [
              {'id': '5', 'name': 'Crash'}
            ],
          },
          {'id': '101', 'type': 0, 'name': 'general'},
        ],
      });
      final state =
          await call('GET', '/api/v1/team-board/discord', token: lead);
      expect((state['forums'] as List).single,
          containsPair('name', 'bug-reports'));

      Future<void> thread(String id, String forum) =>
          bot.handleGatewayEvent('THREAD_CREATE', {
            'id': id,
            'parent_id': forum,
            'guild_id': '1',
            'name': 'Ruby chest crash',
            'newly_created': true,
            'applied_tags': ['5'],
          });
      await thread('900', '100');
      await thread('900', '100');
      await thread('901', '101');

      var board = await call('GET', '/api/v1/team-board', token: lead);
      final entry = (board['entries'] as List).single as Map;
      expect(entry['kind'], 'bug');
      expect(entry['title'], 'Ruby chest crash');
      expect(entry['author'], 'steve');
      expect(entry['brief'], contains('ruby chest'));
      final link = entry['discord'] as Map;
      expect(link['url'], 'https://discord.com/channels/1/900');
      expect(link['missing'], 'log');
      expect((link['attachments'] as List).single['name'], 'crash.jpg');
      expect(posted.single, containsPair('content', contains('<@42>')));

      await bot.handleGatewayEvent('MESSAGE_CREATE', {
        'id': '950',
        'channel_id': '900',
        'guild_id': '1',
        'content': 'here you go',
        'author': {'id': '42', 'username': 'steve'},
        'attachments': [
          {
            'filename': 'latest.log',
            'url': 'https://cdn.discordapp.com/a/latest.log',
            'size': 16,
          },
        ],
      });
      final id = entry['id'];
      var full =
          await call('GET', '/api/v1/team-board/entries/$id', token: lead);
      expect((full['discord'] as Map)['missing'], '');
      final file = (full['files'] as List).single as Map;
      expect(file['name'], 'latest.log');
      expect(file['fromDiscord'], isTrue);
      final message = (full['messages'] as List).single as Map;
      expect(message['text'], 'here you go\n\nShared latest.log');
      expect(message['fromDiscord'], isTrue);

      calls.clear();
      posted.clear();
      await call('POST', '/api/v1/team-board/entries/$id/stage',
          token: lead, json: {'stage': 'added'});
      for (var i = 0; i < 100 && calls.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(calls, ['POST /channels/900/messages', 'PATCH /channels/900']);
      expect(
          posted.single, containsPair('content', 'This was fixed in the mod.'));

      calls.clear();
      await call('POST', '/api/v1/team-board/entries/$id/close',
          token: lead, json: {'closed': true});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, isEmpty, reason: 'the thread was already told');

      await bot.handleGatewayEvent('MESSAGE_CREATE', {
        'id': '951',
        'channel_id': '900',
        'guild_id': '1',
        'content': 'still broken?',
        'author': {'id': '43', 'username': 'alex'},
      });
      full = await call('GET', '/api/v1/team-board/entries/$id', token: lead);
      expect(full['messages'], hasLength(1),
          reason: 'a closed entry takes no more replies');
      board = await call('GET', '/api/v1/team-board', token: lead);
      expect(board['entries'], hasLength(1));

      final metrics = (await call('GET', '/api/v1/team-board/discord',
          token: lead))['metrics'] as Map;
      expect(metrics['cpuMs'], isA<int>());
      expect(bot.meter.cpuMicros, greaterThan(0));
      expect(metrics['diskWrittenBytes'], greaterThan(0),
          reason: 'its settings and the board saves its posts set off');
      expect(metrics['attachmentBytes'], 17, reason: 'only latest.log');
      expect(metrics['settingsBytes'],
          File('${dir.path}/team_board/discord.json').lengthSync());
      expect(metrics['memoryBytes'], greaterThan(0));
    });
  });

  group('metrics', () {
    void spin() {
      final clock = Stopwatch()..start();
      while (clock.elapsedMicroseconds < 30000) {}
    }

    test('only work in the bot’s zone counts as its CPU', () async {
      final meter = DiscordBotMeter();
      spin();
      expect(meter.cpuMicros, 0);
      meter.runSync(spin);
      expect(meter.cpuMicros, greaterThanOrEqualTo(30000));
      final before = meter.cpuMicros;
      await meter.run(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        spin();
      });
      final added = meter.cpuMicros - before;
      expect(added, greaterThanOrEqualTo(30000));
      expect(added, lessThan(400000), reason: 'waiting is not CPU');
      spin();
      expect(meter.cpuMicros, before + added);
    });

    test('only the bot’s disk writes are counted', () async {
      final dir = await Directory.systemTemp.createTemp('team_discord_meter');
      addTearDown(() => dir.delete(recursive: true));
      final meter = DiscordBotMeter();
      await atomicWriteString('${dir.path}/a', 'hello');
      expect(meter.diskWrittenBytes, 0);
      await meter.run(() => atomicWriteString('${dir.path}/b', 'héllo'));
      expect(meter.diskWrittenBytes, 6);
    });

    test('samples turn totals into rates and keep ten minutes', () async {
      final meter = DiscordBotMeter()..netInBytes = 1000;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final s = meter.sample(memoryBytes: 10, storageBytes: 20);
      expect(s.netInPerSecond, inInclusiveRange(1000, 10000));
      expect(s.memoryBytes, 10);
      expect(s.storageBytes, 20);
      expect(meter.sample(memoryBytes: 0, storageBytes: 0).netInPerSecond, 0);
      for (var i = 0; i < kDiscordMeterSamples + 5; i++) {
        meter.sample(memoryBytes: 0, storageBytes: 0);
      }
      expect(meter.samples, hasLength(kDiscordMeterSamples));
    });

    test('byte counting', () {
      expect(discordUtf8Length('abc'), 3);
      expect(discordUtf8Length('é€😀'), 2 + 3 + 4);
      expect(discordWsFrameBytes(10, masked: false), 12);
      expect(discordWsFrameBytes(200, masked: true), 208);
      expect(discordWsFrameBytes(70000, masked: false), 70010);
      expect(
          discordApproxBytes([
            'ab',
            {'k': 'v'}
          ]),
          greaterThan(discordApproxBytes(['ab'])));
    });
  });
}

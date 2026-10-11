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
import 'package:luma_sync_server/team_discord.dart';
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
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/cs2_offline_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Every signed-in device fetches the CS2 offline snapshot after each
/// 10-second sync tick. The snapshot carries the whole price history, so an
/// unchanged one has to cost a 304, not the full body again.
void main() {
  late Directory dir;
  late Store store;
  late Cs2OfflineStore offline;
  late Handler handler;

  const token = 'test-bearer-token-0123456789';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_cs2_offline_test');
    store = await Store.open(dir.path);
    offline = await Cs2OfflineStore.open(dir.path);
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
      adminKey: null,
      mistralApiKey: null,
      mistralAgentId: null,
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
    handler = Api(
      store,
      config,
      Mailer(MailConfig.fromEnvironment(const {})),
      await FamilyStore.open(dir.path),
      await ChatStore.open(dir.path),
      await AiUsageStore.open(dir.path),
      await SubwayStore.open(dir.path),
      await RecipeStore.open(dir.path),
      await AiModelCatalogStore.open(dir.path),
      await AiBenchmarkStore.open(dir.path),
      cs2OfflineStore: offline,
    ).handler;

    final filler = base64Encode(List.filled(32, 1));
    final user = StoredUser(
      id: 'u1',
      email: 'alice@example.com',
      authHash: filler,
      authSalt: filler,
      kdfSalt: base64Encode(List.filled(16, 2)),
      kdfIterations: 200000,
      quotaBytes: 1024,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      planId: 'nova',
    );
    store.usersById[user.id] = user;
    store.userIdByEmail[user.email] = user.id;
    await store.saveUsers();
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    store.sessionsByTokenHash[tokenHash] = StoredSession(
      tokenHash: tokenHash,
      userId: user.id,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      expiresAtMs:
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
    );

    await offline.put('u1', {
      'enabled': true,
      'intervalHours': 1,
      'nextCheckAtMs': 0,
      'items': [
        {'marketHashName': 'AK-47 | Redline (Field-Tested)'},
      ],
      'entries': const [],
      'points': [
        {
          'marketHashName': 'AK-47 | Redline (Field-Tested)',
          'observedAtMs': 1000,
          'lowestCents': 1234,
          'currency': 'USD',
        },
      ],
    });
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<Response> get({String? ifNoneMatch}) async => handler(Request(
        'GET',
        Uri.parse('http://localhost/api/v1/steam/cs2/offline'),
        headers: {
          'Authorization': 'Bearer $token',
          if (ifNoneMatch != null) 'If-None-Match': ifNoneMatch,
        },
      ));

  test('an unchanged snapshot revalidates to a bodyless 304', () async {
    final first = await get();
    expect(first.statusCode, 200);
    final etag = first.headers['etag'];
    expect(etag, isNotNull);
    final body = jsonDecode(await first.readAsString()) as Map;
    expect((body['points'] as List), hasLength(1));

    final second = await get(ifNoneMatch: etag);
    expect(second.statusCode, 304);
    expect(await second.readAsString(), isEmpty);
  });

  test('a weakened ETag from a compressing proxy still matches', () async {
    final etag = (await get()).headers['etag']!;
    expect((await get(ifNoneMatch: 'W/$etag')).statusCode, 304);
  });

  test('new price points change the ETag and resend the snapshot', () async {
    final etag = (await get()).headers['etag']!;

    final config = offline.forUser('u1')!;
    (config['points'] as List).add({
      'marketHashName': 'AK-47 | Redline (Field-Tested)',
      'observedAtMs': 2000,
      'lowestCents': 1300,
      'currency': 'USD',
    });
    await offline.put('u1', config);

    final changed = await get(ifNoneMatch: etag);
    expect(changed.statusCode, 200);
    expect(changed.headers['etag'], isNot(etag));
    final body = jsonDecode(await changed.readAsString()) as Map;
    expect((body['points'] as List), hasLength(2));
  });
}

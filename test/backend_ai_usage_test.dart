import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/server_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account changes during a request discard the old feed and refresh the new one',
    () async {
      final db = AiUsageDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      String? account = 'a';
      final started = Completer<void>();
      final response = Completer<List<Map<String, dynamic>>?>();
      var requests = 0;
      final repo = AiUsageRepository(
        db,
        backendAccount: () => account,
        fetchBackendCalls: () {
          requests++;
          if (requests == 1) {
            started.complete();
            return response.future;
          }
          return Future.value([]);
        },
      );
      addTearDown(repo.dispose);
      final refresh = repo.refreshBackendUsage();
      await started.future;
      account = 'b';
      await repo.refreshBackendUsage();
      response.complete([
        {'id': 'a-call', 'atMs': 1000, 'feature': 'Classroom', 'model': 'test'},
      ]);
      await refresh;
      expect(requests, 2);
      expect(await db.select(db.aiUsageTurns).get(), isEmpty);
    },
  );
  test(
    'backend tracking defaults off, syncs explicitly, and resets off',
    () async {
      final settings = await SettingsController.load();
      addTearDown(settings.dispose);
      settings.resetToDefaults();
      expect(settings.trackBackendAiUsage, isFalse);
      settings.setTrackBackendAiUsage(true);
      expect(settings.exportData()['trackBackendAiUsage'], isTrue);
      await settings.importData({'trackBackendAiUsage': false});
      expect(settings.trackBackendAiUsage, isFalse);
      await settings.importData({'trackBackendAiUsage': true});
      expect(settings.trackBackendAiUsage, isTrue);
      settings.resetToDefaults();
      expect(settings.trackBackendAiUsage, isFalse);
    },
  );

  test(
    'all gated clients carry the live opt-in flag only while enabled',
    () async {
      ServerAccessGate.instance.setApproved(true);
      var enabled = false;
      GatedServerClient.trackBackendAiUsage = () => enabled;
      addTearDown(() {
        GatedServerClient.trackBackendAiUsage = null;
        ServerAccessGate.instance.setApproved(false);
      });
      final headers = <String?>[];
      final client = GatedServerClient(
        inner: MockClient((request) async {
          headers.add(request.headers['X-Luma-Track-AI-Usage']);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);
      final url = Uri.parse(
        'https://sync.luma-app.cc/api/v1/classroom/question',
      );
      await client.post(url, headers: {'X-Luma-Track-AI-Usage': 'true'});
      enabled = true;
      await client.post(url);
      enabled = false;
      await client.post(url);
      expect(headers, [null, 'true', null]);
    },
  );

  test(
    'server calls import once, keep total tokens and cost, and clear on account change',
    () async {
      final db = AiUsageDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      String? account = 'owner@example.com';
      var calls = <Map<String, dynamic>>[
        {
          'id': 'one',
          'atMs': 1720000000000,
          'feature': 'Classroom',
          'upstream': 'OpenRouter',
          'model': 'test/model',
          'inputTokens': 120,
          'outputTokens': 0,
          'totalTokens': 200,
          'costUsd': 0,
          'cacheReadTokens': 20,
        },
        {
          'id': 'two',
          'atMs': 1720000000000,
          'feature': 'Add benchmark',
          'upstream': 'Google AI Studio',
          'model': 'test',
          'inputTokens': 5,
          'outputTokens': 10,
          'totalTokens': 15,
          'costUsd': 0.1,
        },
      ];
      final repo = AiUsageRepository(
        db,
        backendAccount: () => account,
        fetchBackendCalls: () async => calls,
      );
      addTearDown(repo.dispose);
      await repo.refreshBackendUsage();
      await repo.refreshBackendUsage();
      var rows = await db.select(db.aiUsageTurns).get();
      expect(rows, hasLength(2));
      expect(rows.first.inputTokens, 100);
      expect(rows.first.cacheReadTokens, 20);
      expect(rows.first.model, 'openrouter/test/model');
      expect(rows.first.outputTokens, 80);
      expect(rows.first.reportedCost, 0);
      expect(rows.first.deviceId, 'backend:owner@example.com');
      account = 'other@example.com';
      calls = [];
      await repo.refreshBackendUsage();
      expect(await db.select(db.aiUsageTurns).get(), isEmpty);
      account = null;
      await repo.refreshBackendUsage();
      expect(await db.select(db.aiUsageTurns).get(), isEmpty);
    },
  );
}

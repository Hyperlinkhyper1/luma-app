import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/ai_tools.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/assistant_effort.dart';
import 'package:luma/features/chat/assistant_files.dart';
import 'package:luma/features/chat/assistant_ultra_reasoning.dart';
import 'package:luma/features/chat/chat_controller.dart';
import 'package:luma/features/chat/data/chat_database.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/memory/assistant_memory_repository.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/providers/google_client.dart';
import 'package:luma/features/chat/widgets/assistant_effort_menu.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/sync_scope.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Answers each step of a research / Ultra Reasoning run by what its system
/// prompt asks for, and keeps every prompt it saw.
class _ScriptedClient extends AiClient {
  _ScriptedClient({this.reviews = const []});

  final List<String> reviews;
  final prompts = <String>[];
  var _review = 0;

  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
    AiTextProgress? onText,
  }) async {
    prompts.add(systemPrompt);
    final String text;
    if (systemPrompt.contains('You lead a small research team')) {
      text = '["first part", "second part"]';
    } else if (systemPrompt.contains('one agent on a research team')) {
      text = 'notes';
    } else if (systemPrompt.contains('Several research agents')) {
      text = 'draft answer';
    } else if (systemPrompt.contains('strict reviewer')) {
      text = _review < reviews.length ? reviews[_review++] : '{"verdict":"pass"}';
    } else if (systemPrompt.contains('Rewrite the draft answer')) {
      text = 'improved answer ${history.last.text.contains('draft answer')}';
    } else {
      text = 'plain answer';
    }
    onText?.call(text);
    return AiChatResult(
      text: text,
      usage: const AiTokenUsage(model: 'm', inputTokens: 10, outputTokens: 5),
    );
  }
}

class _Keys implements AiKeyStore {
  @override
  Future<String?> readKey(String providerId) async => 'test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tools implements AiToolRegistry {
  @override
  List<AiToolDefinition> get schemas => const [];
  @override
  List<AiToolDefinition> get localAssistantSchemas => schemas;
  @override
  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> input,
  ) async => {'status': 'ok'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSync implements SyncService {
  @override
  bool get serverReady => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoPaths extends PathProviderPlatform {
  @override
  Future<String> getApplicationSupportPath() async =>
      throw UnsupportedError('No support directory');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effort levels', () {
    test('the proxy sends only the level; the server decides the rest', () {
      final client = GoogleProxyClient(
        serverUrl: 'https://luma.example/',
        effort: AssistantEffort.max,
      );
      expect(client.extraBody, {'luma_effort': 'max'});
      expect(client.maxOutputTokens, 16384);
      expect(client.timeout, const Duration(seconds: 180));
      expect(
        GoogleProxyClient(serverUrl: 'x').extraBody,
        {'luma_effort': 'medium'},
      );
    });

    test('an own Google key maps the level itself', () {
      expect(GoogleClient(effort: AssistantEffort.low).reasoningEffort, 'low');
      expect(GoogleClient().reasoningEffort, isNull);
      expect(GoogleClient(effort: AssistantEffort.extra).reasoningEffort, 'high');
    });

    test('unknown saved levels fall back to the recommended one', () {
      expect(AssistantEffort.parse('turbo'), AssistantEffort.medium);
      expect(AssistantEffort.parse(null), AssistantEffort.medium);
    });

    test('Ultra Reasoning needs Nova and Luma AI', () {
      bool active(String? plan, String provider) => ultraReasoningActive(
        enabled: true,
        planId: plan,
        providerId: provider,
      );
      expect(active('nova', 'google'), isTrue);
      expect(active('orbit', 'google'), isFalse);
      expect(active('nova', 'openai'), isFalse);
    });

    test('reply metadata names the effort or the Ultra rounds', () {
      expect(chatEffortOf(jsonEncode({'effort': 'high'}))?.effort,
          AssistantEffort.high);
      expect(chatEffortOf(jsonEncode({
        'ultra': {'checks': 2, 'revisions': 1},
      }))?.checks, 2);
      expect(chatEffortOf('{}'), isNull);
      expect(chatEffortOf('not json'), isNull);
    });
  });

  group('parseUltraReview', () {
    test('reads the JSON verdict', () {
      final r = parseUltraReview(
        'Sure: {"verdict": "revise", "issues": ["fix the date", " "]}',
      );
      expect(r.pass, isFalse);
      expect(r.issues, ['fix the date']);
      expect(parseUltraReview('{"verdict":"pass","issues":[]}').pass, isTrue);
    });

    test('falls back to bullets, and passes when nothing is usable', () {
      expect(parseUltraReview('- wrong unit\n- missing step').issues,
          ['wrong unit', 'missing step']);
      expect(parseUltraReview('Looks great to me.').pass, isTrue);
      expect(parseUltraReview('{"verdict":"revise","issues":[]}').pass, isTrue);
    });
  });

  group('UltraReasoning', () {
    test('researches, then revises until the reviewer passes', () async {
      final client = _ScriptedClient(
        reviews: ['{"verdict":"revise","issues":["add sources"]}'],
      );
      final activities = <AssistantActivity>[];
      final result = await UltraReasoning(
        client: client,
        apiKey: 'k',
        parallel: true,
        systemPrompt: 'base',
        onActivity: activities.add,
      ).run([const AiTurn(role: 'user', text: 'question')]);

      expect(result.result.text, 'improved answer true');
      expect(result.checks, 2);
      expect(result.revisions, 1);
      expect(result.result.usage?.inputTokens, greaterThan(10));
      expect(
        activities.where((a) => a.reviewing).map((a) => (a.round, a.improving)),
        [(1, false), (1, true), (2, false)],
      );
      expect(client.prompts.where((p) => p.contains('strict reviewer')).length, 2);
    });

    test('stops after the round limit', () async {
      final client = _ScriptedClient(
        reviews: List.filled(5, '{"verdict":"revise","issues":["more"]}'),
      );
      final result = await UltraReasoning(
        client: client,
        apiKey: 'k',
        parallel: false,
        systemPrompt: 'base',
        rounds: 2,
      ).run([const AiTurn(role: 'user', text: 'question')]);
      expect(result.checks, 2);
      expect(result.revisions, 2);
    });
  });

  group('ChatController', () {
    late ChatDatabase db;
    late ChatRepository repo;
    late Directory directory;
    late AssistantMemoryRepository memory;
    late SettingsController settings;

    setUp(() async {
      db = ChatDatabase(NativeDatabase.memory());
      repo = ChatRepository(db);
      directory = await Directory.systemTemp.createTemp('luma_effort_');
      memory = AssistantMemoryRepository(
        supportDirectoryProvider: () async => directory,
      );
      await memory.ready;
      settings = await SettingsController.load();
      settings.setAiProviderId('google');
      settings.setAiMode('smarter');
    });

    tearDown(() async {
      settings.setUltraReasoning(false);
      settings.setAssistantEffort('medium');
      settings.dispose();
      memory.dispose();
      await db.close();
      await directory.delete(recursive: true);
    });

    ChatController controllerWith(AiClient client) => ChatController(
      repository: repo,
      keyStore: _Keys(),
      tools: _Tools(),
      settings: settings,
      memory: memory,
      clientOverride: client,
      artifactStore: AssistantArtifactStore(
        repo,
        directory: () async => directory,
      ),
    );

    test('Ultra Reasoning runs the review loop and tags the reply', () async {
      settings.setAdminPlan('nova');
      settings.setUltraReasoning(true);
      final client = _ScriptedClient(
        reviews: ['{"verdict":"revise","issues":["be precise"]}'],
      );
      final controller = controllerWith(client);
      addTearDown(controller.dispose);
      final chat = await repo.createConversation();
      await controller.sendMessage(chat, 'why is the sky blue?');

      final reply = (await repo.loadMessages(chat)).last;
      expect(reply.role, 'assistant');
      expect(reply.content, 'improved answer true');
      expect(chatEffortOf(reply.metadataJson)?.checks, 2);
      expect(client.prompts.first, contains('Take maximum care'));
    });

    test('Ultra Reasoning stays off below Nova', () async {
      settings.setAdminPlan('orbit');
      settings.setUltraReasoning(true);
      final client = _ScriptedClient();
      final controller = controllerWith(client);
      addTearDown(controller.dispose);
      final chat = await repo.createConversation();
      await controller.sendMessage(chat, 'hello');
      expect(client.prompts, hasLength(1));
      expect((await repo.loadMessages(chat)).last.content, 'plain answer');
    });

    test('a higher effort prompts for care and tags the reply', () async {
      settings.setAdminPlan('orbit');
      settings.setAssistantEffort('extra');
      final client = _ScriptedClient();
      final controller = controllerWith(client);
      addTearDown(controller.dispose);
      final chat = await repo.createConversation();
      await controller.sendMessage(chat, 'hello');
      expect(client.prompts.single, contains('Take extra care'));
      final reply = (await repo.loadMessages(chat)).last;
      expect(chatEffortOf(reply.metadataJson)?.effort, AssistantEffort.extra);
    });

    test('plan mode keeps its own flow with Ultra on', () async {
      settings.setAdminPlan('nova');
      settings.setUltraReasoning(true);
      final client = _ScriptedClient();
      final controller = controllerWith(client);
      addTearDown(controller.dispose);
      final chat = await repo.createConversation();
      await controller.sendMessage(
        chat,
        'plan a trip',
        mode: AssistantComposeMode.plan,
      );
      expect(client.prompts, hasLength(1));
      expect(client.prompts.single, contains(kPlanModePrompt));
    });
  });

  group('effort menu', () {
    final previousPaths = PathProviderPlatform.instance;
    setUp(() => PathProviderPlatform.instance = _NoPaths());
    tearDown(() => PathProviderPlatform.instance = previousPaths);

    Widget app(SettingsController settings) => SyncScope(
      service: _NoSync(),
      child: MaterialApp(
        theme: LumaTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: AssistantEffortButton(settings: settings),
          ),
        ),
      ),
    );

    testWidgets('picks a level and turns Ultra Reasoning on and off', (
      tester,
    ) async {
      final settings = await SettingsController.load();
      addTearDown(settings.dispose);
      settings.setAiProviderId('google');
      settings.setAdminPlan('nova');
      await tester.pumpWidget(app(settings));
      expect(find.text('Medium'), findsOneWidget);

      await tester.tap(find.byType(AssistantEffortButton));
      await tester.pumpAndSettle();
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('3.5× or more usage'), findsOneWidget);
      await tester.tap(find.text('Max'));
      await tester.pumpAndSettle();
      expect(settings.assistantEffort, 'max');
      expect(find.text('Max'), findsOneWidget);

      await tester.tap(find.byType(AssistantEffortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ultra Reasoning'));
      await tester.pumpAndSettle();
      expect(settings.ultraReasoning, isTrue);
      expect(find.text('Ultra Reasoning'), findsOneWidget);

      await tester.tap(find.byType(AssistantEffortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low'));
      await tester.pumpAndSettle();
      expect(settings.assistantEffort, 'low');
      expect(settings.ultraReasoning, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ultra Reasoning is locked below Nova; hidden off Luma AI', (
      tester,
    ) async {
      final settings = await SettingsController.load();
      addTearDown(settings.dispose);
      settings.setAiProviderId('google');
      settings.setAdminPlan('orbit');
      await tester.pumpWidget(app(settings));
      await tester.tap(find.byType(AssistantEffortButton));
      await tester.pumpAndSettle();
      expect(find.text('Requires Nova'), findsOneWidget);
      await tester.tap(find.text('Ultra Reasoning'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.ultraReasoning, isFalse);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      settings.setAiProviderId('openai');
      await tester.pumpAndSettle();
      expect(find.text('Medium'), findsNothing);
    });
  });
}

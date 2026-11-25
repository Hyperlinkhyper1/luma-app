import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/ai_tools.dart';
import 'package:luma/features/chat/assistant_auto_router.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/assistant_files.dart';
import 'package:luma/features/chat/chat_controller.dart';
import 'package:luma/features/chat/chat_usage.dart';
import 'package:luma/features/chat/data/chat_database.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/memory/assistant_memory_repository.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/providers/ai_modes.dart';
import 'package:luma/features/chat/providers/luma_image_client.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/sync_service.dart';

class _Keys implements AiKeyStore {
  @override
  Future<String?> readKey(String providerId) async => 'test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServerSync extends ChangeNotifier implements SyncService {
  @override
  Future<AiServerStatus?> aiStatus() async => AiServerStatus.fromJson({
    'imageInputModes': {'normal': true, 'smarter': true, 'smartest': true},
    'picture': {
      'configured': true,
      'weeklyPct': 1.0,
      'proConfigured': true,
      'proWeeklyPct': 4.0,
      'imageInput': true,
      'proImageInput': true,
    },
  });
  @override
  bool get serverReady => true;
  @override
  String? get serverUrl => 'https://luma.example';
  @override
  String? get authToken => 'test';
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

class _Client extends AiClient {
  final prompts = <String>[];
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
    if (systemPrompt.contains('Create a .pdf file')) {
      await executeTool(AssistantArtifactStore.toolName, {
        'name': 'week',
        'type': 'pdf',
        'content': 'Monday: gym',
      });
    }
    return const AiChatResult(text: 'Done');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatDatabase db;
  late ChatRepository repo;
  late Directory directory;
  late AssistantMemoryRepository memory;
  late SettingsController settings;
  late _Client client;
  late _ServerSync sync;
  late ChatController controller;
  late List<Map> pictureRequests;

  setUp(() async {
    db = ChatDatabase(NativeDatabase.memory());
    repo = ChatRepository(db);
    directory = await Directory.systemTemp.createTemp('luma_auto_route_');
    memory = AssistantMemoryRepository(
      supportDirectoryProvider: () async => directory,
    );
    await memory.ready;
    settings = await SettingsController.load();
    settings.setAiProviderId('google');
    settings.setAiMode(kAutoAiMode);
    settings.setPictureTier('standard');
    client = _Client();
    sync = _ServerSync();
    pictureRequests = [];
    controller = ChatController(
      repository: repo,
      keyStore: _Keys(),
      tools: _Tools(),
      settings: settings,
      syncService: sync,
      memory: memory,
      clientOverride: client,
      artifactStore: AssistantArtifactStore(
        repo,
        directory: () async => directory,
      ),
      imageDirectory: () async => directory,
      imageClientFor: (url) => LumaImageClient(
        serverUrl: url,
        httpClient: MockClient((request) async {
          pictureRequests.add(jsonDecode(request.body) as Map);
          return http.Response(
            jsonEncode({
              'image': base64Encode([1, 2, 3]),
              'mimeType': 'image/png',
            }),
            200,
          );
        }),
      ),
    );
  });

  tearDown(() async {
    controller.dispose();
    sync.dispose();
    settings.setAiMode('normal');
    settings.dispose();
    memory.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<({AutoRouteKind kind, AiMode mode, String? tier})?> lastRoute(
    int chat,
  ) async =>
      chatAutoRouteOf((await repo.loadMessages(chat)).last.metadataJson);

  test('easy and hard questions land on different models', () async {
    settings.setAdminPlan('nova');
    final chat = await repo.createConversation();
    final before = Map.of(settings.modelUsage);

    await controller.sendMessage(chat, 'hi there');
    expect((await lastRoute(chat))?.mode, AiMode.normal);

    await controller.sendMessage(chat, 'refactor this dart class for me');
    expect((await lastRoute(chat))?.mode, AiMode.smartest);

    expect(
      settings.modelUsage['google:normal'],
      (before['google:normal'] ?? 0) + 1,
    );
    expect(
      settings.modelUsage['google:smartest'],
      (before['google:smartest'] ?? 0) + 1,
    );
  });

  test('pictures go to the cheaper model, edits and detail to Pro', () async {
    settings.setAdminPlan('orbit');
    final chat = await repo.createConversation();

    await controller.sendMessage(chat, 'draw a cat');
    expect(pictureRequests.last['tier'], 'standard');
    expect((await lastRoute(chat))?.kind, AutoRouteKind.picture);

    await controller.sendMessage(chat, 'now make it night');
    expect(pictureRequests.last['tier'], 'pro');
    expect(pictureRequests.last['prompt'], contains('Edit that picture'));
    expect((await lastRoute(chat))?.kind, AutoRouteKind.pictureEdit);

    final other = await repo.createConversation();
    await controller.sendMessage(
      other,
      'generate a photorealistic image of a lighthouse',
    );
    expect(pictureRequests.last['tier'], 'pro');
    expect(settings.pictureTier, 'standard');
  });

  test('a file named in the prompt is created directly', () async {
    settings.setAdminPlan('orbit');
    final chat = await repo.createConversation();
    await controller.sendMessage(chat, 'make me a pdf of my week');
    expect(client.prompts.last, contains('Create a .pdf file'));
    final reply = (await repo.loadMessages(chat)).last;
    expect(reply.role, 'assistant');
    expect((await repo.watchArtifacts().first).single.name, endsWith('.pdf'));
    expect(chatAutoRouteOf(reply.metadataJson)?.kind, AutoRouteKind.file);
  });

  test('deep research runs on the best model on Nova', () async {
    settings.setAdminPlan('nova');
    final chat = await repo.createConversation();
    await controller.sendMessage(chat, 'research the best e-bikes under 2000');
    final reply = (await repo.loadMessages(chat)).last;
    expect(chatComposeModeOf(reply.metadataJson),
        AssistantComposeMode.deepResearch);
    expect(chatAutoRouteOf(reply.metadataJson)?.mode, AiMode.smartest);
    expect(client.prompts.length, greaterThan(1));
  });

  test('an explicit + menu mode wins over the route', () async {
    settings.setAdminPlan('nova');
    final chat = await repo.createConversation();
    await controller.sendMessage(
      chat,
      'draw a cat',
      mode: AssistantComposeMode.plan,
    );
    expect(pictureRequests, isEmpty);
    expect(client.prompts.last, contains(kPlanModePrompt));
  });

  test('other models never route', () async {
    settings.setAdminPlan('nova');
    settings.setAiMode(AiMode.smarter.name);
    final chat = await repo.createConversation();
    await controller.sendMessage(chat, 'draw a cat');
    expect(pictureRequests, isEmpty);
    expect(await lastRoute(chat), isNull);
  });
}

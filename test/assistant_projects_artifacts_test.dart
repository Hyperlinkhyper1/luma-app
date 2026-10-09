import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/ai_tools.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/assistant_files.dart';
import 'package:luma/features/chat/chat_controller.dart';
import 'package:luma/features/chat/data/chat_database.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/memory/assistant_memory_repository.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/providers/luma_image_client.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// Compare with the separate server package without adding it to the app dependencies.
// ignore: avoid_relative_lib_imports
import '../server/lib/assistant_files.dart' as server;

class _Keys implements AiKeyStore {
  @override
  Future<String?> readKey(String providerId) async => 'test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServerSync extends ChangeNotifier implements SyncService {
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
  List<AiToolDefinition> get schemas => [
    const AiToolDefinition(name: 'remember', description: '', parameters: {}),
    const AiToolDefinition(
      name: 'generate_qr_code',
      description: '',
      parameters: {},
    ),
  ];
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
  String prompt = '';
  List<AiTurn> turns = [];
  List<AiToolDefinition> schemas = [];
  int calls = 0;
  Future<void> Function(AiToolExecutor)? action;
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
    calls++;
    prompt = systemPrompt;
    turns = history;
    schemas = tools;
    await action?.call(executeTool);
    return const AiChatResult(text: 'Done');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Free legacy requests keep ordinary tools while file tools and forced file operations stay restricted',
    () {
      final body = <String, dynamic>{
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'tools': [
          {
            'function': {'name': 'generate_qr_code'},
          },
          {
            'function': {'name': 'create_artifact'},
          },
          {
            'function': {'name': 'remember'},
          },
        ],
      };
      server.stripAssistantFileTools(body);
      expect((body['tools'] as List).single['function']['name'], 'remember');
      expect(server.assistantRequestUsesFiles(body), isFalse);
      body['tool_choice'] = {
        'type': 'function',
        'function': {'name': 'create_artifact'},
      };
      expect(server.assistantRequestUsesFiles(body), isTrue);
    },
  );
  late ChatDatabase db;
  late ChatRepository repo;
  late Directory directory;
  late AssistantMemoryRepository memory;
  late SettingsController settings;
  late _Client client;
  late ChatController controller;
  late AssistantArtifactStore artifacts;
  setUp(() async {
    db = ChatDatabase(NativeDatabase.memory());
    repo = ChatRepository(db);
    directory = await Directory.systemTemp.createTemp(
      'luma_projects_artifacts_',
    );
    memory = AssistantMemoryRepository(
      supportDirectoryProvider: () async => directory,
    );
    await memory.ready;
    settings = await SettingsController.load();
    settings.setAiProviderId('openai');
    client = _Client();
    artifacts = AssistantArtifactStore(repo, directory: () async => directory);
    controller = ChatController(
      repository: repo,
      keyStore: _Keys(),
      tools: _Tools(),
      settings: settings,
      memory: memory,
      clientOverride: client,
      artifactStore: artifacts,
    );
  });
  tearDown(() async {
    controller.dispose();
    settings.dispose();
    memory.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'search matches message contents in projects and keeps literal wildcard searches',
    () async {
      final project = await repo.createProject('Project');
      final chat = await repo.createConversation(
        title: 'Ordinary title',
        projectId: project,
      );
      await repo.addMessage(chat, 'user', 'A rare needle costs 15%');
      await repo.createConversation(title: 'An unrelated chat');
      expect(
        (await repo.watchConversations(query: 'NEEDLE').first).single.id,
        chat,
      );
      expect(await repo.watchConversations(query: 'absent').first, isEmpty);
      expect(
        (await repo.watchConversations(query: '15%').first).single.id,
        chat,
      );
      expect((await repo.watchConversations(query: '%').first).single.id, chat);
    },
  );

  test(
    'project turns use global memory plus only their own memory and scope writes',
    () async {
      await memory.remember(
        section: MemorySection.you,
        title: 'User',
        fact: 'Prefers brief replies',
      );
      final a = await repo.createProject('A');
      final b = await repo.createProject('B');
      await repo.rememberProjectFact(a, 'A private fact');
      await repo.rememberProjectFact(b, 'B private fact');
      final chat = await repo.createConversation(projectId: a);
      client.action = (execute) async {
        await execute('remember', {
          'title': 'A',
          'fact': 'New project fact',
          'section': 'areas',
        });
      };
      await controller.sendMessage(chat, 'Hello');
      expect(client.prompt, contains('Prefers brief replies'));
      expect(client.prompt, contains('A private fact'));
      expect(client.prompt, isNot(contains('B private fact')));
      expect((await repo.loadProject(a))!.memory, contains('New project fact'));
      expect(
        memory.entries.any((e) => e.body.contains('New project fact')),
        isFalse,
      );
      final main = await repo.createConversation();
      await controller.sendMessage(main, 'Hello');
      expect(client.prompt, isNot(contains('A private fact')));
      await memory.setMemoryEnabled(false);
      await controller.sendMessage(chat, 'Hello');
      expect(client.prompt, isNot(contains('A private fact')));
    },
  );

  test('project deletion retains chats and artifacts', () async {
    final project = await repo.createProject('Keep chats');
    final chat = await repo.createConversation(projectId: project);
    await repo.addMessage(chat, 'user', 'Keep this');
    await artifacts.create(chat, {
      'name': 'note',
      'type': 'txt',
      'content': 'Keep file',
    });
    await repo.deleteProject(project);
    expect((await repo.watchConversations().first).single.projectId, isNull);
    expect((await repo.loadMessages(chat)).single.content, 'Keep this');
    await repo.deleteConversation(chat);
    final file = (await repo.watchArtifacts().first).single;
    expect(file.conversationId, isNull);
    expect(await File(file.path).readAsString(), 'Keep file');
  });

  test(
    'Free blocks uploads, selected artifacts, picture mode, and unadvertised tools',
    () async {
      final chat = await repo.createConversation();
      settings.setAdminPlan('core');
      await controller.sendMessage(chat, 'file', artifactType: 'txt');
      await controller.sendMessage(
        chat,
        'upload',
        attachments: [
          const AssistantAttachment(
            name: 'a.txt',
            mimeType: 'text/plain',
            text: 'text',
          ),
        ],
      );
      await controller.sendMessage(
        chat,
        'picture',
        mode: AssistantComposeMode.picture,
      );
      expect(client.calls, 0);
      client.action = (execute) async {
        expect(
          (await execute('create_artifact', {
            'name': 'forbidden',
            'type': 'txt',
            'content': 'no',
          }))['status'],
          'unavailable',
        );
        expect(
          (await execute('generate_qr_code', {
            'url': 'https://example.com',
          }))['status'],
          'unavailable',
        );
      };
      await controller.sendMessage(chat, 'ordinary');
      expect(
        client.schemas.any(
          (t) => t.name == 'create_artifact' || t.name == 'generate_qr_code',
        ),
        isFalse,
      );
      expect(await repo.watchArtifacts().first, isEmpty);
    },
  );

  test(
    'Orbit creates an actual file, links metadata and persists upload content',
    () async {
      settings.setAdminPlan('orbit');
      final chat = await repo.createConversation();
      client.action = (execute) async {
        await execute('create_artifact', {
          'name': '../../report',
          'type': 'json',
          'content': '{"ok":true}',
        });
      };
      await controller.sendMessage(
        chat,
        'Create report',
        artifactType: 'json',
        attachments: [
          const AssistantAttachment(
            name: 'context.txt',
            mimeType: 'text/plain',
            text: 'Source text',
          ),
          const AssistantAttachment(
            name: 'pic.png',
            mimeType: 'image/png',
            base64Data: 'YQ==',
          ),
        ],
      );
      final file = (await repo.watchArtifacts().first).single;
      expect(file.name, 'report.json');
      expect(file.path.startsWith(directory.path), isTrue);
      expect(jsonDecode(await File(file.path).readAsString()), {'ok': true});
      final messages = await repo.loadMessages(chat);
      expect(
        jsonDecode(messages.last.metadataJson!)['artifacts'],
        hasLength(1),
      );
      expect(client.turns.last.text, contains('Source text'));
      expect(client.turns.last.images.single.data, 'YQ==');
      settings.setAdminPlan('core');
      client.action = null;
      await controller.sendMessage(chat, 'Continue');
      expect(client.turns.first.images, isEmpty);
      expect(client.turns.first.text, isNot(contains('Source text')));
    },
  );

  test('missing model artifact is reported without inventing a file', () async {
    settings.setAdminPlan('nova');
    final chat = await repo.createConversation();
    await controller.sendMessage(chat, 'Make file', artifactType: 'pdf');
    expect((await repo.loadMessages(chat)).last.role, 'error');
    expect(await repo.watchArtifacts().first, isEmpty);
  });

  test(
    'Orbit picture mode stores and indexes the returned picture; Free never calls the image service',
    () async {
      final sync = _ServerSync();
      var requests = 0;
      final imageController = ChatController(
        repository: repo,
        keyStore: _Keys(),
        tools: _Tools(),
        settings: settings,
        syncService: sync,
        imageDirectory: () async => directory,
        imageClientFor: (url) => LumaImageClient(
          serverUrl: url,
          httpClient: MockClient((request) async {
            requests++;
            return http.Response(
              jsonEncode({
                'image': base64Encode([1, 2, 3]),
                'mimeType': 'image/webp',
              }),
              200,
            );
          }),
        ),
      );
      try {
        settings.setAdminPlan('orbit');
        final chat = await repo.createConversation();
        await imageController.sendMessage(
          chat,
          'Draw a cat',
          mode: AssistantComposeMode.picture,
        );
        final artifact = (await repo.watchArtifacts().first).single;
        expect(artifact.mimeType, 'image/webp');
        expect(artifact.path, endsWith('.webp'));
        expect(await File(artifact.path).readAsBytes(), [1, 2, 3]);
        expect((await repo.loadMessages(chat)).last.role, 'assistant');
        settings.setAdminPlan('core');
        await imageController.sendMessage(
          chat,
          'Draw another cat',
          mode: AssistantComposeMode.picture,
        );
        expect(requests, 1);
        expect((await repo.loadMessages(chat)).last.role, 'error');
      } finally {
        imageController.dispose();
        sync.dispose();
      }
    },
  );

  test('PDF creation writes a readable PDF and rejects invalid JSON', () async {
    final chat = await repo.createConversation();
    final file = await artifacts.create(chat, {
      'name': 'document',
      'type': 'pdf',
      'content': 'A real PDF document',
    });
    final pdf = PdfDocument(
      inputBytes: await File(file['path'] as String).readAsBytes(),
    );
    expect(
      PdfTextExtractor(pdf).extractText(),
      contains('A real PDF document'),
    );
    pdf.dispose();
    expect(
      artifacts.create(chat, {
        'name': 'bad',
        'type': 'json',
        'content': 'not json',
      }),
      throwsFormatException,
    );
  });

  test(
    'recent attachments fit the proxy body and unavailable images are described honestly',
    () async {
      settings.setAdminPlan('orbit');
      final chat = await repo.createConversation();
      const image = AssistantAttachment(
        name: 'image.png',
        mimeType: 'image/png',
        base64Data: 'YQ==',
      );
      await controller.sendMessage(
        chat,
        'First',
        attachments: [image, image, image],
      );
      await controller.sendMessage(chat, 'Second', attachments: [image, image]);
      expect(client.turns.expand((turn) => turn.images), hasLength(3));
      expect(client.turns.first.text, contains('not available to this model'));
      settings.setAiProviderId('local');
      await controller.sendMessage(chat, 'Continue');
      expect(client.turns.expand((turn) => turn.images), isEmpty);
      expect(client.turns.first.text, contains('not available to this model'));
      expect(
        server.assistantChatBodyLimit('orbit'),
        greaterThan(16 * 1024 * 1024),
      );
      expect(server.assistantChatBodyLimit('core'), 64 * 1024);
    },
  );

  test('legacy pictures are indexed once', () async {
    final chat = await repo.createConversation();
    await repo.addMessage(
      chat,
      'assistant',
      '',
      metadataJson: jsonEncode({'imagePath': '${directory.path}/legacy.png'}),
    );
    await repo.indexExistingArtifacts();
    await repo.indexExistingArtifacts();
    expect(await repo.watchArtifacts().first, hasLength(1));
  });

  test('version 2 database migrates without losing existing chats', () async {
    await db.close();
    final old = ChatDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute(
            'CREATE TABLE chat_conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch()), updated_at INTEGER NOT NULL DEFAULT (unixepoch()), pinned INTEGER NOT NULL DEFAULT 0)',
          );
          sqlite.execute(
            'CREATE TABLE chat_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, metadata_json TEXT, created_at INTEGER NOT NULL DEFAULT (unixepoch()))',
          );
          sqlite.execute(
            "INSERT INTO chat_conversations (title) VALUES ('Existing chat')",
          );
          sqlite.execute(
            "INSERT INTO chat_messages (conversation_id, role, content) VALUES (1, 'user', 'Existing message')",
          );
          sqlite.execute('PRAGMA user_version = 2');
        },
      ),
    );
    try {
      final migrated = ChatRepository(old);
      expect(
        (await migrated.watchConversations().first).single.title,
        'Existing chat',
      );
      expect(
        (await migrated.loadMessages(1)).single.content,
        'Existing message',
      );
      final project = await migrated.createProject('Migrated project');
      await migrated.moveConversation(1, project);
      expect(
        (await migrated.watchConversations().first).single.projectId,
        project,
      );
    } finally {
      await old.close();
    }
  });

  test(
    'projects, memory, memberships and artifact records survive a database reload',
    () async {
      await db.close();
      final file = File('${directory.path}/chat.sqlite');
      final disk = ChatDatabase(NativeDatabase(file));
      final saved = ChatRepository(disk);
      final project = await saved.createProject('Persistent');
      await saved.rememberProjectFact(project, 'Saved memory');
      final chat = await saved.createConversation(projectId: project);
      await saved.addMessage(chat, 'user', 'Saved chat');
      await saved.addArtifact(
        conversationId: chat,
        name: 'file.txt',
        path: '${directory.path}/file.txt',
        mimeType: 'text/plain',
      );
      await disk.close();
      final reloaded = ChatDatabase(NativeDatabase(file));
      try {
        final stored = ChatRepository(reloaded);
        expect((await stored.loadProject(project))!.memory, 'Saved memory');
        expect(
          (await stored.watchConversations().first).single.projectId,
          project,
        );
        expect((await stored.loadMessages(chat)).single.content, 'Saved chat');
        expect((await stored.watchArtifacts().first).single.name, 'file.txt');
      } finally {
        await reloaded.close();
      }
    },
  );

  test(
    'app and server entitlements agree and recognize files without blocking normal chat',
    () {
      for (final plan in [null, 'core', 'orbit', 'nova', 'unknown']) {
        expect(assistantFilesAllowed(plan), server.assistantFilesAllowed(plan));
        expect(assistantFilesAllowed(plan), plan == 'orbit' || plan == 'nova');
      }
      expect(
        server.assistantRequestUsesFiles({
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
        isFalse,
      );
      expect(
        server.assistantRequestUsesFiles({
          'messages': [
            {'content': '<luma_attachment name="a">x</luma_attachment>'},
          ],
        }),
        isTrue,
      );
      expect(
        server.assistantRequestUsesFiles({
          'tools': [
            {
              'function': {'name': 'create_artifact'},
            },
          ],
        }),
        isTrue,
      );
      expect(
        server.assistantRequestHasImages({
          'messages': [
            {
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,YQ=='},
                },
              ],
            },
          ],
        }),
        isTrue,
      );
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/ai_tools.dart';
import 'package:luma/features/chat/assistant_files.dart';
import 'package:luma/features/chat/chat_controller.dart';
import 'package:luma/features/chat/data/chat_database.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/office/assistant_workbench.dart';
import 'package:luma/features/chat/office/office_document.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/widgets/assistant_file_panel.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/theme/luma_theme.dart';

String _documentXml(String path) => utf8.decode(
  ZipDecoder()
          .decodeBytes(File(path).readAsBytesSync())
          .findFile('word/document.xml')!
          .content
      as List<int>,
);

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

/// Builds a report the way a model would: create, then two edits.
class _WritingClient extends AiClient {
  List<String> toolNames = const [];
  final activeDuringEdits = <bool>[];
  AssistantWorkbench? workbench;

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
    toolNames = [for (final t in tools) t.name];
    if (!systemPrompt.contains('create_office_file, then build it')) {
      return const AiChatResult(text: 'No file asked for');
    }
    final created = await executeTool(AssistantWorkbench.createTool, {
      'type': 'docx',
      'name': 'notitie',
      'title': 'Notitie',
    });
    final id = created['file_id'];
    await executeTool(AssistantWorkbench.editTool, {
      'file_id': id,
      'action': 'append',
      'content': '# Doel\n\nDeze notitie geeft een beeld.',
    });
    activeDuringEdits.add(workbench!.modelActive);
    await executeTool(AssistantWorkbench.editTool, {
      'file_id': id,
      'action': 'append',
      'content': '## Kernboodschap\n\n- Bellen en downloaden',
    });
    return const AiChatResult(text: 'Klaar');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatDatabase db;
  late ChatRepository repo;
  late Directory directory;
  late AssistantWorkbench workbench;

  setUp(() async {
    db = ChatDatabase(NativeDatabase.memory());
    repo = ChatRepository(db);
    directory = await Directory.systemTemp.createTemp('luma_office_');
    workbench = AssistantWorkbench(repo, directory: () async => directory);
  });

  tearDown(() async {
    workbench.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  group('tools', () {
    test(
      'create writes the file, its sidecar and an artifact, and opens it',
      () async {
        final chat = await repo.createConversation();
        final result = await workbench.execute(
          chat,
          AssistantWorkbench.createTool,
          {'type': 'docx', 'name': '../../Bestuursnotitie 2026.docx'},
        );
        expect(result['status'], 'created');
        final path = result['path'] as String;
        expect(
          p(path),
          startsWith(p(directory.path)),
          reason: 'no path escape',
        );
        expect(result['name'], 'Bestuursnotitie 2026.docx');
        expect(File(path).existsSync(), isTrue);
        expect(File(AssistantWorkbench.sidecarPath(path)).existsSync(), isTrue);
        final artifacts = await repo.watchArtifacts().first;
        expect(artifacts.single.id, result['file_id']);
        expect(artifacts.single.conversationId, chat);
        expect(workbench.file?.path, path);
        expect(workbench.session?.document.kind, OfficeKind.docx);
      },
    );

    test('each edit lands on disk and moves the focus', () async {
      final chat = await repo.createConversation();
      final created = await workbench.execute(
        chat,
        AssistantWorkbench.createTool,
        {'type': 'docx', 'name': 'r'},
      );
      final id = created['file_id'];
      final edited = await workbench.execute(
        chat,
        AssistantWorkbench.editTool,
        {'file_id': id, 'action': 'append', 'content': '# Een\n\nTwee & drie'},
      );
      expect(edited['status'], 'saved');
      expect(edited['changed'], 'blocks 0-1');
      expect(workbench.focus?.activity, OfficeActivity.writing);
      expect((workbench.focus?.start, workbench.focus?.end), (0, 1));
      expect(_documentXml(created['path']), contains('Twee &amp; drie'));

      await workbench.execute(chat, AssistantWorkbench.readTool, {
        'file_id': id,
        'index': 1,
      });
      expect(workbench.focus?.activity, OfficeActivity.reading);
      expect(workbench.focus?.start, 1);
    });

    test('read lists, outlines and returns parts in edit markdown', () async {
      final chat = await repo.createConversation();
      final id = (await workbench.execute(chat, AssistantWorkbench.createTool, {
        'type': 'pptx',
        'name': 'deck',
      }))['file_id'];
      await workbench.execute(chat, AssistantWorkbench.editTool, {
        'file_id': id,
        'action': 'append',
        'content': '# Cover\n---\n# Punten\n- een',
      });

      final listing = await workbench.execute(
        chat,
        AssistantWorkbench.readTool,
        {},
      );
      expect(listing['files'], [
        {'file_id': id, 'name': 'deck.pptx'},
      ]);
      final outline = await workbench.execute(
        chat,
        AssistantWorkbench.readTool,
        {'file_id': id},
      );
      expect((outline['outline'] as List).length, 2);
      expect(
        workbench.focus?.start,
        -1,
        reason: 'outline reads highlight nothing',
      );
      final part = await workbench.execute(chat, AssistantWorkbench.readTool, {
        'file_id': id,
        'index': 1,
      });
      expect(part['content'], '[1]\n# Punten\n- een');
    });

    test(
      'spreadsheets take sheet, cell and rows and read back a range',
      () async {
        final chat = await repo.createConversation();
        final id = (await workbench.execute(
          chat,
          AssistantWorkbench.createTool,
          {'type': 'xlsx', 'name': 'budget'},
        ))['file_id'];
        final edited = await workbench.execute(
          chat,
          AssistantWorkbench.editTool,
          {
            'file_id': id,
            'action': 'write',
            'sheet': 'Maand',
            'cell': 'A1',
            'rows': [
              ['Post', 'Bedrag'],
              ['Huur', 950],
              ['Totaal', '=SUM(B2:B2)'],
            ],
          },
        );
        expect(edited['changed'], 'A1:B3');
        final read = await workbench.execute(
          chat,
          AssistantWorkbench.readTool,
          {'file_id': id, 'index': 0, 'range': 'B2:B3'},
        );
        expect(read['rows'], [
          {
            'row': 2,
            'cells': ['950'],
          },
          {
            'row': 3,
            'cells': ['=SUM(B2:B2)'],
          },
        ]);
        expect(workbench.focus?.coversCell(2, 1), isTrue);
      },
    );

    test('a later session edits an earlier file through its sidecar', () async {
      final chat = await repo.createConversation();
      final created = await workbench.execute(
        chat,
        AssistantWorkbench.createTool,
        {'type': 'docx', 'name': 'oud'},
      );
      await workbench.execute(chat, AssistantWorkbench.editTool, {
        'file_id': created['file_id'],
        'action': 'append',
        'content': 'Eerste versie',
      });

      final later = AssistantWorkbench(repo, directory: () async => directory);
      addTearDown(later.dispose);
      final result = await later.execute(chat, AssistantWorkbench.editTool, {
        'file_id': created['file_id'],
        'action': 'replace',
        'index': 0,
        'content': 'Tweede versie',
      });
      expect(result['status'], 'saved');
      expect(_documentXml(created['path']), contains('Tweede versie'));
      expect(later.file?.path, created['path'], reason: 'edits open the file');
    });

    test('bad input comes back as invalid instead of throwing', () async {
      final chat = await repo.createConversation();
      expect(
        (await workbench.execute(chat, AssistantWorkbench.editTool, {
          'file_id': 999,
          'action': 'append',
        }))['status'],
        'invalid',
      );
      expect(
        (await workbench.execute(chat, AssistantWorkbench.createTool, {
          'type': 'exe',
          'name': 'x',
        }))['status'],
        'invalid',
      );
    });

    test(
      'the reply ending clears the highlight but keeps the file open',
      () async {
        final chat = await repo.createConversation();
        final id = (await workbench.execute(
          chat,
          AssistantWorkbench.createTool,
          {'type': 'docx', 'name': 'x'},
        ))['file_id'];
        workbench.modelActive = true;
        await workbench.execute(chat, AssistantWorkbench.editTool, {
          'file_id': id,
          'action': 'append',
          'content': 'a',
        });
        expect(workbench.focus, isNotNull);
        workbench.modelActive = false;
        expect(workbench.focus, isNull);
        expect(workbench.hasFile, isTrue);
      },
    );
  });

  test(
    'create_artifact refuses Office types and hands them to the office tools',
    () async {
      final store = AssistantArtifactStore(
        repo,
        directory: () async => directory,
      );
      final enumValues =
          (AssistantArtifactStore.schema.parameters['properties']
                  as Map)['type']['enum']
              as List;
      expect(enumValues, isNot(contains('docx')));
      expect(
        () => store.create(1, {'name': 'x', 'type': 'xlsx', 'content': 'a'}),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'the controller offers the office tools and records the file on the reply',
    () async {
      final settings = await SettingsController.load();
      addTearDown(settings.dispose);
      settings.setAiProviderId('google');
      settings.setAdminPlan('nova');
      final client = _WritingClient();
      final controller = ChatController(
        repository: repo,
        keyStore: _Keys(),
        tools: _Tools(),
        settings: settings,
        clientOverride: client,
        workbench: workbench,
      );
      client.workbench = workbench;
      final chat = await repo.createConversation();
      var layoutRebuilds = 0;
      controller.addListener(() => layoutRebuilds++);

      await controller.sendMessage(
        chat,
        'Maak een notitie',
        artifactType: 'docx',
      );

      expect(client.toolNames, containsAll(AssistantWorkbench.toolNames));
      expect(client.activeDuringEdits, [true]);
      expect(workbench.modelActive, isFalse);
      expect(workbench.session?.document.blocks.length, 4);
      final reply = (await repo.loadMessages(chat)).last;
      expect(reply.role, 'assistant');
      final artifacts =
          (jsonDecode(reply.metadataJson!) as Map)['artifacts'] as List;
      expect((artifacts.single as Map)['name'], 'notitie.docx');
      expect(
        layoutRebuilds,
        greaterThanOrEqualTo(3),
        reason: 'send, file opened, done',
      );
    },
  );

  group('panel', () {
    Future<void> pumpPanel(WidgetTester tester, {VoidCallback? onClose}) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: AssistantFilePanel(
              workbench: workbench,
              onClose: onClose ?? () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows a Word page that follows each edit with a writing tag', (
      tester,
    ) async {
      late int id;
      await tester.runAsync(() async {
        final chat = await repo.createConversation();
        id =
            (await workbench.execute(chat, AssistantWorkbench.createTool, {
                  'type': 'docx',
                  'name': 'notitie',
                }))['file_id']
                as int;
      });
      workbench.modelActive = true;
      await pumpPanel(tester);
      expect(find.text('notitie.docx'), findsOneWidget);
      expect(find.text('The assistant is starting this file…'), findsOneWidget);

      await tester.runAsync(
        () => workbench.execute(1, AssistantWorkbench.editTool, {
          'file_id': id,
          'action': 'append',
          'content':
              '# Doel en gevraagde besluiten\n\n| Aan | Raad van Bestuur |\n|---|---|\n| Van | CRO |',
        }),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Doel en gevraagde besluiten', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Raad van Bestuur', findRichText: true), findsOneWidget);
      expect(find.text('Writing'), findsWidgets);
      expect(find.text('Writing block 1–2'), findsOneWidget);

      workbench.modelActive = false;
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Writing'), findsNothing);
    });

    testWidgets('draws slides and a sheet grid with computed formulas', (
      tester,
    ) async {
      late int deck;
      late int sheet;
      await tester.runAsync(() async {
        final chat = await repo.createConversation();
        deck =
            (await workbench.execute(chat, AssistantWorkbench.createTool, {
                  'type': 'pptx',
                  'name': 'deck',
                }))['file_id']
                as int;
        await workbench.execute(chat, AssistantWorkbench.editTool, {
          'file_id': deck,
          'action': 'append',
          'content':
              '# Dreigingsbeeld\n## 2026\n---\n# Maatregelen\n- MFA overal',
        });
      });
      await pumpPanel(tester);
      expect(find.text('Dreigingsbeeld', findRichText: true), findsOneWidget);
      expect(find.text('MFA overal', findRichText: true), findsOneWidget);

      await tester.runAsync(() async {
        sheet =
            (await workbench.execute(1, AssistantWorkbench.createTool, {
                  'type': 'xlsx',
                  'name': 'scores',
                }))['file_id']
                as int;
        await workbench.execute(1, AssistantWorkbench.editTool, {
          'file_id': sheet,
          'action': 'write',
          'sheet': 'Risico',
          'cell': 'A1',
          'rows': [
            ['Dreiging', 'Score'],
            ['Phishing', '8'],
            ['Totaal', '=SUM(B2:B2)*100'],
          ],
        });
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('scores.xlsx'), findsOneWidget);
      expect(find.text('Phishing'), findsOneWidget);
      expect(find.text('800'), findsOneWidget);
      expect(
        find.text('Risico'),
        findsOneWidget,
        reason: 'named sheet gets a tab',
      );
    });

    testWidgets('the close button hands control back', (tester) async {
      await tester.runAsync(() async {
        await workbench.execute(1, AssistantWorkbench.createTool, {
          'type': 'docx',
          'name': 'x',
        });
      });
      var closed = false;
      await pumpPanel(tester, onClose: () => closed = true);
      await tester.tap(find.byTooltip('Close preview'));
      expect(closed, isTrue);
    });
  });
}

String p(String path) => File(path).absolute.path.toLowerCase();

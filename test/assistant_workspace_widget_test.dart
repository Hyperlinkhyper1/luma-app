import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/chat_page.dart';
import 'package:luma/features/chat/chat_scope.dart';
import 'package:luma/features/chat/data/chat_database.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/widgets/assistant_artifacts_view.dart';
import 'package:luma/features/chat/widgets/assistant_projects_view.dart';
import 'package:luma/features/chat/widgets/chat_input_bar.dart';
import 'package:luma/features/chat/widgets/compose_mode_menu.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

class _Sync extends ChangeNotifier implements SyncService {
  @override
  String? get email => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ChatDatabase db;
  late ChatRepository repository;
  late SettingsController settings;
  setUp(() async {
    db = ChatDatabase(NativeDatabase.memory());
    repository = ChatRepository(db);
    settings = await SettingsController.load();
  });
  tearDown(() async {
    settings.dispose();
    await db.close();
  });
  Widget host(Widget body, {ThemeData? theme}) => SettingsScope(
    controller: settings,
    child: ChatScope(
      repository: repository,
      child: MaterialApp(
        theme: theme ?? LumaTheme.dark,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );

  testWidgets(
    'reference sidebar order, navigation and content search at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late int chat;
      await tester.runAsync(() async {
        final project = await repository.createProject('Project');
        chat = await repository.createConversation(
          title: 'Found by contents',
          projectId: project,
        );
        await repository.addMessage(chat, 'user', 'needle');
      });
      var projects = 0;
      var artifacts = 0;
      int? selected;
      final sync = _Sync();
      addTearDown(sync.dispose);
      await tester.pumpWidget(
        host(
          AssistantSidebar(
            activeConversationId: null,
            syncService: sync,
            onSelect: (id) => selected = id,
            onCollapse: () {},
            onOpenPlugin: (_) {},
            onProjects: () => projects++,
            onArtifacts: () => artifacts++,
            selectedView: 'chat',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final searchY = tester.getTopLeft(find.byType(TextField)).dy;
      expect(searchY, lessThan(tester.getTopLeft(find.text('New')).dy));
      expect(
        tester.getTopLeft(find.text('New')).dy,
        lessThan(tester.getTopLeft(find.text('Projects')).dy),
      );
      expect(find.text('Found by contents'), findsNothing);
      await tester.tap(find.text('Projects'));
      await tester.tap(find.text('Artifacts'));
      expect(projects, 1);
      expect(artifacts, 1);
      await tester.enterText(find.byType(TextField), 'needle');
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pumpAndSettle();
      expect(find.text('Found by contents'), findsOneWidget);
      await tester.tap(find.text('Found by contents'));
      expect(selected, chat);
      expect(tester.takeException(), isNull);
      await tester.runAsync(db.close);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('project screen shows only its chats and memory on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late int project;
    await tester.runAsync(() async {
      project = await repository.createProject('My project');
      await repository.rememberProjectFact(project, 'A private project fact');
      final chat = await repository.createConversation(
        title: 'Project chat',
        projectId: project,
      );
      await repository.addMessage(chat, 'user', 'Hi');
      final main = await repository.createConversation(title: 'Main chat');
      await repository.addArtifact(
        conversationId: chat,
        name: 'project-report.pdf',
        path: 'missing/project-report.pdf',
        mimeType: 'application/pdf',
      );
      await repository.addArtifact(
        conversationId: main,
        name: 'main-notes.txt',
        path: 'missing/main-notes.txt',
        mimeType: 'text/plain',
      );
    });
    await tester.pumpWidget(
      host(
        AssistantProjectsView(
          repository: repository,
          projectId: project,
          onOpenProject: (_) {},
          onOpenChat: (_) {},
          onNewChat: (_) {},
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle();
    expect(find.text('Project chat'), findsOneWidget);
    expect(find.text('Main chat'), findsNothing);
    expect(find.text('A private project fact'), findsOneWidget);
    expect(find.text('project-report.pdf'), findsNothing);
    await tester.tap(find.text('Artifacts · 1'));
    await tester.pumpAndSettle();
    expect(find.text('project-report.pdf'), findsOneWidget);
    expect(find.text('main-notes.txt'), findsNothing);
    expect(find.text('Project chat'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('themed artifact library filters and opens actions at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await repository.addArtifact(
        name: 'report.csv',
        path: '${Directory.systemTemp.path}/missing.csv',
        mimeType: 'text/csv',
        createdAt: DateTime(2026, 11, 3),
      );
      await repository.addArtifact(
        name: 'diagram.svg',
        path: '${Directory.systemTemp.path}/missing.svg',
        mimeType: 'image/svg+xml',
        createdAt: DateTime(2026, 11, 4),
      );
    });
    final theme = LumaTheme.from(Brightness.dark, null, LumaThemeStyle.coffee);
    await tester.pumpWidget(
      host(
        AssistantArtifactsView(repository: repository, onOpenChat: (_) {}),
        theme: theme,
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Artifacts')).style?.fontFamily,
      theme.textTheme.headlineMedium?.fontFamily,
    );
    expect(find.byType(LumaCard), findsOneWidget);
    final accent = theme.extension<LumaPalette>()!.accent;
    expect(tester.widget<Text>(find.text('All')).style?.color, accent);
    expect(find.text('report.csv'), findsOneWidget);
    expect(find.text('diagram.svg'), findsOneWidget);
    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();
    expect(find.text('diagram.svg'), findsOneWidget);
    expect(find.text('report.csv'), findsNothing);
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('diagram.svg'), findsNothing);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'diagram');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('report.csv'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Save a copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'plus menu gates Free and offers Orbit artifact types without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? picked;
      Widget composer(bool paid) => ChatInputBar(
        onSend: (_) {},
        sending: false,
        enabled: true,
        caption: '',
        leading: ComposeModeButton(
          mode: AssistantComposeMode.chat,
          onChanged: (_) {},
          filesAllowed: paid,
          modesAllowed: false,
          onUpload: () {},
          onArtifactTypeChanged: (type) => picked = type,
          availability: () async =>
              const ComposeModeAvailability(research: false, picture: false),
        ),
        modelSelector: const Text('Aurora 1.0'),
      );
      await tester.pumpWidget(host(composer(false)));
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      final locked = tester.widget<SubmenuButton>(
        find.ancestor(
          of: find.text('Artifact generation'),
          matching: find.byType(SubmenuButton),
        ),
      );
      // Pictures are on every plan (header + row); file types stay behind Orbit.
      expect(locked.menuChildren, hasLength(2));
      expect(find.text('Requires Orbit or Nova'), findsOneWidget);
      expect(
        find.text('Pictures only · files need Orbit or Nova'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(310, 650));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(composer(true)));
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artifact generation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV spreadsheet'));
      await tester.pumpAndSettle();
      expect(picked, 'csv');
      expect(tester.takeException(), isNull);
      await tester.runAsync(db.close);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

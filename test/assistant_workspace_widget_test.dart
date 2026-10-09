import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  Widget host(Widget body) => SettingsScope(
    controller: settings,
    child: ChatScope(
      repository: repository,
      child: MaterialApp(
        theme: LumaTheme.dark,
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
      await repository.createConversation(title: 'Main chat');
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
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('artifact library lists existing files at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => repository.addArtifact(
        name: 'report.csv',
        path: '${Directory.systemTemp.path}/missing.csv',
        mimeType: 'text/csv',
      ),
    );
    await tester.pumpWidget(
      host(AssistantArtifactsView(repository: repository, onOpenChat: (_) {})),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle();
    expect(find.text('report.csv'), findsOneWidget);
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
      final locked = tester.widget<PopupMenuItem<Object>>(
        find.ancestor(
          of: find.text('Artifact generation'),
          matching: find.byType(PopupMenuItem<Object>),
        ),
      );
      expect(locked.enabled, isFalse);
      expect(find.text('Requires Orbit or Nova'), findsNWidgets(2));
      await tester.tapAt(const Offset(310, 650));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(composer(true)));
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artifact generation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV spreadsheet (.csv)'));
      await tester.pumpAndSettle();
      expect(picked, 'csv');
      expect(tester.takeException(), isNull);
      await tester.runAsync(db.close);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/account/assistant_agents_view.dart';
import 'package:luma/features/chat/account/assistant_panels.dart';
import 'package:luma/features/chat/account/assistant_settings_view.dart';
import 'package:luma/features/chat/memory/assistant_memory_repository.dart';
import 'package:luma/features/chat/memory/assistant_memory_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_workbench_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_workbench_scope.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _host(AssistantMemoryRepository memory, Widget child) =>
    AssistantMemoryScope(
      repository: memory,
      child: MaterialApp(
        theme: LumaTheme.dark,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  late Directory directory;
  late AssistantMemoryRepository memory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('luma_assistant_ui_');
    memory = AssistantMemoryRepository(
      supportDirectoryProvider: () async => directory,
    );
    await memory.ready;
  });

  tearDown(() async {
    memory.dispose();
    // A write the repository started inside the widget test's fake-async
    // zone never finishes and can keep the JSON file open on Windows.
    try {
      await directory.delete(recursive: true);
    } on FileSystemException catch (_) {}
  });

  testWidgets('settings side bar switches between Chat, Memory and User', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(memory, const AssistantSettingsView()));
    expect(find.text('Response language'), findsOneWidget);

    await tester.tap(find.text('Mono'));
    await tester.pump();
    expect(memory.font, ChatFont.mono);

    await tester.tap(find.text('Memory').first);
    await tester.pump();
    expect(find.text('Nothing remembered yet'), findsOneWidget);

    await tester.runAsync(
      () => memory.saveEntry(
        section: MemorySection.topics,
        title: 'Hardware',
        description: "The user's PC hardware",
        body: 'RTX 4070',
      ),
    );
    await tester.pump();
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Hardware'), findsOneWidget);
    expect(find.text("The user's PC hardware"), findsOneWidget);

    await tester.tap(find.text('User').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Ayden');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(memory.profile.callMe, 'Ayden');
    expect(memory.promptContext(), contains('Call them: Ayden'));
  });

  testWidgets('account menu opens the agents panel', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        memory,
        Align(
          alignment: Alignment.bottomLeft,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                final box = context.findRenderObject()! as RenderBox;
                showAssistantAccountMenu(
                  context,
                  footerRect: box.localToGlobal(Offset.zero) & box.size,
                  email: 'me@example.com',
                  onOpenPlugin: (_) {},
                );
              },
              child: const Text('Ayden'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ayden'));
    await tester.pumpAndSettle();
    expect(find.text('Usage'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);

    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantAgentsView), findsOneWidget);
    expect(find.text('No agents yet'), findsOneWidget);
  });

  testWidgets('agents panel lists the AI Usage agents', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Built inside runAsync so its load runs on the real clock — created in
    // the fake-async zone, `ready` would never complete.
    late final AiWorkbenchRepository workbench;
    await tester.runAsync(() async {
      workbench = AiWorkbenchRepository(
        supportDirectoryProvider: () async => directory,
      );
      await workbench.ready;
      await workbench.saveAgent(
        name: 'Code reviewer',
        description: 'Reviews Flutter changes.',
        instructions: 'Find bugs.',
        outputFormat: '',
        libraryEntryIds: const [],
        preferredModel: 'gpt-5.6-terra',
      );
    });

    await tester.pumpWidget(
      _host(
        memory,
        AiWorkbenchScope(
          repository: workbench,
          child: AssistantAgentsView(onOpenPlugin: (_) {}),
        ),
      ),
    );
    expect(find.text('Code reviewer'), findsOneWidget);
    expect(find.text('Reviews Flutter changes.'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    workbench.dispose();
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_file_pane.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_page.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_queue_panel.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_session.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_transfer_queue.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/theme/luma_theme.dart';

/// Loading settings does real async I/O, so it runs outside the widget
/// tester's fake clock; with no path_provider on the host the controller
/// stays in memory.
Future<SettingsController> _settings(WidgetTester tester, String plan) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  controller.setAdminPlan(plan);
  return controller;
}

Future<void> _pumpPage(WidgetTester tester, String plan) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final settings = await _settings(tester, plan);
  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      home: SettingsScope(
        controller: settings,
        child: const Scaffold(body: SftpPage()),
      ),
    ),
  );
  await tester.pump();
  // The site store's first read hits path_provider, which isn't there under
  // the test host — let that resolve so the manager leaves its loading state.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

const _entries = [
  PaneEntry(
    name: 'www',
    path: '/var/www',
    isDirectory: true,
    permissions: 'rwxr-xr-x',
  ),
  PaneEntry(
    name: 'notes.txt',
    path: '/var/notes.txt',
    isDirectory: false,
    size: 2048,
    permissions: 'rw-r--r--',
  ),
];

Future<void> _pumpPane(
  WidgetTester tester, {
  required Set<String> selection,
  void Function(PaneEntry entry)? onOpen,
  void Function(PaneEntry entry)? onToggleSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      home: Scaffold(
        body: SftpFilePane(
          side: PaneSide.remote,
          title: 'example.com',
          path: '/var',
          crumbs: const [(label: '/', path: '/'), (label: 'var', path: '/var')],
          entries: _entries,
          selection: selection,
          loading: false,
          error: null,
          canGoUp: true,
          onUp: () {},
          onRefresh: () {},
          onHome: () {},
          onNewFolder: () {},
          onNavigate: (_) {},
          onOpen: onOpen ?? (_) {},
          onToggleSelect: onToggleSelect ?? (_) {},
          onContextMenu: (_, _) {},
          onDropped: (_, _) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('plan gate', () {
    testWidgets('Core sees the upgrade prompt instead of the browser',
        (tester) async {
      await _pumpPage(tester, 'core');

      expect(find.text('SFTP is a Nova exclusive'), findsOneWidget);
      expect(find.text('Site Manager'), findsNothing);
    });

    testWidgets('Orbit is also held back', (tester) async {
      await _pumpPage(tester, 'orbit');

      expect(find.text('SFTP is a Nova exclusive'), findsOneWidget);
    });

    testWidgets('Nova opens on the Site Manager', (tester) async {
      await _pumpPage(tester, 'nova');

      expect(find.text('SFTP is a Nova exclusive'), findsNothing);
      expect(find.text('Site Manager'), findsOneWidget);
      expect(find.text('No servers yet'), findsOneWidget);
      expect(
        find.textContaining('Nothing passes through a luma server'),
        findsOneWidget,
      );
    });
  });

  group('file pane', () {
    testWidgets('lists entries with their size and permissions',
        (tester) async {
      await _pumpPane(tester, selection: {});

      expect(find.text('www'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('rwxr-xr-x'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
    });

    testWidgets('tapping a folder opens it, tapping a file selects it',
        (tester) async {
      final opened = <String>[];
      final toggled = <String>[];
      await _pumpPane(
        tester,
        selection: {},
        onOpen: (entry) => opened.add(entry.name),
        onToggleSelect: (entry) => toggled.add(entry.name),
      );

      await tester.tap(find.text('www'));
      await tester.pump();
      expect(opened, ['www']);
      expect(toggled, isEmpty);

      await tester.tap(find.text('notes.txt'));
      await tester.pump();
      expect(toggled, ['notes.txt']);
    });

    testWidgets('the footer counts the selection', (tester) async {
      await _pumpPane(tester, selection: {'/var/notes.txt'});

      expect(find.text('1 of 2 selected'), findsOneWidget);
    });
  });

  group('queue panel', () {
    testWidgets('shows what is moving, and clears when finished',
        (tester) async {
      final queue = SftpTransferQueue();
      addTearDown(queue.dispose);
      queue.enqueueUpload(File('notes.txt'), '/var/notes.txt', size: 4096);

      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(
            body: SftpQueuePanel(
              queue: queue,
              expanded: true,
              onToggleExpanded: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Transferring'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('1 file left'), findsOneWidget);
      // Nothing is bound, so it sits waiting rather than failing.
      expect(find.text('Waiting'), findsOneWidget);

      queue.cancelAll();
      await tester.pump();

      expect(find.text('Transfer queue'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
    });

    testWidgets('an empty queue explains how to fill it', (tester) async {
      final queue = SftpTransferQueue();
      addTearDown(queue.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(
            body: SftpQueuePanel(
              queue: queue,
              expanded: true,
              onToggleExpanded: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Drag files between the two sides'),
          findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
    });
  });

  group('host key prompt', () {
    test('carries what the dialog needs to warn about a changed key', () {
      const prompt = SftpHostKeyPrompt(
        host: 'example.com',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:new',
        changed: true,
        previousFingerprint: 'SHA256:old',
      );

      expect(prompt.changed, isTrue);
      expect(prompt.previousFingerprint, 'SHA256:old');
    });
  });
}

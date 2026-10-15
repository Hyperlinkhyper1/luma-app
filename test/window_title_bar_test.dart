import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/plugin_tab_bar.dart';
import 'package:luma/app/window_title_bar.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Future<List<String>> _pumpTitleBar(
  WidgetTester tester, {
  ValueChanged<String>? onSelect,
  ValueChanged<String>? onClose,
  VoidCallback? onAdd,
  VoidCallback? onTrailing,
  bool withTabs = true,
  bool showWindowControls = true,
}) async {
  tester.view.physicalSize = const Size(1000, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final calls = <String>[];
  const channel = MethodChannel('window_manager');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.add(call.method);
    return switch (call.method) {
      'isMaximized' || 'isFullScreen' => false,
      _ => null,
    };
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            WindowTitleBar(
              title: 'Dashboard',
              showWindowControls: showWindowControls,
              trailing: IconButton(
                tooltip: 'Inbox',
                onPressed: onTrailing ?? () {},
                icon: const Icon(Icons.inbox_rounded),
              ),
              tabs: withTabs
                  ? PluginTabBar(
                      tabs: const [
                        ShellTabItem(
                          id: 'dashboard',
                          title: 'Dashboard',
                          icon: Icons.home_rounded,
                        ),
                      ],
                      activeTabId: 'dashboard',
                      onSelect: onSelect ?? (_) {},
                      onClose: onClose ?? (_) {},
                      onAdd: onAdd ?? () {},
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  calls.clear();
  return calls;
}

void main() {
  testWidgets(
    'dragging empty tab-strip space moves the window',
    (tester) async {
      final calls = await _pumpTitleBar(tester);
      final tabs = tester.getRect(find.byType(PluginTabBar));
      final add = tester.getRect(find.byTooltip('New tab'));
      final position = Offset((add.right + tabs.right) / 2, tabs.center.dy);

      await tester.dragFrom(
        position,
        const Offset(80, 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'dragging brand padding moves the window',
    (tester) async {
      final calls = await _pumpTitleBar(tester);

      await tester.dragFrom(
        const Offset(8, 23),
        const Offset(80, 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'dragging the strip above tabs moves the window',
    (tester) async {
      final calls = await _pumpTitleBar(tester);
      final tabs = tester.getRect(find.byType(PluginTabBar));

      await tester.dragFrom(
        Offset(tabs.left + 20, tabs.top + 2),
        const Offset(80, 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'window dragging begins only after primary mouse movement',
    (tester) async {
      final calls = await _pumpTitleBar(tester);
      final gesture = await tester.startGesture(
        const Offset(8, 23),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(calls, isNot(contains('startDragging')));

      await gesture.moveBy(const Offset(80, 30));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'secondary mouse dragging does not move the window',
    (tester) async {
      final calls = await _pumpTitleBar(tester);
      final gesture = await tester.startGesture(
        const Offset(8, 23),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.moveBy(const Offset(80, 30));
      await gesture.up();
      expect(calls, isNot(contains('startDragging')));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'double-clicking empty space maximizes without starting a drag',
    (tester) async {
      final calls = await _pumpTitleBar(tester);
      final tabs = tester.getRect(find.byType(PluginTabBar));
      final add = tester.getRect(find.byTooltip('New tab'));
      final position = Offset((add.right + tabs.right) / 2, tabs.center.dy);

      await tester.tapAt(position, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(position, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(calls, contains('maximize'));
      expect(calls, isNot(contains('startDragging')));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'tabs and title-bar buttons keep their actions without dragging',
    (tester) async {
      final selected = <String>[];
      final closed = <String>[];
      var added = 0;
      var inboxOpened = 0;
      final calls = await _pumpTitleBar(
        tester,
        onSelect: selected.add,
        onClose: closed.add,
        onAdd: () => added++,
        onTrailing: () => inboxOpened++,
      );

      await tester.tap(find.text('Dashboard'));
      await tester.tap(find.byTooltip('Close tab'));
      await tester.tap(find.byTooltip('New tab'));
      await tester.tap(find.byTooltip('Inbox'));
      await tester.tap(find.byTooltip('Minimize'));
      await tester.tap(find.byTooltip('Maximize'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      expect(selected, ['dashboard']);
      expect(closed, ['dashboard']);
      expect(added, 1);
      expect(inboxOpened, 1);
      expect(calls, containsAll(['minimize', 'maximize', 'hide']));
      expect(calls, isNot(contains('startDragging')));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'title bar without tabs still moves the window',
    (tester) async {
      final calls = await _pumpTitleBar(tester, withTabs: false);

      await tester.dragFrom(
        const Offset(400, 23),
        const Offset(80, 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'title bar without window controls does not start dragging',
    (tester) async {
      final calls = await _pumpTitleBar(tester, showWindowControls: false);

      await tester.dragFrom(
        const Offset(8, 23),
        const Offset(80, 30),
        kind: PointerDeviceKind.mouse,
      );
      expect(calls, isNot(contains('startDragging')));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

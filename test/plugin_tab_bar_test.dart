import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/plugin_tab_bar.dart';
import 'package:luma/app/window_title_bar.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

ShellTabItem _plugin(String id, String name) =>
    ShellTabItem(id: id, title: name, icon: Icons.calculate);

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('tabs share the title bar at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var added = 0;
      final windowCalls = <String>[];
      const windowChannel = MethodChannel('window_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowChannel,
        (call) async {
          windowCalls.add(call.method);
          return call.method == 'isMaximized' ? false : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          windowChannel,
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
                  showWindowControls: width >= 1000,
                  trailing: const SizedBox(width: 96),
                  tabs: PluginTabBar(
                    tabs: [
                      _plugin('home', 'Dashboard'),
                      _plugin('ai', 'AI Usage'),
                    ],
                    activeTabId: 'home',
                    onSelect: (_) {},
                    onClose: (_) {},
                    onAdd: () => added++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(WindowTitleBar)).height,
        WindowTitleBar.height + 1,
      );
      final titleBar = tester.getRect(find.byType(WindowTitleBar));
      final tab = tester.getRect(find.text('Dashboard'));
      expect(tab.top, greaterThanOrEqualTo(titleBar.top));
      expect(tab.bottom, lessThanOrEqualTo(titleBar.bottom));
      if (width >= 1000) {
        expect(find.text('luma'), findsOneWidget);
        final close = tester.getRect(find.byTooltip('Close'));
        expect(close.top, titleBar.top);
        expect(close.bottom, lessThanOrEqualTo(titleBar.bottom));
      }
      await tester.tap(find.byTooltip('New tab'));
      expect(added, 1);
      expect(windowCalls, isNot(contains('startDragging')));
    });
  }

  testWidgets('tabs select, close, middle-click close and add', (tester) async {
    final selected = <String>[];
    final closed = <String>[];
    var added = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: PluginTabBar(
            tabs: [
              _plugin('calculator', 'Calculator'),
              _plugin('calendar', 'Calendar'),
            ],
            activeTabId: 'calculator',
            onSelect: selected.add,
            onClose: closed.add,
            onAdd: () => added++,
          ),
        ),
      ),
    );

    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    expect(selected, ['calendar']);

    await tester.tap(find.byTooltip('Close tab').first);
    expect(closed, ['calculator']);

    final middle = await tester.startGesture(
      tester.getCenter(find.text('Calendar')),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await middle.up();
    expect(closed, ['calculator', 'calendar']);

    await tester.tap(find.byTooltip('New tab'));
    expect(added, 1);
  });
}

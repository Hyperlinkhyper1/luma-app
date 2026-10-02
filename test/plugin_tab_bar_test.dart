import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/plugin_tab_bar.dart';
import 'package:luma/features/plugins/plugin_repository.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

InstalledPluginRecord _plugin(String id, String name) => InstalledPluginRecord(
  pluginId: id,
  name: name,
  icon: 'calculate',
  version: '1.0.0',
  installedAt: DateTime(2026),
  downloadCount: 0,
);

void main() {
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
            activePluginId: 'calculator',
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

    await tester.tap(find.byTooltip('Open another plugin'));
    expect(added, 1);
  });
}

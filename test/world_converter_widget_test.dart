import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/tools/other_tools_view.dart';
import 'package:luma/features/converter/tools/world_converter_view.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets(
    'Other opens world conversion with entity transfer selected at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(body: OtherToolsView(onBack: () {})),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'Other hub layout');
      await tester.tap(find.text('Minecraft world converter'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'World converter layout');
      expect(find.byType(WorldConverterView), findsOneWidget);
      expect(find.text('Target Minecraft version'), findsOneWidget);
      final entitySwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Convert entities'),
      );
      expect(entitySwitch.value, isTrue);
      await tester.ensureVisible(find.text('Preserve statistics'));
      await tester.tap(find.text('Preserve statistics'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Preserve statistics'),
            )
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

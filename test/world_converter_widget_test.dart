import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/tools/other_tools_view.dart';
import 'package:luma/features/converter/tools/world_converter_view.dart';
import 'package:luma/features/converter/world/world_conversion.dart';
import 'package:luma/features/converter/world/world_converter_service.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('pasted quoted world path loads and displays scan warnings', (
    tester,
  ) async {
    final service = _WorldImportService();
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: WorldConverterView(onBack: () {}, service: service),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      r'"C:\Users\ayden\Downloads\resort - Kopiëren.mcworld"',
    );
    await tester.ensureVisible(find.text('Load world'));
    await tester.tap(find.text('Load world'));
    await tester.pumpAndSettle();
    expect(
      service.loadedPath,
      r'C:\Users\ayden\Downloads\resort - Kopiëren.mcworld',
    );
    expect(find.textContaining('513 entities'), findsOneWidget);
    expect(
      find.text('Repeated actor references normalized on a temporary copy.'),
      findsOneWidget,
    );
    expect(find.text('26.3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('world import exposes a pasteable path and .mcworld picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(body: WorldConverterView(onBack: () {})),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Choose .mcworld file'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      r'"C:\Users\ayden\Downloads\resort - Kopiëren.mcworld"',
    );
    expect(find.text('Load world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
      expect(find.text('1.26.60'), findsOneWidget);
      await tester.ensureVisible(find.text('1.26.60'));
      await tester.tap(find.text('1.26.60'));
      await tester.pumpAndSettle();
      expect(find.text('1.21.130'), findsOneWidget);
      expect(find.text('1.21.120'), findsOneWidget);
      await tester.tap(find.text('1.21.130'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Expanded version menu');
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

class _WorldImportService extends WorldConverterService {
  String? loadedPath;
  @override
  Future<WorldCensus> inspect(String path) async {
    loadedPath = path;
    return WorldCensus(
      edition: WorldEdition.bedrock,
      entities: List.generate(
        513,
        (_) => const WorldEntityRecord('minecraft:cow', 0, [0, 64, 0]),
      ),
      localPlayer: true,
      remotePlayers: 11,
      version: [1, 20, 81],
      warnings: const [
        'Repeated actor references normalized on a temporary copy.',
      ],
    );
  }
}

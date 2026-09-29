import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_shell.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/pagoda_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

/// Benchmark tile art downloads from the luma server now — nothing ships in
/// the bundle — so the tab starts with no roster and both tiles render their
/// gradient stand-in.
///
/// The scope sits above [MaterialApp] (as in `main.dart`) so pages pushed by
/// the tiles still see the repository.
Widget _app({AiBenchmarkManifest manifest = AiBenchmarkManifest.empty}) =>
    AiBenchmarkScope(
      repository: AiBenchmarkRepository.withManifest(manifest),
      child: MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(body: TestsTab()),
      ),
    );

void main() {
  // The shell drives its IndexedStack off the enum's index, so keep the
  // navigation order and stack order in lockstep.
  test('rail sections keep their stack order', () {
    expect(AiUsageSection.values.length, 7);
    expect(AiUsageSection.openSource.index, 2);
    expect(AiUsageSection.library.index, 3);
    expect(AiUsageSection.agents.index, 4);
    expect(AiUsageSection.tests.index, 5);
    expect(AiUsageSection.tests.label, 'Tests');
    expect(AiUsageSection.assets.index, 6);
    expect(AiUsageSection.assets.label, 'Assets');
  });

  testWidgets('the tile names itself in the purple band', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Pagoda Test'), findsOneWidget);
    expect(find.text('Engine Test'), findsOneWidget);
    expect(find.text('PC Test'), findsOneWidget);
    // All three tiles currently share the same subtitle.
    expect(find.text('Open the test screen'), findsNWidgets(3));
  });

  testWidgets('the whole tile is one button that opens the test screen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.byType(PagodaTestPage), findsNothing);
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Pagoda Test'));
    await tester.pumpAndSettle();

    expect(find.byType(PagodaTestPage), findsOneWidget);
  });

  // With no roster the tiles show their gradient stand-in rather than
  // throwing: the tab must look deliberate with no account at all.
  testWidgets('tiles with no downloaded artwork yet still render', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.precision_manufacturing_rounded), findsOneWidget);
    expect(find.byIcon(Icons.temple_buddhist_rounded), findsOneWidget);
    expect(find.byIcon(Icons.computer_rounded), findsOneWidget);
    expect(find.text('Pagoda Test'), findsOneWidget);
    expect(find.text('Engine Test'), findsOneWidget);
    expect(find.text('PC Test'), findsOneWidget);
  });

  testWidgets('local Step 5 benchmark is available without a roster', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Pagoda Test'));
    await tester.pumpAndSettle();

    expect(find.text('Step 5'), findsOneWidget);
    expect(find.text('GPT 6 Luna (Low)'), findsOneWidget);
    expect(find.text('No benchmarks yet'), findsNothing);
  });

  testWidgets('GPT 6.1 Sol engine is bundled and listed without a server', (
    tester,
  ) async {
    final scene = await rootBundle.loadString(
      'assets/ai_usage/engine_tests/gpt_6_1_sol_low.html',
    );
    expect(scene, contains('GPT 6.1 Sol (Low)'));
    expect(scene, contains('window.engineDebug'));

    await tester.pumpWidget(_app());
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Engine Test'));
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
  });

  testWidgets('GPT 6.1 Sol Xhigh loads its canonical bundled engine file', (
    tester,
  ) async {
    final scene = await rootBundle.loadString(
      'server/benchmarks/scenes/engine_gpt61_sol_xhigh/index.html',
    );
    expect(scene, contains('GPT 6.1 Sol (Xhigh)'));
    expect(scene, contains('window.engineDebug'));

    await tester.pumpWidget(_app());
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Engine Test'));
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'GPT 6.1 Sol (Xhigh)');
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ModelButton, 'GPT 6.1 Sol (Xhigh)'),
      findsOneWidget,
    );
    expect(find.text('GPT 6.1 Sol (Low)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'GPT 6.1 Sol');
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
  });

  testWidgets('GPT 6.1 Sol Xhigh stays discoverable on a 320px screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    final engineTile = find.widgetWithText(LumaHeroTile, 'Engine Test');
    await tester.ensureVisible(engineTile);
    await tester.tap(engineTile);
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server GPT 6.1 Sol engine replaces its bundled fallback', (
    tester,
  ) async {
    final manifest = AiBenchmarkManifest.fromJson({
      'benchmarks': [
        {
          'id': 'engine_gpt61_sol_low',
          'kind': 'engine',
          'model': 'GPT 6.1 Sol (Low)',
          'description': 'Server engine scene',
        },
      ],
    });
    await tester.pumpWidget(_app(manifest: manifest));
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Engine Test'));
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
    expect(find.text('Server engine scene'), findsOneWidget);
  });

  testWidgets('server Xhigh replaces only its matching bundled fallback', (
    tester,
  ) async {
    final manifest = AiBenchmarkManifest.fromJson({
      'benchmarks': [
        {
          'id': 'engine_gpt61_sol_xhigh',
          'kind': 'engine',
          'model': 'GPT 6.1 Sol (Xhigh)',
          'description': 'Server Xhigh engine scene',
        },
      ],
    });
    await tester.pumpWidget(_app(manifest: manifest));
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Engine Test'));
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
    expect(find.text('Server Xhigh engine scene'), findsOneWidget);
    expect(
      find.text('Procedural cross-plane V8 generated by GPT 6.1 Sol Xhigh.'),
      findsNothing,
    );
  });

  test('the wash goes opaque exactly at the bottom third', () {
    expect(HeroTileWash.solidStart, closeTo(2 / 3, 1e-9));

    final stops = HeroTileWash.gradient.stops!;
    final colors = HeroTileWash.gradient.colors;
    expect(stops.length, colors.length);

    // Transparent above the ramp, fully opaque from the bottom third down.
    expect(colors.first.a, 0);
    final solidIndex = stops.indexOf(HeroTileWash.solidStart);
    expect(solidIndex, isNonNegative);
    for (var i = solidIndex; i < colors.length; i++) {
      expect(colors[i].a, 1);
    }

    // The ramp only ever gets more opaque on the way down.
    for (var i = 1; i < colors.length; i++) {
      expect(stops[i], greaterThan(stops[i - 1]));
      expect(colors[i].a, greaterThanOrEqualTo(colors[i - 1].a));
    }
  });
}
